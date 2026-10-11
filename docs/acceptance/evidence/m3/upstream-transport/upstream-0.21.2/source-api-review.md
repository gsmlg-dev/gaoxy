# Published HTTP 0.21.2 source/API review

Direct assignment `m3_tls_release_source`, 2026-10-11 Asia/Shanghai.
**PASS for publication identity and bounded source/API inspection.** Issue95's
TLS resource-tracking fix is present in the published source. Fresh compilation,
public TLS lifecycle regressions and full P0–P6 qualification are **NOT RUN /
UNQUALIFIED** here. Managed product activation remains disabled.

The [machine receipt](source-api-review.json), [release receipt](release-provenance.json),
[tag/source receipt](tag-source-provenance.json) and [delta receipt](source-delta.json)
record the inputs and checks. Existing0.21.1 artifacts and lemmas were preserved;
none is relabeled as0.21.2 evidence.

## Publication and source identity

Worktree `.trees/m3-gateway`, branch `codex/m3-gateway`, assignment baseline
`81b01bd3334fe4c90a739e1eebdee8bd29bf94f8`. Three pre-existing untracked
accounting/frontier and H1-model documents were left untouched.

Release `v0.21.2`, GitHub release409190531, was published at
`2026-10-10T20:33:44Z`. Hex Fetch0.21.2 was inserted at
`2026-10-10T20:30:41.177678Z`. Fresh network collection identified tag commit
`f677ca49519a007a7a551a5a515127c0f29d8ae6` and tree
`664a2a0de2bd4820017599b2d25f62bc7dcf63b0`.

Python checks verified seven independently downloaded Hex/GitHub archive pairs.
Each pair is byte-identical; its outer SHA256 equals Hex metadata and the
GitHub asset digest, and size equals the release asset size. Each inner CHECKSUM
is SHA256 of VERSION, metadata.config and contents.tar.gz concatenated in that
order. The receipts include all inner/outer checksums, outer-member hashes,
metadata, requirements, shipped paths and every file SHA256.

All196 shipped files were extracted and hashed. All175 runtime `lib/` files
match their Git blobs. The immutable commit source archive was downloaded
separately: every one of919 blob entries in the untruncated recursive tree was
checked using SHA1 of `blob <byte_length> NUL <bytes>`; symlink blobs use their
link-target text. Seven nonidentical packaged manifests equal the tag's
`scripts/release/stage.py` portable-manifest transform exactly. Fetch's shipped
LICENSE/README/CHANGELOG equal the root tag blobs, rather than its app symlink
blobs. These ten explicit app-tree exceptions contain no runtime mismatch.

Before dependency replacement, all196 installed0.21.1 shipped files equaled the
frozen0.21.1 release hashes and were copied to the owned ignored cache. Subsequent
delta checks use those preserved bytes. All seven release manifests require
Elixir `~> 1.18`; internal runtime dependencies stay exactly `== 0.21.2` with the
same dependency graph. Telemetry stays `~> 1.0` where previously present.

## Source/API delta

Exactly15 shipped files changed: seven manifests, Fetch CHANGELOG, and these
seven runtime paths. The other168 runtime paths are byte-identical to0.21.1;
no shipped path was added or removed.

| Package | Runtime path | Source behavior changed |
| --- | --- | --- |
| http_core | `lib/http/request_lifecycle.ex` | Accepted TLS inventory, request monitors, handoff and uncertainty |
| http_core | `lib/http/transport/ssl.ex` | TCP/TLS registration, conservative failed setup, tracked default connect |
| http_runtime | `lib/http/http1/pool.ex` | Idle checkin requires successful handoff |
| http_runtime | `lib/http/http2/pool.ex` | Pool registration requires successful handoff |
| http_runtime | `lib/http/managed_transport.ex` | Durable receipt after settled unconfirmed cleanup |
| http_runtime | `lib/http/managed_transport/scope.ex` | Unknown inventory closes admission; uncertainty remains sticky |
| http_runtime | `lib/http/runtime/dialer.ex` | Carries managed coordinator into TLS options |

Existing public names/arities in these modules remain by lexical inventory and
manual signature diff inspection. The internal, moduledoc-false RequestLifecycle
module adds `unconfirmed_tls/1`. This is source inspection, not loaded-API or
compiler validation. Return/admission behavior is materially stronger:
`track_tls/2` rejects unsupported tracked forms; pool handoff errors are observed;
tracked default SSL connect now uses the cancellable TCP-first path. Existing
ManagedTransport structs and public function signatures are unchanged.

## Issue95: supported socket inventory and release chain

The containing parser (`request_lifecycle.ex:29–58`) accepts the legacy
three-element socket with nested `{:gen_tcp, tcp, _, _}` and exactly two PID
entries, and the OTP28 **eight-element** tuple:

```elixir
{:sslsocket, tcp, receiver, sender, :gen_tcp, _, _, _}
```

The TCP value must be a port and receiver/sender must be PIDs. The frozen
OTP28.5.0.7 source files still equal their0.21.1 review hashes. `ssl_api.hrl:28–35`
has seven record fields, yielding eight tuple elements including the tag;
`tls_socket.erl:169–176` constructs them. The constructor function is `socket/6`,
which does not mean the returned socket has six elements. No six-element socket
parser exists in this release. Legacy support is source-inspected, not executed.

For supported inventory, `track_tls/2` registers TCP as `:socket` and each TLS
PID as `:tls`. `register/3` synchronously calls scope tracking and then creates
its request monitor (`:250–265,385–395`); both tracker and scope deduplicate an
already-known resource. Thus repeated checkout does not add duplicate monitors
for the same resource. Each accepted connection contributes one TCP and two
TLS resources at these boundaries; this is a resource-count fact, not a byte,
heap-word or native-allocation bound.

Handoff identifies the exact TCP/TLS inventory, plus the H2 owner where supplied
(`:113–151`), and removes matching request monitors (`:268–279`). Scope monitors
are untouched. H1 idle checkin (`http1/pool.ex:100–123`) and H2 registration
(`http2/pool.ex:125–153`) require handoff success before exposing pooled reuse.
The unchanged Fetch H1 checkout call (`socket_client.ex:374–378`) now restores
TLS request monitors through the new `track_socket/2` clauses. Scope's resource
deduplication preserves the original connector-token association after reuse.

Cancellation closes TCP; the new TLS cancel clause does not kill TLS PIDs
(`request_lifecycle.ex:405–406`). Request completion remains dependent on actual
monitored resource DOWN signals, unless that connection was handed off. Scope
keeps its own DOWN evidence across handoff (`scope.ex:99–112,147–160`). Connector
slot pruning requires done, no socket/dials, and no remaining tracked resource
with that token (`:239–249`); a surviving receiver or sender therefore prevents
that slot's release. Scope settlement requires no occupied ingress, resources,
children or connector slots (`:214–235`). Confirmed latch2 plus coordinator DOWN
is the public `await_retired/2` success path. These are static transition facts;
fresh races and capacity-turnover observations remain separate checks.

Unsupported tracked socket representation returns
`{:error, :unsupported_tls_socket_representation}` and marks tracker/scope
uncertainty. TLS connect/upgrade abort TCP on that error. A managed TLS setup
error that returns no socket also marks uncertainty (`ssl.ex:12–79,93–97`), with
Dialer now forwarding `managed_coordinator`. Scope's unconfirmed handler closes
admission and begins graceful retirement; new connector starts reject uncertainty
(`scope.ex:83–95,121–124`). Child termination preserves existing uncertainty.

A settled unconfirmed scope uses latch3. `retire/2` now returns its durable
receipt even after the coordinator has terminated, while unchanged
`await_retired/2` still returns `{:error, :cleanup_unconfirmed}` for latch3
(`managed_transport.ex:136–205`). Receipt availability does not certify cleanup.
Failed setup returns no TLS resource inventory; it establishes neither TLS
receiver/sender DOWN nor successful resource reclamation. This explicit
uncertainty is part of the new public behavior, not a successful release proof.

## Remaining qualification and verification

The immutable tag includes source regressions for verified connect/upgrade,
suspended sender DOWN, exact handoff/recheckout, unsupported inventory, failed
setup, managed H1/H2 idle reuse, raw abort, retained capacity and durable receipts.
Their identities are pinned in the JSON. They were inspected and **not run**;
several use private state/process inspection as test instrumentation. That is
upstream test source, not a Gaoxy production workaround or independent public
runtime qualification.

Fresh strict compile, scoped compatibility, verified TLS H1/H2 lifecycle,
connection replacement, delayed sender, setup failure/cancellation and repeated
receipt checks remain **NOT RUN** in this assignment. Exact parser/monitor source
containment permits fresh qualification; it does not prove those runtime
contracts or full P0–P6 roots/copies/native/transient accounting. Historical
0.21.1 bytes and acceptance results remain historical. The extra TLS PID,
monitor and scope/token roots need their own current accounting; unchanged
source alone cannot rebind a complete prior proof.

Collection, installed freeze, archive extraction/checksums, all tag blobs,
manifest normalization, public-name inventories and pinned-input checks exited0.
Final local revalidation checks the receipts and source hashes. Only the five
assigned evidence files and ignored0.21.2 cache were written. No dependency
mutation, VM, Mix, compiler, fixture, private production API, historical edit,
commit, publication or child agent was launched. All own commands completed.
Sol repair rounds0, unsuccessful Sol rounds0, Astra rounds0; no escalation gate
or new product decision applies. Parent independent review and serialized runtime
qualification remain outstanding.
