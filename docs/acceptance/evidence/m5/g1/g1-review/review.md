# M5 G1 independent review

Baseline: `codex/m5-websocket-over-h2-h3@4c6f08959e64303ab6ce6cf3280a1035a82c916f`.
Read-only production/test review; no Mix or protocol runtime commands run. Snapshot hashes are in snapshot.json. Unrelated work preserved.

## Specification review

NEEDS FIX: the shared stream driver cannot accept the existing native H3 transport identity. `apps/gaoxy_http/lib/gaoxy/http/websocket/stream.ex:28` matches only `{owner, id, token}`, whereas H3 retains `{owner, operations_table, key, token}`. A successful H3 handshake/init will crash at the first receive loop. Support both existing tuple shapes without changing native transport state. Add a normal deterministic H3-shaped stream driver case.

Other inspected Task1 contracts match the approved design: immutable wire CONNECT metadata, pure extended handshake and subprotocol validation, explicit compression refusal, ordinary body-read refusal, shared Frame/Message callbacks, asynchronous demand allowing application push, reservation continuity, finite admitted lifetime and owner opening before application init. Actual H2/H3 owner, window and ledger behavior remains G2/G3 work.

## Code review

NEEDS FIX for the same line28 transport-shape defect; no additional actionable findings in the assigned snapshot. Scoped `git diff --check` exited0. Reviewed existing evidence g1-green20/0, g1-final-green32/0, and g1-drain-red5/1; none is an independent rerun.

Scope note: g1-final-green ran the mixed websocket_network_test.exs file, including specialist cases. Preserve its actual32/0 outcome but do not rerun the whole file or add its specialist rows as new acceptance requirements. Parent fresh verification should select ordinary H1 cases51 and65 alongside the four planned unit files.

## Bounded Task2a independent review

SPEC PASS, then CODE PASS. Snapshot: http.ex `ee3e86feffb6ffb92d31b315a492a29b44302726c14b25594236d7f547139040`; phoenix_adapter.ex `8ddc8a62957ad4b8a6c9e250cdd9623bad339387db8dd266c6c73758328741dc`; http_protocol_defaults_test.exs `e4ecd6d29ce10afe73085ac5651ccbaa6bd331af8a640f25d4790889b3f6ae58`.

The HTTP facade defaults TLS to ordered H2/H1, TCP to H1; explicit selections remain. Phoenix delegates omitted protocols. The256MiB default is applied only when an HTTP-facade H2 service omits max_bytes; explicit limits/core-H1 defaults and validation remain. Tests exercise validating TLS H2, H1-only negotiation, absent ALPN fallback and explicit H1 override, plus configuration and budget contracts. The two existing rejection assertions retain explicit preconditions. Inspected g2a-green1 receipt11/0; parent fresh verification remains required.

No public protocol acceptance, publication or deployment claim. Review task repair counter0; inherited production/recovery counters unchanged. All review shell commands finished.
