# Gaoxy

Gaoxy runs supervised TCP, OTP TLS and UDP services inside an Elixir application.
Each instance owns its listeners and connection handlers. HTTP/Plug/Phoenix and
HTTP/3 are available through the separate `gaoxy_http` and `gaoxy_http3` packages.

## Install

Add to `mix.exs`, then run `mix deps.get`:

```elixir
defp deps do
  [
    {:gaoxy, "~> 0.14.0"}
  ]
end
```

Use Elixir 1.18 or newer with Erlang/OTP. Core uses Hex `abyss == 0.10.0`, which
has no bundled DHCP NIF or Rustler build dependency. Neither Rust/Cargo nor
`abyss_raw` is required for ordinary Gaoxy services.

## Run a TCP service

Implement the stream handler in your application:

```elixir
defmodule MyApp.Echo do
  @behaviour Gaoxy.StreamHandler

  @impl true
  def init(_context, _options), do: {:ok, nil}

  @impl true
  def handle_data(bytes, state), do: {:send, bytes, state}
end
```

Add a Gaoxy instance to your application's supervision tree:

```elixir
children = [
  {Gaoxy,
   name: MyApp.Transports,
   services: [
     %{
       id: :echo,
       transport: :tcp,
       ip: {127, 0, 0, 1},
       port: 4001,
       handler: MyApp.Echo
     }
   ]}
]

Supervisor.start_link(children, strategy: :one_for_one)
```

Start your application and connect with `nc 127.0.0.1 4001`. Bytes written to
the connection are echoed back. Input callbacks receive an ordered byte stream;
your handler must buffer and parse any application message framing.
`handler_options: term` supplies the second argument to `init/2`.
Optional `terminate/2` handles connection cleanup.

Raw TCP/TLS connections reserve bounded receive, state and output credit before
handler initialization, including credit to finish I/O during drain. Default
limits require 905,139 bytes per connection. Explicit byte caps must fund that
floor; larger configured socket buffers increase it. See the
[resource-budget migration guide](../../docs/resource-budget.md#quotas-and-migration)
for buffer settings and the exact calculation.

Inspect the instance from IEx:

```elixir
instance = Process.whereis(MyApp.Transports)
Gaoxy.services(instance)
Gaoxy.info(instance, :echo)
Gaoxy.pause(instance, :echo)
Gaoxy.resume(instance, :echo)
```

Service IDs belong to an instance, so two instances can each have an `:echo`
service. `Gaoxy.add/2` and `Gaoxy.remove/3` manage services dynamically;
`Gaoxy.stop/2` stops the instance. A cleanup deadline error can mean cleanup is
still in progress.

## TLS and UDP

For TLS, use `transport: :tls` and supply
`tls: %{certfile: "/path/to/cert.pem", keyfile: "/path/to/key.pem"}` on the service.
TCP/TLS stream services use the same handler behaviour. TLS uses OTP `:ssl`;
TLS 1.3 is the default.

For UDP, implement `Gaoxy.DatagramHandler`:

```elixir
defmodule MyApp.DatagramEcho do
  @behaviour Gaoxy.DatagramHandler

  @impl true
  def handle_datagram(%{data: bytes}, _options), do: {:reply, bytes}
end
```

Use `%{id: :udp_echo, transport: :udp, ip: {127, 0, 0, 1}, port: 4002,
handler: MyApp.DatagramEcho}` in `services`. Each admitted packet gets one
isolated callback; `{:reply, bytes}` sends to that packet's sender.

## Configuration

The instance accepts `:name`, `:services` and `:resource_budget`. Services are
maps; unknown keys are rejected. Bind addresses are IP tuples, and port `0`
requests an ephemeral port. Defaults bind loopback.

Adaptive memory admission shares one capacity pool across instances in the same
BEAM VM. Its soft limit is 50% of effective physical/cgroup capacity and its hard
limit is twice soft. Unreliable detection uses 256/512 MiB. Usage above soft
through hard remains admissible with rate-limited warnings. Explicit instance
thresholds use `resource_budget: %{soft_limit: 268_435_456, hard_limit: 402_653_184}`;
the explicit hard value is never doubled and the shared VM pool still applies.

Service `limits.max_connections`, `max_requests` and `max_streams` are independent
quotas, defaulting to 16,384, 65,536 and 65,536. Explicit legacy `max_active` and
`max_bytes` remain undoubled ordinary-lease and transport/cleanup hard caps;
WebSocket retained bytes participate in shared memory, not the legacy transport
cap. Omitted historical numeric profiles no longer impose aggregate caps.
Protocol, process and OOM safety guards remain finite and independent.

`Gaoxy.resource_budget(instance)` exposes thresholds, retained/temporary usage,
active resource counters, rejection reasons, detection and shared VM totals.
These budgets describe owned resources and commitments, not total VM or kernel
memory. See the [resource budget guide](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/resource-budget.md)
for exact boundaries, telemetry and migration semantics.

TCP/TLS services accept `hell_options`, for example
`[num_acceptors: 4, transport_options: [backlog: 2048, keepalive: true]]`.
UDP services accept `abyss_options`, for example `[udp_buffer_size: 262_144]`.
These are strict backend-specific subsets; binding, TLS, resource and lifecycle
controls remain in their existing fields. See
[backend tuning](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/backend-options.md)
for supported keys, defaults and acceptor budget division.

For HTTP and Phoenix, see the
[HTTP package](https://github.com/gsmlg-dev/gaoxy/blob/main/apps/gaoxy_http/README.md)
and [Phoenix guide](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/phoenix.md).
See [capabilities](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/capabilities.md)
for transport support and
[architecture](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/architecture.md)
for lifecycle and resource ownership.
