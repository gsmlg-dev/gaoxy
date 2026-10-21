# Gaoxy

Gaoxy runs supervised TCP, OTP TLS and UDP services inside an Elixir application.
Each instance owns its listeners and connection handlers. HTTP/Plug/Phoenix and
HTTP/3 are available through the separate `gaoxy_http` and `gaoxy_http3` packages.

## Install

Add to `mix.exs`, then run `mix deps.get`:

```elixir
defp deps do
  [
    {:gaoxy, "~> 0.7.0"}
  ]
end
```

Use Elixir 1.18 or newer with Erlang/OTP. Core uses Hex `abyss == 0.9.0`, which
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

The instance accepts `:name` and `:services`. Services are maps; unknown keys are
rejected. Bind addresses are IP tuples, and port `0` requests an ephemeral port.
Defaults bind loopback and limit each service to 64 active operations and
1,048,576 retained bytes. Override finite positive limits with a map such as
`limits: %{max_active: 32, max_bytes: 4_194_304, idle_timeout: 60_000}`.
These budgets describe admitted resources, not total VM or kernel memory.

For HTTP and Phoenix, see the
[HTTP package](https://github.com/gsmlg-dev/gaoxy/blob/main/apps/gaoxy_http/README.md)
and [Phoenix guide](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/phoenix.md).
See [capabilities](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/capabilities.md)
for transport support and
[architecture](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/architecture.md)
for lifecycle and resource ownership.
