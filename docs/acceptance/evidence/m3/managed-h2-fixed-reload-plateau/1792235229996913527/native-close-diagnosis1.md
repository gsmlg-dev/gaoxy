# Fixed reload native H2 shutdown diagnosis

DONE — read-only direct assignment at `88e435a73429666717a4d20a83f9fca13e0a67e9`, `codex/m3-h1-resource-foundation`.

The additive reload fixture races endpoint return against TCP close. The exact expected original monitor PID/ref reports `:killed` in three displayed failures, disproving stale monitor selection. The TLS active failure has the same helper/seed stack but ExUnit shows only 10 of54 queued messages, omitting its exact worker exit reason. Preserve that limit.

`CapturedFixed.call/2` reports proxy completion while still awaiting `:return` (test69–88). `complete_return/8` proves original upstream completion and Session normal exit but explicitly retains the source pin/native worker (1569–1597). `reload_complete/5` sends `:return` and immediately invokes `close_native/3` (3029–3030); its first action closes TCP (1611). The worker must first return through Generation's source release (`generation.ex304–338`), finish the response and send authentic stream done (`http2/stream.ex23–62`). F's native H2 response returns at wire END_STREAM (`fixed_endpoint_test.exs483–539`), which does not acknowledge this endpoint return.

The actual native TCP host is ThousandIsland (`service.ex941–949`). Its `tcp_closed` branch stops `{:shutdown,:peer_closed}` (`deps/thousand_island/.../handler.ex416–422`), invokes HTTP `handle_close` (495–497), then Gaoxy `HTTP.Connection.handle_close/2` (355) invokes H2 `Connection.close/1` (1411–1418). That function kills every still-registered stream worker. The alternative normal `h2_stream_done` path discards a finished stream without kill (1060–1075). No dependency defect or production repair is evidenced. No upstream workaround is proposed.

## Minimal proposal

The complete tmp source proposal changes only the two additive return callsites and adds this helper in the additive section:

```elixir
  defp reload_return_endpoint(f, captured) do
    return_endpoint(captured)

    # Finish the native H2 worker before closing its connection. The original
    # monitor stays unread for close_native/3's unchanged normal-exit assertion.
    if f.downstream == :http2 do
      F.eventually(fn -> not Process.alive?(captured.native) end)
    end
  end

```

Waiting until a local process is no longer alive before TCP close prevents this close from killing that process. The original monitor remains unread for `close_native/3` to assert the authentic `:normal` reason. This is not a fabricated or replayed DOWN message, late fresh monitor, arbitrary delay or weakened assertion. The exact H1 return/close ordering is unchanged. Source release and stream finishing run with the connection still open; all old connection/writer normal/peer-close, pin/effect/service/gate/zero checks remain.

The existing five-second F.eventually budget bounds the new condition barrier. No timeout constant is changed, including the inherited five-second original monitor assertion, outer60s test, embedding120s or peer180s. The new wait is additional ordering work; full timing feasibility remains unvalidated.

## Static evidence and boundaries

- Input test SHA256: `c1823bedb8eaaf987d5caa50f8ee617e6f656b375b9902da84af4f23b40cb116`.
- Proposed full source: `/tmp/gaoxy-fixed-plateau-native-proposal1.exs` SHA256 `7f8a31bdd3a6f26e54a8ac0710ed4264189a69ba91d0dc49b7a99ab3c7dd6daa`.
- Proposal diff: +12 / -2 lines.
- All 101062 committed prefix bytes match HEAD exactly (prefix SHA256 `6d3e681ffc9337130c4bf60975afd06b4582f635e840e817056e6f87d03d1523`); final module terminator preserved. Original `close_native/3`, assertions/deadlines/all8profiles/22CAS/20samples unchanged.
- Original log SHA256 `ff812b227d7756701dc151a967ecdcd3d78d8ac8ac554329f70ba9b3ddf24999`; actual94tests4failures, root collector exit2. Root collector SHA256 `fa57abea28b6ac7913cb9b0fa044e78db1d9af94c2ae18b04c8ec156624ca4f8` supplied by parent.
- No repository files edited; proposal only under /tmp. No formatting, BEAM/build/test/browser/network/process commands run. All own commands finished; root collector custody unchanged.
- Counters inherited: Sol5/fixture5/production0, Astra2/2 exhausted; this agent executed0 repairs. Parent latest counter7: root232/group64/runtimefailed10.

The source trace identifies the causal cancellation path; no dynamic sender trace was run. Proposal is NOT RUN. Root must independently review/adopt and rerun the unchanged complete defining-F/fixed suite and later prescribed gates. All eight runtime profiles and their full20sample/22CAS ledgers remain acceptance requirements. No user decision or external permission is needed for the bounded fixture repair.
