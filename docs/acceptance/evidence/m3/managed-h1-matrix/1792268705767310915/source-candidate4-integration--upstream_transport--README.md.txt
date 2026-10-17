# Managed-H1 upstream matrix

Compile the worktree first in its qualified Nix/Mix environment, then run:

```sh
/tmp/gaoxy-m3-h2-soak-venv/bin/python integration/upstream_transport/run.py
```

The qualified interpreter must already contain `h2`, `hpack` and `hyperframe`.
The runner installs nothing and starts exactly one
`mix run --no-compile --no-start integration/upstream_transport/fixture.exs`
process. It never calls `mix test` or compiles recursively. `--case` selects one
exact case ID from the explicit registry for diagnosis; the default executes 16.

The registry is fixed/group × native cleartext H1/prior-knowledge H2 downstream
× TCP/TLS-H1 upstream, with `temporal_and_declared_trailers` and
`representation_and_reuse` per row. ExUnit's
`upstream_transport_h1_matrix_test.exs` uses the same Python choreography in
attached mode and the same shared Elixir fixture. Existing H2-upstream suites
remain separate coverage.

Each JSON `case_result` retains actual upstream accepted-connection/request IDs,
ordered fields/trailers, binary bodies and SHA256, observed temporal event order,
original pending completion/binding identities, final accounting, normal joins,
interpreter/package identity and source hashes. Bodyless H1 framing also uses one
persistent downstream socket for HEAD → 204 → healthy GET, preserving leftovers.
The gzip comparison is against exact compressed bytes. Group health HEAD is
explicitly separate from application requests.

Bounds are absolute five-second event barriers capped by the remaining
twenty-second case deadline (including final accepted-connection identity),
ten-second startup/shutdown and a finite 340-second registry budget. Missing,
duplicate or wrong case identities, failed peers, timeout, changed accepted
upstream connection or forced cleanup cause failure. `matrix_finished` reports
actual executed/failed counts. Exit zero requires all selected cases, normal
owned-resource joins and the fixture's explicit `finished` receipt. The runner
terminates only its own subprocesses in `finally`; forced cleanup cannot PASS.
An outer client registry covers partial case startup; its exception-isolated
sweep shares one ten-second shutdown deadline. Attached mode establishes and
acknowledges an owned driver process group before starting a case and reports
client joins before its case result. The ExUnit adapter requires that receipt
and checks group exit, or terminates/checks that owned group on failure.

The fixture JSON-line adapter also exposes `start`, `event`, `upstream`,
`pending`, `clean`, `stop`, then `finish`. Start accepts a `row` object with
`mount`, `downstream`, `upstream`; optional `downstream_tls: true` supports
separate local browser checks without changing this cleartext matrix. Ready
includes listener port and URL; TLS rows include only public certificate paths
and their digest. All certificates come from the existing test fixture generator.

This runner does not qualify the combined slow-peer/queue/peak/sibling profile,
sole H1 disconnect during blocked upload, production, deployment, publication or
the disabled release-artifact E2E workflow.
