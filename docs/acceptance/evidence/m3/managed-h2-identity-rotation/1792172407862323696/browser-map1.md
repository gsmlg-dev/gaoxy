# H2 identity rotation browser fixture map

Task: h2_rotation_browser_map. Status: DONE (read-only fixture mapping only).
Direct assignment; root remains sole repository/evidence/Git writer and runtime/build/test/browser executor.
Repository: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation
Verified baseline: 4f08008f2bdb830bbc0191ba9db39786bb7ea905; initial git status --short empty.
Successor evidence root supplied by root: docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696.
No production/test/browser process started; no repository file changed. Only this /tmp report written.
Counters: inherited group54/root132, later root reports root133/orchestration61/successor-tooling1; no reset, no repair performed here; Astra2/2 exhausted unchanged.

## Scope and smallest row manifest

Recommend FOUR positive TLS browser rows total, executed fixed first, then group:

| row | endpoint | native browser downstream | managed upstream | actual coverage |
|---|---|---|---|---|
| fixed-h1-http2 | fixed prepared T through Generation | HTTP/1.1 clear downstream | TLS-H2 | old/new same-authority DER trust and numeric routing |
| fixed-h2-http2 | fixed prepared T through Generation | native TLS-H2 | TLS-H2 | same |
| group-h1-http2 | two-member/single-owner group through Generation | HTTP/1.1 clear downstream | TLS-H2 | selected old/new A trust/routing; both members health and retirement |
| group-h2-http2 | two-member/single-owner group through Generation | native TLS-H2 | TLS-H2 | same |

The two predecessor h2c rows per endpoint remain scoped compatibility evidence. They are not TLS trust evidence and need not be added as new trust rows. Do not call these four rows the full protocol/streaming matrix, reload/load, multi-owner, selected-B request coverage, standalone or whole Task5 completion.

The predecessor keeps old/new paths distinct (/old%2Fpath?raw=%2F and /new%2Fpath?raw=%2F), to correlate immutable old/new captures and DOM markers. Keep that accepted correlation. Hold the upstream configured origin URL byte-for-byte equal across old/new, with unchanged hostname/port and corresponding request Host/:authority/SNI. Do not describe the two deliberately distinct request targets as identical whole request URLs. If literal identical browser request URLs become a separate requirement, the CDP event selector currently finds the first matching URL and needs per-navigation request/loader correlation; that is beyond the minimal origin-identity adaptation.

## Canonical accepted inputs

All paths below relative to verified repository root unless absolute.
G = docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786
F = docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423

- G/group-generation-browser-host4.exs
- G/group-generation-browser-runner4.py
- G/group-generation-browser-cohort1.exs
- G/browser-command-collector3.py
- Fixed counterpart actually referenced by F/fixed-generation-browser-runner4.py: HOST fixed-generation-browser-host3.exs (runner26), COHORT fixed-generation-browser-cohort2.exs (runner27).
- Common independent peer: apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py.
- Common downstream TEST certificate generator: scripts/generate-fixtures.sh.
- Current runner PEER_PYTHON is exactly /tmp/gaoxy-m3-h2-soak-venv/bin/python (both runner4.py:29). Peer prepare146-150 enforces h2=4.3.0, hpack=4.1.0, hyperframe=6.1.0. Resolve/qualify this interpreter explicitly; do not silently substitute a Python with different packages.

Use fresh successor copies and fresh artifact/receipt names. Preserve historical accepted fixture bytes and receipts. No need to re-review the already accepted old/new A fixture internals.

## Minimum peer identity adaptation

The fixture mapper owns the peer implementation proposal. Current peer Peer.__init__58 and start183-192 hardcode 127.0.0.1:0. Additive --bind-address and separate --listen-port are appropriate; existing --port800 is client-side and must retain its meaning.

Fixed: old 127.0.0.1:P, new 127.0.0.2:P, origin https://localhost:P for both.
Group: old_a 127.0.0.1:P, new_a 127.0.0.2:P, old_b 127.0.0.3:P, new_b 127.0.0.4:P, same origin https://localhost:P for all. Use the first actual bound ephemeral port for P, then bind the others at that actual P; bind failure is an explicit fixture/environment failure, never a fallback to changing authority. Distinct numeric socket tuples and actual peer PIDs establish physical identity even if per-peer connection counters start at1.

Keep each peer's existing ephemeral independently generated chain (prepare157-178) unless the mapper needs an explicit chain injection option. Existing chains already give different CA/leaf identities per peer; do not reuse the Chrome downstream SPKI exception as upstream trust proof. Peer TLS context remains certificate verification-independent server side, h2 ALPN, SNI reporting at serve220-226. Record public CA/leaf SHA256 only; do not copy leaf keys into evidence.

Peer-ready manifest must add/retain a bounded numeric bind-address field. Validate numeric loopback tuples strictly in fixture host, then pass exact four-key production source: %{protocol: :http2, origin: same_origin, connect_address: numeric_tuple, trust: der_list}. Do not add fixture metadata keys to this production source (ManagedH2Preparation.prepare_policy42-45 requires exactly4).

Current unique-port assertions must change: G runner497-498 and host1023; F runner488 and host721. Assert equal actual ports, equal origin, unequal numeric address, distinct physical (address,port) tuples and peer PIDs. G runner616/F runner573 currently compare PID/port; include address in reported physical identity and require the expected old/new tuple.

## Trust replacement and captured policy proof

G GroupH2GenerationBrowserDraft.prepare_candidate385-409 already reads ready["ca"] -> PEM decode -> DER -> T.prepare, then retains sources/transports/custodians. F prepare_candidate388-409 is the same fixed seam. Change only fixture inputs: stable trust-a.pem path for old/new A (and trust-b.pem for old/new B). Copy each old peer's public CA to its stable slot path, prepare OLD, activate OLD, replace each same slot path with its NEW peer CA, then prepare NEW. All copies happen inside bounded fixture setup with no production file-trust API added.

Exact sequencing seam: G host1043 old prepare,1044 old activate,1045 new prepare; F host739-741. File replacement belongs between activation and new preparation. Record path identity, old/new PEM hash and DER hash/count/bytes, assert changed contents, unchanged path, old policy DER equals OLD chain and still equals OLD after replacement, new policy DER equals NEW chain, old/new transport resource handles differ, origins/host/port/protocol equal, numeric address differs as expected.

Production immutable policy location: owner.records[transport.resource].policy (existing fixture already reads records for custodians). Compare actual prepared policy and open_options, not a label generated from ready metadata alone. ManagedH2Preparation.prepare_policy42-67 freezes origin, numeric address and open options; ssl_options618-629 sets verify_peer/cacerts/copied DER/SNI; open_options631-643 uses exact origin/address/http_version :http2/native_v1/max_connections2. Policy source is bounded explicit DER; file/default trust is a different unimplemented API and must not be claimed.

## Mandatory cold old handshake; group health adaptation

Fixed has no health warm-up: retain capture before first checkout, CAS while captured, then old dispatch. Because trust replacement and NEW preparation already preceded dispatch, actual OLD TLS handshake happens after replacement using the captured OLD policy. Require actual OLD peer TLS event h2/localhost and GET at expected numeric listener, then distinct NEW peer handshake/request.

Group prepare launches health probes eagerly (host441, await_health483-545). Existing runner506-531 drives4 HEAD health completions; runner563/566 explicitly reuses the health connection for GET. That warmed-reuse check must change for rotation.

Recommended bounded successor contract, coordinated with peer mapper:
1. Keep all4 real health HEAD probes, original RequestCompletion await, normal Probe DOWN, zero probe/control cleanup gates (host483-545).
2. Close each health socket cleanly AFTER its original HEAD completion. A peer close-after-HEAD mechanism must not truncate the HEAD or mark intentional closure as fixture failure. Record actual health physical closure and worker completion before browser old capture dispatch. No pool private internals or manual mutation of dependency clients.
3. Dispatch OLD after replacement/CAS. Selected old_a must produce a new accept, TLS ALPN h2/SNI localhost and GET on a connection different from its health connection. Then dispatch NEW and require the same fresh identity for new_a. With both health and request sequential, each T remains within existing max_connections2; no capacity increase needed.
4. Selected A peers now expect accepts2,requests2; unselected B expect accepts1,requests1. Old/new request retirement must correlate closure to the fresh GET connection, while unselected B health closure is already recorded. Preserve custodians' normal DOWN/resource retirement proof even though B has no live socket at retirement.

Concrete runner extension seams: health handling509-529; GET request555-567; old retirement physical closure594-596; new final physical closure642-644; per-peer join649. Existing runner563 request.connection==health.accept.connection must become inequality plus equality with fresh accept/TLS. Do not treat peer counters alone as immutable identity; report peer PID,address,actual common port,health connection,request connection and TLS metadata. The mapper determines exact bounded peer-close event, but absence of a fresh selected OLD handshake leaves cold trust coverage NOT RUN/FAIL, not PASS from policy metadata or warmed reuse.

## Preserve Actor, custody, accounting, browser-close and retirement gates

- Actor class G runner318-396: owned session process groups, bounded event EOF/error, actual wait exit0, reader joins, nonforced group disappearance. Keep as accepted.
- Root collector children27-91: subreaper-owned descendants, reap-before-force, no live residue; forced cleanup remains failure. Runner305-315 preserves direct Actor wait ownership while reaping only adopted children.
- Genuine source pin/captured native worker, CAS while pin held: host590-674; source receipts and traces, baseline release, old admission closed, old custody stays live. Preserve original B/accounting and Cohort arithmetic unchanged.
- Session custody1540-1578: derived authentic child receipt, original native holder/acquirer/source_ref, actual Service cleanup token/owner/lease/bytes and cleanup_pending1. Bound original completion and returned-source-held checks host676-801 / runner568-589 remain mandatory.
- Old retirement: host804-827 and1675-1700: old source/group pins gone, records/group removed, each original custodian normal DOWN. Socket close metadata does not replace these gates.
- request_clean: host1702-1727,1799-1885; runner603-611. Keep exact authentic NEW baseline group+two T holds, no request tokens/probes/helpers, zero cleanup pending, native worker/session joins, complete native cohort, live downstream connection/writer. No browser close to make request_clean pass.
- Explicit close authorization: host1730-1754 asserts two completed requests and native downstream target still live/not-closing/not-draining; runner617-627 explicitly sends Browser.close through Node driver, waits actual exit0/profile removed/nonforced, then host stop.
- Final closure: runner628-657 and host1888-2006: genuine complete cohort terminals, Service active0/bytes0/pending0/cleanup_failed nil, zero transport/group state, custodians/owners/instance joins, rebind, immutable loaded manifest equality.
- Cohort snapshot47-62 binds actual public Gate status alias to debug state; progress507-560 trace-delivery barriers cover EVERY acquired PID, including dead/refunded actors. Preserve; no partial facts() substitute for final complete snapshot.
- Raw diagnostic custody: runner665-705 deletes only after owned groups/readers joined; leaves owned raw location recorded if unproven. Use bounded allowlisted NetLog projection only; never publish/read raw private diagnostics as evidence. This mapping did not read raw NetLogs, any private key, or the specifically forbidden terminal trace.

## Source/loaded module manifests and collector adaptation

G runner401-406 inventories all apps/config .ex/.exs plus mix.exs/mix.lock/generator/HOST/COHORT/PEER/runner. G host identity957-1014 enumerates every loaded :gaoxy/:gaoxy_http/:gaoxy_proxy module, requires current-worktree _build path, exact beam bytes/MD5 match, source path inside correct app and source SHA256, plus fixture module source/hash/loaded MD5. Host before/after1020-1021,1982-1984 equality is mandatory. Update source allowlist and Code.require_file path3-5 to exact chosen successor host/cohort paths; reusing unchanged predecessor cohort is fine only when explicit canonical path is inventoried and allowlisted.

Collector94-188 snapshots source around the actual bounded runner command, binds actual PID/exit/group joins, source_before==after, qualification+artifact SHA256 and owns600-second deadline. Its source glob111 currently only captures group-generation-browser-*; adapt to EXPLICIT new fixed/group runner+host/cohort/peer/collector inputs, so renamed successor fixtures are covered. Do not accidentally bind only the historical predecessor fixtures.

Collector161-165 currently enforces4 rows with (mode,upstream_protocol) cross-product including h2c. Change expected row contract to the four endpoint/mode TLS identities above, or use2 separate receipts expecting2 TLS rows each and aggregate them explicitly. Do not retain executed4 by relabeling missing rows or by counting old/new navigations as separate rows.

Smallest recommended execution shape: two derived runners, preserving respective fixed/group accepted lifecycle assertions; each runs native modes h2,h1 with upstream_protocol=http2 ONLY. One copied collector accepts explicit fixed/group expected set and executes each runner separately. Then aggregate exact2+2 PASS receipts with their own source and artifact hashes. No new combined runtime framework is needed.

Proposed commands (names are recommendations, not existing or executed files):
python3 -B <successor>/browser-command-collector1.py --name fixed-browser-final1 --receipt fixed-browser-command-final1 --runner fixed-identity-rotation-browser-runner1.py --endpoint fixed
python3 -B <successor>/browser-command-collector1.py --name group-browser-final1 --receipt group-browser-command-final1 --runner group-identity-rotation-browser-runner1.py --endpoint group

New --endpoint only chooses an explicit expected manifest; collector still uses sys.executable -B runner --evidence-dir <fresh-dir>, and actual host command remains nix develop --command env ERL_FLAGS=+S 2:2 MIX_ENV=test mix run <exact-host> <manifest> <evidence> <mode> <downstream-test-cert-dir> http2. Each actual command is separately qualified. Use root-selected fresh final names after diagnostics.

## Deny rows remain separate

Task5 plan docs/plans/m3-upstream-transport.md572-574 includes hostname rejection, no credential forwarding and no cross-generation reuse. Keep their deterministic negative tests/peer observations separately labeled from four positive browser rows. An expected TLS denial does not satisfy a positive DOM/protocol row. Same-origin positive routing and distinct resource handles need actual peer evidence; labels or different ports are insufficient.

Missing Service is NOT cleanup success. cleanup_attachment1783-1795 raises "actual Service cleanup attachment missing";1549-1556 requires the real positive cleanup receipt and >0 bytes. A denial after Session creation must still prove its actual cleanup contract/completion/joins. A deliberate pre-Session rejection can have an explicitly proven no-Session/no-acquisition contract, but cannot emit the positive session_custody/request_clean facts or silently bypass a required attachment. Do not change missing Service/observer/peer EOF into success merely to complete a deny row.

## Verification and remaining decisions

Performed read-only pwd/HEAD/status and scoped source/line inspections; commands completed. Two initial shorthand filename lookups and one wrong-cwd peer source read returned missing-file errors and were corrected by exact canonical path; no runtime/test failure or repair counter consumed. No tests/build/browser/network executed by this investigator, by assignment. No escalation or design blocker found.

Remaining implementation work belongs to root/mapper: exact bounded health close mechanism/event and fresh GET handshake, strict additive address/listen options, trust-path/policy manifest hashes, successor source inventories and collector expected2+2 contract, deny-specific acceptance. The mapping does not claim any unexecuted successor gate PASS.

Root final steering: keep the original fixed/group standard test cases and assertions intact. Add a TLS-only :rotated identity variant for native h1/h2 (two extra cases per endpoint), with a dedicated cold-request/accept-total helper for rotated cases. Browser execution remains four new TLS positive rows; separate fixed/group successor hosts derived from each accepted host are the smallest approach and avoid adding a combined parameterized endpoint runtime. Keep h2c and standard warmed-connection assertions in the unchanged standard cases; use fresh-connection and accepts2-for-A expectations only in the rotated variant.
