defmodule Brahman.Observer.EWMA do
  @moduledoc """
  Balancer/Observer based on P2C EWMA algorithm
  """

  use GenServer
  use Brahman.Logging

  require Record
  require Logger

  for {name, fields} <- Record.extract_all(from: "include/brahman.hrl") do
    Record.defrecord(name, fields)
  end

  @table_name :observer

  @type ip_port :: {:inet.ip4_address(), :inet.port_number()}

  # API functions

  @spec observe(float(), ip_port(), boolean()) :: :ok
  def observe(measurement, ip_port, success),
    do: GenServer.cast(__MODULE__, {:observe, {measurement, ip_port, success}})

  @spec set_pending(ip_port()) :: :ok
  def set_pending(ip_port),
    do: GenServer.cast(__MODULE__, {:set_pending, ip_port})

  @doc """
  Uses the power of two choices algorithm as described in:
  Michael Mitzenmacher. 2001. The Power of Two Choices in Randomized
  Load Balancing. IEEE Trans. Parallel Distrib. Syst. 12,
  10 (October 2001), 1094-1104.
  """
  @spec pick_upstream([ip_port()]) :: {:ok, record(:upstream)} | {:error, term()}
  def pick_upstream(upstreams = [_ | _]),
    do: GenServer.call(__MODULE__, {:pick_upstream, upstreams}, 1000)

  def pick_upstream(_upstream),
    do: {:error, :no_upstream_available}

  @spec get_ewma(ip_port()) :: record(:upstream)
  def get_ewma(upstream), do: do_get_ewma(upstream)

  @doc """
  Starts the server
  """
  @spec start_link() :: GenServer.on_start()
  def start_link,
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  # GenServer callback functions

  def init(_args) do
    :ok = Logger.info("EWMA observer starting")
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
    result = do_pick_upstream(upstreams)
    {:reply, result, state}
  end

  def handle_call(_request, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast({:observe, {measurement, ip_port, success}}, state) do
    :ok = logging(:debug, {:observing_success, success, measurement})
    {:noreply, state}
  end

  def handle_cast(_request, state) do
    {:noreply, state}
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  # Private functions

  @spec do_pick_upstream([ip_port]) :: record(:upstream)
  defp do_pick_upstream(upstreams) do
    upstreams
    |> split_by_criteria()
    |> pick_upstreams()
    |> select_based_on_cost()
  end

  @spec split_by_criteria([record(:upstream)]) :: {[record(:upstream)], [record(:upstream)]}
  defp split_by_criteria(upstreams) do
    upstreams
    |> Enum.map(&do_get_ewma/1)
    |> Enum.split_with(&in_failure_threshold?(upstream(&1, :tracking)))
  end

  @spec pick_upstreams({[record(:upstream)], [record(:upstream)]}) :: [
          record(:upstream)
        ]
  defp pick_upstreams({[], down}), do: down

  defp pick_upstreams({up, _down}), do: up

  @spec select_based_on_cost([record(:upstream)]) :: {:ok, record(:upstream)}
  defp select_based_on_cost([choice]), do: {:ok, choice}

  defp select_based_on_cost(choices) do
    choice =
      choices
      |> Enum.take_random(2)
      |> Enum.min_by(&calculate_cost/1)

    {:ok, choice}
  end

  # Calculate the exponential weighted moving average of our
  # round trip time. It isn't exactly an ewma, but rather a
  # "peak-ewma", since `cost` is hyper-sensitive to latency peaks.
  # Note, because the frequency of observations represents an
  # unevenly spaced time-series[1], we consider the time between
  # observations when calculating our weight.
  #
  @spec calculate_ewma(float(), record(:ewma)) :: record(:ewma)
  defp calculate_ewma(val, ewma = ewma(cost: cost, stamp: stamp, decay: decay)) do
    now = :erlang.monotonic_time(:nano_seconds)

    weight =
      now
      |> Kernel.-(stamp)
      |> Kernel.max(0)
      |> Kernel.-()
      |> Kernel./(decay)
      |> :math.exp()

    new_cost = if val > cost, do: val, else: cost * weight + val * (1.0 - weight)

    ewma(ewma, stamp: now, cost: new_cost)
  end

  # Returns the cost of this according to the EWMA algorithm.
  @spec calculate_cost(record(:upstream)) :: float()
  defp calculate_cost(upstream(ewma: ewma)) do
    ewma(cost: cost, pending: pending, penalty: penalty) = calculate_ewma(0.0, ewma)

    case {:erlang.float(cost), :erlang.float(penalty)} do
      {0.0, 0.0} ->
        1

      {0.0, _} ->
        penalty

      _ ->
        cost * (pending + 1)
    end
  end

  @spec do_get_ewma(ip_port()) :: record(:upstream)
  defp do_get_ewma(upstream) do
    case :ets.lookup(@table_name, upstream) do
      [] -> upstream(ip_port: upstream)
      [entry] -> entry
    end
  end

  # Determines if this backend is suitable for receiving packet, based
  # on whether the failure threshold has been crossed.
  @spec in_failure_threshold?(record(:tracking)) :: boolean()
  defp in_failure_threshold?(
         tracking(
           consecutive_failures: fails,
           max_failure_threshold: thres
         )
       )
       when fails < thres do
    true
  end

  defp in_failure_threshold?(
         tracking(
           last_failure_time: last,
           failure_backoff: backoff
         )
       ) do
    now = :erlang.monotonic_time(:nano_seconds)
    now - last > backoff
  end

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
