defmodule Brahman.Dns.Header do
  @moduledoc false

  defmacro __using__(_which) do
    quote location: :keep do
      require Record

      @include_libs [
        "dns/include/dns_terms.hrl",
        "dns/include/dns_records.hrl"
      ]

      for lib_path <- @include_libs do
        for {name, fields} <- Record.extract_all(from_lib: lib_path) do
          Record.defrecord(name, fields)
        end
      end

      @dns_rcode_formerr 1
      @dns_rcode_servfail 2
      @dns_rcode_nxdomain 3
      @dns_rcode_notimp 4
      @dns_rcode_refused 5
      @dns_rcode_yxdomain 6
      @dns_rcode_yxrrset 7
      @dns_rcode_nxrrset 8
      @dns_rcode_notauth 9
      @dns_rcode_notzone 10
    end
  end
end
