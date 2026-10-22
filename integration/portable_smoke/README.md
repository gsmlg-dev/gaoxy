# Portable HTTP smoke

`python3 scripts/portable-smoke.py` stages the candidate's core and HTTP packages
in a temporary consumer, compiles them, starts one loopback HTTP endpoint, makes
one OTP HTTP-client GET to `/health`, requires `200` and `ok`, and stops normally.
The wrapper bounds compilation, requests and VM exit, and saves failures under
`.audit/portable-smoke/`. `GAOXY_CONSUMER_DEPS` can seed an existing dependency cache.

Only `portable.yml` runs the Linux/macOS matrix. This candidate-source smoke
does not qualify a downloaded release archive or run the integration suites.
