# Health TLS close research1 — minimal reader-owned proposal

DONE source-only proposal. Root’s terminal full144/2/exit2 diagnostic confirms both identical stacks: `serve255 recv → ssl.recv1285 → ssl.read1140 → BrokenPipeError32` after raw SHUT_WR. The exact internal TLS message requiring a write remains UNKNOWN. The full diagnostic is joined/nonforced/source-stable; actual adopted raw waits0 and10 remain separate. Root runtime is now idle. Classification SHA256: `1baa2ebda8943e344164466dbe663e3963944ff796ed6f548e60c6bba8d38039`.

Keep the existing `write_half_close` operation and every original command field. Under RLock, flush genuine pending h2 output and queue the original command without ACK. The sole existing reader sees it between0.1s reads, drives public nonblocking unwrap with WANT_READ/WANT_WRITE+select under the existing5s command bound and180s peer bound, then performs public rawSHUT_WR, marks write_closed and emits the original ACK. Only then does the existing reader await actual raw recv EOF/reset under the original physical_termination5s gate. Reject any unexpected post-TLS payload before h2 parsing.

This prevents command-thread unwrap racing recv, and permits TLS close_notify while the transport can still write. ACK and unwrap completion remain distinct from physical EOF/reset. No BrokenPipe is swallowed, no terminal is synthesized, and deadlines/caps stay unchanged. All authentic HEAD/original completion/normal probe DOWN/allzero prerequisites remain. Group test and fixture observation points are unchanged; h2c retains its original raw-halfclose/ACK behavior.

Pinned Python ssl.py1340–1352 shows ordinary SSLSocket.shutdown clears the decoder; public unwrap clears it only after TLS shutdown succeeds. OpenSSL SSL_read136–148 permits internal writes. SSL_shutdown110–137 states TLS shutdown leaves TCP open. Those source semantics support this bounded proposal; they do not prove runtime success. Pending peer H2 control is TLS application data and may make unwrap fail, which must remain visible.

Eight exact substitutions, all peer-only, are in JSON. They were checked only by sequential in-memory source matching against peer SHA256 `3ef2ca19968c8e500d4d9dc64ddf4c9a81290e78c3d972a58ccfb2326b0428b8`. No repository mutation, proposal execution, import, parse/syntax check, compile/test/browser/network action or process interference occurred. Root must independently review before adoption. New application requests after enqueue are rejected before response construction; already-running control reads may finish normally.

## Reader-owned helper

```python
    def unwrap_health_tls(self, sock, deadline):
        # Only the original reader may change this connection's TLS state.
        sock.setblocking(False)
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("fixture health TLS shutdown deadline expired")
            try:
                return sock.unwrap()
            except ssl.SSLWantReadError:
                readers, writers = [sock], []
            except ssl.SSLWantWriteError:
                readers, writers = [], [sock]
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not any(select.select(readers, writers, [], remaining)[:2]):
                raise TimeoutError("fixture health TLS shutdown deadline expired")

```

## Source references

- `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py` lines64–72,189–220: Global RLock;180s peer lifetime;listen backlog8;accept limit8; per-connection reader threads.
- `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py` lines243–262,312–321: TLS reader recv is outside RLock; h2 parser/flush under lock; broad ssl.SSLError currently classified connection_reset; generic errors fail; finally closes.
- `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py` lines364–427: Current write_closed flush drops h2 control; command performs raw SHUT_WR under RLock while recv may be running.
- `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py` lines82–87: Current diagnostic addition emits bounded8-frame locations; no exact new runtime frame read by this assignment.
- `apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs` lines1491–1535: Real sole /health HEAD, ended upload, original completion :ok, normal Probe DOWN and restored probe/transport accounting precede rotation closure.
- `apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs` lines1113–1158,1218–1238: Existing closure assertions retain group ledgers, completed-stream GOAWAY, exact physical_termination and no new accepts/TLS/requests before forwarding.
- `apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs` lines121–159,581–594: Command ACK is separate from terminal physical event; EOF/reset only accepted; failure immediately flunks; original5000ms finite deadline.
- `/nix/store/xqnbm0vgqcq9b1b54c80qj9s0qhbwa08-python3-3.13.15/lib/python3.13/ssl.py` lines1129–1148,1278–1287: recv delegates to TLS read while SSL wrapper exists; existing suppress_ragged_eofs defaults can map TLS EOF to empty bytes; not proposed as new synthetic witness.
- `/nix/store/xqnbm0vgqcq9b1b54c80qj9s0qhbwa08-python3-3.13.15/lib/python3.13/ssl.py` lines1340–1352: SSLSocket.shutdown clears decoder before OS shutdown; unwrap calls TLS shutdown and clears wrapper only after successful return; exception leaves wrapper intact.
- `/nix/store/72qwwnvy0cqigflhvy15x4g0511cdsnh-openssl-3.6.3-man/share/man/man3/SSL_read.3ssl.gz` lines136–148 of decompressed man source: A TLS read may need to write non-application messages; WANT_READ/WANT_WRITE readiness is documented.
- `/nix/store/72qwwnvy0cqigflhvy15x4g0511cdsnh-openssl-3.6.3-man/share/man/man3/SSL_shutdown.3ssl.gz` lines110–137,153–182 of decompressed man source: close_notify is bidirectional TLS shutdown; TLS shutdown leaves TCP open; pending peer application data may prevent full shutdown.
- `/nix/store/72qwwnvy0cqigflhvy15x4g0511cdsnh-openssl-3.6.3-man/share/man/man7/openssl-threads.7ssl.gz` lines78–82,124–129 of decompressed man source: OpenSSL thread support does not make individual mutable objects simultaneously safe.
- `/nix/store/72qwwnvy0cqigflhvy15x4g0511cdsnh-openssl-3.6.3-man/share/man/man3/SSL_get_error.3ssl.gz` lines83–98 of decompressed man source: Error queue is thread-local; unexpected TCP EOF is an SSL error in OpenSSL3, not automatically ConnectionResetError.

`_ssl` RUNPATH names `/nix/store/14cfdqp8w2iw188vhjfaz2wg8pzbghp3-openssl-3.6.3/lib`; local3.6.3 manuals match that version. Source-only ELF inspection, no library invocation.

## Preconditions and limits

- Both exact diagnostic frames and terminal144/2/exit2 are confirmed; fully joined/nonforced/source-stable with actual adopted raw waits0 and10. Proposed repair remains unexecuted.
- The specific OpenSSL internal write/alert remains UNKNOWN. Manual SSL_read semantics establish internal writes are possible; the traceback locates the actual failure at SSL read, not Python flush.
- Conditional repair text requires independent root-owned bounded SPEC→CODE before adoption/runtime. It is neither implemented nor syntax-checked here. Existing failing rotated test is already a genuine witness; no assertion or observation-point changes are proposed.
- Public unwrap may fail if peer H2 control/TLS application data is pending or the remote never sends reciprocal close_notify. Preserve all such errors and exact current deadlines. Never discard raw encrypted bytes or swallow BrokenPipe/SSLEOFError.
- Command5s and subsequent physical_termination5s are the existing separate acknowledgement/physical gates. The internal unwrap deadline is fixed once at enqueue and capped by existing peer180s; no retry renews it.
- An already-running recv may complete before queue recognition; existing control is processed normally. New RequestReceived after enqueue fails before response construction; command writes are refused.
- Original external HEAD/original completion/normal Probe DOWN/allzero assertions remain authoritative. Local targets/responses/pending alone do not prove them.
- After successful unwrap raw recv is used only for actual TCP EOF/reset. Unexpected bytes are rejected before conn.receive_data. Local TLS errors are wrapped as failure rather than misclassified by the existing broad SSL-error/reset handler.
- Raw SHUT_WR occurs only after TLS decoder is no longer needed; it is a local action, not accepted EOF proof. Original physical_termination remains unchanged.
- Only peer source is proposed. Group helper, fixture helpers, original command name/fields, h2c behavior, accept8/180s, resource2-connection cap, B availability, native accounting and resource/source/custodian assertions are preserved. Browser fixture references to original op need no operation-name migration; any source binding/review remains root-owned.

## Input hashes

- `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py`: `3ef2ca19968c8e500d4d9dc64ddf4c9a81290e78c3d972a58ccfb2326b0428b8`
- `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs`: `15a35022058cdb93aed572aa6c8dd97a97e1fe66bcd449924a15aa8c1b4384ab`
- `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs`: `e89adb9c7cefa1c64385e9a90962ece819d7dfb492807b42e7b77644f042c33a`
- `/nix/store/xqnbm0vgqcq9b1b54c80qj9s0qhbwa08-python3-3.13.15/lib/python3.13/ssl.py`: `6deea04be4d1a5070e25f2f1523a417474cff6c28128b28dd944fb3ec3d01140`
- `/nix/store/72qwwnvy0cqigflhvy15x4g0511cdsnh-openssl-3.6.3-man/share/man/man3/SSL_read.3ssl.gz`: `2acbdb97faa49d88bf62be7b8e4f705509300b82417ff269d31a56446742572a`
- `/nix/store/72qwwnvy0cqigflhvy15x4g0511cdsnh-openssl-3.6.3-man/share/man/man3/SSL_shutdown.3ssl.gz`: `ac87470fc0d1acc66719d93b9ce1e3fc7b7022764a1b073147ecdfedb254d96b`
- `/nix/store/72qwwnvy0cqigflhvy15x4g0511cdsnh-openssl-3.6.3-man/share/man/man7/openssl-threads.7ssl.gz`: `e4cffabccc440f41d309a67858b6aa4d193c7e6580df4b0aef997860018fae0b`
- `/nix/store/72qwwnvy0cqigflhvy15x4g0511cdsnh-openssl-3.6.3-man/share/man/man3/SSL_get_error.3ssl.gz`: `c4bdbf00b41a5b17905d7cd72210245adeac894487f7fb039bf9fbd0c81cd95e`

Direct assignment; HEAD8f6b884524d81d8defa7c5081230b8ab635e8107. All own commands finished. New errors0/Sol repairs0/Astra repairs0; latest received counter-supplement20 root168/orch91/tool31/group59/runtimefailed5/Sol3/fixture3/Astra2/2 preserved. Readback and8 exact source anchors pass; tests and proposal syntax are NOT RUN.
