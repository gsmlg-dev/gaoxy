
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

defmodule FixedManagedH2Host do
  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports
  def deadline, do: System.monotonic_time(:millisecond) + 5000
  def emit(value), do: IO.puts("FIXED_H2_HOST " <> JSON.encode!(value))
  def run(evidence) do
    for app <- [:http_core, :http_runtime, :http_fetch] do
      {:ok, _} = Application.ensure_all_started(app)
    end
    HTTPFetch0214Identity.record(Path.join(evidence, "host-loaded-before.json"))
    emit(%{event: "ready", elixir: System.version(), otp: System.otp_release(), pid: System.pid()})
    state = Enum.reduce(IO.stream(:stdio, :line), nil, fn line, state ->
      command = JSON.decode!(line)
      case command["op"] do
        "start" ->
          nil = state
          protocol = case command["protocol"] do "tls" -> :http2; "h2c" -> :h2c end
          {:ok, instance} = Gaoxy.start_link()
          Process.unlink(instance)
          {:ok, owner} = Transports.start_link(instance: instance,
            limits: %{max_resources: 2, max_pins: 256, max_request_tokens: 64,
              max_owned_payload_bytes: 4_194_304})
          Process.unlink(owner)
          caller = self()
          debug = fn state, event, _ ->
            case event do
              {:in, {:"$gen_call", _, {:bind_completion, _, token, completion}}} ->
                send(caller, {:fixed_h2_original, token, completion})
              _ -> :ok
            end
            state
          end
          :ok = :sys.install(owner, {make_ref(), debug, nil})
          scheme = if protocol == :http2, do: "https", else: "http"
          origin = scheme <> "://" <> Map.get(command, "hostname", "localhost") <> ":#{command["port"]}"
          trust = if protocol == :http2 do
            for {:Certificate, der, :not_encrypted} <- :public_key.pem_decode(File.read!(command["ca"])), do: der
          end
          {:ok, handle, preparation} = Transports.prepare(owner,
            %{protocol: protocol, origin: origin, connect_address: {127,0,0,1}, trust: trust}, self(), deadline())
          {:ok, pins} = Resources.pin_many([handle], self(), :baseline, deadline())
          :ok = Resources.release(preparation)
          options = [id: :http, endpoint: {Gaoxy.Proxy.HTTP, %{upstream: origin,
            upstream_protocol: protocol, transport: handle}},
            limits: %{max_bytes: 536_870_912, max_active: 64},
            http_limits: %{request_timeout: 10_000, write_timeout: 2000}]
          options = if command["downstream"] == "h2", do: options ++ [protocols: [:http2], h2c: :prior_knowledge], else: options
          options = if command["downstream_tls"] do
            Keyword.merge(options, protocols: [:http2, :http1], transport: :tls,
              h2c: :disabled, tls: %{certfile: command["cert"], keyfile: command["key"]})
          else
            options
          end
          {:ok, spec} = Gaoxy.HTTP.service_spec(options)
          {:ok, _} = Gaoxy.add(instance, spec)
          {:ok, {_, port}} = Gaoxy.info(instance, :http).local
          {:ok, service, _} = GenServer.call(instance, {:lookup, :http}, 1000)
          service_debug = fn seen, event, _ ->
            case event do
              {:noreply, %{cleanup_failed: :cleanup_receipt_missing} = service_state} when not seen ->
                send(caller, {:fixed_h2_service_failure, %{failure: "cleanup_receipt_missing",
                  pending: map_size(service_state.cleanups)}})
                true
              _ -> seen
            end
          end
          :ok = :sys.install(service, {make_ref(), service_debug, false})
          scope = :sys.get_state(owner).records[handle.resource].scope
          creators = :sys.get_state(owner).records |> Map.values() |> Enum.map(& &1.custodian)
          joins = Enum.map([instance, owner | creators], &{&1, Process.monitor(&1)})
          state = %{instance: instance, owner: owner, pins: pins, origin: origin,
            scope: scope, originals: %{}, reported: MapSet.new(), failures: [], joins: joins,
            creators: creators}
          emit(%{event: "started", port: port, origin: origin, owner: inspect(owner), instance: inspect(instance)})
          state
        "status" -> emit(status(state)); state
        "observe" ->
          state = collect_originals(state)
          emit(status(state) |> Map.put(:event, "observed")
            |> Map.put(:originals, original_rows(state))
            |> Map.put(:original_repeat, original_rows(state))
            |> Map.put(:service_failures, state.failures))
          state
        "clean" ->
          wait_clean(state, deadline())
          state = collect_originals(state)
          originals = original_rows(state)
          true = originals != [] and Enum.all?(originals, &(&1.result == ":ok"))
          emit(status(state) |> Map.put(:event, "clean") |> Map.put(:originals, originals))
          %{state | reported: MapSet.new(Map.keys(state.originals))}
        "stop" ->
          state = collect_originals(state)
          before = status(state)
          creators = state.creators
          joins = state.joins
          for pin <- state.pins, do: :ok = Resources.release(pin)
          result = Gaoxy.stop(state.instance, 5000)
          confirmed = result == :ok
          retained = if Process.alive?(state.owner), do: elem(Transports.status(state.owner), 1), else: nil
          forced = not confirmed and Process.alive?(state.owner)
          disposals = if forced do
            for pid <- creators ++ [state.owner], Process.alive?(pid) do
              :ok = GenServer.stop(pid, :normal, 5000)
              %{pid: inspect(pid), outcome: "TEST_OWNED_DISPOSAL_AFTER_UNCONFIRMED_PUBLIC_STOP"}
            end
          else [] end
          reasons = Enum.map(joins, fn {pid, ref} ->
            receive do
              {:DOWN, ^ref, :process, ^pid, reason} -> %{pid: inspect(pid), reason: inspect(reason)}
            after 5000 -> raise "host actor join deadline" end
          end)
          state = collect_originals(state)
          emit(%{event: "stopped", cleanup_confirmed: confirmed, public_result: inspect(result),
            before: before, retained: retained, originals: original_rows(state),
            original_repeat: original_rows(state), service_failures: state.failures,
            forced_test_disposal: forced, test_disposals: disposals, joins: reasons})
          nil
        "exit" ->
          nil = state
          HTTPFetch0214Identity.record(Path.join(evidence, "host-loaded-after.json"))
          emit(%{event: "exited"})
          System.halt(0)
      end
    end)
    if state != nil, do: raise("host stdin ended with live fixture")
  end
  defp status(state) do
    {:ok, owner} = Transports.status(state.owner)
    service = Gaoxy.status(state.instance, :http)
    service = case service do
      %{} -> Map.take(service, [:active, :cleanup_pending, :retained_bytes, :cleanup_failed, :state])
        |> Map.update(:cleanup_failed, nil, fn reason -> if reason == nil, do: nil, else: inspect(reason) end)
      other -> %{public_result: inspect(other)}
    end
    snapshot = case HTTP.ManagedTransport.snapshot(state.scope, 1000) do
      {:ok, snapshot} -> snapshot
      other -> %{public_result: inspect(other)}
    end
    %{event: "status", service: service, owner: owner, native_scope: snapshot}
  end
  defp collect_originals(state) do
    receive do
      {:fixed_h2_original, token, completion} ->
        collect_originals(%{state | originals: Map.put(state.originals, token, completion)})
      {:fixed_h2_service_failure, failure} ->
        collect_originals(%{state | failures: [failure | state.failures]})
    after 0 -> state
    end
  end
  defp original_rows(state) do
    for {token, completion} <- state.originals, not MapSet.member?(state.reported, token) do
      %{token: inspect(token), result: inspect(HTTP.RequestCompletion.await(completion, 0))}
    end |> Enum.sort_by(& &1.token)
  end
  defp wait_clean(state, expires) do
    current = status(state)
    clean = match?(%{active: 0, cleanup_pending: 0, retained_bytes: 0, cleanup_failed: nil}, current.service) and
      match?(%{request_tokens: 0, helpers: 0, pins: 1, resources: 1, reserved_connections: 2}, current.owner)
    unless clean do
      if System.monotonic_time(:millisecond) >= expires, do: raise("clean deadline: #{inspect(current)}")
      receive do after 1 -> :ok end
      wait_clean(state, expires)
    end
  end
end
[evidence] = System.argv()
FixedManagedH2Host.run(evidence)
