# H1 controlled-term representation source proof

Parent-owned bounded P2 investigation, 2026-10-11 Asia/Shanghai. Baseline
`4cc7a1a967d1b90a62d42db438316b10a03a1e16`, `codex/m3-gateway`.
This report supplies conditional term-layout formulas, not a complete scope
budget. Independent review is pending. Full P2 and P0-P6 remain unqualified.

## Identity and boundary

The fixed Nix source is `/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source`,
reconciled with the actual runtime by [source provenance](otp-source-provenance.json).
The parent's fresh [runtime receipt](h1-runtime-layout-profile-repair1.json)
records Elixir1.18.5, ERTS16.4.0.6, x86_64-pc-linux-gnu, word size8,
build type `opt`, JIT, and OpenSSL3.6.5. Public default TLS1.2 suites number19;
the TLS1.3 API returns24 entries (five TLS1.3 plus the19 TLS1.2 fallback
entries), all with AEAD MAC. These metadata queries did not open a managed scope
or socket. They do not enforce those properties over a future scope lifetime,
identify all loaded native artifacts, or validate an actual socket's backend,
options, credit or negotiated suite. `internal_active_n` is unset in that VM;
it is not a live-connection credit observation.

The accounting boundary is the reachable-owned-object boundary in
[the architecture](h1-accounting-architecture.md), excluding unused GC space,
allocator fragmentation, kernel buffers and TLS-private allocations. Shared
binary backing exposed to the managed pipeline remains included. All formulas
below concern object representation only. They do not certify liveness, the
number of simultaneous roots, copying peaks, admission or turnover.

## Source formulas

Let W=8 bytes. References already stored in a parent tuple/cons/map/closure are
included in that parent's slots; immediate scalar occurrences do not introduce
another heap object. Conservative occurrence accounting may count an object
more than once when it is shared, provided that overcount is stated.

| Object | Conditional representation | Exact source |
| --- | --- | --- |
| Cons | 2W=16 bytes, plus children | `copy.c:103-116` adds2 words per list cell. |
| n-tuple | (n+1)W, plus children; the empty tuple may be conservatively charged8 bytes although it is a global literal | `copy.c:124-146` adds arity+1; empty tuples are global. |
| Small flat map, n<=32 | (3+n)W for map body plus (1+n)W for key tuple = (4+2n)W, plus key/value children | `erl_map.h:57-74,89-97`; `copy.c:171-187` counts map body and traverses keys. `opt` selects the normal32-entry cutoff; DEBUG would use3. |
| Heap binary, b<=64 bytes | 2W + W*ceil(b/W), including payload and word padding | `erl_bits.h:150-169`, `heap_bin_size__`; the cutoff is64 bytes. |
| Refcounted binary or ordinary slice wrapper | `sizeof(ErlSubBits)+sizeof(BinRef)=5W+3W=64` bytes per complete ordinary copied occurrence, plus the shared backing allocation | `erl_bits.h:60-82,135-148`; `copy.c:216-229,794-824` copies both wrappers and increments the backing refcount. |
| Normal binary backing | `offsetof(Binary, orig_bytes)+referenced_payload`; driver allocation may additionally request at most7 CHICKEN_PAD bytes | `erl_binary.h:54-75,242-268`. The C offset depends on the matching atomic type/build; it remains a named input, not zero. Allocator rounding is outside the declared boundary. |
| Small integer, atom, nil, internal PID/port | Immediate tagged term; no additional child heap object | `erl_term.h:629-639` identifies internal PIDs as immediate; the scalar/tag and copy dispatch in `erl_term.h`/`copy.c` preserve immediate terms. Parent slots still count. |
| k-bit bignum | W*(1+ceil(k/64)) bytes for header and digits, plus any construction temporaries separately | `big.h:29,55-74`: digit is Uint, D_EXP is word width, digits follow the header. This is an object formula, not a conversion-algorithm peak. |
| External PID | `EXTERNAL_THING_HEAD_SIZE+EXTERNAL_PID_DATA_WORDS=4` words =32 bytes per copied occurrence | `erl_term.h:1111-1144`: header/node/offheap pointers and8-byte PID data. Node-table storage is a distinct global/runtime category. |
| Closure with e environment slots | (2+e)W, plus captured children | `erl_fun.h:55-77`; `copy.c:148-165,845-860`. Global function/export entry storage is distinct. |
| Internal reference | `sizeof(ErtsORefThing)`, `sizeof(ErtsPRefThing)` or `sizeof(ErtsMRefThing)` according to actual reference kind | `erl_term.h:768-797,952-966`; a magic reference additionally retains its referenced resource. A single reference constant is insufficient. |

Large/HAMT maps are deliberately not priced by
`HASHMAP_ESTIMATED_HEAP_SIZE`: `erl_map.h:222-243` calls it an average estimate
and excludes collision nodes. Future scope/runtime maps above32 entries need
a hard constructor/path bound or a verified actual shape. No ETF multiplier is
used. On-heap small binaries may be copied across processes; the large-binary
case shares backing but creates receiver wrappers. Retained-byte composition
must distinguish these cases instead of pricing every message as a pointer.

For a bounded ordinary binary occurrence with referenced payload K, a usable
conservative symbolic bound is

```text
K + 64 + C_Binary + 7
where C_Binary = offsetof(Binary, orig_bytes) for the qualified build.
```

For a heap binary this overcounts the nonexistent offheap header and uses64
instead of at most23 bytes of header/padding. For an offheap occurrence it
counts wrappers and normal backing/driver padding. It deliberately repeats
shared backing per occurrence. It does not price magic binaries/resources,
mutable append capacity, NIF error objects or the allocator's unused space.
Parser append capacity needs the separate allocation proof.

## Controlled preparation manifests

The preparation manifests count source/owned cons cells, tuple arities, map
entry counts, binary occurrences/backing and scalar occurrences. Source maps
have3/7 entries; owned Policy/Request structs have7/9, including `__struct__`.
Their map bodies are within the normal flat-map cutoff. Their field/trailer/
DER/SNI trees are validated finite grammars. Their address octets, ports,
timeouts and fixed option integers fit the immediate small-integer range.
An admitted PID is a term reference, not a claimed owned process; an external
PID requires the32-byte term charge if a later boundary permits it.

These formulas can translate those constructor categories into a partial
source/owned representation expression. They do not price the manifests
themselves, parsed URI/transformation temporaries, transient reverse lists,
maps.fold/URI/trailer helpers, policy serialization, upstream options, copied
process/ETS/message roots or any runtime resource. The constructor counts are
not independently a total preparation peak. The accounting module correctly
returns only named partial facts and the seven-obligation activation error.

## Runtime objects still required by P2

`erl_message.h:198-206,209-244,574-593` exposes message-reference fields and
heap-fragment/combined-message allocation formulas. It includes a
`USE_VM_PROBES`-dependent field count. A complete ledger must identify the actual
message/signal kinds and build definitions before using their sizes. Their
payload representation is additional; copying term bytes alone misses this
metadata. The same is true of process records, ETS table/row objects, atomics
resources, monitor and timer structures, native/socket resource metadata and
ordinary versus magic references. They remain explicit unknown categories.

The next bounded P2 task is to enumerate those runtime object kinds from the
actual managed H1 spawn/ownership/control path, pin relevant build definitions,
then derive finite layout formulas. P4 supplies multiplicities/release barriers;
P5 must bound outstanding controls independent of completed-request count.
No unknown category is assigned zero and no numeric activation result follows.

## Verification and repair accounting

The metadata collector's initial receipt [FAIL](h1-runtime-layout-profile.json)
remains unchanged. `crypto:info_lib/0` returns binary names/version strings,
documented at installed `crypto.erl:908-910`; the collector erroneously called
`List.to_string/1`. Repair1 changes only those conversions to `to_string/1`.
The repaired query exits0 with429 unchanged source hashes. Collector counters:
one initial failure, one successful Sol repair, zero unsuccessful repairs,
Astra0. This is separate from the pure H1 implementation's repair counters.

The [source receipt](h1-term-layout-proof.json) records all inspected immutable
source/input hashes and arithmetic checks. Static inspection, source identities
and arithmetic are the validation here. No product module/test, dependency,
scope integration, network fixture or activation was changed by this task.
Independent specification/quality review remains pending.
