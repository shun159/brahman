defmodule Brahman.Dns.Metrics do
  @moduledoc """
  DNS metric instrumentations
  """

  use Elixometer

  # counters

  @spec failed({:inet.ip4_address(), :inet.port_number()}) :: :ok
  def failed(server),
    do: update_spiral("dns.#{inspect(server)}.failed", 1)

  @spec ignored(non_neg_integer()) :: :ok
  def ignored(num_of_query),
    do: update_counter("dns.ignored", num_of_query)

  @spec success({:inet.ip4_address(), :inet.port_number()}) :: :ok
  def success(server),
    do: update_counter("dns.#{inspect(server)}.successes", 1)

  @spec latency({:inet.ip4_address(), :inet.port_number()}, non_neg_integer()) :: :ok
  def latency(server, timediff),
    do: update_histogram("dns.#{inspect(server)}.latency", timediff)

  @spec no_upstreams() :: :ok
  def no_upstreams, do: update_spiral("dns.no_upstreams", 1)

  @spec selected({:inet.ip4_address(), :inet.port_number()}) :: :ok
  def selected(server),
    do: update_counter("dns.#{inspect(server)}.selected", 1)

  @spec get_latency({:inet.ip4_address(), :inet.port_number()}) :: non_neg_integer()
  def get_latency(server) do
    case get_metric_value("brahman.histograms.dns.#{inspect(server)}.latency") do
      {:error, _} ->
        0

      {:ok, metrics} ->
        metrics[:median]
    end
  end

  @spec get_ignored() :: non_neg_integer()
  def get_ignored do
    case get_metric_value("brahman.counters.dns.ignored") do
      {:error, _} ->
        0

      {:ok, metrics} ->
        metrics[:value]
    end
  end

  @spec get_success({:inet.ip4_address(), :inet.port_number()}) :: non_neg_integer()
  def get_success(server) do
    case get_metric_value("brahman.counters.dns.#{inspect(server)}.successes") do
      {:error, _} ->
        0

      {:ok, metrics} ->
        metrics[:value]
    end
  end

  @spec get_failed({:inet.ip4_address(), :inet.port_number()}) :: non_neg_integer()
  def get_failed(server) do
    case get_metric_value("brahman.spirals.dns.#{inspect(server)}.failed") do
      {:error, _} ->
        0

      {:ok, metrics} ->
        metrics[:one]
    end
  end

  @spec get_selected({:inet.ip4_address(), :inet.port_number()}) :: non_neg_integer()
  def get_selected(server) do
    case get_metric_value("brahman.counters.dns.#{inspect(server)}.selected") do
      {:error, _} ->
        0

      {:ok, metrics} ->
        metrics[:value]
    end
  end
end
