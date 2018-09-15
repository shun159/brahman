defmodule MetricTest do
  use ExUnit.Case, async: true

  setup_all do
    {:ok, _} = Application.ensure_all_started(:brahman)

    on_exit(fn ->
      Application.stop(:brahman)
    end)
  end

  describe "Brahman.Metrics.Counters.get_failed/1" do
    test "with before failed/1" do
      server = {{8, 8, 8, 8}, 53}
      value = Brahman.Metrics.Counters.get_failed(server)
      assert value == 0
    end

    test "with after failed/1" do
      server = {{8, 8, 8, 8}, 53}
      :ok = Brahman.Metrics.Counters.failed(server)
      value = Brahman.Metrics.Counters.get_failed(server)
      assert value in 0..1
    end
  end

  describe "Brahman.Metrics.Counters.get_success/1" do
    test "with before success/1" do
      server = {{8, 8, 8, 8}, 53}
      value = Brahman.Metrics.Counters.get_success(server)
      assert value == 0
    end

    test "with after success/1" do
      server = {{8, 8, 8, 8}, 53}
      :ok = Brahman.Metrics.Counters.success(server)
      value = Brahman.Metrics.Counters.get_success(server)
      assert value in 0..1
    end
  end

  describe "Brahman.Metrics.Counters.get_latency/1" do
    test "with before latency/1" do
      server = {{8, 8, 8, 8}, 53}
      value = Brahman.Metrics.Counters.get_latency(server)
      assert value == 0
    end

    test "with after latency/1" do
      server = {{8, 8, 8, 8}, 53}
      :ok = Brahman.Metrics.Counters.latency(server, 500)
      value = Brahman.Metrics.Counters.get_latency(server)
      assert value in 0..1
    end
  end

  describe "Brahman.Metrics.Counters.get_selected/1" do
    test "with before selected/1" do
      server = {{8, 8, 8, 8}, 53}
      value = Brahman.Metrics.Counters.get_selected(server)
      assert value == 0
    end

    test "with after selected/1" do
      server = {{8, 8, 8, 8}, 53}
      :ok = Brahman.Metrics.Counters.selected(server)
      value = Brahman.Metrics.Counters.get_selected(server)
      assert value in 0..1
    end
  end
end
