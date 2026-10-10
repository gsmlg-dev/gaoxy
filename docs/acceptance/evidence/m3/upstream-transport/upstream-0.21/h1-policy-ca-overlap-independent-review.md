# Independent review of H1 policy and host-CA overlap proof

Date: 2026-10-11 Asia/Shanghai. Task `m3_policy_ca_overlap_review`; separate
direct Sol specification/source and evidence-quality assignment. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `6ef8a3ad8e26e2f4992adeaf9558199aef8105a5`.
Only this new report is owned. Parent changes to acceptance/design/status/plan
documents and all untracked evidence were already present and preserved.

**DONE — PASS_STATIC_CONDITIONAL_REVIEW.** No actionable correctness or
evidence-quality finding was identified within the explicit canonical-DER,
warm-cache, source-formula scope. The checkpoint does not establish preload or
immutability enforcement, source-to-loaded-code equivalence, complete P3,
simultaneous reachability, native representation, activation or any whole P0-P6
gate. M3 remains unqualified. Upstream issue95 remains a separate open blocker.
This review does not authorize or perform a dependency upgrade.

## Exact reviewed identity

| Input | SHA-256 |
| --- | --- |
| [Authored worksheet](h1-policy-ca-overlap-proof.md) | `07cfb87281e5891673238c1614ea0a7d5fd5b89001f8eff0b9ba043e546832cc` |
| [Authored receipt](h1-policy-ca-overlap-proof.json) | `b44c4bf52b8a0a54f34c6116b33f8849bf846c4284bab66eed7484f4cbaa82dc` |

All34 source/input entries in the receipt independently matched their SHA-256
values. All ten installed/source comparisons matched both byte streams and
their pinned hash, and all six prior-source comparisons were checked against
the actual prior wire receipt rather than accepting stored booleans. The native
proof pair hashes matched unchanged. The separately frozen identity checkpoint
pair was preserved and is not promoted into a CA-snapshot/literal certificate.

OTP source root:
`/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source`.
Elixir source root:
`/nix/store/qa7m7ymrcm7izhjdki9r5z1gsvgbfd05-source`.
The seven installed OTP source comparisons use the recorded OTP28.5.0.7
installation. The three Elixir comparisons use the recorded22fybr installation,
whose compiler input differs from the current runtime. The separate loaded
identity checkpoint resolves its selected Elixir modules under jc6g5l instead.
Consequently these source comparisons do not establish that those currently
loaded modules were compiled from this source tree. The authored proof correctly
leaves loaded-code/literal identity and compiler-input equivalence conditional.

## Snapshot and exclusion review

`public_key.erl:2582-2585` delegates `cacerts_get/0` to
`pubkey_os_cacerts:get/0`. The latter's warm branch (`:40-61`) returns the
`persistent_term:get` result unchanged. `erl_bif_persistent.c:359-397` returns
the stored value pointer; `persistent_term.erl:40-60,181-213` documents the
non-copying retrieval. This supports zero new snapshot-list/certificate-record/
DER constructors on a direct warm hit. It does not price the entire operation,
hash-table/native work, reference roots or new surrounding options.

The returned snapshot is a list of combined `#cert{der,otp}` records, a tuple
with the cert tag and two fields, not merely a list of DER binaries.
`public_key.hrl:628-632`, `public_key.erl:342` and the loader's decode functions
agree. `persistent_term:put` copies the stored tree into a literal area with
sharing preserved (`erl_bif_persistent.c:738-761`); source/preparation terms and
the persistent copy are separate roots during cold population.

The cold branch application-loads public_key and honors configured paths.
`pubkey_os_cacerts.erl:136-177` reads complete files and decodes PEM/ASN.1,
including directory scans and list concatenation. Canonical c/T/backing caps
do not constrain this branch. Both the upstream freeze's `put_new` argument and
the SSL adapter's default list evaluate `public_key:cacerts_get()` eagerly,
even when explicit CAs later win. Therefore explicit DER does not prevent a
cold read, decoder peak or loading failure. The proof preserves this limitation.
The public API is `public_key:cacerts_get/0`; no `ssl:cacerts_get/0` export is
present in the inspected SSL exports.

Reload/clear can replace or erase the stored complex term. The persistent-term
documentation and literal-copy paths support old referenced data being copied
into processes during collection. The approved immutable-global exclusion
requires the snapshot to be loaded and identified before the controlled
boundary, with no mutation through every referencing preparation/scope lifetime.
The source proof does not enforce or measure that condition. It does not extend
the exclusion to caller-derived DER, newly constructed referencing options or
owned copies. A finite/reachable snapshot-size certificate was not supplied.

No boundary narrowing was found: newly owned structure/backing/copies remain
included, and TLS-private decoded trees remain outside the declared ledger.
Exposed delivery backing, socket-handle terms and tracked resource metadata
remain included. The host snapshot's exclusion cannot erase cold-loader
preparation peaks or purge-created owned copies.

## Constructor and option-transform review

The preparer validates certificate count, per-certificate logical/referenced
backing and aggregate limits before `copy_trust`. That recursion makes c new
list cells and c compact binary copies, without a reverse list. Source-plus-copy
payload occurrence sums <=2T are only a partial backing component; wrappers,
URI/manifest/host work, call frames and retained source roots are additional.
This validates structural trust admission, not DER cryptographic validity.

| Restricted component | Independently confirmed source result |
| --- | --- |
| Canonical policy logical shape |11 open pairs +5 SSL pairs +6 socket pairs +2 version cons +c DER cons +h SNI cons =24+c+h cons,22 pair tuples. Policy struct has7 entries including `__struct__`. Address/origin occurrences can be shared and are not pair tuples. |
| Upstream canonical SSL freeze | Three absent-file materialize branches return the same options. Existing cacerts/verify/versions/depth survive put_new; warm host-CA argument is unused. Three eager host-to-charlist operands contribute3h construction events. Final SNI put rebuilds four survivor cons and adds one cons/pair. Explicit DER list/backing is retained. |
| Restricted validation helpers | Open keys/uniqueness33 +SSL15 +sockets12 +SSL pair-to-list10 +final wrapper/pair-to-list24 =94 cons events, plus d address cons (d=4 or8). Uniq maps have22 total insertions and maximum11 keys per pass. This excludes other helper/closure/map/URI work and rejected-path peaks. |
| Frozen transport/policy |H1 transport has8 pairs. Prefix/tail/append-copy source events and returned policy/origin/limits maps are separately named. The source-to-state/ETS/caller copy edges remain additional obligations. |
| SSL canonical normalization | Five new list cells return existing pairs in the identity branch; DER is not reconstructed. |
| Default/drop/merge | Six default pairs plus nested match_fun pair are constructed or literal-shared conditionally. Dropping cacerts rebuilds five survivor cons; merge retains only customize_hostname_check from defaults, constructs one filter cell and one append-copy cell, and shares the normalized five-cell user tail. Merged list has6 pairs and explicit DER. |
| Final TLS option shape | Protocol3 +SSL6 +socket6 top-level cons, nested1 +versions2 +c DER +h SNI =18+c+h logical cons;15 pair tuples including nested match_fun. Maximum399 cons at c128/h253. Canonical maximum405. |
| Restricted TLS source events | Normalize5 +defaults6 +nested1 +delete5 +filter1 +append1 +prefix3 +SSL append-copy6 +prefix append-copy3 =31 cons events, excluding SNI and versions. Cancellable connect's earlier TCP list and ordinary/cancellable unused address default add separate construction events. |

The pinned Keyword implementations support the identity claims: put_new returns
its input when the key exists; delete rebuilds surviving list cells with existing
pairs; merge filters the left side and appends the original right tail. Enum.map,
Keyword.keys and list uniq create their stated spines. Fixed lists/pairs may be
compiled literals, so logical occurrence counts can conservatively repeat shared
nodes. The source-event subtotals are restricted construction counts, not exact
fresh allocations or simultaneous-live peaks. The author consistently retains
this distinction;31 or102 is not a byte budget or a complete helper inventory.

The hostname matcher source captures no caller host/certificate data. Its fun
object/native layout remains an independent conditional representation charge.
The transient default cacerts pair references the snapshot before deletion;
deleting it from the result is not a proven release time for the original
defaults. The merge result carries explicit DER and a nested matcher option,
without the default host-CA root in its cacerts field.

Policy's deterministic serialization hashes the full `{origin, transport}`
identity, while its preceding1MiB cap checks `{SSL, sockets}`. That cap is not
a bound on every serializer/crypto scratch allocation, output backing, origin
conversion or old/new-policy overlap. The worksheet explicitly leaves those
finite-grammar derivations open and uses no ETF-to-heap multiplier.

## Independent checks

Read-only scoped Git/status/source/receipt commands established the assigned
baseline and existing parent edits. The published Python verifier was extracted
from the exact authored Markdown and executed unchanged, exiting0:

```text
PASS pinned hashes, installed matches and constructor vectors: 32384
```

A separate Python checker exited0 after independently rehashing34 inputs,
checking ten installed matches, six prior comparisons and the frozen native
pair. A linked-cons/tuple model independently verified same-list put_new,
same-pair normalization/delete, explicit-DER identity and merge-tail sharing.
A concrete nested tree with c=1/h=1 yielded canonical26 cons/22 pair tuples and
TLS20 cons/15 pair tuples. Independently summed source categories over all
128*253 combinations matched24+c+h and18+c+h and their405/399 maxima. Restricted
helper94+d and TLS-event31 subtotals also matched.

```text
PASS independent checks:34 hashes; installed10; prior6; native2; model identity/tail/pair reuse;32384 constructor vectors; helper94+d/TLS-event31; links/fences/whitespace
```

These are independent abstract source-model checks, not Elixir execution or
measured heap liveness. Byte identity is not original compiler-input proof.
Current authored/native/identity hashes and final report links/fences/whitespace
were checked again before handoff. No VM, Mix, C compiler, network, dependency
operation or protocol gate was run by this reviewer.

## Remaining obligations and counters

Open: host snapshot identity/preload/immutability enforcement; loaded/literal
identity; complete URI/manifest/serializer/crypto peaks; helper maps/closures
and live roots; policy copies/ETS costs; supervisor/process/message ownership
and release; rejected-preparation reservation; per-attempt phase and turnover
multiplicity. Persistent-term retrieval is not interchangeable with ETS copies.
The examined source passes policies through start arguments, Scope state,
configuration ETS and admitted-caller lookup; none of those edges is priced or
released merely by proving a warm hit. No retry barrier or complete P3/P0-P6
obligation is closed. No new upstream defect or local workaround is established.

No authored-proof correction or new user/product decision is required for this
bounded delivery. This report leaves authored pending-review fields unchanged.
The parent owns subsequent cohort upgrade/requalification and final acceptance.

Received source-task counters remain Sol implementation/repair0, unsuccessful0,
successful diagnostic selector corrections4, Astra0. This separate review has
Sol diagnostic/implementation repair0, unsuccessful0, Astra0; all independent
checks passed on their first execution. No escalation gate applies, and no
earlier task's counters were reset.

All own commands finished; no background jobs, sessions or agents were started.
Only this report was written. Authored native/identity/CA pairs and all concurrent
parent changes were preserved. No staging, commit, push, upstream mutation,
product/dependency edit or peer-process action occurred. Runtime/protocol gates
remain NOT RUN by this reviewer, and M3/P3/P0-P6 remain unqualified.
