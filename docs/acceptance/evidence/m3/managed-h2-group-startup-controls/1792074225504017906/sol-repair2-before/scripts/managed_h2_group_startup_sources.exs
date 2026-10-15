defmodule Gaoxy.Proxy.ManagedH2GroupStartupSources do
  @moduledoc false
  alias Gaoxy.Proxy.UpstreamGroups.Probe

  @elixir "/nix/store/jc6g5l4a2qg89s3mng0p18r9dbijc28d-elixir-1.18.5"
  @otp "/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7"
  @stdlib @otp <> "/lib/erlang/lib/stdlib-7.3.0.3/src/"
  @kernel @otp <> "/lib/erlang/lib/kernel-10.6.3.4/src/"
  @elixir_sources @elixir <> "/lib/elixir/lib/elixir/lib/"
  @startup_sources [
    {@elixir_sources <> "dynamic_supervisor.ex",
     "75dad290cf34294824d2d0f0741f0d1db2f2ff5533658adab54b0349b3050a62"},
    {@elixir_sources <> "gen_server.ex",
     "6d00e38c0f2ed6296b3c353e823123042345035da7328a1db6f73de44bf57fe2"},
    {@elixir_sources <> "supervisor.ex",
     "e9d63501dfa83707ea2fffc0201ebf6db9c2f763a4bb9189d4092999c940ebb7"},
    {@stdlib <> "gen.erl", "b828697b055865df24aad48ec4cd7f23821fa54a7aa2baa0408a444a5d0d04be"},
    {@stdlib <> "gen_server.erl",
     "66a4a649c8ed58f3c9ed317047f28ea2e2a61b38032cc467565fbad2c53a09db"},
    {@stdlib <> "proc_lib.erl",
     "ff6b30b4bdbc92bc431c0a14ee63e72c7df57d0a8cc2906c8058144253564122"}
  ]
  @metadata_sources [
    {@kernel <> "code.erl", "8d291bb6b9327b00a82e96fc3d825721fd06c14f97269ecd76965fef994ab061"},
    {@kernel <> "code_server.erl",
     "ae0bf37b31206b67c3f5080d56a080d44bae8539b3a9f445d137c19ba6ec45fe"},
    {@stdlib <> "beam_lib.erl",
     "bfd54c468e2fb91839e7be74bf458121fa206e493f8e53010b9f361cba61e52a"}
  ]

  def run do
    "1.18.5" = System.version()
    otp_root = @otp <> "/lib/erlang"
    ^otp_root = to_string(:code.root_dir())
    "28.5.0.7" = otp_root |> Path.join("releases/28/OTP_VERSION") |> File.read!() |> String.trim()

    executables =
      Map.new([{"elixir", @elixir}, {"mix", @elixir}, {"erl", @otp}], fn {name, root} ->
        path = System.find_executable(name) || raise("missing executable: " <> name)
        resolved = resolve_link(path)
        true = String.starts_with?(resolved, root <> "/")
        {name, %{path: path, resolved_path: resolved}}
      end)

    modules = Enum.map([DynamicSupervisor, GenServer, Supervisor, Probe], &module_identity/1)

    # These are the only application function calls: public, pure child-spec
    # construction with an atom marker. No owner or Probe is started.
    marker = :opaque_startup_argument_marker
    expected = %{id: Probe, start: {Probe, :start_link, [marker]}, restart: :temporary}
    raw = Probe.child_spec(marker)
    public = Supervisor.child_spec({Probe, marker}, [])
    true = raw === expected and public === expected

    source = Path.expand("../apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/probe.ex", __DIR__)

    probe_source =
      source_identity(
        {source, "9f3de8e0fc74f8ebfe358629d3e11ca6c65ee20c34fe4043b4b2770f199bcd63"}
      )

    %{
      kind: "CANONICAL_PROBE_STARTUP_SOURCE_CATALOG_METADATA_ONLY",
      elixir_version: System.version(),
      otp_release: to_string(:erlang.system_info(:otp_release)),
      otp_version: "28.5.0.7",
      system_version: to_string(:erlang.system_info(:system_version)),
      canonical_elixir_root: @elixir,
      canonical_otp_root: @otp,
      executables: executables,
      modules: modules,
      probe_source: probe_source,
      canonical_startup_sources: Enum.map(@startup_sources, &source_identity/1),
      supplemental_metadata_sources: Enum.map(@metadata_sources, &source_identity/1),
      generated_child_spec: inspect(raw),
      public_supervisor_child_spec: inspect(public),
      exact_marker_identity_preserved: true,
      normalized_defaults_from_source: %{
        shutdown: 5_000,
        type: "worker",
        modules: [inspect(Probe)]
      },
      tests_executed: 0,
      owner_or_probe_started: false,
      private_startup_trace: false,
      source_to_beam_reproducibility: "NOT_CLAIMED",
      startup_maximum: "UNPROVED",
      reservation_bytes: nil
    }
    |> Jason.encode!()
    |> IO.puts()
  end

  defp module_identity(module) do
    {:module, ^module} = :code.ensure_loaded(module)
    {:file, loaded_origin} = :code.is_loaded(module)
    loaded_md5_before = apply(module, :module_info, [:md5])
    {^module, object_bytes, object_path} = :code.get_object_code(module)
    disk_bytes = File.read!(object_path)
    {:ok, {^module, object_md5}} = :beam_lib.md5(object_bytes)
    {:ok, {^module, disk_md5}} = :beam_lib.md5(disk_bytes)
    loaded_md5_after = apply(module, :module_info, [:md5])

    true =
      loaded_md5_before === loaded_md5_after and loaded_md5_before === object_md5 and
        object_md5 === disk_md5

    object_sha = hash(object_bytes)
    disk_sha = hash(disk_bytes)
    true = object_sha === disk_sha
    compile_source = apply(module, :module_info, [:compile]) |> Keyword.get(:source)
    compile_source = if compile_source == nil, do: nil, else: to_string(compile_source)

    %{
      module: inspect(module),
      loaded_module_origin: to_string(loaded_origin),
      loaded_module_md5: hex(loaded_md5_before),
      loaded_module_md5_after: hex(loaded_md5_after),
      code_path_object_path: to_string(object_path),
      code_path_object_sha256: object_sha,
      code_path_object_module_md5: hex(object_md5),
      disk_beam_path: to_string(object_path),
      disk_beam_sha256: disk_sha,
      disk_beam_module_md5: hex(disk_md5),
      module_md5_match: true,
      object_disk_sha256_match: true,
      compile_source: compile_source,
      compile_source_sha256:
        if(compile_source != nil and File.regular?(compile_source),
          do: hash(File.read!(compile_source)),
          else: nil
        )
    }
  end

  defp source_identity({path, expected}) do
    actual = hash(File.read!(path))
    if actual !== expected, do: raise("source identity mismatch: " <> path)
    %{path: path, sha256: actual}
  end

  defp resolve_link(path) do
    path
    |> Path.expand()
    |> Path.split()
    |> Enum.reduce("", fn component, parent ->
      current = Path.join(parent, component)

      case File.read_link(current) do
        {:ok, target} -> resolve_link(Path.expand(target, Path.dirname(current)))
        {:error, :einval} -> current
        {:error, reason} -> raise File.Error, reason: reason, action: "resolve", path: current
      end
    end)
  end

  defp hash(bytes), do: :crypto.hash(:sha256, bytes) |> hex()
  defp hex(bytes), do: Base.encode16(bytes, case: :lower)
end

Gaoxy.Proxy.ManagedH2GroupStartupSources.run()
