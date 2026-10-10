# Native HTTP and Phoenix

`gaoxy_http` owns the HTTP/1 parser, Plug adapter and WebSock connection lifecycle.
Thousand Island and Gaoxy retain socket/listener supervision, admission and
shutdown. No Bandit application is installed or started. Core consumers do not
depend on Plug, WebSock, Phoenix or an upstream HTTP client.

```elixir
{:ok, server} = Gaoxy.HTTP.start_link(plug: {MyPlug, []}, port: 0)
{:ok, {_ip, port}} = Gaoxy.info(server, :http).local
Gaoxy.stop(server)
```

Use `Gaoxy.HTTP.child_spec/1` under a supervisor, or obtain `{:ok, spec}` from
`Gaoxy.HTTP.service_spec/1` and include it among an instance's services. Options
are `:id`, `:ip`, `:port`, `:transport` (`:tcp` or `:tls`), `:tls`, `:limits`,
`:http_limits`, and exactly one of `:plug` or `:endpoint`. TLS uses the existing
Gaoxy certificate policy; ALPN may be empty or `["http/1.1"]`. Advertising H2 is
rejected because this engine does not implement it.

For Phoenix, configure `adapter: Gaoxy.PhoenixAdapter` with `http: [...]` and/or
`https: [...]`. The Endpoint supervisor owns one Gaoxy instance with one service
per enabled scheme. `MyEndpoint.server_info(:http)` returns its actual address
and port. The HTTPS options accept `:certfile`, `:keyfile`, `:versions` and `:alpn`
alongside `:ip`, `:port`, `:limits` and `:http_limits`. Integer and decimal-string
ports are accepted. Development uses Phoenix's `SyncCodeReloadPlug`; the project
must configure `listeners: [Phoenix.CodeReloader]` as required by Phoenix 1.8.

An Endpoint mounted in a separate gateway must have `server: false` and still
run its ordinary Endpoint supervisor. Mount `{MyEndpoint, []}` as a local Plug.
A conflicting Endpoint listener, including Phoenix's global `serve_endpoints`
setting, is rejected. The adapter's internal `:endpoint_managed` option is
reserved for Endpoint-owned startup. See the runnable
[fixture](../examples/phoenix_native/README.md).

## HTTP profile and limits

The initial profile supports HTTP/1.1 and explicit HTTP/1.0 persistence, raw
origin/absolute/authority/asterisk target parsing, fixed and chunked bodies,
trailers in the endpoint exchange, keep-alive, and ordered pipelining. Ambiguous
framing, duplicate Content-Length, unsupported transfer encodings and malformed
authorities are rejected before dispatch. The original escaped path/query is
preserved. Unread bodies force closure. Ordinary, prepared, chunked, fixed-length
streaming, file, HEAD/bodyless and informational Plug responses are supported.
Protocol push is unsupported. CONNECT targets parse but no tunnel is implemented.

`http_limits` defaults:

| Setting | Default |
|---|---:|
| `max_request_line` | 8,192 bytes |
| `max_header_bytes`, `max_headers` | 32,768 bytes, 100 fields |
| `max_body_bytes` | 8,388,608 bytes |
| `max_chunk_line` | 1,024 bytes |
| `max_trailer_bytes`, `max_trailers` | 8,192 bytes, 32 fields |
| `max_read_chunk`, `max_buffer_bytes` | 16,384 bytes, 65,536 bytes |
| `header_timeout` | 5,000 ms from the first request byte |
| `request_timeout` | 30,000 ms for the whole request/response |
| `read_timeout`, `write_timeout` | 5,000 ms per body-read call / socket write |

Limits are positive finite integers. SSE/long requests need an explicit larger
`request_timeout`. Partial headers and body metadata cannot renew their original
deadline. Slow writes have a finite transport timeout and request watchdog.
`max_header_bytes` also bounds informational and final response heads;
`max_headers` limits parsed request headers.
The service's global active/byte/output limits still apply: configured HTTP
ceilings are not promises of admission under resource pressure. Output iodata
and files are traversed in bounded pieces, without creating a full-body binary.

The ledger charges retained request headers/trailers, parser/body tails, selected
output windows, WebSocket fragments and callback state. Native receive buffers
and decoding have bounded transient copies; kernel/OTP transport buffers and
arbitrary allocations or retained body data inside trusted application code are
outside the ledger. This is not a bound on total BEAM memory. Low global byte
budgets may reject work below a protocol-specific maximum, especially TLS records.

## WebSock

Use `WebSockAdapter.upgrade(conn, MyWebSock, initial_state, options)`. The same
connection process implements callbacks, automatic pong, bounded fragmented
messages, UTF-8 validation, and close handshakes. Handshake response headers,
including a selected offered subprotocol, survive the Plug pipeline. Compression
extensions are not negotiated; `compress: true` and disabling UTF-8 validation
are rejected. The dependency's minimal reviewed dispatch fork has
[commit provenance and a removal plan](../vendor/websock_adapter/GAOXY.md).

Options default to `timeout: 60_000`, `callback_timeout: 5_000`,
`close_timeout: 1_000`, `max_lifetime: 86_400_000`,
`max_frame_size: 262_144`, `max_message_size: 262_144`, `max_fragments: 128`,
`max_mailbox: 128`, and `max_push_frames: 32`. Frame/message ceilings are also
clamped to one quarter of the service byte budget. The service `max_state`
limits callback state. Upgrade establishes one admitted protocol lifetime;
callbacks cannot renew it. Drain uses its existing absolute deadline and sends
1001; a WebSock restart stop sends 1012. Forced watchdog termination cannot run
application cleanup callbacks.

Gaoxy uses active-once transport delivery. Third-party processes can send
arbitrary messages to a WebSock owner; the adapter checks mailbox length and
closes an overloaded connection but cannot promise an absolute bound on such
external traffic. Keep application/PubSub producers bounded.

## Routing and proxy boundary

```elixir
routes = [
  %{host: "example.test", methods: ["GET"], path: {:prefix, "/api"},
    target: {Gaoxy.HTTP.PlugEndpoint, {ApiPlug, []}}},
  %{target: {Gaoxy.HTTP.PlugEndpoint, {WebsitePlug, []}}}
]
{:ok, server} = Gaoxy.HTTP.start_link(endpoint: {Gaoxy.HTTP.Router, routes})
```

Compilation yields an immutable generation. The first declared matching route
wins. Hosts normalize case; methods remain case-sensitive HTTP tokens; paths
match exactly or by complete prefix segments. There is no percent decoding,
forwarding-header trust, or header mutation during selection. Parsing and
authority/framing validation occur first; the selected endpoint then applies
its explicit policy. H1 absolute-target authority must agree with Host.

The endpoint contract also supports [HTTP streaming](http-proxy.md) and
[WebSocket reverse proxying](websocket-proxy.md), without making `gaoxy_http`
depend on `gaoxy_proxy`. HTTP Fetch 0.19.0 confirms request cleanup through its
public completion handle. M2's remaining blocker is raw-target identity:
[#64](https://github.com/gsmlg-dev/http_fetch/issues/64) drops a present empty query.
Per-request `stream_response: true` avoids a global streaming threshold.
These dependencies add no H2/H3 server support.

Native endpoints can call `Exchange.read_body_step(exchange, credit, wait_ms)`
with positive credit and finite nonnegative wait. It returns `{:more, bytes, next}`,
`{:ok, bytes, next}`, `{:pending, next}` or `{:error, reason, next}`. Preserve `next`
on every result; waiting does not renew the request deadline. The existing blocking
Plug body reader retains its API. `Exchange.poll_connection(exchange, wait_ms)`
reserves and reads one byte to detect idle closure, retaining any input for the
next body read or pipelined request; it returns `:pending`, `:more` or `:error`
with the next exchange. Native writes obey both the current absolute deadline
and finite write timeout, including each output window of a larger chunk.
`HTTP1.Response.finish(exchange, trailers)`
completes a stream once; nonempty trailers require a validated `Trailer`
declaration, retain ordered duplicates and obey count/byte limits. HTTP/1.0 and
fixed-length responses cannot send trailers. An endpoint error after commitment
closes the connection without a successful terminal chunk or second response.

The optional native WebSock callback `gaoxy_close({code_or_nil, reason}, state)`
returns `{:ok, state}` before the server echoes peer Close. Ordinary WebSock
termination remains `terminate(:remote, state)`. A native callback result
`{:gaoxy_push, messages, {recipient, ref}, state}` delivers
`{:gaoxy_websocket_written, ref, result}` after local writes finish; only `:ok`
permits an upstream delivery acknowledgment. `{nil, ""}` preserves an empty Close.
