# Independent loopback H2 sustained load

This fixture sends valid ordinary HTTP/2 traffic only to `127.0.0.1`. It owns a
local Python HTTP/1 origin and a scoped Elixir gateway fixture. Profile, bounds,
coverage and teardown requirements are fixed in `docs/designs/m3-soak.md`.

Install `requirements.txt` in an isolated Python environment. Coordinate every
umbrella compile or fixture execution with the shared-worktree owner. Compile
the candidate in the same MIX_ENV first; this script uses `mix run --no-compile`.

```sh
python integration/h2_gateway/run.py --duration 10 --smoke \
  --evidence docs/acceptance/evidence/m3/h2-soak-smoke
python integration/h2_gateway/run.py \
  --evidence docs/acceptance/evidence/m3/h2-soak
```

The default interval is 600 seconds. `--smoke` reports UNQUALIFIED even when its
tooling checks pass. Result JSON records source identity, fixed ceilings, actual
samples, exact response/conservation counts, expected client resets, latency and
finite teardown. The gateway log preserves command responses and runtime output.
Run after freezing production files; candidate drift invalidates the run.

The fixture is a sustained-load gate only. Malformed-wire, TLS, browser, upstream
pool and other milestone acceptance evidence remain separate.
