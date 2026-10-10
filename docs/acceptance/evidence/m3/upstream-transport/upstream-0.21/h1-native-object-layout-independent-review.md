# Independent review of H1 native-object layout source proof

Date: 2026-10-11 Asia/Shanghai. Task `m3_native_layout_review`; direct Sol
independent specification and source/evidence review. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline and reviewed HEAD
`6ef8a3ad8e26e2f4992adeaf9558199aef8105a5`.
Only this new report is owned. The two authored proof files were already
untracked on entry and were preserved; the tracked diff was empty.

**DONE — PASS_STATIC_CONDITIONAL_REVIEW.** No blocking or actionable correctness
finding was identified within the stated normal-binary and ordinary-message
conditional scope. This verdict accepts source formulas under explicit ABI
premises, not the installed emulator's measured layout. M3 and P0-P6 all remain
unqualified. No numeric activation budget, runtime qualification, TLS lifecycle
acceptance or resolution of the separate upstream issue95 blocker follows.

## Exact reviewed inputs

| Input | SHA-256 |
| --- | --- |
| [Authored source proof](h1-native-object-layout-proof.md) | `cf9b651f77e8514aed1e626e8a2f456484f2ed9ded9c29c43d4d5916e10124e8` |
| [Authored receipt](h1-native-object-layout-proof.json) | `9c1546ede87cc33b962726698423db79ecb2ece44436a95dee31cc26b6e1ddff` |
| [Accounting architecture](h1-accounting-architecture.md) | `6ac9a051172e761717da3be3861566740724ff5507601314ea332e1a36bebe81` |

The receipt's five prior-input hashes and all17 pinned source hashes were
independently recomputed. Pinned source root:
`/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source`.
Installed runtime root:
`/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7/lib/erlang`.
The runtime derivation SHA-256, three exported generated files, additional public
integer-header copy and seven source/installed internal-header equalities all
match the receipt. Six overlapping prior-source assertions cover four distinct
source files and agree with the prior provenance/term-layout receipts.

The prior source NAR identity and prior runtime metadata were inspected as
receipts. No fresh NAR reconstruction, VM metadata collection or loaded-artifact
measurement was performed. Source `OTP_VERSION` and `erts/vsn.mk` independently
agree with OTP28.5.0.7 and ERTS16.4.0.6. Older M2 memory was used only to reinforce
the requirement to keep M3 qualification separate; no historical result supplies
evidence for this review verdict.

## Source trace and conclusions

| Reviewed question | Independent assessment |
| --- | --- |
| Binary layout and offset | `erl_binary.h:50-75` contains two word fields and the refcount in `binary_internals`, then a signed word and `orig_bytes[1]`. `ERTS_SIZEOF_Binary(n)` is `offsetof(Binary,orig_bytes)+n`. Under the stated ordinary LP64 premises, single64/locked scalar gives offset32; the hypothetical two32-atomics-plus-word fallback gives offset40. Whole-struct tail padding is correctly omitted from the allocation request. |
| Refcount type selection | `sys.h:964`, `erl_threads.h:361-362`, `ethread.h:238-263,374-416`, `i386/ethread.h`, `i386/atomic.h:42-74`, and `ethr_atomics.h:246-302` support the exported-header native64 route and hypothetical fallbacks. Native64 and the GCC alternative contain one volatile64 scalar; the locked fallback's locks are not fields of this refcount. The pair fallback is explicitly conditional and is not claimed as selected. |
| Word and field alignment | `sys.h:397-476` supplies the pointer-sized Eterm/Uint/Sint aliases and word aliases, including aligned word typedefs. Exported sizes corroborate LP64. Ordinary align8 and absence of packing overrides remain premises, as disclosed, rather than measured emulator facts. |
| Off-heap and fragment metadata | `erl_message.h:89-92,198-206,490-500` yields OffHeap16, fragment field offsets0/8/24/32/40, sizeof48 and the exact physical fragment request40+8a under the same ABI premises. The GC administrative overhead counter is not itself another byte allocation. |
| Message reference and combined allocation | `erl_message.h:209-244,574-593` yields reference40 or48, combined sizeof88 or96 with one term word, and request80+8a or88+8a for a>=1. Defined `USE_VM_PROBES`, including value0, selects four slots because the test is `#ifdef`. Zero-size allocation uses only a reference. The combined sentinel is not another allocation. |
| Allocation path coverage | `erl_message.c:39-77,622-686` and `erl_alloc.h:407-426` support reference allocation, separate fragments, receiver-heap terms and combined allocation. These are available ordinary shapes, not a trace of which H1 operations use them. Fragment chains require every extra header. Receiver-heap terms require their own ledger charge. |
| Probe/build configuration | `configure.ac:122,263-286`, `config.h.in:167`, and `Makefile.in:647-653` support the stated unresolved target configuration. The opcode-generator `-DUSE_VM_PROBES` argument does not certify the C translation unit. `ethread.h:32-34` can bypass exported definitions. Conservative r=4 bounds only the two reviewed ordinary reference layouts under the stated ABI. |

The normal allocator, driver allocator and realloc branches at
`erl_binary.h:253-352` preserve the stated distinction: driver allocation has
CHICKEN_PAD (zero under the three defined diagnostic macros; seven for ordinary
LP64), while normal backing allocation does not. The normal-binary formula is
not silently applied to driver, magic, resource or writable append-capacity
classes. Whole retained backing must be bounded independently of a slice's
logical size; wrappers are additional and shared backing is deduplicated only
where sharing is established.

No unsound narrowing of the architecture's reachable-owned boundary was found.
Owned metadata, reachable term objects, distinct retained backing/resources and
overlapping copies remain included. Excluding unused heap capacity, unreachable
garbage and allocator slack matches the approved architecture. Charging physical
fragment capacity and charging reachable terms are deliberately distinguished;
the reference roots already occupy the reference slots, but reachable children
and off-heap resources remain additional. `erts_shrink_message` can retain
allocation capacity while reducing used_size. Neither used_size nor the attached
data word counter includes all native headers/backing or proves exact reachability.
The worksheet correctly requires disclosure of any conservative used-word
overcount and does not turn the physical capacity formula into a reachable-byte
certificate.

## Independent verification

All successful commands below exited0. Read-only `git status --short`,
`git branch --show-current`, `git rev-parse HEAD` and `git diff --stat` established
the assigned checkout and the pre-existing untracked proof files. Scoped `cat`,
`sed` and `rg` inspected AGENTS.md, the architecture, receipts, the pinned C
definitions and installed exported headers. No executable protocol/test gate
was run or claimed.

1. SHA-256 rereads matched the exact reviewed MD/JSON identities, all17 source
   files, five prior inputs, three generated files, seven installed/source pairs,
   one public-header copy and one runtime derivation. The six recorded overlapping
   source comparisons were independently checked rather than accepting booleans.
2. Four exact missing-path checks and recursive exact-name `config.h` searches
   under source ERTS and installed ERTS includes reproduced the receipt's absence
   observations. These scoped absences do not assert that no external build
   directory or artifact exists elsewhere.
3. The published source-only Python verifier was extracted from the reviewed
   Markdown and executed unchanged: `PASS source/input/report hashes and
   conditional arithmetic: 74496`. This covers the declared two probe variants,
   n=1..4096 and allocated1..256/used0..allocated. Finite arithmetic checks are
   corroboration of the source algebra, not a proof of H1 multiplicities.
4. A separate field-by-field layout function recomputed offsets, aggregate
   alignment and final struct size, independently of the worksheet's compressed
   formulas. Three binary variants, two message variants, OffHeap and fragment
   layouts matched every recorded numeric field. It also confirmed that full
   Binary sizeof exceeds orig_bytes offset under these premises, so adding that
   tail padding would overcharge the source allocation request.
5. Read-only Python extraction independently matched six derivation fields
   (including absent CFLAGS/NIX_CFLAGS_COMPILE), source input, OTP/ERTS source
   versions, and the pinned derivation hash. An absent derivation key does not
   establish absence of effective compiler flags.
6. Local Markdown links resolved; fences balanced; no trailing whitespace was
   found. The final report and authored proof hashes were rechecked before handoff.

The independent field model used this source-only operation, with field sizes
and alignment supplied by the explicitly conditional premises:

```python
def layout(fields):
    offset, alignment, offsets = 0, 1, {}
    for name, size, align in fields:
        offset = ((offset + align - 1) // align) * align
        offsets[name] = offset
        offset += size
        alignment = max(alignment, align)
    return offsets, ((offset + alignment - 1) // alignment) * alignment, alignment
```

This is not compiler `sizeof`/`offsetof`, does not select actual emulator defines
and does not establish native artifact identity.

## Open obligations and handoff

The authored proof explicitly leaves actual translation-unit definitions,
packing/alignment, probe selection and loaded native identity unresolved. H1
message/signal kinds, fragment multiplicity, copy overlap and release barriers
also remain unresolved. Process, ETS, atomics-resource, monitor, timer, other
signal, native/socket/magic-resource layouts and preparation peaks remain open.
These are qualification prerequisites already recorded by the author; they are
not new defects requiring a local workaround. Do not promote the conditional
constants into a certified P2 profile until the missing matching-layout and
object-class coverage is supplied. P4/P5 counts and P6 composition remain separate.
TLS95 remains a separate external blocker; no upstream action occurred here.

No authored proof correction or new product decision is required for this
bounded review. The parent owns subsequent proof closure and acceptance; this
report does not change either proof file's pending-review field.

Counters: reviewed source task reported Sol successful diagnostic1,
unsuccessful0, executable/implementation repairs0, Astra0; preserved unchanged.
This review had one initial read-only verifier syntax error
`SyntaxError: unmatched ')'` (exit1 before any check or mutation). Removing the
extra parenthesis and rerunning the full check passed (exit0): review diagnostic
repair1 successful, unsuccessful0, implementation repairs0, Astra0. This does
not reset any parent task's cumulative repair budget. No escalation gate applies.

All own commands finished; no background jobs, subprocess sessions or agents
were started. Only this report was written. No VM, Mix, C compiler, network,
upstream mutation, dependency/product edit, staging, commit, push or peer-process
interference was performed. Tests and runtime qualification remain NOT RUN by
the explicit review boundary, rather than passing evidence.
At final status inspection, parent-owned `h1-loaded-identity.json`,
`h1-loaded-identity.log` and `h1-loaded-identity.md` had appeared as additional
untracked files. They were neither modified nor incorporated into this verdict;
the exact reviewed proof hashes and HEAD remained unchanged.
