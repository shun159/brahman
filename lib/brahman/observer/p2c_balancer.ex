defmodule Brahman.Observer.P2CBalancer do
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

  # API functionst

  @spec observe(float(), ip_port(), boolean()) :: :ok
  def observe(measurement, ip_port, success),
    do: GenServer.cast(__MODULE__, {:observe, {measurement, ip_port, success}})

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
  def get_ewma(upstream), do: :ok

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

  def handle_call({:pick_upstream, _upstreams}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call(_request, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast({:observe, {measurement, _ip_port, success}}, state) do
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
