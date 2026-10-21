# Verified TLS client certificates (#5)

Gaoxy's OTP TLS service accepts `verify`, `cacertfile`, and `fail_if_no_peer_cert`.
The existing server-only defaults remain unchanged. `verify: :verify_peer` requires
an explicit nonempty CA path; the missing-certificate policy defaults to OTP's
optional presence behavior. A supplied certificate must always validate. CA and
presence options without peer verification fail validation rather than imply
verification that will not occur.

Forward the same TLS keys through Phoenix HTTPS, ListenerSet, the HTTP provider,
and Hell's public OTP transport options. Existing HTTP exchange peer data already
comes from the TLS socket; no header or private process API supplies identity.
HTTP/3 and proxy behavior remain outside this request.

Use a real Phoenix Endpoint and temporary test CA/client certificates to qualify
HTTP and WebSocket peer data with TLS 1.2 and 1.3. Test absent, trusted, and
untrusted certificates on the same optional-presence listener, then mandatory
presence separately. No operational certificates or downstream deployment change.
