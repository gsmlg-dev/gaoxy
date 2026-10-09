# Native Phoenix browser and peer acceptance

From the repository root, resolve the root and fixture locks, then install the
isolated Python dependencies and a Chromium browser:

```sh
mix deps.get --check-locked
(cd examples/phoenix_native && mix deps.get --check-locked)
uv venv .audit/browser-venv
uv pip install --python .audit/browser-venv/bin/python -r integration/phoenix_native/requirements.txt
.audit/browser-venv/bin/python -m playwright install --with-deps chromium
.audit/browser-venv/bin/python integration/phoenix_native/run.py
```

The runner prefers system `chromium` when present, otherwise Playwright's
installed browser. It starts its own development fixture on ephemeral HTTP and
HTTPS ports, generates a local test CA/certificate, and cleans up the process.
No CA is installed globally. Outputs are under `.audit/m2-browser/`; the private
fixture key stays there and is never included in committed or CI artifacts.

The checks cover independent h11 framing, CA/hostname-verified HTTPS with a wrong
hostname negative, independent WebSocket Channel join/fragmentation/ping/close,
and Chromium page/static/LiveView interaction/upload/Channel/SSE/reconnect.
Development reload temporarily edits the fixture controller, confirms changed
and restored behavior through real requests, and restores its original bytes in
`finally`. Do not edit the fixture controller concurrently. Shutdown verifies a
1001/1012 WebSocket close, process exit and both listeners closed.

The JSON file records individually completed checks; a partial JSON after a
nonzero exit is **not** a passing run. The existing integration workflow runs
this gate on Linux. Local acceptance does not establish hosted CI or proxy
acceptance. See [the M2 record](../../docs/acceptance/m2.md).
