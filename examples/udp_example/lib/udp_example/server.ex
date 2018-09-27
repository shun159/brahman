defmodule UdpExample.Server do
  @moduledoc false

  use GenServer
  use Bitwise

  require Logger

  defmodule State do
    @moduledoc false

    defstruct(socket: nil)
  end

  @inet_af_inet 1

  @server_port 8053

  @server_opts [
    :binary,
    {:active, :once},
    {:reuseaddr, true},
    {:recbuf, 57_108_864},
    {:sndbuf, 57_108_864}
  ]

  @local_name  "example.com"

  @local_records [
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

  def send!(sock, src_ip, src_port, packet),
    do: :erlang.port_command(
          sock,
          [encode_ip_and_port(src_ip, src_port), packet],
          []
        )

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_init_args) do
    _ = Process.flag(:message_queue_data, :off_heap)
    {:ok, %State{}, {:continue, :init}}
  end

  def handle_continue(:init, state) do
    :ok = Brahman.Dns.Zones.put(@local_name, @local_records)
    {:noreply, state, {:continue, :open}}
  end

  def handle_continue(:open, state) do
    case :gen_udp.open(@server_port, @server_opts) do
      {:ok, sock} when is_port(sock) ->
        {:noreply, %{state | socket: sock}}
      {:error, reason} ->
        :ok = Logger.error(fn -> "failed to socket open" end)
        {:stop, reason, state}
    end
  end

  def handle_info({:udp, sock, src_ip, src_port, packet}, state) do
    :ok = forward(sock, src_ip, src_port, packet)
    :ok = :inet.setopts(sock, active: :once)
    {:noreply, state}
  end

  def handle_info({:inet_reply, _, status}, state) do
    :ok = Logger.debug(fn -> "prim_inet:send() -> #{inspect(status)}" end)
    {:noreply, state}
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  # private functions

  defp forward(sock, src_ip, src_port, packet) do
    fun = &__MODULE__.send!/4
    fun_args = [sock, src_ip, src_port]
    :ok = Logger.info(fn -> "received udp packet from #{:inet.ntoa(src_ip)}:#{src_port}" end)
    :ok = Brahman.Dns.Handler.handle(packet, {fun, fun_args})
  end

  defp encode_ip_and_port(ip, port) do
    [
      @inet_af_inet,
      int16(port),
      ip_to_bytes(ip)
    ]
  end

  defp int16(port), do: [(port >>> 8) &&& 0xFF, port &&& 0xFF]

  defp ip_to_bytes({a1, a2, a3, a4}),
    do: [a1 &&& 0xFF, a2 &&& 0xFF, a3 &&& 0xFF, a4 &&& 0xFF]
end
