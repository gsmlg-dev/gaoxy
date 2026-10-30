# ARB-CORE — extended-quota repair12

DONE for the bounded implementation candidate and assigned scoped verification.
Independent review and whole-goal qualification/publication remain parent-owned.

Mode implementation recovery; gate SOL_REPEATED_FAILURE supported by the original
two Sol failures and continued parent handoff. Received Sol2/Astra11; cumulative
Sol2/Astra12. The user extends the same fixed window through2026-10-31T02:09:44Z;
no counter reset or numerical failure stop occurred. Existing main at
bc8a5ef5199293ada3b432c2e2741070d3b2d115, original goal baseline
a6a35438c0a153cd53c87c6a55c19a70a11fb75a. Preserved dirty integration remains.

## Findings and bounded repair

R2 is concrete: the inherited raw16/2 regression saw a65-byte returned app slice
pin8192 bytes into the next callback. New pre-repair controls extend this to
continue/close/error states and output. `red-state-output` executes24/10: actual
Hell.Socket.send entry receives a65-byte output referencing8192 bytes on both
TCP and verified TLS. The remaining failures retain the earlier backing gap.
All agreed red and earlier release-drain7 evidence is unchanged.

StreamBridge.normalize_app/2 first preserves the historical ordinary
external_size max_state check. It uses ordinary UNCOMPRESSED term_to_binary and
binary_to_term, checks encoded length before decoding, and requires decoded===
original before adoption. :state_identity_changed and :state_encoding_failed
fail closed; no changed decoded value enters live app state. The rejected
[:local] codec is not used. No node/distribution setting is modified.

Normalization applies after successful init and every continue/send/close/error
app return. On rejection, the exact original returned app goes only to terminal
cleanup. Initialization now keeps its original app/lease context through this
failure path. Six TCP/TLS controls prove original init/close/error cleanup
ownership on state-limit rejection. Existing state/output isolation assertions
remain intact. Successful termination hooks see detached state.

The original retained-slice regressions now complete their previously unreachable
steps: distinct4096-byte frames,65-byte retained slices, unchanged nested,
improper-list/struct values, and actual crypto hash, atomics and ETS usability
both directly and through closure-captured references. The admitted connection
continues after drain without increasing its funded total, then closes to zero.

StreamBridge.normalize_output/2 checks the historical logical max_output bound,
flattens iodata and always binary.copy's it. iodata_to_binary alone can return a
borrowed binary unchanged. The tail handoff to send_prepared/5 removes the
callback-result frame, original app and borrowed output from send ownership.
Actual Hell.Socket.send call traces now receive independent65/67-byte binaries
for borrowed binary and nested-iodata output; exact client bytes are preserved.
This is a boundary guarantee for Gaoxy's retained/send resources and bounded new
copy allocations. It does not purport to bound arbitrary allocations or NIF
memory made by user callback code before normalization, callback-owned external
ETS/process resources, or total BEAM RSS. No such broader heap guarantee is
inferred from these tests.

## Funded overlap and migration

With effective socket buffer B, D=100*B+18437 and
F=2*D+4*max_state+3*max_output. TwoD retain the current delivery/backing and the
next receive/copy obligation. FourS fund old/new application representations and
encoded/decoded normalization overlap. ThreeO fund the bounded logical output,
flattened representation and detached copy during normalization. At the
post-normalization send boundary, retained accounting is the full current input,
normalized app size and exact independent output bytes; the temporary remainder
still includes the next receive obligation. No normalization helper begins a
new callback, resets a watchdog, renews a drain deadline or bypasses canonical
growth checks. Existing32KiB tuning, explicit caps, max_active and forced drain
controls all pass with the larger honest floor.

For default B2048/S65536/O65507 the new floor is905139 bytes, replacing the
inherited643053 checkpoint. Explicit max_bytes is unchanged/undoubled and must
fund this floor; below-floor admission remains :byte_limit. Parent owns the
public design/guide/release-note formula update. This is a raw-stream migration
cost only: Service is unchanged in this round, native HTTP/UDP/QUIC profiles and
common Admission/Ledger code are untouched.

## Actual verification

Every runner receipt records HEAD, exact command, environment,682 input hashes,
raw-log hash, exit and terminal status. All source_changes arrays are empty.
Linux/NixOS, Elixir1.18.5/OTP28, ELIXIR_ERL_OPTIONS='+S 2:2'. No requirements or
peer environment was modified. No broad canonical all gate was run by worker.

- red-state-output: agreed RED24/10, exit2 before production edits.
- round12-raw: PASS24/0, `python3 scripts/check-tests.py
  apps/gaoxy/test/resource_budget_stream_network_test.exs --seed 0 --max-cases 1`.
- round12-scoped: PASS owned mix format --check-formatted, strict test compile,
  check-test-inventory.py, final raw30/0 with seed0/max-cases1, and mix test on
  native_stream_test.exs + stream_isolation_test.exs +
  resource_budget_admission_test.exs,72/0. Strict warnings remain enabled.
- Inventory PASS unit390/component321/protocol187,121 active/143 retained files;
 898 is expected manifest arithmetic, not an executed full-suite claim here.
- round12-release: PASS `MIX_ENV=prod mix compile --warnings-as-errors`,
  `mix release gaoxy --overwrite`, unchanged `python3 scripts/release-smoke.py`:
  all3 transports, initial traffic, original admitted TCP/TLS replies after
  SIGTERM listener-refusal barrier, VM exit0, UDP endpoint reuse/no leaks.
- Scoped `git diff --check`: PASS exit0.

Identity/decode failure fences were inspected in source; no node-identity
mutation or artificial codec override was run. Actual ordinary opaque-resource
usability is exercised by the passing network regression, not merely inferred
from ===. Prior model-capacity block and local-codec failures remain immutable.

## Frozen scope and handoff

Only StreamBridge, the existing raw network test file and the additive manifest
count16->30 changed. candidate-task.patch is relative to captured repair12
before snapshots, not the broad dirty Git diff. candidate-task-hashes.json and
candidate-input-hashes.json identify the exact candidate; handoff.json includes
its patch hash.679 other inputs remain unchanged, including Service, common
CORE/H1/H2/H3, protected release-smoke.py and retained test-inventory.json.
All prior release-drain7 artifacts remain untouched.

All owned commands and test/release runtimes are terminal; the original smoke
itself confirms VM exit and endpoint cleanup. Source/test/manifest writes and
shared build ownership are released to parent. No branch/worktree, Git mutation,
commit, push, publication or deployment was performed. Parent must obtain final
independent review, update migration docs and run fresh combined/delivery gates.
