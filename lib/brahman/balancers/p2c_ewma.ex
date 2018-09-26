defmodule Brahman.Balancers.P2cEwma do
  @moduledoc """
  Balancer/Observer based on P2C+PeakEWMA algorithm
  """

  use GenServer
  use Brahman.Logging

  require Record
  require Logger

  alias Brahman.Metrics.Ewma

  Record.defrecord(
    :upstream,
    ip_port: {{0, 0, 0, 0}, 0},
    ewma: %Ewma.Peak{},
    total_successes: 0,
    total_failures: 0,
    consecutive_failures: 0,
    max_failure_threshold: 5,
    last_failure_time: 0,
    failure_backoff: 10000 * 1.0e6
  )

  @table_name :observer

  @type ip_port :: {:inet.ip4_address(), :inet.port_number()}

  # API functionst

  @spec set_pending(ip_port()) :: :ok
  def set_pending(upstream),
    do: GenServer.cast(__MODULE__, {:set_pending, upstream})

  @spec observe(number(), ip_port(), boolean()) :: :ok
  def observe(measurement, upstream, success),
    do: GenServer.cast(__MODULE__, {:observe, measurement, upstream, success})

  @doc """
  Uses the power of two choices algorithm as described in:
  Michael Mitzenmacher. 2001. The Power of Two Choices in Randomized
  Load Balancing. IEEE Trans. Parallel Distrib. Syst. 12,
  10 (October 2001), 1094-1104.
  """
  @spec pick_upstream([ip_port()]) :: {:ok, ip_port()} | {:error, term()}
  def pick_upstream(upstreams = [_ | _]),
    do: do_pick_backend(upstreams)

  def pick_upstream(_upstream),
    do: {:error, :no_upstream_available}

  @doc """
  Starts the server
  """
  @spec start_link() :: GenServer.on_start()
  def start_link,
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  # GenServer callback functions

  def init(_args) do
    :ok = Logger.debug("Start with P2C+PeakEWMA balancing mode")
    {:ok, nil, {:continue, :init}}
  end

  def handle_continue(:init, state) do
    _ = make_seed()
    _ = create_table()
    {:noreply, state}
  end

  def handle_continue(_continuation, state) do
    {:noreply, state}
  end

  def handle_call({:pick_upstream, upstreams}, _from, state) do
    {:reply, do_pick_backend(upstreams), state}
  end

  def handle_call(_request, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast({:set_pending, upstream}, state) do
    true =
      upstream
      |> get_ewma()
      |> increment_pending()
      |> insert_ewma()

    {:noreply, state}
  end

  def handle_cast({:observe, measurement, upstream, success}, state) do
    :ok = logging(:debug, {:observing_success, success, measurement})

    entry0 = get_ewma(upstream)

    ewma =
      entry0
      |> upstream(:ewma)
      |> Ewma.add(measurement)
      |> decrement_pending()

    true =
      entry0
      |> track_success(success)
      |> upstream(ewma: ewma)
      |> insert_ewma()

    {:noreply, state}
  end

  def handle_cast(_request, state) do
    {:noreply, state}
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  # Private functions

  @spec do_pick_backend([ip_port()]) :: {:ok, record(:upstream)}
  defp do_pick_backend(upstreams) do
    entries = Enum.map(upstreams, &get_ewma/1)
    {up, down} = Enum.split_with(entries, &is_open?/1)

    choices =
      case up do
        [] -> down
        _ -> up
      end

    case choices do
      [choice] ->
        {:ok, upstream(choice, :ip_port)}

      _ ->
        choice =
          choices
          |> Enum.shuffle()
          |> Enum.take(2)
          |> Enum.min_by(fn upstream(ewma: ewma) -> Ewma.value(ewma) end)

        {:ok, upstream(choice, :ip_port)}
    end
  end

  @spec is_open?(record(:upstream)) :: boolean()
  defp is_open?(
         upstream(
           consecutive_failures: fails,
           max_failure_threshold: thres
         )
       )
       when fails < thres do
    true
  end

  defp is_open?(upstream(last_failure_time: last, failure_backoff: backoff)) do
    :nano_seconds
    |> :erlang.monotonic_time()
    |> Kernel.-(last)
    |> Kernel.>(backoff)
  end

  @spec increment_pending(record(:upstream)) :: record(:upstream)
  defp increment_pending(upstream = upstream(ewma: ewma)),
    do: upstream(upstream, ewma: %{ewma | pending: ewma.pending + 1})

  @spec decrement_pending(%Ewma.Peak{pending: non_neg_integer()}) :: %Ewma.Peak{}
  defp decrement_pending(%Ewma.Peak{pending: pending} = ewma) when pending > 0,
    do: %{ewma | pending: pending - 1}

  defp decrement_pending(%Ewma.Peak{} = ewma), do: ewma

  @spec track_success(record(:upstream), boolean()) :: record(:upstream)
  defp track_success(upstream(total_successes: total) = entry, true),
    do: upstream(entry, total_successes: total + 1, consecutive_failures: 0)

  defp track_success(
         upstream(
           total_failures: total_fails,
           consecutive_failures: cons_fails
         ) = entry,
         false
       ) do
    upstream(
      entry,
      total_failures: total_fails + 1,
      consecutive_failures: cons_fails + 1,
      last_failure_time: :erlang.monotonic_time(:nano_seconds)
    )
  end

  @spec get_ewma(ip_port()) :: record(:upstream)
  defp get_ewma(upstream) do
    case :ets.lookup(@table_name, upstream) do
      [] ->
        upstream(ip_port: upstream)

      [entry | _] ->
        entry
    end
  end

  @spec insert_ewma(record(:upstream)) :: true
  defp insert_ewma(entry), do: :ets.insert(@table_name, entry)

  @spec create_table() :: :observer
  defp create_table,
    do: :ets.new(@table_name, [:named_table, {:keypos, upstream(:ip_port) + 1}])

  @spec make_seed() :: :rand.state()
  defp make_seed do
    :rand.seed(
      :exsplus,
      {
        :erlang.phash2([Node.self()]),
        :erlang.monotonic_time(),
        :erlang.unique_integer()
      }
    )
  end
end
