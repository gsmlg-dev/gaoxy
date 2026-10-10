# OTP 28 TLS resource tracking request

Upstream [Bug #95](https://github.com/gsmlg-dev/http_fetch/issues/95), typed Bug
and labeled `internal request`. Managed OTP TLS qualification is blocked;
no local workaround.

**Requesting repo:** gsmlg-opt/gaoxy on branch `codex/m3-gateway`

**Severity:** blocker for M3 managed OTP TLS lifecycle, retained-resource
turnover and whole-generation retirement qualification. This reports a
confirmed source/returned-socket compatibility mismatch, not a measured leak
or an executed false-success retirement race. No local dependency patch or
private transport workaround is being introduced.

**Source/artifacts:** Installed coordinated HTTP packages 0.21.0, containing
tag `9813c126dc8b48055b9ee941c693fc27fa691489`; 196 shipped files and all seven
lock outer checksums rechecked. Qualification uses Elixir 1.18.5,
OTP 28.5.0.7 / ERTS 16.4.0.6 / SSL 11.6.0.6 on x86_64 Linux.

## Trigger and missing tracking

`apps/http_core/lib/http/transport/ssl.ex:24,31-34` tracks the raw TCP port,
then calls `HTTP.RequestLifecycle.track_tls/2` after public `:ssl.connect/3`
succeeds. In `apps/http_core/lib/http/request_lifecycle.ex:29-42`, its only
tracking clause matches `{:sslsocket, _, processes}` with a list. Any other
socket returns `:ok` without registering independent TLS processes.

The exact OTP source input's `lib/ssl/src/ssl_api.hrl:28-35` defines a
seven-field `sslsocket` record. `tls_socket.erl:169-176` constructs the
eight-element tuple containing `connection_handler` and `payload_sender`.
The real public connection probe below confirms that returned shape on the
qualification VM. It does not match the installed three-element clause.

That clause is the only `:tls` emission into the request lifecycle. Its
`:track_independent` handler and `track_scope` path therefore do not register
the receiver/sender with the managed scope. Scope resource maps and DOWN
barriers cannot retain unregistered processes. Raw TCP closure or a receiver's
close reply is not independently a sender DOWN barrier. Normal slot pruning
can omit these processes; raw-abort paths can close TCP before they terminate.
An arbitrary-repeat memory leak or false `:ok` retirement was not reproduced.

## Minimal public reproduction, executed

1. Start an independent Python TLS peer on `127.0.0.1:0` with a disposable CA
   and a CA-signed `localhost` certificate; advertise `h2`.
2. With finite deadlines, use public `:ssl.connect/3` with peer verification,
   the CA, SNI/hostname verification for `localhost` and `h2` ALPN.
3. Inspect only the public returned term's tag/arity and evaluate the old
   source predicate; do not inspect or suspend private HTTP/SSL processes:

   ```elixir
   tuple_size(socket) # 8
   match?({:sslsocket, _, processes} when is_list(processes), socket) # false
   ```

4. Public connection information confirms TLS 1.3 with AES-256-GCM. Close
   through public `:ssl.close/2`, then join every owned peer thread. The final
   diagnostic exits 0 with one verified connection, zero peer failures, zero
   remaining peer threads and 429 unchanged source hashes.

The first diagnostic omitted the peer's expected h2 ALPN: the socket shape was
confirmed, but the peer subsequently failed its ALPN assertion. That initial
result is preserved separately and is not counted as full peer qualification.
The final diagnostic adds ALPN and keeps verification and cleanup assertions.
No HTTP lifecycle race, runtime leak or full managed activation is claimed.

Gaoxy evidence: `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/`
contains `tls-socket-shape-repair1.json/.log` and before/after identities.

## Expected behavior and release gate

Provide a supported OTP-version-compatible way to independently track the
actual TLS receiver/sender resources, or an equivalent proven public barrier
that conservatively covers their termination. Do not silently accept an opaque
socket representation without the required evidence. Preserve policy
isolation, request deadlines, socket handoff, healthy sibling progress and
pending/unconfirmed completion semantics.

Add deterministic OTP 28 regressions for real verified TLS H1 and TLS H2:
normal completion and idle handoff, raw abort, setup/cancellation and whole
generation retirement. Prove connection capacity cannot recycle before all
included transport resources release. Publish containing coordinated artifacts
before Gaoxy enables this managed OTP TLS path. Source shape inspection alone
does not establish those lifecycle/runtime guarantees.
