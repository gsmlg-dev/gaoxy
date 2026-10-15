# fixed_h2_local_status_sol19 — frozen TESTONLY handoff

Assignment: direct bounded diagnosis and test-first candidate preparation. Candidate deliverables complete; production repair and runtime acceptance NOT RUN. No source/dependency/repository/evidence writes, runtimes, upstream mutations or commits performed. Root owns source release, formatting, all execution and evidence.

Repository/worktree: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation
HEAD baseline: 31f23eb2d915ba715a1016f254b90d9805f18a1a
The checkout already contains extensive root-owned tracked and untracked task work. Read-only inspection and SHA comparison confirm both assigned source files remain unchanged by this worker. All worker commands finished; no running processes/sessions remain.

## Diagnosis and end-to-end source contract

- HTTP1.Body.chunk_size/1 rejects `Z\r\n` with {:error, 400, :chunk_size} (body.ex:113-123). The same native decoder produces authentic 413 for body limits and 431 for trailer byte/count limits (body.ex:66-95).
- Exchange.decode_body wraps that rejection as {:error, {:request_error, status, reason}, exchange} (exchange.ex:231-233).
- HTTP.read_upload routes the authentic local error through local_fail (http.ex:640-645, 867-868).
- HTTP.fail normalizes every managed-H2 reason with Session.finite_reason before selecting an HTTP status (http.ex:895-908). The request-error triple has no finite_reason clause; session.ex:646 maps it to :upstream_failure. The subsequent status selection therefore picks 502 instead of 400/413/431.
- The design requires malformed requests/envelopes to produce400 before a response head, while upstream protocol/reset failures produce502 (design:863-867). Native service body/trailer limits independently prescribe413/431; those semantic statuses must survive without retaining raw reasons.
- Authentic upstream request observation and the original public RequestCompletion pending receipt precede every malformed upload. Manual peer mode sends no final head. The guardian's retained submitted_url additionally establishes its accepted pre-head state.

## Bounded repair design — prose only, no production code retained

Preserve local400/413/431 only at the trusted local_fail boundary for ManagedH2Client. Match a finite allowed status and discard the raw local reason immediately, replacing it with existing finite :invalid_request. Feed that bounded scalar status privately into the existing fail cleanup/render path; keep ordinary fail callers using only normalized reason-based status selection. Retain cancellation, demonitoring, response==:unset/total-expiry conditions, close:true and all original deadlines/caps.

Do not teach Session.finite_reason to preserve arbitrary request_error tuples; do not select managed statuses from raw reasons inside generic fail. An upstream error received through Session/dispatch must still normalize to finite upstream failure and502; an unsupported or malicious local status must not acquire the bounded override. ManagedH2Client.finish_body maps all upstream return failures to :upstream_trailer_limit (managed_h2_client.ex:162-175), so that caller cannot introduce a request_error triple into the trusted boundary.

Native H2 oversized DATA currently uses reset(CANCEL), not {:request_error,413,...} (HTTP2.Connection:389-390); preserve that existing contract. No nativeH2 semantic expansion is proposed.

Already-sent-head behavior: HTTP.dispatch headers sets upload_stopped:true after authentic response commitment (http.ex:767-780). The native malformed-upload read path is therefore unreachable after a final head; do not introduce a noncausal test claiming otherwise. Preserve existing early-final upload cessation cases in the endpoint file and committed-head/finite cancellation tests in managed_h2_fixed_write_lifecycle_test.exs:118/128. The repaired fail path must still return finite error with close:true after a committed response and emit no second response. No existing case/assertion changed.

## TESTONLY candidate and written execution plan

Only candidate file is apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs, copied under this temporary artifact directory. The fixture now merges optional test-owned public http_limits overrides into its existing defaults; unchanged callers keep byte-identical limit values. Add one generated loop with four genuine nativeH1 cases for each upstreamTLS-H2/h2c:

1. malformed chunk: Z\r\n ->400 Bad Request;
2. native max_body_bytes4: chunk size5 with5 actual body bytes ->413 Request Entity Too Large;
3. native max_trailers1: two declared safe X-Check trailers ->431 Request Header Fields Too Large;
4. native max_trailer_bytes8: over-budget X-Check line ->431 Request Header Fields Too Large.

Each test authenticates the real observed upstream target/connection/trailer declaration, original completion identity, pending receipt, request token/pins/helpers and unchanged9444956 minimum reservation; asserts the exact sole empty closed H1 wire response; then awaits original completion, guardian normal DOWN, no upload/end/trailer/replay events, service cleanup and physical peer/instance joins using the existing fixture. Finite original5000ms fixture/read/completion deadlines remain unchanged. Tests are additive; the complete original test module is statically verified byte-for-byte after removing the added loop.

Execution is intentionally serialized behind Root's ongoing complete CODE review/source freeze:

1. Root releases TESTONLY against exact before hashes and formats that owned candidate under its qualified environment.
2. Root runs the genuine network RED with original production unchanged. Require the8 exact expected status mismatches, no parser/fixture/config/lifecycle error substituted for RED.
3. Only after observed genuine RED, derive a fresh production implementation from the prose boundary above; review and release it under Root ownership. The unexecuted draft production files were deleted on Root instruction and never read/applied by Root.
4. Re-run the same complete endpoint file with no exclusions, then unchanged adjacent cleanup/committed-head compatibility coverage and required full manifest. Preserve any unrelated upstream122 pre-head cancellation failure as BLOCKED; do not change that assertion or call a blocked full gate green.

## Root-only minimal commands and expected outcomes

Run from the worktree root using Root's already qualified toolchain/peer environment (the fixture's real Python peer uses /tmp/gaoxy-m3-h2-soak-venv/bin/python). Do not start an alternative runtime as part of this worker handoff.

`unbuffer mix test apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs --seed 0`

The source contains30 original generated tests plus8 additive tests (static count38, NOT an executed test count). Expected RED: all8 new cases compare the exact expected400/413/431 response with actual `HTTP/1.1 502 Bad Gateway\r\nconnection: close\r\ncontent-length: 0\r\n\r\n`; then exit nonzero. Existing cases must remain executed. Expected GREEN after root's fresh implementation: those8 status assertions and their original cleanup assertions pass; no execution evidence exists yet.

`unbuffer mix test apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_write_lifecycle_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs --seed 0`

Include the endpoint file because it defines the shared genuine fixture. This retains existing pre-/post-head completion, token/pin/service and physical joins. Root must also retain the existing complete full58 test manifest,135 matrix identities and required browser gates; this candidate does not replace any stage gate.

## Actual verification and risks

PASS: read-only source trace; Python/difflib artifact generation; static reconstruction verifies original test module byte-for-byte; SHA256 of both repository-owned files equals before snapshots; draft production files removed. Each invoked command returned and no background job remains.

NOT RUN: Mix, compilation, formatting, RED, GREEN, native peer, network, browser, full manifest, independent review of this candidate. No runtime success is claimed. Candidate syntax/format and genuine fixture behavior must be validated by Root. If any failure precedes the exact response-status mismatch, diagnose the fixture failure before deriving production changes. Upstream122 remains an external blocker for the unchanged broader cancellation gate, not justification to omit or weaken it.

Cumulative counters unchanged: fixedSol18/unsuccessfulGREEN14; collectorSol17/unsuccessfulGREEN12; matrixfailed11; browserfailed5; R32diagfailed5; Astra recovery2/2 exhausted. This assignment releases no production repair and consumes no release repair round. astra_gate: none. No new user/product decision or external permission is required for this candidate.

## Identities

Before apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex: `fd77c71e781454084e5dbec5de456a51d434567f0b29d86b7cd478d19d959c52`

Before apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs: `f6fc63344779f78e7787865882f0f1b2a948668326547f2b8a813ba88625a0bb`

TESTONLY candidate SHA256: `218f417d03b7daf36f67582330b8a16533882439ccfe2b8837a1f3f2798aa392`

TESTONLY patch SHA256: `a578476836481f660defbd8fef84d0125512879a0f63a44c5e9ae50394f9bada`
