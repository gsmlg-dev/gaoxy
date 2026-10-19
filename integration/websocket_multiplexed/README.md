# Native multiplexed WebSocket peers

These fixtures target Gaoxy's server-side RFC 8441 (H2/h2c) and RFC 9220 (H3)
WebSocket streams. G0 establishes peer/API compatibility only. It does not claim
that Gaoxy has implemented or passed any WebSocket-over-H2/H3 runtime case.

## Environment

Run from the worktree root. Keep the six direct dependency pins in
`requirements.txt` unchanged unless a reviewed compatibility change requires it.
The resolved transitive package versions belong in each execution receipt.

```sh
python3 -m venv .audit/m5/venv
.audit/m5/venv/bin/python -m pip install -r integration/websocket_multiplexed/requirements.txt
nix develop --command .audit/m5/venv/bin/python <peer-script> <arguments>
```

The G0 environment uses Python 3.13.15 at
`.audit/m5/venv/bin/python`. On this NixOS host, use the existing project Nix
shell for Playwright: outside it, `playwright.sync_api` cannot load
`libstdc++.so.6`. The six pinned packages installed successfully, and the
three offline API checks executed successfully. No separately installed
`websockets` package is needed; `wsproto` provides the frame codec directly.

## Public peer APIs

| Peer | Audited public interface |
| --- | --- |
| `h2==4.3.0` | `H2Connection`, `H2Configuration`, `SettingCodes.ENABLE_CONNECT_PROTOCOL`, `remote_settings.enable_connect_protocol`, `send_headers`, `send_data`, `end_stream`, `receive_data`, `data_to_send`; events expose HEADERS, DATA and END_STREAM. |
| `hpack==4.1.0`, `hyperframe==6.1.0` | Pinned dependencies for H2's public header/frame handling. |
| `aioquic==1.2.0` | `QuicConfiguration`, `QuicConnection`, `H3Connection`, `Setting.ENABLE_CONNECT_PROTOCOL`, `sent_settings`, `received_settings`, `send_headers(..., end_stream=False)`, `send_data(..., end_stream=...)`, `handle_event`; QUIC application integration uses public asyncio connection/protocol APIs. |
| `wsproto==1.2.0` | `wsproto.connection.Connection(ConnectionType.CLIENT)` starts a frame session directly, without an H1 handshake. `send`, `receive_data`, `events` handle masked client text/binary frames, fragmentation across HTTP DATA, ping/pong and normal Close. Use this low-level connection after a successful extended CONNECT, rather than `WSConnection`'s H1 handshake. |
| `playwright==1.56.0` | Explicit system Chromium executable selection, browser launch, normal page actions and CDP receipt collection. |

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

## Browser selection

G0 launched `/run/current-system/sw/bin/chromium`, Chromium
`152.0.7977.64`, headlessly through the pinned Playwright package. Its underlying
browser revision is `506c834ecceaa943c5f41e6cfe7f68acb5c45346`.
This browser contains H2 and H3 WebSocket handshake implementations. The matching
[Chromium source](https://github.com/chromium/chromium/blob/152.0.7977.64/net/base/features.cc)
defines `kEnableWebsocketsOverHttp3` as disabled by default. The audited launch
configuration is:

```python
browser = playwright.chromium.launch(
    executable_path="/run/current-system/sw/bin/chromium",
    headless=True,
    args=["--enable-quic", "--enable-features=EnableWebsocketsOverHttp3"],
)
```

G4 must use verified local certificates, record complete feature/QUIC routing
settings, and correlate each successful WebSocket's unique marker with the native
server's wire method, `:protocol`, HTTP version and stream identity. An HTTP
page's CDP protocol, an accepted command-line flag, or a JavaScript WebSocket event
does not establish the WebSocket transport. H1 fallback cannot pass H2/H3 rows.
G0 browser H2/H3 WebSocket negotiation is **NOT RUN**.

## Evidence and later gates

G0 receipts and API scripts live in the task-local ignored
`.audit/m5/g0-peers/` directory. They preserve installed versions, commands,
exits, source hashes, initial failed attempts and the corrected browser settings.
Later H2, h2c, H3 and browser runners belong to their respective implementation
tasks. They must require nonzero executed cases, record negotiated transport,
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

## Phoenix browser runner

`browser.py` owns a separate browser fixture process using the existing
`examples/phoenix_native` Endpoint, RoomChannel and CounterLive. It does not
compile the fixture or dependencies. Run it only after the parent coordinates
the fixture/source build and the corresponding native peer gate passes:

```sh
nix develop --command .audit/m5/venv/bin/python integration/websocket_multiplexed/browser.py \
  --protocol h2 --native-peer-report .audit/m5/h2/run-ATTEMPT/report.json --evidence .audit/m5/browser-h2
nix develop --command .audit/m5/venv/bin/python integration/websocket_multiplexed/browser.py \
  --protocol h3 --native-peer-report .audit/m5/h3/run-ATTEMPT/report.json --evidence .audit/m5/browser-h3
nix develop --command .audit/m5/venv/bin/python integration/websocket_multiplexed/browser.py \
  --protocol http1 --evidence .audit/m5/browser-http1
```

Each attempt starts `mix run --no-start --no-compile` from the Phoenix fixture
directory with the absolute `browser_fixture.exs` path. H2 uses the managed
Phoenix adapter with HTTPS protocol defaults; the H1 row selects H1 explicitly.
H3 sets Endpoint `server: false`, explicitly runs the native wrapper's
duplicate-listener guard, and mounts it through the optional H3 service.
A fixture-only adapter/observer preserves initialized native Plug state and
records accepted upgrade metadata without changing application behavior.

The browser trusts only the generated fixture certificate's SPKI. H2 disables
QUIC; H3 enables `EnableWebsocketsOverHttp3` and forces QUIC for the specific
localhost origin. The existing qualified native peer provides separate verified
TLS/protocol evidence. An init script subclasses the native WebSocket
constructor, appending a different `m5_ws` marker to every actual URL while
retaining normal frame and Close behavior.

Required cases are the initial page, LiveView connected mount/click/upload,
Channels join/ping, an actual Endpoint PubSub broadcast received by the channel,
WebSocket transport correlation, ordinary Origin policy rejection, normal
WebSocket Close, admission release and
fixture shutdown. Successful browser WebSocket URLs must match native upgrade
receipts with their marker, wire method, `:protocol`, HTTP version, stream and
connection identity. The page's CDP protocol is additional context, not the
WebSocket transport verdict. Every opened socket must use the selected protocol;
H1 fallback cannot pass an H2/H3 row.

A sandboxed `srcdoc` iframe under the trusted local page attempts the actual
Channels WebSocket endpoint. Its sandbox allows scripts without allowing the
same origin, retaining opaque `Origin: null` in a local address-space context.
A normal no-CORS HTTP fetch first establishes its selected transport connection.
It must observe a browser error without opening, correlated by a unique marker
with exactly one native Phoenix 403 refusal and `Origin: null`. Its wire protocol
is recorded separately; it does not qualify the successful transport row. Only
this validated expected refusal is excluded from native upgrade error reporting.
Existing Origin, session, CSRF and early upgrade validation stay enabled.

Both Phoenix clients use their public Phoenix Socket disconnect API with
code 1000 before the browser context closes. After the LiveView Socket confirms
disconnection, public `LiveSocket.disconnect` also completes its listener/timer
cleanup before screenshots and admission checks.
The fixture then reports zero admission resources and a confirmed runtime DOWN.
Attempts retain exact commands, runtime/peer/browser settings, source and lock
hashes, complete native events, case counts, page errors, HTML and screenshots.
A demonstrated transport mismatch is `BLOCKED_ENV` only when a passing native
peer report for that protocol is supplied and the application has no native
upgrade error/refusal. Functional failures remain `FAIL`; incomplete cases remain
`NOT RUN`. Preparation checks do not establish browser acceptance.

The browser matrix uses one fixture build with `PHOENIX_NATIVE_H3=1` for
all profiles. Keep that dependency selection during compilation and execution;
Mix application metadata otherwise retains optional dependency entries from the
previous build. H2/H1 profiles still create only their selected native TLS listener.
Standalone consumer scripts separately verify optional QUIC isolation.

For forced H3, Chromium resolves `localhost` explicitly to `127.0.0.1`,
matching the fixture UDP bind. The runner records this process-local resolver
rule with the QUIC feature and certificate SPKI pin.

The H3 fixture initially exposes only UDP so Chromium establishes both accepted
WebSockets over H3. After strictly correlating those sockets, a control command
adds native H1/TLS on the same numeric port for the opaque-Origin policy check,
which Chromium may send over TCP. Both listeners use the same guarded Endpoint
and Gaoxy runtime; admission checks include both services. The final correlation
still requires every opened WebSocket to use H3. This controlled browser profile
qualifies H3 support, without claiming automatic H3 selection when TCP is also
available.

The runner first visits the ordinary local `/` page and waits for network idle
before loading the application page. Chromium's initial certificate configuration
updates can retire reusable H2/QUIC sessions; Chromium uses existing eligible
sessions for multiplexed WebSockets and may otherwise choose H1. Each attempt
records this startup navigation and the default-capture Chromium `netlog.json`.
Priming is preparation, without a guarantee against later browser configuration
changes. Actual socket correlation remains required; a page using H2 does not
guarantee its WebSockets will use H2.
