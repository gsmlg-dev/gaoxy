# H1 fixed-key HAMT representation source proof

Parent-owned bounded P2 source investigation, 2026-10-11 Asia/Shanghai.
Worktree `.trees/m3-gateway`, branch `codex/m3-gateway`; starting HEAD
`d8e3a2622e88037419077989547e2e0a00d5c4e4`. This supplements the
[conditional term-layout proof](h1-term-layout-proof.md), without rewriting its
historical HAMT gap. Independent review is pending. Full P2 and P0-P6 remain
**NOT ESTABLISHED**; no activation reservation is produced.

## Identity and representation boundary

OTP source is the fixed Nix input
`/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source`, linked to the runtime by
[its source provenance](otp-source-provenance.json). The
[runtime metadata receipt](h1-runtime-layout-profile-repair1.json) reports
OTP28.5.0.7/ERTS16.4.0.6, `opt`, x86_64 and W=8 bytes. Elixir's source input is
`/nix/store/qa7m7ymrcm7izhjdki9r5z1gsvgbfd05-source`; its
[provenance receipt](elixir-source-provenance.json) records compilation with
OTP28.5.0.5, distinct from the active runtime. Loaded instructions and literal
map layout were not inspected or reproduced. These formulas remain conditional
on the qualified source/build and valid map representation; substituting a
runtime-wide certificate still requires that identity/enforcement work.

The boundary counts one reachable map's structural objects and slots, before
adding key/value child objects. It excludes unused GC space, allocator rounding,
native construction work arrays/stacks, global literal storage and build-time
objects. Conservative occurrence accounting can charge a shared or literal
structural object again. That overcount does not remove owned children or the
need to count simultaneous roots, copying, runtime metadata and transients.

## Fixed FetchOptions keys

Installed `deps/http_fetch/lib/http/fetch_options.ex:140-172` declares32 unique
fields. Pinned Elixir `lib/elixir/lib/kernel/utils.ex:103-170` constructs a
struct using `:maps.from_list([__struct__: module] ++ fields)`. Its source shape
therefore has n=33 entries. `new/1:216-228` starts from the struct, and
`merge_options/2:292-405` updates existing fields. These source paths do not
remove the33-entry shape. This observation does not assert that the future
canonical-to-Fetch mapping is implemented or that a particular request passes
upstream admission.

`erl_map.h:93-97` uses the normal flat-map cutoff32 for non-DEBUG builds (3 in
DEBUG). The33-entry shape needs a HAMT structural charge; `(4+2n)W` from the
small-map proof is inapplicable. A fixed-key structure does not make the
native hash distribution or its structural object count a constant established
by these source declarations alone. No average estimate or observed shape is
used below.

## Source topology and sizes

`erl_term_hashing.h:31` defines `erts_ihash_t` as `UWord`.
`sys.h:397-460` makes `Uint`/`UWord` pointer-sized; `sys.h:534-538` requires
CHAR_BIT=8. Thus on the recorded64-bit build the source's
`HAMT_MAX_LEVEL = sizeof(erts_ihash_t)*CHAR_BIT/4` (`erl_map.h:220`) is L=16,
including the root's hash nibble. The old source comment saying eight levels
(`erl_map.c:962-964`) is not a substitute for this type-dependent expression.

| Structural object | Words, excluding children | Source |
| --- | --- | --- |
| Root with q occupied slots | 2+q; full array has18 | `erl_map.h:202,204`, `erl_map.c:1137-1154` |
| Nonroot bitmap node with q occupied slots | 1+q; q<=16 | `erl_map.h:203`, `erl_map.c:1070-1084,1118-1131` |
| Exhausted-hash collision tuple with k entries | 1+k, k>=2 | `erl_map.h:205-212`, `erl_map.c:872-897` |
| Key/value leaf `[key | value]` | 2 | `erl_map.c:731-738`, `copy.c:103-116` |

The array form does not contain spare empty child slots: a full root has all16
occupied positions; bitmap nodes allocate their popcount. Keys sharing every
hash nibble terminate in a collision tuple, whose elements are leaf cons cells.
The builder can retain single-child nodes down to depth L-1 for collisions
(`erl_map.c:966-982,1003-1014,1032-1044,1102-1113`). The bound includes them.
Insertion shifts one nibble per ordinary node and stops constructing ordinary
nodes at L before adding a collision tuple
(`erl_map.h:80-86`, `erl_map.c:2633-2652`). Existing-key updates rebuild the
visited path and preserve the other branches (`erl_map.c:2662-2779`).

For one valid completed map, each ordinary node has a nonempty descendant key
set. Distinct nodes at the same depth have disjoint key sets. There are at most
n ordinary nodes at each nonroot depth, and at most floor(n/2) disjoint terminal
collision groups. Each key occurs once as a leaf. This is a topology statement
for a map representation, independent of atom ordering and hash seed. It does
not bound how many old versions a caller or mailbox retains.

## Conservative structural formula

Let V count the root, every nonroot ordinary node and every collision tuple.
There are V-1 edges to child nodes and n edges to leaf cons cells. The root has
two overhead words, each other node one, and every edge occupies one slot.
The leaf cons cells contribute2n. Consequently the structural word count is

```text
overhead + slots + leaves = (V+1) + (V-1+n) + 2n = 2V+3n
V <= 1 + (L-1)n + floor(n/2)
HAMT_skeleton(n,L,W) <= W*((2L+1)n + 2 + 2*floor(n/2))
```

This deliberately loose bound covers maximal shared-prefix chains and full
hash collisions; it is not claimed tight or attainable. For FetchOptions,
n33/L16/W8 gives V<=512, at most1123 structural words, or **8,984 bytes** per
charged complete occurrence, plus all key/value children. The atom keys are
immediate terms; their leaf slots remain counted. Values such as headers,
scope handles, URI data, binaries and option lists require their own charges.

`HASHMAP_ESTIMATED_HEAP_SIZE` is explicitly an average estimate and omits
collisions (`erl_map.h:222-243`); it is not this upper bound. Charging33 entries
as a flat map would give560 bytes, which has no applicable representation
proof here. Neither8,984 nor560 is a measured retained-size observation.

## Copy and overlap limits

`copy.c:189-208,453-466,1297-1313` counts/traverses root and bitmap headers,
size/popcount slots and child terms. Collision tuples use ordinary tuple
copying; their leaf cons cells use list copying. Ordinary copying
(`copy.c:891-907`) and sharing-aware copying (`copy.c:1604-1620`) preserve
these shapes. A destination occurrence can therefore be conservatively charged
by the same structural envelope. Children may create binary wrappers or share
backing; their costs are still separate.

Two complete map versions may coexist with shared subtrees. Charging both
complete envelopes is conservative for their structure, but the proof has not
established the number of such versions or temporary roots. In particular,
`new/1` reduces an option list and normalizes the result; the source's native
builder/update arrays, yield state and copying stacks are separate P2/P3/P4
obligations. This report does not price an entire constructor peak, grant a
constant pointer-cost message assumption, or supply process/ETS/monitor/timer
metadata. Full native build definitions and actual loaded-code identity remain
open. Upstream95's TLS tracking/release qualification remains blocked.

## Static verification and handoff

The [machine-readable receipt](h1-map-layout-proof.json) records inspected
source/input identities, the32-field list, derivation arithmetic and deterministic
abstract-trie sanity checks. Those checks exercise structural formulas with
maximal collisions and prefix sharing; they do not execute OTP's constructor,
measure a live map, prove hash behavior or replace the source argument.
No VM, Mix, managed resource, network, product edit, dependency patch or upstream
mutation was run for this task. Three guessed inspection paths were absent and
were corrected by reading the actual source paths. The initial receipt collector
failed on an incorrect six-link assertion; this report has five links. The
corrected collector creates its receipt before verifying all five link targets.
The initial failure remains in `h1-map-layout-collector-initial.json`. Collector
Sol repairs1/successful1/unsuccessful0/Astra0; executable repairs0. Independent
specification and quality review remain pending. Full P0-P6 remain unqualified.
