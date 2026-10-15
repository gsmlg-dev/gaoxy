alias Gaoxy.Proxy.UpstreamGroups.Probe
marker = :opaque_startup_argument_marker
raw = Probe.child_spec(marker)
public = Supervisor.child_spec({Probe, marker}, [])
expected = %{id: Probe, start: {Probe, :start_link, [marker]}, restart: :temporary}
if raw !== expected or public !== expected, do: raise("unexpected generated child spec")
{_, object, loaded_path} = :code.get_object_code(Probe)
{_, dynamic_object, dynamic_path} = :code.get_object_code(DynamicSupervisor)
hash = fn binary -> :crypto.hash(:sha256,binary) |> Base.encode16(case: :lower) end
source = Probe.module_info(:compile)[:source] |> List.to_string()
IO.puts(Jason.encode!(%{kind: "GENERATED_PROBE_CHILD_SPEC_METADATA_ONLY", generated: inspect(raw), public_supervisor_spec: inspect(public), exact_marker_identity_preserved: true, probe_source: source, probe_source_sha256: hash.(File.read!(source)), probe_loaded_beam: List.to_string(loaded_path), probe_loaded_beam_sha256: hash.(object), dynamic_supervisor_beam: List.to_string(dynamic_path), dynamic_supervisor_beam_sha256: hash.(dynamic_object), elixir_executable: System.find_executable("elixir"), defaults_from_canonical_source: %{type: "worker", shutdown: 5000, modules: "[Gaoxy.Proxy.UpstreamGroups.Probe]"}, tests_executed: 0, owner_or_probe_started: false, wrappers_and_aggregate_caps_measured: false}))
