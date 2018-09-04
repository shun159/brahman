defmodule RouterTest do
  use ExUnit.Case
  use Brahman.Dns.Header

  setup_all do
    {:ok, _} = Application.ensure_all_started(:brahman)

    on_exit(fn ->
      Application.stop(:brahman)
    end)
  end

  describe "Router.upstream_from/1" do
    test "with dns_query() record" do
      upstreams =
        "test/packet_data/dns_query.raw"
        |> File.read!()
        |> :dns.decode_message()
        |> dns_message(:questions)
        |> Brahman.Dns.Router.upstream_from()

      assert upstreams == {
        [
          {{1, 1, 1, 1}, 53},
          {{8, 8, 8, 8}, 53},
          {{4, 2, 2, 1}, 53},
          {{8, 8, 4, 4}, 53}
        ],
        "google.com"
      }
    end
  end
end
