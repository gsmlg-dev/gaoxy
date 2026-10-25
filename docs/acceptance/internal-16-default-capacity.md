# Persistent WebSocket implementation evidence

Date: 2026-10-25, Asia/Shanghai. Branch: `main`. Implementation baseline:
`76d76ef2c93e25dc46b8d96ee4b06e7fa349b617`.

Disposition: **H1/H2/H3 implementation, focused qualification and all 568
canonical tests, core package/runtime checks and final independent H3 client
qualification pass; 0.13.0 publication is in progress**. The upstream gate
[hell#2](https://github.com/gsmlg-dev/hell/issues/2) is CLOSED and released Hell
0.1.3 is installed. Size and persistence remain one completion contract. Issue
[#16](https://github.com/gsmlg-dev/gaoxy/issues/16) remains open until coordinated
publication and independent public checks complete. No deployment is included.

See the [design](../designs/internal-16-caddy-default-alignment.md),
[implementation plan](../plans/internal-16-caddy-default-alignment.md) and
[current configuration contract](../websocket-limits.md).

## Initial dependency and source qualification (historical `90e75ed5`)

The updated root and Phoenix fixture locks select Abyss `0.10.0` and the
HTTP Fetch/QUIC `0.21.17` cohort (`http_core`, `http_fetch`, `http_runtime`,
`http_web_socket`, `elixir_quic`, `elixir_quic_http3`, `ex_ssl`). Direct root Hex
dependencies were checked with `mix hex.outdated` and were current.

[http_fetch#143](https://github.com/gsmlg-dev/http_fetch/issues/143) and
[abyss#6](https://github.com/gsmlg-dev/abyss/issues/6) are CLOSED. Released APIs
support `quic_options: [idle_timeout: :infinity]`, public `Abyss.QUIC.ping/2`
and authenticated peer/local/negotiated/effective idle metadata. Gaoxy uses
those APIs rather than dependency internals.

Hell then remained at `59eed42b019ca41413d1b8cd7a7dc3e344bb93ee`, verified against
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

## Initial verification ledger (historical `90e75ed5`)

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
altering that history. Subsequent 0.13.0 release notes live at
`docs/releases/0.13.0.md`.

## Resumed H2 implementation and 0.13.0 qualification

Baseline: `f2ba26ab6319d0e81da5ff2eb40724d1c170c050`, including the separate #17
repair. Hell 0.1.3 source is
`4fb5d53a1b2acfb5afc9b1ceba65fdc52d61ef83`; its published tag and Hex release
were verified before integration. Root and Phoenix fixture locks select this
source. Staging maps that exact source to required Hex `== 0.1.3`. Plug.Crypto
is updated to compatible 2.2.1 in both locks; the Abyss/HTTP/QUIC cohort above
remains current. All six Gaoxy packages and standalone are versioned 0.13.0.

H2 captures the original host read-idle interval at startup. Opening/open WS
owners select infinity; cleanup after the final owner restores that exact
interval. Call/info transitions retain the updated socket from public
`Hell.Handler.set_read_timeout/2`; network continuations use supported persistent
results. Hell invalidates old timer tokens. An unchanged ordinary policy is not
restarted on arbitrary local messages. Partial-frame assembly and explicit
application lifetime remain finite, and #17 classification is preserved.

Evidence under `.audit/internal-16-h2/` retains semantic component RED **6 tests,
4 failures** and protocol RED **3 tests, 1 failure**. Final focused GREEN executes
**47 tests, 0 failures**: idle-owner 6, wire 4, configured policies 6, common
stream 22 and startup-close 9. Additional ordinary H2 compatibility executes
**7 tests, 0 failures, 76 excluded**; it is scoped evidence, not a whole-file
pass. Real peers verify quiet 600 ms beyond ordinary 200 ms idle, exact
300 KiB / 2 MiB / 300 KiB transfers, ping, HTTP siblings, normal close and idle
restoration. Separate controls preserve a 100 ms partial-frame deadline and
100 ms explicit WS lifetime. Independent specification/code/ownership review
found no actionable runtime findings.

The active manifest now schedules **254 unit / 181 component / 133 protocol**
cases across **98 active files / 145 retained files**. New H2 idle cases are
component tests; real peers remain protocol tests. No specialist slice was run.
Final root commands use `ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test`; raw logs and
exits are in `.audit/release-0.13.0/final-gates.json`:

| Integrated 0.13.0 gate | Result |
| --- | --- |
| Inventory, full formatter, strict compile | PASS, all exit 0 |
| Canonical unit | PASS, 254 executed, 0 failures/excluded/skipped, exit 0 |
| Canonical component | PASS, 181 executed, 0 failures/excluded/skipped, exit 0 |
| Canonical protocol | PASS, 133 executed, 0 failures/excluded/skipped, exit 0 |
| Mocked Python script unit gates | PASS, all four commands exit 0 |
| Isolated vendor dispatch | PASS, 5 tests, 0 failures, exit 0 |
| Packaging regression, Hex 2.6 | PASS, 12 tests, 0 failures, exit 0 |
| Packaging compatibility, Hex 2.5.4 | PASS, affected case 1 test, 0 failures, exit 0 |
| Complete Phoenix fixture | PASS, 24 tests, 0 failures, exit 0 |
| Built-package clean consumers | PASS, base 3/0, H3 2/0, HTTPFetch 2/0; production isolation/release pass, exit 0 |
| Direct dependency freshness and security audit | PASS, both exit 0; all direct Hex packages current, no retired/advisory package |
| Production strict compile and standalone build | PASS, both exit 0 |
| Standalone TCP/TLS/UDP smoke | PASS, 3 transports, orderly drain/exit and endpoint reuse, exit 0 |
| Standalone H1/H2 gateway smoke | PASS, 7 exchanges, exit 0 |
| Initial standalone H3 smoke | FAIL, exit 1; independent aioquic peer self-expires while awaiting response |
| Conforming standalone H3 peer | PASS, 3 checks; exact responses/trailers, orderly exits and port reuse, exit 0 |
| Unified Phoenix H1/H2/H3, WebSockets and reload | PASS, all 8 checks, source restored and fixture exit 0 |
| Native Phoenix HTTP/TLS clients | PASS, all 10 checks, source restored and fixture exit 0 |
| Independent peer wrong-CA control | PASS, certificate rejected; subsequent positive scenario passes 3 checks |

The first resumed packaging command executed **12 tests, 1 failure**: its fixture
expected an owner API lookup on `mix hex.publish --dry-run --yes`. Hex 2.6 skips
that lookup with `--yes`. The test keeps that automated dry run, additionally
executes an explicitly confirmed interactive dry run, and preserves all positive
owner-lookup, immutable-package and no-upload assertions. No production change
or upstream workaround was needed. Original/reproduced failures and compatible
green runs remain in `package-staging.log` and `diagnosis-staging-*`.

### H3 release peer diagnosis and replacement

The original packaged H3 smoke and an unchanged reproduction fail. An
observation-only trace shows aioquic 1.2.0 receiving remote
`max_idle_timeout=0`, with local idle 60 seconds, then calculating approximately
96 ms (three PTO). After the static GET completed at 2.1506 seconds, the same
client began the trailer-bearing POST at 2.1507 seconds and fired its own idle
timer at 2.2551 seconds. The origin received the complete zero-body request,
both trailers and exactly one FIN. This proves request forwarding, not response
completion. The failure does not establish a Gaoxy defect or a passing H3 gate.

[RFC 9000 section 10.1](https://www.rfc-editor.org/rfc/rfc9000#section-10.1)
requires the sole nonzero advertised timeout in this case. The same zero-value
calculation remains in the official aioquic 1.7.0 release and upstream main;
upgrading the test dependency alone has no evidenced fix. Independent review
confirmed the diagnosis. Original `local-h3/`, `final-h3-release-smoke.log` and
`diagnosis-h3-*` evidence remains unchanged under `.audit/release-0.13.0/`.

The user explicitly chose replacement with a conforming independent H3 client
on 2026-10-25. The same old peer defect also failed the unified Phoenix H3
GET after source reload, after six checks had passed; the fixture exited 0 and
restored its source. Earlier local setup attempts lacked `wsproto` and then
the UV-managed venv's `pip` module; installing the declared requirements with
`uv pip` resolved setup without source changes. Those commands and failures
remain recorded separately from the actual protocol failure and passing run.

The packaged smoke's downstream client and the unified fixture's ordinary H3
GETs now use the independent Rust `h3`/Quinn/rustls client in
`integration/http3/release_peer/`. Dependencies are pinned in Cargo.toml and
Cargo.lock. The shared Python helper builds with `--locked`, with a separate
600-second preparation bound before scenario startup. Each request retains its
5-second bound; the release peer/scenario retain 15/90 seconds. Released Quinn
correctly handles a zero peer idle value through its public transport API.

The original independent origin and all certificate,
ALPN, exact byte/trailer, FIN, response, deadline, exit and endpoint-reuse
assertions remain. The two packaged requests share one real connection and use
distinct stream IDs. The new peer returns actual response receipts for Python
validation; it rejects an unrelated CA with `BadSignature`. Generic GET and
full release scenarios passed; final parent gates pass **8/8 unified**, **10/10
native clients** and **3/3 packaged H3**, including clean processes and source
restoration. Receipts are `local-unified-quinn/report.json`,
`local-phoenix-clients/manifest.json`, `local-h3-quinn/result.json` and
`quinn-gates.json`. A first peer receipt used HTTP's `200 OK` display text;
the unchanged numeric-status assertion rejected it. That failure is preserved;
the peer now serializes the actual public `status.as_u16()` value. No assertion
or network deadline was relaxed. Gaoxy server behavior is unchanged by this
test-client repair. Independent specification/code/ownership review approved
the peer and both integrations with no actionable findings. Fresh
post-review commands and their outcomes are recorded in
`post-review-gates.json`. Coordinated
publication and independent public read-back remain required.

A fresh post-review repeat exposed the same aioquic zero-idle failure in the
remaining H3 WebSocket client before the channel check completed. Earlier
protocol paths, H2 Channels and H2 reload passed; the fixture exited 0 and
restored its source. This executed failure remains in
`post-review-unified/report.json` and `post-review-unified.log`; the 8/8 result
above is the earlier passing run. Under the same user decision, the remaining
WebSocket path now uses quic-go 0.64.1's public extended CONNECT API, built with
Go 1.26.6. It verifies the real CA and hostname, negotiated H3, server SETTINGS,
the two original Channels replies, close 1000 and subsequent receive-stream EOF.
All channel operations share the original five-second case deadline. The
independent finite-fixture reader bounds its own frame/message/control storage;
these test-client bounds do not change server policies or capacity assertions.

Independent review found and corrected an allocating convenience reader and a
reset per-operation timeout in the first Go implementation. Eleven temporary
reader regression cases, readonly Go build/vet and formatting pass. Final
post-review parent commands on 2026-10-26 (Asia/Shanghai) pass inventory,
formatter, strict compile, all 12 staging tests, **8/8 unified checks** and
**3/3 packaged H3 checks**. The unified fixture restores its source and exits 0;
the packaged smoke verifies both child exits and endpoint reuse. Exact receipts
are `final-peer-replacement-gates.json`, `final-conforming-unified/report.json`,
`final-conforming-h3/result.json` and
`diagnosis-h3-go-reader/verification.json`. Service sources still match the
frozen 568-case canonical qualification; the replacement changes test clients
and their workflow toolchain setup. Coordinated publication and independent
public read-back remain required before issue closure.

### Hosted source qualification follow-up

The first publication candidate, `e7d294d02039b1908d7f003ad7dcd15312566157`,
passed static/build, unit, portable and source E2E workflows. Package workflow
`40210792153` failed in two independent consumers before any publication:

- The optional QUIC consumer's committed lock still selected Abyss 0.9.0 and
  the old Hell source. Its exact `mix deps.get --check-locked` failure was
  reproduced. Supported resolution updates exactly four entries: Abyss 0.10.0,
  Hell 0.1.3's source, and `elixir_quic`/`ex_ssl` 0.21.17. Locked resolution and
  strict compile now pass; a fresh isolated build executes **4 tests, 0
  failures**. The initial local stale-build setup failure executed zero tests;
  that evidence and the original build directory remain preserved.
- The built H3 consumer still copied the aioquic GET/upload peer. Hosted
  execution reported **2 tests, 1 failure**, with the same self-generated idle
  timeout. Unchanged local execution passed **2 tests, 0 failures**. A controlled
  local diagnostic retaining its assertions and adding a 1.2-second quiet gap
  between requests reproduces the timeout: remote idle 0, local idle 60 seconds,
  effective idle approximately 0.561 seconds. Earlier diagnostic setup and
  non-echo-stub errors remain separate from this reproduction.

The existing shared Rust peer now also supports the consumer's original GET
and POST on one connection, preserving authority `localhost`, the exact
73,728-byte payload, 4,096-byte DATA chunks, content length, real FIN/EOF, CA,
hostname, ALPN, status and body assertions. Its requests retain eight-second
bounds and the Python process retains the original 20-second bound. Both source
and built/published consumer entrypoints prepare this test-only peer before
starting their fixture. Runtime dependency-isolation and cleanup assertions are
unchanged; neither the product nor package dependencies acquire a client.

Independent source review approves these changes. Fresh complete built-package
consumers pass base **3/0**, H3 **2/0**, HTTPFetch **2/0**, plus production
dependency isolation and consumer release. The isolated source H3 consumer also
passes **2 tests, 0 failures**, including dependency isolation and endpoint reuse.
The shared peer's earlier modes
also pass fresh unified **8/8** and packaged H3 **3/3** checks. Receipts are
`ci-consumer-quinn-green.json`, `ci-consumer-final-gates.json`,
`consumer-final-unified/report.json`, `consumer-final-h3/result.json` and
`optional-quic-lock/summary.json` and `ci-source-h3-consumer-green.json`;
original hosted logs are retained as
`ci-e7d294d0-package-failed.log`. These local repairs require a new exact-source
hosted qualification before publication.
