# Source-only additive runtime contract tests. Append beside the existing HTTP
# constructor/runtime modules; do not execute before Task 3.5 closes.
defmodule Gaoxy.HTTP.GenerationCheckedRuntimeContractTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Admission
  alias Gaoxy.HTTP.{Exchange, Generation, Request, Resources, Router}
  alias Gaoxy.HTTP.GenerationCheckedCaptureTest.{Accounting, Provider}
  @budget 16_384
  @prior 37

  defmodule ContractAccounting do
    @budget 16_384
    def reservation(m, context) do
      config = Process.get(__MODULE__)
      send(config.observer, {config.token, :reservation_called, self(), m, context})
      plan = {:native_generation_capture_v1, m, 65_536, 65_536, @budget}
      case config.reservation do
        {:field, index, value} -> {:ok, put_elem(plan, index, value)}
        :short_plan -> {:ok, {:native_generation_capture_v1, m, 65_536, 65_536}}
        :long_plan -> {:ok, {:native_generation_capture_v1, m, 65_536, 65_536, @budget, :extra}}
        :non_tuple_plan -> {:ok, %{m: m, b: @budget}}
        {:return, value} -> value
        :raise -> raise "reservation callback raised"
        :throw -> throw({:reservation_raw_throw, config.token})
        :exit -> exit({:reservation_raw_exit, config.token})
        :valid -> {:ok, plan}
      end
    end

    defdelegate validate_manifest(handles), to: Accounting
    defdelegate correlate(pin, entry, holder), to: Accounting
    defdelegate preflight_cons(pin, pins), to: Accounting
    defdelegate finite_checked_reason(raw), to: Accounting

    def preflight_append(new, existing) do
      config = Process.get(__MODULE__)
      send(config.observer, {config.token, :append_operands, self(), new, existing})
      # The rejection is derived from genuine accepted operands (2+63 pins),
      # not an injected error or a fabricated capacity summary.
      Accounting.preflight_append(new, existing)
    end

    def release(pin, dc) do
      config = Process.get(__MODULE__)
      send(config.observer, {config.token, :release_attempt, self(), pin, dc})
      case config.cleanup do
        :ok -> Provider.release(pin, dc)
        :error -> {:error, {:raw_release, config.token}}
        :raise -> raise "append cleanup raised"
        :throw -> throw({:raw_release_throw, config.token})
        :exit -> exit({:raw_release_exit, config.token})
      end
    end
  end

  defmodule Target do
    def init(options), do: {:ok, options}
    def resources(options), do: options.handles
    def call(exchange, options) do
      config = Process.get(ContractAccounting)
      send(options.observer, {config.token, :router_entered, self(), exchange})
      {:ok, exchange}
    end
  end

  setup do
    assert Code.ensure_loaded?(Resources)
    assert function_exported?(Resources, :pin_many_checked, 4)
    assert function_exported?(Resources, :release_checked, 3)
    assert function_exported?(Generation, :snapshot_for_request, 4)
    :ok
  end

  @tag :checked_capture_runtime
  test "compact success payload validates exact marker M H Q B and tuple grammar before effects" do
    fixture = fixture()
    invalid = [
      {:field, 0, :another_profile}, {:field, 0, nil},
      {:field, 1, 1_048_577}, {:field, 1, 0}, {:field, 1, :wrong_m},
      {:field, 2, 65_535}, {:field, 2, :wrong_h},
      {:field, 3, 65_537}, {:field, 3, :wrong_q},
      {:field, 4, -1}, {:field, 4, 1.5}, {:field, 4, nil},
      :short_plan, :long_plan, :non_tuple_plan
    ]
    for mode <- invalid, do: assert_reservation_refusal(fixture, mode, :invalid_generation_capture)
  end

  @tag :checked_capture_runtime
  test "non-contract outer reservation results normalize to generation unavailable before effects" do
    fixture = fixture()
    for value <- [:ok, nil, {:unexpected, :outer}, {:ok, :extra, :arity},
      %{raw: String.duplicate("r", 70_000)}] do
      assert_reservation_refusal(fixture, {:return, value}, :generation_unavailable)
    end
  end

  @tag :checked_capture_runtime
  test "reservation raise throw and exit normalize finitely before effects" do
    fixture = fixture()
    for mode <- [:raise, :throw, :exit],
      do: assert_reservation_refusal(fixture, mode, :generation_unavailable)
  end

  @tag :checked_capture_runtime
  test "explicit reservation errors preserve finite reasons and normalize unknown raw reasons" do
    fixture = fixture()
    for {raw, expected} <- [
      {:byte_limit, :byte_limit}, {:generation_capture_capacity, :generation_capture_capacity},
      {:invalid_generation_capture, :invalid_generation_capture},
      {{:unknown, String.duplicate("x", 70_000)}, :generation_unavailable}
    ] do
      assert_reservation_refusal(fixture, {:return, {:error, raw}}, expected)
    end
  end

  @tag :checked_capture_runtime
  test "nonnegative B grammar accepts zero without inventing a positive-only restriction" do
    fixture = fixture()
    request = request(fixture, {:field, 4, 0}, :ok, 0)
    token = request.token
    handler = observe_cleanup(request)
    d = deadline(1_000)
    try do
      send(request.caller, {:run, d})
      assert_receive {^token, :router_entered, caller, captured}, 1_000
      assert caller === request.caller
      assert captured.route_bytes === @prior
      assert_receive {^token, :outcome, {:returned, {:ok, result}}}, 1_000
      assert result === captured
      assert Admission.status(fixture.gate).retained_bytes == request.initial
      attempts = drain_releases(request.token, [])
      assert_exact_releases(attempts, captured.resource_pins, request.caller, d + 1_000)
      for owner <- fixture.new_owners, do: assert(GenServer.call(owner, :count) == 1)
      refute_receive {^token, :cleanup_event, _, _, _}, 0
    after
      :telemetry.detach(handler)
      finish_request(request, fixture)
    end
  end

  @tag :checked_capture_runtime
  test "actual append 2 plus 63 count capacity releases each original new receipt once without Router or refund" do
    assert_append_rejection(:ok)
  end

  @tag :checked_capture_runtime
  test "unconfirmed append cleanup preserves capacity primary and emits acquisition event exactly once" do
    for cleanup <- [:error, :raise, :throw, :exit], do: assert_append_rejection(cleanup)
  end

  defp assert_reservation_refusal(fixture, mode, expected) do
    request = request(fixture, mode, :ok, 0)
    store = fixture.store
    token = request.token
    handler = observe_cleanup(request)
    d = deadline(1_000)
    try do
      send(request.caller, {:run, d})
      assert_receive {^token, :reservation_called, caller, 1_048_576, context}, 1_000
      assert caller === request.caller
      assert context === {fixture.store, caller, fixture.gate, request.lease, :request, d, request.initial}
      assert_receive {^token, :outcome, {:returned, {:error, ^expected, original}}}, 1_000
      assert original === %{request.exchange | deadline: d}
      assert :erlang.external_size(expected) < 128
      assert Admission.status(fixture.gate).retained_bytes == request.initial
      assert Admission.status(fixture.gate).active == 1
      assert {:ok, _, _} = Generation.snapshot(fixture.store)
      for owner <- fixture.new_owners, do: assert(GenServer.call(owner, :count) == 1)
      assert GenServer.call(fixture.old_owner, :count) == 0
      lease = request.lease
      refute_receive {:contract_gate_update, ^caller, ^lease, _}, 0
      refute_receive {:contract_snapshot, ^caller, _, _, _}, 0
      refute_receive {:checked_provider_entered, _, ^caller, _}, 0
      refute_receive {:checked_provider_entered, _, ^store, _}, 0
      refute_receive {^token, :router_entered, _, _}, 0
      refute_receive {^token, :append_operands, _, _, _}, 0
      refute_receive {^token, :release_attempt, _, _, _}, 0
      refute_receive {^token, :cleanup_event, _, _, _}, 0
    after
      :telemetry.detach(handler)
      finish_request(request, fixture)
    end
  end

  defp assert_append_rejection(cleanup) do
    fixture = fixture()
    request = request(fixture, :valid, cleanup, 63)
    token = request.token
    handler = observe_cleanup(request)
    assert length(request.existing) == 63
    assert :erlang.external_size(request.existing) <= 65_536
    # Each preexisting receipt is from a separate real checked acquisition by
    # this actual holder. None is copied/forged to reach the count boundary.
    for pin <- request.existing do
      owner = fixture.old_owner
      caller = request.caller
      assert_receive {:checked_provider_entered, ^owner, ^caller, ^pin}, 1_000
    end
    assert GenServer.call(fixture.old_owner, :count) == 63
    d = deadline(1_000)
    try do
      send(request.caller, {:run, d})
      assert_receive {^token, :append_operands, caller, new, existing}, 1_000
      assert caller === request.caller
      assert existing === request.existing
      assert length(new) == 2 and length(existing) == 63
      assert length(new) + length(existing) == 65
      assert :erlang.external_size(new) <= 65_536
      assert Enum.all?(new, &(&1.holder === caller and &1.kind === :request))
      assert length(Enum.uniq_by(new, & &1.ref)) == 2
      for pin <- new do
        assert pin.owner in fixture.new_owners
        store = fixture.store
        owner = pin.owner
        assert_receive {:checked_provider_entered, ^owner, ^store, ^pin}, 1_000
      end
      assert_receive {^token, :outcome, {:returned, {:error, :generation_capture_capacity, charged}}}, 1_000
      assert charged.resource_pins === request.existing
      assert charged.route_bytes == @prior + @budget
      assert Admission.status(fixture.gate).retained_bytes == request.initial + @budget
      assert Admission.status(fixture.gate).active == 1
      assert_exact_releases(drain_releases(request.token, []), new, caller, d + 1_000)
      # Rejected NEW pins are the only cleanup operands. Preexisting custody is
      # preserved and still owned by the live requester through these checks.
      assert GenServer.call(fixture.old_owner, :count) == 63
      for owner <- fixture.new_owners,
        do: assert(GenServer.call(owner, :count) == if(cleanup == :ok, do: 1, else: 2))
      if cleanup == :ok do
        refute_receive {^token, :cleanup_event, _, _, _}, 0
      else
        assert_receive {^token, :cleanup_event, [:gaoxy, :generation_capture_cleanup], measures, metadata}, 0
        assert measures === %{count: 1}
        assert metadata === %{store: fixture.store, holder: caller, lease: request.lease,
          stage: :acquisition, cleanup: :cleanup_unconfirmed}
        assert :erlang.external_size({measures, metadata}) < 1_024
        refute_receive {^token, :cleanup_event, _, _, _}, 0
      end
      refute_receive {^token, :router_entered, _, _}, 0
      refute_receive {^token, :append_operands, _, _, _}, 0
    after
      :telemetry.detach(handler)
      finish_request(request, fixture)
    end
  end

  defp assert_exact_releases(attempts, pins, caller, dc) do
    assert length(attempts) == length(pins)
    assert MapSet.new(Enum.map(attempts, fn {who, pin, actual_dc} ->
      assert who === caller
      assert actual_dc === dc
      assert pin in pins
      pin.ref
    end)) == MapSet.new(Enum.map(pins, & &1.ref))
    assert length(Enum.uniq_by(attempts, fn {_, pin, _} -> pin.ref end)) == length(pins)
  end

  defp fixture do
    token = make_ref()
    new_owners = for i <- 1..2,
      do: start_supervised!({Provider, self()}, id: {:contract_new_owner, make_ref(), i})
    old_owner = start_supervised!({Provider, self()}, id: {:contract_old_owner, make_ref()})
    new_handles = Enum.map(new_owners, &handle/1)
    assert {:ok, router} = Router.compile([%{target: {Target, %{observer: self(), handles: new_handles}}}])
    store = start_supervised!({Generation, router: router}, id: {:contract_store, token})
    assert {:ok, spec} = Gaoxy.HTTP.service_spec(endpoint: {Target, %{observer: self(), handles: new_handles}})
    template = %Exchange{request: %Request{method: "GET", path: "/", host: "localhost",
      version: :"HTTP/1.1", head_bytes: 0, keep_alive: true}, buffer: "", route_bytes: @prior,
      body: Gaoxy.HTTP.HTTP1.Body.new(:none), limits: spec.handler_options.http_limits}
    gate = start_supervised!({Admission, {%{spec.limits | max_bytes: @prior + @budget},
      %{scope_marker: :must_not_leak}}}, id: {:contract_gate, token})
    observer = self()
    store_debug = make_ref()
    :ok = :sys.install(store, {store_debug, fn state, event, _ ->
      case event do
        {:in, {:"$gen_call", {caller, _}, {:snapshot_for_request, holder, d, accounting}}} ->
          send(observer, {:contract_snapshot, caller, holder, d, accounting})
        _ -> :ok
      end
      state
    end, nil})
    gate_debug = make_ref()
    :ok = :sys.install(gate, {gate_debug, fn state, event, _ ->
      case event do
        {:in, {:"$gen_call", {caller, _}, {:update, lease, bytes}}} ->
          send(observer, {:contract_gate_update, caller, lease, bytes})
        _ -> :ok
      end
      state
    end, nil})
    on_exit(fn ->
      if Process.alive?(store), do: :sys.remove(store, store_debug)
      if Process.alive?(gate), do: :sys.remove(gate, gate_debug)
    end)
    %{store: store, gate: gate, template: template, old_owner: old_owner,
      old_handle: handle(old_owner), new_owners: new_owners}
  end

  defp request(fixture, reservation, cleanup, existing_count) do
    observer = self()
    token = make_ref()
    {caller, monitor} = spawn_monitor(fn ->
      Process.put(ContractAccounting, %{observer: observer, token: token,
        reservation: reservation, cleanup: cleanup})
      initial = Exchange.retained_bytes(fixture.template)
      {:ok, lease} = Admission.acquire(fixture.gate, initial)
      existing = if existing_count == 0 do
        []
      else
        d = deadline(5_000)
        Enum.reduce(1..existing_count, [], fn _, accepted ->
          {:ok, [pin]} = apply(Resources, :pin_many_checked,
            [[fixture.old_handle], self(), d, ContractAccounting])
          {:ok, _} = Accounting.preflight_cons(pin, accepted)
          [pin | accepted]
        end)
      end
      exchange = %{fixture.template | gate: fixture.gate, lease: lease, resource_pins: existing}
      {:ok, config} = Generation.init({fixture.store, accounting: ContractAccounting})
      send(observer, {token, :ready, self(), lease, exchange, existing})
      receive do
        {:run, d} ->
          result = try do
            {:returned, Generation.call(%{exchange | deadline: d}, config)}
          catch
            class, value -> {:caught, class, value, __STACKTRACE__}
          end
          send(observer, {token, :outcome, result})
          receive do :finish -> :ok after 4_000 -> exit(:contract_requester_not_finished) end
        :finish -> :ok
      after
        4_000 -> exit(:contract_requester_not_started)
      end
    end)
    on_exit(fn -> join_or_finish(caller) end)
    assert_receive {^token, :ready, ^caller, lease, exchange, existing}, 6_000
    %{caller: caller, monitor: monitor, token: token, lease: lease, exchange: exchange,
      initial: Exchange.retained_bytes(exchange), existing: existing}
  end

  defp observe_cleanup(request) do
    id = make_ref()
    :ok = :telemetry.attach(id, [:gaoxy, :generation_capture_cleanup], &__MODULE__.cleanup_witness/4,
      %{observer: self(), token: request.token, holder: request.caller, lease: request.lease})
    id
  end

  def cleanup_witness(event, measurements, metadata, config) do
    if metadata[:holder] === config.holder and metadata[:lease] === config.lease,
      do: send(config.observer, {config.token, :cleanup_event, event, measurements, metadata})
  end

  defp drain_releases(token, acc) do
    receive do
      {^token, :release_attempt, caller, pin, dc} -> drain_releases(token, [{caller, pin, dc} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp finish_request(request, fixture) do
    send(request.caller, :finish)
    monitor = request.monitor
    caller = request.caller
    assert_receive {:DOWN, ^monitor, :process, ^caller, :normal}, 4_000
    eventually(fn -> Admission.status(fixture.gate).active == 0 and
      Admission.status(fixture.gate).retained_bytes == 0 and
      GenServer.call(fixture.old_owner, :count) == 0 and
      Enum.all?(fixture.new_owners, &(GenServer.call(&1, :count) == 1)) end, deadline(1_000))
  end

  defp join_or_finish(caller) do
    monitor = Process.monitor(caller)
    send(caller, :finish)
    receive do
      {:DOWN, ^monitor, :process, ^caller, _} -> :ok
    after
      4_000 -> flunk("contract test-owned caller did not join")
    end
  end

  defp eventually(fun, d) do
    unless fun.() do
      assert System.monotonic_time(:millisecond) < d
      receive do after 2 -> :ok end
      eventually(fun, d)
    end
  end

  defp handle(owner), do: %{provider: Provider, owner: owner, owner_epoch: make_ref(), resource: make_ref()}
  defp deadline(ms), do: System.monotonic_time(:millisecond) + ms
end
