defmodule Brahman.Dns.Router do
  @moduledoc """
  DNS forwarding router
  """

  use Brahman.Dns.Header

  alias Brahman.Config
  alias Brahman.Metrics.Counters
  alias Brahman.Balancers.P2cEwma

  @typep upstream :: {:inet.ip4_address(), :inet.port_number()}

  @spec upstream_from([record(:dns_query)]) :: {[upstream()], String.t()}
  def upstream_from([dns_query(name: name)]) do
    upstream =
      name
      |> parse_name_to_reversed_labels()
      |> find_upstream(name)
      |> P2cEwma.pick_upstream()
      |> Kernel.elem(1)

    {[upstream], name}
  end

  def upstream_from([question | rest]) do
    :ok =
      rest
      |> length()
      |> Counters.ignored()

    upstream_from(question)
  end

  # private functions

  @spec parse_name_to_reversed_labels(String.t()) :: [String.t()]
  defp parse_name_to_reversed_labels(name) do
    name
    |> :dns.dname_to_lower()
    |> :dns.dname_to_labels()
    |> Enum.reverse()
  end

  @spec find_upstream([String.t()], String.t()) :: [upstream()]
  defp find_upstream(labels, name) do
    case find_custom_upstream(labels) do
      [] ->
        find_upstream(name)

      resolvers ->
        resolvers
    end
  end

  @spec find_upstream(String.t()) :: [upstream()]
  defp find_upstream(name) do
    case Brahman.Dns.Zones.get(name) do
      [] ->
        Config.upstream_resolvers()

      [_ | _] ->
        Config.erldns_servers()
    end
  end

  @spec find_custom_upstream([String.t()]) :: [upstream()]
  defp find_custom_upstream(query_labels) do
    Config.forward_zones()
    |> Enum.reduce([], &custom_upstream_filter(&1, &2, query_labels))
  end

  @spec custom_upstream_filter(
          {String.t(), [upstream()]},
          [upstream()],
          [String.t()]
        ) :: [upstream()]
  defp custom_upstream_filter({label, upstreams}, acc, query_labels) do
    prefix =
      label
      |> :dns.dname_to_lower()
      |> :dns.dname_to_labels()
      |> Enum.reverse()

    query_labels
    |> List.starts_with?(prefix)
    |> if(do: upstreams, else: acc)
  end
end
