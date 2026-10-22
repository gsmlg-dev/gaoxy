# Issue 11: inclusive HTTP/1 polling boundary

`max_buffer_bytes` is an inclusive limit on retained HTTP/1 input. Polling an
exactly full buffer must still distinguish idle input, peer closure and actual
excess input. The current pre-read `>=` check rejects a valid complete pipeline.

Keep the supported Hell socket one-byte read and finite request/wait deadlines.
At the boundary, reserve the existing conservative `2 * buffer_size + 2` poll
floor before reading. A timeout returns `:pending`; a socket close returns its
error. An observed excess byte returns `:buffer_limit` without appending it.
The retained pipeline therefore never grows beyond the configured ceiling.
This is a terminal rejection: callers abort the returned connection on errors.
Below the boundary, retain each byte and return `:more` as before. Buffers already
above the limit reject immediately. HTTP/2 continues through its own transport.

Callers must retain every returned Plug connection, including pending/error
results. No application observation margin or private socket access is needed.
Admission may still reject the conservative copy/probe reservation; this does
not promise success when the listener's aggregate resource budget is exhausted.

Verification uses real TCP and public Plug/Gaoxy polling for inclusive pipeline
reuse, actual excess and closure, with input arriving after body EOF or together
with the first request/body. Focused exchange tests verify retained-byte charging,
pre-read admission, finite deadlines and bounded one-byte observation.
