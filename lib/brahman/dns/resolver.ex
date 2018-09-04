defmodule Brahman.Dns.Resolver do
  @moduledoc """
  DNS Resolver worker
  """

  use GenServer, restart: :temporary, shutdown: 5000

  require Logger

  defmodule State do
    @moduledoc false

    defstruct [:upstream, :data, :parent, :mon_ref, :socket]

    @type t :: %State{
            upstream: {:inet.ip4_address(), :inet.port_number()} | nil,
            data: map() | nil,
            parent: pid() | nil,
            mon_ref: reference() | nil,
            socket: :gen_udp.socket() | nil
          }
  end

  @udp_sock_opt [
    {:reuseaddr, true},
    {:active, :once},
    :binary
  ]

  @typep upstream() :: {:inet.ip4_address(), :inet.port_number()}

  # API functions

  @spec resolve([upstream()], map()) :: {:error, term()} | [{upstream(), pid()}]
  def resolve(upstreams, data) when is_list(upstreams) do
    start_resolvers(upstreams, data)
  end

  @spec resolve(upstream(), map()) :: {:error, term()} | {upstream(), pid()}
  def resolve(upstream, data) when is_tuple(upstream) do
    case GenServer.start(__MODULE__, [upstream, data, self()]) do
      {:error, _reason} = e -> e
      {:ok, pid} -> {upstream, pid}
    end
  end

  # GenServer callback functions

  def init([upstream, data, parent]) do
    _ = Process.flag(:trap_exit, true)
    state = %State{upstream: upstream, data: data, parent: parent}
    {:ok, state, {:continue, :init}}
  end

  @spec handle_continue(:init | term(), State.t()) ::
          {:noreply, State.t()} | {:stop, :normal, State.t()}
  def handle_continue(:init, state0) do
    case try_send_packet(state0) do
      {:error, state} ->
        :ok = notify_result(:down, state)
        {:stop, :normal, state}

      {:ok, state1} ->
        state = init_kill_trigger(state1)
        {:noreply, state}
    end
  end

  def handle_continue(_continue, state) do
    {:noreply, state}
  end

  @spec handle_info(:timeout, State.t()) :: {:stop, :normal, State.t()}
  def handle_info(:timeout, %State{upstream: {ip, port}} = state) do
    :ok = Logger.debug("Timeout in query forwarding: #{:inet.ntoa(ip)}:#{port}")
    :ok = notify_result(:timeout, state)
    {:stop, :normal, state}
  end

  @spec handle_info({:DOWN, :gen_udp.socket(), any(), any(), term()}, State.t()) ::
          {:stop, :normal, State.t()}
  def handle_info({:DOWN, mon_ref, _, _pid, reason}, %{mon_ref: mon_ref} = state) do
    {:stop, reason, state}
  end

  @spec handle_info({:udp, :gen_udp.socket(), tuple(), integer(), binary()}, State.t()) ::
          {:stop, :normal, State.t()}
  def handle_info(
        {:udp, socket, ip, port, reply},
        %State{upstream: {ip, port}, socket: socket} = state
      ) do
    :ok = notify_result({:reply, reply}, state)
    {:stop, :normal, state}
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  @spec terminate(any(), %State{socket: :gen_udp.socket(), upstream: upstream()}) ::
          {:shutdown, State.t()}
  def terminate(_reason, %State{socket: socket, upstream: {ip, port}} = state) do
    :ok = Logger.debug("Closing socket for: #{:inet.ntoa(ip)}:#{port}")
    :ok = if socket, do: :gen_udp.close(socket), else: :ok
    {:shutdown, state}
  end

  # private functions

  @spec try_send_packet(State.t()) :: {:ok, State.t()} | {:error, term()}
  defp try_send_packet(state) do
    state
    |> open_socket()
    |> send_packet()
  end

  @spec init_kill_trigger(State.t()) :: State.t()
  defp init_kill_trigger(state) do
    _tref = schedule_timeout()
    monitor_parent(state)
  end

  @spec open_socket(State.t()) :: {:ok, State.t()} | {:error, term()}
  defp open_socket(state) do
    case :gen_udp.open(0, @udp_sock_opt) do
      {:error, reason} ->
        :ok = Logger.debug("Failed to open socket: reason = #{inspect(reason)}")
        {:error, state}

      {:ok, socket} ->
        {:ok, %{state | socket: socket}}
    end
  end

  @spec send_packet({:ok, State.t()} | {:error, State.t()}) ::
          {:ok, State.t()} | {:error, State.t()}
  defp send_packet({:error, _reason} = error), do: error

  defp send_packet({:ok, %State{data: data, socket: socket, upstream: {ipaddr, port}} = state}) do
    case :gen_udp.send(socket, ipaddr, port, data.dns_packet) do
      {:error, reason} ->
        :ok = Logger.debug("Failed to send packet: reason = #{inspect(reason)}")
        {:error, %{state | socket: socket}}

      :ok ->
        {:ok, %{state | socket: socket}}
    end
  end

  @spec start_resolvers([upstream()], map()) :: [{upstream(), pid()}]
  defp start_resolvers(upstreams, data),
    do: start_resolvers(upstreams, [], data)

  @spec start_resolvers([upstream()], list(), map()) :: [{upstream(), pid()}]
  defp start_resolvers([], acc, _data), do: acc

  defp start_resolvers([upstream | rest], acc, data) do
    case resolve(upstream, data) do
      {:error, reason} ->
        :ok = Logger.debug("Failed to start worker: reason = #{inspect(reason)}")
        start_resolvers(rest, acc, data)

      {upstream, pid} = result when is_tuple(upstream) and is_pid(pid) ->
        start_resolvers(rest, [result | acc], data)
    end
  end

  @spec monitor_parent(State.t()) :: State.t()
  defp monitor_parent(state), do: %{state | mon_ref: Process.monitor(state.parent)}

  @spec schedule_timeout() :: reference()
  defp schedule_timeout, do: Process.send_after(self(), :timeout, 5000)

  @spec notify_result(:down | :timeout | {:reply, binary()}, State.t()) :: :ok
  defp notify_result(:down, state),
    do: Process.send(state.parent, {:upstream_down, {state.upstream, self()}}, [])

  defp notify_result(:timeout, state),
    do: Process.send(state.parent, {:upstream_timeout, {state.upstream, self()}}, [])

  defp notify_result({:reply, reply}, state),
    do: Process.send(state.parent, {:upstream_reply, {state.upstream, self()}, reply}, [])
end
