# HTTP Fetch 0.19.0 / OTP 28.5.0.5 receive qualification

Scope: source qualification of bytes delivered to HTTP Fetch and its HTTP/1
parser, not kernel or OTP-internal buffer accounting. No maximum-observed-size
test is used as proof.

Installed runtime: OTP 28.5.0.5, ERTS 16.4.0.5, ssl 11.6.0.4,
kernel 10.6.3.3. Local Erlang sources under:

`/nix/store/5y0714j8czhkjbmjb6l6m46n5w5fyr6q-erlang-28.5.0.5/lib/erlang/lib/`

Exact upstream driver sources downloaded from erlang/otp tag OTP-28.5.0.5:

- `otp-source/inet_drv.c`: SHA256
  `8ba105d6536eefa0fc658d484b72b97fd733a18d7a1da76cac3846047e5c4534`
- `otp-source/packet_parser.c`: SHA256
  `b4b088b2412debf96b74a3bbea099618193dd145d011f5797efca3bfa4d9aae8`

## Socket configuration

Use public `socket_opts: [buffer: B, recbuf: B]`. Live default kernel backend
and persistent backend are both `inet`; Gaoxy config contains no backend,
internal_active_n, ktls or erl_dist overrides.

Do not add `inet_backend` to Fetch's socket_opts: TCP/SSL transports prepend
binary/packet/active options. OTP requires inet_backend to be the first option
in gen_tcp.connect; a later entry is not an admitted connect socket option.
Evidence: Fetch transport/tcp.ex:8-15; transport/ssl.ex:14-21;
kernel inet.erl:3116-3125,3314-3326.

## TCP bound

For packet raw, active once, inet backend, and explicit buffer B, each application
TCP data binary is at most B bytes:

- inet_drv.c:6959-6966 sets desc.bufsz and marks the buffer explicitly set.
- inet_drv.c:7321-7363 prevents recbuf from enlarging an explicitly set buffer.
- inet_drv.c:13121-13225 allocates desc.bufsz for zero-length/raw receives and
  never reads beyond that allocation.
- packet_parser.c:258-264 returns currently received bytes immediately for RAW.
- inet_drv.c:1551-1561 makes active once passive after one delivered message.

## OTP TLS conservative bound

TLS application messages are not limited to one TLS record. Consecutive decoded
application records are concatenated by tls_gen_connection.erl:734-827.
Use conservative per-delivered-binary cap `N * B + R`, where:

- N = SSL's internal active-N, default 100 (ssl_internal.hrl:55;
  tls_gen_connection_1_3.erl:447-454; ssl_config.erl:132-145).
- B = explicit native TCP buffer size above.
- R = 18,437, accounting for one pending maximum TLS 1.2 ciphertext record
  (18,432) and its five-byte header. TLS 1.3's limit is smaller.
  Evidence: ssl_record.hrl:142-144; tls_record.erl:533-570,704-709.

The read cycle cannot grow its complete-record queue across an unlimited number
of native receive messages: active-N admits N; a new native cycle is activated
with tls_cipher_texts empty; passive raw flow control waits while the plaintext
user queue is nonempty. Evidence: tls_gen_connection.erl:633-641,657-732.
The raw SSL consumer delivers one queued Bin; it does not concatenate all
queued plaintext binaries. Evidence: ssl_gen_statem.erl:1499-1517,1736-1751.
Active once returns passive after this delivery: ssl_gen_statem.erl:1790-1805.
Decrypting supported TLS 1.2/1.3 records removes encryption overhead and does
not expand through compression: tls_record.erl:199-244;
tls_record_1_3.erl:363-393.

For B = 65,536, the conservative TLS cap is 6,572,037 bytes.
For B = 8,192, the conservative TLS cap is 837,637 bytes.
Validate the qualified internal_active_n default if relying on these constants;
configured internal_active_n changes the bound. This qualification uses normal
OTP TLS transports with default full-handshake/non-kTLS/non-distribution options.
The tighter B + R cap for ordinary individual batches is not claimed globally
across every TLS control-state path.

## HTTP Fetch parser and response stream

The input batch cap must be combined with a prior incremental HTTP/1 carry
of at most 65,536 bytes (header/trailer carry; chunk-size line limit 8,192).
HTTP1.stream appends prior carry to the input batch, parses that batch into
events, and synchronously handles events before active-once rearm. With
decode_body false there is no decompression expansion.

Evidence: deps/http_core/lib/http/http1.ex:7-9,55-59,83-109,142-215;
deps/http_fetch/lib/http/socket_client.ex:1298-1334,1374-1381,1422-1427;
deps/http_fetch/lib/http/stream.ex:83-109,321-362.

Content-Length/EOF bodies can emit the entire bounded parser input slice;
chunked body events have their separate 65,536-byte cap. ACK retains one
cooperative stream chunk; the current parser's remaining events can still hold
the rest of the bounded batch. A Gaoxy reservation must cover these payload
representations and its own queue, not just the stream chunk.

## Alternate socket backend (secondary source evidence)

gen_tcp_socket maps public buffer to `{otp,rcvbuf}`. Raw active receive uses
socket.recv length zero/nowait and delivers the resulting data.
kernel gen_tcp_socket.erl:944-947,1336,2413-2443,2635-2647.
socket.erl:890-905,5096-5109 specifies integer BufSize as equivalent to
`{1,BufSize}`, bounding one receive operation by that allocation on select
systems. The primary qualification above uses inet; no alternative backend
runtime acceptance is claimed.

## Test correction

Removed ssl verify_none from the stalled-handshake completion test. No peer
certificate is sent, so default peer verification permits ClientHello and the
cancellation barrier. Focused test passed: one selected test, zero failures,
four excluded; log completion-tls-default-verification.log.
