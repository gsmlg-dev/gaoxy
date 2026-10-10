# Gaoxy dispatch fork

Upstream: https://github.com/phoenixframework/websock_adapter

- Upstream version: `0.6.0`
- Upstream commit: `80901f46c8864cb8bd5231c32b7171b9d0e330ce`
- Local fork commit: `53ee1c7c9edb39fda9c531a5c79aec17ee081a6c`
- License: MIT, retained in `LICENSE`.

The only runtime change adds the real `Gaoxy.PlugAdapter` to the existing
WebSock tuple dispatch. `gaoxy.patch` is the exact commit patch, including its
isolated dependency regression. The vendored runtime, project and license files
are identical to that fork commit. This repository pins the snapshot through
its committed files; `SOURCE.json` records hashes for offline verification.
No remote fork was published. No fetched dependency is modified.

The regression failed with `Unknown adapter Gaoxy.PlugAdapter` on upstream,
then passed on the fork. Run it independently of Gaoxy's real module after
building the root dependencies:

```sh
ELIXIR_ERL_OPTIONS='+S 2:2' elixir \
  -pa _build/test/lib/plug/ebin -pa _build/test/lib/websock/ebin \
  -r vendor/websock_adapter/lib/websock_adapter/upgrade_error.ex \
  -r vendor/websock_adapter/lib/websock_adapter/upgrade_validation.ex \
  -r vendor/websock_adapter/lib/websock_adapter.ex \
  -r apps/gaoxy_http/test/test_helper.exs \
  vendor/websock_adapter/test/gaoxy_dispatch_test.exs
```

Gaoxy's `websocket_network_test.exs` separately verifies the actual native
adapter over TCP. The patch received independent source review.

Removal: replace the path dependency with an exact upstream release supporting
Gaoxy dispatch or public adapter registration; remove this directory and the
fixture override together; rerun native WebSock, Phoenix/browser and dependency
isolation gates. Do not remove the fork merely because an upstream issue closes.
