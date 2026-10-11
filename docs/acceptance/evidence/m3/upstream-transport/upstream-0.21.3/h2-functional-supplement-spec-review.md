# H2 0.21.3 functional supplement independent SPEC review

Status: **DONE — PASS_STATIC_SPEC.** No open finding.
Runtime and implementation CODE review: **NOT RUN**.

Direct task `h2_0_21_3_functional_supplement_spec_review`; plan author
`upstream_contract_status`, independent reviewer. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`; parent supplies branch
`codex/m3-gateway` and baseline `85c2284a035e0b4ecbf577279eee01142702b5a3`.
Reviewer writes only this report and its JSON. Source, plan, manifests, frozen
TLS/H1 inputs and other workers' edits remain untouched.

## Resolved precision findings

- **H2-SPEC-01, P2:** Parent added the complete invocation's600-second external
  collector bound: eight*(45s ready+15s case)=480s plus headroom. Preserve actual
  child wait/exit before parsing; timeout FAIL; finite termination/join only of
  the recorded owned process group. Per-case D/C are unchanged.
- **H2-SPEC-02, P2:** Parent added controls3/events128/encoded-line4096/reader4097
  caps including cleanup. Duplicate, unknown, oversized and nonterminated input
  rejects. Command eligibility remains strict. These local fixture bounds do
  not establish upstream adversarial/native/accounting bounds.

Amended reviewed plan SHA256:
`25fdfb876f7e83f65b97414816a6a82c258ec8f789f0d0eb7f4e07f627ad7270`.
Initial plan SHA256 before precision amendments:
`1bd56b39b48efc01c6dcd05400dd98960e6f15c96e45b29f1d455e46084f0fad`.
An initial pre-write hash guard observed the authorized concurrent amendment and
stopped before any report write. Final re-review uses only the amended bytes.

## Source and public-oracle verdict

All sixteen listed source/helper/lock/requirements hashes match current bytes;
both cached-tag oracle test hashes also match. Exact identities are in JSON.
All eight registered TLS/h2c cases retain their original exact oracles:

- Manual parser cases support original completion. Nonterminal trailing HEADERS
  with payload `0001780176`, type1/flags4, produce exact
  `invalid_headers_transition` and code1 PROTOCOL_ERROR. Source:
  `stream_state.ex:255`, `connection_owner.ex:1318–1328`.
- Follow abort/deadline cases expose exact unsupported redirect completion.
  `request_mode: :fetch` does not choose tracking; no connect_address is supplied.
  Cancellation retains exact `aborted`/`request_timeout` and code8 CANCEL.
  Source: `request_completion.ex:39–40,77–79`,
  `socket_client.ex:927–929,991–993,1253–1257`,
  `connection_owner.ex:676–677`.
- Early sentinel/chunk-reference/ACK proves reader attachment. Late first read
  follows a matching peer-observed reset; it does not infer private mailbox state.
  Exact terminal error, normal exposed stream DOWN and final mailbox scan bound
  the observation. Parser late pending and post-reader/repeated completion checks
  match the released regression. Only early cases receive one sentinel byte.
- Explicit native_v1/reuse/unique case scope, pinned Python packages, separate
  h2c profile, verified IP-SAN TLS trust and actual ALPNh2 are coherent. OTP
  default hostname verification remains enabled. No private Pool,
  ConnectionOwner or RequestLifecycle calls or managed generation are authorized.

Original request6s/connect2s and outerD10s/C15s remain distinct fixed clocks.
Promise, terminal and completion waits use remaining original time; deadline
reset waits for actual request expiry. Alternate errors, retries and renewed
request timeouts cannot satisfy a registered case.

`HTTP.AbortController.new/0` publicly returns the newly created Agent PID
(`abort_controller.ex:95–98`; `Agent.start_link` at85). Register that exact owned
controller immediately. Finite `Agent.stop/3` with normal reason and remainingC,
followed by its normal DOWN, applies to that controller. Registry lookup and
private process inspection do not establish ownership. Implementation must keep
public abort calls' built-in Agent waits within the fixed ceilings, using an
owned bounded helper if needed; no private controller state is necessary.

## Execution and cleanup boundary

Require eight distinct executed results, TLS4/h2c4, no skips, failed0, eight peer
shutdowns and actual exit0. Every acquisition is registered for finally cleanup,
including partial startup. Require all exact owned socket/thread/listener,
controller, exposed stream and peer-port joins, with one shared finite peer
shutdown deadline. Forced cleanup remains FAIL and never changes the original
oracle. Source/profile drift invalidates execution.

Unsupported completion provides no request-resource/native barrier. Dedicated
BEAM exit and wire/reader observations do not establish long-lived pooled native
reclamation. This specification qualifies only the selected functional slice;
#97, siblings, proxy matrix and full M3 acceptance remain separate.

Final static hash/text checks passed. No VM/tests/dependency/Git/network command
was executed; all reviewer commands finished and no background process exists.
New supplement repair counters remain0. H1 Sol2/unsuccessful2/Astra1 and TLS
Sol4/unsuccessful2/Astra2 are unchanged. Parent owns implementation admission,
independent CODE review and actual eight-case runtime execution.
