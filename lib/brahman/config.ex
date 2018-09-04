defmodule Brahman.Config do
  @moduledoc """
  Configuration Helpers
  """

  @default_resolvers [
    {{1, 1, 1, 1}, 53},
    {{8, 8, 8, 8}, 53},
    {{4, 2, 2, 1}, 53},
    {{8, 8, 4, 4}, 53}
  ]

  @spec upstream_resolvers() :: [{:inet.ip4_address(), non_neg_integer()}]
  def upstream_resolvers, do: get_env(:upstream_resolvers, @default_resolvers)

  @spec erldns_servers() :: [{:inet.ip4_address(), non_neg_integer()}]
  def erldns_servers do
    :erldns
    |> Application.get_env(:servers, [])
    |> filter_servers([])
  end

  @spec forward_zones() :: %{String.t() => [{:inet.ip4_address(), non_neg_integer()}]}
  def forward_zones, do: get_env(:forward_zones, Map.new())

  # private functions

  defp filter_servers([], acc), do: acc

  defp filter_servers([config | rest], acc) do
    with {:ok, addr} <- :inet.parse_ipv4_address(config[:address]),
         port when is_integer(port) <- config[:port],
         _family <- config[:family] do
      filter_servers(rest, [{addr, port} | acc])
    else
      _ -> filter_servers(rest, acc)
    end
  end

  defp get_env(key, default \\ nil)
  defp get_env(key, default), do: Application.get_env(:brahman, key, default)
end
