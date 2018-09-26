defmodule NFQ.Supervisor do
  @moduledoc false

  @nfq_handler %{
    id: NFQ.Handler,
    start: {NFQ.Handler, :start_link, []},
    restart: :permanent,
    shutdown: 5000,
    type: :worker,
    modules: [NFQ.Handler]
  }

  @children [@nfq_handler]

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    Supervisor.init(@children, strategy: :one_for_one)
  end
end
