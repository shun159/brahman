defmodule NetlinkTest do
  use ExUnit.Case
  doctest Netlink

  test "greets the world" do
    assert Netlink.hello() == :world
  end
end
