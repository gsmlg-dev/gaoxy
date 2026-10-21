# Phoenix WebSocket transport options and LiveView composer capacity

Issues: gsmlg-dev/gaoxy#8 and #9. Implement directly on the existing `main`
candidate, preserving the #6 frame/message selection and service budget clamp.

Phoenix owns `:log` and `:code_reloader` transport policy and forwards its
validated options to the WebSock adapter. Add these two keys to Gaoxy's existing
application-owned option allowlist; do not turn them into wire engine settings
or relax unknown-option, compression, UTF-8 or numeric-limit validation. Prove
both keys directly and a real Phoenix `log: false` socket handshake and channel
exchange.

Issue #9 is another consumer of #6's independent message-default defect. Its
production repair is already the omitted message ceiling following Phoenix's
supported `max_frame_size`. Extend acceptance with an actual cookie-session
LiveView composer under a 16MiB service budget and a 2MiB frame ceiling. Submit
300KiB of double quotes as a normal URL-encoded form event, verify full persisted
bytes and the escaped rendered diff, reload the actual HTTP page, then rejoin
its rendered LiveView session and verify the same body. Exercise unfragmented
and fragmented input plus configured frame and aggregate oversize rejection.
Use a test-owned draft store; application/database integration remains the
requesting consumer's qualification. No new production persistence or listener
option is needed.
