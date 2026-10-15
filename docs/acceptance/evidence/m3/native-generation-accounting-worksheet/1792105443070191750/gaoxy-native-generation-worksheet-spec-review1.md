# Native Generation worksheet independent SPEC review1

**DONE — PASS_PURE_SPEC. No open SPEC findings.** Direct read-only assignment. This verdict covers the frozen pure prerequisite; it does not qualify runtime accounting or complete the subsequent independent CODE gate.

R=`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; branch `codex/m3-h1-resource-foundation`; HEAD `48a71a70acbe9cb46f99b82e4062c6f5f25d9667`. Reviewer changed only the two assigned `/tmp` reports. Existing untracked task files and others' work were preserved.

## Frozen sources and actual gates

* `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_generation_accounting.ex` SHA256 `73249ba0952f33cb7605d1ca8a5c7aecfe240d93456a3ad9f877ee9a9501636c`
* `apps/gaoxy_proxy/test/managed_generation_accounting_test.exs` SHA256 `6e4b24a4b578c92f7731774f3e5c14b7f21472a5c8f8ffb9609aaf22c7f48a7a`
* `docs/designs/m3-native-generation-accounting-worksheet.md` SHA256 `f2562dedca75267c5f8bce008e590d5e156c478f6c0f1fac56466f1c06e8e619`
* `docs/plans/m3-native-generation-accounting-worksheet.md` SHA256 `241243ee7debb1183e3cbe2ca86829425d35b6d2728ad6bd01a6f9469ea729b4`
* `docs/acceptance/m3-native-generation-accounting-worksheet.md` SHA256 `f38bcb48c53764e3e743d0a09fa700aa4c38e9b865ecc5350711cc5520cf2592`

All18 original/expanded core identities match both actual disk and HEAD. Loaded OTP gen/gen_server and Elixir call sources are hashed in JSON. For each fresh gate, both78-entry source manifests match, all actual files were initially rehashed with zero mismatches, and the exact output log matches its recorded SHA256/byte count. A final parent plan/acceptance execution-status tail was then read and rehashed: those two documentation hashes changed after gates, while module/test/design and all other76guards still match. JSON distinguishes gate-time and final documentation identities; no contract/code change occurred.

* `worksheet-green2.json` SHA256 `b88f4511139666e601bf51e8b5ad0fa637ceb4f941b438a92246b170e93dcafb`; log `8a027d41a294aeb0fdbee30f39836bfc14bc8f3a466db2214b1183111b1507b8`. Actual exit0, joined, process-group absent, source stable, zero warnings. Counts: {'doctests': 0, 'excluded': 0, 'failures': 0, 'properties': 0, 'skipped': 0, 'tests': 24}.
* `format-check1.json` SHA256 `032fc1b09b570562c2a051925c068bd2faf6098904f5fcadb3d48a1763d2ce3a`; log `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`. Actual exit0, joined, process-group absent, source stable, zero warnings. Counts: {'doctests': 0, 'excluded': 0, 'failures': 0, 'properties': 0, 'skipped': 0, 'tests': 0}.
* `strict-compile1.json` SHA256 `99dd8d043d2648206827f57fa95c40125e9e77340f2b830ef366078598bb99e6`; log `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`. Actual exit0, joined, process-group absent, source stable, zero warnings. Counts: {'doctests': 0, 'excluded': 0, 'failures': 0, 'properties': 0, 'skipped': 0, 'tests': 0}.

The fresh test command is `nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 --seed 1 apps/gaoxy_proxy/test/managed_generation_accounting_test.exs`. Format checks only the new module/test; strict compile is `mix compile --warnings-as-errors` under the same environment. These are audited parent executions, not reviewer runtime runs.

The initial24/2 GREEN failure remains archived. Its two exact-expectation blocks omitted standalone ETF version bytes: E(0)=3 and INTEGER_EXT E=6. The production module was unchanged. I independently derived every corrected retained row and large-M expectation from ETF syntax; full equality assertions remain. Fresh24/0 is bound to the final corrected test.

## Criteria

* **W1 PASS** — Actual baseline/branch/worktree and 18 immutable sources rebound to HEAD; selected loaded gen/gen_server/Elixir sources hashed; three fresh gates bind current module/test.
* **W2 PASS** — All34 complete constructors, owners/lifetimes/multiplicities checked against source; independent ETF grammar reproduces every baseline cap/subtotal and both2758572/8656812 totals.
* **W3 PASS_PURE** — Original actual pin/lists go through existing full grammar; private derived count/ETF precedes arithmetic; no candidate cons/append/singleton constructed. Runtime insertion remains C1.
* **W4 PASS_CONDITIONAL** — G7/T8 full pin R73862/75921, singleton/result/alias constructors separately paid; supported G-H1/T >Q remains genuine R role. C2 source PID/ref inequalities reviewed, actual public owner boundary execution remains later.
* **W5 PASS_PURE** — Request-only kinds and handle/provider/owner/epoch schema enforced. No two-argument authentic-holder/operation authority claim; original provenance paid and later runtime correlation contract retained.
* **W6 PASS_PURE_DESIGN** — Exact finite nonrecursive normalization; finite release/cancel/primary-precedence/empty-scope telemetry table retained as later C3/C5 contract. No toy outcome model or runtime success claim.
* **W7 PASS_SPEC_REVIEW** — Fresh green24/0/0skip/0exclude, strict compile and scoped format receipts independently audited with78 rehashed guards each. Independent CODE and post-review fresh affected verification remain parent-owned.
* **W8 PASS** — Original Generation/Resources/owners/Admission unchanged, legacy kinds remain, fixed reservations unchanged, opaque dynamic Store scope and H2 Generation exclusion intact; no activation/publication/runtime claim.

## Prior findings R1–R5

* **R1 CLOSED_FOR_PURE** — No aggregate candidate construction; exact empty/nonempty/count/byte preflight before later caller construction; C1 actual runtime insertion explicitly open.
* **R2 CLOSED_FOR_CONDITIONAL_WORKSHEET** — Complete supported G7/T8 genuine result envelopes paid separately at R>Q; whole ledger and loaded package source predicates included. Real owner receipt boundary remains next-stage C2.
* **R3 CLOSED_FOR_PURE_SCOPE** — Exact request-only grammar; authentic original T holder/operation correlation deferred to the later seam holding those facts, documented explicitly.
* **R4 CLOSED_DESIGN_ONLY** — Concrete finite release outcome/cleanup uncertainty/primary preservation policy specified; actual C5 implementation/testing remains open.
* **R5 CLOSED** — Original14 plus G/Lifecycle/Admission/Telemetry identities match actual disk and baseline; loaded call constructors and toolchain source identity bound.

## Independent arithmetic and constructor proof

Explicit tuple/map/proper-list/improper-alias algebra independently reproduces all34 literal row caps and multiplicity/subtotals; B65536=2,758,572 and B1048576=8,656,812. At M2^64, B=110,680,464,442,259,675,080, plan cap67, update2070 and wire6205. All11 retained-boundary exact totals match the corrected tests. JSON includes complete tables.

H/Q65536, k64, S2048, Rf2062 are source derived. G7 R73862/T8 R75921; their complete {:ok,pin} payloads73868/75927 and maximum alias replies75943/78002 are paid separately from Q. Actual G-H1/T constructor success beyond Q stays a supported genuine receipt; G-H2 post-construction singleton validation does not erase its paid raw constructor. Existing shared validator retains all legacy kinds.

C2 source evidence was independently inspected from the archived immutable OTP excerpts/package derivation record and actual loaded call-source files. NEW_PID_EXT adds13 to nodeETF; ordinary make_ref3words and native aliases at most5words yield reference<=nodeETF+27, therefore future-ref<=2048+14. This is source/package qualification, without a complete NAR recomputation or binary rebuild claim. No sampled pid/ref size substitutes for these inequalities. Real public owner boundary tests remain later C2.

Revision2 context is exactly3PIDs/1reference/:request/signed64 deadline/nonnegative retained, scalarETF<=2048 and deadline<=max-1000. Its explicit pure grammar accepts past deadlines and inspects no clock. M accepts every positive integer; default1048576 is retained. B pays exact E(M), E(B), E(retained+B) and converges; no universal M/depth/dynamic-Store inventory cap is invented.

The complete report is review metadata, never an activated Admission charge or retained plan. The future plan remains exactly `{:native_generation_capture_v1,M,H,Q,B}`. Preflights validate and measure original maps/lists and use private trusted numeric summaries; no public stats authority and no candidate singleton/cons/append list is built. Exact finite reason top-level normalization exposes only the specified atoms.

## Boundary and remaining work

Pure arithmetic/schema/preflight/finite-reason SPEC passes. C1 actual runtime preflight/provenance, C2 real owner boundary, C3 production finite errors, C4 context/plan adoption and C5 release/primary/telemetry/charge-retention remain separate. No native worker transfer, H2 Generation activation, runtime cleanup, protocol/load, publication/deployment or production acceptance is claimed. No total arbitrary-provider heap proof or dismissed97 requirement is introduced.

Independent CODE review and fresh affected verification after actionable findings are parent-owned next gates. Parent updated current pure execution/verification status after the gates; I reread that plan/acceptance tail. It correctly leaves SPEC/CODE/post-review verification/commit bookkeeping pending until completion and keeps runtime unqualified. Parent must finish final acceptance/checklist bookkeeping after reviews. This report binds current module/test/design/plan and fresh receipts exactly.

All own commands finished; no runtime/background process was started or touched. No repository/Git mutation, Nix/build/test/formatter/network execution by reviewer. Reviewer repair rounds0; inherited24failedGREEN/27root events and exhaustedAstra2/2 remain recorded. Worksheet adds failedGREEN1/test-contract repair event1/production repair0. Pre-RED deprecation compatibility1 and pre-runtime adoption tooling failure1 remain separately recorded. Known lineage arithmetic25/28 counts only inherited group plus worksheet series; it is not a global Sol-round count. Parent confirmation and archived diagnosis/repair receipts are bound in JSON. No design decision, external permission or Astra gate.
