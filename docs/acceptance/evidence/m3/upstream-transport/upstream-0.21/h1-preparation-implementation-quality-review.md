# Managed H1 preparation implementation code-quality review

Task: `m3_managed_contract_review`, separate direct independent Sol
**code-quality-only** assignment, 2026-10-11 Asia/Shanghai. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline/HEAD
`4cc7a1a967d1b90a62d42db438316b10a03a1e16`. The reviewer authored none of
the implementation. This assignment owns only this new report; other writers'
source, documentation and processes were preserved.

## Verdict and scope

**PASS for code quality of the four frozen, formatted pure additions.** No
actionable executable finding or concrete forged-policy crash was found.
One opening documentation-status finding was resolved by the parent before
this verdict. The reviewed implementation is small enough to trace directly,
uses finite explicit grammars, and introduces no process, I/O, concurrency or
global state. No source change or regression-test repair is requested.

This is independent static review of both modules, both tests and the final
design/plan. No Mix, VM, test, formatter, network or commit command ran here;
no parser/term proof report was reviewed. Parent-reported pre-format26/0 and
completed formatter/global check exit0 remain separate evidence. Fresh tests
of the reviewed formatted bytes are still pending. Review PASS establishes no
runtime budget, production activation or full M3 acceptance.

## Quality trace

| Concern | Review result |
| --- | --- |
| Bounded source rejection | Preparation25–29/68–84 require exact map shapes before nested traversal. Scalars114–122, URL byte/backing351–357 and fixed IP tuple359–367 are checked before variable source walks. Pair clauses239–262 accept a proper list only after independent count/logical/backing checks; cap clauses precede head destructuring. Trust369–395 follows the same ordering. A valid256-field prefix followed by a50,000-cell nested head returns `:request_limit` at cell257; the nested head is never inspected. Equivalent128-trailer/certificate cases reject at129. |
| Helper scans and allocation | Complete pair preflight precedes URL parsing, semantic scans, declaration scans, public trailer helper, copies and constructor enumeration. Byte scanners consume capped binaries. Declaration298–340 bounds each token class at128 before `HTTP.Trailers.upload/2`; the129th declaration is rejected before token scanning. Comma matching consumes successive suffixes and OWS trimming progresses one byte per step. There is no repeated scan of a growing source tree. Small fixed IP/constructor tuple conversion and bounded output `Enum` calls do not operate on rejected caller lists. |
| Forged canonical policies | Canonical124–221 checks exact struct shape, compact bounded origin/host, numeric address and parsed consistency. Options152–181 match exactly11 fixed entries and a fixed six-entry socket list, with no generic caller-option enumeration. SSL185–206 matches an exact five-entry grammar. Certificates must pass the proper-list/binary/count/backing preflight before `compact_certificates?/1`; nil trust short-circuits before that traversal. SNI equality against the generated≤253-integer list can examine only that matching prefix before rejecting an excess cell or malformed tail. Final ETF sizing is reachable only after the finite grammar succeeds. |
| Concrete malformed-policy paths | A50,000-element `open_options` list fails the finite option pattern. HTTPS `cacerts: ["opaque" \| :bad]` fails trust preflight and never reaches compact traversal/ETF. `cacerts: nil` fails the non-nil condition before compact traversal. An SNI with the exact host prefix plus an arbitrary nested next head differs from the required terminating `[]`; the nested head is not enumerated. Mismatched scheme/port/address/option origin or extra struct keys return fixed `:invalid_policy`. These are static branch traces, not newly executed tests. No general rescue was added to conceal invalid-tree traversal. |
| Compact ownership and immutability | Origin, lower-case host, exact URL, target, each pair name/value and each opaque certificate are copied with `:binary.copy/1`; SNI is generated from the bounded host. Parsed URI/source maps are absent from outputs. Revalidation checks every variable retained binary leaf and its fixed grammar before reuse. Output shares only immutable already-owned values, fixed literals and the admitted PID term. PID preservation does not interact with or claim ownership of its process. Runtime referenced-backing evidence remains the parent's test obligation. |
| Behavior and errors | URL preflight forbids whitespace/control, bad percent escapes, fragment and backslash before bounded `URI.parse/1`; only its expected `ArgumentError` is collapsed. Effective origin comparison preserves case/default-port equivalence. Target construction keeps percent spelling, query order and a present empty delimiter. Pair copying preserves original spelling/order/duplicates. The public pure trailer helper applies declaration/forbidden-name rules after finite validation; all helper rejections collapse to `:invalid_trailers`. Error branches return fixed atoms without retaining caller values. |
| Stack/resource structure | Source list walks, semantic byte scanners, token/OWS loops and pair semantic/declaration walks advance through bounded values. Constructor recursion has shallow validated nesting, pair lists≤256, certificates≤128 and SNI≤253; it cannot descend into arbitrary caller terms. `copy_trust/1` is non-tail recursive but bounded at128 entries. Parsing, target creation, SNI, ETF and serialization transient bytes remain explicitly open P3/P4 work; source-plus-owned backing is not advertised as an allocation peak. No concrete unbounded stack or allocation path was identified inside this approved finite contract. |
| Complete constructor accounting | Constructor463–505 runs only after complete source validation or on newly constructed canonical values. `:maps.fold/3` includes struct keys, avoiding the former Enumerable-on-struct failure. Each map key/value, tuple element, list head, binary reference occurrence, integer/atom/PID occurrence is counted; no equality-based binary deduplication hides references. Scalar manifests509–532 retain no input or canonical payload. Pair reverse accumulation is separately recorded as extra cons cells. Neither these counters nor ETF length become VM heap/native-delivery estimates. |
| Fixed unqualified facts | Accounting6–76 is a literal facts tree and a permanently refusing `activation_status/0`. Profile/runtime/cohort identities, independent request/trailer/response pair caps, source caps and upload-framing arithmetic are readable directly. P0–P6 and explicit P4 coverage stay unqualified. There is no evaluator, caller proof input, activation success or mutable qualification state. |
| Maintainability | Validation, semantic checks, copying and manifests are separated into narrowly named private functions. Explicit field/trailer/trust counters make rejection precedence visible without a generalized traversal framework. Some fixed limits/options appear both in construction and canonical validation; that deliberate redundancy permits exact revalidation and exact fixture checks. No dependency, public adapter interface or surrounding module was altered by these additions. |

## Independent fixture assessment

The preparation tests use22 async cases; accounting uses4. They contain no
sleep, peer, global-state setup, mailbox protocol or timing-dependent assertion.
`self()` is only an admitted PID term. The test-only compact/scalar walkers
inspect finite returned trees, rather than replacing production validation or
reusing its constructor helper.

The compact fixture first compacts its parent with `:binary.copy/1`, then takes
an80+-byte slice. Assertions prove8192 or65537 source backing before checking
copy/rejection results, preventing eager tiny-slice copying or append capacity
from silently invalidating the fixture. Full output traversal checks every
retained binary, not just the selected value. Repeated references deliberately
exercise occurrence-based aggregate rejection. The parent must still execute
these assertions on the pinned runtime after formatting.

Python independently constructed literal policy/request/TLS trees with distinct
atom and binary tags, without running Elixir or the production walker. It
confirmed policy source19 bytes and owned50 bytes/3 binaries/17 cons cells,
tuples `{2:17,4:2}`, one7-entry map,31 atoms and17 integers. Request source54
and owned62 bytes give116 coexistence, binary occurrences5/6, map sizes7/9,
atoms9/12 and integer occurrences2/2. TLS owned cons37/integers30 include the
top-level port, SSL depth and generated SNI integers.

Independent arithmetic also confirmed `1+1+65502+32=65536`,
`2+1+65529+4=65536`, pair skeletons10240/5120/655360 and maximum framing9.
Literal expectations and boundary tests therefore have support independent of
the implementation. Static test counts do not establish execution or coverage
of every forged variant. The branch traces above supplement the existing
forged-policy cases without pretending those variants were run.

## Finding resolution and verification

The initial design opening still said formatting was pending, despite its
corrected execution handoff. The reviewer sent this actionable status finding
to the parent. Final design4–6 now explicitly records written design/plan and
implementation specification PASS, pre-format26/0 and formatter/global check
PASS, with quality review/fresh formatted tests pending. **RESOLVED**; no
actionable finding remains. The parent changed the design; this reviewer did
not edit it or the earlier specification report.

Read-only full source/test/design/plan reads, Git identity/state, independent
literal Python arithmetic, four frozen SHA-256 checks,22+4 test declaration
counts and a static process/I/O/global-state API scan completed. The first
scanner expression produced exit1 because its `send` prefix also matched the
literal `send_timeout` option; the call-aware corrected scanner exited0. This
was a diagnostic-script false positive, not an implementation/test failure or
repair. Final report whitespace and frozen-source stability are checked before
handoff. No executable validation is claimed by this reviewer.

## Handoff

Task status **DONE for independent code-quality review only**. Assignment is
direct; reviewer Sol repair rounds0. Received pure-task counters remain initial
unexpected3, targeted repair validations3 successful/0 unsuccessful, Astra0.
No escalation gate or design/product decision is needed. All reviewer commands
finished; no reviewer process/runtime session was started or remains. Only this
report was created during this assignment. Parent owns fresh formatted tests,
execution-status/checklist updates, any final evidence and local commit decision.
P0–P6 and numeric H1 activation remain NOT ESTABLISHED.

| Reviewed input | SHA-256 |
| --- | --- |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h1_preparation.ex` | `114dfce56ad02ee65b588caec861ad7c6b46097b06690cb5af5ed8504beadf56` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h1_accounting.ex` | `e450888a458a4d1d5205b2c08563d34621bdce7b953fcd6fb72c75ded038febe` |
| `apps/gaoxy_proxy/test/managed_h1_preparation_test.exs` | `3d30aeb065362967ef66a03f44cfdca2c8473b5f57e805d9ea84852a2f7116a4` |
| `apps/gaoxy_proxy/test/managed_h1_accounting_test.exs` | `691188a72264f3a50d15a958c6f1b8ce5ba08efb8c3511c21ab0a9eb969737f0` |
| Final design | `505612790daa0ab1d89e6d9aa0fbc60c719953e36bee6aede1b3959d3b9b1bc1` |
| Final plan | `e50d7b97e65ef7ebdc44ba8f0c4f6867bf3eb0c4e54af975e626959e22864b14` |
