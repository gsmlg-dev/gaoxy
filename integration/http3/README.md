# M4 independent peers

The initial host gate uses the public Gaoxy/Abyss QUIC APIs with the locked
`elixir_quic` and `ex_ssl` 0.21.3 packages. The independent peer is
`aioquic==1.2.0`, installed in the ignored consumer-local environment:

```sh
uv venv --python 3.12 integration/quic_consumer/.venv
uv pip install --python integration/quic_consumer/.venv/bin/python -r integration/http3/requirements.txt
nix develop
export MIX_ENV=test ERL_FLAGS='+S 2:2'
cd integration/quic_consumer
unbuffer mix deps.get --check-locked
unbuffer mix compile --warnings-as-errors
unbuffer mix test --warnings-as-errors
```

`GAOXY_QUIC_PYTHON` can select an explicit Python executable with this pinned
peer installed. By default the fixture uses `.venv/bin/python`; it performs no
implicit downloads while running tests. Record the resolved Python environment
and locked Erlang/Elixir versions with each evidence run.

The fixture negotiates `h3` and verifies its locally generated CA and `localhost`
certificate. It rejects a wrong CA, wrong hostname, and unsupported ALPN. It
checks peer/local bidi and uni byte streams, deliberately fragmented input,
directional FIN/reset/STOP, definitely blocked write admission followed by
byte-for-byte small-window progress, numeric IDs returned by public reads,
connection isolation, live listener removal, sibling listener exchange, and
rebinding the removed port with a new generation.

This gate exchanges generic QUIC bytes; it does not implement or qualify HTTP/3
frames merely because the negotiated ALPN is `h3`. The later H3 protocol gates
have their own fixture and acceptance evidence. A write receipt proves admission;
the independent peer separately checks received bytes. Shutdown proves bounded
local host cleanup, not graceful protocol drain. Local certificates are temporary
test material; never use them as operational certificates. The release-artifact
E2E workflow remains disabled.

Source-bound host results are recorded under
`docs/acceptance/evidence/m4/host/`.

## Minimal HTTP/3 server gate

From the worktree root in the locked Nix shell:

```sh
export MIX_ENV=test ERL_FLAGS='+S 2:2'
mix compile --warnings-as-errors
python integration/http3/run.py --gate minimal --evidence docs/acceptance/evidence/m4/minimal
```

The runner uses temporary loopback credentials and ephemeral listeners, runs the
pinned independent peer and removes its own children. Each run has an immutable
source-hashed directory; `latest.json` points to the latest result. Nonzero exit,
missing cases or changed source fails the gate. The fixture-only minimal profile
covers ordinary/control/malformed, exact stream/connection errors, slow-window
streaming, cancellation and bounded shutdown. It does not qualify arbitrary
production Endpoint/Plug execution; that is the shared integration gate.

FIN-completed malformed requests require exact RESET and sibling/no-late-DATA
checks. Additional open-direction variants require both exact RESET and STOP
callbacks. Diagnostic qlog proves the server's two exact wire frames even when
aioquic retires a FIN-completed stream before its STOP callback; see the retained
`peer-diagnostic` evidence. This distinction changes the observable callback
contract without dropping protocol-code or isolation requirements.

## Shared HTTP/3 endpoint and Plug gate

```sh
export MIX_ENV=test ERL_FLAGS='+S 2:2'
mix compile --warnings-as-errors
python integration/http3/run.py --gate shared --evidence docs/acceptance/evidence/m4/shared
```

This gate selects the public `plug:` service option and executes arbitrary Plug
code. Its separate fixture profile leaves the G1 minimal profile intact. The
independent peer decodes ordinary requests, HTTPS/H3 metadata, simultaneous
streams, fragmented streaming upload/response, ordered repeated request/response
trailers (including zero DATA and the public body-complete shortcut),
fixed-length streaming, file ranges, informational 103, exactly one
100-continue before upload, HEAD/204/205/304 and early response with unread body.
An endpoint worker kills itself while the receive direction remains open; the
peer requires exact RESET and STOP `0x102`, zero response DATA including after
sibling requests, no connection close and successful same-connection and
sibling-listener requests. Zero-DATA repeated trailers remain ordered, including
when an already-complete body lets the endpoint skip reading; the peer records
the initial completion flag without imposing scheduler timing.
A 1 MiB file uses 2 KiB stream and 4 KiB connection windows while both a sibling
stream and listener complete. Exact eventual bytes and definitely blocked host
admission are separately required.

Gaoxy-owned `[:gaoxy, :http3, :queue]` telemetry records actual application slot,
ingress and output high water without inspecting dependency-private QUIC state.
The fixture compares these observations and Admission retained high water to
the normalized application/service bounds; it separately confirms leases,
retained bytes, cleanup counters and ETS slots return to zero after peer exit.
These application reservations do not describe total QUIC engine or VM memory.

A third loopback listener gives a busy Plug an original 1,500 ms request
deadline. The Plug acquires a monitored request resource pin, signals its
dispatched barrier and waits only for a release token which is never sent.
The fixture kills only the callback owner, keeps Admission alive, and requires
observed worker DOWN, deleted ETS and zero leases/bytes/pins by original D plus
the existing 1,000 ms cleanup headroom. The independent peer then requires a
new connection on that listener and the existing sibling listener to complete
within the same bound. Owner DOWN alone is never a cleanup PASS.
The peer uses one absolute 2,500 ms deadline beginning before its busy request,
including runner coordination and both sibling exchanges, and rejects any late
DATA from the killed request. Abrupt owner death does not promise a graceful
wire CONNECTION_CLOSE; its observation is recorded separately. Explicit listener
stop still requires the existing exact wire close assertion. The original
wire-close wait failure is retained in the execution evidence.

The gate also reruns the complete G1 malformed-error, cancellation and bounded
listener/runtime shutdown contracts against production endpoint dispatch.
All child processes and ephemeral ports have finite cleanup; fixture resource
provider and temporary file/credentials are owned by this run.

The intended missing-dispatch failure is preserved under `shared-red/` at
`run-1791782903127521242`: a real GET closed and the fixture recorded
`{:binding_failed, {:error, :http3_endpoint_not_implemented}}`. The two FAIL
events identify that one request and its runtime diagnostic; zero cases passed.
Source hashes stayed unchanged and all owned processes exited. A later PASS
must retain that failure evidence. Shared acceptance does not qualify Phoenix,
browser, upstream-H3, standalone release, publication or deployment.

## Retained proxy matrix

`matrix.py --evidence <directory> --python <aioquic-python>` retains the
source-bound H3 proxy/independent-H1-origin checks. Phoenix document/static
checks use an aioquic peer with actual negotiated H3 and correlated server
receipts, retaining admission release and runtime stop/rebind assertions. Its
browser entrypoint has been removed. Ordinary Phoenix H1/H2/H3 document/static/
SSE, reload and shutdown checks use the direct-client
[unified Phoenix gate](../phoenix_native/README.md).
This change does not execute or certify the matrix's specialist cases.
Historical immutable results under `docs/acceptance/` remain unchanged.
