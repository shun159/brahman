defmodule Brahman.Dns.Forwarder do
  @moduledoc """
  DNS forwarder/server process
  """

  use GenServer, restart: :temporary, shutdown: 5000
  use Brahman.Dns.Header

  require Logger

  alias Brahman.Dns.Router
  alias Brahman.Dns.Resolver
  alias Brahman.Dns.Metrics

  @query_timeout 5000 * 2

  defmodule State do
    @moduledoc false

    defstruct dns_message: nil,
              dns_packet: "",
              reply_fun: nil,
              outstandings: [],
              send_query_time: nil,
              start_timestamp: nil,
              reply_sent: false,
              timer_ref: nil,
              query_name: nil

    @type t :: %State{
            dns_message: tuple(),
            dns_packet: binary(),
            reply_fun: function(),
            outstandings: [{:inet.ip4_address(), pid()}],
            send_query_time: integer(),
            start_timestamp: integer(),
            reply_sent: boolean(),
            timer_ref: reference(),
            query_name: String.t()
          }
  end

  # API functions

  @type reply_fun :: (binary() -> :ok) | {(... -> :ok), [term()]}

  @spec start_link(dns_packet :: binary(), reply_fun()) :: GenServer.on_start()
  def start_link(dns_packet, reply_fun) do
    GenServer.start_link(__MODULE__, [dns_packet, reply_fun])
  end

  # GenServer callback functions

  def init([dns_packet, reply_fun]) do
    {:ok, %State{dns_packet: dns_packet, reply_fun: reply_fun}, {:continue, :INIT}}
  end

  def handle_continue(:INIT, %State{dns_packet: packet} = state0) do
    case :dns.decode_message(packet) do
      {:formerr, _reason, packet} ->
        :ok = logging(:error, {:decode_error, packet})
        :ok = send_formerr(state0)
        {:stop, :normal, state0}

      dns_message() = message ->
        now = :erlang.monotonic_time()
        state = %{state0 | dns_message: message, send_query_time: now}
        {:noreply, state, {:continue, :QUERY}}
    end
  end

  def handle_continue(:QUERY, %State{dns_message: dns_message(questions: questions)} = state) do
    case Router.upstream_from(questions) do
      {[], _name} ->
        :ok = logging(:warn, :no_upstreams_available)
        :ok = Metrics.no_upstreams()
        _ = send_servfail(state)
        {:stop, :normal, state}

      {[_ | _] = upstreams, name} ->
        outstandings = Resolver.resolve(upstreams, state)
        start_time = :os.timestamp()
        tref = update_timer(@query_timeout, :timeout, state)

        {:noreply,
         %{
           state
           | outstandings: outstandings,
             start_timestamp: start_time,
             timer_ref: tref,
             query_name: name
         }}
    end
  end

  def handle_info(:timeout, %State{reply_sent: false} = state) do
    :ok = logging(:warn, {:query_timeout, state.query_name})
    _ = send_servfail(state)
    {:stop, :normal, state}
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  def handle_info({:upstream_timeout, {server, _} = upstream}, %State{} = state) do
    :ok = logging(:warn, {:upstream_timeout, upstream})
    :ok = Metrics.failed(server)
    {:stop, :normal, state}
  end

  def handle_info({:upstream_down, {server, _} = upstream}, state) do
    :ok = logging(:warn, {:upstream_down, upstream})
    :ok = Metrics.failed(server)
    maybe_done(upstream, state)
  end

  def handle_info(
        {:upstream_reply, {server, _} = upstream, packet},
        %State{reply_sent: false} = state
      ) do
    tdiff = :timer.now_diff(:os.timestamp(), state.start_timestamp)
    :ok = logging(:debug, {:upstream_reply, upstream, tdiff})
    :ok = Metrics.latency(server, tdiff)
    _ = do_callback(packet, state)
    maybe_done(upstream, %{state | reply_sent: true})
  end

  def handle_info(
        {:upstream_reply, {server, _} = upstream, _packet},
        %State{reply_sent: true} = state
      ) do
    tdiff = :timer.now_diff(:os.timestamp(), state.start_timestamp)
    :ok = logging(:debug, {:upstream_reply, upstream, tdiff})
    :ok = Metrics.latency(server, tdiff)
    maybe_done(upstream, state)
  end

  def handle_info(info, state) do
    :ok = Logger.warn(fn -> "Unhandled info received: #{inspect(info)}" end)
    {:noreply, state}
  end

  # private functions

  @spec maybe_done({:inet.ip4_address(), pid()}, State.t()) ::
          {:noreply, State.t()} | {:stop, :normal, State.t()}
  defp maybe_done(upstream, state) do
    case List.keydelete(state.outstandings, upstream, 0) do
      [] ->
        {:stop, :normal, %{state | outstandings: []}}

      outstandings ->
        tref =
          state
          |> timeleft_ms()
          |> update_timer(:timeout, state)

        {:noreply, %{state | timer_ref: tref, outstandings: outstandings}}
    end
  end

  @spec send_formerr(State.t()) :: :ok
  defp send_formerr(%State{dns_message: msg} = state) do
    msg
    |> dns_message(rc: @dns_rcode_formerr)
    |> :dns.encode_message()
    |> do_callback(state)
  end

  @spec send_servfail(State.t()) :: :ok
  defp send_servfail(%State{dns_message: msg} = state) do
    msg
    |> dns_message(rc: @dns_rcode_servfail)
    |> :dns.encode_message()
    |> do_callback(state)
  end

  @spec timeleft_ms(State.t()) :: integer()
  defp timeleft_ms(state) do
    now = :erlang.monotonic_time()
    timeout = now - state.send_query_time
    :erlang.convert_time_unit(timeout, :native, :milli_seconds)
  end

  @spec update_timer(integer(), term(), State.t()) :: reference()
  defp update_timer(time, msg, %State{timer_ref: tref}) do
    :ok = cancel_timer(tref)
    Process.send_after(self(), msg, time)
  end

  @spec cancel_timer(reference() | any()) :: :ok
  defp cancel_timer(ref) when is_reference(ref) do
    _ = Process.cancel_timer(ref)
    :ok
  end

  defp cancel_timer(_), do: :ok

  @spec do_callback(binary(), State.t()) :: :ok
  defp do_callback(packet, %State{reply_fun: fun}) when is_function(fun),
    do: fun.(packet)

  defp do_callback(packet, %State{reply_fun: {fun, args}}),
    do: apply(fun, args ++ [packet])

  @spec logging(Logger.level(), term()) :: :ok
  defp logging(level, key), do: Logger.log(level, log_descr(key))

  @spec log_descr(
          {:decode_error, binary()}
          | :no_upstreams_available
          | {:upstream_reply, {:inet.ip4_address(), :inet.port_number()}, pid()}
          | {:upstream_timeout, {:inet.ip4_address(), :inet.port_number()}, pid()}
          | {:query_timeout, String.t()}
        ) :: function()
  defp log_descr({:decode_error, packet}),
    do: fn -> "Undecodable packet given: packet = #{inspect(packet)}" end

  defp log_descr(:no_upstreams_available),
    do: fn -> "No upstream available" end

  defp log_descr({:upstream_reply, {{ip, port}, _}, tdiff}),
    do: fn -> "Received reply from #{:inet.ntoa(ip)}:#{port} in #{tdiff / 1000} msec" end

  defp log_descr({:upstream_down, {{ip, port}, _}}),
    do: fn -> "Upstream #{:inet.ntoa(ip)}:#{port} DOWN" end

  defp log_descr({:upstream_timeout, {{ip, port}, _}}),
    do: fn -> "Upstream #{:inet.ntoa(ip)}:#{port} TIMEOUT" end

  defp log_descr({:query_timeout, name}),
    do: fn -> "Query Timeout name = #{name}" end
end