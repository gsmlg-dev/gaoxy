# Installed 0.21 qualification notes

This supplement preserves earlier source/API and worksheet review receipts.
Those reports describe the source and live release state at their own checkpoints;
they do not overwrite the installed-artifact provenance or current runtime results.

The containing release is now installed: actual tag
`9813c126dc8b48055b9ee941c693fc27fa691489`, successful Release38067971805,
all seven archive/lock checksums,196 shipped-file hashes and175 runtime Git blobs
matched. #78 managed ownership/retirement and #79's256-frame fragment cap are
present. The [compatibility receipt](compatibility.json) is460/0,
seed21102026, with228 unchanged source hashes; no managed runtime result follows.

Two precision corrections apply to the earlier numeric worksheet:

- The1MiB H2 writer check in `deps/http_runtime/lib/http/http2/connection_owner.ex`
  lines667–710 bounds a synchronous write batch. It does not establish an
  aggregate send, decoded-header or capacity-notification queue bound.
- The8192-byte H1 line limit in `deps/http_core/lib/http/http1.ex`
  lines394–408 applies when CRLF is absent. A complete chunk-size line follows
  the matched-CRLF branch first; its transient allocation must be charged under
  qualified transport delivery plus parser carry, rather than an8192 limit.

The historical empty-CONTINUATION metadata defect is fixed in installed0.21.
The current H2 blocker is [#86](https://github.com/gsmlg-dev/http_fetch/issues/86):
peer-driven decoded-head events and asynchronous SETTINGS capacity casts lack
hard aggregate outstanding-event limits. This is independently reviewed source
evidence, not a measured runtime leak. DATA credit, active-once receive,
per-block limits and the writer batch do not supply those missing terms.

H2 C2/R32/P0 components total52,207,632 bytes; narrow H1 components total
261,199,114 bytes. Both remain incomplete. Narrow H1 uses frozen
`buffer/recbuf/sndbuf=8192`, nil/PID upload, binary pieces≤65536 with ACK,
raw streamed response and manual redirects. Its separate accounting review
must establish policy/preparation representations, retained binary backing,
header/trailer structural and copy overlap, process/ETS/monitor/timer/control
metadata and the exact managed OTP delivery envelope. No unknown term is zero.

Task3 public functional results, repaired source identity and peer shutdown
receipts belong in their own manifests. A finite public PASS does not resolve
#86, approve either subtotal or qualify Gaoxy integration,600-second managed
load, the full version matrix, M3 completion or M4 progression. Tasks4–8 remain
gated until the corresponding complete prerequisites and independent review pass.

The initial managed run and diagnostic-only rerun both FAIL after11 case
receipts and12 joined peer cleanups, with425 source hashes unchanged. The
diagnostic preserves the primary force-retirement assertion failure instead
of masking it with cleanup: A is `cleanup_unconfirmed`, while independent B
has one live request/connection in an open scope and its completion is pending
before cleanup. The containing-tag retirement contract explicitly permits
conservative individual request evidence after abnormal termination. A fresh
protocol-specific contract repair/review/full39-case run remains required.
This diagnostic instrumentation is not a successful functional repair.

A third precision correction applies to the historical H1 worksheet:
the65,536-byte emission cap applies only to chunked `:chunk_data`. Content-length
and EOF response events can span the full transport delivery. The controlled
H1 architecture replaces the guessed eight-window expression with named P0–P6
obligations and allows a pure compact-input/constructor slice without process
activation. Complete numeric H1 accounting remains NOT ESTABLISHED.

Source-confirmed input/backing requests#87/#88 are routed as needed; their
recipes and any retention amount are NOT RUN / NOT MEASURED. They do not turn
the remaining local H1 derivations into an external blocker. Exact-runtime C
source acquisition begins with the Nix derivation receipt `otp-source-location.json`;
identifying the source input does not certify representation constants. The
exact input was subsequently restored; `otp-source-provenance.json` records
its signed fixed-output NAR,15 source hashes and6 matches with installed SSL
sources. It certifies source provenance only, not P1/P2 closure.

Actual contract repair1 passes every abnormal-retirement and deadline case,
then FAILs after24 cases/25 successful cleanups on empty-response fixture
dispatch. HEADERS END_STREAM yields exact binary `""`; the historical helper
assumes a PID. Repair2 makes the local256-frame positive assertion follow the
public binary/PID contract, but its strict preflight FAILs before runtime due
to formatter-required blank-line layout. Both failures remain distinct in
their receipts. After two unsuccessful Sol validation rounds (one runtime,
one formatter preflight), bounded Astra recovery1 is routed with
`mode: implementation`, `astra_gate: SOL_REPEATED_FAILURE`; no gate is skipped.

The named verified TLS H2 GOAWAY finite capacity case passed in repair1, while
its canonical error shape is MISMATCH. Needed Bug#89 requests the documented
connection-capacity tuple instead of actual `:pending_capacity`. Its issue
receipt verifies Bug/internal request/open and the submitted body. h2c was
not reached in that cited run. Finite resource-property success never supplies
canonical contract compliance or completes the remaining managed gates.

Current recovery1 verification supersedes only the pending functional status:
independent specification and code-quality delta review PASS, strict preflight
18/0 PASS, complete public run39/39 PASS with39 successful joined cleanups,
exit0,425 stable hashes and no owned peer remaining. Both TLS H2 and h2c now
confirm Bug89's canonical MISMATCH. Historical failures remain unchanged.
Counters remain Sol unsuccessful repair validations2 (runtime1/formatter1),
Astra completed recovery1/2 and unsuccessful0. See the separate
`managed-preflight-recovery1.json` and `managed-probes-recovery1.json` receipts.

`h1-delivery-proof.md` supplies conditional exact-source raw inet lemmas:
logical event<=8192 and exposed payload backing<=10922; SSL singleton
`iolist_to_binary` preserves borrowed backing. Complete credit induction,
decrypt-output backing and pool/parser overlap remain open local obligations.
No source provenance or finite runtime PASS closes P1/P2/P4 or enables activation.
