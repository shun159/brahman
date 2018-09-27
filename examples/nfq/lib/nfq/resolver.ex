defmodule NFQ.Resolver do
  @moduledoc false

  use GenServer

  def process(pid, payload) do
    GenServer.call(pid, {:process, payload}, 5000)
  catch
    _, _ -> process(pid, payload)
  end

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_init_args) do
    {:ok, %{from: nil}}
  end

  def handle_call({:process, payload}, from, state) do
    :ok = Brahman.Dns.Handler.handle(payload, {&Kernel.send/2, [self()]})
    {:noreply, %{state | from: from}}
  end

  def handle_call(_request, _from, state) do
    {:reply, :ok, state}
  end

  def handle_info(packet, state) when is_binary(packet) do
    GenServer.reply(state.from, {:ok, packet})
    {:noreply, %{state | from: nil}}
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end
end
