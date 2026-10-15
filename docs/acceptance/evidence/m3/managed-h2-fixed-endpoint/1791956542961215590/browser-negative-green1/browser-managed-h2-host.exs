
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

defmodule FixedGaoxyIdentity do
  alias HTTPFetch0214Identity, as: Identity
  def record(path) do
    root = File.cwd!() |> Path.expand()
    applications = for app <- [:gaoxy, :gaoxy_http, :gaoxy_proxy] do
      loaded = Application.load(app)
      true = loaded in [:ok, {:error, {:already_loaded, app}}]
      modules = for module <- Application.spec(app, :modules) do
        Code.ensure_loaded!(module)
        {^module, bytes, beam_path} = :code.get_object_code(module)
        beam_path = to_string(beam_path) |> Path.expand()
        true = String.starts_with?(beam_path, root <> "/_build/")
        ^bytes = File.read!(beam_path)
        {:ok, {^module, md5}} = :beam_lib.md5(bytes)
        ^md5 = module.module_info(:md5)
        source = module.module_info(:compile) |> Keyword.fetch!(:source) |> to_string() |> Path.expand()
        true = String.starts_with?(source, Path.join(root, "apps/#{app}") <> "/")
        %{module: to_string(module), beam: Identity.file(beam_path),
          loaded_code_md5: Base.encode16(md5, case: :lower),
          disk_code_md5: Base.encode16(md5, case: :lower), source: Identity.file(source),
          compile_source: source}
      end
      true = modules != []
      %{application: to_string(app), version: to_string(Application.spec(app, :vsn)),
        app: Identity.file(:code.where_is_file(~c"#{app}.app") |> to_string() |> Path.expand()), modules: modules}
    end
    File.write!(path, JSON.encode!(%{pid: System.pid(), root: root, applications: applications}) <> "\n")
  end
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
    FixedGaoxyIdentity.record(Path.join(evidence, "host-gaoxy-before.json"))
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
          options = if command["boundary_limits"] do
            Keyword.update!(options, :http_limits, &Map.merge(&1, %{max_headers: 512,
              max_header_bytes: 131_072, max_trailers: 256, max_trailer_bytes: 131_072}))
          else options end
          options = if command["downstream"] == "h2", do: options ++ [protocols: [:http2], h2c: :prior_knowledge], else: options
          options = if command["downstream_tls"] do
            Keyword.merge(options, protocols: [:http2, :http1], transport: :tls,
              h2c: :disabled, tls: %{certfile: command["cert"], keyfile: command["key"]})
          else
            options
          end
          {:ok, spec} = Gaoxy.HTTP.service_spec(options)
          {spec, allowance} = case command["native_clients"] do
            nil ->
              {spec, %{mode: "DEFAULT", max_bytes: spec.limits.max_bytes, max_active: spec.limits.max_active}}
            clients when is_integer(clients) and clients in 1..33 ->
              true = command["downstream"] == "h2"
              reserves = Gaoxy.HTTP.HTTP2.Limits.reservation(
                spec.handler_options.http_limits, spec.handler_options.h2_limits)
              # Each independent client owns C+Writer+one native stream lease.
              # The upstream scope still has exactly32 request slots/C2/P0.
              bytes = max(536_870_912,
                clients * (reserves.connection + reserves.writer + reserves.stream) + 32 * 9_444_956)
              active = max(64, 3 * clients)
              true = bytes <= 8_589_934_592 and active <= 128
              options = Keyword.update!(options, :limits, &Map.merge(&1, %{max_bytes: bytes, max_active: active}))
              {:ok, expanded} = Gaoxy.HTTP.service_spec(options)
              {expanded, %{mode: "DERIVED_CONCURRENT_NATIVE_CLIENTS", native_clients: clients,
                max_bytes: bytes, max_active: active, native_reservations: reserves,
                upstream_request_slots: 32, upstream_request_reservation: 9_444_956}}
            other -> raise "invalid finite native_clients: #{inspect(other)}"
          end
          {:ok, _} = Gaoxy.add(instance, spec)
          {:ok, {_, port}} = Gaoxy.info(instance, :http).local
          {:ok, service, _} = GenServer.call(instance, {:lookup, :http}, 1000)
          gate = :sys.get_state(service).gate
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
            creators: creators, gate: gate, spec: spec, gate_join: {gate, Process.monitor(gate)},
            native_joins: %{}}
          emit(%{event: "started", port: port, origin: origin, owner: inspect(owner), instance: inspect(instance),
            native_allowance: allowance})
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
        "request_clean" ->
          {state, ledger} = wait_request_clean(state, deadline())
          state = collect_originals(state)
          originals = original_rows(state)
          true = originals != [] and Enum.all?(originals, &(&1.result == ":ok"))
          emit(status(state) |> Map.put(:event, "request_clean") |> Map.put(:originals, originals)
            |> Map.put(:original_repeat, original_rows(state)) |> Map.put(:native_idle, ledger))
          state
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
          native_joins = Enum.map(state.native_joins, fn {pid, ref} -> joined(pid, ref) end)
          {gate, gate_ref} = state.gate_join
          gate_join = joined(gate, gate_ref)
          state = collect_originals(state)
          emit(%{event: "stopped", cleanup_confirmed: confirmed, public_result: inspect(result),
            before: before, retained: retained, originals: original_rows(state),
            original_repeat: original_rows(state), service_failures: state.failures,
            forced_test_disposal: forced, test_disposals: disposals, joins: reasons,
            native_joins: native_joins, gate_join: gate_join})
          nil
        "exit" ->
          nil = state
          HTTPFetch0214Identity.record(Path.join(evidence, "host-loaded-after.json"))
          FixedGaoxyIdentity.record(Path.join(evidence, "host-gaoxy-after.json"))
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
  defp joined(pid, ref) do
    receive do
      {:DOWN, ^ref, :process, ^pid, reason} -> %{pid: inspect(pid), reason: inspect(reason)}
    after 5000 -> raise "native actor join deadline: #{inspect(pid)}" end
  end
  defp idle_ledger(state) do
    gate = :sys.get_state(state.gate)
    reserves = Gaoxy.HTTP.HTTP2.Limits.reservation(
      state.spec.handler_options.http_limits, state.spec.handler_options.h2_limits)
    leases = Enum.to_list(gate.leases)
    native_states = for {_, lease} <- leases, lease.bytes == reserves.connection, into: %{} do
      {_, native} = :sys.get_state(lease.pid, 1000)
      {lease.pid, native}
    end
    diagnostic = for {ref, lease} <- leases do
      native = Map.get(native_states, lease.pid)
      %{pid: inspect(lease.pid), lease: inspect(ref), bytes: lease.bytes,
        request_active: lease.request_active, cleanup: inspect(lease.cleanup), send: inspect(lease.send),
        token: inspect(lease.token), timer: inspect(lease.timer), deadline: lease.deadline,
        native: if(native, do: %{phase: inspect(native.phase), lease: inspect(native.lease),
          writer: inspect(native.writer), preface: native.preface, streams: map_size(native.streams),
          buffer_bytes: byte_size(native.buffer), writer_ready: native.writer_ready}, else: nil)}
    end
    emit(%{event: "native_idle_snapshot", reservations: reserves, leases: diagnostic, status: status(state)})
    connections = for {ref, lease} <- leases, lease.bytes == reserves.connection do
      # This is the documented callback state of Gaoxy.HTTP.Connection, not a
      # private upstream dependency process or an opaque capability interior.
      native = Map.fetch!(native_states, lease.pid)
      true = native.gate == state.gate and native.lease == ref and native.phase == :http2
      true = native.reserves == reserves and native.streams == %{} and native.starting == nil
      true = native.buffer == "" and native.inflight == nil and native.inflight_write == nil
      true = native.outgoing_block == nil and :queue.is_empty(native.output)
      %{pid: lease.pid, writer: native.writer, preface: native.preface, lease: ref}
    end
    true = connections != []
    true = length(Enum.uniq_by(connections, & &1.pid)) == length(connections)
    rows = for {ref, lease} <- leases do
      true = not lease.request_active and lease.cleanup == nil and lease.send == nil
      true = lease.token == nil and lease.timer == nil and lease.deadline == nil and lease.drain_notify
      true = Process.alive?(lease.pid)
      connection = Enum.find(connections, &(&1.pid == lease.pid and &1.lease == ref))
      writer = Enum.find(connections, &(&1.writer == lease.pid))
      cond do
        connection ->
          %{pid: lease.pid, lease: ref, class: "native_h2_connection", bytes: reserves.connection,
            preface: connection.preface, writer: inspect(connection.writer)}
        writer ->
          true = lease.bytes == reserves.writer
          %{pid: lease.pid, lease: ref, class: "native_h2_writer", bytes: reserves.writer,
            connection: inspect(writer.pid)}
        true -> raise "unclassified native idle lease: #{inspect({ref, lease})}"
      end
    end
    writers = Enum.filter(rows, &(&1.class == "native_h2_writer"))
    true = length(writers) == length(connections)
    true = Enum.all?(connections, fn connection ->
      Enum.count(writers, &(&1.pid == connection.writer)) == 1
    end)
    true = length(Enum.uniq_by(rows, & &1.pid)) == length(rows)
    true = map_size(gate.cleanups) == 0
    bytes = Enum.sum(Enum.map(rows, & &1.bytes))
    true = gate.bytes == bytes
    current = status(state)
    true = current.service.active == length(rows) and current.service.retained_bytes == bytes
    true = current.service.cleanup_pending == 0 and current.service.cleanup_failed == nil
    true = match?(%{request_tokens: 0, helpers: 0, pins: 1, resources: 1, reserved_connections: 2}, current.owner)
    true = current.native_scope.active_requests == 0 and current.native_scope.preparing_requests == 0
    true = current.native_scope.pending == 0
    {rows, %{active: length(rows), retained_bytes: bytes, reservations: reserves,
      leases: Enum.map(rows, fn row -> row |> Map.update!(:pid, &inspect/1) |> Map.update!(:lease, &inspect/1) end)}}
  end
  defp wait_request_clean(state, expires) do
    current = status(state)
    settled = current.service.cleanup_pending == 0 and current.service.cleanup_failed == nil and
      match?(%{request_tokens: 0, helpers: 0, pins: 1}, current.owner)
    if settled do
      {rows, ledger} = idle_ledger(state)
      monitors = Enum.reduce(rows, state.native_joins, fn row, monitors ->
        Map.put_new_lazy(monitors, row.pid, fn -> Process.monitor(row.pid) end)
      end)
      {%{state | native_joins: monitors}, ledger}
    else
      if System.monotonic_time(:millisecond) >= expires, do: raise("request cleanup deadline: #{inspect(current)}")
      receive do after 1 -> :ok end
      wait_request_clean(state, expires)
    end
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
