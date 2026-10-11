# Published HTTP 0.21.3 source review

Task `upstream_contract_status_0_21_3`, direct bounded Sol source/provenance assignment.
Base `85c2284a035e0b4ecbf577279eee01142702b5a3`, branch `codex/m3-gateway`,
worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`.

The published source contains the #98 parser-error and #100 untracked-cancellation
changes. This review does not execute a VM or prove local runtime behavior.
Installed verification awaits the parent's dependency update. Feature #97 remains
open and managed numerical accounting/production activation remain blocked.

## Identity and sizes

The [archive receipt](release-provenance.json) checks all seven Hex archives against
separately downloaded GitHub release assets: complete archive SHA256, raw inner
`VERSION || metadata.config || contents.tar.gz` SHA256, package contents and exact
coordinated requirements. The [tag receipt](tag-source-provenance.json) binds all
921 immutable commit source blobs to tag `ceecbf2df62ca80c361597c7303f65a153f2ce3c`
and tree `6a44b862e8a09fb2648e48f928e37c20b1c8109a`.
The separate offline verifier reconstructs every Git tree, parses archive metadata
without evaluation, and rechecks the recorded bytes. Tag identity is not a signature
authentication claim.

There are 196 shipped files and 175 runtime `lib/` files, totaling
1853714 and 1711134 bytes respectively.
The [runtime inventory](runtime-source-inventory.json) lists every absolute cached
runtime source path, tag path, byte size, SHA256 and Git blob identity.
All runtime bytes equal the immutable tag. Seven package manifests differ from
development manifests; Fetch's three top-level text files resolve to exact root
LICENSE/README/CHANGELOG blobs. These ten normalization paths are explicit.

Relative to the preserved published 0.21.2 cache, [deltas](source-delta.json) show
10 changed shipped files, 186 identical files, no removed files, and only two
changed runtime sources; 173 runtime sources are identical. The two runtime files
are `http_core/lib/http/request_lifecycle.ex` (13082 to 14293 bytes) and
`http_fetch/lib/http/socket_client.ex` (67089 to 66950 bytes).

## Public parser and cancellation behavior

`SocketClient.fail/2` reports failure and finishes transport cleanup; a sent
streamed response delegates to `RequestLifecycle.fail_response/3`. For tracked
parser failures that function sends the original error to the response stream,
then sends a response-failure control message to its tracker. The handler retains
that response while cancelling the other registered resources. This removes the
previous generic-abort race against original parser-error delivery.

The failed unread response still owns its request lease. The published managed
transport guide and upstream regressions require original completion to return
`{:error, :cleanup_pending}` before the late first reader consumes the error.
The correct requester gate preserves exact `:line_too_long`,
`{:forbidden_trailer, "host"}` and `:trailers_too_large` observations, then separately
confirms original completion and generation retirement. Completion-before-reader
`:ok` would contradict the new contract. No fixture oracle was edited here.

Tracked abort, request deadline and lost-worker evidence retain their stop/cleanup
behavior. The nil-tracker clause precedes those cancellation guards and preserves
untracked abort/deadline errors for a late first reader, as required by #100.
The source tests cover early/late H1 malformed chunk lines and forbidden/excess
trailers, unread abort retirement, H2 malformed trailers, cancelled upload cleanup,
and actual-wire untracked H2 abort/deadline after peer-observed RST_STREAM.
These are inspected upstream regression sources, not tests run by this task.

Exact source hashes and relevant line anchors appear in the
[review receipt](source-api-review.json). Cached runtime diffs and upstream source
are retained only in the new `.audit/m3-transport/upstream-0.21.3` directory.

## Remaining boundary

The whole `HTTP.ManagedTransport` public module is byte-identical to 0.21.2.
Its termination receipt covers independently monitored resources; it supplies no
new native/deferred reclamation certificate, source/ABI/profile envelope or
history-independent control bound. The fetched #97 issue remains open and
acknowledges that missing contract. Published parser fixes do not resolve it.

Next parent-owned checks are the coordinated installation, independent installed
byte/metadata/lock verification, fresh compilation and scoped functional fixtures.
No dependency mutation, VM, fixture, Git mutation, private API, production activity
or edit to 0.21.2 records occurred. Direct Sol repair rounds 0; no Astra recovery
used by this source task. Independent parent review is required before stage advance.
