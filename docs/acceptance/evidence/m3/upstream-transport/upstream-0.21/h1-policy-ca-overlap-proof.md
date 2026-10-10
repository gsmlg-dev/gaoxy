# H1 policy and host-CA overlap source proof

Task `m3_h1_policy_ca_overlap_source`, direct bounded Sol source assignment.
2026-10-11 Asia/Shanghai; worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `6ef8a3ad8e26e2f4992adeaf9558199aef8105a5`.
Only this new report and [receipt](h1-policy-ca-overlap-proof.json) are owned.
The native proof pair and concurrent parent work are preserved.

**STATIC_CONDITIONAL_PASS** for the bounded trace and constructor formulas.
Warm host-CA lookup returns the persistent-term snapshot directly; neither
lookup nor the examined explicit-DER keyword transformations copies its tree.
Cold loading and snapshot replacement remain unbounded by the controlled DER
limits. Preloaded immutable-global enforcement, complete P3 and P0-P6 remain
unqualified. No activation total, retry proof or native measurement follows.
No VM/Mix/compiler/network/upstream mutation or executable change ran.
Independent review is pending.

## Identities and premises

The [architecture](h1-accounting-architecture.md), especially lines53-70,
92-111,257 and273, requires reachable owned structures, distinct retained
backing and overlapping copies, while excluding unused heap space, unreachable
garbage, allocator slack, kernel buffers and TLS-private allocations.
Global immutable data may be excluded; newly constructed referencing lists,
option tuples and any owned copies remain included. A caller binary becoming
scope-owned cannot inherit that global exclusion.

The installed HTTP0.21.0 cohort is sourced from gsmlg-dev/http_fetch; the
[earlier trace](h1-request-wire-proof.json) records tag commit
`9813c126dc8b48055b9ee941c693fc27fa691489`. Both inspected package metadata
files confirm0.21.0 and the repository URL. This task rechecks overlapping
prior dependency/module/source hashes and pins every used source and input.
It does not fetch a new package, update dependencies or prove loaded code.

OTP input `/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source` is the fixed
NAR in [provenance](otp-source-provenance.json). Prior runtime metadata is
OTP28.5.0.7/ERTS16.4.0.6, word8, x86_64 JIT; it is not reproduced here.
Elixir input `/nix/store/qa7m7ymrcm7izhjdki9r5z1gsvgbfd05-source` is
v1.18.5 in [its provenance](elixir-source-provenance.json), compiled using
OTP28.5.0.5 rather than the current OTP28.5.0.7. Seven installed OTP public
sources and three installed Elixir sources match their inputs byte for byte.
Loaded module, native and literal identity are separate parent obligations.

The following trace assumes the pure canonical HTTPS grammar: ASCII host of
h<=253 bytes; c=1..128 nonempty compact DER binaries, each<=65,536 bytes and
aggregate logical/backing<=T=1,048,576; explicit verify_peer, depth4, TLS1.3/1.2,
cacerts and generated SNI; six fixed socket pairs; eleven open-option pairs.
HTTP uses nil trust and no freeze_ssl host-CA lookup; a plain HTTP connection
never uses this SSL adapter. The future controlled-preparer-to-managed mapping
remains conditional as documented in [the reviewed wire trace](h1-request-wire-independent-review.md).
This report does not assert current Gaoxy scope integration.

## Snapshot lookup and global roots

The runtime public API here is **public_key:cacerts_get/0**;
`ssl.erl:69-136` does not export ssl:cacerts_get/0. Its docs/examples call the
public_key API. `public_key.erl:2582-2585` delegates to
`pubkey_os_cacerts:get/0`. That function at `:40-61` reads
`persistent_term:get(pubkey_os_cacerts, not_loaded)`. On a warm hit it returns
CaCerts unchanged, with no map/filter or DER reconstruction.

`erl_bif_persistent.c:359-397` looks up the stored tuple and returns its value
pointer directly; get/1 and get/2 return that term without a copy/allocation
path. `persistent_term.erl:40-60,181-213` documents the same behavior. Therefore
warm lookup introduces **zero new certificate-list/record/DER constructors**
in this source path, conditional on the recorded implementation and unchanged
snapshot. The surrounding caller variable/argument or an option tuple is still
a root; this result is not zero whole-operation cost or zero native work.

The cached value is a list of combined **#cert{der,otp}** records, not just DER
binaries (`public_key.hrl:628-632`, public_key.erl:342).
`pubkey_os_cacerts.erl:144-159` PEM-decodes and ASN.1-decodes each valid entry,
adding one list cell and one three-element cert record, plus its DER and decoded
certificate tree, before storing the list via persistent_term:put/2 at `:215-218`.
That persistent store copies into a literal area with sharing preserved
(`erl_bif_persistent.c:738-761`); the cold loader's original terms are separate
preparation roots. No finite snapshot size was measured or pinned in this task.

A cache miss can application-load public_key and consult its cacerts_path
configuration. Linux/default paths and configured directory/file inputs are
outside the canonical DER grammar. `load_from_file` uses uncapped file:read_file
at `:136-143`; directory loading at `:162-177` folds matching files, reads each
fully, decodes certs and concatenates lists. There is no c<=128, source-size cap,
compact-backing cap or decoder-peak bound on this route. Invalid entries can
still be parsed before rejection. Failure can occur even with explicit CAs,
because both examined defaults are eagerly evaluated.

`public_key:cacerts_load/0,1` and cacerts_clear/0 expose reload/erase. On replacing
or deleting a complex persistent term, processes retaining references can copy
its old tree into their heaps (`persistent_term.erl:49-60,117-120`). The immutable
global exclusion therefore requires a preloaded snapshot, identified before the
controlled boundary, with no reload/clear/replacement over every referencing
scope/preparation lifetime. Neither source inspection nor explicit-DER input
enforces that condition. Normal copy paths can reuse literal pointers outside
purge, while literal-copy/purge routes differ (`copy.c:100-123,1137-1151`);
this is not a proof that every ETS/process copy of all policy fields is shared.

## Canonical DER preparation and upstream freeze

The pure preparer (`managed_h1_preparation.ex:25-55,369-400,432-462`)
validates bounded source backing before copying. `copy_trust/1` recursively
builds c new list cells and c compact binary copies, without a reverse list.
Original source trust may remain rooted alongside the copied list. Source and
owned DER payload occurrence sums are each<=T; their sum<=2T is a partial
backing bound, not a total preparation peak or a claim that all originals
release immediately. Origin/host/URI, manifests, binary headers and all helper
roots remain additional. Certificate acceptance here is structural, not proof
that DER is cryptographically valid.

The logical canonical value contains:

| Grammar component | Cons cells | Pair tuples | Other children |
| --- | --- | --- | --- |
| Open options | 11 | 11 | Referenced origin/address/SSL/sockets |
| SSL options | 5 | 5 | Explicit DER list, SNI, versions |
| Fixed socket options | 6 | 6 | Immediate values |
| Versions | 2 | 0 | Two existing atoms |
| DER list | c | 0 | c compact binaries |
| SNI | h | 0 | h immediate ASCII integers |

Thus one canonical occurrence contains24+c+h cons and22 pair tuples, plus
Policy map7, two address-tuple occurrences through fields/options and binary
children. Occurrence counting may repeat a shared address/origin reference;
it is not an exact unique-object count. Fixed sockets/versions and constant
pairs can be global compiled literals; table entries describe the logical
structure and a conservative occurrence charge, not proof every node was
newly allocated. Existing [term](h1-term-layout-proof.md) and
[String](h1-string-transform-proof.md) lemmas remain conditional inputs.

On upstream Policy.freeze_ssl (`policy.ex:188-214`), the canonical list passes
three materialize calls without file access: no cacertfile/certfile/keyfile is
present, so each returns {:ok, opts}. Before/around those calls, keys/uniqueness,
bounded_term and valid_tls_option checks still construct helper terms.
The eager `Keyword.put_new(:cacerts, :public_key.cacerts_get())` obtains the
snapshot, but Keyword.put_new (`keyword.ex:825-830`) returns the original list
when the key exists. It creates no new :cacerts tuple or retained host snapshot
entry. Verify, versions and depth also already exist and do not grow the list.
This result applies to the explicit canonical DER grammar only.

SNI comparison evaluates two eager String.to_charlist(host) expressions,
including Keyword.get's unused default; the final Keyword.put evaluates a
third. The String worksheet supplies3h cons as a conservative construction
count, not a certified simultaneous-live count. Original canonical SNI remains
an additional root. Final put removes the old SNI and prepends a new pair:
Keyword.delete scans membership, then rebuilds the four survivor cons cells,
reusing their tuples/children; prepend adds one cons and one pair tuple
(`keyword.ex:719-728,780-782`). The frozen SSL list has five pairs, the same
DER list/backing and new SNI, with no host-CA tree copied or retained through
its cacerts field. Source options/canonical value may still hold the old SNI.

For the bounded successful canonical path, source helper constructions include:

| Validation helper | Conservative constructed cons | Other helper objects |
| --- | --- | --- |
| Open keys/all + uniqueness | 11+11+11 =33 | uniq map grows through11 keys |
| SSL uniqueness + allowed keys | 5+5+5 =15 | uniq map grows through5 keys |
| Socket uniqueness | 6+6 =12 | uniq map grows through6 keys |
| SSL bounded_term tuples | 2*5 =10 | Tuple.to_list of five pairs |
| Final bounded_term({SSL,sockets}) | 2+2*5+2*6 =24 | Wrapper tuple + eleven pair conversions |
| Connect-address validation | d<=8 | Tuple.to_list(address) |

The keys/uniq/bounded-term helpers therefore contribute94+d<=102 cons
construction events for these calls, before SNI/origin/URI and manifest work.
This is a restricted helper subtotal, not a whole peak. Enum.uniq's maps create
up to22 insertions across three passes, with each map shape<=11 keys
(`enum.ex:3850-3852,3883-3885,4905-4915`); intermediate maps/closures and their
liveness need composition. Keyword.keys/Enum.map call lists.map, which builds
an output spine (`keyword.ex:646-653`, enum.ex:1713-1715,
OTP lists.erl:2383-2392). No new pair tuple is needed merely to return an
existing pair through the identity branch.

`freeze_sockets:260-274` keeps all six explicit socket values; its five put_new
calls find existing keys and allocate no replacement spine. H1 frozen transport
has eight pair entries; its five-entry prefix ++ three-entry tail can construct
five prefix cells and then five append-copy cells in addition to the tail's
three. The final eight cells are a distinct logical spine, while option values
and pairs may be shared. The returned policy has maps of4/3/4 entries for
policy/origin/limits; origin normalization and URI parsing are additional.

Policy.freeze computes deterministic term_to_binary({origin,transport}) then
SHA256. The serializer input tuple, [:deterministic] argument list, serialized
binary and32-byte digest are named roots. The final1MiB check covers
{SSL,sockets}, not the serialized complete identity tree, native serializer/
crypto scratch or the old/new policy overlap. The grammar is finite, but an
exact serialized-output/backing and helper-peak proof was not derived here;
no ETF-to-heap multiplier is used.

## SSL default/normalization/merge overlap

`HTTP.Transport.SSL.ssl_options` (`ssl.ex:144-183`) normalizes user SSL options,
constructs defaults, drops host CAs if explicit cacerts/cacertfile exists, then
merges. For canonical five-pair DER input, Enum.map creates five new spine
cells and returns the same pair objects. No path-string conversion or DER copy
occurs in its identity branch.

The defaults logically have six pairs: verify, cacerts, SNI,
customize_hostname_check, versions and depth. The nested hostname-check list
has one pair whose value is the fun returned by
public_key:pkix_verify_hostname_match_fun(https) (`public_key.erl:2319-2323`),
which captures no caller certificates or host variable. Its closure layout is
still the separate conditional P2 rule. Default SNI adds h cons; versions is
a two-atom literal. The :cacerts pair temporarily points to the entire cached
snapshot. Warm lookup creates no snapshot list or decoded-certificate tree.

Dropping :cacerts rebuilds five survivor cons, reusing tuples. Keyword.merge
(`keyword.ex:1019-1031`) filters the left list and appends user options.
Five user keys override matching defaults; only customize_hostname_check
survives. That intermediate filter creates one cell and append copies one
cell, sharing the normalized five-cell user tail. Merged SSL list length is6.
It contains the explicit DER list/SNI and hostname-check fun, with no default
host-CA root. Original defaults can overlap later results until their roots
release; no source-level GC/release timing is inferred.

| Stage | Additional source constructor events | Snapshot root |
| --- | --- | --- |
| Normalize canonical SSL | 5 cons,0 new pairs | None |
| Build defaults | <=6 cons,<=6 pairs; nested1 cons/1 pair; SNI h; one fun | cacerts value in defaults |
| Delete default cacerts | 5 cons,0 pairs | Original defaults may remain |
| Filter+append merge | 1+1 cons,0 pairs | Absent from result |
| TLS prefix/append with six sockets | prefix3 plus append-copy6+3 cons; <=2 prefix pairs | Absent from final TLS options |

Excluding literal versions and SNI h, this source-event envelope is31 cons
for the normal/upgrade TLS option-building path. It is not a minimum allocation
count or a simultaneous peak: literal suffixes can be shared and compiler
liveness/append optimizations need loaded-code proof. The final TLS option tree
has15 top-level cons (three protocol entries + six SSL pairs + six socket pairs),
plus one nested hostname-check cons, two version cons, c DER cons and h SNI cons:
18+c+h total logical cons, and15 pair tuples including the nested match_fun pair.
DER payload and closure are extra. Conditional maxima are399 TLS-tree cons and
405 canonical-policy cons at c128/h253; neither is a complete byte budget.

connect_cancellable (`ssl.ex:12-41`) separately builds nine TCP-option entries
(three protocol plus six socket entries) before constructing the TLS options.
Its two prefix pairs, three prefix cells and three append-copy cells require
an additional stage ledger. Both cancellable and ordinary connect eagerly evaluate
String.to_charlist(host) as Keyword.get's connect_address default, even with an
explicit literal IP; this adds one more h-cons construction outside default SNI.
Upgrade does not take that TCP/address branch. The adapter's option lists then
cross OTP APIs and may be copied/normalized further; those process/scratch
multiplicities and resource metadata are not proven by these constructor counts.

OTP ssl_config:940-965 preserves supplied cacerts as an option value, and
init_cacerts:378-390 sends {der,CaCerts} to SSL manager initialization.
ssl_pkix_db:341-355 can decode raw DER into #cert while already combined certs
have decoded data. Those TLS-private trees remain excluded under the architecture;
any exposed delivery backing, caller-owned option copies and tracked resource
metadata remain included. No decoder/native cost is silently assigned zero.

## Owned copies, uncapped inputs and remaining obligations

The source open path passes frozen policy through supervisor child/start
arguments (`managed_transport.ex:94-111`), Scope init/state and configuration ETS
(`scope.ex:7-50`), then retrieves {policy,injection} into each admitted caller
(`managed_transport.ex:193-214`). Those are distinct copy/ownership edges.
Per-attempt Policy.prepare normalizes supplied pairs, merges policy transport,
and the facade merges five injection pairs plus lease/deadline; the
[reviewed wire worksheet](h1-request-wire-proof.md) bounds option lengths for
its proposed mapping. Policy.freeze/snapshot hit does not prove roots/copies
release at these edges. ETS storage/lookup is not interchangeable with
persistent_term:get. State/configuration/start arguments and request-caller
policies must remain charged according to their actual representation and
simultaneous reachability. No DynamicSupervisor retention or retry barrier was
qualified by this task.

Outside the canonical boundary, public freeze validates/traverses original
keyword lists and URI input before final serialized caps; tuple widths, numeric
size and source-backing provenance are not universally preflighted by its
bounded_term grammar. Public supplied maps/string keys, arbitrary SSL options,
file paths, PEM/client keys and lazy host-cache loading remain outside the
existing controlled source grammar. The canonical explicit-DER branch bypasses
file materialization; it does not prove those other branches safe under P3.
This is an unresolved local profile/enforcement proof, not a newly established
upstream contract bug. No upstream issue/comment mutation is authorized here.

Remaining: preload/snapshot identity and lifetime immutability; loaded code/
literal identities; exact URI/manifest/serializer/hash scratch and output
backing; helper closure/map liveness; policy copies/ETS native costs; supervisor/
process/message roots and release; rejected-preparation reservations;
per-attempt admission and phase multiplicity. No complete P3, P2, P4/P5 or
P0-P6 gate is closed. Upstream95's separate TLS/lifecycle dependency is unchanged.

## Verification and execution record

The receipt pins all used repository, OTP, Elixir and prior evidence inputs;
compares ten installed public sources; rechecks overlapping prior hashes and
the frozen native pair. A Python identity-preserving keyword model checks
five explicit keys, five post-delete defaults, one surviving default, merged
length6 and retained DER identity. Arithmetic checks all128*253=32,384
(c,h) combinations for the two logical constructor formulas. These are abstract
source checks, not executing Elixir/OTP or observing heap liveness.
The following command reproduces the hash and finite arithmetic checks:

```sh
python3 - <<'PY_VERIFY'
from pathlib import Path
import hashlib, json
p = Path('docs/acceptance/evidence/m3/upstream-transport/upstream-0.21')
d = json.loads((p/'h1-policy-ca-overlap-proof.json').read_text())
sha = lambda f: hashlib.sha256(f.read_bytes()).hexdigest()
for f, h in d['source_and_input_sha256'].items():
    assert sha(Path(f)) == h
for v in d['installed_source_matches']:
    assert sha(Path(v['source'])) == sha(Path(v['installed'])) == v['sha256']
for f, h in d['preserved_native_proof_hashes'].items():
    assert sha(p/f) == h
assert sha(p/'h1-policy-ca-overlap-proof.md') == d['report_sha256']
checks = 0
for c in range(1,129):
    for h in range(1,254):
        assert 24+c+h <= 405
        assert 18+c+h <= 399
        checks += 1
assert checks == d['arithmetic_checks']['der_host_vectors']
assert 33+15+12+10+24+8 == 102
assert 5+6+1+5+1+1+3+6+3 == 31
print('PASS pinned hashes, installed matches and constructor vectors:', checks)
PY_VERIFY
```

JSON, hashes, links, fences and whitespace are checked after writing.

Four selector/cwd diagnostics were corrected: one zsh 'no matches found:
deps/core*' search and three rg OTP/worktree-relative 'No such file or directory'
queries. Two shell batches exited0 despite their failed early rg, so final
verification uses assertions rather than those batch exit codes. These did
not change source or constitute implementation repair rounds. An overbroad
own /nix/store file search was stopped by SIGTERM after verifying its PID,
parent PID and exact argv; its shell session finished safely. No others'
processes were touched. Sol implementation/repair rounds0, unsuccessful0,
Astra0; successful diagnostic corrections4. No own background jobs remain.
