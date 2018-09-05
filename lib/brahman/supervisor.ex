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

  @children [@dns_forwarder_sup_spec]

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    Supervisor.init(@children, strategy: :one_for_one)
  end
end
