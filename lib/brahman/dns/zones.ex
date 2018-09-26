defmodule Brahman.Dns.Zones do
  @moduledoc """
  convert into erldns record
  """

  require Record
  require Logger

  @dns_header "erldns/include/erldns.hrl"

  for {name, field} <- Record.extract_all(from_lib: @dns_header) do
    Record.defrecord(name, field)
  end

  # API functions

  @spec put(name :: String.t(), [map()]) :: :ok | {:error, :reason}
  def put(name, records) do
    rr_record = to_records(name, records, [])
    zone = zone(
      name: name,
      version: :crypto.hash(:sha, :erlang.term_to_binary(rr_record)),
      authority: rr_record,
      records_by_name: %{name => rr_record},
      keysets: []
    )
    :erldns_zone_cache.put_zone(name, zone)
  end

  @spec get(String.t()) :: [map()]
  def get(name) do
    case :erldns_zone_cache.get_authority(name) do
      {:ok, records} ->
        to_map(records, [])

      _ ->
        []
    end
  end

  @spec delete(String.t()) :: :ok
  def delete(name), do: :erldns_zone_cache.delete_zone(name)

  # private functions

  @spec to_map([record(:dns_rr)], [map()]) :: [map()]
  defp to_map([], acc), do: Enum.reverse(acc)

  defp to_map([dns_rr(type: type, ttl: ttl, data: data0) | rest], acc) do
    case to_map(data0) do
      data when is_map(data) ->
        rr_map = %{type: int_to_type(type), ttl: ttl, data: data}
        to_map(rest, [rr_map | acc])
    end
  catch
    :throw, reason ->
      :ok = Logger.warn(fn -> "to_map error: reason = #{inspect(reason)}" end)
      to_map(rest, acc)
  end

  @spec to_map(tuple()) :: map()
  defp to_map(dns_rrdata_a(ip: ip)), do: %{ip: "#{:inet.ntoa(ip)}"}

  defp to_map(dns_rrdata_aaaa(ip: ip)), do: %{ip: "#{:inet.ntoa(ip)}"}

  defp to_map(dns_rrdata_cname(dname: dname)), do: %{dname: dname}

  defp to_map(dns_rrdata_rp(mbox: mbox, txt: txt)), do: %{mbox: mbox, txt: txt}

  defp to_map(dns_rrdata_txt(txt: txt)), do: %{txt: txt}

  defp to_map(dns_rrdata_spf(spf: spf)), do: %{spf: spf}

  defp to_map(dns_rrdata_ns(dname: name)), do: %{dname: name}

  defp to_map(
         dns_rrdata_srv(
           priority: priority,
           weight: weight,
           port: port,
           target: target
         )
       ) do
    %{priority: priority, weight: weight, port: port, target: target}
  end

  defp to_map(
         dns_rrdata_sshfp(
           alg: alg,
           fp_type: fp_type,
           fp: fp
         )
       ) do
    %{alg: alg, fp_type: fp_type, fp: fp}
  end

  defp to_map(
         dns_rrdata_mx(
           exchange: exchange,
           preference: preference
         )
       ) do
    %{exchange: exchange, preference: preference}
  end

  defp to_map(
         dns_rrdata_naptr(
           order: order,
           preference: preference,
           flags: flags,
           services: services,
           regexp: regexp
         )
       ) do
    %{order: order, preference: preference, flags: flags, services: services, regexp: regexp}
  end
  
  defp to_map(
         dns_rrdata_soa(
           mname: mname,
           rname: rname,
           serial: serial,
           refresh: refresh,
           retry: retry,
           expire: expire,
           minimum: minimum
         )
       ) do
    %{
      mname: mname,
      rname: rname,
      serial: serial,
      refresh: refresh,
      retry: retry,
      expire: expire,
      minimum: minimum
    }
  end

  defp to_map(_undefined), do: throw(:unknown)

  @spec to_records(String.t(), [map()], tuple()) :: tuple()
  defp to_records(_name, [], acc), do: Enum.reverse(acc)

  defp to_records(name, [%{type: type, ttl: ttl, data: data0} = rr | rest], acc) do
    case to_record(type, data0) do
      data when is_tuple(data) ->
        rr_name = if rr[:name], do: rr[:name], else: name
        rr = dns_rr(name: rr_name, type: type_to_int(type), ttl: ttl, data: data)
        to_records(name, rest, [rr | acc])
    end
  catch
    :throw, reason ->
      :ok = Logger.warn(fn -> "to_records error: reason = #{inspect(reason)}" end)
      to_records(name, rest, acc)
  end

  @spec to_record(String.t(), map()) :: tuple() | {:error, :unknown}
  defp to_record("A", data) do
    case :inet.parse_address(~c"#{data.ip}") do
      {:ok, ip} ->
        dns_rrdata_a(ip: ip)

      {:error, _} ->
        throw(:ip4_address)
    end
  end

  defp to_record("AAAA", data) do
    case :inet.parse_address(~c"#{data.ip}") do
      {:ok, ip} ->
        dns_rrdata_aaaa(ip: ip)

      {:error, _} ->
        throw(:ip6_address)
    end
  end

  defp to_record("CNAME", data),
    do: dns_rrdata_cname(dname: data.dname)

  defp to_record("NS", data),
    do: dns_rrdata_ns(dname: data.dname)

  defp to_record("RP", data),
    do: dns_rrdata_rp(mbox: data.mbox, txt: data.txt)

  defp to_record("TXT", data),
    do: dns_rrdata_txt(txt: data.txt)

  defp to_record("SPF", data),
    do: dns_rrdata_spf(spf: data.spf)

  defp to_record("SRV", data),
    do:
      dns_rrdata_srv(
        priority: data.priority,
        weight: data.weight,
        port: data.port,
        target: data.target
      )

  defp to_record("SSHFP", data),
    do:
      dns_rrdata_sshfp(
        alg: data.alg,
        fp_type: data.fp_type,
        fp: Base.decode16!(data.fp, case: :mixed)
      )

  defp to_record("MX", data),
    do:
      dns_rrdata_mx(
        exchange: data.exchange,
        preference: data.preference
      )

  defp to_record("NAPTR", data),
    do:
      dns_rrdata_naptr(
        order: data.order,
        preference: data.preference,
        flags: data.flags,
        services: data.services,
        regexp: data.regexp
      )

  defp to_record("SOA", data),
    do:
      dns_rrdata_soa(
        mname: data.mname,
        rname: data.rname,
        serial: data.serial,
        refresh: data.refresh,
        retry: data.retry,
        expire: data.expire,
        minimum: data.minimum
      )

  defp to_record(_type, _data), do: {:error, :unknown}

  @spec type_to_int(String.t()) :: non_neg_integer()
  defp type_to_int("A"), do: 1
  defp type_to_int("NS"), do: 2
  defp type_to_int("MD"), do: 3
  defp type_to_int("MF"), do: 4
  defp type_to_int("CNAME"), do: 5
  defp type_to_int("SOA"), do: 6
  defp type_to_int("MB"), do: 7
  defp type_to_int("MG"), do: 8
  defp type_to_int("MR"), do: 9
  defp type_to_int("NULL"), do: 10
  defp type_to_int("WKS"), do: 11
  defp type_to_int("PTR"), do: 12
  defp type_to_int("HINFO"), do: 13
  defp type_to_int("MINFO"), do: 14
  defp type_to_int("MX"), do: 15
  defp type_to_int("TXT"), do: 16
  defp type_to_int("RP"), do: 17
  defp type_to_int("AFSDB"), do: 18
  defp type_to_int("X25"), do: 19
  defp type_to_int("ISDN"), do: 20
  defp type_to_int("RT"), do: 21
  defp type_to_int("NSAP"), do: 22
  defp type_to_int("SIG"), do: 24
  defp type_to_int("KEY"), do: 25
  defp type_to_int("PX"), do: 26
  defp type_to_int("GPOS"), do: 27
  defp type_to_int("AAAA"), do: 28
  defp type_to_int("LOC"), do: 29
  defp type_to_int("NXT"), do: 30
  defp type_to_int("EID"), do: 31
  defp type_to_int("NIMLOC"), do: 32
  defp type_to_int("SRV"), do: 33
  defp type_to_int("ATMA"), do: 34
  defp type_to_int("NAPTR"), do: 35
  defp type_to_int("KX"), do: 36
  defp type_to_int("CERT"), do: 37
  defp type_to_int("DNAME"), do: 39
  defp type_to_int("SINK"), do: 40
  defp type_to_int("OPT"), do: 41
  defp type_to_int("APL"), do: 42
  defp type_to_int("DS"), do: 43
  defp type_to_int("SSHFP"), do: 44
  defp type_to_int("IPSECKEY"), do: 45
  defp type_to_int("RRSIG"), do: 46
  defp type_to_int("NSEC"), do: 47
  defp type_to_int("DNSKEY"), do: 48
  defp type_to_int("NSEC3"), do: 50
  defp type_to_int("NSEC3PARAM"), do: 51
  defp type_to_int("DHCID"), do: 49
  defp type_to_int("HIP"), do: 55
  defp type_to_int("NINFO"), do: 56
  defp type_to_int("RKEY"), do: 57
  defp type_to_int("TALINK"), do: 58
  defp type_to_int("SPF"), do: 99
  defp type_to_int("UINFO"), do: 100
  defp type_to_int("UID"), do: 101
  defp type_to_int("GID"), do: 102
  defp type_to_int("UNSPEC"), do: 103
  defp type_to_int("TKEY"), do: 249
  defp type_to_int("TSIG"), do: 250
  defp type_to_int("IXFR"), do: 251
  defp type_to_int("AXFR"), do: 252
  defp type_to_int("MAILB"), do: 253
  defp type_to_int("MAILA"), do: 254
  defp type_to_int("ANY"), do: 255
  defp type_to_int("CAA"), do: 257
  defp type_to_int("DLV"), do: 32769

  @spec int_to_type(non_neg_integer()) :: String.t()
  defp int_to_type(1), do: "A"
  defp int_to_type(2), do: "NS"
  defp int_to_type(3), do: "MD"
  defp int_to_type(4), do: "MF"
  defp int_to_type(5), do: "CNAME"
  defp int_to_type(6), do: "SOA"
  defp int_to_type(7), do: "MB"
  defp int_to_type(8), do: "MG"
  defp int_to_type(9), do: "MR"
  defp int_to_type(10), do: "NULL"
  defp int_to_type(11), do: "WKS"
  defp int_to_type(12), do: "PTR"
  defp int_to_type(13), do: "HINFO"
  defp int_to_type(14), do: "MINFO"
  defp int_to_type(15), do: "MX"
  defp int_to_type(16), do: "TXT"
  defp int_to_type(17), do: "RP"
  defp int_to_type(18), do: "AFSDB"
  defp int_to_type(19), do: "X25"
  defp int_to_type(20), do: "ISDN"
  defp int_to_type(21), do: "RT"
  defp int_to_type(22), do: "NSAP"
  defp int_to_type(24), do: "SIG"
  defp int_to_type(25), do: "KEY"
  defp int_to_type(26), do: "PX"
  defp int_to_type(27), do: "GPOS"
  defp int_to_type(28), do: "AAAA"
  defp int_to_type(29), do: "LOC"
  defp int_to_type(30), do: "NXT"
  defp int_to_type(31), do: "EID"
  defp int_to_type(32), do: "NIMLOC"
  defp int_to_type(33), do: "SRV"
  defp int_to_type(34), do: "ATMA"
  defp int_to_type(35), do: "NAPTR"
  defp int_to_type(36), do: "KX"
  defp int_to_type(37), do: "CERT"
  defp int_to_type(39), do: "DNAME"
  defp int_to_type(40), do: "SINK"
  defp int_to_type(41), do: "OPT"
  defp int_to_type(42), do: "APL"
  defp int_to_type(43), do: "DS"
  defp int_to_type(44), do: "SSHFP"
  defp int_to_type(45), do: "IPSECKEY"
  defp int_to_type(46), do: "RRSIG"
  defp int_to_type(47), do: "NSEC"
  defp int_to_type(48), do: "DNSKEY"
  defp int_to_type(50), do: "NSEC3"
  defp int_to_type(51), do: "NSEC3PARAM"
  defp int_to_type(49), do: "DHCID"
  defp int_to_type(55), do: "HIP"
  defp int_to_type(56), do: "NINFO"
  defp int_to_type(57), do: "RKEY"
  defp int_to_type(58), do: "TALINK"
  defp int_to_type(99), do: "SPF"
  defp int_to_type(100), do: "UINFO"
  defp int_to_type(101), do: "UID"
  defp int_to_type(102), do: "GID"
  defp int_to_type(103), do: "UNSPEC"
  defp int_to_type(249), do: "TKEY"
  defp int_to_type(250), do: "TSIG"
  defp int_to_type(251), do: "IXFR"
  defp int_to_type(252), do: "AXFR"
  defp int_to_type(253), do: "MAILB"
  defp int_to_type(254), do: "MAILA"
  defp int_to_type(255), do: "ANY"
  defp int_to_type(257), do: "CAA"
  defp int_to_type(32769), do: "DLV"
end
