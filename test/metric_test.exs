defmodule MetricTest do
  use ExUnit.Case

  setup_all do
    {:ok, _} = Application.ensure_all_started(:brahman)

    on_exit(fn ->
      Application.stop(:brahman)
    end)
  end

  describe "Brahman.Dns.Metrics.get_failed/1" do
    test "with before failed/1" do
      server = {{8, 8, 8, 8}, 53}
      {:ok, value} = Brahman.Dns.Metrics.get_failed(server)
      assert value == 0
    end

    test "with after failed/1" do
      server = {{8, 8, 8, 8}, 53}
      :ok = Brahman.Dns.Metrics.failed(server)
      {:ok, value} = Brahman.Dns.Metrics.get_failed(server)
      assert value in 0..1
    end
  end

  describe "Brahman.Dns.Metrics.get_success/1" do
    test "with before success/1" do
      server = {{8, 8, 8, 8}, 53}
      {:ok, value} = Brahman.Dns.Metrics.get_success(server)
      assert value == 0
    end

    test "with after success/1" do
      server = {{8, 8, 8, 8}, 53}
      :ok = Brahman.Dns.Metrics.success(server)
      {:ok, value} = Brahman.Dns.Metrics.get_success(server)
      assert value in 0..1
    end
  end

  describe "Brahman.Dns.Metrics.get_latency/1" do
    test "with before latency/1" do
      server = {{8, 8, 8, 8}, 53}
      {:ok, value} = Brahman.Dns.Metrics.get_latency(server)
      assert value == 0
    end

    test "with after latency/1" do
      server = {{8, 8, 8, 8}, 53}
      :ok = Brahman.Dns.Metrics.latency(server, 500)
      {:ok, value} = Brahman.Dns.Metrics.get_latency(server)
      assert value in 0..1
    end
  end
end
