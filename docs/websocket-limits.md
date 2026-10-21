# WebSocket frame and message limits

Gaoxy 0.9.0 uses the configured `max_frame_size` as the message-size limit when
`max_message_size` is omitted. Gaoxy's own defaults remain 262,144 bytes (256 KiB).
WebSockAdapter supplies its own 10,000,000-byte frame default when the application
omits that option; this also becomes the selected message ceiling before the
service-budget clamp. Set the desired frame limit explicitly for Phoenix:

```elixir
# In the Endpoint:
socket "/live", Phoenix.LiveView.Socket,
  websocket: [max_frame_size: 16 * 1024 * 1024]

# In the Endpoint configuration:
config :my_app, MyAppWeb.Endpoint,
  adapter: Gaoxy.PhoenixAdapter,
  http: [port: 4000, limits: %{max_bytes: 128 * 1024 * 1024}]
```

The example permits a message up to 16 MiB, including the total payload of a
fragmented message. Each individual frame also has a 16 MiB ceiling. Protocol and
fragment-count validation continue to apply. Larger messages receive WebSocket
close code 1009.

The service admission budget remains authoritative: Gaoxy clamps both frame and
message limits to `div(limits.max_bytes, 4)`. Raising only the transport frame
limit does not raise that budget. Account for all concurrent connections and
application state when choosing the service budget; admission can reject work
before the nominal frame ceiling if the shared budget is already occupied.

Direct WebSock users can still choose an independent, lower message ceiling:

```elixir
WebSockAdapter.upgrade(conn, MyWebSock, state,
  max_frame_size: 1024 * 1024,
  max_message_size: 64 * 1024
)
```

An explicitly supplied `max_message_size` remains authoritative before the
service-budget clamp. Phoenix validates its transport options and does not
accept this Gaoxy-specific option; use `max_frame_size` for Phoenix transports.

## Phoenix application policies and LiveView composer acceptance

Phoenix-owned `log` and `code_reloader` transport options are accepted after
Phoenix applies their semantics. They do not change Gaoxy's wire limits;
unknown settings, unsupported compression and invalid numeric limits still fail.

For LiveView, configure the supported frame option on the `/live` socket:

```elixir
socket "/live", Phoenix.LiveView.Socket,
  websocket: [max_frame_size: 2_097_152, connect_info: [session: @session_options]],
  longpoll: false
```

An omitted message ceiling follows that frame ceiling. The service byte budget
still clamps both ceilings to one quarter of `limits.max_bytes`. Allow enough
capacity for form encoding and escaped outbound HTML as well as the plain text;
a 300KiB body of double quotes occupies about 900KiB in URL-encoded form and
1.8MiB as escaped textarea HTML. The scoped real LiveView regression uses a
16MiB service budget and 2MiB frame/message ceilings. It checks exact persisted
test-store bytes, HTTP reload, WebSocket rejoin, unfragmented/fragmented events,
outbound rendered content and configured oversize rejection. Consumers retain
their own application persistence and authorization acceptance.
