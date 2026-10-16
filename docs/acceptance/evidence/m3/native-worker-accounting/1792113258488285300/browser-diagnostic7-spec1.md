# Frozen diagnostic7 actual-source SPEC1

**DONE — PASS, source-only for the NONACCEPTED diagnostic.** No runtime/browser/acceptance PASS is claimed. No actionable finding remains on this revised tuple.

## Prior findings resolved

DIAG6-SPEC-F1: `native-worker-browser-diagnostic-host7.exs:461–496` begins projection at depth0, retains only a finite literal atom allowlist and at most3 allowed wrapper tags (`:shutdown,:handshake,:tls_alert`), and uses a fixed omission marker for deeper/unknown/nonallowlisted values. Integers, binaries, maps, exception structs and arbitrary reason contents are no longer retained. Traversal and projected output now have a hard bound independent of reason input; there is no raw-reason format/hash/inspect operation.

DIAG6-SPEC-N1: `error_present: Map.has_key?(metadata,:error)` at440 preserves original key presence separately from projected nil/value. **Missing stop error still cannot distinguish local close, peer close or orderly shutdown.** This corrects field-presence evidence, not causality; earlier FAIL/report remains immutable.

## Preserved logging and acceptance contract

The rest of host6→7 is unchanged. The exact public connection start/ready/stop/exception subscription, handler guard, before-service attach, actual emitter `self()` identity and send-only callback remain. No callback I/O/blocking/socket/sys-state call or original metadata forwarding was added. Existing exact safe sys-reply projection, all original protocol/global Gate/custody/lease/actor/terminal assertions remain.

Runner6→7 changes only host filename. Helper3 is byte-identical to the prior reviewed helper; scalar per-direction I/O/EOF/counter diagnostics leave actual relay decisions/finite deadlines/authorization/byte identity/normal joins unchanged. NONACCEPTED diagnostic metadata and source inventory remain. No synthetic acceptance, production/API change or relaxed assertion is introduced.

Observability limits remain: queued telemetry can be lost if the main hostloop blocks/fails; helper diagnostic sink can fail independently; omitted reason and missing events remain UNKNOWN. Prior earlyEOF cause stays **UNKNOWN**, with no inference that Chrome abandoned the connection.

## Frozen identities and verification

- `native-worker-browser-diagnostic-host7.exs`: `a8e19636c70e338bb32574f6896058f9214d1bbc5f6e850e6a657140ef39b513`
- `native-worker-browser-diagnostic-runner7.py`: `03a9570fbde11d68e444f7556d1f9aca1f2161cfad71612347c6d796755542e0`
- `native-worker-browser-frontdoor3.py`: `2049619b2e77073af8c4269eec1ddf307db64d0a0656f1b1b4cfa0e6a02ac2b1`

Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; evidence root `docs/acceptance/evidence/m3/native-worker-accounting/1792113258488285300`. Frozen identities reverified before/after read-only source/diff review. Parent-reported formatter94824 joined exit0 before freeze; not independently rerun or promoted to runtime evidence. No runtime/browser/network/Mix/Git operation, raw archive read, or repository edit. Only assigned `/tmp` reports were created. All own commands completed.

Counters unchanged: group37/root48/stage7/Astra2of2/diagnosticfails3. This review adds0 failedGREEN and0 Sol repairs. Full-stage acceptance remains OPEN.
