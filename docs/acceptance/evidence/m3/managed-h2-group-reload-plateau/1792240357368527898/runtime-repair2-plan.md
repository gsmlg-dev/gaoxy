# Group reload runtime repair2

The first complete scope remains FAIL104/8. Two independently reviewed,
separately executed diagnostics each reproduced one failure, with1 executed,
103 excluded, payload2/collector1, source401 stable and nonforced joined
custody. These diagnostics do not satisfy any qualification gate.

## Causes and smallest changes

The active diagnostic records the last request pending with its authentic child
at131ms. The source query includes both the original source and the derived
selected child because both have kind `:request` and an OLD transport handle.
Its singleton comparison cannot succeed while that child exists. At4982ms the
original Session receives `:opening_expired`; cancellation removes the child,
then the query succeeds at4985ms and the unchanged pending assertion fails.
Independent `active-diagnosis2.json` confirms the fixture defect.

Restore the accepted candidate2 source, removing diagnostic hooks and events.
In the source-only query exclude actual `derived` pins. Retain the original
singleton/source and pending-completion assertions. Add explicit checks that
the original selected child still exists with its original public pin and
source ref immediately before that pending assertion. Do not change any
response, monitor, timeout, deadline, cap or production module.

The idle diagnostic captures G2/pins2, both authentic baseline pins, with zero
tokens/probes/inflight, while both original T retirement inputs are held at
elapsed0ms. Store sampled later already has retired=[]; the snapshots are
sequential. Held T inputs do not synchronize Store's separate G release.
Wait for actual G/Store settlement before retaining every original capacity
snapshot/assertion. Anchor one absolute expiry to the earliest original hold
start+2000ms. Each state query uses only its remaining budget; poll through the
existing F.eventually helper with that absolute expiry. Both original holds,
charged OLD records, genuine fifth-T refusal, before/after exact equalities,
transaction/through-continue elapsed<2000ms and unconditional both continues
remain unchanged. No sleep, fresh relative window or physical-retirement wait.

## Verification

1. Preserve diagnosis/proposal/source/document bytes and cumulative counters.
   Review both actual causes; write the bounded patch against candidate2.
2. Root formats as preparation, freezes exact source/maps/documents and the
   original unfiltered two-file first scope under a new immutable name.
3. Independent complete source SPEC then CODE must pass before execution.
4. Run the complete104-test scope with all8 profiles, no filter/exclusion/skip,
   original deadlines and caps, and genuine source/process custody. A failure
   returns to diagnosis; it cannot be hidden by the filtered diagnostics.
5. After a real pass, perform full implementation SPEC→CODE and the unchanged
   prescribed fresh compile/format/syntax/scoped/consumer/peer/browser gates,
   factual document reviews and local commit custody. Rebind the accepted audit
   logic explicitly to final source/command bytes before its execution.

This is local Sol fixture repair2; production repairs remain0 for this slice.
Astra2/2 is exhausted and unchanged. Whole Task5/M3 and later bounded slices
remain open. Existing publication/deployment/Vault/production/certificate/
public-management/account/E2E restrictions remain in force.
