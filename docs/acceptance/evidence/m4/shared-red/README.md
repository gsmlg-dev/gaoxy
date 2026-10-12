# G2 production endpoint intended red

Worktree `.trees/m4-http3`, branch `codex/m4-http3`, source HEAD
`42f0c0569ba556f8b08e5e2bbc1bc1d3acf0261e`, original baseline `78de9d0`.
Run `run-1791782903127521242` was executed before production Connection dispatch
implementation, under an exclusive Mix/source lease. Its immutable source
manifest includes the unchanged qualified G1 Connection
`81b1d2081aaeb363120d6c68f1a00ab95f4ee54dac8406ba59b8ef104d851008`.

```sh
nix develop --command sh -c 'export MIX_ENV=test ERL_FLAGS="+S 2:2"; mix format integration/http3/fixture.exs && mix compile --warnings-as-errors && python -m py_compile integration/http3/peer.py integration/http3/run.py && python integration/http3/run.py --gate shared --evidence docs/acceptance/evidence/m4/shared-red'
```

Exact owned fixture formatting, strict compilation and Python compilation
completed successfully. The live gate returned exit 1, **FAIL**, with one actual
GET failure and its additional runtime diagnostic; zero PASS cases. The pinned
independent aioquic peer authenticated against local test credentials, sent the
request to the public Plug service, and observed connection close `0x0`.
`fixture.log` preserves the concrete server rejection:

```text
{:binding_failed, {:error, :http3_endpoint_not_implemented}}
```

This is the agreed missing-dispatch TDD red, not a protocol acceptance PASS or
an unexpected implementation failure. Shared peer Sol repair rounds remain 0.
Both owned child processes exited (fixture 0 after bounded SIGTERM cleanup,
peer 1); the runner confirms source hashes stayed unchanged. Runtime/port and
application cleanup acceptance were NOT RUN after the expected request failure.
No child, Mix process, publication or deployment remains owned by this run.

Subsequent peer cases, busy-Plug listener and queue observations are additional
source work and require their own fresh full-gate verification. This original
failure evidence must remain unchanged.
