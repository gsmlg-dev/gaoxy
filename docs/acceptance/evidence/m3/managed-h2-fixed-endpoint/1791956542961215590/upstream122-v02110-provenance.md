DONE — upstream122_v02110_provenance, direct read-only investigation.

Issue #122 is closed as completed. Source fix `6c6078d26cc9ab69806095bc1461383f6149803a` merged as `9caf38cabdaa5fc1c65501632a28548ebd27d714` at 2026-10-15 08:04:34 UTC. Release v0.21.10 resolves to `ed27a577d418e45266cd54638692362d17fcdcd1`, the merge commit’s direct child, published at 08:24:47 UTC.

The fix notifies owners before closing resources. At post-send activation, it maps only closed/einval errors with an actually queued abort to aborted. Independent native errors, already-published send failures and parser errors retain their exact reasons. Ten statically expanded TCP/OTP SSL regressions cover these distinctions, peer closure/join and repeated original completion. Upstream core/Fetch test and E2E checks report success. Skipped consumer/historical checks remain skipped. This reviewer ran no runtime tests.

All seven existing-cohort Hex 0.21.10 tarball SHA256 values match Hex API metadata; 176 implementation files match the GitHub tag. The seven mix.exs differences are limited to standalone export removal of umbrella paths/settings. Promise, RequestCompletion, Response, Stream and Headers APIs are byte-identical across the immutable refs. No required Gaoxy production adapter change or actual Gaoxy regression was identified.

Minimal upgrade recommendation:

1. Update the two direct pins, http_fetch and elixir_quic_http3, and resolve the existing seven-package cohort together to exactly 0.21.10.
2. Add qualification plumbing for the new cohort: the current public qualification and supplement hardcode 0.21.4. Preserve historical files/receipts and all 63 assertions; do not relabel old results.
3. Retain Gaoxy’s finite method, timeout, policy and memory limits. Stricter HTTP/1 framing/version rejection and H3/QUIC/lifecycle changes need the already-required affected compatibility checks, with unchanged assertions.
4. Resume the unchanged H1 cancellation regression and full58 gate. Complete independent review and fresh format, compile, full58, public63, matrix135 and browser3 before stage acceptance, local commit or successor execution.

The released fix permits resuming the blocked gate; this report does not claim that the gate passed. Preserve historical 845/1 evidence and negative TLS cleanup uncertainty. Issue #97 remains dismissed. No publication, deployment, E2E or Vault authorization is inferred.

Cumulative counters remain fixed Sol19, collector Sol17 and Astra 2/2; this review consumes zero repair rounds. Baseline is 31f23eb. Root owns concurrent upgrade changes. Reviewer repository/dependency/upstream writes: none. Only the assigned /tmp JSON and Markdown reports were written. All reviewer commands finished; no session remains.
