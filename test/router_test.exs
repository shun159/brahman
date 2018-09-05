defmodule RouterTest do
  use ExUnit.Case, async: true
  use Brahman.Dns.Header

  setup_all do
    {:ok, _} = Application.ensure_all_started(:brahman)

    on_exit(fn ->
      Application.stop(:brahman)
    end)
  end

  describe "Router.upstream_from/1" do
    test "with dns_query() record" do
      {upstreams, name} =
        "test/packet_data/dns_query.raw"
        |> File.read!()
        |> :dns.decode_message()
        |> dns_message(:questions)
        |> Brahman.Dns.Router.upstream_from()

      assert name == "google.com"
      assert length(upstreams) == 2
    end
  end
end
