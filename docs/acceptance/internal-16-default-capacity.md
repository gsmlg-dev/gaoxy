# Persistent WebSocket implementation evidence

Date: 2026-10-25, Asia/Shanghai. Branch: `main`. Implementation baseline:
`76d76ef2c93e25dc46b8d96ee4b06e7fa349b617`.

Disposition: **H1/native size and H3 persistence are locally qualified; the
complete H1/H2/H3 product contract remains BLOCKED by
[hell#2](https://github.com/gsmlg-dev/hell/issues/2)**. Size and persistence are
one completion contract. Issue [#16](https://github.com/gsmlg-dev/gaoxy/issues/16)
remains open. The package version remains `0.12.2`; this work has not been
published or deployed.

See the [design](../designs/internal-16-caddy-default-alignment.md),
[implementation plan](../plans/internal-16-caddy-default-alignment.md) and
[current configuration contract](../websocket-limits.md).

## Dependency and source qualification

The updated root and Phoenix fixture locks select Abyss `0.10.0` and the
HTTP Fetch/QUIC `0.21.17` cohort (`http_core`, `http_fetch`, `http_runtime`,
`http_web_socket`, `elixir_quic`, `elixir_quic_http3`, `ex_ssl`). Direct root Hex
dependencies were checked with `mix hex.outdated` and were current.

[http_fetch#143](https://github.com/gsmlg-dev/http_fetch/issues/143) and
[abyss#6](https://github.com/gsmlg-dev/abyss/issues/6) are CLOSED. Released APIs
support `quic_options: [idle_timeout: :infinity]`, public `Abyss.QUIC.ping/2`
and authenticated peer/local/negotiated/effective idle metadata. Gaoxy uses
those APIs rather than dependency internals.

Hell remains at `59eed42b019ca41413d1b8cd7a7dc3e344bb93ee`, verified against
upstream `main`. Its public persistent timeout result is available to network
callbacks. H2 upgrade and final stream cleanup occur in GenServer callbacks;
there is no supported transition there to invalidate the inherited read-idle
timer and restore ordinary policy when the final WS ends. Feature request
`hell#2`, severity `blocker`, records that boundary. TODOs remain at the two H2
callsites. Neither private timer mutation nor a synthetic transport event was
used. H2 type validation and service-budget handoff changes do not establish
quiet persistence.

Local qualification used Linux x86_64, Elixir `1.18.5`, Erlang/OTP 28
(`erts-16.4.0.5`), OpenSSL `3.6.3`, Python `3.12.13`, aioquic `1.2.0` and h2
`4.3.0`. Source files were frozen before final verification; documentation and
local commits record the results afterwards. Commands, process exits and raw
logs remain under ignored `.audit/internal-16/`.

## Implemented behavior

- Omitted native frame/message/fragment-count/output-count/mailbox/lifetime and
  inactivity policies are infinite. Explicit finite application policies still
  apply. The adapter preserves omitted frame size for Gaoxy and preserves an
  explicit value, including exactly `10_000_000`; other adapters keep their own
  defaults.
- Classified admission leases separate bounded `transport_bytes` from observed
  `websocket_bytes`. Generic `max_bytes` and `max_state` do not cap WS messages,
  application state or output. Scalar ordinary leases retain their original
  shape; scalar updates to classified leases preserve retained WS ownership.
- Incremental decoding retains only bounded wire parser state. An iodata cursor
  sends bounded chunks without building a second full wire binary. Complete
  WebSock messages, application state, undispatched input events and pending
  output are observed retained memory, including assembly overlap. Total memory
  remains O(message + state + pending output), not O(transport staging).
- Callback result handoff ends the computation watchdog before output. Each
  bounded send owns a fresh finite deadline. Returning or raising terminate
  callbacks invalidate their watchdog before transport finish. Nonreturning
  callbacks and stalled outstanding sends remain bounded; close and drain keep
  their finite operations. Old request/callback tokens cannot expire the new
  owner.
- H1 uses the supported persistent timeout result. H3 advertises disabled local
  QUIC idle expiry and sends public PINGs when required by a finite peer idle
  policy. Empty ordinary H3 owners regain finite application idle policy;
  ordinary requests retain finite request/operation deadlines. This is not a
  claim of equivalence to the former packet-level QUIC idle policy.
- Phoenix `/socket`, `/live` and persistent fixture endpoints explicitly use
  public `websocket: [timeout: :infinity]`, preserving LiveView session
  `connect_info`. The adapter does not infer intent from Phoenix's 60-second
  value or hidden metadata. Existing Phoenix applications must configure this
  supported persistence option themselves.

The dedicated message-level `Gaoxy.Proxy.WebSocket` bridge retains its separate
bridge policies. This native WebSock/Phoenix work adds no opaque reverse-proxy
tunnel API and makes no unlimited-bridge claim.

## Reproductions and ordinary acceptance

The original native 300 KiB init reply and actual LiveView initial render each
executed **1 test, 1 failure** before the repair, receiving close `1011` instead
of the required data reply. Their actual failure logs are retained as
`native-baseline-red.log` and `phoenix-baseline-red.log`. Earlier fixture setup
errors were corrected before those RED runs and are not payload regressions.

Native default-capacity acceptance now executes **5 tests, 0 failures**:
300 KiB init output; exact 300 KiB, 2 MiB and 10,000,001-byte echoes;
10,000,001-byte output; 129 legal wire fragments; 129 valid output messages;
600 KiB application state with generic `max_state` at 128 KiB; repeated 200 KiB
transfers across finite reusable capacity; quiet H1 beyond ordinary 60 ms idle;
ping/pong and normal close. These measured sizes are evidence of removed
implicit cutoffs, not a claim of physically infinite memory.

Actual LiveView acceptance executes **1 test, 0 failures**, with 320 KiB initial
content, a serialized join reply of at least 313,781 bytes, exact rendered
content, heartbeat and normal close. It raises no frame/message/service budget.
Focused Phoenix configured-policy and compatibility acceptance executes
**12 tests, 0 failures**; the complete fixture is qualified separately below.

H3 independent-peer acceptance executes **2 tests, 0 failures**. After its
initial push, the persistent case remains quiet for 900 ms against the peer's
300 ms idle policy and ordinary empty-owner 200 ms idle. It then transfers and
exactly echoes 5,242,880 bytes and 307,200 bytes twice, and checks ping/pong,
close and HTTP siblings. Peer
connection/stream windows remain 64 KiB/16 KiB. Qlog verifies server
`max_idle_timeout=0`. The client transfer harness has a finite 30-second bound;
product callback/send deadlines are not extended.

Two earlier H3 development runs failed: Python masking inside the peer event
loop caused client idle expiry, then a whole-response 10-second harness bound
expired during a progressing upload. Wire preparation moved before connection
creation; the bounded test transfer deadline became 30 seconds after stream
offset evidence showed progress. Those failures remain in
`h3-transfer-diagnostic.txt` and are not reported as passing runs or server cap
defects.

Independent review also found undispatched coalesced input retention and an
incorrect successful write receipt after output rejection. Both were repaired;
the new controlled file executes **2 tests, 0 failures**, with separate mutation
runs proving each regression fails without its repair. Termination watchdog
regressions executed **22 tests, 2 failures** before the completion fix and
**22 tests, 0 failures** afterwards. The failures specifically showed live
callback timers after returning/raising terminate callbacks at transport finish.

## Verification ledger

The sole active app manifest is `scripts/check-repairs.py`; inventory reports
**95 active files, 145 retained files**, with exact scheduled counts of
**254 unit, 167 component, 130 protocol**. Retained specialist paths keep their
prior disposition. Unit tests do not open sockets; component/protocol execution
belongs to Linux E2E. No browser gate was added.

| Gate | Result | Evidence |
| --- | --- | --- |
| Inventory | PASS, exit 0 | `final-inventory.log` |
| Formatter and strict compile | PASS, both exit 0 | `final-format.log`, `final-compile.log` |
| Canonical unit | PASS, 254 executed, 0 failures, 0 excluded/skipped, exit 0 | `final-unit.log` |
| Canonical component | PASS, 167 executed, 0 failures, 0 excluded/skipped, exit 0 | `final-component.log` |
| Canonical protocol | PASS, 130 executed, 0 failures, 0 excluded/skipped, exit 0 | `final-protocol.log` |
| Complete Phoenix fixture | PASS, 24 tests, 0 failures, exit 0 | `final-phoenix.log` |
| Package staging regressions | PASS, 12 Python tests, exit 0 | recorded staging command |
| Built-package clean consumers | PASS, base 3/0, H3 2/0, HTTPFetch 2/0, production isolation and consumer release, exit 0 | `final-consumers.log` |
| Isolated vendor dispatch | PASS, 5 tests, 0 failures, exit 0 | command in `vendor/websock_adapter/GAOXY.md` |
| Offline vendor reconstruction | PASS: 8 upstream hashes, patch check/apply, 10 snapshot hashes | `SOURCE.json` and canonical `gaoxy.patch` |
| Focused H2/H3/API compatibility | PASS, 67 tests, 0 failures, exit 0 | `ws-incremental-h3-verification.txt` |
| Independent specification/code/ownership reviews | PASS for implemented scope, no remaining actionable findings | framing/H3 review by `ws_accounting`; common ownership review by `ws_incremental` |
| H2 connection-owner quiet persistence | BLOCKED_DEPENDENCY | `hell#2` remains open |
| Hosted CI, new-version publication, public artifact/downstream read-back | NOT RUN for this candidate | complete contract blocked |
| Deployment or production acceptance | NOT RUN | outside this task |

Root final commands use `ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test`:

```sh
python3 scripts/check-test-inventory.py
mix format --check-formatted
mix compile --warnings-as-errors
python3 scripts/check-repairs.py unit
python3 scripts/check-repairs.py component
python3 scripts/check-repairs.py protocol
python3 scripts/test-stage-hex-packages.py
python3 scripts/test-consumers.py
```

The complete Phoenix command runs from `examples/phoenix_native`:

```sh
PHOENIX_NATIVE_H3=1 ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test python3 ../../scripts/check-tests.py --seed 0 --max-cases 1
```

`PHOENIX_NATIVE_H3=1` keeps the compiled fixture application metadata consistent
with its conditional H3 dependency graph. Final gate commands and exits are
also stored in `final-gates.json`. Local success is not hosted CI or published
package evidence. H2 owner transition, its real-peer persistence/restoration
acceptance and complete-contract verification must finish before coordinated
publication or issue closure. No specialist pressure/slow-peer/soak slice or
excluded `http_fetch#97` requirement was reopened.

The frozen source-file receipt covers 492 non-Markdown files, combined SHA-256
`86a40d0ce491373c1d1087977b9b2d77b958db50d704e8ca7a9f635623caec89`.
`source-files.json` retains each path/hash; production and test files are checked
against it before the local commits. The existing vendor changelog is upstream
history; this acceptance record documents the unpublished change instead of
altering that history or creating release notes for a version not yet released.
