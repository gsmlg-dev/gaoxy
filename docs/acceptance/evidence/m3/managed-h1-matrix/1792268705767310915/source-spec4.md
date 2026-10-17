# Managed-H1 matrix independent source specification review4

**PASS_SOURCE_SPEC4** — no actionable source specification findings. Direct non-author, read-only review; runtime **NOT RUN**.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; baseline `1426657e65d726629d618dcf03880df718375dd1`, branch `codex/m3-h1-resource-foundation`.

Candidate4 SHA256 `05269802d86ec0f9742b5d2e725168fccdfbd6cdb98fa0d9f07e73aa3f745913`; command-inventory4 SHA256 `31ca79fed77863843b0983640d02667d263f47bcfa12fe72f691fcef70fc255b`. All9 owned sources,8 documents and11 dependency pins match. Full hashes and requirement tracing are in the JSON companion. Only adapter and fixture source changed vs candidate3; the other7 owned sources retain their frozen bytes.

`http_fetch_client.ex:39-47` reserves nil for an absent body and uses the existing public PID-stream path for explicit CL0. Preparation accepts nil/PID, stream serialization preserves validated CL0 without chunk framing, and the existing zero-byte finish_upload path finishes the stream. Matrix `run.py:425` retains the exact explicit Content-Length assertion.

Fixture `managed_h1_matrix_fixture.exs:135-165` keeps H1 at16MiB and selects supported small H2 limits within64MiB. Independent arithmetic against the unchanged native validator gives40,946,727 bytes, with26,162,137 bytes headroom. Ingress and default max_active satisfy the validators. No deadline/assertion/validator changed.

Fixture `:469-511` captures the attached-case cause and original stacktrace before the isolated cleanup sweep, warns on secondary cleanup errors and reraises that cause. Cleanup failure after an otherwise successful case still raises; forced/unjoined cleanup remains failing. Exact archived diff preserves all existing operation deadlines and protocol/content/accounting assertions.

Full source requirement coverage remains present:8rows/16cases; shared ExUnit/standalone oracles; upload and received-response prefix holds; stable original completion/binding; ordered duplicate fields/safe declared trailers; empty/fixed/raw-gzip/bodyless representations; persistent H1 framing; H2 terminal empty responses; same accepted upstream connection and separate health HEAD; finite failures/cleanup/registry receipts; separate two-row/four-page browser source and root image gate.

Prior SPEC3→CODE2 PASS is retained. First1 remains FAIL16tests/12failures/exit2; both selected diagnoses remain FAIL1/1/exit1. Repair3 runtime, compile/tests, integration, browser, image inspection and local commit/custody were not executed by this review. No source PASS implies runtime acceptance. WholeTask6/Task5/M3 remain OPEN.

All finite static commands finished; no background process started. One bounded search used a nonexistent request.ex path, then was corrected to the actual http_core path; no implementation failure or repair arose. No forbidden directory/private material or broad status/untracked inventory was accessed. No repository files changed. Only these two requested `/tmp` reports were written. Ownership returns to root; no decision needed.

Parent cumulative managed-H1 matrix Sol repair rounds3, Astra2/2 exhausted; this review adds0 repairs and requests no escalation.
