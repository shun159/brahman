brahman (ब्रह्मन्)
====

It is written as an extendable library for building DNS Balancer/Server.  
Running it is pretty simple:  

- Start the `brahman` app
- Implement a socket server(using `:gen_udp` or `netlink`)
- Implement a handler function
- Call `Brahman.Dns.Handler.handle/2`

Overview
====

### Querying

Aims to make it as easy as possible to build DNS LB/Server.  

```elixir
iex> packet = File.read!("test/packet_data/dns_query.raw")
iex> handler_fn = &IO.inspect/1
iex> Brahman.Dns.Handler.handle(packet, handler_fn)
```

The `handler_fn` is a higher order function or form of `{function(), [:args]}`.  

### Zone Interfaces

- `Brahman.Dns.Zones.put/2`
  ```elixir
  name = "google.com"

  records = [
    %{
      name: "dummy1.google.com",
      type: "A",
      ttl: 3600,
      data: %{ip: "192.168.5.1"}
    },
    %{
      name: "dummy2.google.com",
      type: "A",
      ttl: 3600,
      data: %{ip: "192.168.5.2"}
    },
    %{
      name: "dummy3.google.com",
      type: "A",
      ttl: 3600,
      data: %{ip: "192.168.5.3"}
    }
  ]

  :ok = Brahman.Dns.Zones.put(name, records)
  ```

- `Brahman.Dns.Zones.get/1`
  ```elixir
  ^records = Brahman.Dns.Zones.get("google.com")
  ```

- `Brahman.Dns.Zones.delete/1`
  ```elixir
  :ok = Brahman.Dns.Zones.delete("google.com")
  [] = Brahman.Dns.Zones.get("google.com")
  ```

Status
===

__Under development__
