# Public Session DATA and residual stream credit

Upstream: [gsmlg-dev/http_fetch#105](https://github.com/gsmlg-dev/http_fetch/issues/105),
type **Bug**, label **internal request**, severity **needed**. Package provenance
for both `elixir_quic_http3` and `elixir_quic` points to that umbrella. This is a
separate H3 interoperability finding on the coordinated **0.21.4** cohort.

The direct Session gate's first 16 KiB `/tiny-upload` DATA became blocked after
HEADERS consumed part of the independent peer's 16 KiB stream window. Session
split the encoded DATA into 16 KiB transport fragments; QUIC requires an entire
submitted fragment to fit remaining credit. No DATA prefix was admitted, so the
peer's receive threshold could not advance credit. Repeated resume retained the
same fragment until the original deadline. Polling was not a missing credit pump:
the QUIC network frame path handles authenticated credit updates independently.

The preserved [runtime result](../acceptance/evidence/m4/upstream-contract/run-1791831993043786216/result.json)
is **FAIL / exit1**, with 31 boundary doubles and six real network rows PASS,
11 network and two policy rows NOT RUN. The failed tiny request has no captured
cleanup receipt or local endpoint rebind; origin port rebinds and global child
exits 0/1 provide only partial cleanup evidence. Original evidence is immutable.

[Independent failure/API review](../acceptance/evidence/m4/upstream-contract/review-session-astra1-runtime-public-option-1791832511081707496.json)
confirmed that public `Session.new(max_frame: 8_192)` is a supported bounded
configuration candidate. It changes encoded transport fragmentation while
preserving the 16 KiB application DATA ceiling, the 1 MiB payload, the peer's
16 KiB window, exact bytes/FIN, no replay, ACK, deadlines and all 50 named rows.
The configuration requires a written amendment, independent review and actual
qualification; its availability does not turn the failed run into PASS. Until
then UP1 remains HOLD_UP0. Any temporary selection carries TODO/WORKAROUND
comments referring to #105. No dependency source is patched.

The issue is **needed**, not an unavoidable external blocker while this supported
public configuration remains available for qualification. Release eligibility
still requires complete M4 gates and independent review. Received counters are
Sol2/unsuccessful2 and Astra1/unsuccessful1; the diagnosis-only review did not
consume a second Astra recovery round or reset historical counters.
