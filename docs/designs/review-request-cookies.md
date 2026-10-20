# Split Cookie forwarding repair

Date: 2026-10-20, Asia/Shanghai.

`Gaoxy.Proxy.HTTP` prepares request fields once through `HTTP.Headers.request/1`
before choosing the dedicated or managed upstream session. Normalize split
Cookie fields here for HTTP/2 and HTTP/3 downstream requests: retain the first
field's location and concatenate values in encounter order with exactly `; `.
An already combined value remains unchanged. HTTP/1 inputs and other duplicate
fields retain their existing behavior; response Set-Cookie is independent.

Input preflight still bounds the original count, bytes and binary backing before
normalization. Hop filtering precedes joining, so a nominated field cannot be
restored. Final field count and serialized byte checks run after joining and
include the separators and generated forwarding identity fields. The same
semantically valid combined Cookie is used for all configured origin protocols;
no upstream-specific duplicate handling or HTTP Fetch change is necessary.

Pure cases cover empty/single/multiple/interleaved fields, H1 compatibility,
input preflight, exact output byte limits and unchanged response cookies. Real
H1 origin capture covers dedicated H2, managed H2 and dedicated H3 downstream
requests; both H1 modes share the same normalization boundary.
