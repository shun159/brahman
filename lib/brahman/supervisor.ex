defmodule Brahman.Supervisor do
  @moduledoc """
  Brahman Top Level supervisor
  """

  use Supervisor

  @dns_forwarder_sup_spec %{
    id: Brahman.Dns,
    start: {Brahman.Dns, :start_link, []},
    restart: :permanent,
    shutdown: :infinity,
    type: :supervisor,
    modules: [Brahman.Dns]
  }

  @p2c_balancer %{
    id: Brahman.Balancers.P2cEwma,
    start: {Brahman.Balancers.P2cEwma, :start_link, []},
    restart: :permanent,
    shutdown: 5000,
    type: :worker,
    modules: [Brahman.Balancers.P2cEwma]
  }

  @children [@p2c_balancer, @dns_forwarder_sup_spec]

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    Supervisor.init(@children, strategy: :one_for_one)
  end
end
