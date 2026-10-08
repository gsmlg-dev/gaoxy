# Mixed transports

This script defines custom byte-stream and datagram handlers and starts TCP,
OTP TLS, UDP unicast, IPv4 broadcast and IPv4 multicast together through Gaoxy.
All ports are ephemeral and reported by `Gaoxy.info/2`.

Run from the umbrella root **inside an isolated network fixture**, after generating
test credentials with `bash scripts/generate-fixtures.sh /tmp/gaoxy-fixture-certs`:

```sh
GAOXY_FIXTURE_CONFIRM=isolated \
GAOXY_FIXTURE_INTERFACE=eth0 GAOXY_FIXTURE_ADDRESS=192.0.2.10 \
GAOXY_FIXTURE_CERT=/tmp/gaoxy-fixture-certs/cert.pem \
GAOXY_FIXTURE_KEY=/tmp/gaoxy-fixture-certs/key.pem \
mix run examples/mixed_transports/run.exs
```

The address/interface belong to the fixture. Do not substitute a physical LAN
interface. Echo replies preserve the original listener port. The actual custom-handler example passed11 isolated Linux checks with two
independent peers: five transports each, then shutdown/port reuse. Evidence is
`docs/acceptance/evidence/mixed-example-repair1-linux.log`. The separate
production release passed its own11-check gate; see `docs/acceptance/m1.md`.
