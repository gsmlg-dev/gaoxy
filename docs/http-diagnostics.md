# HTTP failure diagnostics

Since Gaoxy 0.16.5, `gaoxy_http` emits `[:gaoxy, :http, :failure]` once for each covered
failure: HTTP/1 head parsing and header/request timeouts, HTTP/2 semantic
header/body rejection and request/header-block timeouts, and endpoint failures. Attach a fast `:telemetry` handler to collect it. The
handler runs synchronously; perform persistence or network work elsewhere.
Successful requests and orderly transport closure alone do not emit failure
events. An endpoint returning a closed-transport error is classified as
`:peer_closed`.

Measurements are `count: 1` and `duration` in native monotonic time units from
lifecycle observation to failure. Convert with `System.convert_time_unit/3`.
Metadata contains only:

| Field | Contract |
| --- | --- |
| `protocol` | `:http1`, `:http2`, or `:unknown` during protocol detection |
| `stage` | `:headers`, `:request`, `:endpoint`, or `:protocol` |
| `reason` | A finite classification, described below |
| `status` | Successfully submitted final response header status, or `nil` |
| `response_committed` | Whether final response headers were successfully submitted to the transport |
| `request_id` | A server-generated reference for this lifecycle |
| `stream_id` | Valid HTTP/2 stream ID, or `nil` |

A successful transport write is not proof of delivery to a remote application.
Prepared, queued, failed or partially written response headers do not establish a
status. In particular, a Plug raising after a sent 201 reports 201, while one
raising after only `Plug.Conn.resp/3` reports the status of its actual error
response. A timeout that closes without a response reports `nil`, not an
invented 408. No response is added for instrumentation.

Header rejection reasons reuse the finite parser vocabulary: `:ambiguous_framing`,
`:authority`, `:authority_mismatch`, `:body_limit`, `:content_length`, `:expectation`, `:header`,
`:header_bytes_limit`, `:header_count_limit`, `:host`, `:http_version`,
`:line_ending`, `:method`, `:port`, `:request_line`, `:request_line_limit`,
`:request_target`, `:transfer_encoding`, and `:scheme_mismatch`. HTTP/2 semantic
header rejection uses `:malformed_request`. Deadline failures use
`:header_timeout` or `:request_timeout`. Endpoint failures use `:plug_exception`,
`:endpoint_error`, `:endpoint_throw`, `:endpoint_exit`, `:endpoint_failure`,
`:response_not_sent`, `:malformed_body`, `:peer_closed`, or `:response_failed`.
Unknown classifications on these instrumented paths are collapsed to
`:protocol_error`. HTTP/2 connection-level compression, flow-control and other
frame errors retain their existing behavior and are outside this event contract.

The event never includes request targets, query strings, headers, body bytes,
credentials, exception messages or terms, or stack traces. Reference IDs are
for diagnostic correlation; do not use them as metric labels. Reason, stage and
protocol are suitable bounded labels.

HTTP/1 header timeouts and the admission watchdog retain their existing close
and deadline behavior. The watchdog reads a bounded context from the existing
Registry before terminating a blocked request; it does not wait for the endpoint
to return. Context is replaced at each keep-alive request and removed on upgrade,
request completion or owner death. Registry availability follows the existing
service recovery policy; diagnostic observation during a Registry outage is best
effort, and cannot interrupt response writes or detach the watchdog observer.

HTTP/2 endpoint errors, request timeouts and semantic header rejections remain
stream-local. An incomplete header block's frame timeout remains a connection
protocol failure, as before, and is reported with its stream ID. Commitment is
recorded from the writer receipt, not from the queued response. HTTP/3 is not
covered by this event contract.
