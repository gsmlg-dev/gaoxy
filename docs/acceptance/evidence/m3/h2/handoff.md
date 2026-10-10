# H2 implementation handoff

Task `/root/upstream_cleanup` native H2 P0–P3. Direct implementation assignment. Status BLOCKED_HANDOFF: worker developer hard maximum of two repair-and-validation rounds reached; parent requested third round under local AGENTS interpretation, but worker cannot override governing developer limit. This is a routing/budget conflict, not an upstream/environment/product blocker or technical impasse. No Astra gate honestly established (only one unsuccessful repair round). Ownership of all previously worker-owned HTTP/H2/facade/proxy compatibility files is released to parent. No own command remains running.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch `codex/m3-gateway`; current intentional parent baseline `22b76e8051ddaf09e36797cb781b9b119870a9d4`, original implementation baseline `71f1b02032b440c5626263bd48aa4f622260e70a`. Preserve parent Generation/config/policy/relay changes and unrelated files. No worker commit/push.

## Retain completed work

- HPAX1.1.0 manifest/lock, artifact/public API/expansion evidence in hpax-qualification.md.
- Native pure Frame/Settings/Limits/Headers.
- Neutral Response facade, Exchange semantic body/trailer/metadata/abort APIs and route/protocol reservation fields; Plug/Router/Proxy existing callsites migrated.
- Explicit TCP prior knowledge and opt-in TLS ALPN options; insufficient-budget validation before bind; Phoenix forwards protocol options.
- HTTP task supervisor, admitted PID-bound endpoint workers; isolated admitted writer using public Socket.send; owner frame/HPACK/window state, pending authenticated calls, settings/preface/partial timers, stream cancellation, GOAWAY/drain, coalesced receive-credit updates, round-robin outgoing DATA.
- Native TCP tests already pass concurrency/body/trailers/zero-window sibling/reset worker/continuation scope. RFC Huffman/dynamic and malformed codec tests pass. H1 compatibility tests in latest60-test check pass.

## Exact immediate repair

`apps/gaoxy_http/lib/gaoxy/http/http2/settings.ex` currently has `defp setting(_, 8, _), do: {:error, :protocol_error}`. Independent Python h2 defaults emit SETTINGS `{1:4096,2:1,4:65535,5:16384,8:0,3:100,6:65536}`. That initial setting8=0 makes the owner send GOAWAY and close before any requests. Remove unsupported-extension rejection so unknown setting8 is ignored; retain `:protocol` pseudoheader rejection and no extended CONNECT advertisement/support. Add a pure raw-peer SETTINGS regression. Do not weaken90KB/verifiedTLS independent peer assertions.

Pinned independent Python tooling installed in `.audit/h2peer`; reproducible requirements in `apps/gaoxy_http/test/support/h2-requirements.txt`. The new network test asserts tooling exists; clean CI must provision the pinned peer (no skip). The support peer validates verifiedTLS ALPN, Huffman/dynamic state,90KB request/response flow control, concurrent streams, HEAD and trailers.

Canonical test command from apps/gaoxy_http:

`nix develop --command bash -c "export ERL_FLAGS='+S 2:2'; export MIX_ENV=test; unbuffer mix test test/http2_codec_test.exs test/http2_protocol_test.exs test/http2_network_test.exs test/http2_facade_test.exs test/http_contract_test.exs test/http_network_test.exs test/http_poll_test.exs test/phoenix_adapter_test.exs"`

## Actual validation and cumulative repairs

- engine-red.log:10expectedred failures before implementation, exit2; not repair rounds.
- protocol-green.log:4tests0failures exit0.
- facade-green-scoped.log:26tests0failures exit0.
- engine-initial.log:12tests4failures from missing HTTP2.Transport response delegates, exit2.
- engine-repair-1-actual.log:12tests0failures exit0; repair1successful.
- engine-repair-1.log: accidental no-edit duplicate run due wrong relative path; no edit happened, unchanged4failures, not a repair round.
- checkpoint-p0-p2.log:60tests2failures (malformedTLS validation shape and independentpeerBrokenPipe).
- checkpoint-repair-2.log:60tests1failure exit2; repair2 corrected TLS validation shape and batched WINDOW_UPDATE credits but independentpeer startup remains broken. Subsequent read-only diagnosis identified setting8 as the precise cause.
- Cumulative Sol repair attempts2, unsuccessful1; received Astra repairs0. Further source edits stopped. Do not reset counters.

## Required further work / risks (not acceptance)

P0 TLS cross-process writer proof has NOT RUN because independent test fails its first TCP case. P1 proxy guardian suite has NOT RUN in this worker's updated checkpoint. P2 independentpeer remains FAIL. P3 H2→dedicatedH1 proxy/guardian integration, early upstream response, uploads/request trailers, reset/disconnect during response, GOAWAY/drain/pause, writer/owner crashes, stale operations, H2reload across immutable snapshots, malformedframe scope matrix are NOT RUN and need meaningful regressions. No full nativeH2 completion claim is warranted.

Read-only inspection also identifies follow-up checks:

- Closed-stream HEADERS currently reset before HPACK decode; either decode to maintain compression state with RFC-correct scope or close the connection. Never continue with a desynchronized decoder. Verify rejected/refused header blocks via dynamic-table traffic.
- Initial HEADERS without END_HEADERS needs immediate compressed-block bound (continuation path checks later blocks; single-frame ending path checks decode).
- H2 read-step guard allows1..16384 but normalize accepts max_read_chunk larger; the transport clamps to HTTPmax rather than min16384. Preserve proxy upload credits with a16KB clamp.
- Invalid `protocols` on TLS can reach Enum.map function-clause before Options.normalize. Strict service validation must return an error.
- Ensure bodyless streaming finish, exact16KB iodata boundaries, file framing, informational responses and duplicate headers get dual-protocol façade tests.
- Coalesced credit update is required to keep4byte credited consumer reads from generating unbounded outbound control frames; preserve it while fixingsetting8.
- Stream discard clears starting id; reset now invokes start_next, preserving one pending admitted-worker start. Verify reset during admission does not wedge future streams.

## Independent root review

Worker read-only Generation/config review is `docs/acceptance/evidence/m3/generation-review.md`: G1 oversized activation payload crosses mailbox before bounds, G2 invalid static framing survives activation. Parent acknowledged and is repairing; worker did not edit parent-owned code. Re-review after fresh evidence remains necessary.
