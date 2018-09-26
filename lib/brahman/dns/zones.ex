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
    sha = :crypto.hash(:sha, :erlang.term_to_binary(rr_record))
    :erldns_zone_cache.put_zone({name, sha, rr_record})
  end

  @spec get(String.t()) :: {:ok, map()} | {:error, term()}
  def get(name) do
    case :erldns_zone_cache.get_records_by_name(name) do
      [] ->
        []

      records ->
        to_map(records, [])
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
        rr_map = %{type: type, ttl: ttl, data: data}
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

  defp to_records(name, [%{type: type, ttl: ttl, data: data0} | rest], acc) do
    case to_record(type, data0) do
      data when is_tuple(data) ->
        rr = dns_rr(name: name, type: type, ttl: ttl, data: data)
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
end
