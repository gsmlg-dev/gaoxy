# H1 request/wire independent source and evidence review

Date: 2026-10-11 Asia/Shanghai. Task: `m3_h1_new_evidence_review`.
Assignment: direct Sol independent specification/source and evidence-quality
review. Status: **DONE**. Specification/source verdict: **PASS**. Evidence and
quality verdict: **PASS**, restricted to the source worksheet and static receipt.
No actionable finding remains against the frozen inputs below.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, review baseline HEAD
`d8e3a2622e88037419077989547e2e0a00d5c4e4`.
The two proof inputs and three map-layout artifacts were pre-existing untracked
files. The reviewer owns only this new report. Existing artifacts, executable
files and parent jobs were preserved. No Git staging or commit was performed.

## Frozen review inputs

| Input | SHA-256 |
| --- | --- |
| [Source worksheet](h1-request-wire-proof.md) | `9270fe02df98a51a6dcbb8bbc4e1fcb4eecf1d8461b13de732eb9104602103dc` |
| [Static receipt](h1-request-wire-proof.json) | `96e228c6fcaa82e5d7b0ff19c08526d653dcc2b2db33e3ea3f74b5ecc807dc8e` |

Both identities were recomputed independently. The receipt's Markdown identity
matches the file. The reviewer also checked all 41 recorded current input hashes:
20 repository entries, three Elixir source entries, two OTP source entries,
seven evidence inputs and nine preserved-report entries. All match. These are
40 unique files: `h1-preparation-spec-review.md` occurs in two groups. The 25
source-input count means the 20 repository plus five Elixir/OTP entries; it does
not mean 41 distinct source files.

The 19 prior comparisons are independently reproducible against
`h1-string-transform-proof.json`: eight shared repository hashes, two shared
Elixir hashes and nine preserved-report hashes match. Its three additional
shared evidence-input hashes also match; those are additional comparisons,
not 19 new unique inputs. Existing provenance and String lemmas remain the
explicitly declared trusted boundary rather than a new loaded-code claim.

For the Promise shape, this review additionally binds the directly inspected
`deps/http_fetch/lib/http/promise.ex` to SHA-256
`d49110cfae54440fd16568391a3a2c1a90ef0c7831ee458185e0e361e9c74064`.
This supplementary file is outside the receipt's 41 records. It declares two
fields plus `__struct__`, agreeing with the worksheet's three-entry map.

## Independent specification and source findings

| Claim | Reviewed evidence and verdict |
| --- | --- |
| Canonical ownership facts | `ManagedH1Preparation.request/2` checks bounded source grammar and aggregate charges before its compact-copy construction. `copy_pairs/1` retains source, new tuples and reverse/ordered spines as potential overlapping roots. The partial payload and constructor bounds agree with this path. PASS. |
| Mapping is conditional | `HTTPFetchClient.open/1` remains dedicated and does not wire canonical preparation or a managed scope. The proposed 14-entry Fetch keyword list is a future mapping. The report does not describe it as shipped integration. PASS. |
| H1 option exclusion | H1 policy transport contains eight entries and omits `http2_profile`. The open-policy validator accepts native-v1 separately. `Dialer.http2_options?/1` treats a non-nil profile as H2 options and rejects the H1 route. The proposed Fetch mapping omits that field. PASS. |
| FetchOptions representation | Independent identifier extraction includes digit-bearing `http1/http2/http3` keys: 32 declared fields, 33 entries with `__struct__`. Request and HTTP1 each have eight declared fields, nine entries. `M_FetchOptions33` remains symbolic; the worksheet never applies the flat-map formula above the 32-entry cutoff. PASS. |
| Policy admission ordering | `HTTP.fetch/2` parses the URL, constructs options/Request and eagerly generates/inserts its UA before `ManagedTransport.prepare/2`. Policy counts those resulting fields. Canonical f=256 without UA becomes 257 and rejects. A lease cancellation is not a proof that preparation roots were released. PASS. |
| Finite keyword construction | Fetch produces ten entries for the supplied scalars. H1 policy adds six unique keys to reach 16. Scope adds five pool/coordinator keys plus lease/deadline to reach 23. Lifecycle adds one, then async preparation inserts `connect_failure_token` even when nil, reaching 24/25. TLS pinning replaces an existing key. Intermediate Keyword and ETS-copy costs remain open. PASS. |
| URI captures/copy | Exact Elixir source has nine outer and five authority capture groups, yielding at most 10+6 results. Exact OTP binary-capture code uses `erts_make_sub_binary`; binary copy allocates the result bit length and can yield with source/result rooted. Capture occurrence sum and backing-union overcounts do not replace trim, native regex or integer scratch terms. PASS. |
| UA construction | Both Fetch and HTTP1 eagerly evaluate the UA candidate before `set_default`, including explicit-UA cases. Independent interpolation stripping yields 37 fixed literal bytes. OS/version/Application outputs, native work, compiled construction capacity and candidate backing remain open. PASS. |
| Framing/head bounds | Direct proxy routing keeps original headers and origin form. UA/Host defaults, Connection replacement, nil CL deletion and PID fixed/chunked framing match the table. Duplicate identical CL values collapse; no new CL charge is needed when an original CL already exists. Field and logical head bounds are conservative, conditional on successful serialization. PASS. |
| Header helper/work bounds | The no-TE fixed-body path plus trailer declaration and the original-CL serialization query uses at most 16 Headers operations. Five possible synthetic normalizations and declaration/trim/CL helpers remain additional. Per-operation constructors and work are not presented as a live-memory peak. PASS. |
| Wire constructors | Header lines have four cons plus one outer cons per field, and the head has six. Nil/PID wrappers, protocol maps, method/target/header byte-list validation and CL integer conversion match source. No whole-head flattening is introduced in the restricted HTTP-layer path. Public send costs remain symbolic. PASS. |
| Root/release graph | Fetch caller, task, owner, dialer, serialization and nil/PID send roots are retained separately. Source rebinding, task launch, send return and lease cancellation are not treated as proven release barriers. Upload subscribes before start/head send, allowing a producer chunk to overlap head send. PASS. |
| Small map shapes | Owner context nine, added state keys eight, total 17; upload state seven and handle four; Promise three and Completion four entries. Their conditional skeleton sizes agree. Children, closure environments and runtime metadata remain additional. PASS. |
| Upload handoff | Four-cons nonempty chunk framing and three-cons terminal wrapper plus 5t trailer cons match public source. ACK follows successful send. The proof does not establish producer ownership, admitted overlap or one-ACK runtime enforcement. PASS. |

The exact source inspected includes the recorded preparation/adapter, Request,
HTTP1, Headers, Proxy, Trailers, lifecycle, Fetch, FetchOptions, upload,
SocketClient, Completion, managed transport/policy/scope and Dialer files,
plus the supplementary Promise file and exact Elixir/OTP source slices.
Independent String lemmas and conditional term-layout formulas were checked
against their stated scope. No replacement runtime or public API was invented.

## Independently recomputed arithmetic

- Source plus owned pair/reversal skeleton: `96*(256+128) = 36864`.
- Owned binary occurrences: `2+2*256+2*128 = 770`.
- Owned compact payload: `3*65536-2 = 196606`; source backing occurrence sum:
  `3*65536 = 196608`; combined bound: `6*65536-2 = 393214`.
- Fetch initialization: 14 keyword entries, `14*40 = 560` skeleton bytes.
  Unique transport lengths: `10,16,23,24,25`.
- URI groups: `9,5`; returned capture-occurrence ceiling: `10+6 = 16`.
  This does not price native regex or parse/trim intermediates.
- Fixed UA literal bytes: 37. Authority upper: `253+2+1+5 = 261`.
- Common head extra: `a+A+46`; fixed PID extra: `a+A+86`; chunked PID extra:
  `a+A+114`. Substitution into `m+l+14+R_h+4g` gives the reported constants
  `65864+a`, `65904+a`, `65932+a`.
- Python checked all `257*7*3 = 5397` algebra cases, f=0..256, m=1..7 and
  three body branches. All equal the symbolic formulas and stay within their
  reported upper bounds. These are model checks, not executed HTTP requests.
- Head iodata skeleton: `80*261+96 = 20976`; successful managed preflight's
  final field count is at most 260. The broader canonical 261-field bound
  does not override policy's 256-field preflight cap.
- Nonempty 65536-byte chunk: five hex digits plus four CR/LF bytes,
  `65536+5+4 = 65545`. Terminal trailer frame: `3+(65536-2)+2 = 65539`.
- Conditional small-map skeletons: context9/owner17 = 176/304;
  upload7/handle4 = 144/96; Promise3/Completion4 = 80/96.

## Quality, retained failures and remaining gates

The author receipt retains its digit-omitting collector failure and its
incorrect initial UA42 worksheet arithmetic. Final digit-aware extraction
and UA37 formulas are correct. Author counters remain separate: two successful
static/report repairs, zero unsuccessful repairs, zero executable repairs,
Astra0. Historical parser/String/provenance/credit counters are not reset or
merged into this review.

The reviewer started Sol0/Astra0. One reviewer-only static collector failed:
the first UA regex selected the earlier documentation example (93 literal
bytes), so the assertion expecting 37 exited1. Read-only diagnostics printed
both matches and isolated the cause. Restricting extraction to the text after
`def user_agent(` fixed the selector; fresh validation exited0 with 37 and all
remaining arithmetic checks passing. This was not an author/source defect.
Reviewer cumulative Sol repair rounds1, successful1, unsuccessful0,
executable0, Astra0; no Astra recovery counter was received and no escalation
gate applies.

No VM, Mix, formatter, fixture, test, network qualification, upstream mutation,
staging or commit was run. Checks were scoped read-only Git inspection,
source/document reads, Python3 JSON/SHA-256/source extraction and arithmetic,
relative-link/fence/whitespace checks. Input Markdown has four valid relative
links, balanced fences and no trailing whitespace. Final verification exited0:
both frozen inputs, all 41 source/evidence records and supplementary Promise
identity stayed unchanged. This report's two relative links resolve, fences
balance and whitespace checks pass. `git diff --no-index --check /dev/null`
for this new report exited1 because a diff exists, with no diagnostics.

`M_FetchOptions33`, Keyword/uniq/manifest helpers, URI/native/integer scratch,
UA/profile/backing and target/authority/method/UA concat terms remain open.
Compiled closure environments, spawn/message/control/resource metadata,
public-send representation, rejection/root release multiplicities,
policy/host-CA overlap, producer/admission discipline and loaded-code identity
remain open. A separate map-layout artifact was not adopted by this review.
No complete budget or production reservation is established.

**Full P0-P6, activation and loaded-code enforcement remain NOT ESTABLISHED.**
**Managed TLS lifecycle remains BLOCKED_UPSTREAM95; qualification NOT RUN.**
The retained turnover/TLS review already documents the three-element legacy
`track_tls` matcher against the eight-element pinned OTP socket shape. This
review does not rerun a live TLS probe, infer a measured leak/retirement race
or introduce a private tracking workaround. Source provenance remains distinct
from compiled reproduction, runtime qualification and production acceptance.

All reviewer commands finished, no owned background job was created, and parent
jobs were untouched. Remaining risks are the named source/runtime proof gaps
and TLS blocker, not new decisions for this bounded review. Decisions needed:
none. The parent owns serialized evidence adoption, commits and subsequent
helper/release proofs.
