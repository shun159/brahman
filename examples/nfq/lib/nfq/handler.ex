defmodule NFQ.Handler do
  @moduledoc false

  use Bitwise

  require Logger
  require Record

  alias NFQ.IPTables
  alias Brahman.Dns

  @pkt_header "pkt/include/pkt.hrl"

  for {name, field} <- Record.extract_all(from_lib: @pkt_header) do
    Record.defrecord(name, field)
  end

  @nf_accept 1
  @queue_id 0

  def start_link do
    Netfilter.Queue.start_link(@queue_id, callback_mod: __MODULE__)
  end

  def nfq_init(_opts) do
    :ok = init_iptables()
    :ok = init_zone()
    {}
  end

  def nfq_verdict(_family, info, state) do
    {:payload, packet} = List.keyfind(info, :payload, 0)

    new_ip_packet =
      packet
      |> parse_packet()
      |> do_resolve()
      |> update_packet()

    {@nf_accept, [payload: new_ip_packet], state}
  end

  # private functions

  defp init_zone do
    name = "example.com"

    records = [
      %{
        name: "dummy1.example.com",
        type: "A",
        ttl: 3600,
        data: %{ip: "192.168.5.1"}
      },
      %{
        name: "dummy2.example.com",
        type: "A",
        ttl: 3600,
        data: %{ip: "192.168.5.2"}
      },
      %{
        name: "dummy3.example.com",
        type: "A",
        ttl: 3600,
        data: %{ip: "192.168.5.3"}
      }
    ]

    :ok = Brahman.Dns.Zones.put(name, records)
  end

  defp init_iptables do
    :ok = Logger.info("Initialize iptables nfqueue entry: queue_id = #{@queue_id}")
    rule = "-p udp -m udp --dport 8054 -j NFQUEUE --queue-num #{@queue_id}"
    _ = IPTables.delete(:input, rule)
    :ok = IPTables.append(:input, rule)
  end

  defp parse_packet(packet) do
    [ipv4(), udp(), _payload] = :pkt.decapsulate(:ipv4, packet)
  end

  defp do_resolve([ip, udp, payload]) do
    {:ok, pid} = Task.Supervisor.start_link()

    task =
      Task.Supervisor.async(pid, fn ->
        :ok = Dns.Handler.handle(payload, {&Kernel.send/2, [self()]})

        receive do
          reply when is_binary(reply) -> [ip, udp, reply]
        after
          10000 ->
            {:error, :timeout}
        end
      end)

    Task.await(task)
  end

  defp update_packet([
         ipv4(saddr: sa, daddr: da) = l3_0,
         udp(sport: sp, dport: dp) = l4_0,
         payload
       ]) do
    l3_1 = ipv4(l3_0, saddr: da, daddr: sa, sum: 0)
    ipv4_sum = :pkt.makesum(l3_1)
    ipv4 = ipv4(l3_1, sum: ipv4_sum)

    l4_1 = udp(l4_0, sport: dp, dport: sp, sum: 0, ulen: byte_size(payload) + 8)
    udp_sum = :pkt.makesum([ipv4, l4_1, payload])
    udp = udp(l4_1, sum: udp_sum)

    :pkt.encode({[ipv4, udp], payload})
  end
end
