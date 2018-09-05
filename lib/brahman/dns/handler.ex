defmodule Brahman.Dns.Handler do
  use GenStage

  require Logger

  # API functions

  @type handler_fun :: (binary() -> :ok) | {(... -> :ok), [term()]}

  @spec handle(binary(), handler_fun()) :: :ok
  def handle(query, handler_fn) do
    GenStage.cast(__MODULE__, {:handle, query, handler_fn})
  end

  # GenStage callback functions

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    :ok = Logger.info("DNS Handler started")
    {:producer, %{}}
  end

  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  def handle_call(_request, _from, state) do
    {:reply, :ok, [], state}
  end

  def handle_cast({:handle, query, handler_fn}, state) do
    {:noreply, [query, handler_fn], state}
  end

  def handle_cast(_msg, state) do
    {:noreply, [], state}
  end

  def handle_info(_info, state) do
    {:noreply, [], state}
  end
end
