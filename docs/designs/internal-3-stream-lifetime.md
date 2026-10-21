# Explicit streaming response lifetime

Issues: gsmlg-dev/gaoxy#3 and #7. Scope: native HTTP/1 and HTTP/2, direct Plug and
Phoenix listeners. Existing finite defaults and specialist-test exclusions stand.

## Selected contract

Add `http_limits.stream_timeout`, default `:request`, accepting `:request`,
`:infinity`, or a positive millisecond integer. It applies only when an endpoint
starts a streaming response with a completely consumed request body. The
ordinary `request_timeout` remains a positive finite deadline through headers,
upload, endpoint admission and work before the streaming transition.

`Gaoxy.HTTP.put_stream_timeout(conn, timeout)` selects the same policy per route
before `Plug.Conn.send_chunked/2`; `:request` can retain the ordinary deadline on
a listener whose streaming default is infinite. `Gaoxy.HTTP.poll_connection/2`
preserves the Plug connection while checking peer closure with a finite wait.
`Gaoxy.HTTP.abort/2` cancels the current response; returning from the Plug also
finishes it normally. Native endpoints use the corresponding Exchange operations.

The transition changes the existing admission lease, preserving its owner
monitor, active slot, byte accounting and finite instance drain. Infinite
lifetime cancels only its absolute request watchdog. Each physical H1 write and
each H2 write/owner operation keeps a finite timeout. H2 updates only the selected
stream's deadline; resets and cancellation preserve sibling streams.

Changing all request deadlines to infinity would also unbound uploads and is
rejected. Periodically renewing finite leases would hide lifetime semantics and
is rejected. HTTP/3 infinite streaming is outside this issue and must fail
explicitly if selected, while ordinary H3 behavior remains unchanged.

## Verification

Use real loopback H1 and independent Python h2 peers. Prove survival across
multiple finite request intervals; finite/infinite coexistence; header/body
protection; finite blocked writes; peer close; explicit cancellation; bounded
shutdown; and resource reclamation. Qualify a real Phoenix Endpoint using the
same configuration and route API. Preserve red/green logs and independent review.

## Generation capture cleanup compatibility

Checked generation resource captures retain the original finite request deadline.
After an explicit streaming transition, completion can occur beyond that deadline
plus its existing one-second cleanup allowance. A returned Exchange with a changed
deadline gives completion a fresh finite cleanup budget of at most one second.
The same allowance applies when an exception or a Plug rescue loses the latest
Exchange, but only after a bounded owner-only query confirms that the existing
admission lease deadline changed. Query the lease only when the old cleanup
allowance is exhausted, with a maximum 50ms owner call; unavailable or unchanged
evidence preserves the original cleanup failure. Acquisition and ordinary finite
request cleanup keep their original deadlines, and exceptions retain their class,
value and stack. No infinite resource-release call is introduced.

Deterministic Generation/Admission/resource-owner regressions hold extended
streams past the original request deadline plus one second, then prove pin release
while the request owner remains alive and lease reclamation after its exit.

## H2 initial worker reservation compatibility

The numeric native worker constructor includes the new Exchange.stream_timeout
field at its initial nil value. The existing independent complete-Exchange ETF
regression detected a 21-byte constructor undercharge; its exact equality
assertions remain unchanged. The numeric model now pays the complete term before
worker admission, including all copies already represented by its role table.
