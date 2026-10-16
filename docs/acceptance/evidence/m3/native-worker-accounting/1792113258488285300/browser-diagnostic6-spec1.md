# Frozen diagnostic6 logging delta SPEC1

**DONE — FAIL for the requested bounded logging contract.** One blocking projection bound finding; original protocol/accounting/lifecycle assertions remain intact. Source-only review for a NONACCEPTED diagnostic, not runtime or acceptance PASS.

## DIAG6-SPEC-F1 — reason projection is not hard-bounded

`native-worker-browser-diagnostic-host6.exs:460–464` recursively preserves arbitrary-depth `{:shutdown,reason}`, `{:handshake,reason}`, and `{:tls_alert,reason}` chains without a depth budget. The host then writes `inspect(event, limit: :infinity)` at669–673. An arbitrary terminal metadata term can therefore produce input-sized callback traversal and logs; integer reasons also have no representation bound. The public error/reason type is arbitrary term. This is source evidence, not a claimed actual runtime trigger.

Use a small explicit depth cap and fixed omitted marker on exhaustion; allow only bounded safe scalar values (literal safe atom allowlist, and omit or bound integers). Do not inspect/hash/stringify unknown raw terms. Keep the callback send-only and preserve all existing assertions.

## DIAG6-SPEC-N1 — absent error is lost, never closure proof

At439–442 `metadata[:error]` maps absent key and explicit nil to the same value, and the output always inserts error:nil. Add `error_present: Map.has_key?(metadata,:error)` if distinguishing field absence matters. Regardless, even genuinely missing error cannot distinguish peer_closed/local_closed/shutdown: TI deliberately omits error for all three. No interpretation may infer Chrome abandonment or replace authentic terminal checks. This is an observability note, not an assertion failure.

## Preserved contract and privacy

Host4→6 retains all original assertions and exact safe sys-reply projection. Added telemetry whitelist is precisely public connection start/ready/stop/exception with handler==Gaoxy.HTTP.Connection. Registration returns:ok before starting native service; callback `self()` correctly captures emitter PID. Callback does maps, pure reason classification, scalar monotonic clock and send only, with no I/O/blocking/socket/state call or forwarding of original maps. Under the inspected TI source, projected remote address/port/spanrefs and measurement keys contain scalar protocol metadata; raw TLS/socket state, binary reason contents, exception structs and stacktraces are not copied. No listener/data-bearing telemetry is subscribed.

Frontdoor3 adds only scalar first-I/O/directional EOF/exception/final-close diagnostics. In particular `selected_eof` records endpoint_role and direction **before** the unchanged earlyEOF assertion. It does not print wire bytes. Original irreversible first socket, backend count, byte identity, finite deadlines/backpressure, pending authorization quiet boundary, half-closes and joins remain. Original exception is re-raised. Diagnostic sink OSError is deliberately ignored for noninterference; an absent line remains missing evidence rather than success.

Runner6 differs only by host/helper filenames. All assertions, NONACCEPTED profile identity, source inventory and forced-failure handling remain. No synthetic acceptance is added. The main hostloop recorder can still miss queued events if host blocks/fails before receiving them; telemetry is evidence only and absence remains UNKNOWN. Registration lasts until owned host VM teardown; no explicit detach/completeness check was added.

Prior early terminal cause remains **UNKNOWN**. Stop without error is not a process-exit reason; exception may replace stop; pre-span peername/ownership failures or brutal kill may lack terminal telemetry.

## Frozen tuple and verification

- `native-worker-browser-diagnostic-host6.exs`: `ec16bd51ba5e9c5f9925931ee3ced8c573ea8d9f78a862c703118a85e020e6af`
- `native-worker-browser-diagnostic-runner6.py`: `54586cdd23b800b60a114c1c2de529d2138c92dbff09020cd03f7578f3fdd8db`
- `native-worker-browser-frontdoor3.py`: `2049619b2e77073af8c4269eec1ddf307db64d0a0656f1b1b4cfa0e6a02ac2b1`

Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; evidence root `docs/acceptance/evidence/m3/native-worker-accounting/1792113258488285300`. Hashes matched before/after scoped read-only diff/source review. Expected diff exit1 is a change indicator, not runtime/test failure. CODE-agent AST equivalence was not independently rerun. No runtime/browser/network/Mix/Git operation, raw archive read, or repository edit. Only assigned `/tmp` reports were created. All own commands finished.

Counters preserved: group37/root48/stage7/Astra2of2; diagnosticfails3. This review adds0 failedGREEN/0 Sol repairs. Full stage remains OPEN.
