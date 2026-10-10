# OTP passive SSL receive qualification

Qualification uses the exact Nix development runtime, not the host's different
system Erlang: Erlang28.5.0.7, SSL11.6.0.6, Elixir1.18.5, default inet backend.
`ssl-buffer-probe.log` records exact source paths and SHA256 for
`tls_gen_connection.erl`, `ssl_gen_statem.erl`, `ssl_internal.hrl`, and
`ssl_record.hrl`. The probe uses only public OTP SSL APIs and fixture certificates.

Audited source behavior:

- `ssl_internal.hrl:55` defaults `INTERNAL_ACTIVE_N` to100.
- `tls_gen_connection.erl:675` onward stops passive socket reactivation while
  unread user data exists; `do_activate_socket` activates at mostN transport
  deliveries. `next_record` can concatenate consecutive TLS application records.
- `ssl_gen_statem.erl:1748` onward delivers the resulting binary in raw
  `recv(...,0)` mode; it is not a promise of one16KiB plaintext record per call.
- `ssl_record.hrl:143` allows TLS1.2 ciphertext up to16384+2048 bytes, plus the
  5byte record header; TLS1.3's256byte allowance is smaller.

With buffer/recbuf configured at most16384 and supported internal_active_n1..100,
the conservative delivery ceiling is `100*16384 + 18437 = 1656837`. The relay
reserves four such delivery/copy windows plus bounded writer/copy overhead before
TLS dial or application polling, for both termination and verified upstream TLS.
The one TLS direction and its carry fit the conservative owner reservation;
the opposite raw TCP direction also fits. Each admitted writer remains bounded
to one16KiB piece, and the pump retains finite carry without another receive
credit until the current delivery has been split and acknowledged.

The public passive SSL probe sent3145728bytes each direction with exact total
checks and confirmed peer shutdown. Its observed maximum recv0 delivery was
16384 on both endpoints. This empirical maximum does not replace the larger
source-derived bound. The focused relay burst regression separately asserts the
reservation before any payload write, then transfers3MiB through downstream
termination and verified upstream TLS. A host regression rejects0,101 and
noninteger internal_active_n rather than claiming qualification there.

Bounds exclude OTP/kernel socket metadata and are service admission accounting,
not an assertion about total VM memory. A different OTP implementation/backend
requires fresh source and runtime qualification. No private socket APIs or
dependency modifications are used.
