# H2 request authority correctness repair

Date: 2026-10-20 (Asia/Shanghai)

R2 retains the existing pure header validation and connection stream-reset path.
An origin request must resolve a binary authority from `:authority` or the first
regular Host before calling the HTTP/1 authority parser. Missing authority
returns `{:error, :protocol_error, :request_target}`. The H2 admission owner
already maps that result to `RST_STREAM(PROTOCOL_ERROR)` without admitting an
endpoint worker for the malformed request.

Keep the existing authority grammar, Host fallback/equivalence, default ports,
and ordinary/extended CONNECT policy. No rescue is introduced. The shared IPv6
authority parser converts the untrusted binary to bytes rather than Unicode
codepoints before strict IPv6 validation. This rejects malformed UTF-8 through
the existing structured error instead of raising during conversion; valid IPv6
acceptance remains unchanged.

The independent Python h2 regression holds a valid sibling stream open while
sending a request without authority or Host. It requires reset code 1 for the
malformed stream, then completes the sibling and requires both PING acknowledgement
and a third successful request on the same connection. This is an ordinary
malformed-header check, not exceptional/disconnect or pressure qualification.
