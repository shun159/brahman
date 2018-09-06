defmodule Brahman.Dns.Router do
  @moduledoc """
  DNS forwarding router
  """

  use Brahman.Dns.Header

  alias Brahman.Config
  alias Brahman.Dns.Metrics

  @typep upstream :: {:inet.ip4_address(), :inet.port_number()}

  @spec upstream_from([record(:dns_query)]) :: {[upstream()], String.t()}
  def upstream_from([dns_query(name: name)]) do
    upstreams =
      name
      |> parse_name_to_reversed_labels()
      |> find_upstream(name)
      |> Metrics.select_upstreams()

    {upstreams, name}
  end

  def upstream_from([question | rest]) do
    :ok =
      rest
      |> length()
      |> Metrics.ignored()

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
  defp find_upstream(labels, _name) do
    case find_custom_upstream(labels) do
      [] ->
        Config.upstream_resolvers()

      resolvers ->
        resolvers
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
