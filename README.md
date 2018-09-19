brahman (ब्रह्मन्)
====

It is written as an extendable library for building DNS Balancer/Server.

Overview
====

Aims to make it as easy as possible to build DNS LB/Server.

```elixir
iex> packet = File.read!("test/packet_data/dns_query.raw")
iex> handler_fn = &IO.inspect/1
iex> Brahman.Dns.Forwarder.start_link(packet, handler_fn)
```

Status
===

__Under development__
