defmodule NFQ.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    NFQ.Supervisor.start_link()
  end
end
