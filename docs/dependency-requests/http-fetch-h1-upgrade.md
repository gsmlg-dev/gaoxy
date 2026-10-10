**Requesting repo:** gsmlg-opt/gaoxy on branch `codex/m2-native`

**Severity:** blocker

Gaoxy M2 includes WebSocket reverse-proxy tunnelling. The public `HTTP.fetch/2`
contract at revision `a78c0a35d84921678de40e8623eeeae71389c4ce` (0.17.1) cannot
provide a tunnel: `apps/http_core/lib/http/http1.ex`, lines 211-213, rejects 101
with `{:error, :unsupported_protocol_switch}`. No supported upgrade ownership
handoff or duplex tunnel API is exposed.

Expected: a documented public H1 upgrade/tunnel boundary suitable for a
WebSocket proxy (or a separately documented public WebSocket-client boundary).
It must validate the upstream handshake, preserve bytes following the response
head, provide finite read credit and bounded acknowledged writes in both
directions, enforce handshake/I/O/close deadlines, and clean up on either owner
or peer loss. Verified HTTPS/wss must retain CA/hostname/SNI policy. Do not
automatically retry uncertain operations or follow redirects.

Acceptance should use an independent WebSocket server and include coalesced
101+first-frame bytes, invalid handshake, bidirectional data/control/close,
slow-peer backpressure and cancellation. Gaoxy must use supported public APIs,
not raw access to HTTP Fetch's private owner or transport state.

This blocks Gaoxy's proxy WebSocket gate, independently of native Gaoxy WebSock
serving, which can proceed. No dependency source changes or workaround were
made.
