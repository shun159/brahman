defmodule DnsZoneTest do
  use ExUnit.Case
  doctest Brahman

  setup_all do
    {:ok, _} = Application.ensure_all_started(:brahman)

    on_exit(fn ->
      Application.stop(:brahman)
    end)
  end

  test "with A, CNAME and SOA map" do
    name = "example.com"

    records = [
      %{
        type: "A",
        ttl: 3600,
        data: %{ip: "192.168.5.200"}
      },
      %{
        type: "CNAME",
        ttl: 3600,
        data: %{dname: "example.com"}
      },
      %{
        type: "SOA",
        ttl: 3600,
        data: %{
          mname: "ns.brahman",
          rname: "support.brahman.com",
          serial: 0,
          refresh: 60,
          retry: 180,
          expire: 86400,
          minimum: 1
        }
      }
    ]

    assert Brahman.Dns.Zones.put(name, records) == :ok
    assert Brahman.Dns.Zones.get(name) == records
    assert Brahman.Dns.Zones.delete(name) == :ok
    Process.sleep(10)
    assert Brahman.Dns.Zones.get(name) == []
  end
end
