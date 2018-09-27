defmodule UdpExample.Supervisor do
  @moduledoc false

  @udp_server %{
    id: UdpExample.Server,
    start: {UdpExample.Server, :start_link, []},
    restart: :permanent,
    shutdown: 5000,
    type: :worker,
    modules: [UdpExample.Server]
  }

  @children [@udp_server]

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    Supervisor.init(@children, strategy: :one_for_one)
  end
end
