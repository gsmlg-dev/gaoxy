# H1 native-object layout source proof

Bounded direct P2 source investigation, 2026-10-11 Asia/Shanghai. Task
`m3_h1_native_object_layout_source`. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, start HEAD `d8e3a2622e88037419077989547e2e0a00d5c4e4`.
Parent Git-only progress is allowed; input/source hashes identify this work.
Only this new worksheet and [receipt](h1-native-object-layout-proof.json) are owned.

**STATIC_CONDITIONAL_PASS:** normal binary and ordinary local-message layouts
are derived below. These are conditional source formulas, with installed
exported-header corroboration. No native compiler, VM, Mix, network, upstream
operation or TLS lifecycle qualification ran. The actual native translation-unit
configuration and ABI layout were not reproduced. Full P2 and P0-P6 remain
unqualified; no activation byte total follows. Independent review is pending.

## Identity and build conditions

Pinned source: `/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source`.
The existing [provenance](otp-source-provenance.json) records the fixed source NAR
`sha256-1XnZspWzU8gCaeJz6kFMonrY51EKL4r/6jBI6UdNu0g=`. Its source deriver is
not locally available, so no Git URL/revision is claimed. This task rechecks
four overlapping prior source hashes and pins every newly used file.

The [prior runtime receipt](h1-runtime-layout-profile-repair1.json) records
OTP28.5.0.7, ERTS16.4.0.6, x86_64-pc-linux-gnu, word8, `opt`, JIT,
OpenSSL3.6.5 and the installed runtime under
`/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7/lib/erlang`.
Those are prior metadata, not fresh native-layout measurements or scope-lifetime
enforcement. Elixir1.18.5 was compiled with OTP28.5.0.5; that compiler input is
distinct from the current runtime OTP28.5.0.7.

Installed `erts-16.4.0.6/include/erl_int_sizes_config.h` records pointer8,
long8, int4, long-long8. Its generated internal
`ethread_header_config.h` records the same sizes, native implementations enabled,
no gcc/libatomic_ops preference, no libatomic_ops availability, GCC atomic
builtins enabled and compare-exchange masks12 (including the eight-byte bit).
Installed `internal/ethread.mk` supplies thread flags, without an atomic override.
Seven installed internal selection/atomic headers match the source byte for byte.

This corroborates the exported-header route; it does **not** certify every
emulator command-line definition. `ethread.h:32-34` bypasses that header when
`ETHR_HAVE_ETHREAD_DEFINES` is already defined. `erts/configure.ac:122` generates
an emulator target `config.h` as well as those exported headers;
`config.h.in:167` contains the corresponding define placeholder. The generated
emulator `erts/x86_64-pc-linux-gnu/config.h` and target Makefile are absent from
the available source, and no `config.h` is present under installed ERTS includes.
`erts/emulator/Makefile` is an unconfigured dispatcher, not the generated target
Makefile. The receipt records scoped absence searches and exact paths.

The locally readable runtime derivation has this source input, x86_64-linux,
no patches and configure flags for SSL, threads, SMP, kernel-poll, hipe, wx and
systemd. No explicit CFLAGS or NIX_CFLAGS_COMPILE key was recovered. This is
additional build provenance, not proof of all effective compiler flags, packing,
predefined macros, ABI alignment, dynamic-trace configuration or native binary
identity. Numeric formulas below assume ordinary LP64 field alignment and
no packing overrides. Other architectures or unknown backends stay symbolic.

## Normal binary backing

`erl_binary.h:50-75` defines empty `ERTS_BINARY_STRUCT_ALIGNMENT`, then
`binary_internals = {UWord flags, UWord apparent_size, erts_refc_t refc}`,
followed by `SWord orig_size` and `char orig_bytes[1]` in `Binary`.
The allocation macro is `offsetof(Binary,orig_bytes)+Sz`, not `sizeof(Binary)+Sz`;
struct tail padding must not be added a second time. The comment requires the
payload offset to be eight-byte aligned, including 32-bit builds, but this
worksheet does not qualify a 32-bit build.

`sys.h:964` aliases `erts_refc_t` to `erts_atomic_t`; `erl_threads.h:361-362`
aliases that to `ethr_atomic_t`. Lock-check/refcount debug changes checks, not
this field's type. Under the installed exported defines, GNU-compatible
x86_64 compilation and no overriding defines, `ethread.h:374-416` chooses
`x86_64/ethread.h`, which includes `i386/ethread.h`. That file requests atomic64
when pointer8; `i386/atomic.h:42-74` defines one volatile `ethr_sint64_t counter`.
`ethread.h:238-263` makes that scalar a long on these sizes;
`ethr_atomics.h:246-253` selects the native64 type as `ethr_atomic_t`.
The GCC route, if preferred instead, defines one volatile scalar `value` in
`gcc/ethr_atomic.h:52-99` and also supports atomic64 with mask12.
Neither route inserts a mutex or a cache-line pad into this scalar struct.

Let W=8; `S` and `A` are qualified refcount size/alignment. For ordinary word
alignment8 and `align_up(x,a)=a*ceil(x/a)`:

```text
refc_offset = align_up(2W, A)
intern_size = align_up(refc_offset + S, max(8,A))
C_Binary = align_up(intern_size, 8) + W
normal backing request(n) = C_Binary + n
```

| Conditional type | S / A | intern bytes | C_Binary |
| --- | --- | --- | --- |
| Native64 single long scalar | 8 / 8 | 24 | 32 |
| Locked scalar fallback | 8 / 8 | 24 | 32 |
| Only native32 operations, pair fallback | 16 / 8 | 32 | 40 |

The pair fallback is hypothetical here: `ethr_atomics.h:280-302` supplies two
32-bit atomics plus a word scalar when native word atomics are unavailable.
Its 16-byte size assumes each atomic32 is four bytes with ordinary alignment.
It is not the route selected by the inspected exported x86_64 headers.
The table is not a universal maximum across unknown builds.

`erl_binary.h:291-311` requests exactly the normal macro via ERTS_ALC_T_BINARY.
Driver allocation (`:253-268`) adds CHICKEN_PAD: zero for DEBUG, VALGRIND or
ADDRESS_SANITIZER, otherwise pointer-size minus one (seven here). Normal
allocation never adds it. Reallocation (`:326-352`) preserves that distinction.
For retained ordinary backing, n must bound the whole backing allocation,
not merely a slice's logical byte_size or apparent_size. Wrappers and exposed
backing are additional to message metadata; shared backing is counted once
per distinct retained allocation. Heap binaries have their separate term rule.
Magic binaries, NIF/driver resource payloads and mutable append-capacity proofs
remain outside this normal-backing result. Allocator rounding/fragmentation is
outside the approved boundary.

## Ordinary message references and heap fragments

`erl_message.h:89-92` defines `ErlOffHeap = {pointer first, Uint64 overhead}`.
Under the stated LP64 alignment it is16 bytes. `overhead` is a GC administrative
counter, not an extra allocation charge equal to its numeric value. Linked
resources/backing still require their own representation charges.

`erl_message.h:198-206` defines a fragment as next pointer, ErlOffHeap,
alloc_size, used_size and mem[1]. Their offsets are0,8,24,32,40; its ordinary
sizeof is48. Thus `ERTS_HEAP_FRAG_SIZE(a)` at `:490-500` requests40+8a bytes.
The40-byte header includes all per-fragment fields. On other ABIs retain the
exact `sizeof(ErlHeapFragment)-sizeof(Eterm)+a*sizeof(Eterm)` formula.

`erl_message.h:209-244` gives a message reference two pointers and r Eterm
slots, r=3 normally or4 if USE_VM_PROBES is **defined**. `#ifdef` means a
macro defined as0 still selects4. Its roots (message, token, sender and optional
user tag) are included in the reference slots; reachable child terms are extra.

| Conditional ordinary LP64 object | Probes absent (r=3) | Probes defined (r=4) |
| --- | --- | --- |
| ErtsMessageRef | 40 | 48 |
| ErlHeapFragment with mem[1] | 48 | 48 |
| ErtsMessage with inline fragment and mem[1] | 88 | 96 |
| Combined allocation, a>=1 | 80+8a | 88+8a |
| Reference plus k separate fragments | 40+sum(40+8a_i) | 48+sum(40+8a_i) |

The reference allocator in `erl_message.c:39-64` uses ErtsMessageRef.
`erl_alloc.h:407-426` requests sizeof(TYPE) on its allocator fallback; preallocated
objects have the same struct fields. Scheduler preallocation pools, free slots,
allocator metadata and allocator fragmentation are not per-owned-reference
fields and remain outside this boundary. `erts_alloc_message(0)` allocates only
that reference; do not charge a nonexistent inline fragment. For a>=1,
`erl_message.h:574-593` allocates sizeof(ErtsMessage)+(a-1)*sizeof(Eterm) and
marks the inline fragment with a sentinel, which is not another allocation.
`new_message_buffer` at `erl_message.c:68-77` separately allocates a fragment.

`erts_try_alloc_message_on_heap` at `erl_message.c:622-686` establishes three
ordinary paths: reference plus terms in the receiver heap, reference plus a
separate fragment, or combined message/fragment. This proves available shapes,
not which shape or how many messages the H1 path retains. Charge receiver-heap
term objects once in the owned term ledger, rather than duplicating them merely
because a reference points at them. A combined first fragment may link additional
fragments; include each additional header and its reachable terms once.

The physical request uses **alloc_size**. The approved reachable-object charge
uses each retained metadata header plus reachable owned term structure (including
its object padding), plus retained backing/resources. Unused heap capacity and
unreachable garbage remain excluded under [the architecture](h1-accounting-architecture.md).
The used region is a conservative containment bound for initialized terms,
not a proof that every word is a reachable object or that used_size equals
allocated size. A bound using8*used_size must explicitly disclose any resulting
overcount; it must not relabel spare capacity as reachable cost. At construction
used=allocated, but `erts_shrink_message` at `:619-626` can retain the larger
allocation and update only used_size. `erts_used_frag_sz`/attached-data size at
`:635-653` sums used words and omits native headers and binary backing.

`erts/configure.ac:263-286` enables VM probes conditionally on dynamic-trace
configuration (and excludes the lttng branch). Actual USE_VM_PROBES remains
unresolved without the generated emulator definitions. The `-DUSE_VM_PROBES=0/1`
argument in `Makefile.in:647-653` goes to the Perl opcode generator, not directly
to the message C translation unit. It cannot settle r. A conservative r=4 can
bound these two ordinary shapes under the stated ABI, but cannot price all signals.

`erl_message.h:247-288` distinguishes ordinary/internal messages, undecoded
distribution messages and other signal structs. These formulas do not apply
to every nonmessage signal, marker, distribution buffer or transport resource.
No TLS-dependent message tracing or lifecycle reproduction was attempted.

## Remaining proof and verification

Unresolved: actual native translation-unit defines/packing/alignment and probe
selection; loaded native artifact identity; H1 message kinds, fragment counts,
copy overlap and release; full Process, ETS, atomics-resource, monitor, timer,
nonmessage-signal, native/socket/magic-resource layouts. This task resolves
conditional normal-binary and ordinary-message structure, not those classes,
P4/P5 multiplicity, preparation algorithm peaks or activation eligibility.
Upstream tracking issue95 still gates the separate TLS/lifecycle qualification.

The receipt pins17 source files, five prior input files, four installed generated
header/makefile copies and the derivation. It includes seven source/installed
header comparisons, four matching overlapping prior source hashes, three binary
alignment vectors, two message-layout vectors and finite algebra checks.
Python field/alignment arithmetic is not a C offsetof/sizeof measurement.
The following source-only command reproduces the hash and algebra checks:

```sh
python3 - <<'PY_VERIFY'
from pathlib import Path
import hashlib, json
p = Path('docs/acceptance/evidence/m3/upstream-transport/upstream-0.21')
d = json.loads((p/'h1-native-object-layout-proof.json').read_text())
sha = lambda f: hashlib.sha256(f.read_bytes()).hexdigest()
for f, h in d['source_hashes'].items():
    assert sha(Path(d['source_store_path'])/f) == h
for f, h in d['input_hashes'].items():
    assert sha(p/f) == h
assert sha(p/'h1-native-object-layout-proof.md') == d['report_sha256']
up = lambda n, a: (n+a-1)//a*a
for v in d['binary_conditional_vectors']:
    intern = up(up(16, v['refc_alignment'])+v['refc_size'],
                max(8, v['refc_alignment']))
    assert intern == v['intern_size']
    assert up(intern, 8)+8 == v['orig_bytes_offset']
checks = 0
for v in d['ordinary_message_conditional_vectors']:
    ref = (2+v['reference_slots'])*8
    assert ref == v['reference_size']
    assert v['message_size_with_one_word'] == ref+48
    for n in range(1,4097):
        assert ref+48+(n-1)*8 == ref+40+n*8
        checks += 1
    for a in range(1,257):
        for used in range(a+1):
            assert ref+40+used*8 <= ref+40+a*8
            checks += 1
assert checks == d['arithmetic_checks']['combined_and_used_vs_allocated_checks']
print('PASS source/input/report hashes and conditional arithmetic:', checks)
PY_VERIFY
```

Validation also rechecks hashes, JSON parsing, local links, Markdown fences and
whitespace. No product/dependency changes or tests were needed for this bounded
source-only task.

A diagnostic rg was accidentally run from the worktree for OTP-relative paths,
printing four 'No such file or directory' errors; the combined read command
exited0 because its later sed succeeded. The search was rerun from the pinned
OTP root and exited0. Evidence collector/source arithmetic had no failures.
Counters: one successful Sol diagnostic repair, zero unsuccessful Sol repairs,
zero executable-validation/implementation repairs, Astra0. All own commands
finished; no background jobs were started. Parent changes were preserved.
