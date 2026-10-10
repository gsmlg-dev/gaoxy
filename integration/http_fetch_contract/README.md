# HTTP Fetch public contract revalidation

## Current published 0.21.0 managed qualification

The seven packages are installed at0.21.0, actual tag
`9813c126dc8b48055b9ee941c693fc27fa691489`. The
[artifact/installed provenance](../../docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/installed-provenance.json)
and [460-test compatibility gate](../../docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/compatibility.json)
are recorded separately from public managed runtime qualification. The
[managed fixture instructions](MANAGED_README.md) retain finite capacity,
deadline, isolation, retirement and256/257-fragment assertions. Serialize
execution after independent review and a renewed complete source freeze. The
[recovery1 runtime receipt](../../docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/managed-probes-recovery1.json)
records **39/39 PASS**,39 successful cleanups, exit0,425 unchanged source hashes
and no remaining owned peer. Strict preflight passes18/0. Both TLS H2 and h2c
retain the separately reported canonical capacity-error **MISMATCH** in
[Bug89](https://github.com/gsmlg-dev/http_fetch/issues/89).
The historical initial and diagnostic-only runs both FAIL after11 case receipts; the
[diagnostic receipt](../../docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/managed-probes-diagnostic1.json)
identifies conservative H2 request completion after force retirement, with
independent B still live before cleanup. Contract repair1's24-case runtime
failure and repair2's formatter-preflight failure remain preserved separately;
one bounded Astra formatting recovery and fresh complete verification resolved
the local fixture failures without removing any of the39 cases.

#78 ownership/retirement and #79 fragment-cap fixes are present in installed
artifacts. H2 retained header/control event bounds remain blocked on
[#86](https://github.com/gsmlg-dev/http_fetch/issues/86); complete H1 accounting
also remains unqualified. Functional PASS cannot approve either subtotal as a
memory reservation or enable Gaoxy managed transports.

## Historical published 0.20.0 public qualification

The following receipts and commands belong to the historical0.20 candidate;
the old empty-CONTINUATION diagnostic is not the0.21 positive cap regression.
The coordinated seven packages at that checkpoint were0.20.0, upstream tag commit
`951ec75dadcebd8218f30d3ecdf99da142d4a463`. The installed-source
[audit](../../docs/acceptance/evidence/m3/upstream-0.20/public-client-audit.md)
separates public request completion/trailers from the missing owned transport
retirement contract in [Feature #78](https://github.com/gsmlg-dev/http_fetch/issues/78).
These fixtures qualify direct Fetch requests only. Full M3 and Gaoxy reuse/H2
activation remain blocked; successful diagnostic execution is not acceptance.
Historical negative logs and older reproduction instructions below are preserved.

Run each probe in a separate otherwise idle VM, serialized with other Mix or
network fixtures, from the worktree root. The parent records actual outputs
under `docs/acceptance/evidence/m3/upstream-0.20/`. The
[public probe receipt](../../docs/acceptance/evidence/m3/upstream-0.20/public-probes-final.json)
records 16/16 PASS, exit 0, all 16 peers stopped and 202 unchanged source hashes.
The [bounded diagnostic receipt](../../docs/acceptance/evidence/m3/upstream-0.20/empty-continuation-final.json)
records INCONCLUSIVE, exit 0 with public cleanup and peer shutdown confirmed;
the retained-state gate remains unqualified. The original201 maps omitted the
main probe/shared helper; both probes were rerun with corrected202 maps and
original results retained. Source-confirmed missing metadata cap is routed as
[Bug #79](https://github.com/gsmlg-dev/http_fetch/issues/79), with the inconclusive
runtime evidence stated explicitly. Python must provide `h2`, `hpack` and `hyperframe`; missing
tools fail the probe. The existing qualified environment has h2 4.3.0 and hpack
4.1.0 (the independent hpack network test has a separate 4.2.0 pin). No production
package is added. `openssl` generates an ephemeral test CA and signed localhost
server leaf, verifies its SSL-server purpose/hostname, and removes both on peer
shutdown. Fetch trusts only that CA and retains peer/hostname verification.

```sh
HTTP_FETCH_PEER_PYTHON=/tmp/gaoxy-m3-h2-soak-venv/bin/python \
  nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; unbuffer mix run --no-compile --no-start integration/http_fetch_contract/pooled_completion_probe.exs'
HTTP_FETCH_PEER_PYTHON=/tmp/gaoxy-m3-h2-soak-venv/bin/python \
  nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; unbuffer mix run --no-compile --no-start integration/http_fetch_contract/empty_continuation_probe.exs'
```

`pooled_completion_probe.exs` has 16 explicit cases, requiring all cases for its
final PASS line. The independent peer records connection IDs, H2 stream IDs,
ordered fields, upload bytes, terminal headers, resets and exact request counts.
Readiness, peer control, network operations, request deadlines, public cleanup
and joined fixture shutdown are finite. Completion handles are captured from
the original Promise; acknowledged response chunks are matched against finite
expected bytes without collecting the stream. Each cleanup is repeated both
in the caller and a separate monitored waiter. Only the owned peer closes
its sockets; no private or global dependency pools are manipulated.

| Profile | Cases and exact evidence |
| --- | --- |
| H1 | Two sequential requests on one accepted socket; stalled cancellation closes that socket with one request; peer-observed stale closure before the next write yields one request per socket; chunked upload with declared, ordered duplicate trailers and acknowledged duplicate response trailers. |
| Verified TLS H2 | Live A/B on one connection, reset A, finish exact B, reuse for C; normal/empty/split trailer uploads; early final at a 16-byte stream-window barrier with pending upload trailers, producer/stream DOWN and live sibling; GOAWAY with exactly one received request and no replacement accept. |
| h2c | The same six H2 cases run separately with their own peer and reuse scope. TLS results never substitute for h2c results. |

The stale H1 case proves the **pre-write stale guard**, not an after-send failure
race. The split-upload case requires a wire CONTINUATION frame and exact decoded
terminal fields. Uploads declare `Trailer` only for H1; the 0.20 H2 request API
rejects that initial header and sends the same ordered fields through
`HTTP.Stream.finish/2` as terminal HEADERS. Trailer cases require cleanup to
remain pending before response
consumption and confirmed after all acknowledged bytes/trailers/EOF. Early-final
cases require no received late trailer block after sibling progress. These are
finite public request cases, not a transport-retirement or whole matrix claim.

`empty_continuation_probe.exs` shares fixture helpers but runs its own disposable
VM. It sends one valid empty response HEADERS without END_HEADERS, followed by
four batches of 20,000 valid empty CONTINUATION frames on that stream. The ceiling
is 80,000 frames / 720,009 wire bytes / zero compressed payload bytes; there is
no unbounded flood, malformed interleaving, PING or server push. Each peer
`sendall` receipt is correlated with three VM-wide memory observations at finite
50-ms intervals. Only the measurement process is garbage collected; private
client state is never read, enumerated, or changed.

The report includes installed source SHA-256, exact wire batches, VM totals,
process-used/binary memory, finite growth and post-cleanup samples. It reports
`reproduced` only for at least 640,000 bytes of process-used growth and at least
three batch deltas of 160,000 bytes; otherwise it reports `inconclusive`. These
conservative thresholds diagnose fragment metadata growth, not a memory bound.
Peer send receipts do not prove application consumption of unfinished headers;
review raw samples and source correlation before routing an upstream bug.
Public abort/await, reset observation, one request/accept and joined peer shutdown
are required in either result. Exit 0 means the finite diagnostic and cleanup
finished; it does not pass the H2 retained-state gate. Issue routing and adapter
TODOs belong to the parent; no local dependency workaround is authorized.

## Historical published 0.19.1

The root lock selects the seven published Fetch/Core/Runtime/WebSocket/QUIC/TLS
packages at 0.19.1. The release tag identifies commit `c26a17712a02a03985a764b6b100ca840fcc4349`;
workflow main HEAD is not the release identity. #27–#30, #38, #45, #60 and #64
are closed. The [current audit](../../docs/m2-dependency-audit.md) and
[0.19.1 evidence](../../docs/acceptance/evidence/m2/http-fetch-0.19.1/) record
immutable Git tree/blob verification and dependency gates separately from
historical failures.

From the worktree root:

```sh
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix test --warnings-as-errors \
  apps/gaoxy_proxy/test/http_fetch_contract_test.exs \
  apps/gaoxy_proxy/test/http_fetch_completion_test.exs
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix run \
  integration/http_fetch_contract/method_body_probe.exs
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix run \
  integration/http_fetch_contract/websocket_close_probe.exs
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix run \
  integration/http_fetch_contract/empty_query_probe.exs
```

Thirteen streaming/WebSocket tests and five public RequestCompletion tests pass.
They cover raw bytes, trailers, early responses, GET/DELETE entities, exact valid
WebSocket close codes, incremental fixed-length responses and confirmed request
cleanup. `request_mode: :proxy` and WebSocket `mode: :proxy` preserve proxy
semantics; browser defaults retain their browser restrictions.
`stream_response: true` remains a per-request option.

Both string and URI Fetch inputs now preserve `/upload?` on the wire. The public
empty-query probe exits **0**, and both request cleanup receipts return `:ok`.
The equivalent end-to-end regression in `http_proxy_wire_test.exs` also passes.
The method-body and close-code probes pass all **6 and 4 cases**, exit 0.
No dependency patch, private target API or URI rewrite workaround is used.

## Historical 0.19.0 raw-target failure

HTTP Fetch 0.19.0 removed a present empty query from string and URI inputs:
`/upload?` reached the peer as `/upload`. The public probe exited **1** and the
proxy regression failed, even though request completion independently returned
`:ok`. Bug [#64](https://github.com/gsmlg-dev/http_fetch/issues/64) blocked that
raw-target gate until the published 0.19.1 fix. Original failed evidence remains
in [the earlier bundle](../../docs/acceptance/evidence/m2/http-fetch-0.19.0/).

## Historical 0.17.1 reproduction

The original `probe.exs` and `observed.log` preserve the 2026-10-09 blockers
against HTTP Fetch 0.17.1 at `a78c0a35d84921678de40e8623eeeae71389c4ce`.
The probe runs actual `HTTP.fetch/2` against a loopback TCP peer, without
modifying upstream modules or installing the optional H2/H3/QUIC stack.
It is not a replacement package acceptance suite.

From the Gaoxy root, supply an untouched checkout of that revision:

```sh
git clone https://github.com/gsmlg-dev/http_fetch.git .audit/http-fetch-contract
git -C .audit/http-fetch-contract checkout --detach a78c0a35d84921678de40e8623eeeae71389c4ce
HTTP_FETCH_AUDIT_DIR="$PWD/.audit/http-fetch-contract" ELIXIR_ERL_OPTIONS='+S 2:2' \
  elixir -pa _build/test/lib/telemetry/ebin integration/http_fetch_contract/probe.exs
```

Expected observations at that historical revision are incorrect decoded gzip
bytes with unchanged headers, missing trailer metadata, and timeout instead of
early 413. Undefined H2/H3 module warnings are expected because only H1 modules
are compiled in memory. The recorded log used the same source files from the
audit snapshot. The separately source-audited 101 upgrade ownership gap was #30.
Do not count historical defect output as a passing proxy gate or as current
0.19.1 behavior.
