# M4 committed endpoint error completion

H2 and H3 Stream currently extract the final Exchange from an endpoint's error
tuple, then finish it unconditionally. FramedResponse.finish on :chunked or a
completed fixed stream emits terminal DATA/FIN. A committed partial response
followed by an endpoint error can therefore look successfully complete on wire.
This contradicts the existing UP2 total-timeout contract: retain the 200 prefix,
never send success FIN, and cancel only the affected stream (H2 code0x8,
H3 code0x10C). This finding is independent of the ingress/progress repair.

Keep endpoint error reasons local and bounded. For an error result whose final
response is still open (neither :unset, :sent nor :bodyless_stream), do not finish
the response. H2 sends its owner a fixed error completion outcome; H3 stores a
fixed endpoint-failed outcome through Gaoxy's existing Operations.finish slot.
Their owners use the existing stream cancellation paths and original codes.
The error outcome must not embed endpoint terms, body bytes or the Exchange.

Preserve pre-head errors as ordinary 500 responses. Already fully sent responses,
including complete 502/504 followed by an error tuple, and bodyless responses
remain completed. Normal success still finishes its response. Internal worker
crashes and response-operation failure classifications retain existing behavior.
Do not add a new process, shared API, dependency patch or connection-wide close.

Real H2/H3 regressions must synchronize release of the endpoint error after an
independent peer has observed exact 200/prefix bytes without END_STREAM/FIN.
Then require the exact cancellation code, no successful terminal frame and a
successful sibling on the same connection. Verify pre-head500 and already sent
502/504 separately. The H3 body-marker barrier uses a public request DATA read;
it does not assume readiness from a sleep. All waits retain finite deadlines.

No live repair or acceptance is claimed by this design. Follow
[the execution delta](../plans/m4-framed-endpoint-errors.md).
