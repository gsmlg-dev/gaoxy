# Released-server clients

Install `requirements.txt`, curl, OpenSSL 3 and the GitHub CLI, then run:

~~~sh
python3 integration/e2e/run.py --version 0.11.1 --evidence .audit/released-clients
~~~

The runner downloads the existing Linux x86_64 archive and SHA256SUMS, verifies
the checksum and runtime version, and records the release tag's source SHA.
It never builds the server. A test-only fixture runs against the archive's
public APIs. The existing aioquic peer and credential helper come from that
release's exact source revision; HTTPFetch comes from the downloaded runtime.

Eleven ordinary checks cover curl/httpx H1, verified TLS, negotiated H2,
upload/streaming, public HTTPFetch, negotiated H3 and WebSocket message/normal
close. All listeners use ephemeral loopback ports. Startup, requests, shutdown
and subprocess cleanup have finite deadlines. Results, protocol/client identity
and server logs are saved to the evidence directory, including on failure.

`e2e.yml` runs source integration on push/PR/manual. Its independent
`release-clients` job adds these artifact checks only for a manual run with a
nonempty version, after local qualification and review. No browser is required.
