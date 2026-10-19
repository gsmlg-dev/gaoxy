# Repair 3 proposal — ordinary Exchange limit boundary

Status: PROPOSED ONLY. Tracked source has not been edited. Parent must obtain cached diagnostic evidence and independent review before activating ownership or applying `repair3.patch`. This worker has not parsed, compiled, formatted or executed the proposed Elixir code or tests.

The only production behavior change is at H2/H3 Exchange construction: `request.protocol == "websocket"` retains existing WS-only configuration; every ordinary request receives the original native numeric limit map plus max_write_chunk. Connection-level WS configuration stays intact. All accounting schemas/caps, fixture guards, defaults, resources, deadlines, selectors, existing test assertions and publication behavior remain unchanged.

## Exact proposed ownership

1. `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex`: in dispatch/6, strip only extended_connect/websocket_limits from ordinary Exchange.limits; preserve both for actual WebSocket requests.
2. `apps/gaoxy_http3/lib/gaoxy/http/http3/connection.ex`: in exchange/3, add WS fields only for actual WebSocket requests; preserve the ordinary native map.
3. `apps/gaoxy_http/test/http2_websocket_network_test.exs`: retain the full existing WS push/echo/normal-Close/sibling test unchanged. Add one named ordinary h2c case that performs real GET exchanges with opt-in false and true and observes exact endpoint limit equality to normalized native limits plus max_write_chunk. A finite native endpoint fixture only reports its limits back to the owning test process.
4. `apps/gaoxy_http3/test/websocket_test.exs`: choose this ONE H3 test file. Add one direct Exchange case using normalized options, Connection.init/stream-open and actual Protocol.feed header parsing; check ordinary requests under false/true and actual WebSocket metadata retention under true. Terminate each constructed connection after its assertions. Existing tests remain unchanged.

## Proposed verification, parent-owned

RED before applying the production repair: apply only the two test hunks, run the named ordinary H2/H3 tests below and preserve their failures. Existing four group line-21 cases provide the actual failed integration regression already captured by the parent diagnostic. Do not count preparation or unexecuted tests as RED.

GREEN after the production repair: scoped format check of exactly the four files, normal strict compile, then scoped tests. Run ordinary and network checks serially in the pinned qualified environment, preserving peer pins and existing finite deadlines:

```sh
mix test apps/gaoxy_http/test/http2_websocket_network_test.exs --seed 0 --max-cases 1
mix test apps/gaoxy_http3/test/websocket_test.exs --seed 0 --max-cases 1
mix test apps/gaoxy_proxy/test/managed_h2_group_endpoint_test.exs:21 --seed 0 --max-cases 1
```

The parent may use the existing check-tests.py wrapper with exactly these selectors to enforce nonzero execution and counts. The two network cases remain ordinary GET/WS normal Close only; no abnormal/disconnect/slow-peer/pressure/load gate is included. Existing broader M5 ordinary selectors, full ordinary M3 24-case network selection, fresh portable builder/offline runtime and three packaged WS profiles remain parent-owned required qualification after the source repair. Do not run a broad H3 connection file merely for constructor coverage.

## Expected case-count deltas, not executed claims

- H2 WebSocket network test file: existing 1 named case becomes 2, with opt-in false/true exercised inside the new one.
- H3 WebSocket test file: existing 8 named cases become 9, adding exactly 1 case covering three constructor scenarios (ordinary disabled, ordinary enabled, actual WebSocket enabled).
- Existing reviewed M5 suite: gaoxy_http 54 → 55; gaoxy_http3 82 → 83; total 136 → 138 executed invocations. No M5 exclusions/skips expected.
- M3 ordinary unit remains 38; ordinary network remains 24 executed with 90 deliberate exclusions and no skips. Four selected group cases remain four; assertions are unchanged.
- Portable ordinary invocation count therefore changes from 198 to 200, not 200 unique tests.
- Parent must update ordinary-scope.json expected counts and its content hash, the download verifier embedded snapshot/hash and release evidence counts before fresh qualification. No selector broadening or assertion weakening is proposed, and those metadata files are outside this worker's current four-file ownership.

Astra remains 2/2 exhausted. This is authorized ordinary Sol repair3 preparation, with no product execution or new recovery model.

## Frozen patch/source hashes

Patch SHA256: `86dffbfee45a7756541563016fe37349fbfe3e264e0e55263000e650d60113fb`

```json
{
  "apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex": {
    "baseline_sha256": "39afca3bb60626ff63c9c8b93696048de701d8c1466f5a1eca217d06644df1e9",
    "proposed_sha256": "4e5ff7cfabb9f04f3283d42cb40d56df0ddb96838e15e60ff904ea2e8320a2b3"
  },
  "apps/gaoxy_http3/lib/gaoxy/http/http3/connection.ex": {
    "baseline_sha256": "a951daebc38ac3a061ccadf1f344da0d0e58cc977b18243560e32efdb5093e39",
    "proposed_sha256": "512edd9f3e0c7ec37859a25d8fd7dcb5e21dca92c32adf8dfa6b7ca10e4b545a"
  },
  "apps/gaoxy_http/test/http2_websocket_network_test.exs": {
    "baseline_sha256": "a02024a271736283e143c5fa6977a2b7d31b23449d011c7c4a06e4eb3dfae793",
    "proposed_sha256": "aee91544a3108dce0cd231f93333bacee2f996004fe4daed460a6836d817a73d"
  },
  "apps/gaoxy_http3/test/websocket_test.exs": {
    "baseline_sha256": "267f1396b5af515ee9816cb8edede6e23608784a81fcfbf20807622d9d4ba4ba",
    "proposed_sha256": "97acc6ab0780e64ae3d05e92059368a73a95b428c69c2e1f162cf0b085cd9c05"
  }
}
```
