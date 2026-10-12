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
