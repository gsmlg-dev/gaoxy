Code.require_file("managed_h1_lease_model.exs", __DIR__)

defmodule Gaoxy.Qualification.ManagedH1AccountingFixture do
  @moduledoc """
  Public H1 functional fixture. Public cleanup is recorded separately from the
  symbolic native frontier, which this fixture cannot establish.
  """
  alias Gaoxy.Qualification.ManagedH1LeaseModel, as: Model
  alias Gaoxy.Proxy.ManagedH1Preparation, as: Preparation
  @apps [:http_core, :http_fetch, :http_runtime, :http_web_socket, :ex_ssl, :elixir_quic, :elixir_quic_http3]
  @audit Path.expand("../../.audit/m3-transport/h1-slice-b-implementation", __DIR__)
  @ids Enum.map(1..20, &("B" <> String.pad_leading(to_string(&1), 2, "0")))

  def configure!(args) do
    case args do
      [] -> :ok
      ["--baseline"] -> :ok
      ["--tls-connecting", "--tls95-gate", _] ->
        IO.puts("H1_ACCOUNTING_FIXTURE_GATE " <> JSON.encode!(%{status: "BLOCKED_TOOLING", case: "B21", registered: 0}))
        raise "BLOCKED_TOOLING: actual TLS95 qualification required before B21 implementation"
      _ -> raise "invalid fixture flags"
    end

    ensure(Application.get_env(:http_fetch, :telemetry) == false, :http_fetch_telemetry)
    ensure(Application.get_env(:http_runtime, :telemetry) == false, :http_runtime_telemetry)
    ensure(Enum.all?(@apps, &(to_string(Application.spec(&1, :vsn)) == "0.21.2")), :cohort)
    python = System.fetch_env!("HTTP_FETCH_PEER_PYTHON")
    ensure(Path.type(python) == :absolute and File.regular?(python), :python_identity)
    File.mkdir_p!(@audit)
    identity = identity(python)
    File.write!(Path.join(@audit, "run-identity.json"), JSON.encode!(identity))
    File.write!(Path.join(@audit, "run-origin"), to_string(now()))
    ExUnit.start(autorun: false, max_cases: 1, seed: 21_112_026, timeout: 35_000, include: [], exclude: [])
  end

  def finish!(totals) do
    run_origin = File.read!(Path.join(@audit, "run-origin")) |> String.to_integer()
    rows = Enum.map(@ids, fn id ->
      case File.read(Path.join(@audit, id <> "-result.json")) do
        {:ok, data} ->
          row = JSON.decode!(data)
          if row["run_origin"] == run_origin and row["id"] == id,
            do: row, else: %{"id" => id, "status" => "NOT_CURRENT_RUN"}
        {:error, _} -> %{"id" => id, "status" => "NOT_RUN"}
      end
    end)
    summary = %{run_origin: run_origin, tests: totals.total, failures: totals.failures, skipped: totals.skipped,
      excluded: totals.excluded, ids: Enum.map(rows, & &1["id"]),
      cases_passed: Enum.count(rows, &(&1["status"] == "PASS_FUNCTIONAL")),
      accounting: "ACCOUNTING_BLOCKED_INPUT", native_frontier: "unestablished",
      identity_sha256: sha256(File.read!(Path.join(@audit, "run-identity.json"))),
      case_rows: Enum.map(rows, &Map.take(&1, ["id", "status", "joins", "outstanding_controls"]))}
    IO.puts("H1_ACCOUNTING_FIXTURE_SUMMARY " <> JSON.encode!(summary))
    File.write!(Path.join(@audit, "summary.json"), JSON.encode!(summary))
    ensure(totals.total == 20 and totals.failures == 0 and totals.skipped == 0 and totals.excluded == 0 and summary.cases_passed == 20, :baseline20)
  end

  def sha256(data), do: :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  def pattern_sha256(n), do: pattern_hash(0, n, :crypto.hash_init(:sha256))
  defp pattern_hash(offset, n, hash) when offset >= n, do: Base.encode16(:crypto.hash_final(hash), case: :lower)
  defp pattern_hash(offset, n, hash) do
    piece = for i <- offset..(min(offset + 8192, n) - 1), into: <<>>, do: <<rem(i, 251)>>
    pattern_hash(offset + byte_size(piece), n, :crypto.hash_update(hash, piece))
  end
  def upload_sha256 do
    :crypto.hash_init(:sha256)
    |> :crypto.hash_update(:binary.copy("X", 65_536))
    |> :crypto.hash_update(:binary.copy("Y", 65_536))
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end
  def now, do: System.monotonic_time(:millisecond)
  def remaining(deadline), do: max(deadline - now(), 0)
  def ensure(true, _), do: :ok
  def ensure(false, reason), do: raise(Atom.to_string(reason))

  defp identity(python) do
    modules = [HTTP, HTTP.Promise, HTTP.RequestCompletion, HTTP.ManagedTransport, HTTP.Stream,
      HTTP.Headers, HTTP.Request, HTTP.HTTP1, Preparation, Gaoxy.Proxy.ManagedH1Accounting]
    beams = Enum.map(modules, fn module ->
      {:module, ^module} = Code.ensure_loaded(module)
      {^module, binary, file} = :code.get_object_code(module)
      {:ok, [{^module, disk_md5}]} = :beam_lib.md5(binary)
      ensure(module.module_info(:md5) == disk_md5, :loaded_beam_identity)
      origin = Path.expand(to_string(:code.which(module)))
      ensure(origin == Path.expand(to_string(file)), :beam_origin)
      %{module: Atom.to_string(module), origin: origin, sha256: sha256(binary), loaded_md5: Base.encode16(disk_md5, case: :lower)}
    end)
    priv = Enum.flat_map(@apps, fn app ->
      case :code.priv_dir(app) do
        {:error, :bad_name} -> []
        path ->
          Path.wildcard(Path.join(to_string(path), "**/*"))
          |> Enum.filter(&File.regular?/1)
          |> Enum.map(&%{origin: &1, sha256: sha256(File.read!(&1))})
      end
    end)
    inventory = JSON.decode!(File.read!("docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.2/h1-fixture-spec-inventory.json"))
    runtime_paths = Enum.sort(inventory["runtime_source_paths"])
    ensure(length(runtime_paths) == 175 and length(Enum.uniq(runtime_paths)) == 175, :runtime_manifest)
    sources = Enum.map(runtime_paths, &%{path: &1, sha256: sha256(File.read!(&1))})
    own = Enum.map(["managed_h1_accounting_fixture.exs", "managed_h1_accounting_fixture_test.exs", "managed_h1_accounting_peer.py", "managed_h1_lease_model.exs"], fn name ->
      %{path: name, sha256: sha256(File.read!(Path.join(__DIR__, name)))}
    end)
    %{cohort: "0.21.2", versions: Map.new(@apps, &{&1, to_string(Application.spec(&1, :vsn))}),
      otp: System.otp_release(), erts: to_string(:erlang.system_info(:version)), elixir: System.version(),
      python: %{origin: python, sha256: sha256(File.read!(python))}, beams: beams,
      native_origins: priv, runtime_sources_count: length(sources), runtime_sources_sha256: sha256(JSON.encode!(sources)),
      source: own, telemetry: %{http_fetch: false, http_runtime: false}}
  end

  defmodule Ledger do
    use GenServer
    alias Gaoxy.Qualification.ManagedH1LeaseModel, as: Model
    alias Gaoxy.Qualification.ManagedH1AccountingFixture, as: Fixture
    def start(case_id), do: GenServer.start(__MODULE__, case_id)
    def init(case_id) do
      {:ok, model} = Model.new(0)
      {:ok, %{case: case_id, t0: nil, model: model, generations: List.to_tuple(List.duplicate(nil, 4)),
        actors: List.to_tuple(List.duplicate(nil, 665)), operation: 0, fetches: 0, admission: true, context: nil}}
    end
    def handle_call(:start_clock, _, state) do
      origin = Fixture.now()
      {:reply, origin, %{state | t0: origin}}
    end
    def handle_call(:state, _, state), do: {:reply, state, state}
    def handle_call(:context, _, state), do: {:reply, state.context, state}
    def handle_call({:context, context}, _, state), do: {:reply, :ok, %{state | context: context}}
    def handle_call({:upload, {:attempt, {:generation, gi, _}, ai, _} = token, stream}, _, state) do
      generation = elem(state.generations, gi)
      row = elem(generation.attempts, ai)
      Fixture.ensure(row.token == token and row.upload == nil, :upload_registration)
      monitor = Process.monitor(stream)
      row = %{row | upload: stream, upload_monitor: monitor, upload_status: :alive}
      generation = %{generation | attempts: put_elem(generation.attempts, ai, row)}
      {:reply, :ok, %{state | generations: put_elem(state.generations, gi, generation)}}
    end
    def handle_call({:join, deadline}, _, state) do
      state = join(state, deadline)
      {:reply, state, state}
    end
    def handle_call({:actor_join, index, deadline}, _, state) do
      state = join_actor(state, index, deadline)
      {:reply, elem(state.actors, index).status, state}
    end
    def handle_call(:close_admission, _, state), do: {:reply, :ok, %{state | admission: false}}
    def handle_call({:event, event}, _, state) do
      case Model.step(state.model, event) do
        {:ok, model, result} -> {:reply, {:ok, result}, %{state | model: model}}
        {:error, reason, _} -> {:reply, {:error, reason}, state}
      end
    end
    def handle_call({:generation, token, row}, _, state) do
      {:generation, index, _} = token
      ensure_empty = is_nil(elem(state.generations, index))
      Fixture.ensure(ensure_empty, :generation_row)
      {:reply, :ok, %{state | generations: put_elem(state.generations, index, row)}}
    end
    def handle_call({:get_generation, {:generation, index, _}}, _, state), do: {:reply, elem(state.generations, index), state}
    def handle_call({:put_generation, {:generation, index, _}, key, value}, _, state) do
      row = elem(state.generations, index)
      Fixture.ensure(Map.has_key?(row, key), :generation_key)
      {:reply, :ok, %{state | generations: put_elem(state.generations, index, Map.put(row, key, value))}}
    end
    def handle_call({:attempt, {:attempt, {:generation, gi, _}, ai, _} = token, row}, _, state) do
      generation = elem(state.generations, gi)
      previous = elem(generation.attempts, ai)
      Fixture.ensure(is_nil(previous) or previous.local_released, :attempt_row_occupied)
      row = Map.put(row, :token, token)
      generation = %{generation | attempts: put_elem(generation.attempts, ai, row)}
      {:reply, :ok, %{state | generations: put_elem(state.generations, gi, generation)}}
    end
    def handle_call({:get_attempt, {:attempt, {:generation, gi, _}, ai, _}}, _, state), do: {:reply, elem(elem(state.generations, gi).attempts, ai), state}
    def handle_call({:put_attempt, {:attempt, {:generation, gi, _}, ai, _} = token, key, value}, _, state) do
      generation = elem(state.generations, gi)
      row = elem(generation.attempts, ai)
      if row.token == token do
        Fixture.ensure(Map.has_key?(row, key), :attempt_key)
        row = Map.put(row, key, value)
        generation = %{generation | attempts: put_elem(generation.attempts, ai, row)}
        {:reply, :ok, %{state | generations: put_elem(state.generations, gi, generation)}}
      else
        {:reply, :stale, state}
      end
    end
    def handle_call({:register, token, promise, completion}, _, state) do
      {:attempt, {:generation, gi, _}, ai, _} = token
      generation = elem(state.generations, gi)
      row = elem(generation.attempts, ai)
      Fixture.ensure(row.token == token and row.promise == nil, :original_registration)
      row = %{row | promise: promise, completion: completion}
      generation = %{generation | attempts: put_elem(generation.attempts, ai, row)}
      {:reply, :registered, %{state | generations: put_elem(state.generations, gi, generation), fetches: state.fetches + 1}}
    end
    def handle_call({:actor, index, role, owner}, _, state) when index in 0..664 do
      case elem(state.actors, index) do
        nil ->
          coordinator = self()
          {pid, monitor} = spawn_monitor(fn -> Fixture.actor_loop(coordinator, role, owner, %{}) end)
          actor = %{pid: pid, monitor: monitor, role: role, owner: owner, status: :alive, operation: nil}
          {:reply, pid, %{state | actors: put_elem(state.actors, index, actor)}}
        %{status: :alive, pid: pid} -> {:reply, pid, state}
        _ -> {:reply, {:error, :consumed_actor_slot}, state}
      end
    end
    def handle_call({:command, index}, _, state) do
      actor = elem(state.actors, index)
      Fixture.ensure(actor.status == :alive and is_nil(actor.operation), :actor_in_flight)
      operation = state.operation + 1
      actor = %{actor | operation: operation}
      {:reply, {actor.pid, operation}, %{state | actors: put_elem(state.actors, index, actor), operation: operation}}
    end
    def handle_call({:ack, index, operation}, _, state) do
      actor = elem(state.actors, index)
      Fixture.ensure(actor.operation == operation, :actor_ack)
      {:reply, :ok, %{state | actors: put_elem(state.actors, index, %{actor | operation: nil})}}
    end
    def handle_info({:DOWN, monitor, :process, pid, reason}, state) do
      actors = state.actors |> Tuple.to_list() |> Enum.map(fn
        %{monitor: ^monitor, pid: ^pid} = actor -> %{actor | status: reason}
        actor -> actor
      end) |> List.to_tuple()
      generations = state.generations |> Tuple.to_list() |> Enum.map(fn
        nil -> nil
        generation ->
          attempts = generation.attempts |> Tuple.to_list() |> Enum.map(fn
            %{upload_monitor: ^monitor} = row -> %{row | upload_status: reason}
            row -> row
          end) |> List.to_tuple()
          %{generation | attempts: attempts}
      end) |> List.to_tuple()
      {:noreply, %{state | actors: actors, generations: generations}}
    end
    defp join(state, deadline) do
      pending = Enum.any?(Tuple.to_list(state.actors), &match?(%{status: :alive}, &1)) or
        Enum.any?(Tuple.to_list(state.generations), fn
          nil -> false
          g -> Enum.any?(Tuple.to_list(g.attempts), &match?(%{upload_status: :alive}, &1))
        end)
      if pending and Fixture.remaining(deadline) > 0 do
        receive do
          {:DOWN, _, :process, _, _} = down ->
            {:noreply, state} = handle_info(down, state)
            join(state, deadline)
        after
          Fixture.remaining(deadline) -> state
        end
      else
        state
      end
    end
    defp join_actor(state, index, deadline) do
      if elem(state.actors, index).status == :alive and Fixture.remaining(deadline) > 0 do
        receive do
          {:DOWN, _, :process, _, _} = down ->
            {:noreply, state} = handle_info(down, state)
            join_actor(state, index, deadline)
        after
          Fixture.remaining(deadline) -> state
        end
      else
        state
      end
    end
  end

  defp call(ctx, message), do: GenServer.call(ctx.ledger, message, max(remaining(ctx.shutdown), 1))
  defp event(ctx, message), do: call(ctx, {:event, message})
  defp applied(ctx, message) do
    {:ok, result} = event(ctx, message)
    result
  end
  defp generation(ctx, token), do: call(ctx, {:get_generation, token})
  defp attempt(ctx, token), do: call(ctx, {:get_attempt, token})
  defp put_g(ctx, token, key, value), do: call(ctx, {:put_generation, token, key, value})
  defp put_a(ctx, token, key, value), do: call(ctx, {:put_attempt, token, key, value})
  defp gslot({:generation, slot, _}), do: slot
  defp aslot({:attempt, _, slot, _}), do: slot
  defp wire_slot({:attempt, generation, slot, _}), do: gslot(generation) * 32 + slot
  defp gen_of({:attempt, generation, _, _}), do: generation
  defp role_index(g, :custodian, _), do: gslot(g) * 166
  defp role_index(g, :source, a), do: gslot(g) * 166 + 1 + aslot(a)
  defp role_index(g, :producer, a), do: gslot(g) * 166 + 33 + aslot(a)
  defp role_index(g, :consumer, a), do: gslot(g) * 166 + 65 + aslot(a)
  defp role_index(g, :initial_wait, a), do: gslot(g) * 166 + 97 + 2 * aslot(a)
  defp role_index(g, :abort_wait, a), do: gslot(g) * 166 + 98 + 2 * aslot(a)
  defp role_index(g, :retire, _), do: gslot(g) * 166 + 161
  defp role_index(g, :abort, _), do: gslot(g) * 166 + 162
  defp role_index(g, :retirement_wait, n), do: gslot(g) * 166 + 163 + n
  defp role_index(g, :snapshot, _), do: gslot(g) * 166 + 165
  defp actor(ctx, g, role, owner), do: call(ctx, {:actor, role_index(g, role, owner), role, owner})
  defp command(ctx, g, role, owner, operation, descriptor) do
    _ = actor(ctx, g, role, owner)
    index = role_index(g, role, owner)
    {pid, id} = call(ctx, {:command, index})
    envelope = {ctx.id, gslot(g), if(match?({:attempt, _, _, _}, owner), do: aslot(owner), else: -1), owner, id}
    send(pid, {:command, self(), envelope, operation, descriptor})
    {index, id, owner}
  end
  defp reply(ctx, {index, id, owner}, deadline) do
    receive do
      {:fixture_reply, ^owner, ^id, result} ->
        :ok = call(ctx, {:ack, index, id})
        result
    after
      remaining(deadline) -> raise "owned actor reply deadline"
    end
  end
  defp invoke(ctx, g, role, owner, operation, descriptor, deadline) do
    reply(ctx, command(ctx, g, role, owner, operation, descriptor), deadline)
  end

  def run(which) do
    run_origin = File.read!(Path.join(@audit, "run-origin")) |> String.to_integer()
    ensure(now() < run_origin + 660_000, :suite_deadline)
    id = which |> Atom.to_string() |> String.upcase()
    {:ok, ledger} = Ledger.start(id)
    # The ledger exists before the peer or any generation/source allocation.
    boot = now()
    ctx = %{id: id, ledger: ledger, t0: boot, primary: boot + 15_000, cleanup: boot + 25_000,
      shutdown: boot + 30_000, peer: nil, origin: nil, port: nil}
    outcome = try do
      ctx = start_peer(ctx)
      result = scenario(which, ctx)
      {:ok, result, ctx}
    rescue
      exception -> {:error, %{category: :assertion_or_contract, exception: exception.__struct__, sites: safe_sites(__STACKTRACE__)}, ctx}
    catch
      :exit, _ -> {:error, :owned_operation_exit, ctx}
    end
    ctx = call(ctx, :context) || ctx
    cleanup = cleanup(ctx)
    state = call(ctx, :state)
    snapshot = Model.snapshot(state.model)
    result = case outcome do
      {:ok, result, _} -> result
      {:error, reason, _} -> %{failure: reason}
    end
    status = if match?({:ok, _, _}, outcome) and cleanup.ok, do: "PASS_FUNCTIONAL", else: "FAIL"
    row = %{id: id, run_origin: run_origin, status: status, oracle: json_value(result), joins: cleanup.ok,
      cleanup: cleanup.evidence, accounting: "ACCOUNTING_BLOCKED_INPUT", native_frontier: "unestablished",
      outstanding_controls: snapshot.outstanding_controls, held_roots: snapshot.held_roots,
      held_chunks: snapshot.held_chunks, occupied_attempts: Tuple.to_list(snapshot.occupied_attempts),
      actors: Enum.count(Tuple.to_list(state.actors), &(not is_nil(&1))), fetches: state.fetches,
      operations: state.operation, identity_sha256: sha256(File.read!(Path.join(@audit, "run-identity.json")))}
    encoded = JSON.encode!(json_value(row))
    ensure(byte_size(encoded) <= 4096, :row_limit)
    File.write!(Path.join(@audit, id <> "-result.json"), encoded)
    IO.puts("H1_ACCOUNTING_FIXTURE_CASE " <> encoded)
    GenServer.stop(ledger, :normal, max(remaining(ctx.shutdown), 1))
    ensure(status == "PASS_FUNCTIONAL", :case_failed)
    result
  end

  defp json_value(value) when is_tuple(value), do: value |> Tuple.to_list() |> Enum.map(&json_value/1)
  defp json_value(value) when is_list(value), do: Enum.map(value, &json_value/1)
  defp json_value(value) when is_map(value), do: Map.new(value, fn {k, v} -> {k, json_value(v)} end)
  defp json_value(value) when value in [true, false, nil], do: value
  defp json_value(value) when is_atom(value), do: Atom.to_string(value)
  defp json_value(value), do: value

  defp safe_sites(stack) do
    stack |> Enum.take(3) |> Enum.map(fn {module, function, arity, info} ->
      %{module: Atom.to_string(module), function: Atom.to_string(function),
        arity: if(is_integer(arity), do: arity, else: "arguments_elided"), line: info[:line]}
    end)
  end

  defp reserve_g(ctx) do
    token = applied(ctx, {:reserve_generation, 15_000})
    if token != :busy do
      row = %{token: token, scope: nil, policy: nil, open: false, retired: false,
        roots: %{}, receipts: %{retire: nil, abort: nil}, waits: {nil, nil}, snapshots: 0,
        issued: %{open: false, retire: false, abort: false}, wait_issued: {false, false},
        operation_results: %{open: nil, retire: nil, abort: nil},
        retirement_deadline: nil, attempts: List.to_tuple(List.duplicate(nil, 32))}
      :ok = call(ctx, {:generation, token, row})
      _ = actor(ctx, token, :custodian, token)
    end
    token
  end

  defp open_g(ctx, g) do
    claim_generation(ctx, g, :open)
    root(ctx, g, :policy_source)
    root(ctx, g, :policy_prepared)
    root(ctx, g, :custodian)
    source = {:attempt, g, 0, make_ref()}
    {:ok, policy} = invoke(ctx, g, :source, source, :policy, ctx.origin, ctx.primary)
    put_g(ctx, g, :policy, policy)
    control = applied(ctx, {:begin_control, g, :open})
    {:ok, scope} = invoke(ctx, g, :custodian, g, :open, policy.open_options, ctx.primary)
    put_g(ctx, g, :scope, scope)
    put_g(ctx, g, :open, true)
    root(ctx, g, :scope)
    applied(ctx, {:control_result, control, :ok})
    # Open is custodian-owned; no helper/native release follows a returned handle.
    applied(ctx, {:scope_opened, g})
    invoke(ctx, g, :source, source, :drop, nil, ctx.primary)
    release_root(ctx, g, :policy_source)
    g
  end

  defp root(ctx, token, role) do
    root = applied(ctx, {:retain_root, token, role})
    if match?({:generation, _, _}, token) do
      row = generation(ctx, token)
      put_g(ctx, token, :roots, Map.put(row.roots, role, root))
    else
      row = attempt(ctx, token)
      put_a(ctx, token, :roots, Map.put(row.roots, role, root))
    end
    root
  end
  defp release_root(ctx, token, role) do
    row = if match?({:generation, _, _}, token), do: generation(ctx, token), else: attempt(ctx, token)
    case Map.get(row.roots, role) do
      nil -> :ok
      credit ->
        applied(ctx, {:release_root, credit})
        roots = Map.delete(row.roots, role)
        if match?({:generation, _, _}, token), do: put_g(ctx, token, :roots, roots), else: put_a(ctx, token, :roots, roots)
    end
  end

  defp reserve_a(ctx, g, deadline \\ nil) do
    elapsed = max(now() - ctx.t0, 0)
    applied(ctx, {:advance, elapsed})
    d = deadline || min(15_000, elapsed + 10_000)
    token = applied(ctx, {:acquire_attempt, g, d})
    if token != :busy do
      row = %{token: token, deadline: ctx.t0 + d, connect_deadline: ctx.t0 + min(d, elapsed + 3000),
        promise: nil, completion: nil, stream: nil, upload: nil, upload_monitor: nil, roots: %{},
        public_result: nil, late_public_result: nil, prepared: nil, local_released: false, reader: false, response: nil,
        controls: %{initial_wait: nil, abort_wait: nil}, upload_calls: 0, upload_finish: 0,
        upload_status: nil, lost_oracle: nil, fetch_issued: false}
      :ok = call(ctx, {:attempt, token, row})
      root(ctx, token, :source)
      applied(ctx, {:prepare_attempt, token})
      _ = actor(ctx, g, :source, token)
    end
    token
  end

  defp prepare(ctx, token, descriptor) do
    row = attempt(ctx, token)
    g = gen_of(token)
    policy = generation(ctx, g).policy
    result = invoke(ctx, g, :source, token, :prepare,
      {policy, descriptor, ctx.id, wire_slot(token), row.deadline, row.connect_deadline}, ctx.primary)
    case result do
      {:ok, meta} -> root(ctx, token, :prepared); put_a(ctx, token, :prepared, meta)
      {:error, _} -> :ok
    end
    result
  end

  defp launch(ctx, token) do
    row = attempt(ctx, token)
    ensure(not row.fetch_issued and remaining(row.deadline) > 0 and remaining(row.connect_deadline) > 0, :fetch_deadline)
    applied(ctx, {:advance, max(now() - ctx.t0, 0)})
    case event(ctx, {:launch_attempt, token}) do
      {:ok, _} ->
        root(ctx, token, :terminal)
        root(ctx, token, :upstream)
        scope = generation(ctx, gen_of(token)).scope
        put_a(ctx, token, :fetch_issued, true)
        result = command(ctx, gen_of(token), :source, token, :fetch, {scope, row.deadline, row.connect_deadline})
        result
      {:error, _} = error -> error
    end
  end

  defp fetched(ctx, token, pending) do
    result = reply(ctx, pending, attempt(ctx, token).deadline)
    put_a(ctx, token, :public_result, result)
    case result do
      %{status: 200, stream: stream} -> put_a(ctx, token, :stream, stream)
      {:error, _} -> applied(ctx, {:attempt_result, token, :failed})
    end
    result
  end

  defp local_release(ctx, token) do
    g = gen_of(token)
    :ok = invoke(ctx, g, :source, token, :drop, nil, ctx.cleanup)
    Enum.each([:prepared, :source], &release_root(ctx, token, &1))
    if attempt(ctx, token).promise == nil do
      applied(ctx, {:reject_attempt, token})
      applied(ctx, {:release_attempt, token})
      put_a(ctx, token, :local_released, true)
    end
    :ok
  end

  def actor_loop(coordinator, role, owner, data) do
    receive do
      {:command, caller, {case_id, _g, _a, token, operation}, command, descriptor} ->
        {result, data} = actor_operation(coordinator, role, token, command, descriptor, data, caller, operation, case_id)
        actor_reply_and_loop(coordinator, role, owner, data, caller, token, operation, result)
      {:stop, _deadline} when role == :producer -> exit(:fixture_producer_shutdown)
      {:stop, _deadline} -> :ok
      {port, {:data, {:eol, line}}} when role == :peer ->
        actor_loop(coordinator, role, owner, peer_record(data, port, line))
      {port, {:data, {:noeol, _}}} when role == :peer and port == data.port -> raise "peer line limit"
      {port, {:exit_status, code}} when role == :peer and port == data.port ->
        actor_loop(coordinator, role, owner, Map.put(data, :exit, code))
    end
  end
  defp actor_reply_and_loop(coordinator, role, owner, data, caller, token, operation, result) do
    # Enter a new tail frame before ACK: the old source or producer binary is
    # absent from these arguments and cannot survive in the command frame.
    send(caller, {:fixture_reply, token, operation, result})
    actor_loop(coordinator, role, owner, data)
  end

  defp actor_operation(_c, :source, _token, :policy, origin, _data, _caller, _op, _case) do
    case Preparation.prepare_policy(%{origin: origin, connect_address: {127, 0, 0, 1}, trust: nil}) do
      {:ok, policy, manifest} -> {{:ok, policy}, %{policy: policy, manifest: manifest}}
      {:error, reason} -> {{:error, reason}, %{}}
    end
  end
  defp actor_operation(_c, :source, _token, :prepare, {policy, descriptor, case_id, slot, deadline, connect}, data, _caller, _op, _case) do
    source = request_source(policy, descriptor, case_id, slot, deadline, connect)
    case Preparation.prepare_request(policy, source) do
      {:ok, prepared, manifest} ->
        meta = request_oracle(policy, source, prepared)
        {{:ok, meta}, Map.merge(data, %{source: source, prepared: prepared, manifest: manifest})}
      {:error, reason} -> {{:error, reason}, Map.merge(data, %{source: source})}
    end
  end
  defp actor_operation(c, :source, token, :fetch, {scope, deadline, connect_deadline}, %{prepared: prepared} = data, _caller, _op, _case) do
    ensure(not Map.get(data, :fetched, false), :fetch_once)
    ensure(remaining(deadline) > 0 and remaining(connect_deadline) > 0, :fetch_deadline)
    prepared = %{prepared | timeout: min(prepared.timeout, remaining(deadline)),
      connect_timeout: min(prepared.connect_timeout, remaining(connect_deadline))}
    promise = HTTP.fetch(prepared.url,
      method: prepared.method, headers: prepared.fields, body: prepared.body,
      duplex: if(is_pid(prepared.body), do: :half, else: nil), request_mode: :proxy,
      redirect: :manual, decode_body: false, stream_response: true, telemetry: false,
      timeout: prepared.timeout, connect_timeout: prepared.connect_timeout,
      transport_scope: scope, http_version: :http1, tls_backend: :ssl)
    completion = HTTP.Promise.completion(promise)
    :registered = GenServer.call(c, {:register, token, promise, completion}, max(remaining(deadline), 1))
    result = try do
      case HTTP.Promise.await(promise, remaining(deadline)) do
        %HTTP.Response{status: status, body: body, stream: stream} ->
          stream = if is_pid(body), do: body, else: stream
          %{status: status, stream: stream, buffered: if(is_binary(body), do: %{length: byte_size(body), digest: sha256(body)}, else: nil)}
        {:error, reason} -> {:error, compact_reason(reason)}
      end
    catch
      :exit, _ -> {:error, :promise_await_exit}
    end
    :ok = GenServer.call(c, {:put_attempt, token, :public_result, result})
    {result, Map.put(data, :fetched, true)}
  end
  defp actor_operation(_c, :source, _token, :drop, nil, _data, _caller, _op, _case), do: {:ok, %{}}
  defp actor_operation(_c, :source, _token, :die, nil, _data, _caller, _op, _case), do: exit(:fixture_declared_death)
  defp actor_operation(c, :custodian, token, :open, options, data, _caller, _op, _case) do
    ensure(not Map.get(data, :opened, false), :open_once)
    result = HTTP.ManagedTransport.open(options)
    case result do
      {:ok, scope} ->
        :ok = GenServer.call(c, {:put_generation, token, :scope, scope})
        :ok = GenServer.call(c, {:put_generation, token, :open, true})
        register_generation_result(c, token, :open, :ok)
        {result, Map.merge(data, %{scope: scope, opened: true})}
      {:error, reason} ->
        result = {:error, compact_reason(reason)}
        register_generation_result(c, token, :open, result)
        {result, Map.put(data, :opened, true)}
    end
  end
  defp actor_operation(_c, :custodian, _token, :die, nil, _data, _caller, _op, _case), do: exit(:fixture_declared_death)
  defp actor_operation(c, role, token, :retire, {scope, mode}, data, _caller, _op, _case) when role in [:retire, :abort] do
    ensure(not Map.has_key?(data, :used), :retire_once)
    result = HTTP.ManagedTransport.retire(scope, mode: mode)
    case result do
      {:ok, receipt} ->
        row = GenServer.call(c, {:get_generation, token})
        :ok = GenServer.call(c, {:put_generation, token, :receipts, Map.put(row.receipts, role, receipt)})
      {:error, _} -> :ok
    end
    register_generation_result(c, token, role, if(match?({:ok, _}, result), do: :ok, else: compact_result(result)))
    {result, %{used: true}}
  end
  defp actor_operation(c, :abort, token, :late_abort, {scope, gate, deadline}, data, caller, operation, _case) do
    ensure(data == %{}, :abort_once)
    send(caller, {:fixture_gate, token, operation, :abort_reserved})
    receive do
      {:release_abort, ^gate} -> :ok
    after
      remaining(deadline) -> raise "late abort gate deadline"
    end
    result = HTTP.ManagedTransport.retire(scope, mode: :abort)
    case result do
      {:ok, receipt} ->
        row = GenServer.call(c, {:get_generation, token})
        :ok = GenServer.call(c, {:put_generation, token, :receipts, Map.put(row.receipts, :abort, receipt)})
      {:error, _} -> :ok
    end
    register_generation_result(c, token, :abort, if(match?({:ok, _}, result), do: :ok, else: compact_result(result)))
    {result, %{used: true}}
  end
  defp actor_operation(c, :retirement_wait, _token, :wait, {g, index, receipt, deadline, zero}, data, _caller, _op, _case) do
    ensure(data == %{}, :retirement_wait_once)
    result = HTTP.ManagedTransport.await_retired(receipt, if(zero, do: 0, else: remaining(deadline)))
    row = GenServer.call(c, {:get_generation, g})
    :ok = GenServer.call(c, {:put_generation, g, :waits, put_elem(row.waits, index, compact_result(result))})
    {result, %{used: true}}
  end
  defp actor_operation(_c, :snapshot, _token, :snapshot, {scope, deadline}, data, _caller, _op, _case) do
    count = Map.get(data, :count, 0)
    ensure(count < 3, :snapshot_cap)
    {HTTP.ManagedTransport.snapshot(scope, min(remaining(deadline), 1000)), %{count: count + 1}}
  end
  defp actor_operation(c, role, token, :completion, {completion, deadline, zero, lost}, data, caller, operation, _case) when role in [:initial_wait, :abort_wait] do
    ensure(data == %{}, :completion_once)
    result = case role do
      :initial_wait -> HTTP.RequestCompletion.await(completion, if(zero, do: 0, else: remaining(deadline)))
      :abort_wait -> HTTP.RequestCompletion.abort_and_await(completion, if(zero, do: 0, else: remaining(deadline)))
    end
    row = GenServer.call(c, {:get_attempt, token})
    control = row.controls[role]
    :ok = GenServer.call(c, {:put_attempt, token, :controls, Map.put(row.controls, role, %{control | result: compact_result(result)})})
    if lost do
      :ok = GenServer.call(c, {:put_attempt, token, :lost_oracle, result})
      send(caller, {:fixture_gate, token, operation, :proof_dropped})
      exit(:fixture_proof_dropped)
    end
    {result, %{used: true}}
  end
  defp actor_operation(c, :producer, token, :stream, nil, data, _caller, _op, _case) do
    ensure(data == %{}, :upload_stream_once)
    {:ok, stream} = HTTP.Stream.start_link(0)
    :ok = GenServer.call(c, {:upload, token, stream})
    {{:ok, stream}, %{stream: stream, chunks: 0, finishes: 0}}
  end
  defp actor_operation(_c, :producer, token, :chunk, {pattern, length, deadline}, data, caller, op, _case) do
    ensure(length in 1..65_536 and data.chunks < 2, :upload_chunk_cap)
    send(caller, {:fixture_gate, token, op, :producer_started})
    binary = :binary.copy(<<pattern>>, length)
    result = HTTP.Stream.chunk(data.stream, binary, remaining(deadline))
    # The tail return drops the producer's binary before the next scalar command.
    {result, %{data | chunks: data.chunks + 1}}
  end
  defp actor_operation(_c, :producer, _token, :finish, kind, data, _caller, _op, _case) do
    limit = if kind in [:excess, :forbidden, :trail128], do: 3, else: 1
    ensure(data.finishes < limit, :upload_finish_cap)
    trailers = case kind do
      :none -> []
      :excess -> trailer_fields(129)
      :forbidden -> [{"Content-Length", "1"}]
      :trail128 -> trailer_fields(128)
    end
    {HTTP.Stream.finish(data.stream, trailers), %{data | finishes: data.finishes + 1}}
  end
  defp actor_operation(c, :consumer, token, :consume, {stream, deadline, hold}, data, caller, operation, _case) do
    ensure(data == %{}, :response_reader_once)
    send(stream, {:read_chunk, self(), :ack})
    state = %{length: 0, hash: :crypto.hash_init(:sha256), chunks: 0, trailers: [], ends: 0, error: nil, hold: hold, credit_order: true}
    result = consume(c, token, stream, deadline, caller, operation, state)
    {result, %{used: true}}
  end
  defp actor_operation(_c, :peer, _token, :start, {{python, case_id}, deadline}, data, _caller, _op, _case) do
    ensure(data == %{}, :peer_once)
    port = Port.open({:spawn_executable, python}, [:binary, :exit_status, {:line, 4096},
      {:args, [Path.join(__DIR__, "managed_h1_accounting_peer.py"), "--mode", "h1", "--case", case_id]}])
    state = %{port: port, events: 0, controls: 0, requests: List.to_tuple(List.duplicate(%{}, 128)),
      ready: nil, cut: nil, stopped: nil, exit: nil, released: List.to_tuple(List.duplicate(false, 128)),
      last_control: nil, failure: nil, stop_requested: false}
    {ready, state} = peer_wait(state, {:ready, nil, nil}, deadline)
    {ready, state}
  end
  defp actor_operation(_c, :peer, _token, :control, {{command, request, scenario, operation}, deadline}, data, _caller, _op, _case) do
    ensure(data.controls < 64, :peer_control_cap)
    envelope = %{command: command, operation: operation, budget_ms: remaining(deadline)}
    envelope = if request == nil, do: envelope, else: Map.put(envelope, :request, request)
    envelope = if scenario == nil, do: envelope, else: Map.put(envelope, :scenario, scenario)
    line = JSON.encode!(envelope)
    ensure(byte_size(line) <= 4096, :peer_command_size)
    true = Port.command(data.port, line <> "\n")
    data = %{data | controls: data.controls + 1, last_control: nil, stop_requested: command == "stop"}
    {result, data} = peer_wait(data, {:control, operation, nil}, deadline)
    data = if command == "release", do: %{data | released: put_elem(data.released, request, true)}, else: data
    if command == "stop" and is_map(result) do
      {code, data} = peer_wait(data, {:exit, nil, nil}, deadline)
      {result |> Map.put("exit", code) |> Map.put("failure_seen", data.failure), data}
    else
      {result, data}
    end
  end
  defp actor_operation(_c, :peer, _token, :event, {query, deadline}, data, _caller, _op, _case), do: peer_wait(data, query, deadline)
  defp actor_operation(_c, :peer, _token, :state, {nil, _deadline}, data, _caller, _op, _case), do: {data, data}

  defp actor_operation(_c, :source, _token, :trust, backing, _data, _caller, _op, _case) do
    parent = :binary.copy("d", backing)
    der = binary_part(parent, 0, 4096)
    ensure(:binary.referenced_byte_size(der) == backing, :der_backing_constructed)
    source = %{origin: "https://127.0.0.1", connect_address: {127, 0, 0, 1}, trust: [der]}
    case Preparation.prepare_policy(source) do
      {:ok, policy, manifest} ->
        [copy] = Keyword.fetch!(policy.open_options[:ssl], :cacerts)
        ensure(byte_size(copy) == 4096 and :binary.referenced_byte_size(copy) == 4096, :der_compacted)
        {{:ok, :compact}, %{source: source, policy: policy, manifest: manifest}}
      {:error, reason} -> {{:error, reason}, %{source: source}}
    end
  end
  defp actor_operation(_c, :source, _token, :challenge, {old, old_root}, data, caller, _op, _case) do
    send(caller, {:late_fixture_prepared, old})
    send(caller, {:late_fixture_release, old, old_root})
    {:ok, data}
  end
  defp actor_operation(c, :custodian, token, :late_open, {options, gate, deadline}, data, caller, op, case_id) do
    send(caller, {:fixture_gate, token, op, :open_reserved})
    receive do
      {:release_open, ^gate} -> :ok
    after remaining(deadline) -> raise "late open gate deadline" end
    actor_operation(c, :custodian, token, :open, options, data, caller, op, case_id)
  end

  defp compact_reason(reason) when reason in [:transport_scope_request_limit, :transport_scope_retired,
    :cleanup_pending, :cleanup_unconfirmed, :line_too_long, :invalid_chunk_size, :closed,
    :trailers_too_large, :promise_await_exit, :request_timeout, :timeout, :aborted], do: reason
  defp compact_reason({:transport_scope_capacity, value}) when value in [:connections, :requests], do: {:transport_scope_capacity, value}
  defp compact_reason({:forbidden_trailer, "content-length"}), do: {:forbidden_trailer, "content-length"}
  defp compact_reason(_), do: raise("unexpected public error")
  defp compact_result(:ok), do: :ok
  defp compact_result({:error, reason}), do: {:error, compact_reason(reason)}
  defp register_generation_result(c, token, role, result) do
    row = GenServer.call(c, {:get_generation, token})
    :ok = GenServer.call(c, {:put_generation, token, :operation_results, Map.put(row.operation_results, role, result)})
  end

  defp consume(c, token, stream, deadline, caller, operation, state) do
    receive do
      {:stream_chunk, ^stream, binary, ref} ->
        {:ok, credit} = GenServer.call(c, {:event, {:offer_chunk, token, :response}})
        state = %{state | length: state.length + byte_size(binary), hash: :crypto.hash_update(state.hash, binary), chunks: state.chunks + 1}
        ensure(state.length <= 131_073 and state.chunks <= 131_073, :consumer_cap)
        if state.hold do
          send(caller, {:fixture_gate, token, operation, :chunk_held})
          receive do
            {:release_consumer, ^token} -> :ok
            {:stop, _} -> exit(:normal)
          after
            remaining(deadline) -> raise "consumer hold deadline"
          end
        end
        release_and_ack(c, token, stream, ref, credit, deadline, caller, operation, %{state | hold: false})
      {:stream_trailers, ^stream, %HTTP.Headers{headers: fields}} ->
        ensure(length(fields) <= 128 and state.trailers == [], :consumer_trailers)
        consume(c, token, stream, deadline, caller, operation, %{state | trailers: %{count: length(fields), digest: field_digest(fields), value_bytes: Enum.map(fields, fn {_name, value} -> byte_size(value) end)}})
      {:stream_end, ^stream} ->
        {:ok, _} = GenServer.call(c, {:event, {:finish_stream, token, :response}})
        consumer_result(%{state | ends: state.ends + 1})
      {:stream_error, ^stream, reason} -> consumer_result(%{state | error: compact_reason(reason)})
      {:stop, _} -> exit(:normal)
    after
      remaining(deadline) -> raise "consumer deadline"
    end
  end
  defp release_and_ack(c, token, stream, ref, credit, deadline, caller, operation, state) do
    # No binary argument or retained body list crosses this tail-call boundary.
    {:ok, _} = GenServer.call(c, {:event, {:release_chunk, credit}})
    {:ok, _} = GenServer.call(c, {:event, {:ack_chunk, credit}})
    send(stream, {:stream_chunk_ack, ref})
    consume(c, token, stream, deadline, caller, operation, state)
  end
  defp consumer_result(state), do: Map.take(state, [:length, :chunks, :trailers, :ends, :error, :credit_order]) |> Map.put(:digest, Base.encode16(:crypto.hash_final(state.hash), case: :lower))

  defp peer_record(data, port, line) do
    ensure(data.port == port and byte_size(line) <= 4096 and data.events < 128, :peer_event_cap)
    event = JSON.decode!(line)
    data = %{data | events: data.events + 1}
    data = case event["event"] do
      "ready" -> %{data | ready: event}
      "wire_cut" -> %{data | cut: event}
      "stopped" -> %{data | stopped: event}
      "failure" -> %{data | failure: event["category"]}
      value when value in ["head", "body", "sent", "armed"] ->
        request = event["request"]
        if is_integer(request) and request in 0..127 do
          row = elem(data.requests, request)
          key = if value == "sent", do: event["phase"], else: value
          allowed = ["head", "body", "armed", "response", "response_head", "held", "terminal", "fanout", "pattern", "line", "bignum", "invalid", "trailer_prefix", "trailers", "released"]
          ensure(key in allowed, :peer_phase)
          %{data | requests: put_elem(data.requests, request, Map.put(row, key, event))}
        else
          data
        end
      value when value in ["accepted", "eof", "closed"] -> data
      _ -> raise "unknown peer event"
    end
    if is_integer(event["operation"]), do: %{data | last_control: event}, else: data
  end
  defp peer_wait(data, query, deadline) do
    if data.failure != nil and not data.stop_requested do
      {{:error, :peer_failure}, data}
    else
    result = case query do
      {:ready, _, _} -> data.ready
      {:exit, _, _} -> data.exit
      {:control, operation, _} -> if data.last_control && data.last_control["operation"] == operation, do: data.last_control
      {event, request, phase} -> Map.get(elem(data.requests, request), phase || Atom.to_string(event))
    end
    if result != nil do
      {result, data}
    else
      receive do
        {port, {:data, {:eol, line}}} -> peer_wait(peer_record(data, port, line), query, deadline)
        {port, {:data, {:noeol, _}}} when port == data.port -> raise "peer oversized line"
        {port, {:exit_status, code}} when port == data.port -> peer_wait(%{data | exit: code}, query, deadline)
      after
        remaining(deadline) -> {{:error, :peer_deadline}, data}
      end
    end
  end

    end
  defp start_peer(ctx) do
    _ = call(ctx, {:actor, 664, :peer, :peer})
    :ok = call(ctx, {:context, %{ctx | peer: true}})
    ready = peer(ctx, :start, {System.fetch_env!("HTTP_FETCH_PEER_PYTHON"), ctx.id})
    ensure(ready["event"] == "ready" and ready["protocol"] == "h1" and ready["case"] == ctx.id, :peer_ready)
    t0 = call(ctx, :start_clock)
    ctx = %{ctx | peer: true, t0: t0, primary: t0 + 15_000, cleanup: t0 + 25_000,
      shutdown: t0 + 30_000, port: ready["port"], origin: "http://127.0.0.1:" <> to_string(ready["port"])}
    :ok = call(ctx, {:context, ctx})
    ctx
  end
  defp peer(ctx, operation, descriptor, deadline \\ nil) do
    deadline = deadline || ctx.primary
    ensure(remaining(deadline) > 0, :peer_phase_deadline)
    {pid, id} = call(ctx, {:command, 664})
    descriptor = case descriptor do
      {:control, command, request, scenario} -> {command, request, scenario, id}
      descriptor -> descriptor
    end
    send(pid, {:command, self(), {ctx.id, -1, -1, :peer, id}, operation, {descriptor, deadline}})
    reply(ctx, {664, id, :peer}, deadline)
  end
  defp peer_control(ctx, command, request \\ nil, scenario \\ nil), do: peer(ctx, :control, {:control, command, request, scenario})
  defp arm(ctx, token, scenario), do: peer_control(ctx, "arm", wire_slot(token), Atom.to_string(scenario))
  defp release_peer(ctx, token), do: peer_control(ctx, "release", wire_slot(token))
  defp peer_event(ctx, token, event, phase \\ nil), do: peer(ctx, :event, {event, wire_slot(token), phase})
  defp cut(ctx), do: peer_control(ctx, "wire_cut")

  defp request_source(policy, descriptor, case_id, slot, deadline, connect) do
    {target, fields, body, trailers, method, url_override} = source_parts(policy, descriptor, case_id, slot)
    %{url: url_override || policy.origin <> target, method: method, fields: fields, body: body,
      trailers: trailers, timeout: max(remaining(deadline), 1), connect_timeout: max(remaining(connect), 1)}
  end
  defp base_fields(policy), do: [{"User-Agent", "u"}, {"Host", "127.0.0.1:" <> to_string(policy.port)}, {"Connection", "keep-alive"}]
  defp upload_fields(policy), do: base_fields(policy) ++ [{"Transfer-Encoding", "chunked"}, {"Content-Type", "application/octet-stream"}]
  defp duplicates(n), do: List.duplicate({"x-a", "v"}, n)
  defp trailer_fields(n), do: Enum.map(0..(n - 1), &{"x-t", "v" <> String.pad_leading(to_string(&1), 3, "0")})
  defp source_parts(policy, {:standard, body, trailers}, case_id, slot) do
    fields = if body == nil, do: base_fields(policy), else: upload_fields(policy)
    fields = if trailers == :trail128, do: fields ++ [{"Trailer", "x-t"}], else: fields
    {"/" <> String.downcase(case_id) <> "/" <> to_string(slot), fields, body, [], if(body == nil, do: :get, else: :post), nil}
  end
  defp source_parts(policy, {:count, index, body}, case_id, slot) do
    fields = case index do
      0 -> base_fields(policy) ++ duplicates(253)
      1 -> base_fields(policy) ++ duplicates(254)
      2 -> Enum.reject(base_fields(policy), fn {k, _} -> k == "User-Agent" end) ++ duplicates(254)
      3 -> Enum.reject(base_fields(policy), fn {k, _} -> k == "Host" end) ++ duplicates(254)
      4 -> upload_fields(policy) ++ duplicates(251)
      5 -> Enum.reject(upload_fields(policy), fn {k, _} -> k == "Content-Type" end) ++ duplicates(252)
      6 -> Enum.reject(upload_fields(policy), fn {k, _} -> k == "Transfer-Encoding" end) ++ duplicates(252)
      7 -> base_fields(policy) ++ [{"Content-Length", "1"}] ++ duplicates(252)
    end
    {"/" <> String.downcase(case_id) <> "/" <> to_string(slot), fields, body, [], if(body == nil, do: :get, else: :post), nil}
  end
  defp source_parts(policy, {:boundary, kind, charge, query, body}, _case, _slot) do
    target = if query, do: "/b04?", else: "/b04"
    fields = case kind do
      :initial -> base_fields(policy)
      :effective -> Enum.reject(base_fields(policy), fn {name, _} -> name == "Connection" end)
      :generated -> []
    end
    padded = fields ++ [{"x-pad", ""}]
    effective = effective_fields(policy, padded, body)
    fixed = case kind do
      :initial -> field_charge(padded) + 4 + 9 + 4
      _ -> field_charge(effective) + byte_size(target)
    end
    ensure(charge >= fixed, :padding_nonnegative)
    fields = fields ++ [{"x-pad", :binary.copy("p", charge - fixed)}]
    {target, fields, body, [], if(body == nil, do: :get, else: :post), nil}
  end
  defp source_parts(policy, {:backing_url, backing}, case_id, slot) do
    text = policy.origin <> "/" <> String.downcase(case_id) <> "/" <> to_string(slot) <> "/" <> :binary.copy("p", 80)
    parent = text <> :binary.copy("p", backing - byte_size(text))
    source = binary_part(parent, 0, byte_size(text))
    ensure(:binary.referenced_byte_size(source) == backing, :url_backing_constructed)
    {"/unused", base_fields(policy), nil, [], :get, source}
  end
  defp source_parts(policy, {:backing_field, backing}, case_id, slot) do
    parent = :binary.copy("p", backing)
    value = binary_part(parent, 0, 4096)
    ensure(:binary.referenced_byte_size(value) == backing, :field_backing_constructed)
    {"/" <> String.downcase(case_id) <> "/" <> to_string(slot), [{"x-pad", value}], nil, [], :get, nil}
  end
  defp source_parts(policy, {:malformed, kind}, case_id, slot) do
    {fields, trailers} = case kind do
      :fields -> {[{"x\r\n", "v"}], []}
      :excess -> {base_fields(policy), List.duplicate({"x-t", "v"}, 128) ++ [:malformed_tail]}
      :tail128 -> {base_fields(policy), List.duplicate({"x-t", "v"}, 127) ++ [{"x\r\n", "v"}]}
    end
    {"/" <> String.downcase(case_id) <> "/" <> to_string(slot), fields, nil, trailers, :get, nil}
  end

  defp field_charge(fields), do: Enum.reduce(fields, 0, fn {name, value}, n -> n + byte_size(name) + byte_size(value) + 32 end)
  defp field_digest(fields), do: sha256(Enum.map(fields, fn {name, value} -> [String.downcase(name), ": ", value, "\r\n"] end) |> IO.iodata_to_binary())
  defp default(fields, name, value) do
    if Enum.any?(fields, fn {key, _} -> String.downcase(key) == String.downcase(name) end), do: fields, else: [{name, value} | fields]
  end
  defp replace(fields, name, value), do: Enum.reject(fields, fn {key, _} -> String.downcase(key) == String.downcase(name) end) ++ [{name, value}]
  defp remove(fields, name), do: Enum.reject(fields, fn {key, _} -> String.downcase(key) == String.downcase(name) end)
  defp effective_fields(policy, fields, body) do
    fields = fields |> default("User-Agent", HTTP.Headers.user_agent(:http_fetch))
      |> default("Host", "127.0.0.1:" <> to_string(policy.port)) |> replace("Connection", "keep-alive")
    if body == nil do
      remove(fields, "Content-Length")
    else
      length = Enum.find(fields, fn {key, _} -> String.downcase(key) == "content-length" end)
      fields = if length == nil, do: replace(fields, "Transfer-Encoding", "chunked"), else: fields |> replace("Content-Length", elem(length, 1)) |> remove("Transfer-Encoding")
      default(fields, "Content-Type", "application/octet-stream")
    end
  end
  defp request_oracle(policy, source, prepared) do
    fields = effective_fields(policy, source.fields, source.body)
    initial = default(source.fields, "User-Agent", HTTP.Headers.user_agent(:http_fetch))
    target = prepared.target
    query = if String.contains?(target, "?"), do: target |> String.split("?", parts: 2) |> List.last(), else: ""
    path = target |> String.split("?", parts: 2) |> hd()
    serialized = [String.upcase(Atom.to_string(prepared.method)), " ", target, " HTTP/1.1\r\n",
      Enum.map(fields, fn {name, value} -> [name, ": ", value, "\r\n"] end), "\r\n"] |> IO.iodata_to_binary()
    %{target: target, supplied_count: length(source.fields), pure_charge: field_charge(source.fields) + byte_size(target),
      initial_count: length(initial), initial_charge: field_charge(initial) + 4 + 9 + byte_size(path) + byte_size(query),
      effective_count: length(fields), effective_charge: field_charge(fields) + byte_size(target),
      field_sha256: field_digest(fields), head_sha256: sha256(serialized), head_length: byte_size(serialized),
      compact: :binary.referenced_byte_size(prepared.url) == byte_size(prepared.url) and
        Enum.all?(prepared.fields, fn {name, value} -> :binary.referenced_byte_size(name) == byte_size(name) and :binary.referenced_byte_size(value) == byte_size(value) end)}
  end

  defp wait_gate(_ctx, token, {_index, operation, owner}, phase, deadline) when owner == token do
    receive do
      {:fixture_gate, ^token, ^operation, ^phase} -> :ok
    after
      remaining(deadline) -> raise "owned fixture gate deadline"
    end
  end
  defp upload(ctx, token) do
    root(ctx, token, :upload_source)
    {:ok, stream} = invoke(ctx, gen_of(token), :producer, token, :stream, nil, ctx.primary)
    stream
  end
  defp chunk(ctx, token, pattern, length) do
    row = attempt(ctx, token)
    put_a(ctx, token, :upload_calls, row.upload_calls + 1)
    command(ctx, gen_of(token), :producer, token, :chunk, {pattern, length, row.deadline})
  end
  defp finish_upload(ctx, token, kind \\ :none) do
    row = attempt(ctx, token)
    result = invoke(ctx, gen_of(token), :producer, token, :finish, kind, row.deadline)
    put_a(ctx, token, :upload_finish, row.upload_finish + 1)
    result
  end
  defp consume_start(ctx, token, hold \\ false) do
    ensure(not attempt(ctx, token).reader, :single_reader)
    stream = attempt(ctx, token).stream
    ensure(is_pid(stream), :public_stream)
    put_a(ctx, token, :reader, true)
    root(ctx, token, :response_consumer)
    command(ctx, gen_of(token), :consumer, token, :consume, {stream, attempt(ctx, token).deadline, hold})
  end
  defp consumed(ctx, token, operation) do
    result = reply(ctx, operation, attempt(ctx, token).deadline)
    put_a(ctx, token, :response, result)
    if result.error == nil do
      ensure(result.ends == 1, :one_end)
      applied(ctx, {:attempt_result, token, :ok})
    else
      applied(ctx, {:attempt_result, token, :failed})
    end
    release_root(ctx, token, :response_consumer)
    result
  end
  defp release_consumer(ctx, token), do: send(actor(ctx, gen_of(token), :consumer, token), {:release_consumer, token})
  defp completion(ctx, token, operation \\ :initial_wait, zero \\ false, lost \\ false) do
    row = attempt(ctx, token)
    ensure(row.completion != nil and row.controls[operation] == nil, :completion_budget)
    control = applied(ctx, {:begin_control, token, operation})
    put_a(ctx, token, :controls, Map.put(row.controls, operation, %{token: control, result: nil}))
    root(ctx, token, :helpers)
    task = command(ctx, gen_of(token), operation, token, :completion, {row.completion, if(operation == :initial_wait, do: row.deadline, else: ctx.cleanup), zero, lost})
    if lost do
      wait_gate(ctx, token, task, :proof_dropped, ctx.cleanup)
      applied(ctx, {:owner_down, token})
      :lost
    else
      result = reply(ctx, task, if(operation == :initial_wait, do: row.deadline, else: ctx.cleanup))
      ensure(result in [:ok, {:error, :cleanup_pending}], :completion_result)
      applied(ctx, {:control_result, control, model_result(result)})
      # helper release is recorded at the real join in cleanup, never on return.
      put_a(ctx, token, :controls, Map.put(attempt(ctx, token).controls, operation, %{token: control, result: result}))
      if result == :ok, do: applied(ctx, {:request_completed, token})
      result
    end
  end
  defp model_result(:ok), do: :ok
  defp model_result({:error, :cleanup_pending}), do: :cleanup_pending
  defp claim_generation(ctx, g, mode) do
    row = generation(ctx, g)
    ensure(not row.issued[mode], :generation_operation_once)
    put_g(ctx, g, :issued, Map.put(row.issued, mode, true))
  end
  defp retire(ctx, g, mode \\ :retire, deadline \\ nil) do
    row = generation(ctx, g)
    claim_generation(ctx, g, mode)
    deadline = row.retirement_deadline || deadline || min(ctx.primary, now() + 3000)
    if row.retirement_deadline == nil do
      applied(ctx, {:retire_generation, g, deadline - ctx.t0})
      put_g(ctx, g, :retirement_deadline, deadline)
    end
    control = applied(ctx, {:begin_control, g, mode})
    {:ok, receipt} = invoke(ctx, g, mode, g, :retire, {row.scope, if(mode == :retire, do: :graceful, else: :abort)}, ctx.cleanup)
    applied(ctx, {:control_result, control, :ok})
    receipt
  end
  defp retirement_wait(ctx, g, receipt, zero \\ false) do
    row = generation(ctx, g)
    index = cond do not elem(row.wait_issued, 0) -> 0; not elem(row.wait_issued, 1) -> 1; true -> raise "retirement wait cap" end
    put_g(ctx, g, :wait_issued, put_elem(row.wait_issued, index, true))
    result = invoke(ctx, g, :retirement_wait, index, :wait, {g, index, receipt, row.retirement_deadline, zero}, ctx.cleanup)
    ensure(result in [:ok, {:error, :cleanup_pending}], :retirement_result)
    put_g(ctx, g, :waits, put_elem(row.waits, index, result))
    if result == :ok do
      applied(ctx, {:scope_retired, g})
      put_g(ctx, g, :retired, true)
    end
    result
  end
  defp snapshot(ctx, g) do
    row = generation(ctx, g)
    ensure(row.snapshots < 3, :snapshot_cap)
    result = invoke(ctx, g, :snapshot, g, :snapshot, {row.scope, ctx.primary}, ctx.cleanup)
    put_g(ctx, g, :snapshots, row.snapshots + 1)
    result
  end
  defp wire_oracle(ctx, token) do
    meta = attempt(ctx, token).prepared
    head = peer_event(ctx, token, :head)
    ensure(head["target"] == meta.target and head["field_count"] == meta.effective_count and
      head["field_sha256"] == meta.field_sha256 and head["sha256"] == meta.head_sha256 and head["length"] == meta.head_length, :wire_header_oracle)
    head
  end
  defp simple(ctx, g, scenario \\ :ok, descriptor \\ nil) do
    token = reserve_a(ctx, g)
    {:ok, _} = prepare(ctx, token, descriptor || {:standard, nil, :none})
    arm(ctx, token, scenario)
    pending = launch(ctx, token)
    %{status: 200} = fetched(ctx, token, pending)
    wire_oracle(ctx, token)
    token
  end
  defp drain(ctx, token) do
    result = consumed(ctx, token, consume_start(ctx, token))
    :ok = completion(ctx, token)
    local_release(ctx, token)
    result
  end

  defp scenario(:b01, ctx) do
    [g1, g2, _g3, g4] = Enum.map(1..4, fn _ -> reserve_g(ctx) end)
    before = Model.snapshot(call(ctx, :state).model)
    :busy = reserve_g(ctx)
    ensure(Model.snapshot(call(ctx, :state).model) == before, :busy_generation_unchanged)
    open_g(ctx, g1)
    open_g(ctx, g2)
    request = simple(ctx, g2, :held)
    retire(ctx, g2)
    applied(ctx, {:owner_down, g4})
    invoke_death(ctx, g4, :custodian, g4)
    before = Model.snapshot(call(ctx, :state).model)
    :busy = reserve_g(ctx)
    ensure(Model.snapshot(call(ctx, :state).model) == before, :mixed_busy_unchanged)
    release_peer(ctx, request)
    %{length: 1, digest: digest} = drain(ctx, request)
    ensure(digest == sha256("h"), :held_data)
    %{generation_busy: 2, opens: Enum.count(Tuple.to_list(call(ctx, :state).generations), &(&1.open)),
      occupied_generations: before.occupied_generations, local_uncertainty: elem(call(ctx, :state).model.generations, gslot(g4)).lost_proof}
  end

  defp scenario(:b02, ctx) do
    g = open_g(ctx, reserve_g(ctx))
    requests = Enum.map(1..32, fn _ ->
      token = reserve_a(ctx, g)
      {:ok, _} = prepare(ctx, token, {:standard, nil, :none})
      token
    end)
    before = call(ctx, :state)
    :busy = reserve_a(ctx, g)
    after_busy = call(ctx, :state)
    ensure(before.actors == after_busy.actors and before.fetches == 0 and
      Enum.all?(Tuple.to_list(elem(after_busy.model.generations, 0).attempts), &(map_size(&1.roots) == 8 and &1.roots.source != nil and &1.roots.prepared != nil)), :r32_held)
    wire = cut(ctx)
    ensure(wire["requests"] == 0 and wire["connections"] == 0, :preparing_wire_zero)
    Enum.each(requests, &local_release(ctx, &1))
    ensure(Model.snapshot(call(ctx, :state).model).occupied_attempts == {0, 0, 0, 0}, :r32_released)
    %{preparing: 32, busy: true, fetches: call(ctx, :state).fetches, requests: wire["requests"], released_local: 32}
  end

  defp scenario(:b03, ctx) do
    g = open_g(ctx, reserve_g(ctx))
    tokens = Enum.map(0..7, fn _ -> reserve_a(ctx, g) end)
    result = Enum.reduce(Enum.with_index(tokens), %{accepted: [], local: 0, public: 0}, fn {token, index}, acc ->
      body = if index in 4..6, do: upload(ctx, token), else: nil
      case prepare(ctx, token, {:count, index, body}) do
        {:error, :request_limit} ->
          ensure(index == 1, :count_local_oracle)
          local_release(ctx, token)
          %{acc | local: acc.local + 1}
        {:ok, meta} ->
          accepted = index in [0, 4, 7]
          if accepted, do: arm(ctx, token, if(body == nil, do: :ok, else: :upload))
          launched = launch(ctx, token)
          producer = if accepted and body != nil, do: chunk(ctx, token, ?X, 1), else: nil
          if producer do
            :ok = reply(ctx, producer, attempt(ctx, token).deadline)
            :ok = finish_upload(ctx, token)
          end
          result = fetched(ctx, token, launched)
          if accepted do
            %{status: 200} = result
            wire_oracle(ctx, token)
            %{length: 2, digest: digest} = drain(ctx, token)
            ensure(digest == sha256("ok"), :count_response)
            %{acc | accepted: acc.accepted ++ [meta.effective_count]}
          else
            {:error, :transport_scope_request_limit} = result
            :ok = completion(ctx, token)
            local_release(ctx, token)
            %{acc | public: acc.public + 1}
          end
      end
    end)
    wire = cut(ctx)
    ensure(wire["requests"] == 3, :count_rejected_wire)
    %{accepted_counts: result.accepted, local_rejects: result.local, public_rejects: result.public,
      wire_oracle: true, rejected_wire: wire["requests"] - 3}
  end

  defp scenario(:b04, ctx) do
    g = open_g(ctx, reserve_g(ctx))
    variants = for query <- [false, true], kind <- [:initial, :effective], charge <- [65_536, 65_537], do: {kind, charge, query, false}
    variants = variants ++ (for pid <- [false, true], charge <- [65_536, 65_537], do: {:generated, charge, false, pid})
    result = Enum.reduce(variants, %{accepted: 0, rejected: 0}, fn {kind, charge, query, pid}, acc ->
      token = reserve_a(ctx, g)
      body = if pid, do: upload(ctx, token), else: nil
      {:ok, meta} = prepare(ctx, token, {:boundary, kind, charge, query, body})
      ensure(meta.pure_charge <= 65_536 and meta.supplied_count <= 256, :boundary_pure)
      tested = if kind == :initial, do: meta.initial_charge, else: meta.effective_charge
      ensure(tested == charge, :boundary_exact)
      if kind != :initial, do: ensure(meta.initial_charge <= 65_536, :boundary_initial)
      if kind == :initial and charge == 65_536 do
        ensure(meta.effective_charge == if(query, do: 65_524, else: 65_523), :opaque_query_charge)
      end
      accepted = charge == 65_536
      if accepted, do: arm(ctx, token, if(pid, do: :upload, else: :ok))
      pending = launch(ctx, token)
      producer = if accepted and pid, do: chunk(ctx, token, ?X, 1), else: nil
      if producer do
        :ok = reply(ctx, producer, attempt(ctx, token).deadline)
        :ok = finish_upload(ctx, token)
      end
      reply = fetched(ctx, token, pending)
      if accepted do
        %{status: 200} = reply
        wire_oracle(ctx, token)
        drain(ctx, token)
        %{acc | accepted: acc.accepted + 1}
      else
        {:error, :transport_scope_request_limit} = reply
        ensure(attempt(ctx, token).roots.source != nil and attempt(ctx, token).roots.prepared != nil, :rejected_roots_held)
        :ok = completion(ctx, token)
        local_release(ctx, token)
        %{acc | rejected: acc.rejected + 1}
      end
    end)
    wire = cut(ctx)
    ensure(wire["requests"] == result.accepted, :boundary_rejected_wire)
    %{subcases: length(variants), accepted: result.accepted, rejected: result.rejected,
      targets: ["/b04", "/b04?"], exact_charge_oracle: true, wire_oracle: true}
  end

  defp scenario(:b05, ctx) do
    g = open_g(ctx, reserve_g(ctx))
    tokens = Enum.map(1..8, fn _ -> reserve_a(ctx, g) end)
    descriptors = [{:backing_url, 131_072}, {:backing_url, 65_536}, {:backing_field, 131_072}, {:backing_field, 8192}]
    results = Enum.map(Enum.zip(Enum.take(tokens, 4), descriptors), fn {token, descriptor} ->
      result = prepare(ctx, token, descriptor)
      case result do
        {:ok, meta} -> ensure(meta.compact, :backing_compacted)
        {:error, reason} -> ensure(reason == :source_backing_limit, :backing_reject)
      end
      result
    end)
    trust = Enum.map(Enum.zip(Enum.slice(tokens, 4, 2), [65_536, 65_537]), fn {token, backing} ->
      result = invoke(ctx, g, :source, token, :trust, backing, ctx.primary)
      if result == {:ok, :compact}, do: root(ctx, token, :prepared)
      result
    end)
    malformed_token = Enum.at(tokens, 6)
    {:error, malformed} = prepare(ctx, malformed_token, {:malformed, :fields})
    excess_token = Enum.at(tokens, 7)
    {:error, excess} = prepare(ctx, excess_token, {:malformed, :excess})
    local_release(ctx, excess_token)
    tail_token = reserve_a(ctx, g)
    ensure(aslot(tail_token) == aslot(excess_token), :trailer_local_slot_reuse)
    {:error, tail128} = prepare(ctx, tail_token, {:malformed, :tail128})
    Enum.each(Enum.take(tokens, 7) ++ [tail_token], &local_release(ctx, &1))
    [{:error, :source_backing_limit}, {:ok, _}, {:error, :source_backing_limit}, {:ok, _}] = results
    [{:ok, :compact}, {:error, :source_backing_limit}] = trust
    ensure(malformed == :invalid_fields and excess == :trailer_limit and tail128 == :invalid_trailers, :malformed_oracle)
    %{backing_rejects: 3, compact_copies: 3, malformed: malformed, excess: excess,
      malformed_128: tail128, fetches: call(ctx, :state).fetches}
  end

  defp scenario(:b06, ctx) do
    g = open_g(ctx, reserve_g(ctx))
    a = simple(ctx, g, :held)
    ca = consume_start(ctx, a, true)
    wait_gate(ctx, a, ca, :chunk_held, ctx.primary)
    b = simple(ctx, g, :held)
    cb = consume_start(ctx, b, true)
    wait_gate(ctx, b, cb, :chunk_held, ctx.primary)
    third = reserve_a(ctx, g)
    {:ok, _} = prepare(ctx, third, {:standard, nil, :none})
    result = fetched(ctx, third, launch(ctx, third))
    {:error, {:transport_scope_capacity, :connections}} = result
    :ok = completion(ctx, third)
    local_release(ctx, third)
    {:ok, status} = snapshot(ctx, g)
    wire = cut(ctx)
    ensure(status.connections == 2 and status.pending == 0 and wire["connections"] == 2 and wire["requests"] == 2, :c2_wire)
    Enum.each([a, b], fn token -> release_peer(ctx, token); release_consumer(ctx, token) end)
    Enum.each([{a, ca}, {b, cb}], fn {token, op} ->
      %{length: 1, ends: 1} = consumed(ctx, token, op)
      :ok = completion(ctx, token)
      local_release(ctx, token)
    end)
    %{capacity: result, connections: status.connections, pending: status.pending, requests: wire["requests"],
      rejected_wire: wire["requests"] - 2, held_consumers: 2}
  end

  defp scenario(:b07, ctx) do
    g = open_g(ctx, reserve_g(ctx))
    token = simple(ctx, g, :held)
    receipt = retire(ctx, g)
    initial = completion(ctx, token, :initial_wait, true)
    retirement = retirement_wait(ctx, g, receipt, true)
    {:ok, _} = snapshot(ctx, g)
    ensure(attempt(ctx, token).roots.upstream != nil and Model.snapshot(call(ctx, :state).model).outstanding_controls > 0, :unread_held)
    operation = consume_start(ctx, token)
    release_peer(ctx, token)
    body = consumed(ctx, token, operation)
    final = completion(ctx, token, :abort_wait)
    final_retirement = retirement_wait(ctx, g, receipt)
    local_release(ctx, token)
    %{initial_completion: initial, initial_retirement: retirement, final_completion: final,
      final_retirement: final_retirement, body_length: body.length, body_sha256: body.digest}
  end

  defp scenario(:b08, ctx) do
    g = open_g(ctx, reserve_g(ctx))
    token = reserve_a(ctx, g)
    stream = upload(ctx, token)
    {:ok, _} = prepare(ctx, token, {:standard, stream, :none})
    first = chunk(ctx, token, ?X, 65_536)
    wait_gate(ctx, token, first, :producer_started, ctx.primary)
    receive do
      {:fixture_reply, ^token, _, _} -> raise "preloaded upload acknowledged without reader"
    after
      0 -> :ok
    end
    arm(ctx, token, :upload)
    fetch = launch(ctx, token)
    :ok = reply(ctx, first, attempt(ctx, token).deadline)
    second = chunk(ctx, token, ?Y, 65_536)
    :ok = reply(ctx, second, attempt(ctx, token).deadline)
    :ok = finish_upload(ctx, token)
    %{status: 200} = fetched(ctx, token, fetch)
    head = wire_oracle(ctx, token)
    body = peer_event(ctx, token, :body)
    ensure(body["length"] == 131_072 and body["chunks"] == [65_536, 65_536] and body["sha256"] == upload_sha256(), :upload_wire)
    ensure(head["request"] == body["request"] and head["sequence"] < body["sequence"] and body["terminal"], :upload_terminal)
    drain(ctx, token)
    %{preloaded_without_ack: true, upload_lengths: body["chunks"], upload_acks: [:ok, :ok],
      root_before_next_input: true, head_before_body: true, body_length: body["length"], body_sha256: body["sha256"], finish: :ok}
  end

  defp scenario(:b09, ctx) do
    g = open_g(ctx, reserve_g(ctx))
    token = simple(ctx, g, :fanout)
    operation = consume_start(ctx, token, true)
    wait_gate(ctx, token, operation, :chunk_held, ctx.primary)
    held = Model.snapshot(call(ctx, :state).model)
    second_offer = event(ctx, {:offer_chunk, token, :response})
    ensure(second_offer == {:error, :ownership_pending}, :second_consumer_offer)
    ensure(Model.snapshot(call(ctx, :state).model) == held and held.held_chunks == 1, :sole_consumer_credit)
    phase = peer_event(ctx, token, :sent, "fanout")
    ensure(phase["length"] == 8195 and phase["sha256"] == sha256(:binary.copy("1\r\na\r\n", 1365) <> "0\r\n\r\n"), :fanout_wire)
    release_consumer(ctx, token)
    body = consumed(ctx, token, operation)
    :ok = completion(ctx, token)
    local_release(ctx, token)
    %{held_credit: held.held_chunks, second_offer: second_offer, body_length: body.length,
      body_sha256: body.digest, ends: body.ends, trailers: body.trailers, credit_order: body.credit_order}
  end

  defp scenario(:b10, ctx) do
    bodies = Enum.map([:cl, :eof], fn framing ->
      g = open_g(ctx, reserve_g(ctx))
      token = simple(ctx, g, framing)
      body = drain(ctx, token)
      ensure(body.length == 131_073 and body.digest == pattern_sha256(131_073), :large_framed_body)
      body
    end)
    %{lengths: Enum.map(bodies, & &1.length), digests: Enum.map(bodies, & &1.digest),
      ends: Enum.map(bodies, & &1.ends), completions: [:ok, :ok]}
  end

  defp scenario(:b11, ctx) do
    g = open_g(ctx, reserve_g(ctx))
    bodies = Enum.map([:line8192, :line8193, :bignum, :invalid], fn scenario ->
      token = simple(ctx, g, scenario)
      operation = consume_start(ctx, token)
      if scenario in [:line8192, :line8193] do
        phase = peer_event(ctx, token, :sent, "line")
        ensure(phase["length"] == if(scenario == :line8192, do: 8192, else: 8193), :line_boundary_wire)
        if scenario == :line8192, do: release_peer(ctx, token)
      end
      body = consumed(ctx, token, operation)
      if scenario in [:line8193, :invalid], do: release_peer(ctx, token)
      :ok = completion(ctx, token)
      local_release(ctx, token)
      body
    end)
    [boundary, over, bignum, invalid] = bodies
    ensure(boundary.error == nil and over.error == :line_too_long and bignum.error == :closed and invalid.error == :invalid_chunk_size, :line_public_oracle)
    %{boundary: Map.take(boundary, [:length, :ends, :error]), over: over.error,
      bignum: Map.take(bignum, [:length, :digest, :error]), invalid: invalid.error, completion_handles: 4}
  end

  defp scenario(:b12, ctx) do
    g = open_g(ctx, reserve_g(ctx))
    bodies = Enum.map([:trail128, :trail129, :forbidden, :trail65536, :trail65537], fn scenario ->
      token = simple(ctx, g, scenario)
      body = consumed(ctx, token, consume_start(ctx, token))
      if scenario in [:trail129, :forbidden, :trail65537], do: release_peer(ctx, token)
      :ok = completion(ctx, token)
      local_release(ctx, token)
      body
    end)
    [accepted, excess, forbidden, exact, over] = bodies
    ensure(accepted.trailers.count == 128 and accepted.trailers.digest == field_digest(trailer_fields(128)) and accepted.ends == 1, :trailer_order_128)
    ensure(exact.trailers.count == 1 and exact.trailers.value_bytes == [65_527] and exact.trailers.digest == field_digest([{"x-t", :binary.copy("p", 65_527)}]), :trailer_exact_wire)
    token = reserve_a(ctx, g)
    stream = upload(ctx, token)
    {:ok, _} = prepare(ctx, token, {:standard, stream, :trail128})
    arm(ctx, token, :upload)
    fetch = launch(ctx, token)
    :ok = reply(ctx, chunk(ctx, token, ?q, 1), attempt(ctx, token).deadline)
    validations = Enum.map([:excess, :forbidden, :trail128], &finish_upload(ctx, token, &1))
    %{status: 200} = fetched(ctx, token, fetch)
    wire_oracle(ctx, token)
    wire = peer_event(ctx, token, :body)
    ensure(wire["trailer_count"] == 128 and wire["trailer_sha256"] == field_digest(trailer_fields(128)), :upload_trailer_order)
    drain(ctx, token)
    %{ordered_128: true, excess: excess.error, forbidden: forbidden.error, exact_wire: 65_536,
      over_wire: over.error, upload_validations: validations, upload_ordered_128: true}
  end

  defp scenario(:b13, ctx) do
    g = open_g(ctx, reserve_g(ctx))
    old = reserve_a(ctx, g, 200)
    {:ok, _} = prepare(ctx, old, {:standard, nil, :none})
    old_root = attempt(ctx, old).roots.source
    receive do after remaining(ctx.t0 + 200) -> :ok end
    applied(ctx, {:advance, max(now() - ctx.t0, 200)})
    old_record = elem(elem(call(ctx, :state).model.generations, 0).attempts, 0)
    ensure(old_record.outcome == :timed_out and old_record.deadline == 200, :prelaunch_timeout)
    local_release(ctx, old)
    replacement = reserve_a(ctx, g)
    {:ok, _} = prepare(ctx, replacement, {:standard, nil, :none})
    before = call(ctx, :state).model
    :ok = invoke(ctx, g, :source, replacement, :challenge, {old, old_root}, ctx.primary)
    receive do
      {:late_fixture_prepared, ^old} -> ensure(event(ctx, {:prepare_attempt, old}) == {:ok, :stale}, :late_prepared_stale)
    after remaining(ctx.primary) -> raise "missing late preparation challenge" end
    receive do
      {:late_fixture_release, ^old, ^old_root} -> ensure(event(ctx, {:release_root, old_root}) == {:ok, :stale}, :late_root_stale)
    after remaining(ctx.primary) -> raise "missing late root challenge" end
    ensure(call(ctx, :state).model == before, :replacement_nonce_unchanged)
    # Tail-call with scalar observations only: neither old challenge nonce nor
    # its source root survives into the launched negative trace.
    b13_launched(ctx, g, %{old_outcome: old_record.outcome, old_deadline: old_record.deadline,
      slot_reused: aslot(old) == aslot(replacement), nonce_changed: old != replacement,
      stale_replies: 2, replacement_unchanged: true})
  end

  defp scenario(:b14, ctx) do
    g1 = open_g(ctx, reserve_g(ctx))
    before = reserve_a(ctx, g1)
    {:ok, _} = prepare(ctx, before, {:standard, nil, :none})
    invoke_death(ctx, g1, :source, before)
    applied(ctx, {:owner_down, before})
    ensure(attempt(ctx, before).promise == nil, :prelaunch_death_no_handle)
    fetches_before = call(ctx, :state).fetches
    g2 = open_g(ctx, reserve_g(ctx))
    after_launch = simple(ctx, g2, :held)
    consumer = consume_start(ctx, after_launch, true)
    wait_gate(ctx, after_launch, consumer, :chunk_held, ctx.primary)
    original = attempt(ctx, after_launch).completion
    ensure(original != nil, :death_original_completion)
    invoke_death(ctx, g2, :source, after_launch)
    applied(ctx, {:owner_down, after_launch})
    release_peer(ctx, after_launch)
    release_consumer(ctx, after_launch)
    # DOWN supplies only owned fixture evidence; the registered public handle
    # independently supplies cancellation/cleanup evidence.
    :ok = completion(ctx, after_launch, :abort_wait)
    body = reply(ctx, consumer, ctx.cleanup)
    put_a(ctx, after_launch, :response, body)
    ensure(attempt(ctx, after_launch).completion == original, :death_handle_preserved)
    %{before_launch_fetches: fetches_before, after_launch_registered: true, declared_deaths: 2,
      fabricated_public_outcomes: 0, original_cleanup: :ok, refunds: 0}
  end

  defp scenario(:b15, ctx) do
    g1 = open_g(ctx, reserve_g(ctx))
    token = reserve_a(ctx, g1)
    {:ok, _} = prepare(ctx, token, {:standard, nil, :none})
    receipt = retire(ctx, g1)
    late = launch(ctx, token)
    ensure(late == {:error, :invalid_phase}, :retiring_no_fetch)
    local_release(ctx, token)
    :ok = retirement_wait(ctx, g1, receipt)
    g2 = reserve_g(ctx)
    Enum.each([:policy_source, :policy_prepared, :custodian], &root(ctx, g2, &1))
    source = {:attempt, g2, 0, make_ref()}
    {:ok, policy} = invoke(ctx, g2, :source, source, :policy, ctx.origin, ctx.primary)
    put_g(ctx, g2, :policy, policy)
    open_control = applied(ctx, {:begin_control, g2, :open})
    claim_generation(ctx, g2, :open)
    gate = make_ref()
    operation = command(ctx, g2, :custodian, g2, :late_open, {policy.open_options, gate, ctx.cleanup})
    wait_gate(ctx, g2, operation, :open_reserved, ctx.primary)
    d = min(ctx.primary, now() + 3000)
    applied(ctx, {:retire_generation, g2, d - ctx.t0})
    put_g(ctx, g2, :retirement_deadline, d)
    send(actor(ctx, g2, :custodian, g2), {:release_open, gate})
    {:ok, scope} = reply(ctx, operation, ctx.cleanup)
    ensure(generation(ctx, g2).scope == scope, :late_scope_registered)
    root(ctx, g2, :scope)
    applied(ctx, {:control_result, open_control, :ok})
    applied(ctx, {:scope_opened, g2})
    ensure(elem(call(ctx, :state).model.generations, gslot(g2)).phase == :retiring, :late_open_no_readiness)
    :ok = retirement_wait(ctx, g2, retire(ctx, g2))
    wire = cut(ctx)
    ensure(wire["requests"] == 0 and call(ctx, :state).fetches == 0, :retired_preparation_no_wire)
    %{late_launch: late, fetches: call(ctx, :state).fetches, requests: wire["requests"],
      late_scope_registered: true, late_readiness_published: false, retirements: [:ok, :ok]}
  end

  defp scenario(:b16, ctx) do
    ga = open_g(ctx, reserve_g(ctx))
    gb = open_g(ctx, reserve_g(ctx))
    a = simple(ctx, ga, :held)
    b = simple(ctx, gb, :held)
    ca = consume_start(ctx, a, true)
    cb = consume_start(ctx, b, true)
    wait_gate(ctx, a, ca, :chunk_held, ctx.primary)
    wait_gate(ctx, b, cb, :chunk_held, ctx.primary)
    original_b = peer_event(ctx, b, :head)
    receipt_a = retire(ctx, ga, :abort)
    release_consumer(ctx, a)
    :ok = completion(ctx, a, :abort_wait)
    :ok = retirement_wait(ctx, ga, receipt_a)
    reply(ctx, ca, ctx.cleanup)
    release_peer(ctx, b)
    release_consumer(ctx, b)
    body = consumed(ctx, b, cb)
    :ok = completion(ctx, b)
    late_b = peer_event(ctx, b, :head)
    ensure(late_b["connection"] == original_b["connection"] and body.length == 1 and body.digest == sha256("h"), :scope_b_independent)
    local_release(ctx, b)
    :ok = retirement_wait(ctx, gb, retire(ctx, gb))
    %{a_retirement: :ok, b_completion: :ok, b_length: body.length, b_digest: body.digest,
      b_connection_preserved: true, b_ends: body.ends}
  end

  defp scenario(:b17, ctx) do
    g = open_g(ctx, reserve_g(ctx))
    token = simple(ctx, g, :held)
    consumer = consume_start(ctx, token, true)
    wait_gate(ctx, token, consumer, :chunk_held, ctx.primary)
    ensure(now() < ctx.t0 + 500, :retirement_before_d)
    receipt = retire(ctx, g, :retire, ctx.t0 + 500)
    control = applied(ctx, {:begin_control, g, :abort})
    claim_generation(ctx, g, :abort)
    gate = make_ref()
    operation = command(ctx, g, :abort, g, :late_abort, {generation(ctx, g).scope, gate, ctx.cleanup})
    wait_gate(ctx, g, operation, :abort_reserved, ctx.t0 + 500)
    published = retirement_wait(ctx, g, receipt)
    ensure(published == {:error, :cleanup_pending}, :original_deadline_pending)
    overshoot = max(now() - ctx.t0 - 500, 0)
    ensure(overshoot <= 100, :retirement_tolerance)
    applied(ctx, {:advance, max(now() - ctx.t0, 500)})
    send(actor(ctx, g, :abort, g), {:release_abort, gate})
    {:ok, late_receipt} = reply(ctx, operation, ctx.cleanup)
    applied(ctx, {:control_result, control, :ok})
    ensure(generation(ctx, g).receipts.abort == late_receipt, :late_abort_registration)
    release_consumer(ctx, token)
    :ok = completion(ctx, token, :abort_wait)
    reply(ctx, consumer, ctx.cleanup)
    late = retirement_wait(ctx, g, late_receipt, true)
    ensure(late in [:ok, {:error, :cleanup_pending}], :late_public_receipt)
    model_g = elem(call(ctx, :state).model.generations, 0)
    ensure(model_g.retirement_deadline == 500 and model_g.retirement_outcome == :timed_out and elem(generation(ctx, g).waits, 0) == published, :deadline_immutable)
    %{deadline: model_g.retirement_deadline, published: published, late_published: elem(generation(ctx, g).waits, 0),
      graceful_calls: 1, abort_calls: 1, late_receipt_registered: true, overshoot_ms: overshoot}
  end

  defp scenario(:b18, ctx) do
    g = open_g(ctx, reserve_g(ctx))
    success = simple(ctx, g)
    drain(ctx, success)
    pending = simple(ctx, g, :held)
    reader = consume_start(ctx, pending, true)
    wait_gate(ctx, pending, reader, :chunk_held, ctx.primary)
    pending_result = completion(ctx, pending, :initial_wait, true)
    lost = simple(ctx, g)
    consumed(ctx, lost, consume_start(ctx, lost))
    :lost = completion(ctx, lost, :initial_wait, false, true)
    ensure(attempt(ctx, lost).lost_oracle == :ok, :independent_public_oracle)
    local_release(ctx, lost)
    lost_release = event(ctx, {:release_attempt, lost})
    ensure(lost_release == {:error, :lost_proof}, :lost_fixture_proof_held)
    receipt = retire(ctx, g)
    retired_pending = retirement_wait(ctx, g, receipt, true)
    release_peer(ctx, pending)
    release_consumer(ctx, pending)
    consumed(ctx, pending, reader)
    :ok = completion(ctx, pending, :abort_wait)
    abort_receipt = retire(ctx, g, :abort)
    final = retirement_wait(ctx, g, abort_receipt)
    %{success: attempt(ctx, success).controls.initial_wait.result, pending: pending_result,
      lost_public_oracle: attempt(ctx, lost).lost_oracle, lost_fixture_proof: true, lost_release: lost_release,
      pending_preserved: attempt(ctx, pending).controls.initial_wait.result == pending_result,
      retirement_pending: retired_pending, retirement_final: final}
  end

  defp scenario(:b19, ctx) do
    g = open_g(ctx, reserve_g(ctx))
    sibling = simple(ctx, g, :held)
    consumer = consume_start(ctx, sibling, true)
    wait_gate(ctx, sibling, consumer, :chunk_held, ctx.primary)
    connections = Enum.map(1..8, fn _ ->
      token = simple(ctx, g)
      head = peer_event(ctx, token, :head)
      %{length: 2, digest: digest, ends: 1} = drain(ctx, token)
      ensure(digest == sha256("ok"), :reuse_body)
      head["connection"]
    end)
    ensure(Enum.uniq(connections) == [2], :finite_connection_reuse)
    wire = cut(ctx)
    ensure(wire["connections"] == 2 and wire["requests"] == 9, :reuse_no_new_accept)
    held = Model.snapshot(call(ctx, :state).model)
    ensure(held.occupied_attempts == {9, 0, 0, 0}, :nine_proof_slots)
    release_peer(ctx, sibling)
    release_consumer(ctx, sibling)
    body = consumed(ctx, sibling, consumer)
    :ok = completion(ctx, sibling)
    local_release(ctx, sibling)
    %{sequential: length(connections), reused_connection: true, accepted_connections: wire["connections"],
      held_sibling_length: body.length, held_sibling_ends: body.ends, occupied_proof_slots: elem(held.occupied_attempts, 0), refunds: 0}
  end

  defp scenario(:b20, ctx) do
    g = open_g(ctx, reserve_g(ctx))
    {:ok, %{lifecycle: :open}} = snapshot(ctx, g)
    token = simple(ctx, g, :held)
    reader = consume_start(ctx, token, true)
    wait_gate(ctx, token, reader, :chunk_held, ctx.primary)
    {:ok, _} = snapshot(ctx, g)
    {:error, :cleanup_pending} = completion(ctx, token, :initial_wait, true)
    state = call(ctx, :state)
    invalid = event(ctx, {:begin_control, token, :invalid_fixture_operation})
    {:ok, :cached} = event(ctx, {:begin_control, token, :initial_wait})
    {:attempt, generation, slot, _} = token
    old = {:attempt, generation, slot, make_ref()}
    stale = event(ctx, {:control_result, {:control, old, :initial_wait, make_ref()}, :ok})
    ensure(stale == {:ok, :stale} and call(ctx, :state).model == state.model, :invalid_stale_unchanged)
    counts = call(ctx, :state)
    ensure(counts.actors == state.actors and counts.operation == state.operation, :no_extra_callers)
    receipt = retire(ctx, g)
    release_peer(ctx, token)
    release_consumer(ctx, token)
    consumed(ctx, token, reader)
    :ok = completion(ctx, token, :abort_wait)
    :ok = retirement_wait(ctx, g, receipt)
    final = snapshot(ctx, g)
    valid = case final do
      {:error, :transport_scope_retired} -> true
      {:ok, %{lifecycle: lifecycle}} -> lifecycle != :open
      _ -> false
    end
    ensure(valid, :final_snapshot_oracle)
    state = call(ctx, :state)
    shape = tuple_size(state.generations) == 4 and Enum.all?(Tuple.to_list(state.generations), fn nil -> true; row -> tuple_size(row.attempts) == 32 end)
    oracle = %{snapshots: generation(ctx, g).snapshots, invalid_operation: invalid, duplicate_cached: true,
      stale_ignored: true, counts_unchanged: true, fixed_shape: shape, final_snapshot_valid: valid}
    Map.put(oracle, :row_bytes, byte_size(JSON.encode!(json_value(oracle))))
  end

  defp b13_launched(ctx, g, oracle) do
    launched = simple(ctx, g, :held)
    {:error, :cleanup_pending} = completion(ctx, launched, :initial_wait, true)
    local_release(ctx, launched)
    launched_release = event(ctx, {:release_attempt, launched})
    ensure(launched_release == {:error, :ownership_pending}, :launched_proof_not_recycled)
    release_peer(ctx, launched)
    consumed(ctx, launched, consume_start(ctx, launched))
    :ok = completion(ctx, launched, :abort_wait)
    Map.put(oracle, :launched_release, launched_release)
  end

  defp invoke_death(ctx, g, role, token) do
    _ = command(ctx, g, role, token, :die, nil)
    index = role_index(g, role, token)
    :fixture_declared_death = call(ctx, {:actor_join, index, ctx.primary})
    # The persistent slot is consumed; no source actor is respawned.
  end

  defp cleanup(ctx) do
    :ok = call(ctx, :close_admission)
    # Each step is attempted independently; one failed row cannot abandon later
    # originals. All failures are compact and survive the peer/actor joins.
    failures = []
    failures = cleanup_step(failures, :peer_in_flight, fn ->
      if ctx.peer do
        actor = elem(call(ctx, :state).actors, 664)
        if actor.status == :alive and actor.operation != nil,
          do: reply(ctx, {664, actor.operation, :peer}, ctx.cleanup)
      end
    end)
    failures = cleanup_step(failures, :peer_release, fn ->
      if ctx.peer do
        peer_state = peer(ctx, :state, nil, ctx.cleanup)
        Enum.each(0..127, fn index ->
          if Map.has_key?(elem(peer_state.requests, index), "armed") and not elem(peer_state.released, index),
            do: peer(ctx, :control, {:control, "release", index, nil}, ctx.cleanup)
        end)
      end
    end)
    generations = call(ctx, :state).generations |> Tuple.to_list() |> Enum.reject(&is_nil/1) |> Enum.map(& &1.token)
    failures = Enum.reduce(generations, failures, fn g, failures ->
      tokens = generation(ctx, g).attempts |> Tuple.to_list() |> Enum.reject(&is_nil/1) |> Enum.map(& &1.token)
      Enum.reduce(tokens, failures, fn
        token, failures ->
          cleanup_step(failures, :attempt_cleanup, fn ->
            cleanup_attempt(ctx, g, token)
          end)
      end)
    end)
    failures = Enum.reduce(generations, failures, fn g, failures ->
      cleanup_step(failures, :scope_cleanup, fn -> cleanup_scope(ctx, g) end)
    end)
    peer_result = if ctx.peer do
      try do
        result = peer(ctx, :control, {:control, "stop", nil, nil}, ctx.shutdown)
        ensure(result["event"] == "stopped" and result["exit"] == 0 and
          result["alive_workers"] == 0 and result["accept_join"] == true and result["failure_seen"] == nil, :peer_join)
        %{ok: true, connections: result["connections"], requests: result["requests"], workers: result["joined_workers"]}
      rescue
        _ -> %{ok: false}
      catch
        :exit, _ -> %{ok: false}
      end
    else
      %{ok: true, connections: 0, requests: 0, workers: 0}
    end
    state = call(ctx, :state)
    Enum.each(Tuple.to_list(state.actors), fn
      %{status: :alive, pid: pid} -> send(pid, {:stop, ctx.shutdown})
      _ -> :ok
    end)
    joined = call(ctx, {:join, ctx.shutdown})
    actors = Tuple.to_list(joined.actors) |> Enum.reject(&is_nil/1)
    actor_ok = Enum.all?(actors, fn actor ->
      actor.status in [:normal, :fixture_declared_death, :fixture_proof_dropped, :fixture_producer_shutdown]
    end)
    uploads = Enum.flat_map(generations, fn g ->
      generation(ctx, g).attempts |> Tuple.to_list() |> Enum.reject(&is_nil/1)
      |> Enum.filter(&(&1.upload != nil))
    end)
    upload_ok = Enum.all?(uploads, &(&1.upload_status in [:normal, :fixture_producer_shutdown]))
    failures = Enum.reduce(generations, failures, fn g, failures ->
      cleanup_step(failures, :local_root_release, fn -> cleanup_local_roots(ctx, g, joined) end)
    end)
    failures = cleanup_step(failures, :result_preservation, fn -> preserve_rows(ctx, joined) end)
    identity_ok = try do
      initial = JSON.decode!(File.read!(Path.join(@audit, "run-identity.json")))
      current = identity(System.fetch_env!("HTTP_FETCH_PEER_PYTHON")) |> JSON.encode!() |> JSON.decode!()
      ensure(initial == current, :identity_drift)
      true
    rescue _ -> false end
    %{ok: failures == [] and actor_ok and upload_ok and peer_result.ok and identity_ok,
      evidence: %{failed_steps: Enum.uniq(failures), actors_joined: Enum.count(actors, &(&1.status != :alive)),
        actors_total: length(actors), uploads_joined: Enum.count(uploads, &(&1.upload_status != :alive)),
        uploads_total: length(uploads), peer: peer_result, identity_stable: identity_ok}}
  end

  defp cleanup_step(failures, step, function) do
    try do
      function.()
      failures
    rescue
      _ -> [step | failures]
    catch
      :exit, _ -> [step | failures]
    end
  end

  defp cleanup_attempt(ctx, g, token) do
    source_index = role_index(g, :source, token)
    source = elem(call(ctx, :state).actors, source_index)
    failures = cleanup_step([], :source_cleanup, fn ->
      if source != nil and source.status == :alive do
        if source.operation != nil do
          late = reply(ctx, {source_index, source.operation, token}, ctx.cleanup)
          put_a(ctx, token, :late_public_result, late)
        end
        invoke(ctx, g, :source, token, :drop, nil, ctx.cleanup)
        Enum.each([:source, :prepared], &release_root(ctx, token, &1))
      end
    end)
    row = attempt(ctx, token)
    consumer = elem(call(ctx, :state).actors, role_index(g, :consumer, token))
    if consumer != nil and consumer.status == :alive, do: send(consumer.pid, {:release_consumer, token})
    if row.upload != nil and row.upload_finish == 0 and row.upload_status == :alive,
      do: HTTP.Stream.error(row.upload, :aborted)
    failures = Enum.reduce([:initial_wait, :abort_wait], failures, fn role, failures ->
      cleanup_step(failures, :completion_in_flight, fn -> settle_role(ctx, g, role, token) end)
    end)
    failures = cleanup_step(failures, :completion_cleanup, fn ->
      row = attempt(ctx, token)
      if row.completion != nil do
        confirmed = (row.controls.initial_wait != nil and row.controls.initial_wait.result == :ok) or
          (row.controls.abort_wait != nil and row.controls.abort_wait.result == :ok) or row.lost_oracle == :ok
        if not confirmed and row.controls.abort_wait == nil do
          :ok = completion(ctx, token, :abort_wait)
        end
      else
        model_a = elem(elem(call(ctx, :state).model.generations, gslot(g)).attempts, aslot(token))
        if model_a != nil and not model_a.lost_proof and not row.local_released,
          do: local_release(ctx, token)
      end
    end)
    failures = cleanup_step(failures, :consumer_in_flight, fn ->
      settle_role(ctx, g, :consumer, token)
    end)
    ensure(failures == [], :attempt_cleanup_failed)
  end

  defp cleanup_scope(ctx, g) do
    failures = Enum.reduce([:custodian, :retire, :abort], [], fn role, failures ->
      cleanup_step(failures, :scope_in_flight, fn -> settle_role(ctx, g, role, g) end)
    end)
    failures = Enum.reduce(0..1, failures, fn index, failures ->
      cleanup_step(failures, :retirement_wait_in_flight, fn -> settle_role(ctx, g, :retirement_wait, index) end)
    end)
    row = generation(ctx, g)
    if row.scope != nil and not row.retired do
      # A late original open/receipt is already registered by its owned actor.
      model_g = elem(call(ctx, :state).model.generations, gslot(g))
      if model_g.roots.scope == nil, do: root(ctx, g, :scope)
      if match?(%Model.Control{result: :pending}, model_g.controls.open) do
        applied(ctx, {:control_result, model_g.controls.open.token, :ok})
        applied(ctx, {:scope_opened, g})
      end
      failures = cleanup_step(failures, :graceful_cleanup, fn ->
        row = generation(ctx, g)
        if not row.issued.retire, do: retire(ctx, g)
        row = generation(ctx, g)
        ensure(not row.issued.retire or row.receipts.retire != nil, :original_retire_receipt)
        if not elem(row.wait_issued, 0) and row.receipts.retire != nil,
          do: retirement_wait(ctx, g, row.receipts.retire)
      end)
      failures = cleanup_step(failures, :abort_cleanup, fn ->
        row = generation(ctx, g)
        if not row.retired do
          if not row.issued.abort, do: retire(ctx, g, :abort)
          row = generation(ctx, g)
          ensure(row.receipts.abort != nil, :original_abort_receipt)
          if not elem(row.wait_issued, 1), do: retirement_wait(ctx, g, row.receipts.abort)
        end
      end)
      row = generation(ctx, g)
      ensure(failures == [] and (row.retired or (ctx.id == "B17" and elem(row.waits, 0) == {:error, :cleanup_pending})), :scope_cleanup_confirmation)
    else
      ensure(failures == [] and (row.scope != nil or not row.issued.open), :missing_original_scope)
    end
  end

  defp settle_role(ctx, g, role, owner) do
    index = role_index(g, role, owner)
    case elem(call(ctx, :state).actors, index) do
      %{status: :alive, operation: operation} when operation != nil ->
        result = reply(ctx, {index, operation, owner}, ctx.cleanup)
        case role do
          role when role in [:initial_wait, :abort_wait] ->
            ensure(result in [:ok, {:error, :cleanup_pending}], :late_completion_result)
            control = attempt(ctx, owner).controls[role]
            applied(ctx, {:control_result, control.token, model_result(result)})
            if result == :ok, do: applied(ctx, {:request_completed, owner})
          role when role in [:retire, :abort] ->
            ensure(match?({:ok, _}, result), :late_original_receipt)
            control = elem(call(ctx, :state).model.generations, gslot(g)).controls[role]
            applied(ctx, {:control_result, control.token, :ok})
          :retirement_wait ->
            ensure(result in [:ok, {:error, :cleanup_pending}], :late_retirement_result)
            if result == :ok do
              applied(ctx, {:scope_retired, g})
              put_g(ctx, g, :retired, true)
            end
          :consumer -> put_a(ctx, owner, :response, result)
          :custodian -> ensure(match?({:ok, _}, result), :late_original_scope)
        end
      nil -> :ok
      %{status: status} when status in [:alive, :fixture_declared_death, :fixture_proof_dropped] -> :ok
      %{operation: nil} -> :ok
      _ -> raise "missing original actor result"
    end
  end

  defp cleanup_local_roots(ctx, g, joined) do
    row = generation(ctx, g)
    Enum.each(Tuple.to_list(row.attempts), fn
      nil -> :ok
      request ->
        source = elem(joined.actors, role_index(g, :source, request.token))
        ensure(source == nil or source.status != :alive, :source_join_before_release)
        Enum.each(Map.keys(request.roots), &release_root(ctx, request.token, &1))
        Enum.each(request.controls, fn {operation, control} ->
          if control do
            helper = elem(joined.actors, role_index(g, operation, request.token))
            ensure(helper != nil and helper.status != :alive, :helper_join_before_release)
            applied(ctx, {:control_helper_released, control.token})
          end
        end)
        # Drop actual handles after recording their separate results. Their
        # symbolic native control obligations remain occupied and outstanding.
        put_a(ctx, request.token, :public_result, evidence_public(request.public_result))
        put_a(ctx, request.token, :late_public_result, evidence_public(request.late_public_result))
        Enum.each([:promise, :completion, :stream, :upload, :prepared], &put_a(ctx, request.token, &1, nil))
    end)
    Enum.each(Map.keys(generation(ctx, g).roots), &release_root(ctx, g, &1))
    model_g = elem(call(ctx, :state).model.generations, gslot(g))
    Enum.each(model_g.controls, fn {_operation, control} ->
      if control != :unused, do: applied(ctx, {:control_helper_released, control.token})
    end)
    Enum.each([:scope, :policy], &put_g(ctx, g, &1, nil))
    put_g(ctx, g, :receipts, %{retire: nil, abort: nil})
  end

  defp evidence_public(%{status: _} = result), do: Map.take(result, [:status, :buffered])
  defp evidence_public({:ok, %{head_sha256: _} = result}),
    do: {:ok, Map.take(result, [:supplied_count, :pure_charge, :initial_count, :initial_charge,
      :effective_count, :effective_charge, :field_sha256, :head_sha256, :head_length, :compact])}
  defp evidence_public(result) when result in [nil, :ok], do: result
  defp evidence_public({:error, reason}) when is_atom(reason), do: {:error, reason}
  defp evidence_public({:error, reason}), do: {:error, compact_reason(reason)}
  defp evidence_public(_), do: raise("unexpected public result evidence")

  defp joined_status(joined, index) do
    case elem(joined.actors, index) do
      nil -> :unused
      %{status: status} when status in [:alive, :normal, :fixture_declared_death,
        :fixture_proof_dropped, :fixture_producer_shutdown] -> status
      _ -> :unexpected_exit
    end
  end

  defp preserve_rows(ctx, joined) do
    state = call(ctx, :state)
    run_origin = File.read!(Path.join(@audit, "run-origin")) |> String.to_integer()
    # One bounded diagnostic row is encoded/written at a time by the existing
    # controller; there is no history collector or additional resource role.
    File.open!(Path.join(@audit, ctx.id <> "-attempt-results.jsonl"), [:write], fn file ->
      Enum.each(Tuple.to_list(state.generations), fn
        nil -> :ok
        generation ->
          Enum.each(Tuple.to_list(generation.attempts), fn
            nil -> :ok
            row ->
              g = generation.token
              model_a = elem(elem(state.model.generations, gslot(g)).attempts, aslot(row.token))
              helper_join = Map.new([:source, :producer, :consumer, :initial_wait, :abort_wait], fn role ->
                {role, joined_status(joined, role_index(g, role, row.token))}
              end)
              evidence = %{id: ctx.id, run_origin: run_origin, generation_slot: gslot(g), attempt_slot: aslot(row.token),
                public_result: evidence_public(row.public_result), late_public_result: evidence_public(row.late_public_result),
                original_deadline: row.deadline - ctx.t0, connect_deadline: row.connect_deadline - ctx.t0,
                published_outcome: if(model_a, do: model_a.outcome, else: :released_local),
                fetch_issued: row.fetch_issued, helper_join: helper_join,
                controls: Map.new(row.controls, fn {role, control} -> {role, if(control, do: control.result, else: :unused)} end),
                lost_public_oracle: row.lost_oracle, response: row.response,
                local_roots_released: map_size(row.roots) == 0,
                data_credit_released: model_a == nil or Enum.all?(Map.values(model_a.chunks), &is_nil/1),
                native_frontier: :unestablished}
              write_evidence_row(file, evidence)
          end)
      end)
    end)
    File.open!(Path.join(@audit, ctx.id <> "-generation-results.jsonl"), [:write], fn file ->
      Enum.each(Tuple.to_list(state.generations), fn
        nil -> :ok
        row ->
          g = row.token
          model_g = elem(state.model.generations, gslot(g))
          helpers = Map.new([:custodian, :retire, :abort, :snapshot], fn role ->
            {role, joined_status(joined, role_index(g, role, g))}
          end)
          evidence = %{id: ctx.id, run_origin: run_origin, generation_slot: gslot(g), issued: row.issued,
            public_results: row.operation_results, original_deadline: model_g.retirement_deadline,
            published_outcome: model_g.retirement_outcome, waits_issued: Tuple.to_list(row.wait_issued),
            public_waits: Tuple.to_list(row.waits), helper_join: helpers,
            retirement_helpers: Enum.map(0..1, &joined_status(joined, role_index(g, :retirement_wait, &1))),
            local_roots_released: map_size(row.roots) == 0, native_frontier: :unestablished}
          write_evidence_row(file, evidence)
      end)
    end)
  end

  defp write_evidence_row(file, evidence) do
    line = JSON.encode!(json_value(evidence))
    ensure(byte_size(line) <= 4096, :evidence_row_limit)
    :ok = IO.binwrite(file, line <> "\n")
  end
end
