
defmodule HTTPFetch0214Identity do
  @packages ~w(http_core http_runtime http_fetch http_web_socket ex_ssl elixir_quic elixir_quic_http3)a
  def digest(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)
  def file(path), do: %{path: path, sha256: digest(File.read!(path))}
  def capture do
    applications = Enum.map(@packages, fn app ->
      loaded = Application.load(app)
      true = loaded in [:ok, {:error, {:already_loaded, app}}]
      "0.21.4" = version = to_string(Application.spec(app, :vsn))
      app_path = :code.where_is_file(~c"#{app}.app") |> to_string()
      modules = Enum.map(Application.spec(app, :modules), fn module ->
        Code.ensure_loaded!(module)
        {^module, bytes, path} = :code.get_object_code(module)
        path = to_string(path)
        ^bytes = File.read!(path)
        {:ok, {^module, md5}} = :beam_lib.md5(bytes)
        ^md5 = module.module_info(:md5)
        compile_source = module.module_info(:compile) |> Keyword.fetch!(:source) |> to_string()
        [_prefix, relative] = String.split(compile_source, "/deps/#{app}/")
        source = Path.expand(Path.join("deps/#{app}", relative))
        true = String.starts_with?(source, Path.expand("deps/#{app}") <> "/")
        source_hash = digest(File.read!(source))
        compile_source_hash =
          if File.regular?(compile_source), do: digest(File.read!(compile_source)), else: nil
        true = is_nil(compile_source_hash) or compile_source_hash == source_hash
        %{module: to_string(module), beam_path: path, beam_sha256: digest(bytes),
          loaded_code_md5: Base.encode16(md5, case: :lower),
          disk_code_md5: Base.encode16(md5, case: :lower),
          source: source, source_sha256: source_hash,
          compile_source: compile_source, compile_source_sha256: compile_source_hash}
      end)
      true = modules != []
      %{application: to_string(app), version: version, app: file(app_path), modules: modules}
    end)
    mapped = File.read!("/proc/self/maps") |> String.split("\n", trim: true)
    paths = Enum.flat_map(mapped, fn line ->
      case String.split(line, ~r/\s+/, parts: 6) do
        [_, _, _, _, _, "/" <> _ = path] ->
          if String.ends_with?(path, " (deleted)") do
            true = String.starts_with?(path, "/memfd:vmem")
            []
          else
            [path]
          end
        _ -> []
      end
    end) |> Enum.uniq() |> Enum.sort()
    files = Enum.map(paths, &file/1)
    true = Enum.any?(paths, &String.ends_with?(&1, "/crypto.so"))
    true = Enum.any?(paths, &String.contains?(&1, "/libcrypto.so"))
    %{applications: applications, mapped_files: files,
      beam_executable: file(File.read_link!("/proc/self/exe")),
      pid: System.pid(), elixir: System.version(), otp: System.otp_release(),
      erts: to_string(:erlang.system_info(:version)), architecture: to_string(:erlang.system_info(:system_architecture)),
      native_claim: "Actual loaded file identity; excludes mutable JIT/anonymous memory; no memory certification"}
  end
  def record(path), do: File.write!(path, JSON.encode!(capture()) <> "\n")
end

defmodule PublicCapacityWitness do
 def emit(value), do: IO.puts("CAPACITY_WITNESS " <> JSON.encode!(value))
 def run do
  [dir] = System.argv()
  HTTPFetch0214Identity.record(Path.join(dir,"loaded-before.json"))
  emit(%{event: "ready", elixir: System.version(), otp: System.otp_release()})
  Enum.reduce(IO.stream(:stdio,:line), %{scope: nil, promises: %{}}, fn line,state ->
   cmd = JSON.decode!(line)
   case cmd["op"] do
    "open" ->
     nil = state.scope
     origin = "http://localhost:#{cmd["port"]}"
     {:ok,scope} = HTTP.ManagedTransport.open(origin: origin, connect_address: {127,0,0,1},
       http_version: :h2c, tls_backend: :ssl, http2_profile: :native_v1,
       max_requests: 32, max_connections: 2, max_pending: 0, idle_timeout: 5000)
     emit(%{event: "opened"})
     Map.merge(state,%{scope: scope,origin: origin})
    "fetch" ->
     p=HTTP.fetch(state.origin<>cmd["target"],transport_scope: state.scope,
       redirect: :manual, decode_body: false, stream_response: true,
       timeout: 10000, connect_timeout: 5000)
     original=HTTP.Promise.completion(p)
     true=match?(%HTTP.RequestCompletion{},original)
     emit(%{event: "fetch_started",id: cmd["id"], original_completion_bound: true})
     %{state|promises: Map.put(state.promises,cmd["id"],{p,original})}
    "snapshot" ->
     {:ok,s}=HTTP.ManagedTransport.snapshot(state.scope,1000)
     emit(%{event: "snapshot",active_requests: s.active_requests, preparing_requests: s.preparing_requests,
       connections: s.connections, pending: s.pending,limits: s.limits})
     state
    "await" ->
     {p,original}=Map.fetch!(state.promises,cmd["id"])
     result=HTTP.Promise.await(p,5000)
     true=HTTP.Promise.completion(p) === original
     detail=case result do
       {:error,{:transport_scope_capacity,:connections}} ->
        %{raw_result: inspect(result),exact_capacity_connections: true}
       %HTTP.Response{status: 200}=response ->
        ""=body=HTTP.Response.read_all(response)
        %{status: response.status,body_bytes: byte_size(body),http_version: inspect(response.http_version)}
     end
     :ok=HTTP.RequestCompletion.await(original,5000)
     :ok=HTTP.RequestCompletion.await(original,0)
     emit(Map.merge(detail,%{event: "result", id: cmd["id"],original_completion_unchanged: true,cleanup: ":ok", repeated_cleanup: ":ok"}))
     state
    "retire" ->
     {:ok,receipt}=HTTP.ManagedTransport.retire(state.scope,mode: :graceful)
     :ok=HTTP.ManagedTransport.await_retired(receipt,5000)
     :ok=HTTP.ManagedTransport.await_retired(receipt,0)
     emit(%{event: "retired",result: ":ok",repeated: ":ok"})
     state
    "exit" ->
     HTTPFetch0214Identity.record(Path.join(dir,"loaded-after.json"))
     emit(%{event: "exited"})
     state
   end
  end)
 end
end
PublicCapacityWitness.run()
