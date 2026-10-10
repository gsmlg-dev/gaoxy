# OTP receive bound for HTTP Fetch 0.19.0

Qualified runtime: OTP 28.5.0.5 / ERTS 16.4.0.5, kernel 10.6.3.3,
ssl 11.6.0.4. Local Erlang sources:
`/nix/store/5y0714j8czhkjbmjb6l6m46n5w5fyr6q-erlang-28.5.0.5/lib/erlang/lib/`.
Fetch/Core/Runtime installed sources match HTTP Fetch release
`v0.19.0`, commit `09b1686fb2ce529a17287d97801107c53b1ac57c`;
see package-source-hashes.json.

Exact driver source: erlang/otp tag `OTP-28.5.0.5`.

- otp-source/inet_drv.c SHA256:
  `8ba105d6536eefa0fc658d484b72b97fd733a18d7a1da76cac3846047e5c4534`
- otp-source/packet_parser.c SHA256:
  `b4b088b2412debf96b74a3bbea099618193dd145d011f5797efca3bfa4d9aae8`

Public socket_opts `[buffer: 8192, recbuf: 8192]` bounds inet/raw TCP deliveries
to B = 8,192 bytes. Explicit buffer sets desc.bufsz and prevents recbuf inflation
(inet_drv.c:6959-6966,7321-7363). Raw zero-length receive allocates/reads at most
B and immediately delivers received bytes (inet_drv.c:13121-13225;
packet_parser.c:258-264). Active once returns passive after one message
(inet_drv.c:1551-1561).

OTP TLS concatenates consecutive decoded records (tls_gen_connection.erl:
734-827), so use conservative delivered-binary cap `N*B+R`. N is internal
active-N(default100); new native read cycles require an empty ciphertext queue,
and passive raw flow control waits while queued plaintext remains
(tls_gen_connection.erl:633-641,657-732). Raw TLS consumption returns one queued
Bin, not all queued plaintext (ssl_gen_statem.erl:1499-1517,1736-1751), and
active once returns passive (1790-1805). TLS decryption removes overhead and
does not decompress (tls_record.erl:199-244; tls_record_1_3.erl:363-393).
R = 18,437 bounds one incomplete maximum TLS1.2 ciphertext plus its five-byte
header; TLS1.3 is smaller (ssl_record.hrl:142-144; tls_record.erl:533-570,704-709).
For N<=100 and B=8192, delivered SSL binary <=837,637 bytes.

Public configuration checks, without global mutations:

- `Application.get_env(:kernel, :inet_backend, :inet) == :inet`
- `Application.get_env(:ssl, :internal_active_n, 100)` is an integer in 1..100.

Default N evidence: ssl_internal.hrl:55; TLS1.3 tls_gen_connection_1_3.erl:
447-454; TLS1.2 ssl_config.erl:132-145. Backend selection:
kernel inet.erl:3314-3326. This assumes stable startup-qualified kernel config;
OTP caches backend selection at kernel initialization. Current application and
cached default backend were both verified inet. Gaoxy config has no overrides.
Do not pass inet_backend through Fetch socket_opts: Fetch prepends binary/
packet/active options, whereas OTP requires inet_backend first and rejects it
as an ordinary socket option (transport/tcp.ex:8-15; transport/ssl.ex:14-21;
kernel inet.erl:3116-3125,3314-3326).

Qualification also requires direct H1/nonreuse/manual/raw-body/OTP TLS,
packet raw, active once, normal full handshake, non-kTLS/non-distribution, and
cooperative ACK consumption. HTTP carry <=65,536 must be added to the delivered
batch bound (http_core HTTP1:7-9,55-59,83-109,142-215). Parser events are handled
synchronously before rearm (http_fetch SocketClient:1298-1334,1374-1381,
1422-1427). Reservation must include input/copy/current remaining events and
Gaoxy-owned queues. Kernel and OTP-internal buffers are outside this ledger.
No maximum-observed-size test substitutes for this source qualification.

Secondary socket backend source: gen_tcp_socket.erl:1336,2413-2443,2635-2647
maps buffer to OTP rcvbuf and delivers raw socket.recv(0,nowait) data;
socket.erl:890-905,5096-5109 defines integer BufSize as {1,BufSize} on select
systems. Alternate-backend runtime acceptance is not claimed here.

Reproducible driver sources (snapshots stayed in `.audit`, not vendored here):

- [inet_drv.c at OTP-28.5.0.5](https://github.com/erlang/otp/blob/OTP-28.5.0.5/erts/emulator/drivers/common/inet_drv.c)
- [packet_parser.c at OTP-28.5.0.5](https://github.com/erlang/otp/blob/OTP-28.5.0.5/erts/emulator/beam/packet_parser.c)
- [SSL sources at the same tag](https://github.com/erlang/otp/tree/OTP-28.5.0.5/lib/ssl/src)
