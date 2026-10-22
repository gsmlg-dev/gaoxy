# Native multiplexed WebSocket peers

These fixtures target Gaoxy's server-side RFC 8441 (H2/h2c) and RFC 9220 (H3)
WebSocket streams. G0 establishes peer/API compatibility only. It does not claim
that Gaoxy has implemented or passed any WebSocket-over-H2/H3 runtime case.

## Environment

Run from the worktree root. Keep the five direct dependency pins in
`requirements.txt` unchanged unless a reviewed compatibility change requires it.
The resolved transitive package versions belong in each execution receipt.

```sh
python3 -m venv .audit/m5/venv
.audit/m5/venv/bin/python -m pip install -r integration/websocket_multiplexed/requirements.txt
nix develop --command .audit/m5/venv/bin/python <peer-script> <arguments>
```

The runner needs Python with the five pinned peer dependencies, OpenSSL and
the prepared Mix build (or an explicitly supplied packaged release). No browser
or browser automation package is required. `wsproto` supplies the frame codec.

## Public peer APIs

| Peer | Audited public interface |
| --- | --- |
| `h2==4.3.0` | `H2Connection`, `H2Configuration`, `SettingCodes.ENABLE_CONNECT_PROTOCOL`, `remote_settings.enable_connect_protocol`, `send_headers`, `send_data`, `end_stream`, `receive_data`, `data_to_send`; events expose HEADERS, DATA and END_STREAM. |
| `hpack==4.1.0`, `hyperframe==6.1.0` | Pinned dependencies for H2's public header/frame handling. |
| `aioquic==1.2.0` | `QuicConfiguration`, `QuicConnection`, `H3Connection`, `Setting.ENABLE_CONNECT_PROTOCOL`, `sent_settings`, `received_settings`, `send_headers(..., end_stream=False)`, `send_data(..., end_stream=...)`, `handle_event`; QUIC application integration uses public asyncio connection/protocol APIs. |
| `wsproto==1.2.0` | `wsproto.connection.Connection(ConnectionType.CLIENT)` starts a frame session directly, without an H1 handshake. `send`, `receive_data`, `events` handle masked client text/binary frames, fragmentation across HTTP DATA, ping/pong and normal Close. Use this low-level connection after a successful extended CONNECT, rather than `WSConnection`'s H1 handshake. |

The offline H2 audit exchanged setting 8, CONNECT with `:protocol=websocket`,
200 HEADERS, DATA and END_STREAM between two Python state machines. The H3
audit checked its advertised setting and queued CONNECT/DATA/FIN through public
methods; it did not establish a QUIC connection. The frame audit checked masking,
text/binary, split input, ping/pong and orderly Close. These are fixture readiness
checks, separate from Gaoxy acceptance.

The selected Elixir 0.21.10 cohort exposes public
`QuicHttp3.Settings.enable_connect_protocol/0`, `encode/1`, `decode/1`,
`QuicHttp3.Control.new(:server, settings)`, `local_payload/1`, and
`receive_peer/3`. Public host stream operations are
`Abyss.QUIC.send_stream(handle, bytes, fin, opts)` and `read/3`, with
`events/3` and `operation_status/2` for their existing completion contract.
Gaoxy keeps control of the connection owner; fixtures must not use private
dependency actors. API evidence is recorded separately from real DATA/FIN
network execution.

## Evidence and later gates

G0 receipts and API scripts live in the task-local ignored
`.audit/m5/g0-peers/` directory. They preserve installed versions, commands,
exits, source hashes and initial failed attempts.
H2, h2c and H3 runners retain their independent protocol evidence. They must require nonzero executed cases, record negotiated transport,
and preserve PASS, FAIL, BLOCKED_ENV and NOT RUN distinctly.

Normal runtime cases cover valid handshakes, ordinary frames, application pushes,
two simultaneous WebSockets plus an HTTP sibling on one connection, bounded
upgraded lifetime, and orderly Close/END_STREAM/FIN. Fault injection, abnormal
disconnects, slow peers, pressure and sustained load remain outside this suite.

## H2 and h2c ordinary runner

After the selected Gaoxy source has compiled in the locked environment:

```sh
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' \
  .audit/m5/venv/bin/python integration/websocket_multiplexed/run.py --protocol h2 --evidence .audit/m5/h2
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' \
  .audit/m5/venv/bin/python integration/websocket_multiplexed/run.py --protocol h2c --evidence .audit/m5/h2c
```

The runner creates a unique evidence subdirectory for each attempt, generates a
local localhost certificate, and starts the native fixture with compilation
disabled. HTTPS leaves protocol selection and its budget at the HTTP facade's
defaults; h2c selects prior knowledge explicitly. Both enable extended CONNECT.
The TLS peer verifies the generated certificate and negotiated `h2` ALPN.

The exact required cases are `negotiation`, `setting-8`, `200-open-handshake`,
`two-websocket-streams`, `http-sibling`, `text`, `binary`, `split-data`,
`coalesced-data`, `ping-pong`, `selected-subprotocol`,
`server-push-while-idle`, `post-original-request-deadline`, `normal-close` and
`http-after-close`. All 15 must execute and pass; missing, duplicate and zero
cases fail. Both unsolicited pushes are received before the peer sends any
WebSocket frame. The entire normal exchange has a five-second deadline and
includes a message/pong after the original one-second HTTP request deadline.
The configured WebSocket lifetime is ten seconds.

A transparent fixture transport delegates the four WebSocket operations to the
native H2 transport and records its successful `websocket_open` call's actual
original, requested and accepted deadlines. It retains the original native
transport state. Server receipts correlate both stream IDs and the ordinary HTTP
siblings with one native connection, actual wire metadata and normal termination.
The runner then checks ordinary admission release and stops the owned fixture.
Source hashes, lock hashes, dirty diff digest, exact commands, environment,
versions, per-case outcomes, negotiated protocol, server events and shutdown
results are recorded. Fixture preparation/offline checks alone are not runtime
acceptance.

## Packaged native WebSocket runner

For each `h2`, `h2c` or `h3` profile, supply the exported release executable and
its checked source identity together:

```sh
.audit/m5peer/bin/python integration/websocket_multiplexed/run.py --protocol h3 \
  --release /path/to/extracted/bin/gaoxy --source-identity /path/to/source-identity.json \
  --evidence .audit/release-0.4.0/packaged-h3
```

This starts the existing native fixture through `bin/gaoxy eval`, using packaged
applications and the same 15 ordinary cases, Close and cleanup assertions. It
needs no Mix, development beams, Phoenix, Git checkout or browser. The receipt
checks the release version and records immutable source/archive/lock identities
and the executable hash. This is a trusted embedded native Endpoint fixture;
it does not activate WebSockets through standalone JSON configuration.

## H3 peer preparation

`h3_peer.py` exposes the same synchronous
`run(protocol, port, certificate=None, results=None)` entry point as the H2 peer,
with `protocol="h3"`. It also exposes `run_async` for an existing asyncio caller.
The caller supplies the verified local certificate and an optional results list;
completed case records remain in that list if a later case fails. Shared fixture
and runner H3 selection are integrated separately by the parent.

The H3 peer uses the same 15 required case names as H2/h2c. It verifies localhost
TLS and negotiated `h3`, receives server setting 8 before creating extended
CONNECT streams, and carries masked RFC 6455 frames inside public H3 DATA calls.
Both WebSockets, their labelled application pushes and the ordinary HTTP siblings
share one QUIC connection. Normal Close is followed by stream FIN. The ordinary
exchange has a five-second deadline, including the bounded original-request
deadline crossing. Fault injection, resets, deliberate credit exhaustion and load
profiles are not part of this runner.

`QuicConnectionProtocol` receives the public `QuicConnection` argument through
aioquic's supported protocol factory. The peer retains that argument and uses
public `H3Connection`, QUIC event, stream allocation, and protocol transmission
methods; it does not access dependency private attributes.

For the H3 fixture's receipt wrapper, the native exchange transport state is
`{owner, table, key, token}`. `key` is a `Gaoxy.QUIC.Stream` wrapping a public QUIC
stream handle; its wire stream ID is `key.handle.id`. Record `inspect(owner)` as
the connection identity and that integer stream ID, retaining the whole original
transport-state tuple for native operations. Record the original deadline at
endpoint dispatch and the actual requested/accepted deadlines around the
delegated native `websocket_open` call, as for H2. The post-deadline callback
receipt must correlate with the same stream ID. Do not serialize the table,
handle or token as a replacement for the native operation state.

Preparation evidence belongs in `.audit/m5/h3-peer-preparation/`. Offline API,
stream isolation and finite-wait checks are separate from runtime acceptance.
At preparation handoff, H3 WebSocket runtime acceptance is **NOT RUN**.

## Phoenix client checks

The ordinary Phoenix client gates are documented in
[phoenix_native](../phoenix_native/README.md). Browser automation entrypoints and
UI-only mount/click/upload/DOM/screenshot checks have been retired. Historical
acceptance evidence remains unchanged; it is not an executable prerequisite.
The independent `h2_peer.py` and `h3_peer.py` remain the native protocol peers.
