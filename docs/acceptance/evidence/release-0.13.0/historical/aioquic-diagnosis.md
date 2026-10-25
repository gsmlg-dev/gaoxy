# H3 standalone smoke diagnosis

- Baseline main: `f2ba26ab6319d0e81da5ff2eb40724d1c170c050`, with parent-owned 0.13.0 changes.
- Original smoke failed; unchanged reproduction also failed. Existing release executable reused; no build or tracked source edits.
- The upstream B origin observed the zero-body POST, two expected x-check trailer fields, and exactly one request FIN. Request/EOF forwarding therefore progressed through the gateway.
- Observation-only client event tracing showed remote max_idle_timeout=0.0 and local idle_timeout=60.0, but aioquic computed an effective idle of approximately 96ms (3 PTO). It completed GET at2.1506s, started POST at2.1507s, and self-terminated for Idle timeout at2.2551s. No server CONNECTION_CLOSE was reported.
- RFC9000 section10.1 requires use of the sole nonzero advertised timeout when the other endpoint advertises zero. The expected effective value was60s, not3PTO.
- The new supported H3 disabled-local-idle configuration advertises zero as required; the client timeout is an independent aioquic defect.
- Installed dependency: aiortc/aioquic1.2.0. PyPI latest is1.7.0; official tagged source still has the same parameter assignment and numeric-minimum idle calculation. A version update alone has no evidenced fix.
- No workaround, dependency patch, changed timeout, assertion removal, tracked test/runtime change, external issue write or publication was performed.
- Current packaged H3 smoke remains FAIL / blocked on the peer dependency; previous passing gates remain their separate evidence.

Evidence:
- `diagnosis-h3-reproduction.log` and `diagnosis-h3-reproduction/{result.json,origin.log,release.log}`
- `diagnosis-h3-trace.py`, `diagnosis-h3-trace.log` and `diagnosis-h3-trace/`
- `diagnosis-h3-aioquic-1.2.0-source.txt`
- `diagnosis-h3-aioquic-1.7.0-source.txt`
- `diagnosis-h3-rfc9000-idle.txt`

Dependency source is https://github.com/aiortc/aioquic, outside the covered organizations. No permission to file a third-party issue was inferred. Parent retains delivery and issue-routing decisions.
