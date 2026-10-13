# M4 Session fragment-size task delta

> Sol coordinator owns independent review and live acceptance. The bounded Astra
> recovery worker owns only the four upstream harness files, these two new
> amendment documents and new receipts. No live execution before frozen-source
> independent Sol review PASS.

**Goal:** qualify the supported 8 KiB Session fragment configuration against the
unchanged 1 MiB/16 KiB tiny-peer-window acceptance case.

**Design:** [fragment-size amendment](../designs/m4-session-frame-fragmentation.md).
Apply as a delta to [the Session plan](m4-public-session-upstream.md) and
[consumer-affinity delta](m4-public-session-consumer-affinity.md); preserve all
remaining UP0/UP1/UP2/standalone/browser/consumer gates.

- [ ] Change only the real Session construction option in
  `integration/http3/upstream/session_probe.exs` to `max_frame: 8_192`. Keep its
  16,384-byte application calls, 64-chunk 1 MiB case and all deadlines unchanged.
  Mark the callsite with `TODO(upstream)` and `WORKAROUND(upstream)` for
  `gsmlg-dev/http_fetch#105` (severity `needed`).
- [ ] In the existing named `blocked_suspend_poll_resume` double row, use public
  `Session.new(max_frame: 8_192)`, Qpack/Frame codecs and scripted Transport calls
  to assert exact 8,192/8,192/5 DATA fragments, byte-for-byte concatenation and
  only final FIN. Exercise success, definite block on fragment two and unknown
  admission on fragment two: first prefix never replayed, unknown resolved only
  through operation status, original operation resumed without a fresh send_data.
- [ ] Preserve the existing paused-control repair and all 50 counted names.
  Update only current-run counters in `run.py`: Sol 2 unsuccessful 2, Astra 2
  in progress, preceding unsuccessful Astra 1. Explain the configuration and
  superseded blocker classification in the owned README/new receipt.
- [ ] Keep `origin.py` byte-for-byte unchanged. Preserve all 17 network, two
  policy and 31 double row classifications, 1 MiB hash and exact FIN/request
  counts, peer windows, cancellation/cleanup and sibling requirements.
- [ ] Compile definitions only, then check formatting under the exclusive lease:

  ```sh
  nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' GAOXY_SESSION_PROBE_LOAD_ONLY=1 mix run --no-compile --no-start integration/http3/upstream/session_probe.exs
  nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' mix format --check-formatted integration/http3/upstream/session_probe.exs
  ```

- [ ] Record source/lock/spec hashes, exact task diff, Python AST/local-link
  checks and actual command results. No doubles or live gate execution by this
  worker before review. Freeze the candidate and return ownership to root.
- [ ] Independent Sol specification and code review of the amendment plus exact
  sources; root then executes the original `--gate session-contract` command.
  All required rows and original finite deadlines must pass. Runtime failure
  remains a failure; no third Astra repair is authorized. Preserve earlier failed
  run and missing per-request cleanup evidence without retroactive PASS.
- [ ] On full UP0 qualification/review, the Sol UP1 implementer uses this same
  Session option while preserving the application 16 KiB ceiling and every
  existing integration contract. No UP1 activation follows from static checks.

The earlier diagnosis-only receipt consumed no second repair round. First
failure-directed source edit plus validation for this candidate consumes Astra
round 2, retaining Astra1 unsuccessful 1 and all historical counters. No budget
reset or additional user approval is implied.
