defmodule Brahman.Dns.Metrics do
  @moduledoc """
  DNS metric instrumentations
  """

  use Elixometer

  @type upstream :: {:inet.ip4_address(), :inet.port_number()}

  # counters

  @spec select_upstreams([upstream()]) :: [
          upstream()
        ]
  def select_upstreams(upstreams) do
    upstreams
    |> group_by_failcount()
    |> take_upstream_1()
    |> take_upstream_2()
  end

  @spec failed(upstream()) :: :ok
  def failed(server),
    do: update_spiral("dns.#{inspect(server)}.failed", 1)

  @spec ignored(non_neg_integer()) :: :ok
  def ignored(num_of_query),
    do: update_counter("dns.ignored", num_of_query)

  @spec success(upstream()) :: :ok
  def success(server),
    do: update_counter("dns.#{inspect(server)}.successes", 1)

  @spec latency(upstream(), non_neg_integer()) :: :ok
  def latency(server, timediff),
    do: update_histogram("dns.#{inspect(server)}.latency", timediff)

  @spec no_upstreams() :: :ok
  def no_upstreams, do: update_spiral("dns.no_upstreams", 1)

  @spec selected(upstream()) :: :ok
  def selected(server),
    do: update_counter("dns.#{inspect(server)}.selected", 1)

  @spec get_latency(upstream()) :: non_neg_integer()
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

  @spec get_success(upstream()) :: non_neg_integer()
  def get_success(server) do
    case get_metric_value("brahman.counters.dns.#{inspect(server)}.successes") do
      {:error, _} ->
        0

      {:ok, metrics} ->
        metrics[:value]
    end
  end

  @spec get_failed(upstream()) :: non_neg_integer()
  def get_failed(server) do
    case get_metric_value("brahman.spirals.dns.#{inspect(server)}.failed") do
      {:error, _} ->
        0

      {:ok, metrics} ->
        metrics[:one]
    end
  end

  @spec get_selected(upstream()) :: non_neg_integer()
  def get_selected(server) do
    case get_metric_value("brahman.counters.dns.#{inspect(server)}.selected") do
      {:error, _} ->
        0

      {:ok, metrics} ->
        metrics[:value]
    end
  end

  # private functions

  @spec group_by_failcount([upstream()]) :: [[upstream()]]
  defp group_by_failcount(upstreams) do
    upstreams
    |> Enum.group_by(&calc_metrics/1)
    |> Map.values()
  end

  @spec calc_metrics(upstream()) :: float()
  defp calc_metrics(upstream) do
    get_latency(upstream) / 1000 * (get_failed(upstream) * 10_000) * get_selected(upstream)
  end

  @spec take_upstream_1([[upstream()]]) :: [upstream()]
  defp take_upstream_1([upstreams]), do: upstreams

  defp take_upstream_1([upstreams | _]) when length(upstreams) > 2, do: upstreams

  defp take_upstream_1([upstreams1, upstreams2 | _]), do: upstreams1 ++ upstreams2

  @spec take_upstream_2([upstream()]) :: [upstream()]
  defp take_upstream_2(upstreams) when length(upstreams) > 2,
    do: Enum.take_random(upstreams, 2)
end
