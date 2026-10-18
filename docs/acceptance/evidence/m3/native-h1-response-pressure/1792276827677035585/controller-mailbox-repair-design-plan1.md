# Controller mailbox repair and matrix timeout diagnosis

Continuing authorization selects the recommended bounded approach automatically. This is a test-only repair within the existing native-H1 pressure stage; all runtime acceptance remains pending. Source entry is candidate8 (test aa9646ac1e15a912f634f950ec4b5a35bcc4577e7d083c17248e0b676ff894aa). Counter33 preserves Sol5/runtimefailed5/Astra2of2 and all historical failures.

The actual diagnostic-fresh3 run executed52/3, excluded0/skipped0: group/TCP pressure failed at controller mailbox67/64 at eof_released. The controller receives each send telemetry event but several selective waits do not drain them. Diagnostic packet history is incomplete (32-packet cap), and old fresh1 count66 had no actor attribution. Separately fixed/group native-H1→TLS-H1 temporal cases timed out in respond/5 on connection2; request identity and cause remain unknown. See diagnosis5.json and matrix-compat-diagnosis1.json for immutable evidence and confidence limits.

## Selected design

Draining every controller wait leaves a scheduler-dependent burst queue and touches unrelated wait paths. A separate observer adds another mailbox and lifecycle. Direct synchronous writes to one test-owned ETS table avoid telemetry notifications and add no process. Select the ETS option.

Use a public table owned by the test controller, created before attachment and retained through normal emitter joins and telemetry detach. The observer records exactly the existing event, generation monotonic time, bytes, operation and outcome, filtered by the same exact scope. Reserve a unique slot atomically; slots1..128 retain committed event rows. A counter saturates at129 as sticky overflow, using the supported ETS operation:

```elixir
slot = :ets.update_counter(table, :count, {2, 1, 129, 129})
if slot <= 128, do: :ets.insert(table, {slot, event})
```

No per-event controller message or extra observer process. Event reads return only committed rows: a reservation may precede its row while a callback is running. Never assert reservation/row equality during progress. The sampler and event reader reject overflow; after all normal emitter joins and detach, require counter<=128, exact committed-row count equality and valid unique slots. Event129 cannot become a silent accepted drop. Maximum retained rows remain128 plus one fixed control row; keep mailbox64, metadata/hash/operation identities and all original protocol/resource/time limits. Delete the table only after detach and owned cleanup; keep failure cleanup failures visible. Remove only message plumbing made unused by this change; preserve bounded failure chronology and actual outcomes.

Matrix diagnostic ownership is separate: only failure branches in respond/5 and next_event/4 (or stop/2 rescue). Retain RuntimeError, original response release deadline prefix and5000ms. Add existing base connection/request ordinals plus POST/DELETE/other method and temporal/trailers/other route labels. Existing fixture-owned queued events may yield at most16 summaries plus total/truncated, whitelist accepted/request/upload_prefix/upload_end/command and event/connection/request/method-label/route-label/action-label/ended fields. No raw targets, payloads, headers, extra success queries/messages/drains or functional timeout repair. Unknown cause stays unknown until a real attributed failure.

## Implementation and verification plan

- [ ] One writer owns only upstream_transport_native_h1_pressure_test.exs for bounded ETS storage, overflow and final completeness. Another owns only support/managed_h1_matrix_fixture.exs for failure-only matrix metadata. They preserve each other's edits; root owns runtime/evidence/Git. No production or dependency edits.
- [ ] Root formats only those two files, freezes their source plus unchanged dependencies/doc cohort/evidence, then obtains independent source SPEC followed by CODE. Retain exact prior failures and unchanged assertions.
- [ ] Root runs strict compile and two-file format checks. Execute the actual four pressure cases with no selectors/exclusions, then the same five-file52 command with seed166590 and max-cases1. A failure re-enters diagnosis; a matrix timeout must expose the new bounded identity context. No enlarged deadlines or skipped cases.
- [ ] Independently review implementation and actual pressure/accounting/normal-cleanup evidence. Then qualify the original standalone default16 and ordinary browser two rows with four actual root image opens. These remain default compatibility evidence, distinct from slow-reader acceptance.
- [ ] Reconcile canonical3 and both main plans against actual results, complete independent final fact/doc review and fresh affected checks, make a local conventional commit and postcommit custody. Include predecessor E12 custody. Advance the prepared sole-H1 disconnect slice only after this actual closure. WholeTask6/Task5/M3 remain OPEN.
