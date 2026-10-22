# Native Phoenix client and peer acceptance

Resolve the root and fixture locks and install the independent client pins:

```sh
mix deps.get --check-locked
(cd examples/phoenix_native && PHOENIX_NATIVE_H3=1 mix deps.get --check-locked)
uv venv .audit/phoenix-clients
uv pip install --python .audit/phoenix-clients/bin/python -r integration/phoenix_native/requirements.txt
PHOENIX_NATIVE_H2=1 GAOXY_PHOENIX_EVIDENCE=.audit/workflow-split/phoenix \
  .audit/phoenix-clients/bin/python integration/phoenix_native/gate.py
```

The shell needs Mix, OpenSSL and curl. Both runners create loopback ephemeral
listeners and generate a temporary CA/certificate, without changing global trust.
Keep generated private keys out of committed and uploaded artifacts. Browser
runtimes and browser automation packages are not used.

`gate.py` requires overlapping curl and httpx H1 status, content-type and body
checks, independent h11 framing, CA/hostname-verified HTTPS and wrong-hostname
rejection, WebSocket Channel join/fragmentation/ping/close, static files, SSE,
development code reload/restoration and graceful shutdown. Set
`PHOENIX_NATIVE_H2=1` to require httpx's actual negotiated HTTP/2 response.
Each recorded protocol comes from the response or TLS negotiation. Static and
SSE checks use direct HTTP requests. No LiveView UI protocol is emulated.

The runner temporarily edits the fixture controller and restores its original
bytes in `finally`; do not edit that controller concurrently. Shutdown requires a
1001/1012 WebSocket close, successful process exit and closed listeners.
`manifest.json` records source hashes before/after, client versions, actual exit,
and the complete nonempty expected-check set. Partial results after a failed
runner remain failed. Evidence defaults to `.audit/phoenix-clients/`.

`unified.py` uses the Endpoint-owned H1/H2/H3 listeners with reload enabled.
Prepare the fixture with its optional H3 dependency before running it:

```sh
(cd examples/phoenix_native && \
  PHOENIX_NATIVE_H2=1 PHOENIX_NATIVE_H3=1 PHOENIX_NATIVE_RELOAD=1 \
  ELIXIR_ERL_OPTIONS='+S 2:2' mix compile --warnings-as-errors)
GAOXY_PHOENIX_EVIDENCE=.audit/workflow-split/unified \
  .audit/phoenix-clients/bin/python integration/phoenix_native/unified.py
```

The unified gate checks document/static/SSE responses through independent TLS
H1/H2 and aioquic H3 peers, including H3 discovery headers on H1/H2 responses.
Its native H2/H3 WebSocket peers join and ping the Phoenix Channel, complete
normal Close, and correlate their actual negotiated transport with server upgrade
receipts. It verifies reload/restoration over both H2 and H3, requires all eight
client/server checks, and stops the Endpoint with a finite cleanup deadline.
`report.json` retains per-check protocol receipts, source restoration and process
exit. Existing multiplexed peer modules remain shared with their separate
ordinary protocol runners.

Retired UI checks are page DOM assertions, LiveView mount/click/upload/reconnect,
JavaScript Channel/EventSource calls, page-error assertions, CDP checks and
screenshots. Their historical acceptance receipts are preserved under
`docs/acceptance/`; retirement does not relabel those outcomes. Ordinary Linux
integration belongs to `e2e.yml`. Local client results do not establish hosted CI,
publication or deployment acceptance.
