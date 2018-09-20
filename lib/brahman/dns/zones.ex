defmodule Brahman.Dns.Zones do
  @moduledoc """
  Module for CRUD operations to DNS zone
  """

  use GenServer

  require Logger

  @spec start_link() :: GenServer.on_start()
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    :ok = Logger.info("starting zone API server")
    {:ok, %{}}
  end
end
