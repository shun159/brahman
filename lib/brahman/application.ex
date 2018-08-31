defmodule Brahman.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    {:ok, _pid} = Brahman.Supervisor.start_link()
  end
end
