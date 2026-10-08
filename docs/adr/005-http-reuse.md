# ADR 005: Native HTTP ownership and scoped codec reuse

M1 exports no HTTP server. M2 must own native request/response lifecycle and Plug
adapter execution, without a Bandit runtime backend or loopback Plug forwarding.
The inspected HTTP umbrella 0.17.0 contains role-neutral-looking frame/varint/
settings codecs, but `HTTP.HTTP2.Frame` is marked `@moduledoc false`; it is not
automatically a supported public dependency seam. Its shared owners are clients,
and package dependencies also activate TLS/QUIC. Reuse only after a public,
role-neutral boundary is verified or supplied upstream, with original licenses
and provenance. Do not couple to private client state or copy mature engines.

Preparation contracts are Plug v1.20.3 and Phoenix v1.8.15 at the audit commits.
Plug requires body, response, chunked/file, peer/version/upgrade and informational
semantics. Phoenix endpoint ownership must start exactly one listener. The pinned
WebSockAdapter dispatch recognizes specific Bandit/Cowboy/test adapters and raises
`Unknown adapter` for another module. Native Phoenix therefore requires a real
upstream registration/addition or reviewed pinned fork. Impersonating Bandit,
redefining dependency modules and monkey patches are excluded.
