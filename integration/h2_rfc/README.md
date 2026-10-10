# Selected independent RFC 9113 checks

This finite loopback fixture fixes expected HTTP/2 frame error scope and codes
before execution. Python constructs frames directly and uses public independent
`hpack` to encode requests and decode exact responses. It never imports Gaoxy's
codec. Install the pinned `../h2_gateway/requirements.txt` in an isolated venv.
After compiling the candidate in `MIX_ENV=test`, run under its Nix shell:

```sh
python integration/h2_rfc/run.py --evidence docs/acceptance/evidence/m3/h2-rfc
```

The cases cover SETTINGS, PING, RST_STREAM, PRIORITY, GOAWAY, WINDOW_UPDATE,
DATA, HEADERS/CONTINUATION, HPACK index errors, and declared frame-size limits.
Stream errors require the exact live sibling response over the same socket.
Unknown settings/frames must preserve an exact response. Every case requires
zero owned admission bytes/work/cleanup reservations after closing its socket;
finite teardown confirms runtime DOWN, refused connection and port rebind.

The report records actual counts, errors, runtime versions, commands and production
source hashes. Candidate drift fails the gate. This selected suite is not a full
conformance, TLS, browser, load, or production-security certification.
