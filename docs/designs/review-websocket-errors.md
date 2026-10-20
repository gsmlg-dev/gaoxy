# WebSocket proxy error responses across HTTP versions

The WebSocket proxy accepts HTTP/1.1 upgrades. Its handshake validator already
rejects ordinary HTTP/2 and HTTP/3 requests, including extended CONNECT, before
creating an upstream session. The rejection currently uses the HTTP/1 response
backend, which attempts to send through a socket absent from framed exchanges.

Use `Gaoxy.HTTP.Response` for the proxy's error responses. It selects the native
response backend from the exchange and retains HTTP/1 behavior. Keep the existing
handshake validation and status codes; this change adds no WebSocket proxy
transport support.

Acceptance requires real HTTP/2 and HTTP/3 clients to receive an empty 400 for
ordinary GET and unsupported WebSocket CONNECT requests on this route, then
receive a successful sibling response on the same connection. An unopened local
upstream listener and an empty session supervisor verify rejection precedes
upstream creation. Existing HTTP/1 upgrade and upstream-error tests must pass.
