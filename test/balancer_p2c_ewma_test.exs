defmodule BalancerP2cEwmaTest do
  use ExUnit.Case, async: false

  setup_all do
    {:ok, _} = Application.ensure_all_started(:brahman)

    on_exit(fn ->
      Application.stop(:brahman)
    end)
  end

  describe "Brahman.Balancers.P2cEwma.set_pending/1" do
    test "with upstream" do
      server = {{8, 8, 8, 8}, 53}
      :ok = Brahman.Balancers.P2cEwma.set_pending(server)
    end
  end

  describe "Brahman.Balancers.P2cEwma.observe/3" do
    test "with high latency" do
      msec = :timer.seconds(1)
      upstream = {{8, 8, 8, 8}, 53}
      success = true

      :ok = Brahman.Balancers.P2cEwma.set_pending(upstream)
      :ok = Brahman.Balancers.P2cEwma.observe(msec, upstream, success)
    end
  end

  describe "Brahman.Balancers.P2cEwma.pick_upstream/1" do
    test "with upstreams" do
      servers = [
        {{8, 8, 8, 8}, 53},
        {{1, 1, 1, 1}, 53}
      ]

      {:ok, upstream} = Brahman.Balancers.P2cEwma.pick_upstream(servers)
      assert upstream == {{1, 1, 1, 1}, 53}
    end
  end
end
