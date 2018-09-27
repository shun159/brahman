defmodule UdpExampleTest do
  use ExUnit.Case
  doctest UdpExample

  test "greets the world" do
    assert UdpExample.hello() == :world
  end
end
