# Parent runs this in the original sanitized baseline Mix environment. Only the
# wrapper module is evaluated; its main/driver entrypoint is never evaluated.
wrapper = System.fetch_env!("TLS95_REGRESSION_WRAPPER")
{:__block__, _, forms} = Code.string_to_quoted!(File.read!(wrapper))
[module] = Enum.filter(forms, &match?({:defmodule, _, _}, &1))
Code.eval_quoted(module)

defmodule TLS95IdentityRegression do
  alias TLS95RuntimeIdentity, as: Identity

  def check(true), do: :ok
  def check(false), do: raise("Regression assertion failed")

  def rejects(fun) do
    check(function_exported?(Identity, :application_manifest, 1))
    check(function_exported?(Identity, :manifest!, 2))
    result =
      try do
        fun.()
        :accepted
      rescue
        error -> {:rejected, error}
      end

    check(match?({:rejected, _}, result))
  end

  def fixture(fun) do
    app = :tls95_identity_fixture
    root = Path.join(__DIR__, "tmp-#{System.pid()}-#{System.unique_integer([:positive])}")
    ebin = Path.join(root, "#{app}-1.0.0/ebin")
    path = Path.join(ebin, "#{app}.app")
    spec = [description: ~c"identity regression", vsn: ~c"1.0.0", modules: [], applications: []]
    File.mkdir_p!(ebin)
    write_app(path, app, spec)
    :ok = :application.load({:application, app, spec})
    true = :code.add_patha(String.to_charlist(ebin))

    try do
      fun.(app, path, spec)
    after
      :code.del_path(String.to_charlist(ebin))
      Application.unload(app)
      File.rm_rf!(root)
    end
  end

  def write_app(path, app, spec) do
    File.write!(path, :io_lib.format(~c"~tp.~n", [{:application, app, spec}]))
  end

  def run do
    # Same cohort load as the parent's successful diagnostic; no fixture driver,
    # TLS peer or request runs. This preserves the actual removed Hex/inets paths.
    Identity.cohort(System.fetch_env!("TLS95_COHORT_VERSION"), File.cwd!())

    cases = [
      {"paired JIT mapping is recorded outside immutable files", fn ->
         maps = "1000-2000 r-xs 00000000 00:01 7 /memfd:vmem (deleted)\n3000-4000 rw-s 00000000 00:01 7 /memfd:vmem (deleted)\n"
         record = Identity.mapping_inventory(maps)
         check(record.files == [])
         check(length(record.jit_exclusions) == 1)
         check(hd(record.jit_exclusions).claim == "Mutable JIT memory; machine-code bytes excluded")
       end},
      {"unknown, unpaired, private, RWX and mismatched JIT rows fail closed", fn ->
         check(function_exported?(Identity, :mapping_inventory, 1))
         rx = "1000-2000 r-xs 00000000 00:01 7 /memfd:vmem (deleted)\n"
         rw = "3000-4000 rw-s 00000000 00:01 7 /memfd:vmem (deleted)\n"
         for maps <- [rx, rw, rx <> String.replace(rw, "vmem", "other"), rx <> String.replace(rw, "rw-s", "rw-p"), String.replace(rx, "r-xs", "rwxs") <> rw, rx <> String.replace(rw, "00:01 7", "00:01 8"), rx <> String.replace(rw, "00:01 7", "00:02 7"), rx <> String.replace(rw, "00000000", "00001000"), rx <> String.replace(rw, "3000-4000", "3000-5000"), "malformed row", rx <> rw <> rw] do
           rejects(fn -> Identity.mapping_inventory(maps) end)
         end
       end},
      {"paired JIT labels without inode separator fail closed", fn ->
         maps = "1000-2000 r-xs 00000000 00:01 7/memfd:vmem (deleted)\n3000-4000 rw-s 00000000 00:01 7/memfd:vmem (deleted)\n"
         rejects(fn -> Identity.mapping_inventory(maps) end)
       end},
      {"ordinary native path spaces retain content identity and missing paths fail", fn ->
         path = Path.join(__DIR__, "native file #{System.pid()}.so")
         maps = "1000-2000 r-xp 00000000 00:01 9 #{path}\n"
         try do
           File.write!(path, "native1")
           first = Identity.mapping_inventory(maps)
           check(first.jit_exclusions == [])
           check(first.files == [%{path: Identity.real(path), sha256: Identity.sha("native1")}])
           File.write!(path, "native2")
           check(Identity.mapping_inventory(maps).files != first.files)
           rejects(fn -> Identity.mapping_inventory(String.replace(maps, path, path <> " (deleted)")) end)
           File.rm!(path)
           rejects(fn -> Identity.mapping_inventory(maps) end)
         after
           File.rm(path)
         end
       end},
      {"actual runtime retains Hex/inets, Mix version and all loaded app code", fn ->
         check(:code.lib_dir(:hex, :ebin) == {:error, :bad_name})
         check(:code.lib_dir(:inets, :ebin) == {:error, :bad_name})
         loaded = Application.loaded_applications() |> Enum.map(&elem(&1, 0)) |> Enum.sort()
         declared = for app <- loaded, mod <- Application.spec(app, :modules), into: MapSet.new(), do: mod
         expected = for {mod, _} <- :code.all_loaded(), MapSet.member?(declared, mod), into: MapSet.new(), do: Atom.to_string(mod)
         IO.puts("TLS95_RAW_JIT_MAPS " <> JSON.encode!(%{rows: File.read!("/proc/#{System.pid()}/maps") |> String.split("\n") |> Enum.filter(&String.contains?(&1, "memfd:"))}))
         runtime = Identity.runtime()
         check(runtime.mix == to_string(Application.spec(:mix, :vsn)))
         check(Enum.map(runtime.applications, & &1.application) == Enum.map(loaded, &Atom.to_string/1))
         actual = MapSet.new(runtime.actual_loaded_modules, & &1.module)
         check(MapSet.subset?(expected, actual))

         for app <- [:hex, :inets] do
           record = Enum.find(runtime.applications, &(&1.application == Atom.to_string(app)))
           check(File.regular?(record.path))
           check(record.sha256 == Identity.sha(File.read!(record.path)))
         end

         for record <- runtime.actual_loaded_modules, Map.has_key?(record, :disk_code_md5) do
           check(record.disk_code_md5 == record.loaded_code_md5)
         end

         check(runtime.mapped_files != [])
         IO.puts("TLS95_REGRESSION_RUNTIME " <> JSON.encode!(%{applications: length(runtime.applications), loaded_modules: length(runtime.actual_loaded_modules), mapped_files: length(runtime.mapped_files), hex: Enum.find(runtime.applications, &(&1.application == "hex")).path, inets: Enum.find(runtime.applications, &(&1.application == "inets")).path}))
       end},
      {"ordinary active manifest", fn ->
         fixture(fn app, path, _ -> check(Identity.application_manifest(app) == path) end)
       end},
      {"removed unknown application path fails closed", fn ->
         fixture(fn app, path, _ ->
           true = :code.del_path(String.to_charlist(Path.dirname(path)))
           rejects(fn -> Identity.application_manifest(app) end)
         end)
       end},
      {"missing manifest fails closed", fn ->
         fixture(fn app, path, _ ->
           File.rm!(path)
           rejects(fn -> Identity.manifest!(app, [path]) end)
         end)
       end},
      {"empty provenance fails closed", fn ->
         fixture(fn app, _, _ -> rejects(fn -> Identity.manifest!(app, []) end) end)
       end},
      {"ambiguous identical manifests fail closed", fn ->
         fixture(fn app, path, _ ->
           other = path <> ".other"
           File.cp!(path, other)
           rejects(fn -> Identity.manifest!(app, [path, other]) end)
         end)
       end},
      {"wrong application name fails closed", fn ->
         fixture(fn app, path, spec ->
           write_app(path, :tls95_wrong_identity, spec)
           rejects(fn -> Identity.manifest!(app, [path]) end)
         end)
       end},
      {"duplicate descriptor key fails closed", fn ->
         fixture(fn app, path, spec ->
           write_app(path, app, spec ++ [vsn: ~c"2.0.0"])
           rejects(fn -> Identity.manifest!(app, [path]) end)
         end)
       end},
      {"malformed descriptor fails closed", fn ->
         fixture(fn app, path, _ ->
           File.write!(path, "not an application descriptor")
           rejects(fn -> Identity.manifest!(app, [path]) end)
         end)
       end},
      {"loaded module and disk origin mismatch fails closed", fn ->
         fixture(fn _, path, _ ->
           copy = path <> ".beam"
           File.cp!(Identity.real(:code.which(Enum)), copy)
           rejects(fn -> Identity.beam(Enum, copy) end)
         end)
       end}
    ]

    drift_cases =
      for {key, value} <- [vsn: ~c"2.0.0", modules: [Enum], applications: [:kernel], included_applications: [:stdlib], optional_applications: [:crypto], description: ~c"changed", mod: {Enum, []}, registered: [:changed], start_phases: []] do
        {"descriptor #{key} drift fails closed", fn ->
          fixture(fn app, path, spec ->
            write_app(path, app, Keyword.put(spec, key, value))
            rejects(fn -> Identity.manifest!(app, [path]) end)
          end)
        end}
      end

    results =
      Enum.map(cases ++ drift_cases, fn {name, fun} ->
        try do
          fun.()
          IO.puts("PASS " <> name)
          :pass
        rescue
          error ->
            IO.puts("FAIL #{name}\n" <> Exception.format(:error, error, __STACKTRACE__))
            :fail
        end
      end)

    failures = Enum.count(results, &(&1 == :fail))
    IO.puts("TLS95_REGRESSION_RESULT " <> JSON.encode!(%{cases: length(results), failures: failures, tls_cases: 0, peer_started: false}))
    if failures > 0, do: raise("#{failures} identity regressions failed")
  end
end

TLS95IdentityRegression.run()
