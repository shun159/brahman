defmodule BrahmanTest do
  use ExUnit.Case
  doctest Brahman

  test "greets the world" do
    assert Brahman.hello() == :world
  end
end
