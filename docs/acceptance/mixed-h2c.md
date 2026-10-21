# Mixed cleartext HTTP acceptance

Date: 2026-10-21, Asia/Shanghai. Implementation starts at
`ec1fead80884804de9ab662e311ebb9c1cfdaf60`, preserving the newer dependency
refresh beyond the reviewed 0.5.5 snapshot. Work is isolated in
`.trees/mixed-h2c` to preserve concurrent release preparation in the main
checkout. [Design](../designs/mixed-h2c.md) and
[implementation plan](../plans/mixed-h2c.md) define this feature's scope.

Feature commit after reconciliation: `930fba3abfeab48838d09aa4d838704c1259b746`,
based on concurrent 0.6.0 preparation `aaa613985b08edd146f393ddd48f65fd6f3665b2`.
The feature release is **0.7.0**; all six own manifests and five
distributions are coordinated. The corrected vendor guide retains upstream
WebSockAdapter source version 0.6.0.

[PR #2](https://github.com/gsmlg-dev/gaoxy/pull/2) merged normally as
`14287f30b83ccec207ffc944867413043cb8f360`. Its parents preserve the completed
0.6.0 evidence commit `e536fc9e81a6eec9a8568f7c0f1bf23154af6455` and reviewed
feature/CI head `2a096b7db1a4e52d7296c7c65cc1c94fb26cc647`. The remote merge
tree matches the prevalidated tree `87ba24ff20c206194f254c073873f2f6c7f2573c`;
all 131 qualified packaging inputs remain byte-identical. Both local checkouts
were fast-forwarded to the merge; the untracked `prompt.md` is preserved.

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
| Hosted PR CI with corrected API head `2a096b7d` | PASS: Unit 180 tests on each Linux/macOS platform; Static all 3 jobs; Foundation all 5 jobs, including native HTTP 207 cases, Phoenix ownership 5 cases, browser, external consumer and portable release checks. Actual synthetic checkout `c46c99ff` has the same tree as the API head. Both push runs also passed. |
| Exact merged-main CI on `14287f30` | PASS: Unit `39554903610` (2 jobs), Static `39554903614` (3 jobs), Foundation `39554903599` (5 jobs), including both portable platforms; all 10 jobs successful. |
| Exact publication-source workflow | PASS: release run `39555029237` on merged source `14287f30`; native HTTP 207 tests, packaging 9 tests, core 3 transports, gateway 7 exchanges (5 mixed), H3 3 checks; zero failures. |
| Public GitHub/Hex downloads and package payloads | PASS: 7 assets, 6 checksum entries, 5 public Hex packages; source/tag/run identity, GitHub/Hex byte equality and immutable source/local payload-metadata comparison verified. |
| Downloaded standalone on local NixOS | PASS with explicit existing host library path: version 0.7.0, core 3 transports, gateway 7 exchanges (5 mixed), H3 3 checks. The initial missing-`libtinfo.so.6` startup FAIL remains preserved separately. |
| Clean public Hex consumers | PASS: core 1 + HTTP 4 + Phoenix 5 = 10 executed tests, zero failures/exclusions/skips; all 37 commands exit 0, exact 0.7.0 own packages, isolated dependency/build/cache paths and unchanged accepted upstream locks. |

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

The first hosted PR unit run (`39551788377`, source `1be0f0fb`) passed on
Ubuntu but failed two TLS configuration fixtures on macOS because its selected
OpenSSL was 1.1.1w. The classifier and lifecycle files passed before that setup
failure. The unit workflow now provisions OpenSSL 3 and exports `OPENSSL_BIN`
using the established portable-workflow step. The original hosted failure is
retained separately. Fresh corrected-head unit run `39553035130` passed all
180 cases on both platforms; static run `39553035149` and foundation run
`39553035150` also passed in full. No runtime, package payload or test assertion
changed in that CI repair.

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
fixture and baseline failures separately from successful reruns.

## Publication and independent consumption

[Gaoxy v0.7.0](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.7.0) was
published by [release workflow 39555029237](https://github.com/gsmlg-dev/gaoxy/actions/runs/39555029237)
from `14287f30b83ccec207ffc944867413043cb8f360`. The tag resolves to that
exact commit. All five distributions are publicly available at version 0.7.0:
[gaoxy](https://hex.pm/packages/gaoxy/0.7.0),
[gaoxy_http](https://hex.pm/packages/gaoxy_http/0.7.0),
[gaoxy_http3](https://hex.pm/packages/gaoxy_http3/0.7.0),
[gaoxy_proxy](https://hex.pm/packages/gaoxy_proxy/0.7.0), and
[gaoxy_websock_adapter](https://hex.pm/packages/gaoxy_websock_adapter/0.7.0).

The [publication receipt](evidence/mixed-h2c/publication/verification.json)
binds all seven downloaded assets, six checksum entries, public Hex metadata,
source payloads and the actual release workflow. GitHub and public Hex package
bytes agree. Locally built tar bytes may differ; normalized package payloads
and metadata agree with the qualified local artifacts and immutable Git source.
The standalone asset's SHA-256 is
`b85128c90dd319563398dd6ab58c32fc32574d34fc27f84e6a9ae18210126283`.
[Artifact](https://github.com/gsmlg-dev/gaoxy/releases/download/v0.7.0/gaoxy-0.7.0-linux-x86_64.tar.gz)
and [checksums](https://github.com/gsmlg-dev/gaoxy/releases/download/v0.7.0/SHA256SUMS)
are attached to the release. Binary downloads and expanded builds stay in the
audit directory; compact receipts, tools and lossless logs are archived.

The [downloaded runtime receipt](evidence/mixed-h2c/downloaded-runtime/final/verification.json)
records actual execution of that unmodified archive. Its initial startup on
NixOS failed because the default loader path lacked `libtinfo.so.6`; gateway
and H3 were not run in that attempt. A direct BEAM probe isolated the host
lookup issue. A fresh extraction passed all smoke checks with the existing
nix-ld libraries and ncurses directory supplied through `LD_LIBRARY_PATH`.
No system configuration or artifact files changed. This result is qualified
by the recorded host environment; the original FAIL remains immutable.

The [clean consumer receipt](evidence/mixed-h2c/public-consumers/result.json)
records ten tests using newly resolved public Hex packages, separate caches,
deps and builds, and nineteen source-bound fixture/lock files. The HTTP
consumer holds explicit H1 and independent Python-h2 sockets open on one port,
checks actual versions/content, preserves body/pipeline/coalesced frames,
asserts five exact-once endpoint calls and verifies lease cleanup. Phoenix
body and listener ownership regressions also pass. Existing warnings from
the unchanged accepted lock syntax remain in the logs.

Post-publication commands, executed from the isolated worktree:

```sh
python3 .audit/mixed-h2c/publication/verify-publication.py \
  --source 14287f30b83ccec207ffc944867413043cb8f360 \
  --run 39555029237 \
  --artifacts-dir .audit/mixed-h2c/publication/qualified-local-artifacts
python3 .audit/mixed-h2c/consumers/verify.py \
  --execute .audit/mixed-h2c/consumers/run-1792561859466896362 \
  --source 14287f30b83ccec207ffc944867413043cb8f360 \
  --run 39555029237 \
  --publication .audit/mixed-h2c/publication/run-1792563923297863898/verification.json
LD_LIBRARY_PATH=/run/current-system/sw/share/nix-ld/lib:/nix/store/2iaawa9vbqas51lgpn4cjnnfdv74x8fn-ncurses-6.6/lib \
python3 .audit/mixed-h2c/publication/verify-runtime.py \
  --publication .audit/mixed-h2c/publication/run-1792563923297863898/verification.json
```

The [PR CI archive](evidence/mixed-h2c/hosted-final/README.md) records API head
`2a096b7d` and actual checkout `c46c99ff48123d58b765f3ba79944c0ba703524a`.
Their Git trees are identical. The later normal merge differs only in 225
acceptance-document/evidence files from the completed 0.6.0 closeout; all
qualified packaging inputs remain identical.

Fresh [main CI evidence](evidence/mixed-h2c/main-ci/README.md) separately binds
the actual merged/published commit `14287f30` in both API data and checkout logs:
[Unit 39554903610](https://github.com/gsmlg-dev/gaoxy/actions/runs/39554903610),
[Static 39554903614](https://github.com/gsmlg-dev/gaoxy/actions/runs/39554903614),
and [Foundation 39554903599](https://github.com/gsmlg-dev/gaoxy/actions/runs/39554903599)
passed all ten jobs. Both unit platforms executed 180 tests without failures,
exclusions or skips; native HTTP executed 207 without failures, exclusions or
skips. Main CI, release execution and downloaded/public-consumer verification
remain separate source-bound results. Publication grants no deployment or
production acceptance.

Final independent closeout review passed with no actionable findings. It
verified all five new archive inventories (241 files), exact/decompressed
hashes and audit copies, source identities, actual counts, public payloads,
consumer isolation and the initial/final runtime distinction. Documentation
links and whitespace checks passed; all 131 release inputs remain unchanged.
The closeout changes only acceptance/release/plan documents and their evidence.
