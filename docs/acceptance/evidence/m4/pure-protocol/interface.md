# Pure M4 protocol implementation receipt

Worktree `.trees/m4-http3`, branch `codex/m4-http3`, baseline
`78de9d0f3bba5a4662717359438eb3d0853a79b4`. Source hashes, raw logs and
verification results are in `summary.json`. This is pure-parser evidence;
live H3, browser and proxy acceptance remain NOT RUN.

## Connection integration

- `Protocol.new(%{http_limits: normalized_http, h3_limits: normalized_h3})`
  returns `{:ok, state}` with the public server `Control` in `state.control`.
  The owner can send `Control.local_payload(state.control)` on its separately
  tracked local control stream. Only peer streams enter this parser.
- `Protocol.open(state, opaque_key, :bidi | :uni)`, `feed(state, key, bytes)`,
  `fin(state, key)` and `reset(state, key)` return `{:ok, next, actions}` or
  `{:error, :stream | :connection, numeric_code, reason, next}`.
- Actions, in received order: `{:headers, key, request}`, `{:data, key, bytes}`,
  `{:trailers, key, fields}`, `{:complete, key}`, `{:cancelled, key}`,
  `{:discard, key}`, `{:settings, settings}`, `{:goaway, push_id}`.
- `feed` retains bounded input when the byte/transition quantum expires. Drain
  empty-input continuations before applying received FIN. A frame with zero
  remaining payload can also need an empty continuation. Stop draining when
  no progress is possible; `fin` then distinguishes incomplete framing from a
  complete request. Bound continuation scheduling in the connection owner.
- The owner reserves body credit before supplying bytes; pure parsing does
  not implement admission or QUIC I/O. Parsed DATA is incremental. Successful
  request FIN frees the parser slot while the owner retains response/worker
  state until application completion. The owner separately bounds active
  endpoint tasks and request states.
- Stream-scoped errors remove that parser slot; siblings remain. Connection
  errors retain diagnostic state for connection close. Critical FIN/reset
  closes the connection with `0x104`. Request reset emits `:cancelled` and frees
  its parser slot. Handle STOP_SENDING directionally in the I/O owner.
- Unknown uni types emit `:discard` and free their parser slot. The owner must
  stop/discard that receive direction and avoid reopening a parser for it.

`Headers.request(fields, http_limits)` returns a shared `Gaoxy.HTTP.Request`
with `version: :"HTTP/3"`, `scheme: :https`, regular fields, escaped target/path,
and `body: {:length, n}` or `:chunked` as the existing facade sentinel for an
unknown streaming length. CONNECT is parsed for the owner's explicit 501
policy. Actual peer/local and unavailable TLS metadata are set by the owner.
Matching regular Host fields on CONNECT are accepted; disagreement or duplicate
Host fields remain message errors. A valid advertised Content-Length exceeding
the configured body bound yields `0x107`, while invalid syntax yields `0x10e`.
`Headers.decode(block, max_fields)` distinguishes semantic `0x10e`, resource
`0x107`, and compression connection `0x200` failures. `Headers.trailers/2`
returns `:ok` or an H3 error tuple. `response/3` preserves the shared response
validator contract, `:ok | {:error, :invalid_response_headers}`.

## Retained application state

Header/control payloads use compact binaries bounded before accumulation.
Unknown frames retain length counters, not their declared payload. Unclassified
uni type carry after a feed is at most seven bytes; uni parser slots are bounded
by `max_streams + 3`. Critical carry can remain up to `max_buffer_bytes` per
stream after a bounded turn. Control additionally retains at most
`min(max_header_block, 65536)` bytes of payload and its decoded peer SETTINGS.
An explicit uni reservation covers three critical carry buffers, five compressed
control-header bounds including decoded SETTINGS, and finite slot metadata.
These are local parser reservations, not exact VM/native memory accounting.

The deterministic single-byte header-fragmentation test first observed serialized
parser state 192560 bytes against the 81920-byte local reservation. Compact
binary storage passes the same assertion. Missing authority previously reached
`:binary.split(nil, ":")`; the guarded conversion now returns a stream error.
Second SETTINGS now uses `H3_FRAME_UNEXPECTED` (`0x105`), while duplicate setting
identifiers and invalid SETTINGS payloads remain `H3_SETTINGS_ERROR` (`0x109`).
Zero-capacity decoder Stream Cancellation is accepted and ignored with bounded
six-bit integer parsing and a QUIC stream identifier bound below `2^62`.
Section Acknowledgement and Insert Count Increment without dynamic references
or inserts remain decoder errors (`0x202`). Fragmented legal cancellation,
malformed/out-of-range identifiers and sibling request completion are tested.

## Verification

Expected initial missing-feature red: 37 tests, 37 failures. Initial implementation
green: 37 tests, 0 failures. Three deterministic review regressions were reproduced
before repair; all raw runs are retained, including a corrected test-edit mistake.
Repair round 1 and fresh final verification: 47 tests, 0 failures; exact changed
Elixir files format-check and compilation with warnings-as-errors both exit 0.
Independent review then identified legal decoder cancellation, regular Host on
CONNECT, and the advertised Content-Length resource classification. Their
fail-first suite ran 52 tests with 4 failures; repair round 2 passed 52 tests
with 0 failures plus fresh format-check and strict compilation. The corrected
authored cancellation vector (`0x40`) is legal; malformed acknowledgement,
increment, identifier overflow and out-of-range vectors remain asserted.
Sol repairs 2, unsuccessful repairs 0, Astra recovery 0. Independent specification
and code re-review by `m4_dependency_audit` passed with no unresolved findings;
the parent performs the combined fresh stage verification before committing.
