# Gaoxy WebSockAdapter snapshot

Upstream: https://github.com/phoenixframework/websock_adapter

- Upstream version: `0.6.0`
- Original upstream commit: `80901f46c8864cb8bd5231c32b7171b9d0e330ce`
- Historical dispatch-only fork: `53ee1c7c9edb39fda9c531a5c79aec17ee081a6c`
- License: MIT, retained unchanged in `LICENSE`.

The current downstream snapshot retains the historical `Gaoxy.PlugAdapter`
WebSock tuple dispatch and adds M5 early upgrade validation for native Gaoxy H2
and H3 requests. It also preserves an omitted frame ceiling for Gaoxy instead
of injecting upstream's 10,000,000-byte default. Explicit application frame
limits, including exactly 10,000,000, pass through unchanged. Other adapters
retain their upstream default and explicit-limit behavior. It is no longer
byte-identical to the dispatch-only fork.
No remote fork was published. No fetched dependency is modified.

Phoenix's explicit compatibility wrapper temporarily presents GET to its socket
pipeline. Early validation therefore reads the immutable native request in the
Gaoxy adapter payload: HTTP/2 or HTTP/3, method CONNECT, protocol `websocket`, and
exactly one `sec-websocket-version: 13` header. Apparent Plug GET metadata cannot
replace invalid native metadata. Other adapters and H1 retain upstream validation.
Early validation remains enabled; Gaoxy separately validates the full native
handshake and retains transport/lifecycle authority.

Phoenix applies its own finite inactivity default before calling this adapter.
For persistent sockets, use public Endpoint declarations with
`websocket: [timeout: :infinity]` on `/socket` and `/live`; preserve LiveView's
`connect_info: [session: ...]` in the same list. This is explicit application
integration configuration. The adapter neither infers intent from a numeric
60,000 timeout nor inspects hidden Phoenix endpoint metadata. Deliberately
finite application policies remain supported.

`gaoxy.patch` is the canonical complete diff from the original upstream snapshot,
including dispatch, Gaoxy frame-default preservation, immutable-metadata validation,
and the isolated dependency
regression. It is a plain Git patch, not the old dispatch commit's mail patch.
`SOURCE.json` retains both historical identities, upstream file hashes and current
snapshot hashes, including the patch. Its `fork_commit` identifies the historical
dispatch fork, not a commit containing the current M5 changes. The patch applies
from the upstream checkout root with `git apply --check` and `git apply`.

For offline reconstruction, repository baseline `4c6f089` contains upstream
runtime/project/license files except the one Gaoxy dispatch clause in
`lib/websock_adapter.ex`. Remove that clause and omit the downstream
`test/gaoxy_dispatch_test.exs` to reconstruct the retained upstream snapshot.
The original `upgrade_validation.ex` is available unchanged at that baseline.
Applying the current patch must reproduce every snapshot hash in `SOURCE.json`.

The isolated dependency regression covers dispatch without an injected frame
ceiling, explicit application frame/inactivity policies, other-adapter frame
defaults, valid native H2/H3 CONNECT metadata while Phoenix sees GET, and invalid
native method/protocol/version rejection. Run independently of Gaoxy's real module after building root dependencies:

```sh
ELIXIR_ERL_OPTIONS='+S 2:2' elixir \
  -pa _build/test/lib/plug/ebin -pa _build/test/lib/websock/ebin \
  -r vendor/websock_adapter/lib/websock_adapter/upgrade_error.ex \
  -r vendor/websock_adapter/lib/websock_adapter/upgrade_validation.ex \
  -r vendor/websock_adapter/lib/websock_adapter.ex \
  -r apps/gaoxy_http/test/test_helper.exs \
  vendor/websock_adapter/test/gaoxy_dispatch_test.exs
```

The dependency regression and patch reconstruction are separate from Gaoxy's
native network and Phoenix HTTP-client acceptance. Historical M2 dispatch evidence
remains historical; current M5 acceptance records its own verification and review.

Removal: replace the path dependency with an exact upstream release supporting
Gaoxy dispatch, omitted frame-ceiling preservation and native H2/H3 early
validation (or equivalent public extension
APIs); remove this directory and the fixture override together; rerun native
WebSock, Phoenix HTTP-client and dependency isolation gates. Do not remove the
snapshot merely because an upstream issue closes.
