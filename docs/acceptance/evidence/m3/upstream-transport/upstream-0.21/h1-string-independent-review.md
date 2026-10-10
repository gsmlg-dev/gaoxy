# Independent review of generated String source lemmas

Date: 2026-10-11 Asia/Shanghai. Task: `m3_h1_new_evidence_review`.
Assignment: direct independent Sol SOURCE-PROOF review. Status: **DONE**.
Verdict: **PASS**, limited to the conditional generated String result,
constructor/progress lemmas and exact Elixir source-input provenance below.
No actionable findings remain within this assignment.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`. Assigned source baseline:
`4cc7a1a967d1b90a62d42db438316b10a03a1e16`; observed parent commit at review start:
`7cabfb77f2e87ee23d7684c118d4206f17f4fd95`. Parent commits and concurrent
documentation edits are permitted; the identities reviewed are the hashes below.
The reviewer authored neither the worksheet nor its input provenance.
Only this report is changed by this task. Existing shared edits, reports and
processes are preserved.

## Reviewed identities

| Artifact | SHA256 |
| --- | --- |
| [String worksheet](h1-string-transform-proof.md) | `d6b818575aacc4e2a8bed8dd6d990eae24225a866f320bca0f6a657762f8174e` |
| [String receipt](h1-string-transform-proof.json) | `be02ca597c7cab533230bf091d98c0ef06cc51108da8c96f6499e8c607200dab` |
| [Elixir input provenance](elixir-source-provenance.json) | `e5dcd5290dc2d39996cef185c3cf56b26fb8cd99aae0b55889ad0e1146f33b8f` |

The preceding [source-lemmas review](h1-source-lemmas-independent-review.md)
is trusted for its earlier unrelated conditional results. It was not rederived.
New String derivations and their referenced source paths were inspected directly.

## Independent verification

All commands below finished with exit 0. Commands were read-only except creation
of this assigned report. No Mix/VM/format command, runtime test, network request,
upstream mutation, commit or process-control operation was run.

- Python `hashlib.sha256` rechecked **70 recorded hash comparisons**, with zero
  mismatches: 13 Elixir source inputs, 14 OTP inputs, nine repository inputs,
  five evidence inputs, nine preserved-report inputs, six installed BEAM
  fingerprints, four installed/public source pairs, the worksheet identity,
  and nine repeated provenance source identities.
- An independent Python extraction followed the actual generator's 15-column
  UnicodeData interpretation and 103 unconditional SpecialCasing overrides.
  It reproduced 40,116 rows and 2,981 combined entries. The reviewer constructed
  prefix groups independently, rather than consuming the author's extracted
  mapping counts as inputs.
- Downcase: 1,457 changed mappings excluding special I/İ/sigma; 25 ASCII keys,
  one non-ASCII single, 54 prefix tables and **13,824** prefix/byte outcomes.
  Upcase: 1,551 mappings excluding special i; 25 ASCII keys, three non-ASCII
  singles, 58 tables and **14,848** outcomes. All 256 final-byte choices per
  table include malformed/non-continuation bytes. Ratios, fallback widths,
  maximum result widths and all five listed ratio witnesses agree exactly.
- Independent PropList extraction reproduces all 25 whitespace scalars and
  width counts 6/2/17 for one/two/three-byte encodings.
- Python checked arithmetic identities for every logical length 0 through
  65,536, including the triangular small-slice allowance, positive-delimiter
  part counts and camel-key byte envelope. These are static arithmetic checks;
  they do not execute generated String modules or establish runtime layouts.
- `nix --offline hash path
  /nix/store/qa7m7ymrcm7izhjdki9r5z1gsvgbfd05-source` independently reproduced
  `sha256-C7RXBjZZbdSgz4jdoOCKv8xfM95ChrYjXIIS/ahX+3Y=`.
- `nix --offline store verify --no-contents` for that source succeeded, checking
  the local store trust/signature metadata. Contents were checked separately
  by the preceding recursive NAR recomputation.
- `nix --offline derivation show` for the Elixir and source derivations confirms
  elixir-lang/elixir `v1.18.5`, the recursive source hash, no source patches,
  the installed output identity and the Erlang **28.5.0.5 build input**.

## Derivation assessment

The default case proof covers admitted binary inputs, including invalid UTF-8.
Explicit special clauses, generated single/table clauses and byte fallbacks
always consume positive input and emit one accumulator item. Table misses
recreate consumed bytes; default sigma short-circuits the Greek-context scans.
Therefore `O_down(b) <= floor(3*b/2)`, `O_up(b) <= 3*b`, and ASCII preserves
logical length. The bounds are not generalized to conditional locale modes.

The accumulator and reversed spines admit at most `2*b` cons. Case-item backing
uses the conservative constructor union with `F_case=256`; literal-prefix
lowering, integer-segment compiler paths and the narrower fresh heap-binary
alternative were inspected. The narrower alternative remains conditional on
compiled-code identity. Iolist singleton aliasing is distinguished from actual
multi-item flatten allocation. Shared input backing, small suffix copies,
candidate binary occurrences, output backing and wrapper/match-context terms
are separated. The payload envelope does not substitute logical field bytes
for retained parent backing, or count unreachable garbage as live memory.

Leading/trailing trim removes positive byte lengths through exact byte patterns;
unknown bytes stop matching. The monotone slice-chain and three-byte-window
counts support the stated occurrence and payload envelopes. Small final
constructors, shared parent backing and two decreasing small-copy chains are
accounted separately. Literal split bounds preserve part backing rather than
inventing a fresh input-sized allocation per part.

The two regex uses are distinguished correctly. Anchored OWS replacement has
at most two positive matches, whereas camel-key normalization has at most
`floor(b/2)` nonoverlapping matches and can expand before downcase. Returned
capture/index/replacement constructors are bounded without certifying native
regex workspace. Native regex terms and exceptional formatting roots stay
explicitly open.

Actual dependency callsites confirm repeated name normalization, including
downcase of the normalized query inside every `Headers.set` callback. Four
isolated final-head name scans have 48 fixed query bytes; selected token-value
bytes are disjoint within H, supporting the processed-byte bound `5*H+48`.
This is work/constructor accounting, not a live-memory reservation. The response
field count does not borrow the controlled request cap. The 129th trailer
validation attempt before the 128-field acceptance limit is retained.

Synthetic ASCII header normalization preserves length while admitting append
capacity and singleton aliasing. ASCII SNI conversion constructs one immediate
integer per byte; the successful HTTPS policy path eagerly evaluates three
conversions, including the default argument. The worksheet preserves restart,
helper and exception-root obligations instead of zeroing native state.

## Qualification boundary

Source provenance establishes generator/data input and installed artifact
fingerprints. It establishes neither build reproduction nor the code loaded
inside a managed worker. The installed Elixir derivation's OTP28.5.0.5 build
input is distinct from the parent runtime receipt's OTP28.5.0.7 / ERTS16.4.0.6.
The worksheet preserves this distinction and its required enforcement.

`M_iolist`, `M_split`, `M_match`, included helper/resource layouts,
`U_regex_native`, `U_exception`, integer scratch, remaining URI/serialization/
host-CA/policy transformations, and phase/lifetime multiplicity remain open.
The managed bounded input boundary and effective profile/code identity also
remain unqualified. This PASS does **not** establish full P0–P6, composed owned
object budget, production reservation, integration, activation, M3 completion,
TLS tracking or H2 qualification. The parent's separate TLS socket-shape issue
is outside this review.

Review Sol repair rounds: **0**; unsuccessful review validations: **0**;
Astra counter: **0**. Received worksheet counters remain String Sol0 /
unsuccessful0 / Astra0; provenance successful repair1 / unsuccessful0;
prior credit successful evidence repair1; parser reporting correction1 /
executable repair0. No escalation gate applies. All owned commands finished;
no owned background job was created. Remaining decisions: none for this bounded
review; unresolved qualification work remains with the parent.
