# Managed-H1 matrix runtime diagnosis1

DONE — read-only diagnosis, not runtime acceptance. The first full suite remains FAIL: 16 executed tests, 12 failures, exit2. Four native-H1 temporal/trailer cases passed. All eight H2 cases and four H1 representation cases failed.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; baseline revision `1426657e65d726629d618dcf03880df718375dd1` plus frozen candidate3 source401, stable per root collectors. No Git or candidate commands were run by this worker.

## Confirmed earliest causes

1. H1 representation standalone log line8: `AssertionError('explicit request Content-Length')`. Sole upstream receipt is POST `/empty`, connection1/request1, with no `content-length`. The driver requested explicit downstream Content-Length:0. `run.py:425` fails before upload_end and before sending the first response. Thus the logged response-release timeout is downstream teardown fallout, not the established first cause. Follow-up source tracing establishes a local adapter representation error; details below.
2. H2 temporal standalone log lines2-3: `MatchError` on `{:error, :http2_byte_budget}` at shared fixture line165, `Gaoxy.HTTP.service_spec(options)`. This happens during fixture startup, before the downstream listener is ready. No application receipt exists. H2 EOF/BrokenPipe are secondary. The fixture declares max_bytes16MiB and leaves H2 bounds at defaults; exact required accounting composition remains root investigation.
3. Attached fixture lines465-483 raise cleanup errors from an after block, replacing primary failure details. A still-live driver process group is killed and reported as forced cleanup. `respond/6` waits only for send commands, so teardown following a pre-send assertion can hit its unchanged 5-second release timeout; peer join then fails. Retain all cleanup failures while preserving primary failure details.

## Root-only next work

Trace zero-length framing through Gaoxy request headers/body-policy/client serialization before assigning dependency blame. Keep the exact assertion. Inspect H2 byte-budget validation and compose valid bounded fixture resource settings. Preserve primary attached failure plus cleanup evidence. Then run the unchanged cases and the complete16 under root ownership. No artificial adapter, deadline increase, weaker assertion, dependency workaround or #97 requirement is proposed.

## Evidence and verification

Evidence directory: `docs/acceptance/evidence/m3/managed-h1-matrix/1792268705767310915`. Root suite receipt: `first-assessment1.json`, actual16/12/exit2. Root standalone diagnostics: `h1-matrix-diagnostic-h1-representation1.{log,json}` and `h1-matrix-diagnostic-h2-temporal1.{log,json}`, each one case executed/failed, exit1, source stable. Both outer processes joined without outer force and had no remaining process group. Individual inner cleanup failures remain failed.

Worker commands: bounded rg/sed/nl source/log reads and selected JSON metadata extraction only; no tests, Mix, Git, browser or candidate execution. All worker commands finished. No repository edits. Only these two /tmp report files were written.

Direct assignment; local Sol repair rounds0; root-owned counter12 unchanged (exact prior cumulative Sol count not supplied); received Astra2/2 exhausted and unchanged. No escalation gate. No product decision needed for diagnosis. Later representations remain unexecuted, and no dependency defect is established.

## Follow-up: Content-Length0 ownership

The local HTTP1 parser maps absent CL/TE to `:none`, explicit CL0 to `{:length,0}` (`http1/parser.ex:241-248`). Proxy `Headers.request/1` preserves this ordinary Content-Length (`http/headers.ex:12-35`), and `HTTP.request_options/5` retains the body mode (`http.ex:531-550`). The distinction is lost at `HTTPFetchClient.open/1:39-47`, which maps both cases to nil. The managed fetch path passes that nil to HTTP.fetch (`http_fetch_client.ex:67-89`).

Installed provenance: exact http_fetch/http_core0.21.10, sourced from `https://github.com/gsmlg-dev/http_fetch`, verified in the package mix.exs files lines4-5 plus Gaoxy mix/lock pin. Dependency `HTTP.Request.body_payload/1:152` treats nil as no payload, and `put_body_headers/2:184-187` removes Content-Length for that representation. Its PID-stream path retains validated explicit CL (`request.ex:189-195,210-219`). This establishes a Gaoxy mapping error; no upstream defect or workaround is demonstrated. No issue is required for this diagnosis.

Smallest recommended local change: choose nil only for `options.body == :none`; allow `{:length,0}` to use the existing supported `HTTP.Stream.start_link(0)` path. This stays within Gaoxy managed preparation's nil/PID contract (`managed_h1_preparation.ex:114-119`). An empty binary alternative would require expanding that contract. The existing request pump skips writing empty chunks but invokes finish_upload on kind :ok and finishes nonnil upload through the public client (`http.ex:861-912`).

Keep the matrix Content-Length assertion exactly as written. The existing deterministic red network case is already a meaningful regression. A focused adapter network check can compare no-body versus explicit-zero-body wire headers, require zero entity bytes/no chunk framing, and observe original completion and upload join; then the unchanged complete matrix establishes reuse and remaining representations. Proposed stream handling is source-supported but runtime verification remains root-owned and NOT RUN by this worker.
