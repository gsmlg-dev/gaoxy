packages = ~w(http_core http_runtime http_fetch http_web_socket ex_ssl elixir_quic elixir_quic_http3)a
versions = Map.new(packages, fn app ->
  loaded = Application.load(app)
  true = loaded in [:ok, {:error, {:already_loaded, app}}]
  "0.21.4" = version = to_string(Application.spec(app, :vsn))
  {app, version}
end)
modules = [HTTP.ManagedTransport, HTTP.RequestCompletion, HTTP.Promise, HTTP.Stream,
           HTTP.Response, HTTP.Headers, Gaoxy.Proxy.UpstreamTransports,
           Gaoxy.Proxy.ManagedH2Preparation, Gaoxy.Proxy.ManagedH2Reservation,
           Gaoxy.Proxy.HTTP, Gaoxy.Proxy.HTTP.Session, Gaoxy.HTTP.Generation]
loaded = Map.new(modules, fn module ->
  {:module, ^module} = Code.ensure_loaded(module)
  {^module, bytes, path} = :code.get_object_code(module)
  {module, %{beam: to_string(path),
             disk_sha256: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower),
             loaded_md5: Base.encode16(:code.module_md5(module), case: :lower)}}
end)
identity = %{kind: :FIXED_H2_KICKOFF_ENVIRONMENT, status: :PASS,
  versions: versions, modules: loaded, elixir: System.version(), otp: System.otp_release(),
  erts: to_string(:erlang.system_info(:version)), architecture: to_string(:erlang.system_info(:system_architecture)),
  schedulers: :erlang.system_info(:schedulers_online), environment: Map.new(~w(ERL_FLAGS MIX_ENV), &{&1, System.get_env(&1)})}
[directory] = System.argv()
File.write!(Path.join(directory, "kickoff-environment.json"), JSON.encode!(identity) <> "\n")
IO.puts(JSON.encode!(identity))
