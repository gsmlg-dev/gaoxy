# Frozen diagnostic4 actual-source SPEC1

**DONE — FAIL. One blocking race in the frozen frontdoor1.** This is source-only review for a NONACCEPTED diagnostic, not GREEN or full-stage qualification.

Repository: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`
Evidence root: `docs/acceptance/evidence/m3/native-worker-accounting/1792113258488285300`

## DIAG4-SPEC-F1 — control-first authorization accepts preauthorization EOF

`native-worker-browser-frontdoor1.py:45–60,87–98`: `select.select` can return stdin authorization and an already-readable selected-socket EOF together. The code handles stdin first, checks cached `eof`, sets `authorized=True` and emits its ack, then reads that socket's EOF and accepts it because authorization is now true. This recategorizes an observable preauthorization EOF as allowed shutdown. The host's live C/R handshake cannot remove the interval between that handshake and relay authorization.

Required correction: selected I/O must be serviced before authorization. Parse authorization as pending; keep the relay unauthorized until the same live pair has no EOF/error/failure, both queues are empty, and a fresh zero-time read-readiness check on both sockets is empty. If readable, defer and service it while still unauthorized. Pending authorization cannot accept duplicate/other commands. Emit ack only after committing at that observed quiet boundary. Exceptions remain fatal/nonzero and the finite absolute deadline remains. This addresses observation order; no implementation can claim that a local poll establishes unknowable remote physical FIN ordering.

Parent's planned helper2 uses this approach and is conceptually suitable. Its actual source and runner binding were not supplied/reviewed in this report; the FAIL binds only frozen frontdoor1 and diagnostic4 pair.

## Preserved and otherwise sound source behavior

Host4 versus diagnostic3 adds only exact connection sys-state reply projection through `diagnostic_log`; all original assertions are retained. Runner4 versus diagnostic3 retains all existing checks, adds frontdoor inventory/launch, keeps host requestclean+same captured live C/R authorization before relay authorization ack before Browser.close, waits for relay complete/normal join, and names the run `NONACCEPTED_BROWSER_DIAGNOSTIC` with its isolation profile.

Frontdoor1 uses one irreversible first selection and exactly one backend connection call; extras close without a backend. It binds loopback, connects to the native ready port with5s timeout, uses nonblocking I/O and90s absolute deadline, bounded65536-byte direction queues and partial sends. Per-direction read/write lengths and streaming hashes preserve byte identity; complete requires positive traffic in both directions, true EOFs, queue drain, half-close after source EOF/drain, and normal socket/process join. Read/write/reset/timeout exceptions remain nonzero failures. Runner actor joins and forced-cleanup FAIL handling remain unchanged; the strict independent raw upstream peer is untouched.

Nonblocking notes: selected/backend endpoint tuples are not emitted, though source and configured port bind the sole backend to the native listener and exact global actor assertions remain. Result `entry_counters` retains predecessor historical group30/root35 text; parent evidence must retain actual current group37/root47/stage7/Astra2 separately. The safe reply projection covers its exact matched alias shape; no broader shape guarantee is inferred. No raw archived trace or full sys-state reply was read.

## Exact reviewed identities

- `native-worker-browser-diagnostic-host4.exs`: `1c2b98b459c3d15d3fad7d5c20d73e7a5b7629c1a507da0ead62e8c929d15113`
- `native-worker-browser-diagnostic-runner4.py`: `aa592a2825a49978ca97c7e96886b4dcb07d67c14c1d56d469089c6a05bd6961`
- `native-worker-browser-frontdoor1.py`: `8015508ae56c3b4b33220536000ca96bda3ab12bfb505ba812a91c16eada1a4c`

Verified these hashes again before reporting. No repository edits, browser/runtime/network/Mix/Git commands, or actor launches. Source reads/diffs/hash checks completed; expected diff exit1 denotes source differences, not runtime/test failure. Parent-reported formatter/AST checks were not rerun or promoted to runtime evidence. Only the two assigned `/tmp` reports were created.

Counters unchanged: group37/root47/stage7; Astra2of2 exhausted; zero new failedGREEN and zero Sol repair rounds from this review. All own commands finished. Prior target writer cause remains **UNKNOWN**; full-stage acceptance remains OPEN.
