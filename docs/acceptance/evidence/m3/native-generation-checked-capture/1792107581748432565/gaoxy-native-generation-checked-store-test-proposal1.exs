# SOURCE-ONLY PROPOSAL. Split the two top-level test modules into their owning
# applications before adoption. No Generation.call/2 or Admission lease is used.
defmodule Gaoxy.HTTP.GenerationCheckedCaptureTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Generation, Resources, Router}

  defmodule Provider do
    use GenServer
    @behaviour Gaoxy.HTTP.Resources

    def start_link(observer), do: GenServer.start_link(__MODULE__, observer)
    def init(observer), do: {:ok, %{observer: observer, mode: :normal, pins: %{}}}

    def pin_many([handle | _] = handles, holder, kind, operation, deadline) do
      {:ok, pin, mode, observer} =
        GenServer.call(handle.owner, {:acquire, handles, holder, kind, operation, deadline})

      if kind == :request and mode == :pause do
        send(observer, {:checked_provider_paused, self(), pin})

        receive do
          {:continue_checked_pin, ^operation, :normal} -> {:ok, pin}
          {:continue_checked_pin, ^operation, {:mutate, field, value}} ->
            {:ok, Map.put(pin, field, value)}
          {:continue_checked_pin, ^operation, {:return, value}} -> value
          {:continue_checked_pin, ^operation, :raise} -> raise "checked fixture failure"
          {:continue_checked_pin, ^operation, {:throw, value}} -> throw(value)
          {:continue_checked_pin, ^operation, {:exit, value}} -> exit(value)
        after
          2_000 -> raise "checked provider barrier was not released"
        end
      else
        {:ok, pin}
      end
    end

    def release(pin), do: GenServer.call(pin.owner, {:release, pin})
    def release(pin, deadline), do: Gaoxy.Lifecycle.call(pin.owner, {:release, pin}, deadline)
    def cancel(owner, operation) do
      send(owner, {:cancel, self(), operation})
      :ok
    end

    def handle_call({:acquire, handles, holder, kind, operation, _deadline}, {caller, _}, state) do
      pin = %{
        provider: __MODULE__, owner: self(), owner_epoch: hd(handles).owner_epoch,
        operation: operation, ref: make_ref(), handles: handles, kind: kind, holder: holder
      }

      record = %{pin: pin, acquirer: caller, monitor: Process.monitor(holder)}
      if kind == :request,
        do: send(state.observer, {:checked_provider_entered, self(), caller, pin})
      {:reply, {:ok, pin, state.mode, state.observer},
       %{state | pins: Map.put(state.pins, pin.ref, record)}}
    end

    def handle_call({:mode, mode}, _, state), do: {:reply, :ok, %{state | mode: mode}}
    def handle_call(:count, _, state), do: {:reply, map_size(state.pins), state}

    def handle_call({:release, pin}, {caller, _}, state) do
      case state.pins[pin.ref] do
        nil -> {:reply, :ok, state}
        %{pin: %{holder: ^caller}} -> {:reply, :ok, remove(state, pin.ref)}
        _ -> {:reply, {:error, :unauthorized}, state}
      end
    end

    def handle_info({:cancel, caller, operation}, state) do
      refs = for {ref, r} <- state.pins,
        r.acquirer === caller and r.pin.operation === operation, do: ref
      next = Enum.reduce(refs, state, &remove(&2, &1))
      send(state.observer, {:checked_cancelled, self(), caller, operation})
      {:noreply, next}
    end

    def handle_info({:DOWN, monitor, :process, _, _}, state) do
      refs = for {ref, r} <- state.pins, r.monitor === monitor, do: ref
      {:noreply, Enum.reduce(refs, state, &remove(&2, &1))}
    end

    defp remove(state, ref) do
      Process.demonitor(state.pins[ref].monitor, [:flush])
      %{state | pins: Map.delete(state.pins, ref)}
    end
  end

  # HTTP-only test authority for the instrumented provider. The production
  # managed schema is tested in gaoxy_proxy; this fixture adds no proxy import.
  defmodule Accounting do
    @finite ~w(invalid_generation_capture generation_capture_capacity generation_unavailable
      generation_pin_release_failed cleanup_unconfirmed invalid_resource_holder byte_limit
      stale_generation deadline_exceeded cleanup_pending)a

    def reservation(_, _), do: raise("Task 3 must not call reservation/2")

    def validate_manifest(handles) do
      valid = Enum.all?(handles, fn
        %{provider: Provider, owner: owner, owner_epoch: epoch} ->
          is_pid(owner) and is_reference(epoch)
        _ -> false
      end)

      epochs = Enum.group_by(handles, &{&1.provider, &1.owner}, & &1.owner_epoch)

      if valid and Enum.all?(epochs, fn {_, es} -> length(Enum.uniq(es)) == 1 end),
        do: :ok, else: {:error, :invalid_generation_capture}
    end

    def correlate(pin, {provider, owner, operation, handles}, holder) do
      keys = [:provider, :owner, :owner_epoch, :operation, :ref, :handles, :kind, :holder]

      if is_map(pin) and Enum.sort(Map.keys(pin)) == Enum.sort(keys) and
           pin.provider === provider and pin.owner === owner and
           pin.operation === operation and pin.handles === handles and
           pin.owner_epoch === hd(handles).owner_epoch and pin.kind === :request and
           pin.holder === holder and is_reference(pin.ref),
        do: :ok, else: {:error, :invalid_generation_capture}
    end

    def preflight_cons(pin, pins) do
      # This fixture measures the ACTUAL two operands, before capture-list cons.
      bytes = if pins == [], do: 7 + :erlang.external_size(pin) - 1,
        else: :erlang.external_size(pins) + :erlang.external_size(pin) - 1
      count = length(pins) + 1
      if count <= 64 and bytes <= 65_536,
        do: {:ok, %{count: count, bytes: bytes}},
        else: {:error, :generation_capture_capacity}
    end

    def preflight_append(new, old) do
      count = length(new) + length(old)
      body = fn pins -> if pins == [], do: 0, else: :erlang.external_size(pins) - 7 end
      bytes = if count == 0, do: 2, else: 7 + body.(new) + body.(old)
      if count <= 64 and bytes <= 65_536,
        do: {:ok, %{count: count, bytes: bytes}},
        else: {:error, :generation_capture_capacity}
    end

    def finite_checked_reason(reason) when reason in @finite, do: reason
    def finite_checked_reason({:deadline_exceeded, :cleanup_pending}), do: :deadline_exceeded
    def finite_checked_reason(:timeout), do: :deadline_exceeded
    def finite_checked_reason({:timeout, _}), do: :deadline_exceeded
    def finite_checked_reason({:operation_exit, :timeout}), do: :deadline_exceeded
    def finite_checked_reason({:operation_exit, {:timeout, _}}), do: :deadline_exceeded
    def finite_checked_reason(_), do: :generation_unavailable
    def release(pin, deadline), do: Provider.release(pin, deadline)
  end

  defmodule AccountingDelegates do
    defmacro __using__(_) do
      quote do
        defdelegate reservation(m, context), to: Accounting
        defdelegate validate_manifest(handles), to: Accounting
        defdelegate correlate(pin, entry, holder), to: Accounting
        defdelegate preflight_cons(pin, pins), to: Accounting
        defdelegate preflight_append(new, old), to: Accounting
        defdelegate finite_checked_reason(reason), to: Accounting
        defdelegate release(pin, deadline), to: Accounting
        defoverridable validate_manifest: 1, correlate: 3, preflight_cons: 2,
          finite_checked_reason: 1, release: 2
      end
    end
  end

  defmodule BadValidation do
    use AccountingDelegates
    def validate_manifest(_), do: {:unexpected, :validation}
  end

  defmodule BadCorrelation do
    use AccountingDelegates
    def correlate(_, _, _), do: {:unexpected, :correlation}
  end

  defmodule BadPreflight do
    use AccountingDelegates
    def preflight_cons(_, _), do: {:unexpected, :preflight}
  end

  defmodule BadNormalizer do
    use AccountingDelegates
    def finite_checked_reason(_), do: %{not: :finite}
  end

  defmodule ReleaseProbe do
    use AccountingDelegates
    def release(%{observer: observer, ref: ref, action: action}, deadline) do
      send(observer, {:checked_release_dispatched, ref, deadline})
      case action do
        :ok -> :ok
        :wait -> receive do after max(deadline - System.monotonic_time(:millisecond), 0) -> :ok end
        :raise -> raise "release fixture failure"
        :throw -> throw({:raw, String.duplicate("r", 70_000)})
        :exit -> exit(:release_fixture_exit)
        :garbage -> {:unexpected, :release}
        :error -> {:error, {:raw, String.duplicate("r", 70_000)}}
      end
    end
  end

  defmodule Endpoint do
    def init(handles), do: {:ok, handles}
    def resources(handles), do: handles
    def call(exchange, _), do: {:ok, exchange}
  end

  setup do
    assert_checked_apis()
    :ok
  end

  @tag :checked_capture_constructor
  test "checked Store success preserves complete router and authentic receipts; legacy remains usable" do
    {store, router, [owner], _handles} = store(1)
    assert {:ok, generation, ^router} = Generation.snapshot(store)
    assert {:ok, ^generation, ^router, [pin]} =
      checked_snapshot(store, self(), deadline(), Accounting)
    assert pin.holder === self()
    assert pin.kind === :request
    assert GenServer.call(owner, :count) == 2
    assert :ok = checked_release([pin], deadline(), Accounting)
    assert GenServer.call(owner, :count) == 1
    assert {:ok, ^generation, ^router, legacy} =
      Generation.snapshot_for_request(store, self(), deadline())
    assert :ok = Resources.release(legacy)
    assert {:ok, %{store: ^store, max_config_bytes: 1_048_576, accounting: Accounting}} =
      Generation.init({store, accounting: Accounting})
    assert {:ok, %{store: ^store, snapshot_bytes: 2_097_152}} = Generation.init(store)
  end

  @tag :checked_capture_constructor
  test "wrong Store holder refuses before provider effects" do
    {store, _router, [owner], _} = store(1)
    :ok = GenServer.call(owner, {:mode, :pause})
    {other, monitor} = idle()
    try do
      assert {:error, :invalid_resource_holder, :clean} =
        checked_store(store, other, deadline(), Accounting)
      assert GenServer.call(owner, :count) == 1
      refute_receive {:checked_provider_paused, _, _}, 0
      refute_receive {:checked_provider_entered, _, _, _}, 0
    after
      finish(other, monitor)
    end
  end

  @tag :checked_capture_constructor
  test "public checked snapshot timeout is finite and its queued expired request has no provider effect" do
    {store, router, [owner], _} = store(1)
    assert :ok = :sys.suspend(store)
    try do
      assert {:error, :deadline_exceeded, :cleanup_unconfirmed} =
        checked_snapshot(store, self(), deadline(30), Accounting)
      refute_receive {:checked_provider_entered, _, _, _}, 0
    after
      if Process.alive?(store), do: :sys.resume(store)
    end
    # Same-sender snapshot follows the earlier checked request in Store's queue.
    assert {:ok, _, ^router} = Generation.snapshot(store)
    assert GenServer.call(owner, :count) == 1
    refute_receive {:checked_provider_entered, _, _, _}, 0
  end

  @tag :checked_capture_constructor
  test "raw manifest grammar count size and unknown-provider refusals are clean before dispatch" do
    owner = start_supervised!({Provider, self()})
    handle = handle(owner)
    invalid = [
      [handle | :improper], List.duplicate(handle, 65),
      [Map.put(handle, :payload, String.duplicate("x", 65_536))],
      [%{handle | provider: __MODULE__}], [%{handle | owner_epoch: :not_a_reference}]
    ]
    for handles <- invalid do
      assert {:error, :invalid_generation_capture, :clean} =
        checked_acquire(handles, self(), deadline(), Accounting)
    end
    assert GenServer.call(owner, :count) == 0
    refute_receive {:checked_provider_paused, _, _}, 0
    refute_receive {:checked_provider_entered, _, _, _}, 0
  end

  @tag :checked_capture_constructor
  test "inconsistent original epochs refuse before provider entry" do
    owner = start_supervised!({Provider, self()})
    first = handle(owner)
    second = %{first | owner_epoch: make_ref(), resource: make_ref()}
    assert {:error, :invalid_generation_capture, :clean} =
      checked_acquire([first, second], self(), deadline(), Accounting)
    assert GenServer.call(owner, :count) == 0
    refute_receive {:checked_provider_entered, _, _, _}, 0
  end

  @tag :checked_capture_constructor
  test "deadline grammar and exhausted deadline refuse without a started ledger" do
    owner = start_supervised!({Provider, self()})
    for d <- [:infinity, nil, 1.5, -9_223_372_036_854_775_809, 9_223_372_036_854_775_808] do
      assert {:error, :invalid_generation_capture, :clean} =
        checked_acquire([handle(owner)], self(), d, Accounting)
    end
    assert {:error, :deadline_exceeded, :clean} =
      checked_acquire([handle(owner)], self(), System.monotonic_time(:millisecond), Accounting)
    assert GenServer.call(owner, :count) == 0
    refute_receive {:checked_provider_entered, _, _, _}, 0
  end

  @tag :checked_capture_constructor
  test "invalid and already dead resource holders refuse before dispatch" do
    owner = start_supervised!({Provider, self()})
    {dead, monitor} = spawn_monitor(fn -> :ok end)
    assert_receive {:DOWN, ^monitor, :process, ^dead, :normal}, 1_000
    for holder <- [nil, :not_a_pid, dead] do
      assert {:error, :invalid_resource_holder, :clean} =
        checked_acquire([handle(owner)], holder, deadline(), Accounting)
    end
    assert GenServer.call(owner, :count) == 0
    refute_receive {:checked_provider_entered, _, _, _}, 0
  end

  @tag :checked_capture_constructor
  test "missing or malformed validation callback cannot fall back to legacy acquisition" do
    owner = start_supervised!({Provider, self()})
    for accounting <- [:erlang, BadValidation] do
      assert {:error, :generation_unavailable, :clean} =
        checked_acquire([handle(owner)], self(), deadline(), accounting)
    end
    assert GenServer.call(owner, :count) == 0
    refute_receive {:checked_provider_entered, _, _, _}, 0
  end

  @tag :checked_capture_constructor
  test "raw deduplication preserves the complete original batch and order" do
    owner = start_supervised!({Provider, self()})
    first = handle(owner)
    second = %{first | resource: make_ref()}
    assert {:ok, [pin]} = checked_acquire(
      [first, second, first], self(), deadline(), Accounting)
    assert pin.handles === [first, second]
    assert_receive {:checked_provider_entered, ^owner, caller, ^pin}, 1_000
    assert caller === self()
    assert :ok = checked_release([pin], deadline(), Accounting)
    assert GenServer.call(owner, :count) == 0
  end

  @tag :checked_capture_constructor
  test "current malformed success cancels both exact original operations after a prior success" do
    {store, router, owners, _} = store(2)
    before = :sys.get_state(store)
    Enum.each(owners, &GenServer.call(&1, {:mode, :pause}))
    {caller, monitor, token} = request(store, deadline(), Accounting)
    try do
      assert_receive {:checked_provider_paused, ^store, first}, 1_000
      send(store, {:continue_checked_pin, first.operation, :normal})
      assert_receive {:checked_provider_paused, ^store, second}, 1_000
      refute first.owner === second.owner
      # Simultaneously corrupt every routing identity. Rollback must use neither.
      corrupt = %{second | provider: __MODULE__, owner: self(), operation: make_ref()}
      send(store, {:continue_checked_pin, second.operation, {:return, {:ok, corrupt}}})
      assert_receive {^token, {:error, :invalid_generation_capture, :cleanup_unconfirmed}}, 1_000
      assert_cancel(first, store)
      assert_cancel(second, store)
      refute_receive {:checked_cancelled, _, _, _}, 0
      for owner <- owners, do: assert(GenServer.call(owner, :count) == 1)
      assert :sys.get_state(store) === before
      assert {:ok, _, ^router} = Generation.snapshot(store)
    after
      finish(caller, monitor)
    end
  end

  @tag :checked_capture_constructor
  test "each substituted complete receipt field is rejected with original-current rollback" do
    {store, _router, [owner], _} = store(1)
    :ok = GenServer.call(owner, {:mode, :pause})
    for field <- [:provider, :owner, :owner_epoch, :operation, :handles, :kind, :holder, :ref] do
      {caller, monitor, token} = request(store, deadline(), Accounting)
      try do
        assert_receive {:checked_provider_paused, ^store, pin}, 1_000
        value = case field do
          :provider -> __MODULE__
          :owner -> self()
          :owner_epoch -> make_ref()
          :operation -> make_ref()
          :handles -> Enum.map(pin.handles, &Map.put(&1, :resource, make_ref()))
          :kind -> :baseline
          :holder -> self()
          :ref -> :not_a_reference
        end
        send(store, {:continue_checked_pin, pin.operation, {:mutate, field, value}})
        assert_receive {^token, {:error, :invalid_generation_capture, :cleanup_unconfirmed}}, 1_000
        assert_cancel(pin, store)
        assert GenServer.call(owner, :count) == 1
      after
        finish(caller, monitor)
      end
    end
  end

  @tag :checked_capture_constructor
  test "arbitrary provider diagnostics and bad callback results return only finite failures" do
    {store, _router, [owner], _} = store(1)
    :ok = GenServer.call(owner, {:mode, :pause})
    huge = {:unknown, String.duplicate("d", 70_000)}
    deep = Enum.reduce(1..256, :leaf, fn _, acc -> {:nested, acc} end)
    cases = [
      {Accounting, {:return, {:error, huge}}},
      {Accounting, {:return, {:error, deep}}},
      {Accounting, {:return, huge}}, {Accounting, :raise},
      {Accounting, {:throw, deep}}, {Accounting, {:exit, huge}},
      {BadCorrelation, :normal}, {BadPreflight, :normal},
      {BadNormalizer, {:return, {:error, huge}}}
    ]
    for {accounting, action} <- cases do
      before = :sys.get_state(store)
      {caller, monitor, token} = request(store, deadline(), accounting)
      try do
        assert_receive {:checked_provider_paused, ^store, pin}, 1_000
        send(store, {:continue_checked_pin, pin.operation, action})
        assert_receive {^token, {:error, :generation_unavailable, :cleanup_unconfirmed} = result}, 1_000
        assert :erlang.external_size(result) < 128
        assert_cancel(pin, store)
        assert :sys.get_state(store) === before
        assert GenServer.call(owner, :count) == 1
      after
        finish(caller, monitor)
      end
    end
  end

  @tag :checked_capture_constructor
  test "actual oversized receipt fails preflight before capture publication and rolls back" do
    owner = start_supervised!({Provider, self()})
    base = Map.put(handle(owner), :payload, "")
    full = %{base | payload: String.duplicate("p", 65_536 - :erlang.external_size([base]))}
    assert :erlang.external_size([full]) == 65_536
    {store, _router} = store_with([full])
    :ok = GenServer.call(owner, {:mode, :pause})
    {caller, monitor, token} = request(store, deadline(), Accounting)
    try do
      assert_receive {:checked_provider_paused, ^store, pin}, 1_000
      assert :erlang.external_size([pin]) > 65_536
      send(store, {:continue_checked_pin, pin.operation, :normal})
      assert_receive {^token, {:error, :generation_capture_capacity, :cleanup_unconfirmed}}, 1_000
      assert_cancel(pin, store)
      assert GenServer.call(owner, :count) == 1
    after
      finish(caller, monitor)
    end
  end

  @tag :checked_capture_constructor
  test "expired acquisition cannot publish a usable Store snapshot after genuine provider success" do
    {store, router, [owner], _} = store(1)
    before = :sys.get_state(store)
    :ok = GenServer.call(owner, {:mode, :pause})
    d = deadline(300)
    {caller, monitor, token} = request(store, d, Accounting)
    try do
      assert_receive {:checked_provider_paused, ^store, pin}, 1_000
      assert GenServer.call(owner, :count) == 2
      wait_until(d)
      send(store, {:continue_checked_pin, pin.operation, :normal})
      assert_receive {^token, {:error, :deadline_exceeded, :cleanup_unconfirmed}}, 1_000
      assert_cancel(pin, store)
      assert GenServer.call(owner, :count) == 1
      assert :sys.get_state(store) === before
      assert {:ok, _, ^router} = Generation.snapshot(store)
      refute_receive {^token, {:ok, _, _, _}}, 0
    after
      finish(caller, monitor)
    end
  end

  @tag :checked_capture_constructor
  test "holder dying behind provider barrier cannot escape final checked readiness" do
    owner = start_supervised!({Provider, self()})
    :ok = GenServer.call(owner, {:mode, :pause})
    {holder, holder_monitor} = idle()
    observer = self()
    token = make_ref()
    {worker, monitor} = spawn_monitor(fn ->
      result = checked_acquire([handle(owner)], holder, deadline(), Accounting)
      send(observer, {token, result})
    end)
    on_exit(fn -> join_or_finish(worker) end)
    try do
      assert_receive {:checked_provider_paused, ^worker, pin}, 1_000
      finish(holder, holder_monitor)
      send(worker, {:continue_checked_pin, pin.operation, :normal})
      assert_receive {^token, {:error, :invalid_resource_holder, :cleanup_unconfirmed}}, 1_000
      assert_cancel(pin, worker)
      assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, 1_000
      assert GenServer.call(owner, :count) == 0
    after
      join_or_finish(holder)
      join_or_finish(worker)
    end
  end

  @tag :checked_capture_constructor
  test "checked release dispatches every success with the same original absolute deadline" do
    dc = deadline()
    pins = for _ <- 1..2, do: %{observer: self(), ref: make_ref(), action: :ok}
    assert :ok = checked_release(pins, dc, ReleaseProbe)
    for pin <- pins do
      ref = pin.ref
      assert_receive {:checked_release_dispatched, ^ref, ^dc}, 0
    end
    refute_receive {:checked_release_dispatched, _, _}, 0
  end

  @tag :checked_capture_constructor
  test "first release consumes shared deadline and no second synchronous release starts" do
    first = %{observer: self(), ref: make_ref(), action: :wait}
    second = %{observer: self(), ref: make_ref(), action: :ok}
    dc = deadline(30)
    assert {:error, :generation_pin_release_failed} =
      checked_release([first, second], dc, ReleaseProbe)
    first_ref = first.ref
    assert_receive {:checked_release_dispatched, ^first_ref, ^dc}, 0
    refute_receive {:checked_release_dispatched, _, _}, 0
  end

  @tag :checked_capture_constructor
  test "checked release failures remain finite and expired or malformed Dc never dispatches" do
    for action <- [:error, :raise, :throw, :exit, :garbage] do
      pin = %{observer: self(), ref: make_ref(), action: action}
      assert {:error, :generation_pin_release_failed} =
        checked_release([pin], deadline(), ReleaseProbe)
      ref = pin.ref
      assert_receive {:checked_release_dispatched, ^ref, _}, 0
    end
    for dc <- [:infinity, nil, 1.5, System.monotonic_time(:millisecond)] do
      pin = %{observer: self(), ref: make_ref(), action: :ok}
      assert {:error, :generation_pin_release_failed} =
        checked_release([pin], dc, ReleaseProbe)
      refute_receive {:checked_release_dispatched, _, _}, 0
    end
  end

  defp assert_checked_apis do
    assert Code.ensure_loaded?(Resources)
    assert function_exported?(Resources, :pin_many_checked, 4), "missing checked acquisition API"
    assert function_exported?(Resources, :release_checked, 3), "missing checked release API"
    assert function_exported?(Generation, :snapshot_for_request, 4), "missing checked snapshot API"
  end

  defp checked_acquire(handles, holder, d, accounting) do
    assert_checked_apis()
    apply(Resources, :pin_many_checked, [handles, holder, d, accounting])
  end

  defp checked_release(pins, dc, accounting) do
    assert_checked_apis()
    apply(Resources, :release_checked, [pins, dc, accounting])
  end

  defp checked_snapshot(store, holder, d, accounting) do
    assert_checked_apis()
    apply(Generation, :snapshot_for_request, [store, holder, d, accounting])
  end

  defp checked_store(store, holder, d, accounting) do
    assert_checked_apis()
    GenServer.call(store, {:snapshot_for_request, holder, d, accounting})
  end

  defp store(count) do
    owners = for i <- 1..count, do: start_supervised!({Provider, self()}, id: {:provider, i})
    handles = Enum.map(owners, &handle/1)
    {store, router} = store_with(handles)
    {store, router, owners, handles}
  end

  defp store_with(handles) do
    assert {:ok, router} = Router.compile([%{target: {Endpoint, handles}}])
    {start_supervised!({Generation, router: router}), router}
  end

  defp handle(owner), do: %{provider: Provider, owner: owner, owner_epoch: make_ref(), resource: make_ref()}
  defp deadline(ms \\ 1_000), do: System.monotonic_time(:millisecond) + ms
  defp wait_until(d) do
    receive do
    after
      max(d - System.monotonic_time(:millisecond), 0) -> :ok
    end
  end

  defp request(store, d, accounting) do
    assert_checked_apis()
    observer = self()
    token = make_ref()
    {caller, monitor} = spawn_monitor(fn ->
      result = GenServer.call(store, {:snapshot_for_request, self(), d, accounting}, 3_000)
      send(observer, {token, result})
      receive do :finish -> :ok after 3_000 -> exit(:checked_requester_not_finished) end
    end)
    on_exit(fn -> join_or_finish(caller) end)
    {caller, monitor, token}
  end

  defp idle do
    {pid, monitor} = spawn_monitor(fn -> receive do :finish -> :ok after 4_000 -> :ok end end)
    on_exit(fn -> join_or_finish(pid) end)
    {pid, monitor}
  end

  defp assert_cancel(pin, acquirer) do
    owner = pin.owner
    operation = pin.operation
    assert_receive {:checked_cancelled, ^owner, ^acquirer, ^operation}, 1_000
  end

  defp finish(pid, monitor) do
    send(pid, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, 3_000
  end

  defp join_or_finish(pid) do
    monitor = Process.monitor(pid)
    send(pid, :finish)
    receive do
      {:DOWN, ^monitor, :process, ^pid, _} -> :ok
    after
      3_000 -> flunk("test-owned checked requester did not join")
    end
  end
end

# SPLIT HERE: this module belongs in gaoxy_proxy, which already depends on HTTP.
defmodule Gaoxy.Proxy.ManagedGenerationCheckedOwnerTest do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.{Generation, Router}
  alias Gaoxy.Proxy.ManagedGenerationAccounting
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports

  defmodule Endpoint do
    def init(handles), do: {:ok, handles}
    def resources(handles), do: handles
    def call(exchange, _), do: {:ok, exchange}
  end

  setup do
    assert Code.ensure_loaded?(Gaoxy.HTTP.Resources)
    assert function_exported?(Gaoxy.HTTP.Resources, :pin_many_checked, 4), "missing checked acquisition API"
    assert function_exported?(Gaoxy.HTTP.Resources, :release_checked, 3), "missing checked release API"
    assert function_exported?(Generation, :snapshot_for_request, 4), "missing checked snapshot API"
    :ok
  end

  @tag :checked_capture_constructor
  test "real T success then failed postcheck sends its own cancel plus exact Store-ledger cancel" do
    {instance, owner} = owner()
    assert is_pid(instance)
    assert {:ok, handle, preparation} = Transports.prepare(owner, policy_source(), self(), deadline())
    assert {:ok, router} = Router.compile([%{target: {Endpoint, [handle]}}])
    store = start_supervised!({Generation, router: router})
    assert :ok = Gaoxy.HTTP.Resources.release(preparation)
    assert {:ok, %{pins: 1}} = Transports.status(owner)
    assert {:ok, generation, ^router} = Generation.snapshot(store)
    before = :sys.get_state(store)
    observer = self()
    debug_id = make_ref()

    :ok = :sys.install(owner, {debug_id, fn state, event, _ ->
      case event do
        {:in, {:"$gen_call", {^store, _}, {:pin_many, batch, holder, :request, operation, d}}} ->
          :erlang.suspend_process(store)
          send(observer, {:real_t_suspended, store, batch, holder, operation, d})
        {:in, {:cancel_pins, ^store, operation}} ->
          send(observer, {:real_t_cancel_received, store, operation})
        _ -> :ok
      end
      state
    end, debug_id})

    assert :erlang.trace(owner, true, [:send, {:tracer, observer}]) == 1
    assert :erlang.trace(store, true, [:send, {:tracer, observer}]) == 1
    d = deadline(300)
    token = make_ref()
    {caller, monitor} = spawn_monitor(fn ->
      result = GenServer.call(store, {:snapshot_for_request, self(), d, ManagedGenerationAccounting}, 3_000)
      send(observer, {token, result})
      receive do :finish -> :ok after 3_000 -> exit(:real_t_requester_not_finished) end
    end)

    try do
      assert_receive {:real_t_suspended, ^store, [^handle], ^caller, operation, ^d}, 1_000
      # A real owner-generated public reply must exist BEFORE D/resume. No fake
      # provider, manufactured receipt, or production test hook can satisfy this.
      assert_receive {:trace, ^owner, :send, {_alias_tag, {:ok, %{
        provider: Transports, owner: ^owner, operation: ^operation,
        handles: [^handle], holder: ^caller, kind: :request
      } = real_pin}}, _destination}, 1_000
      assert is_reference(real_pin.ref)
      assert map_size(real_pin) == 8
      assert {:ok, %{pins: 2}} = Transports.status(owner)
      receive do after max(d - System.monotonic_time(:millisecond), 0) -> :ok end
      resume_from_owner(owner, store)
      assert_receive {^token, {:error, :deadline_exceeded, :cleanup_unconfirmed}}, 1_000

      # Both genuine controls have the SAME original Store acquirer/operation.
      for _ <- 1..2 do
        assert_receive {:trace, ^store, :send, {:cancel_pins, ^store, ^operation}, ^owner}, 1_000
        assert_receive {:real_t_cancel_received, ^store, ^operation}, 1_000
      end
      assert {:ok, %{pins: 1}} = Transports.status(owner)
      # Synchronize trace delivery; a zero-time mailbox check alone is too weak.
      trace_barrier = :erlang.trace_delivered(store)
      assert_receive {:trace_delivered, ^store, ^trace_barrier}, 1_000
      refute_receive {:trace, ^store, :send, {:cancel_pins, ^store, ^operation}, ^owner}, 0
      refute_receive {:real_t_cancel_received, ^store, ^operation}, 0
      assert Process.alive?(caller)
      assert :sys.get_state(store) === before
      assert {:ok, ^generation, ^router} = Generation.snapshot(store)
      refute_receive {^token, {:ok, _, _, _}}, 0
    after
      resume_from_owner(owner, store)
      if Process.alive?(owner) do
        :erlang.trace(owner, false, [:send])
        :sys.remove(owner, debug_id)
      end
      if Process.alive?(store), do: :erlang.trace(store, false, [:send])
      send(caller, :finish)
      receive do
        {:DOWN, ^monitor, :process, ^caller, _} -> :ok
      after
        4_000 -> flunk("real T checked requester did not join")
      end
    end
  end

  defp resume_from_owner(owner, store) do
    if Process.alive?(owner) do
      :sys.replace_state(owner, fn state ->
        if Process.info(store, :status) == {:status, :suspended},
          do: :erlang.resume_process(store)
        state
      end)
    end
  end

  defp owner do
    {:ok, instance} = Gaoxy.start_link()
    Process.unlink(instance)
    {:ok, owner} = Transports.start_link(instance: instance, limits: %{
      max_resources: 2, max_pins: 8, max_request_tokens: 64, max_owned_payload_bytes: 131_072
    })
    Process.unlink(owner)
    on_exit(fn ->
      actors = if Process.alive?(owner) do
        state = :sys.get_state(owner)
        creators = Enum.map(state.records, fn {_, record} -> record.custodian end)
        helpers = for {_, hold} <- state.tokens, {pid, _} <- [hold.abort_helper], do: pid
        Enum.uniq(creators ++ helpers)
      else
        []
      end
      monitors = Enum.map(actors, &{&1, Process.monitor(&1)})
      if Process.alive?(owner), do: GenServer.stop(owner, :normal, 1_000)
      for {pid, monitor} <- monitors do
        receive do
          {:DOWN, ^monitor, :process, ^pid, _} -> :ok
        after
          6_000 -> flunk("real T owned actor did not join")
        end
      end
      Gaoxy.stop(instance, 100)
    end)
    {instance, owner}
  end

  defp policy_source, do: %{origin: "http://example.test", connect_address: {127, 0, 0, 1}, trust: nil}
  defp deadline(ms \\ 1_000), do: System.monotonic_time(:millisecond) + ms
end
