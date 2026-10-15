alias Gaoxy.Proxy.ManagedH2GroupAccounting, as: A
ExUnit.start(autorun: false)
Code.require_file("apps/gaoxy_proxy/test/managed_h2_group_accounting_test.exs")
parent = self()
loop = fn recur, seen ->
  receive do
    {:trace, _pid, :call, {A, :project, [{:control, family},
      {:gaoxy_proxy_http, pid, {:transport_handoff, ref, transport, identity, deadline}} = original]}}
    when family in [:handoff_request, :identity] and is_map(identity) and is_binary(identity.origin) ->
      uri = URI.parse(identity.origin)
      if not MapSet.member?(seen, family), do: send(parent, {:original_identity_diagnostic, %{
        original_project_arguments: [{:control, family}, original],
        family: family, identity_keys: Map.keys(identity), protocol: identity.upstream_protocol,
        origin_bytes: byte_size(identity.origin), origin_backing: :binary.referenced_byte_size(identity.origin),
        scheme: uri.scheme, host: uri.host, port: uri.port, path: uri.path,
        query: uri.query, fragment: uri.fragment, userinfo: uri.userinfo,
        deadline: deadline, deadline_integer: is_integer(deadline),
        sender_bytes: :erlang.external_size(pid), ref_bytes: :erlang.external_size(ref),
        instance_bytes: :erlang.external_size(identity.instance), transport: transport,
        copied_origin_result: A.project({:control, family}, put_elem(original, 2,
          {:transport_handoff, ref, transport, %{identity | origin: :binary.copy(identity.origin)}, deadline}))
      }})
      recur.(recur, MapSet.put(seen, family))
    {:trace, _pid, :call, _call} -> recur.(recur, seen)
    {:flush, tag} -> send(parent, {:flushed, tag})
  end
end
tracer = spawn(fn -> loop.(loop, MapSet.new()) end)
:erlang.trace_pattern({A, :project, 2}, true, [:local])
:erlang.trace(self(), true, [:call, {:tracer, tracer}])
for name <- [
      "test closed fixed handoff_request envelope fits its full2048 slot",
      "test raw8192 identity plus real handle and signed scalar shell uses full group24576 slot"
    ] do
  result = try do
    apply(Gaoxy.Proxy.ManagedH2GroupAccountingTest, String.to_atom(name), [%{}])
    :passed
  catch
    kind, reason -> {kind, Exception.message(reason)}
  end
  IO.inspect(result, label: name, limit: 20)
end
:erlang.trace(self(), false, [:call])
barrier = :erlang.trace_delivered(self())
receive do {:trace_delivered, _pid, ^barrier} -> :ok after 5_000 -> raise "trace delivery timeout" end
flush = make_ref()
send(tracer, {:flush, flush})
collect = fn recur ->
  receive do
    {:original_identity_diagnostic, value} ->
      IO.inspect(value, label: "exact_original_fixture", limit: :infinity, printable_limit: :infinity)
      recur.(recur)
    {:flushed, ^flush} -> :ok
  after
    5_000 -> raise "diagnostic tracer join timeout"
  end
end
collect.(collect)
monitor = Process.monitor(tracer)
receive do {:DOWN, ^monitor, :process, ^tracer, reason} when reason in [:normal, :noproc] -> :ok after 5_000 -> raise "diagnostic tracer exit timeout" end
:erlang.trace_pattern({A, :project, 2}, false, [:local])
