defmodule Brahman.Dns.Metrics do
  @moduledoc """
  DNS metric instrumentations
  """

  use Elixometer

  # counters

  @spec failed(:inet.ip4_address()) :: :ok
  def failed(srv), do: update_spiral("dns.#{:inet.ntoa(srv)}.failed", 1)

  @spec ignored(:inet.ip4_address()) :: :ok
  def ignored(srv), do: update_spiral("dns.#{:inet.ntoa(srv)}.ignored", 1)

  @spec no_upstreams() :: :ok
  def no_upstreams, do: update_spiral("dns.no_upstreams", 1)
end
