# H1 source lemmas: independent review

Date: 2026-10-11 Asia/Shanghai. Task: `m3_h1_source_lemmas_independent_review`
(review assignment to `m3_h1_preparation`). Assignment: direct Sol, independent
SOURCE-PROOF review. Status: **DONE; PASS for the conditional source lemmas
within the scope below**. Full P1/P2/P4/P5, P0-P6 composition, a numeric
reservation, managed H1/H2 activation and M3 acceptance remain **NOT ESTABLISHED**.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline/HEAD
`4cc7a1a967d1b90a62d42db438316b10a03a1e16`. Existing tracked and untracked
changes were present before this assignment and preserved. The sole owned change
is this new review report. No source, dependency, design, plan, shared-status or
other evidence file was edited by this reviewer.

## Scope and independence

Reviewed [delivery](h1-delivery-proof.md), [credit](h1-credit-induction.md),
[decode/backing](h1-decode-backing-proof.md), [parser roots](h1-parser-root-proof.md),
and the parent-owned [term layout](h1-term-layout-proof.md), their JSON receipts,
the initial and repaired runtime-layout receipts/logs, and their recorded source
identities. The [accounting architecture](h1-accounting-architecture.md) is the
boundary reference, not a newly certified architecture or complete ledger.

This reviewer authored the pure H1 preparation/accounting implementation in an
earlier assignment. Its implementation, tests, manifest correspondence, and the
term report's statements about those modules' behavior are **excluded from this
independent review**. Recorded module hashes were checked only for identity.
General C representation formulas can be reviewed independently of that code.
The parent's separate implementation reviews and test results are not acceptance
evidence issued by this report.

## Review result and resolved finding

No remaining actionable source or arithmetic error was found in the reviewed
conditional lemmas. One reporting-boundary finding was routed to the parent and
corrected by the parser-report author: the original `U_representation` wording
mixed reachable simultaneous copies/object headers with unreachable garbage and
allocator slack. The latter are excluded by the approved reachable-owned-object
boundary. The corrected Markdown and JSON now explicitly distinguish included
reachable structures, retained backing, copies, headers/padding and owned
metadata from excluded garbage, unused heap and allocator slack/fragmentation.

The reviewer reread that correction and checked its new identities. The formulas,
consumer-root obligations, effective-profile conditions and unqualified
activation gates are unchanged. Finding disposition: **RESOLVED**. This is one
author reporting correction, not an executable parser repair or a new obligation
to certify VM/RSS. No upstream defect or issue request follows from it.

## Critical source and derivation checks

OTP paths below are relative to the exact fixed source input
`/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source`; HTTP paths are relative
to the worktree. Installed Elixir helper sources are under
`/nix/store/22fybrvpfzc2csw3n686x8nr486jsj0n-elixir-1.18.5/lib/elixir/lib/elixir/lib`.

| Lemma | Independently checked evidence and limit |
| --- | --- |
| Raw logical/backing distinction | `inet_drv.c:13062-13090,13126-13226`, driver copy/share paths, `io.c`, and `erl_bits.c` support raw logical `n<=B` under the fresh fixed raw-buffer premises. Sharing requires `n>=s-(s>>2)=ceil(3s/4)`, hence `s<=floor(4n/3)`. At B8192 the exposed payload bound is10922. This excludes wrappers, padding and allocator space. |
| Credit cuts and fragment construction | `tls_gen_connection.erl:291-305,604-670,717-827` drains ciphertexts before ordinary reactivation and uses a fresh local concatenation accumulator. Genuine passive markers follow the prior raw emissions; integer driver active settings add credit, making sole arming and genuine marker ordering essential. `inet_drv.c:1551-1559,4215-4238,6974-7000`, `ref_man_processes.md:349-357,507-511`, and `gen_statem.erl:4746-4782` support the stated ordering. `D=N*B+18437` bounds each newly constructed fragment's encoded contribution; it does not bound the whole private application queue. |
| Public delivery and pool handoff | `ssl_gen_statem.erl:755-759,821-826,1517-1528,1750-1861` preserves one raw queued binary and makes active-once passive after sending. `pool.ex:23-30,97-150,189-191` serializes passive/recv-timeout/scan/transfer. Ordinary `gen.erl:235-276,549-554` replies use the same destination without priority delivery. `erl_bif_info.c:1196-1269,1354-1361,1689-1736` supports the copied mailbox inspection. The successful-handoff lemma uses earlier SSL data/call-reply ordering plus passive delivery, rather than treating a scan as a barrier against future input. It concerns public data messages, not all controls or roots. |
| Default suites and native output | Source extraction from `tls_v1.erl:522-564` and the exact `ssl_cipher_format.erl` clauses reproduced19 TLS1.2 and5 TLS1.3 AEAD defaults. Crypto filtering removes entries. `aead.c:163-207,241-272,303-310,346-362` allocates and returns the bounded q-size successful plaintext. TLS1.3 slices can retain that larger record output. NIF allocation/slice helpers distinguish referenced payload from physical headers/slack. Initial null-record assembly is separately covered; CBC/stream paths are outside the default profile. |
| Concatenation/backing | `erl_iolist.c:719-737,881-885,916-927` distinguishes fresh sized multi-element output from unchanged singleton/binary inputs. Consequently the source bound is `K_delivery=max(D,18432,floor(4B/3))`, reducing to D for admitted B8192/N>=1. Neither iolist conversion nor a short slice proves compaction. |
| Parser progress and append induction | `http1.ex:55-60,83-214,221-223,235-441` supports nonterminal carry<=H65536, whole-input content-length/EOF events, J65536 only for chunk-data, complete chunk-size lines bypassing the incomplete-line L8192 guard, and terminal surplus retention. `erl_bits.c:70-73,1749-2008,2635-2668`, interpreter/JIT append paths and `erl_binary.h:287-347` support `T=H+D`, `A=max(K_delivery,256,2*T)` with T<16MiB. Reuse requires capacity induction, not a byte-size substitution. Repeated direct post-done calls are explicitly excluded. |
| Parser roots and event constructors | Positive body events consume input, so `n<=T`, body-byte sum<=T and `E<=n+3<=T+3`. Two list spines and shared event tuples cost at most8E words/64E bytes, excluding payload wrappers and other temporaries. `socket_client.ex:1372-1422,1469-1615,1670-1686` parses the whole batch before ACK reduction, suppresses rearm on done and forbids reuse with surplus. `stream.ex:201-374` supports terminal and reader-root retention. `2*A+K_delivery` bounds only append operand/result backing; `3*A+K_delivery` adds one stored-head provenance class, not complete owner/request lifetime memory. |
| General term layouts | `copy.c:103-229,794-824`, `erl_bits.h:60-82,135-169`, `erl_map.h:57-97`, `erl_fun.h:55-77`, `big.h:55-98`, `erl_term.h:1111-1144` and `erl_binary.h:54-75,242-268` support cons2W, tuple(n+1)W, flatmap(4+2n)W under the normal32-entry cutoff, heap-binary rounding,64-byte ordinary copied refbinary wrappers, closure(2+e)W, bignum header/limbs and32-byte external PID occurrences. Binary header offset remains symbolic; HAMT estimates and unresolved runtime-object layouts are not used as hard constants. |

The long-integer result bound follows from at most4d magnitude bits and64-bit
limbs: at most `1+ceil(d/16)` words. It does not price conversion, multiplication,
subtraction or simultaneous accumulator scratch. Generated Unicode/regex
construction and the P4/P5 release table remain open in the reviewed parser
report. Newly acquired Elixir source evidence outside these frozen inputs was
not reviewed in this assignment.

## Arithmetic and provenance validation

Read-only Python checks independently verified the raw sharing threshold for
all s in1..1048576, and the formula inequalities for every N in1..100. With
B8192/M18437/H65536, K_delivery=D, T<16MiB and A=2T in every case:

| Quantity | N1 | N100 |
| --- | ---: | ---: |
| D / K_delivery | 26629 | 837637 |
| T | 92165 | 903173 |
| A | 184330 | 1806346 |
| Append three-root payload envelope | 395289 | 4450329 |
| Stored-head plus append provenance classes | 579619 | 6256675 |
| Event ceiling T+3 | 92168 | 903176 |
| Specific event-list/tuple ceiling64E bytes | 5898752 | 57803264 |

These are conditional component arithmetic, not recommended production limits
or an evaluated scope budget. Flatmaps n7/n9 give144/176 bytes; ordinary copied
refbinary wrappers give64 bytes and external PID occurrences32 bytes at W8.

Final hash verification matched187 recorded entries across the five source-proof
receipts, including Markdown self-hashes and the corrected boundary inputs.
The four runtime collector before/after snapshots are identical and their429
current source identities matched. Six installed SSL source pairs matched the
fixed OTP source. All24 default suite macro mappings matched source, and the
repaired runtime receipt's24-entry TLS1.3 API result equals its5 TLS1.3 defaults
plus19 TLS1.2 fallback entries, all AEAD.

The initial metadata receipt records FAIL/exit1; the retained repaired receipt
and log record PASS/exit0. The recorded repair replaces invalid List.to_string
handling of documented binary crypto metadata with to_string. This review
inspected those historical receipts and their unchanged source snapshots; it
did **not** rerun the VM. Recorded runtime metadata is Elixir1.18.5,
OTP28.5.0.7/ERTS16.4.0.6/SSL11.6.0.6, x86_64-pc-linux-gnu, word size8, opt/JIT,
OpenSSL3.6.5 and unset configured internal_active_n. It is not a live socket,
scope-lifetime enforcement or negotiated-suite receipt.

The provenance receipt records the direct fixed signed Nix source input. This
review checked local source identities and installed SSL matches; it did not
independently revalidate the NAR signature, loaded native/compiler identity or
an OTP Git revision. Those identities must not be inferred from matching text.

## Final reviewed input identities

Paths in this table are relative to this evidence directory. Four collector
source snapshots share the single recorded hash shown below.

| Input | SHA-256 |
| --- | --- |
| `h1-delivery-proof.md` | `1fcb1d4300a36984ef28795edfc91cf61d9a5c916720f1b373e29a8695cde2a9` |
| `h1-delivery-proof.json` | `688b8d0bd3236c0486f1bdf69c664c2f49e5a2490798e06e5bc25aae30734fae` |
| `h1-credit-induction.md` | `f5924230c352ab71fbbb876e33c260c411f57503b995464ee7d2dca2f2beb60c` |
| `h1-credit-induction.json` | `3e21b6b5adf7f875711a8d1b2302f9822fc93e81fd17bf3bfd247b22a0212359` |
| `h1-decode-backing-proof.md` | `207e527bc7922784062eadfc3bc17f8f29bf1ac56e4ef6ceea9b74010025abb6` |
| `h1-decode-backing-proof.json` | `5bb1ff6ba1ee88789f78322991811e9ddcce430fa53b85de91321f42364a1042` |
| `h1-parser-root-proof.md` | `c47dd42053b2168dfb1c7daf119f9137c34e89c3d2760d3fbaa60ac20e9ea97e` |
| `h1-parser-root-proof.json` | `848a81aa4ec650264452079dca377569cbb0cc2b430c2ff927b0710a0cfbda4e` |
| `h1-term-layout-proof.md` | `3c8b4c5bd86df8f6d56538cfbdc984111c5d8c2dd7eeaf301f88d91bfa1a0c53` |
| `h1-term-layout-proof.json` | `9afd005835d6a67790ca4aad2c0dae3125d8b112b83fb50efd9fb17b49d39bf6` |
| `h1-runtime-layout-profile.json` | `5b0a8b716cf4ad971e74276309475e247768bea904cecc21d3bb314e1af182f3` |
| `h1-runtime-layout-profile.log` | `2ccd1a108c82216496eeefe9cbfbafdf2f3248609eba38075e9b189e74a72833` |
| `h1-runtime-layout-profile-repair1.json` | `0e33a01f03064e63b7d11532cb5c5035294cdf46815326507e0888ab8089fa42` |
| `h1-runtime-layout-profile-repair1.log` | `50e9662546ee007fb9aec7b3c0a5d13a4f7c24f7450072176881bae635f82dda` |
| `h1-runtime-layout-profile[-repair1]-source-{before,after}.json` (four files) | `d16e5e845629f97f86fd6327f26f3b259736ca335f26ea72b3fa945917e03411` |
| `otp-source-provenance.json` | `0a71c965c2ca335fb7d36c2e33be6d2b26d0646e4c0eafdf8e88f44ad46db493` |
| `h1-accounting-architecture.md` | `6ac9a051172e761717da3be3861566740724ff5507601314ea332e1a36bebe81` |

## Handoff and remaining limits

Verification consisted of git branch/HEAD/status reads, focused numbered source
and receipt/log reads, Python SHA-256/arithmetic/source-suite extraction, and
Markdown links/fences/whitespace checks. No Mix, VM, tests, network, fixtures,
formatting, delegation, dependency edit, commit or publication ran. All this
reviewer's commands finished; no subprocess remains and other agents' processes
were untouched.

Current review Sol executable repair rounds0 / unsuccessful0 / Astra0; one
author reporting correction is resolved. Earlier pure-implementation counters
remain separate: three successful repair validations / zero unsuccessful /
Astra0, with original unexpected failures preserved. Metadata collector counters
remain separate: one initial failure, one successful repair, zero unsuccessful /
Astra0. No escalation gate applies and no user decision is required.

The parent may use this PASS only for the reviewed conditional source lemmas and
general layout formulas. Sole arming, effective inet/raw/header0/binary buffers,
fixed positive N<=100, exact default-suite/native/compiled identity, ownership
enforcement, all included runtime object classes, consumer/terminal liveness,
control turnover and complete composition remain required. Existing receipts
cannot authorize a numeric reservation, live scope, managed activation or M3
acceptance. The parent owns follow-up proof closure and integration acceptance.
