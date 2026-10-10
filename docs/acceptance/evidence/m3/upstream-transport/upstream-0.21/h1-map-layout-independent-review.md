# Independent review of the H1 HAMT representation supplement

Date: 2026-10-11 Asia/Shanghai. Task: `M3-H1-P2-FIXED-KEY-HAMT-REVIEW`.
Assignment: direct independent Sol source/specification review, followed by
quality/evidence review. Status: **DONE**. Final verdict: **PASS**, limited to
one valid completed HAMT structural occurrence under the conditional source/
build representation. No actionable findings remain within this assignment.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline and observed HEAD
`d8e3a2622e88037419077989547e2e0a00d5c4e4`.
The reviewer did not author the parent-owned supplement. Only this new review
report is changed by this assignment; all other writers, frozen source inputs,
previous reports and parent jobs are preserved.

## Reviewed identities

| Artifact | SHA256 |
| --- | --- |
| [HAMT worksheet](h1-map-layout-proof.md) | `094bd03e12eba6440cad29f203b4bd15e507c60e220451e07a45f85c90160b57` |
| [Refined HAMT receipt](h1-map-layout-proof.json) | `0b40f163c0ba624e7eaa4f283dddba4132867e3536bff5649b01103e593b4c5c` |
| [Preserved initial collector failure](h1-map-layout-collector-initial.json) | `1df037ff67e509f28e3108546640ea811264cc63fdbdacf54380c4404de61706` |

Original receipt `be9282c76eb48d83384b0289d4b8318466d7b18ea9956ee13c5de524b8e77738`
was refined by its author in response to the finding below; the worksheet and
all17 recorded inputs remain unchanged. The refined receipt records the old
identity and refinement, with `assertions_weakened:false` and no product change.

## Source and specification assessment

The reviewer inspected the exact OTP Nix input at
`/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source`, including map headers,
builder, insertion/update and ordinary/sharing-aware copy implementations.
`erts_ihash_t` is `UWord`; `sys.h` makes UWord/Uint pointer-sized and requires
CHAR_BIT=8. For W=8, `HAMT_MAX_LEVEL=sizeof(erts_ihash_t)*CHAR_BIT/4` therefore
has L=16, including the root nibble. The old eight-level source comment is not
the controlling expression. The non-DEBUG flat-map cutoff is32.

Independent field extraction reproduces all32 distinct FetchOptions field
names, including digit-bearing http1/http2/http3 names. The pinned Elixir
`Kernel.Utils.defstruct` adds `__struct__` using maps.from_list, giving33 keys.
The list-init update and normalization path updates existing fields. This is a
fixed33-entry source shape, not a claim about arbitrary forged structs, the
loaded literal representation or actual request admission.

Source constructors allocate root2+q words, bitmap nonroot1+q, collision
tuple1+k, and two-word key/value leaf cons cells. Full root arrays have16
occupied slots, not spare empty capacity. Collision tuples have at least two
keys and terminate exhausted hash paths; the builder/insertion code includes
single-child shared-prefix nodes through depth L-1. Existing-key updates and
copy operations preserve these structural kinds.

For a valid completed map, each ordinary node at a depth has a nonempty key
set, and distinct nodes at that depth have disjoint key sets. Therefore at most
n ordinary nodes occur per nonroot depth, with at most floor(n/2) disjoint
terminal collision groups. Every key has one leaf. With V including root,
ordinary nodes and collision tuples, tree edges number V-1 and leaf edges n;
header/size overhead totals V+1. The derivation is consequently:

```text
words = (V+1) + (V-1+n) + 2n = 2V+3n
V <= 1 + (L-1)n + floor(n/2)
words <= (2L+1)n + 2 + 2floor(n/2)
n33/L16/W8: V<=512, words<=1123, structural bytes<=8984
```

This is deliberately loose and independent of hash seed/distribution. It
counts structural slots without pretending key/value children are free.
It does not borrow HASHMAP_ESTIMATED_HEAP_SIZE, which is an average estimate
and excludes collision treatment. The flat-map formula is correctly withheld.
Conservatively charging complete old/new occurrences can overcount shared
subtrees but cannot establish how many versions are simultaneously rooted.

## Evidence finding and resolution

The initial receipt embedded the abstract model and108 output vectors but
omitted their exact input-generator recipes. In particular, the SHA pattern
could not be rerun exactly without index encoding, byte selection, byte order
and level masking. The reviewer reported this reproducibility gap before
accepting the evidence.

The author added all six deterministic recipes, tested cardinalities/levels
and the exact SHA recipe: SHA256 of the UTF-8 decimal index, first eight digest
bytes, interpreted little-endian, masked to4L bits. No vector, mathematical
assertion or source file was weakened or changed. The refined receipt was then
rechecked independently and the gap is resolved.

## Independent verification

Read-only Python3 validation completed with exit0 after the diagnostic
correction recorded below. No embedded model code was executed; the reviewer
implemented a separate breadth-first count of ordinary/collision nodes,
header words and occupied slots, then added two words per leaf.

- All17 recorded input hashes and both final worksheet/receipt hashes match.
  The preserved initial collector-failure identity also matches.
- Three overlapping OTP input hashes (map header, sys header, copy source)
  agree with the preceding term-layout receipt.
- The32-field list,33-entry count, L16 derivation and512/1123/8984 arithmetic
  agree with the source and receipt.
- All4,096 algebra cases (n1..2048 at L8 and L16) reproduce the formula.
- All108 vectors reproduce exactly under the independent traversal: six
  recipes, nine cardinalities and two levels. Every vector also satisfies
  the word identity, node/collision ceilings and structural upper bound.
- All five worksheet links resolve. Refinement metadata, unchanged inputs
  and parent collector counters agree. No tracked repository diff was created
  by the reviewer.

These are source/arithmetic/abstract-model checks. They do not execute OTP's
constructor, observe a native hash distribution, measure a retained map,
inspect loaded literals/instructions or prove compiler/runtime reproduction.
The source derivation, rather than those sanity vectors, establishes the
conditional structural envelope.

## Failures, counters and qualification limits

The parent's initial collector failure remains visible: it asserted six links
when the worksheet had five and attempted the future receipt self-target.
The repaired collector first creates the receipt and then checks all five
links. Parent collector Sol1/successful1/unsuccessful0/Astra0; executable0.
The later recipe addition is an evidence review refinement, recorded separately.

One reviewer validation still expected the original frozen receipt while the
parent applied that authorized refinement; its hash assertion stopped before
source checking. This was expected input advancement, not a technical finding.
The next run passed every substantive check but its final optional metadata
print used `review_refinement` at the top level, producing
`KeyError: 'review_refinement'`. Reviewer diagnostic repair1 uses its actual
location under `verification`; fresh full validation exits0. Reviewer Sol
repair rounds1, successful1, unsuccessful0, executable0, Astra0. No escalation
gate applies. No product assertion was removed or weakened.

The existing runtime metadata is OTP28.5.0.7 / ERTS16.4.0.6 / opt / x86_64 /
W8. Elixir's provenance identifies OTP28.5.0.5 as its compiler input, distinct
from that runtime. Loaded instruction/literal identity, complete native build
definitions and lifetime profile enforcement remain open. Source provenance
and prior metadata do not replace those obligations.

Key/value children, native constructor/update arrays, stacks and yield state,
copy multiplicity, simultaneous root release, process/message/ETS/monitor/
timer/resource metadata, other P2 classes and P0/P1/P3/P4/P5/P6 composition
remain open. Thus full P2/P0-P6, numeric reservation, activation, managed TLS
tracking/release and M3 completion remain **NOT ESTABLISHED**. Upstream95
continues to gate TLS qualification.

No VM, Mix, formatter, test, managed resource, fixture, network request,
upstream mutation or commit ran. All owned commands finished; no background
job was created and parent jobs were untouched. Decisions needed: none for
this bounded review. The parent may use the8984-byte structural envelope only
with its stated representation conditions and separate children/transient/
multiplicity charges.
