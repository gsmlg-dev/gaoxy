# Trace filter CODE1

DONE; precise projection proposal PASS (source-only; implementation/runtime not reviewed). Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, archived baseline `58307a7084298db309a93697b9102b2cc4c87eda`.

Actual safe envelope is `{:trace_ts, connection, :send, {[:alias | ref] = tag, {:ok, {%ThousandIsland.Socket{}, state}}}, ref, timestamp}`. Destination is a reference alias, not PID. Redacted trace get_state requests at7/10 corroborate the corresponding tag/destination references; omitted reply markers at9/11 preserve sender/destination/time. No full private state was reproduced. After root relocation, only redacted trace/relocation receipt were read; raw archive was not reopened.

Future diagnostic_log should project only this exact reply payload, before inspect/write, retaining sender, tag, :ok envelope, destination and timestamp:

```elixir
def diagnostic_event(s,
      {:trace_ts, owner, :send,
       {[:alias | reference] = tag, {:ok, {%ThousandIsland.Socket{}, state}}},
       destination, timestamp})
    when owner == s.connection and is_reference(reference) and
           destination == reference and is_map(state) do
  {:trace_ts, owner, :send,
   {tag, {:ok, :omitted_system_state_reply}}, destination, timestamp}
end

def diagnostic_event(_s, event), do: event
```

Use the projected event for logging. Identity fallback preserves H2 plaintext, get_state request tags, writer results/stops, DOWN/exit reasons, trace markers, scalar connection snapshots and full Gate leases/public status. Full connection state flags remain available through explicit safe scalar snapshots; no terminal event is filtered. Do not discard generic :send events or all maps/tuples. Existing archived raw hash/receipt plus precise redacted markers preserve history without reintroducing raw state to Git. Current raw SHA256 receipt is `a7990ac4d6dc3c36c710b3aced24f9b48f107785ff262bb5722c3499c20e349a`; redacted SHA256 `1c404d390494b9584cdf8fead1f0a64a9bc936822f22f58c3feb76baf653875e`.

No claim that extra Gate leases explain the earlier writer terminal: diagnostic2 establishes actual active5 including another genuine C/W, but causal timing remains unknown. No acceptance counts. Only this assigned report written; no repository/runtime/Mix/browser/network/Git commands. All own commands finished, no processes launched. Counters preserved group37/root47/stage7/Astra2of2; no review repairs or GREEN attempts added.
