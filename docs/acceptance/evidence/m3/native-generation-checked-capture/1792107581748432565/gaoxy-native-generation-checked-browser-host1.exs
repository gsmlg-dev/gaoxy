# Source-only fixture; execute only after Task3.5 and final checked call wiring pass.
defmodule CheckedBrowserHost do
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Exchange, Generation, Resources, Router}
  alias Gaoxy.Proxy.{GroupEndpoint, ManagedGenerationAccounting, UpstreamGroups}
  alias Gaoxy.Proxy.UpstreamTransports, as: T
  @m 1_048_576
  defmodule Captured do
    def init({group, host}) do
      with {:ok, config} <- GroupEndpoint.init(%{group: group}), do: {:ok, {config, host}}
    end
    def resources({config, _}), do: GroupEndpoint.resources(config)
    def call(exchange, {config, host}) do
      token = make_ref()
      send(host, {:capture, self(), token, exchange})
      receive do
        {:dispatch, ^token} -> GroupEndpoint.call(exchange, config)
      after
        min(10_000, Lifecycle.remaining(exchange.deadline)) ->
          {:error, :checked_browser_barrier_expired, exchange}
      end
    end
  end
  def emit(event, fields \\ %{}), do: IO.puts("CHECKED_BROWSER " <> JSON.encode!(Map.put(fields, :event, event)))
  def deadline, do: Lifecycle.deadline(10_000)
  def wait_until(fun, d) do
    if fun.() do
      :ok
    else
      true = Lifecycle.remaining(d) > 0
      receive do after 2 -> wait_until(fun, d) end
    end
  end
  def identity do
    root = File.cwd!() |> Path.expand()
    for app <- [:gaoxy, :gaoxy_http, :gaoxy_proxy], module <- Application.spec(app, :modules) do
      Code.ensure_loaded!(module)
      {^module, bytes, beam_path} = :code.get_object_code(module)
      beam_path = to_string(beam_path) |> Path.expand()
      true = String.starts_with?(beam_path, root <> "/_build/")
      ^bytes = File.read!(beam_path)
      {:ok, {^module, md5}} = :beam_lib.md5(bytes)
      ^md5 = module.module_info(:md5)
      source = module.module_info(:compile) |> Keyword.fetch!(:source) |> to_string() |> Path.expand()
      true = String.starts_with?(source, root <> "/apps/#{app}/")
      %{module: to_string(module), source: source, source_sha256: hash(File.read!(source)),
        beam: beam_path, beam_sha256: hash(bytes), loaded_md5: Base.encode16(md5, case: :lower)}
    end
  end
  def hash(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
  def run(port, evidence) do
    Process.flag(:trap_exit, true)
    before = identity()
    File.write!(Path.join(evidence, "host-loaded-before.json"), JSON.encode!(before))
    {:ok, instance} = Gaoxy.start_link()
    {:ok, transports} = T.start_link(instance: instance, limits: %{max_resources: 32,
      max_pins: 4096, max_request_tokens: 64, max_owned_payload_bytes: 67_108_864})
    {:ok, groups} = UpstreamGroups.start_link(instance: instance, limits: %{max_groups: 64,
      max_pins: 1024, max_probes: 1, max_config_bytes: 67_108_864})
    source = %{origin: "http://localhost:#{port}", connect_address: {127, 0, 0, 1}, trust: nil}
    {:ok, t, tp} = T.prepare(transports, source, self(), deadline())
    {:ok, compiled} = UpstreamGroups.compile(%{id: "checked-browser", members: [
      %{id: "one", upstream: source.origin, transport: t, connect_address: nil}],
      health: %{path: "/health", interval: 60_000, stale_after: 120_000,
        timeout: 2_000, jitter: 0, recovery_threshold: 1}})
    {:ok, g, gp} = UpstreamGroups.prepare(groups, compiled, self(), deadline())
    {:ok, router} = Router.compile([%{target: {Captured, {g, self()}}}])
    {:ok, store} = Generation.start_link(router: router, max_config_bytes: @m)
    :ok = Resources.release(gp ++ tp)
    wait_until(fn -> match?(%{members: [%{health: :healthy, probe: false}], probes: 0}, UpstreamGroups.status(g)) end, deadline())
    wait_until(fn -> UpstreamGroups.status(g).pins == 1 and elem(T.status(transports), 1).pins == 1 end, deadline())
    host = self()
    for owner <- [groups, transports] do
      :ok = :sys.install(owner, {make_ref(), fn previous, event, _ ->
        case event do
          {:in, {:"$gen_call", {^store, _}, {tag, batch, holder, :request, op, d}}}
          when tag in [:pin, :pin_many] ->
            send(host, {:original, owner, batch, holder, op, d, Gaoxy.status(instance, :http)})
          _ -> :ok
        end
        previous
      end, nil})
      1 = :erlang.trace(owner, true, [:send, {:tracer, self()}])
    end
    {:ok, spec} = Gaoxy.HTTP.service_spec(endpoint: {Generation, {store, accounting: ManagedGenerationAccounting}},
      protocols: [:http1], h2c: :disabled, limits: %{max_bytes: 67_108_864},
      http_limits: %{request_timeout: 15_000})
    {:ok, _} = Gaoxy.add(instance, spec)
    {:ok, {{127, 0, 0, 1}, listen_port}} = Gaoxy.info(instance, :http).local
    input = spawn_link(fn ->
      Stream.repeatedly(fn -> IO.gets("") end) |> Enum.reduce_while(nil, fn
        :eof, _ -> send(host, :input_eof); {:halt, nil}
        line, _ -> send(host, {:command, JSON.decode!(line)}); {:cont, nil}
      end)
    end)
    input_monitor = Process.monitor(input)
    emit("ready", %{port: listen_port, endpoint: "Generation checked ManagedGenerationAccounting"})
    loop(%{instance: instance, transports: transports, groups: groups, store: store,
      g: g, t: t, input: input, input_monitor: input_monitor, evidence: evidence, before: before, captures: 0, originals: [], receipts: []})
  end
  def independent_b(retained, b \\ 0, n \\ 0)
  def independent_b(retained, b, n) when n < 64 do
    e = &:erlang.external_size/1
    next = 6 * @m + 4_957_373 + 3 * (e.(retained) - 3) + 5 * (e.(b) - 6) + 4 * (e.(retained + b) - 6)
    if next == b, do: b, else: independent_b(retained, next, n + 1)
  end
  def independent_b(_, _, _), do: raise("browser B did not converge")
  def loop(s) do
    receive do
      {:original, owner, batch, holder, op, d, status} ->
        loop(%{s | originals: s.originals ++ [%{owner: owner, batch: batch, holder: holder, operation: op, deadline: d, status: status}]})
      {:capture, native, token, exchange} ->
        true = s.captures == 0 and exchange.transport == nil
        # Messages from distinct owners can arrive after the captured endpoint message.
        originals = collect_originals(s.originals, 2)
        true = length(exchange.resource_pins) == 2
        true = MapSet.new(Enum.flat_map(exchange.resource_pins, & &1.handles)) == MapSet.new([s.g, s.t])
        retained = Exchange.retained_bytes(exchange) - exchange.route_bytes
        b = independent_b(retained)
        ^b = exchange.route_bytes
        {:ok, {:native_generation_capture_v1, @m, 65_536, 65_536, ^b}} = ManagedGenerationAccounting.reservation(@m,
          {s.store, native, exchange.gate, exchange.lease, :request, exchange.deadline, retained})
        total = retained + b
        for original <- originals do
          true = original.holder === native and original.deadline === exchange.deadline
          true = original.status.retained_bytes == total
        end
        for pin <- exchange.resource_pins do
          original = Enum.find(originals, &(&1.owner === pin.owner))
          :ok = ManagedGenerationAccounting.correlate(pin,
            {pin.provider, original.owner, original.operation, original.batch}, native)
          if pin.provider == T, do: true = pin.holder === native
          owner = pin.owner
          if not Enum.any?(s.receipts, fn {p, observed} -> p === owner and observed === pin end) do
            receive do
              {:trace, ^owner, :send, {_tag, {:ok, observed}}, _} when observed === pin -> :ok
            after 1000 -> raise "actual public owner receipt missing" end
          end
        end
        true = Admission.status(exchange.gate).retained_bytes == total
        gate = :sys.get_state(exchange.gate, 1000)
        true = Map.fetch!(gate.leases, exchange.lease).bytes == total
        emit("captured", %{pins: Enum.map(exchange.resource_pins, fn p -> %{provider: to_string(p.provider),
          kind: to_string(p.kind), bytes: :erlang.external_size(p), operation: inspect(p.operation)} end),
          holder: inspect(native), retained: retained, reservation: b, gate_bytes: total,
          original_owner_effects: length(originals), original_gate_bytes: Enum.map(originals, & &1.status.retained_bytes)})
        send(native, {:dispatch, token})
        loop(%{s | captures: 1, originals: originals})
      {:command, %{"op" => "request_clean"}} ->
        true = s.captures == 1
        wait_until(fn -> UpstreamGroups.status(s.g).pins == 1 and elem(T.status(s.transports), 1).pins == 1 and
          UpstreamGroups.status(s.g).inflight == 0 and elem(T.status(s.transports), 1).request_tokens == 0 and
          elem(T.status(s.transports), 1).helpers == 0 end, deadline())
        emit("request_clean", %{group: Map.take(UpstreamGroups.status(s.g), [:pins, :inflight, :probes]),
          transport: Map.take(elem(T.status(s.transports), 1), [:pins, :request_tokens, :helpers, :resources])})
        loop(s)
      {:command, %{"op" => "stop"}} ->
        wait_until(fn -> match?(%{active: 0, retained_bytes: 0, cleanup_pending: 0, cleanup_failed: nil}, Gaoxy.status(s.instance, :http)) end, deadline())
        emit("closed_browser_clean", %{service: Map.take(Gaoxy.status(s.instance, :http), [:active, :retained_bytes, :cleanup_pending, :cleanup_failed])})
        stop_join(s.store)
        wait_until(fn -> match?({:ok, %{resources: 0, pins: 0, request_tokens: 0, helpers: 0,
          reserved_connections: 0, owned_serialized_payload_bytes: 0}}, T.status(s.transports)) end, deadline())
        stop_join(s.groups)
        ref = Process.monitor(s.transports)
        :ok = Gaoxy.stop(s.instance, 10_000)
        receive do {:DOWN, ^ref, :process, pid, :normal} when pid == s.transports -> :ok
        after 10_000 -> raise "transport shutdown join deadline" end
        true = not Process.alive?(s.instance)
        after_identity = identity()
        true = s.before === after_identity
        File.write!(Path.join(s.evidence, "host-loaded-after.json"), JSON.encode!(after_identity))
        emit("stopped", %{cleanup_confirmed: true, source_stable: true, captures: s.captures})
        receive do {:command, %{"op" => "exit"}} -> :ok after 10_000 -> raise "host exit command deadline" end
        input_ref = s.input_monitor
        receive do {:DOWN, ^input_ref, :process, pid, :normal} when pid == s.input -> :ok
        after 1000 -> raise "host stdin helper join deadline" end
        emit("exited")
      :input_eof -> raise "stdin closed before stop"
      {:trace, owner, :send, {_tag, {:ok, %{kind: :request} = pin}}, _} when s.captures == 0 ->
        true = length(s.receipts) < 2
        loop(%{s | receipts: s.receipts ++ [{owner, pin}]})
      {:trace, _, :send, _, _} -> loop(s)
      {:EXIT, _, :normal} -> loop(s)
      other -> raise "unexpected host message: #{inspect(other)}"
    after 30_000 -> raise "host command/capture deadline" end
  end
  def collect_originals(rows, count) when length(rows) == count, do: rows
  def collect_originals(rows, count) do
    receive do
      {:original, owner, batch, holder, op, d, status} -> collect_originals(rows ++ [%{owner: owner,
        batch: batch, holder: holder, operation: op, deadline: d, status: status}], count)
    after 1000 -> raise "owner input observation missing" end
  end
  def stop_join(pid) do
    ref = Process.monitor(pid)
    :ok = GenServer.stop(pid, :normal, 5000)
    receive do {:DOWN, ^ref, :process, ^pid, :normal} -> :ok
    after 5000 -> raise "host actor join deadline" end
  end
end
[port, evidence] = System.argv()
CheckedBrowserHost.run(String.to_integer(port), evidence)
