# Managed H1 preparation specification review

Date: 2026-10-11 Asia/Shanghai. Task: `m3_h1_preparation_spec_review`.
Assignment: direct Sol independent specification/design review only.
Verdict: **PASS — ready for pure implementation only**. Runtime, formatter,
ExUnit, network and production qualification: **NOT RUN** by this reviewer.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, HEAD `4cc7a1a967d1b90a62d42db438316b10a03a1e16`.
Pre-existing parent-owned dependency, adapter, fixture, design/acceptance and
lockfile changes were inspected and preserved. This reviewer owns only this
new report. The design author made the three narrow corrections below; no
executable source was edited by this reviewer.

## Findings and corrections

All actionable findings are resolved in the final document hashes below.

1. Original plan lines52-53 prohibited HTTP application startup, but original
   scoped test commands at326-327 omitted `--no-start`. `gaoxy_proxy` depends
   on `http_fetch`; its application starts `HTTPFetch.Application`, including
   a Task.Supervisor and Registry. The author added `--no-start` to both
   commands, now plan329-330. The existing proxy test helper only calls
   `ExUnit.start/0`. This correction preserves the pure-test boundary; tests
   themselves still run ExUnit processes.
2. Original design69-74 promised rejection of forged/modified policy structs
   without a means to prove their provenance. Final design69-76 requires
   bounded canonical grammar, compact leaves and consistency among origin,
   scheme, host, port and options; structurally valid copies are explicitly
   permitted. No capability, provenance or unforgeability claim remains.
3. Original design144-147 and plan123-125 could imply PEM payload detection
   while also treating DER bytes as opaque. Final design146-154 and
   plan123-126 distinguish unsupported PEM/file input options from opaque
   binary-list payloads. No decoding or certificate-validity promise remains;
   HTTP/OTP retain real validation.

No remaining specification/plan blocker or new product decision was found.
These corrections do not consume implementation repair rounds.

## Contract review

| Area | Result and implementation acceptance boundary |
| --- | --- |
| Scope | Two internal pure modules and two scoped tests. No scope/handle, manager, process implementation, network, file reader, adapter wiring, dependency or lock change. |
| Profile/types | C2/R32/P0, explicit H1/OTP SSL/native-v1, buffers8192, raw stream/manual redirects. Owned URL strings, atom scheme/method, numeric IP tuple and nil/PID body are coherent with the bounded internal contract. PID ownership is not asserted. |
| Bounded rejection | Exact map size/keys before nested inspection; at most257 field cells and129 trailer/trust cells. First excess cell rejects before inspecting its contents. No unvalidated list length, Enum or ETF walk; errors have fixed atom values and no caller payload. |
| Independent limits | Logical charges, counts and referenced-backing occurrence sums are separate. Source policy backing1114112 and request backing196608 are conservative per-occurrence bounds, including repeated references. |
| URL behavior | Bounded ASCII/percent preflight precedes URI parsing. No URI input/output, Unicode conversion or normalization promise. Matching default ports/case, IPv6, query ordering, percent spelling and present empty query have explicit tests. |
| Fields/trailers | Spelling, order and duplicates survive copies. Both declaration classes have128-token ceilings before public `HTTP.Trailers.upload/2`; nil body requires empty trailers. Helper payload errors collapse to a fixed atom. |
| Trust | Explicit bounded nonempty opaque DER-list representation for HTTPS; HTTP requires nil. Per-leaf/count/aggregate backing caps precede copies. Fixed SSL/socket trees alone receive the final ETF compatibility check. ETF is never heap accounting. |
| Policy revalidation | No blanket equality against an arbitrary options tree. Bounded canonical shape, consistency and compact-leaf checks precede request use; malformed oversized forged trees must reject with `:invalid_policy`. |
| Ownership evidence | Tests first prove80+-byte fixtures share8192-byte backing, then verify compact output backing. Oversized-parent and aggregate-occurrence rejection are separate tests. Independently calculated whole-tree constructor counts include struct keys and all option/SNI occurrences. |
| Partial manifests | Fixed scalar maps count logical/backing bytes and constructors. Source-plus-owned backing coexistence and pair reversal cons are named partial facts; parsing/SNI/ETF/serialization and metadata peaks remain unresolved. |
| Accounting | Only `facts/0` and always-unqualified `activation_status/0`. No evaluator, caller constants/proofs, synthetic activation, zero-default term, byte budget or success object. All P0-P6 remain open. |
| Evidence/status | Exact source provenance sharpens identity only. No delivery/representation proof follows. H2#86 is a distinct external activation blocker; needed#87/#88 concern broader managed inputs and do not block this pure restricted grammar. |

The narrower named-facts interface intentionally defers the architecture
memo's proposed expression evaluator. It preserves the memo's requirement
that unresolved obligations prevent an activation total. File-backed trust
and producer/admission enforcement likewise remain future work rather than
silently entering this slice.

Independent static arithmetic confirmed:

- Root field fixture: `1 + 1 + 65502 + 32 = 65536`; +1 exceeds the charge.
- Trailer fixture: `2 + 1 + 65529 + 4 = 65536`; +1 exceeds the charge.
- Trust: `16 * 65536 = 1048576`; ETF overhead makes this source-equality
  fixture fail the final policy cap. Fifteen such leaves leave65536 bytes
  for the small fixed tree. Source aggregate and final compatibility limits
  must have distinct test outcomes.
- Pair skeletons: `256/128/16384 * (2 + 3) * 8 = 10240/5120/655360`.
  Response16384 is separate from the request256 cap. Upload framing is
  `hex_digits(65536) + 4 = 9`.
- Backing aggregates: `65536 + 1048576 = 1114112`; `3 * 65536 = 196608`.
  Nine references to8192-byte backing exceed a65536 occurrence cap despite
  small logical slices.

The tests are specified, not executed. In particular, compact backing,
exceptions/error categories, ETF results and forged-policy bounded behavior
still require actual implementation and scoped runtime verification.

## Frozen input identities and checks

| Input | SHA-256 |
| --- | --- |
| Initial design | `c4f6db961ca9dc6ab515de2941d0f2d82e385ba9e09ec0630905b03d934526d8` |
| Initial plan | `e3415434bea496fcf2ef7556a9de609c5a642668f809da2016c6fa0c37dfb16e` |
| Final design | `e886356ce1c6c84d05da01bfd8fcceb4b9c91b03b7e99b546c2519d30821913e` |
| Final plan | `43683281be8f4c4f5b2136fce5a357cd23a254348d0fe22af752d69a489a2000` |
| Accounting architecture | `6ac9a051172e761717da3be3861566740724ff5507601314ea332e1a36bebe81` |
| OTP source provenance | `0a71c965c2ca335fb7d36c2e33be6d2b26d0646e4c0eafdf8e88f44ad46db493` |
| `deps/http_core/lib/http/trailers.ex` | `440b945822366705f2098804657e8ed07b2a5e6dd29be216730a4c8e753dec75` |
| `deps/http_core/lib/http/headers.ex` | `490e85607b4e375323945e984b618319a48b3bc4d08148d2e55195e41d427a4a` |
| `deps/http_core/lib/http/request.ex` | `b097ad2d68d3a4d715dad594f02cc9025b6a17a267175b375a4b7d37bc675dcf` |
| `deps/http_runtime/lib/http/managed_transport/policy.ex` | `d2164cc922893b9cb626b3886d1fbdc1c4f479f1253446277120df6720df1279` |
| `deps/http_fetch/lib/http_fetch.ex` | `8cdb4d6f318233c8bfab9815d38cbdd78f38d9ad7762da15da788535b9d85d3e` |

The inspected installed/release receipts identify0.21.0 tag
`9813c126dc8b48055b9ee941c693fc27fa691489`; the runtime receipt identifies
Elixir1.18.5, OTP28.5.0.7, ERTS16.4.0.6, SSL11.6.0.6 and64-bit. These
are existing receipts, not a new VM execution. Python SHA-256 validation
matched all15 locally available OTP source files named in
`otp-source-provenance.json`; its status remains source-provenance-only,
P1/P2 NOT ESTABLISHED. No source URL/revision claim was added.

Available checks: read-only `git status --short`, branch/HEAD/diff inventory,
numbered document/source inspection, `sha256sum`, Python arithmetic/source-hash
checks, final relative-link/fence/whitespace checks and scoped report
`git diff --no-index --check`. Python checks exited0; the new-file no-index
check exited1 because a diff exists, with no whitespace diagnostics. Two initial
source searches named nonexistent files and exited2; corrected inventories
identified `deps/http_fetch/lib/http_fetch.ex`. No runtime test failed or ran.

Review status **DONE**. Pure-task counters remain Sol unsuccessful0/Astra0;
no escalation gate applies. All reviewer commands finished, and no child,
HTTP/OTP application, peer or network job was started. Parent-owned jobs were
not touched. Remaining risks are actual implementation behavior and unresolved
P0-P6; H1 qualification, managed probes/soak and full M3 acceptance remain open.
The parent owns freeze release and serialized implementation/test dispatch.
