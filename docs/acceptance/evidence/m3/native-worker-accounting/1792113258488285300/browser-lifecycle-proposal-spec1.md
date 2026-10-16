# Browser lifecycle SPEC1

PASS for the bounded runner3/host2 fixture proposal with the preservation conditions below. This is a direct independent source-only SPEC assignment, not implementation or runtime acceptance.

Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; baseline `58307a7084298db309a93697b9102b2cc4c87eda` from archived qualification, with no Git commands run by reviewer. BrowserGREEN1 remains FAIL: H2 executed1, H1 NOT RUN, actual exit1, forced cleanup despite all owned groups gone. Qualification SHA256 `f970b3f2c767c7212a1b729db3eb9cd646c2c45d188ebeaa0c939c377e2d65e2`.

Independent parsing confirms `session_custody` and `request_clean.custody` have exactly equal complete payloads; the full event has only one additional field, `event: session_custody`. Separate that envelope discriminator explicitly and preserve exact equality for every payload key. This repairs a fixture contract mismatch.

ThousandIsland's pinned Handler source416-421 returns exactly `{:stop, {:shutdown, :peer_closed}, {socket, state}}` for the actual matching socket's tcp_closed/ssl_closed. Its terminate495-498 invokes handle_close. Gaoxy uses this handler, and its H2 close1411-1421 sends writer :stop. Therefore authorized graceful browser closure requires the exact connection monitor reason `{:shutdown, :peer_closed}`; Session, H2 request worker, writer and fixture actors still require :normal. This is a supported lifecycle contract, not grounds for production edits or catchall acceptance.

Required implementation and acceptance:

- Create new immutable runner3/host2; retain runner2/host1 and browser-green1 FAIL unchanged. No production or startup95 modifications.
- Assert custody event discriminator exactly session_custody, remove exactly that envelope key for comparison, then compare the entire remaining dictionary to request_clean.custody with exact equality. Do not compare a selected subset or strip arbitrary keys.
- Host request_clean performs the existing actual public status, Session normal join, H2 native-worker normal join and Gate cleanup checks before setting request_cleaned=true. Authorization requires that flag and rejects repeat or out-of-order commands.
- Host authorize_browser_close must verify the real native connection is still alive and not previously joined: H1 uses native/native_monitor; H2 uses separate connection/connection_monitor. H2 writer remains alive until close, while Session and H2 request worker must already have joined normally. Set a separate browser_close_authorized flag and emit explicit acknowledgment.
- Runner sends authorize_browser_close only after exact request_clean assertions, awaits and verifies its acknowledgment, and only then sends Chrome graceful exit. A missing or invalid acknowledgment is a failure; elapsed time is never authorization.
- Accept exactly {:DOWN, expected_monitor, :process, expected_connection_pid, {:shutdown, :peer_closed}} only with browser_close_authorized=true. H1 records native_joined for its connection; H2 records connection_joined on its separate monitor. Remove/guard existing connection normal-DOWN acceptance so :normal does not accidentally qualify. Any early connection DOWN, different PID/ref or reason still fails.
- Use an exact expected_reason parameter in join_native for connection joins only. Session, H2 request worker, H2 writer and fixture actors keep strict :normal. An already-joined boolean may only come from the corresponding exact expected monitor/PID/reason clause; still assert actual process dead and real monitor reference.
- Host stop requires request_cleaned and browser_close_authorized. Keep zero Gate active/retained_bytes/cleanup_pending and cleanup_failed=nil, actual dead flags and monitors, real resource zeroing, source identity, profile removal, all process-group joins and normal actor exits.
- Keep raw-peer complete request framing and sendall success, no partial request/reset/send acceptance, exact HEAD+GET sequence and joined live0/no failure. Keep actual CDP protocol/TLS/ALPN/DOM/screenshot and all original95 accounting/ownership assertions.
- Keep forced termination or nonzero actor exit as FAIL even when process groups are gone. Fresh H2 and H1 must both execute and pass after independent actual-source CODE review; archived H1 remains NOT RUN.

The authorization boundary needs a real live-connection check before acknowledgment. Merely setting a flag and later accepting a queued DOWN could legitimize an earlier connection death. H1 uses native/native_monitor because native is the connection; H2 uses its separately captured connection monitor. Mode-specific exact clauses must not leave the old connection :normal clause as an alternate success path. Request Session/H2 worker normal completion before authorization remains expected.

Source hashes and exact references are in companion JSON. No production/startup95 changes, no browser execution, builds, tests, formatter, network or Git. Only the assigned two `/tmp` reports were written. All reviewer commands finished, no background process started, and root nativeGREEN4 ownership was untouched.

Counters unchanged: effective group36/root42/stage failedGREEN6; production2/fixture4 before browser fix; Astra2of2 exhausted. Review adds0 repair rounds. Independent actual-source CODE review and fresh H2+H1 browser verification remain necessary. No further user/product decision is needed for this bounded fixture correction.
