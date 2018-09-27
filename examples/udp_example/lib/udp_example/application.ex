defmodule UdpExample.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    UdpExample.Supervisor.start_link()
  end
end
