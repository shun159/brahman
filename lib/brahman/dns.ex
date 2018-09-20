defmodule Brahman.Dns do
  @moduledoc false

  use Supervisor

  @handler_spec %{
    id: Brahman.Dns.Handler,
    start: {Brahman.Dns.Handler, :start_link, []},
    restart: :permanent,
    shutdown: 5000,
    type: :worker,
    modules: [Brahman.Dns.Handler]
  }

  @zone_api_spec %{
    id: Brahman.Dns.Zones,
    start: {Brahman.Dns.Zones, :start_link, []},
    shutdown: 5000,
    type: :worker,
    modules: [Brahman.Dns.Zones]
  }

  @forwarder_sup_spec %{
    id: Brahman.Dns.ForwarderSup,
    start: {Brahman.Dns.ForwarderSup, :start_link, []},
    restart: :permanent,
    shutdown: :infinity,
    type: :supervisor,
    modules: [Brahman.Dns.ForwarderSup]
  }

  @children [@handler_spec, @forwarder_sup_spec, @zone_api_spec]

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    Supervisor.init(@children, strategy: :one_for_one)
  end
end
