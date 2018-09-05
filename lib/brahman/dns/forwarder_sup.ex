defmodule Brahman.Dns.ForwarderSup do
  @moduledoc """
  DNS forwarder supervisor
  """

  # API functions

  @spec start_link() :: Supervisor.on_start()
  def start_link do
    ConsumerSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  # ConsumerSupervisor callback functions

  def init(_args) do
    children = [Brahman.Dns.Forwarder]

    ConsumerSupervisor.init(
      children,
      strategy: :one_for_one,
      subscribe_to: [{Brahman.Dns.Handler, max_demand: 10000}]
    )
  end
end
