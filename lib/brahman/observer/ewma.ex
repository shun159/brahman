defmodule Brahman.Observer.EWMA do
  @moduledoc false

  use GenServer

  require Record
  require Logger

  Record.defrecord(
    :ewma,
    cost: 0,
    stamp: :erlang.monotonic_time(:nano_seconds),
    penalty: 1.0e307,
    pending: 0,
    decay: 10.0e9
  )

  Record.defrecord(
    :tracking,
    total_successes: 0,
    total_failures: 0,
    consecutive_failures: 0,
    failure_thres: 5,
    failure_backoff: 10_000,
    last_failure_time: 0
  )

  Record.defrecord(
    :upstream,
    ip_port: nil,
    tracking: nil,
    ewma: nil
  )

  @table_name :observer

  @type ip_port :: {:inet.ip4_address(), :inet.port_number()}

  # API functions

  def observe(measurement, ip_port, success) do
    GenServer.cast(__MODULE__, {:observe, {measurement, ip_port, success}})
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # GenServer callback functions

  def init(_args) do
    :ok = Logger.info("EWMA observer starting")
    {:ok, nil, {:continue, :init}}
  end

  def handle_continue(:init, state) do
    _ = make_seed()
    :observer = create_table()
    {:noreply, state}
  end

  def handle_call(_request, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast({:observe, {measurement, ip_port, success}}, state) do
    :ok = logging(:debug, {:observing_success, success, measurement})

    ip_port
    |> get_ewma()
    |> calculate_ewma(measurement)
    |> decrement_pending()

    {:noreply, state}
  end

  def handle_cast(_request, state) do
    {:noreply, state}
  end

  # Private functions

  # NOTE: for this functions
  #
  # Records a new value in the exponentially weighted moving average.
  # This type of algorithm shows up all over the place in load balancer code,
  # and here we're porting Twitter's P2CBalancerPeakEwma which factors time into our moving average.
  # This is nice because we can bias decisions more with recent information,
  # allowing us to not have to assume a constant request rate to a particular service.
  #
  # Calculate the exponential weighted moving average of our
  # round trip time. It isn't exactly an ewma, but rather a
  # "peak-ewma", since `cost` is hyper-sensitive to latency peaks.
  # Note, because the frequency of observations represents an
  # unevenly spaced time-series[1], we consider the time between
  # observations when calculating our weight.
  # [1] http://www.eckner.com/papers/ts_alg.pdf
  #
  defp calculate_ewma(upstream(ewma: ewma), val) do
    now = :erlang.monotonic_time(:nano_seconds)
    new_cost = calculate_ewma_1(val, ewma, now)
    ewma(ewma, cost: new_cost, stamp: now)
  end

  defp calculate_ewma_1(ewma(cost: cost, stamp: stamp, decay: decay), val, now) do
    now
    |> Kernel.-(stamp)
    |> Kernel.max(0)
    |> Kernel.-()
    |> Kernel./(decay)
    |> :math.exp()
    |> calculate_ewma_2(val, cost)
  end

  defp calculate_ewma_2(_weight, val, cost) when val > cost, do: val

  defp calculate_ewma_2(weight, val, cost), do: (cost * weight) + (val * (1.0 - weight))

  defp decrement_pending(ewma = ewma(pending: pending)) when pending > 0 do
    ewma(ewma, pending: pending - 1)
  end

  defp decrement_pending(ewma) do
    :ok = logging(:warn, :pending_connection_is_zero)
    ewma
  end

  @spec get_ewma(ip_port()) :: record(:upstream)
  defp get_ewma(ip_port) do
    case :ets.lookup(@table_name, ip_port) do
      [] ->
        upstream(ip_port: ip_port, tracking: tracking(), ewma: ewma())

      [upstream() = entry] ->
        entry
    end
  end

  @spec logging(Logger.level(), term()) :: :ok
  defp logging(level, key), do: Logger.log(level, log_descr(key))

  @spec log_descr(tuple() | atom()) :: function()
  defp log_descr({:observing_success, success, measurement}),
    do: fn -> "Observing connection success: #{success} with time of #{measurement} ms" end

  defp log_descr(:pending_connection_is_zero),
    do: fn -> "Call to decrement connections for backend when pending connections == 0" end

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
