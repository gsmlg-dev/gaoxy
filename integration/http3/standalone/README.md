# Local standalone H3 qualification

Run under the locked Nix test environment after ST1 and G3 compatibility:

```sh
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python integration/http3/standalone/run.py --evidence docs/acceptance/evidence/m4/standalone
```

The owned child loads data-only JSON through the actual standalone Application,
Config and Supervisor path. Independent aioquic and H1 clients verify H3 static
responses, streamed H3-to-dedicated-H1 proxying, failure isolation, live reload
with an in-flight old generation, invalid reload rollback and bounded shutdown.
Fixed explicit `upstream_protocol: "http3"` routes use two independently certified
H3 origins. The peer observes upload bytes before request FIN, zero-DATA and
ordered duplicate request/response trailers, and an H3-origin response that stays
in flight across reload. Origin fields, bytes/hash, exactly one FIN and unique
requests are checked independently, alongside both application admission baselines.
A separate child verifies startup rollback after a later occupied UDP port and
a missing local fixture certificate. Temporary loopback ports and certificates
are owned by the runner; every live execution binds exact source hashes and child
exits. This is source-level local qualification, separate from release-artifact
E2E and publication. These rows require the qualified public Session adapter;
source preparation alone is not a runtime PASS.
