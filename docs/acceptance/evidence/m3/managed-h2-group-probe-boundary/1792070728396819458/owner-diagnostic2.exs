alias Gaoxy.Proxy.UpstreamGroups
scheme = Enum.at(["https", "http"], 0)
transport = %{provider: Gaoxy.Proxy.UpstreamTransports, owner: self(), owner_epoch: make_ref(), resource: make_ref()}
uri = Map.new(Map.to_list(URI.parse(scheme <> "://upstream.test")), fn {k,v} when is_binary(v) -> {k,:binary.copy(v)}; pair -> pair end)
limits = %{max_chunk_bytes: 65_536, opening_timeout: 5_000, idle_timeout: 60_000, write_timeout: 3_000, max_lifetime: 30_000}
config = %Gaoxy.Proxy.HTTP{uri: uri, upstream_protocol: :http2, client: Gaoxy.Proxy.ManagedH2Client, transport: transport, limits: limits, cacertfile: nil, connect_address: nil}
health = %{path: "/health", interval: 5_000, timeout: 2_000, stale_after: 15_000, failure_threshold: 3, recovery_threshold: 2, jitter: 500}
group = %{provider: UpstreamGroups, owner: self(), owner_epoch: make_ref(), group: "group", generation: make_ref(), max_url_bytes: 8_192, transports: [transport], execution_profile: :managed_h2}
args = %{owner: self(), token: make_ref(), member: %{id: "member", config: config, max_inflight: 1}, deadline: 12_000, health: health, url: scheme <> "://upstream.test/health", group: group}
parent = self()
{tracer, monitor} = spawn_monitor(fn ->
  loop = fn loop, entries ->
    receive do
      {:trace, _, :return_from, {UpstreamGroups, function, arity}, result} ->
        value = if is_boolean(result), do: result, else: inspect(if(is_tuple(result), do: elem(result,0), else: result))
        entries = [%{function: Atom.to_string(function), arity: arity, result: value} | entries]
        if function == :probe_start_arguments, do: send(parent,{:traced,Enum.reverse(entries)}), else: loop.(loop,entries)
    after
      5_000 -> send(parent, {:trace_timeout, entries})
    end
  end
  loop.(loop, [])
end)
:erlang.trace_pattern({UpstreamGroups, :_, :_}, [{:_, [], [{:return_trace}]}], [:local])
:erlang.trace(self(), true, [:call, {:tracer, tracer}])
result = UpstreamGroups.probe_start_arguments(args)
:erlang.trace(self(), false, [:call])
copied_result = UpstreamGroups.probe_start_arguments(%{args | url: :binary.copy(args.url)})
trace = receive do {:traced, entries} -> entries after 5_000 -> raise "trace timeout" end
receive do {:DOWN, ^monitor, :process, ^tracer, :normal} -> :ok after 5_000 -> raise "tracer join timeout" end
:erlang.trace_pattern({UpstreamGroups,:_,:_}, false, [:local])
public = %{map_sizes: Enum.map([args,args.member,group,transport], &map_size/1), envelope: inspect(Gaoxy.Proxy.ManagedH2Envelope.validate_config(config)), resources: inspect(elem(Gaoxy.HTTP.Resources.validate([group | group.transports]),0)), backing: Enum.map([args.member.id,health.path,args.url,group.group], fn v -> [byte_size(v),:binary.referenced_byte_size(v)] end), owner_equal: group.owner === args.owner, selected_member: config.transport in group.transports, url_equal: args.url === config.uri.scheme <> "://" <> config.uri.authority <> health.path}
IO.puts(Jason.encode!(%{kind: "PURE_OWNER_DIAGNOSIS_ONLY", copied_url_result: inspect(elem(copied_result,0)), public_checks: public, actual_result: inspect(if(is_tuple(result),do: elem(result,0),else: result)), private_return_trace: trace, tracer_joined: true, tests_executed: 0}))
