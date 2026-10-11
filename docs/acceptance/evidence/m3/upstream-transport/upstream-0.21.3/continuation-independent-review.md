# Independent continuation specification and executable review

Task `m3_continuation_independent_review`, direct bounded Sol review. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch `codex/m3-gateway`,
parent-supplied baseline `85c2284a035e0b4ecbf577279eee01142702b5a3`.
Only this report and its JSON companion are owned. No executable/dependency edit,
test, VM, Mix, network or Git command ran. All static commands finished.

SPEC was reviewed first: **PASS for the B05/B17 amendment and bounded 0.21.3
continuation**, retaining the separate accounting/TLS/production gates. H1
implementation SPEC and CODE QUALITY: **PASS_STATIC_REVIEW**. TLS mapping
implementation SPEC and CODE QUALITY: **FAIL**, with one actionable parser
finding below. This is review completion, not functional/runtime acceptance.

## Actionable finding TLS-MAP-01

P2, `.audit/m3-transport/tls95-runtime-identity.exs:289`: the maps regex permits
zero whitespace between the inode and a pathname because `[0-9]+` is followed
by `\s*(.*)`. These malformed, otherwise complete rows therefore match the
parser and satisfy its JIT pair guards by source inspection:

```text
1000-2000 r-xs 00000000 00:01 7/memfd:vmem (deleted)
3000-4000 rw-s 00000000 00:01 7/memfd:vmem (deleted)
```

The result is classified as a memory exclusion despite the required malformed
row rejection. The negative regression at
`.audit/m3-transport/continuation-2026-10-11/tls95-identity-regression.exs:69`
covers a wholly malformed string but misses this complete-row boundary.
Require whitespace when a pathname is present while permitting a truly absent
pathname; add a deterministic rejection of the paired no-delimiter form.
This counterexample was derived statically, not executed by the reviewer.

## H1 amendment and preservation result

The canonical role table, original-deadline section and B17 paragraph now agree
with the independently reviewed Astra1 amendment: original D500/slot0 pending,
one already-issued abort helper, second pre-reserved observation to t0+25000,
unchanged shutdown t0+30000 and no native-frontier refund. B05 materializes the
append-created URL parent with `:binary.copy/1` before slicing and retains its
exact backing assertion, three rejects/three copies, malformed-input oracles
and zero Fetch. The Python peer is hash-identical to the preserved source.

Fixture lines2020-2077 restrict late cleanup to B17 slot1 after original
D500/pending, require the original abort receipt, enforce the two-wait ceiling,
and retain separate purpose/deadline/result fields. Lines2843-2895 preserve
original pending/timed_out, tolerance<=100ms, strict late `:ok`, receipt
registration and one graceful/one abort/two waits. The strict B17 test checks
both observation rows. The other nineteen test definitions are unchanged;
all twenty cases remain registered, including exact B11 chunk parser and B12
trailer errors. No generic-abort replacement, skip or exclusion was introduced.

Ledger command refusal returns typed errors without killing the custodian
(lines370-388), and the controller preserves those failures (lines511-518).
Every case attempts cleanup and finally owned shutdown; PASS requires scenario
success plus cleanup confirmation (lines538-617). Scope cleanup still requires
`row.retired` and no failed step (lines3342-3401). Peer/actor/upload joins,
identity stability and model-control obligations remain separate; helper DOWN
does not manufacture native release. Suite acceptance requires20 current-run
PASS rows,20 tests, zero failures/skips/exclusions (lines63-102).

The parent-generated 0.21.3 inventory passes this review's static checks:
207/207 current source hashes match, no missing inputs,175 unique runtime paths,
exact B01-B20 case identities and matching canonical-plan hash. Its B17 text
contains the reviewed late-cleanup amendment. Installed/build identities and
baseline20 execution remain parent-owned gates, not performed by this reviewer.
H1 Astra repair1 is
edited but validation remains pending; preserve Sol2/unsuccessful2/completedAstra0.

## TLS mapping and identity result

Parent raw-map evidence records shared RW/RX aliases of the same device/inode,
offset0 and64MiB extent. The classifier admits only the exact vmem label with
two shared `r-xs`/`rw-s` nonoverlapping equal-offset/equal-extent aliases and a
nonzero backing identity. Unknown memfds, private/RWX/unpaired/mismatched pairs
fail closed. Ordinary absolute paths retain strict resolution and hashing,
including path spaces; missing/deleted ordinary files still fail. JIT machine
code bytes are explicitly excluded, not described as immutable native files.
Kernel vDSO/vsyscall and other nonexecuting anonymous memory are outside the
file-identity claim; arbitrary unnamed executable mappings are rejected.

The diff against the preserved Astra2 wrapper leaves loaded-cohort source
origin, application metadata, loaded/disk BEAM MD5, executable and native-file
hash checks intact. `unchanged!/2` excludes only the new variable JIT observation
field from immutable comparisons; the original loaded-module/file subset checks
remain unchanged. The source-based JIT allowance is a profile exclusion and
does not cryptographically attest ownership or in-memory machine code.

The parent green receipt/log records22/0, exit0, TLS0 and15 mapped files/585 loaded
modules. Its log hash matches the recorded digest. It binds wrapper
`8c9c75d9...`, before the parent subsequently added0.21.3 to `main/0`'s allowed
cohorts. The current wrapper is `0ea66635...`; the mapping logic is unchanged
by that rebind, but final accepted-source verification must be fresh after the
parser repair/cohort change. Actual TLS baseline/candidate cases remain NOT RUN.
No positive TLS or M3 acceptance is inferred. Preserve TLS Sol3/unsuccessful2/Astra2.

The deferred B21 envelope in the canonical fixture plan still names0.21.2
(line614). Before separately designing/admitting B21 against0.21.3, rebind that
envelope to actual qualified cohort/tag/tree and hashes. Baseline B01-B20 is
independent; current B21 flags remain fail-closed before allocation.

Reviewer repair counters Sol0/unsuccessful0/Astra0; no received counter reset.
No background command or owned VM exists. Remaining gates are the parser fix
and fresh independent delta review/regression, parent install/compile
checks, actual H1 baseline20 and supplemental TLS runtime qualification.
Feature97/N8, numerical accounting, managed activation/soaks and M4 remain gated.
