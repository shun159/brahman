defmodule UdpExample.Server do
  @moduledoc false

  use GenServer

  require Logger

  defmodule State do
    @moduledoc false

    defstruct(socket: nil)
  end

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

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_init_args) do
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

  def handle_info(_info, state) do
    {:noreply, state}
  end

  # private functions

  defp forward(sock, src_ip, src_port, packet) do
    fun = &:gen_udp.send/4
    fun_args = [sock, src_ip, src_port]
    :ok = Logger.info(fn -> "received udp packet from #{:inet.ntoa(src_ip)}:#{src_port}" end)
    :ok = Brahman.Dns.Handler.handle(packet, {fun, fun_args})
  end
end
