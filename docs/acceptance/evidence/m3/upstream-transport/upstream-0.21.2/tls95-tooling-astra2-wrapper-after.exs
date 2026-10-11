defmodule TLS95RuntimeIdentity do
  @apps [
    :http_core,
    :http_runtime,
    :http_fetch,
    :http_web_socket,
    :ex_ssl,
    :elixir_quic,
    :elixir_quic_http3,
    :telemetry
  ]

  def sha(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
  def hex(bytes), do: Base.encode16(bytes, case: :lower)

  def real(path, depth \\ 0) do
    true = depth < 40
    parts = Path.expand(to_string(path)) |> Path.split()
    walk(parts, "", depth)
  end

  defp walk([], resolved, _depth), do: resolved

  defp walk([part | rest], prefix, depth) do
    path = if prefix == "", do: part, else: Path.join(prefix, part)

    case File.read_link(path) do
      {:ok, target} ->
        target = Path.expand(target, Path.dirname(path))
        real(Path.join([target | rest]), depth + 1)

      {:error, :einval} ->
        walk(rest, path, depth)

      {:error, reason} ->
        raise "Missing identity path #{path}: #{inspect(reason)}"
    end
  end

  def within!(path, root) do
    resolved = real(path)
    true = resolved == root or String.starts_with?(resolved, root <> "/")
    resolved
  end

  def inputs(path) do
    JSON.decode!(File.read!(path))
    |> Enum.map(fn {input, expected} ->
      true = sha(File.read!(input)) == expected
      %{path: input, real: real(input), sha256: expected}
    end)
    |> Enum.sort_by(& &1.path)
  end

  def beam(mod, path) do
    path = real(path)
    {:module, ^mod} = :code.ensure_loaded(mod)
    true = real(:code.which(mod)) == path
    {:ok, {^mod, disk_md5}} = :beam_lib.md5(String.to_charlist(path))
    loaded_md5 = apply(mod, :module_info, [:md5])
    true = disk_md5 == loaded_md5

    %{
      module: Atom.to_string(mod),
      beam_path: path,
      beam_sha256: sha(File.read!(path)),
      disk_code_md5: hex(disk_md5),
      loaded_code_md5: hex(loaded_md5)
    }
  end

  def cohort(version, root) do
    records =
      Enum.map(@apps, fn app ->
        case Application.load(app) do
          :ok -> :ok
          {:error, {:already_loaded, ^app}} -> :ok
        end

        actual_version = Application.spec(app, :vsn) |> to_string()
        true = actual_version == if(app == :telemetry, do: "1.4.2", else: version)

        ebin =
          within!(:code.lib_dir(app, :ebin), root <> "/_build/test/lib/" <> Atom.to_string(app))

        app_path = Path.join(ebin, "#{app}.app")
        listed = Application.spec(app, :modules) |> Enum.sort()

        disk =
          Path.wildcard(Path.join(ebin, "*.beam"))
          |> Enum.map(&Path.basename(&1, ".beam"))
          |> Enum.sort()

        true = Enum.map(listed, &Atom.to_string/1) |> Enum.sort() == disk

        source_root =
          root <> if(version == "0.21.1", do: "/packages/", else: "/deps/") <> Atom.to_string(app)

        modules =
          Enum.map(listed, fn mod ->
            record = beam(mod, Path.join(ebin, "#{mod}.beam"))

            {:ok, {^mod, [{:compile_info, compile}]}} =
              :beam_lib.chunks(String.to_charlist(record.beam_path), [:compile_info])

            source = within!(Keyword.fetch!(compile, :source), source_root)
            Map.merge(record, %{source: source, source_sha256: sha(File.read!(source))})
          end)

        %{
          application: Atom.to_string(app),
          version: actual_version,
          app_path: real(app_path),
          app_sha256: sha(File.read!(app_path)),
          declared_applications: Application.spec(app, :applications),
          included_applications: Application.spec(app, :included_applications) || [],
          modules: modules
        }
      end)

    allowed =
      for app <- records, mod <- app.modules, into: MapSet.new(), do: {mod.module, mod.beam_path}

    for {mod, path} <- :code.all_loaded(), is_list(path), path != [] do
      origin = real(path)

      if Enum.any?(@apps, &String.starts_with?(origin, root <> "/_build/test/lib/#{&1}/")) do
        true = MapSet.member?(allowed, {Atom.to_string(mod), origin})
      end

      if version == "0.21.1" and
           String.starts_with?(origin, System.fetch_env!("TLS95_PARENT_ROOT") <> "/_build/") do
        raise "Baseline module leaked from parent: #{mod}"
      end
    end

    records
  end

  def application_manifest(app) do
    {paths, removed_path?} =
      case :code.lib_dir(app, :ebin) do
        ebin when is_list(ebin) ->
          {[Path.join(to_string(ebin), "#{app}.app")], false}

        {:error, :bad_name} ->
          # Mix can remove code paths without unloading application metadata or
          # code. Recover only from the running OTP and the frozen copied archive.
          otp_root = real(:code.root_dir())
          version = Application.spec(app, :vsn) |> to_string()
          otp_path = Path.join([otp_root, "lib", "#{app}-#{version}", "ebin", "#{app}.app"])
          otp = if File.exists?(otp_path), do: [within!(otp_path, otp_root)], else: []

          archives =
            if app == :hex do
              true = is_nil(System.get_env("MIX_ARCHIVES"))
              archive_root = real(Path.join(System.fetch_env!("MIX_HOME"), "archives"))

              Path.wildcard(Path.join(archive_root, "*/*/ebin/hex.app"))
              |> Enum.map(&within!(&1, archive_root))
            else
              []
            end

          {otp ++ archives, true}
      end

    path = manifest!(app, paths)

    if removed_path? do
      for mod <- Application.spec(app, :modules), {:file, origin} <- [:code.is_loaded(mod)] do
        case origin do
          :preloaded ->
            :ok

          origin when is_list(origin) and origin != [] ->
            true = real(origin) == Path.join(Path.dirname(path), "#{mod}.beam")

          _ ->
            raise "Application module has no immutable disk origin: #{mod}"
        end
      end
    end

    path
  end

  def manifest!(app, paths) do
    path =
      case paths |> Enum.map(&real/1) |> Enum.uniq() do
        [path] -> path
        candidates -> raise "Expected one manifest for #{app}, got: #{inspect(candidates)}"
      end

    {:ok, [{:application, ^app, disk}]} = :file.consult(String.to_charlist(path))
    true = Keyword.keyword?(disk)
    true = length(Keyword.keys(disk)) == length(Enum.uniq(Keyword.keys(disk)))

    # Public Application.spec/1 omits mutable env and exposes these OTP defaults.
    # Environment remains independently hashed in runtime/0.
    defaults = [
      description: ~c"",
      id: ~c"",
      vsn: ~c"",
      modules: [],
      maxP: :infinity,
      maxT: :infinity,
      registered: [],
      included_applications: [],
      optional_applications: [],
      applications: [],
      mod: [],
      start_phases: :undefined
    ]

    loaded = Application.spec(app)
    true = is_list(loaded)

    for {key, value} <- loaded do
      unless value == Keyword.get(disk, key, Keyword.fetch!(defaults, key)) do
        raise "Loaded application descriptor differs from #{path}: #{key}"
      end
    end

    path
  end

  def runtime do
    started = Application.started_applications() |> Enum.map(&elem(&1, 0)) |> Enum.sort()
    loaded = Application.loaded_applications() |> Enum.map(&elem(&1, 0)) |> Enum.sort()

    applications =
      Enum.map(loaded, fn app ->
        path = application_manifest(app)

        %{
          application: Atom.to_string(app),
          version: Application.spec(app, :vsn) |> to_string(),
          started: app in started,
          path: path,
          sha256: sha(File.read!(path)),
          declared_applications: Application.spec(app, :applications),
          modules: Application.spec(app, :modules) |> Enum.map(&Atom.to_string/1) |> Enum.sort(),
          config_sha256:
            Application.get_all_env(app) |> Enum.sort() |> :erlang.term_to_binary() |> sha()
        }
      end)

    app_modules =
      for app <- loaded, mod <- Application.spec(app, :modules), into: MapSet.new(), do: mod

    modules =
      for {mod, path} <- :code.all_loaded(), MapSet.member?(app_modules, mod) do
        case path do
          :preloaded -> %{module: Atom.to_string(mod), origin: "ERTS_PRELOADED"}
          path when is_list(path) and path != [] -> beam(mod, path)
          _ -> raise "Application module has no immutable disk origin: #{mod}"
        end
      end

    executable = real("/proc/#{System.pid()}/exe")
    maps = File.read!("/proc/#{System.pid()}/maps")

    mapped =
      maps
      |> String.split("\n")
      |> Enum.flat_map(fn line ->
        case String.split(line, ~r/\s+/, parts: 6) do
          [_, _, _, _, _, "/" <> _ = path] -> [path]
          _ -> []
        end
      end)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.map(fn path ->
        %{path: real(path), sha256: sha(File.read!(path))}
      end)

    %{
      elixir: System.version(),
      mix: Application.spec(:mix, :vsn) |> to_string(),
      otp: to_string(:erlang.system_info(:otp_release)),
      erts: to_string(:erlang.system_info(:version)),
      architecture: to_string(:erlang.system_info(:system_architecture)),
      word_bytes: :erlang.system_info(:wordsize),
      executable: executable,
      executable_sha256: sha(File.read!(executable)),
      applications: applications,
      actual_loaded_modules: Enum.sort_by(modules, & &1.module),
      mapped_files: mapped,
      native_claim:
        "Loaded file identity only; not native ABI, allocator or lifetime qualification."
    }
  end

  def capture(version, root, inputs_path) do
    %{
      cohort: version,
      root: root,
      applications: cohort(version, root),
      inputs: inputs(inputs_path),
      runtime: runtime()
    }
  end

  def unchanged!(before, after_record) do
    true = before.applications == after_record.applications
    true = before.inputs == after_record.inputs
    true = before.runtime.applications == after_record.runtime.applications

    for {key, value} <- Map.drop(before.runtime, [:actual_loaded_modules, :mapped_files]) do
      true = value == Map.fetch!(after_record.runtime, key)
    end

    for key <- [:actual_loaded_modules, :mapped_files] do
      true =
        MapSet.subset?(
          MapSet.new(Map.fetch!(before.runtime, key)),
          MapSet.new(Map.fetch!(after_record.runtime, key))
        )
    end
  end

  def outcome(fun) do
    try do
      {:ok, fun.()}
    catch
      kind, reason -> {:error, kind, reason, __STACKTRACE__}
    end
  end

  def main do
    version = System.fetch_env!("TLS95_COHORT_VERSION")
    true = version in ["0.21.1", "0.21.2"]
    root = real(System.fetch_env!("TLS95_COHORT_ROOT"))
    true = root == real(File.cwd!())
    driver = real(System.fetch_env!("HTTP_FETCH_TLS95_DRIVER"))
    inputs_path = System.fetch_env!("HTTP_FETCH_TLS95_INPUTS")
    {:ok, _} = Application.ensure_all_started(:http_fetch)
    before = capture(version, root, inputs_path)
    IO.puts("TLS95_IDENTITY_BEFORE " <> JSON.encode!(before))
    primary = outcome(fn -> Code.require_file(driver) end)

    post =
      outcome(fn ->
        after_record = capture(version, root, inputs_path)
        unchanged!(before, after_record)

        IO.puts(
          "TLS95_IDENTITY_AFTER " <>
            JSON.encode!(Map.put(after_record, :static_inputs_unchanged, true))
        )
      end)

    IO.puts(
      "TLS95_WRAPPER_OUTCOME " <>
        JSON.encode!(%{
          primary: describe(primary),
          post_identity: describe(post)
        })
    )

    case primary do
      {:error, kind, reason, stack} ->
        :erlang.raise(kind, reason, stack)

      {:ok, _} ->
        case post do
          {:ok, _} -> :ok
          {:error, kind, reason, stack} -> :erlang.raise(kind, reason, stack)
        end
    end
  end

  defp describe({:ok, _}), do: %{status: "OK"}

  defp describe({:error, kind, reason, stack}),
    do: %{
      status: "ERROR",
      kind: to_string(kind),
      reason: inspect(reason, limit: :infinity),
      stack: Exception.format_stacktrace(stack)
    }
end

TLS95RuntimeIdentity.main()
