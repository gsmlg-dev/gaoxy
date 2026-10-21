# Mixed cleartext HTTP acceptance

Date: 2026-10-21, Asia/Shanghai. Implementation starts at
`ec1fead80884804de9ab662e311ebb9c1cfdaf60`, preserving the newer dependency
refresh beyond the reviewed 0.5.5 snapshot. Work is isolated in
`.trees/mixed-h2c` to preserve concurrent release preparation in the main
checkout. [Design](../designs/mixed-h2c.md) and
[implementation plan](../plans/mixed-h2c.md) define this feature's scope.

Feature commit after reconciliation: `930fba3abfeab48838d09aa4d838704c1259b746`,
based on concurrent 0.6.0 preparation `aaa613985b08edd146f393ddd48f65fd6f3665b2`.
The next feature release is **0.7.0**; all six own manifests and five
distributions are coordinated. The corrected vendor guide retains upstream
WebSockAdapter source version 0.6.0.

## Behavior

```elixir
Gaoxy.HTTP.start_link(
  endpoint: {MyEndpoint, []},
  transport: :tcp,
  protocols: [:http2, :http1],
  h2c: :prior_knowledge
)
```

Standalone JSON uses `"protocols": ["http2", "http1"]` and
`"h2c": "prior_knowledge"`. Phoenix passes the same atom options in `http:`.
These entry points share one native listener and existing endpoint/Plug/router
engines. Plain TCP defaults to H1; TLS retains ALPN. Protocol ordering, invalid
combinations and H2 host/budget validation remain enforced. HTTP Upgrade is
outside this feature.

The pure classifier compares the complete 24-byte preface, retaining at most
23 copied undecided bytes. First mismatch selects H1, complete match selects
H2, and selection never falls back after a parser error. The selected engine
receives the full carry and deciding delivery once, including preface and all
trailing bytes, after its existing ingress limit check. Detection creates no
H2 decoder/writer or frames.

One owner lease survives detection and selection with the same drain identity.
H2 grows that reservation before resource allocation and retains its separate
writer/stream accounting. Undecided drain closes promptly. Existing selected
request admission and owner-exit cleanup remain authoritative.

Detection starts at first input and expires after the minimum of header,
request and H2 frame timeouts, without renewal. H1's first header/request
budgets retain that timestamp; keep-alive successors retain existing timing.
H2 startup retains an absolute deadline and completes only on server SETTINGS
acknowledgment. Checks before replay and acknowledgment prevent an expired
startup from winning a queued-timeout race. The partial-frame timer remains
separate; stale detector tokens are explicitly consumed before H2 delegation.

## Executed evidence

Local environment: Elixir 1.18.5, OTP 28 / ERTS 16.4.0.5;
`ELIXIR_ERL_OPTIONS='+S 4:4'` unless recorded otherwise. Independent review used
`+S 2:2`. Python uses the pinned `.audit/h2peer` environment. Commands execute
in the isolated worktree. Counts below describe separate runs and overlap.

| Gate | Actual result |
| --- | --- |
| Classifier/configuration/lifecycle RED | Expected feature rejections and missing detector behavior recorded before implementation |
| Startup race RED | 25 executed, 2 expected failures: expired coalesced/late ACK incorrectly accepted before repair |
| Startup repair + existing H2 regressions | PASS: 73 tests, 0 failures, exit 0 |
| Native/Phoenix same-port and standalone routing | PASS: 8 tests, 0 failures, exit 0; explicit H1 plus independent Python h2 with both sockets open |
| Expanded ordinary exact-count gate | PASS: 207 tests, 0 failures/excluded/skipped, exit 0 |
| Focused existing body/H2/Plug/Phoenix/WebSocket compatibility | PASS: 84 tests, 0 failures, exit 0 |
| Independent specification then code review | PASS: no remaining actionable findings; independent fresh feature run 47 tests, 0 failures, exit 0 |
| Canonical formatting and whitespace | PASS: `mix format --check-formatted`, `git diff --check`, exit 0 |
| Packaging harness regressions | PASS: 9 tests, 0 failures, exit 0 |
| Strict production compile | PASS: `MIX_ENV=prod mix compile --warnings-as-errors`, exit 0 |
| Fresh final feature/configuration run after review | PASS: 47 tests, 0 failures, exit 0 |
| Standalone production assembly and mixed artifact smoke | PASS: core 3 transports, gateway 7 exchanges (5 on the mixed port), H3 3 checks; all exit 0. Pre-version candidate assembly identifies as 0.5.5; final publication assembly is separate. |
| Versioned 0.7.0 standalone assembly and smoke | PASS: core 3 transports, gateway 7 exchanges, H3 3 checks; [receipt](evidence/mixed-h2c/versioned-local-smoke.json) |
| Versioned package build and independent release-preparation review | PASS: five actual archives, 108 runtime payload files and 131 stable packaging inputs; [receipt](evidence/mixed-h2c/package-0.7.0/receipt.json). Coordinated versions, dependency metadata and vendor provenance verified. |
| Exact publication source, hosted CI, release and public artifact verification | PENDING |

Main verification commands:

```sh
ELIXIR_ERL_OPTIONS='+S 4:4' python3 scripts/check-repairs.py all
ELIXIR_ERL_OPTIONS='+S 4:4' python3 scripts/check-tests.py \
  apps/gaoxy_http/test/protocol_detector_test.exs \
  apps/gaoxy_http/test/mixed_connection_lifecycle_test.exs \
  apps/gaoxy_http/test/http_protocol_defaults_test.exs \
  apps/gaoxy_server/test/config_test.exs \
  apps/gaoxy_http/test/mixed_http_network_test.exs \
  apps/gaoxy_server/test/mixed_http_routing_test.exs --seed 0 --max-cases 1
ELIXIR_ERL_OPTIONS='+S 4:4' python3 scripts/check-tests.py \
  apps/gaoxy_http/test/http1_body_test.exs \
  apps/gaoxy_http/test/http2_network_test.exs \
  apps/gaoxy_http/test/http2_pre_settings_test.exs \
  apps/gaoxy_http/test/http2_protocol_test.exs \
  apps/gaoxy_http/test/phoenix_websocket_test.exs \
  apps/gaoxy_http/test/websocket_network_test.exs \
  apps/gaoxy_http/test/websocket_stream_test.exs \
  apps/gaoxy_http/test/plug_body_network_test.exs \
  apps/gaoxy_http/test/phoenix_adapter_test.exs --seed 0 --max-cases 1
```

Live coverage includes all 23 nonterminal preface split positions, H1 deciding
headers/body/pipeline bytes, coalesced H2 preface/SETTINGS/HEADERS/DATA, actual
version metadata, exactly-once endpoint/body messages, no H2 output before
selection, persistent connections on the same port, no fallback on H2 errors,
fixed timer identity, and zero retained bytes/leases after peer closure.
Lifecycle cases cover reservation denial before writer allocation, runtime
host and budget rejection, stale detector messages, finite idle behavior,
original first-engine budgets, and drain/close/error/shutdown cleanup.

## Preserved wider baseline failure

**FAIL, separately reproduced on the baseline:**
`apps/gaoxy_http/test/http_network_test.exs:351`, "one large client write
streams through a smaller parser buffer", expects body `2000` but receives
HTTP 500 with a 4096-byte service budget. The wider run executed 104 tests with
one failure. A separate in-memory compilation of the exact baseline connection
module reproduced the same failure: one selected test executed, one failed,
26 explicitly excluded by the line selector. No assertions or production code
for that unrelated body-copy reservation issue were changed.

That test uses omitted protocols/H1-only defaults and never enters detection.
Independent review found no feature causality. Its FAIL status remains visible;
the curated ordinary 207-case gate and focused affected compatibility runs are
separate PASS results. Specialist disconnect/blocked-upload/slow-peer/pressure/
load/soak and combined qualification, `http_fetch#97`, deployment, production
operations, Vault, public management and disabled release-artifact E2E are
**NOT RUN**, outside this feature. No cross-platform portability claim follows
from the local Linux verification.

## Review and repair record

The first independent specification review identified the expired H2 startup
race. One production Sol repair added the absolute startup deadline checks and
two deterministic regressions; RED and GREEN evidence preserves the original
assertions. One earlier fixture-only repair corrected iodata concatenation in
new tests. A fresh independent agent then completed specification and code
reviews with no findings and ran all 47 feature/configuration cases. Astra
recovery rounds: zero.

Independent review of the rebased feature, versioned package contents and smoke
receipts also passed. Its sole documentation finding was corrected before the
version commit: future publication receipts are described as pending until
actually recorded. No runtime or package input changed during that correction.

Raw logs and source receipts are preserved in
[feature evidence](evidence/mixed-h2c/manifest.json). Initial logs preserve
fixture and baseline failures separately from successful reruns. Publication
receipts will bind the final commit, tag and downloaded artifacts separately
from the local implementation evidence.
