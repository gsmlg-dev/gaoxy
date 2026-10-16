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
          {:continue_checked_pin, ^operation, :normal} ->
            {:ok, pin}

          {:continue_checked_pin, ^operation, {:mutate, field, value}} ->
            {:ok, Map.put(pin, field, value)}

          {:continue_checked_pin, ^operation, {:return, value}} ->
            value

          {:continue_checked_pin, ^operation, :raise} ->
            raise "checked fixture failure"

          {:continue_checked_pin, ^operation, {:throw, value}} ->
            throw(value)

          {:continue_checked_pin, ^operation, {:exit, value}} ->
            exit(value)
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
        provider: __MODULE__,
        owner: self(),
        owner_epoch: hd(handles).owner_epoch,
        operation: operation,
        ref: make_ref(),
        handles: handles,
        kind: kind,
        holder: holder
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
      refs =
        for {ref, r} <- state.pins,
            r.acquirer === caller and r.pin.operation === operation,
            do: ref

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
      valid =
        Enum.all?(handles, fn
          %{provider: Provider, owner: owner, owner_epoch: epoch} ->
            is_pid(owner) and is_reference(epoch)

          _ ->
            false
        end)

      epochs = Enum.group_by(handles, &{&1.provider, &1.owner}, & &1.owner_epoch)

      if valid and Enum.all?(epochs, fn {_, es} -> length(Enum.uniq(es)) == 1 end),
        do: :ok,
        else: {:error, :invalid_generation_capture}
    end

    def correlate(pin, {provider, owner, operation, handles}, holder) do
      keys = [:provider, :owner, :owner_epoch, :operation, :ref, :handles, :kind, :holder]

      if is_map(pin) and Enum.sort(Map.keys(pin)) == Enum.sort(keys) and
           pin.provider === provider and pin.owner === owner and
           pin.operation === operation and pin.handles === handles and
           pin.owner_epoch === hd(handles).owner_epoch and pin.kind === :request and
           pin.holder === holder and is_reference(pin.ref),
         do: :ok,
         else: {:error, :invalid_generation_capture}
    end

    def preflight_cons(pin, pins) do
      # This fixture measures the ACTUAL two operands, before capture-list cons.
      bytes =
        if pins == [],
          do: 7 + :erlang.external_size(pin) - 1,
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

        defoverridable validate_manifest: 1,
                       correlate: 3,
                       preflight_cons: 2,
                       finite_checked_reason: 1,
                       release: 2
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
        :ok ->
          :ok

        :wait ->
          receive do
          after
            max(deadline - System.monotonic_time(:millisecond), 0) -> :ok
          end

        :raise ->
          raise "release fixture failure"

        :throw ->
          throw({:raw, String.duplicate("r", 70_000)})

        :exit ->
          exit(:release_fixture_exit)

        :garbage ->
          {:unexpected, :release}

        :error ->
          {:error, {:raw, String.duplicate("r", 70_000)}}
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
      [handle | :improper],
      List.duplicate(handle, 65),
      [Map.put(handle, :payload, String.duplicate("x", 65_536))],
      [%{handle | provider: __MODULE__}],
      [%{handle | owner_epoch: :not_a_reference}]
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
             checked_acquire(
               [handle(owner)],
               self(),
               System.monotonic_time(:millisecond),
               Accounting
             )

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

    assert {:ok, [pin]} =
             checked_acquire(
               [first, second, first],
               self(),
               deadline(),
               Accounting
             )

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

        value =
          case field do
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

        assert_receive {^token, {:error, :invalid_generation_capture, :cleanup_unconfirmed}},
                       1_000

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
      {Accounting, {:return, huge}},
      {Accounting, :raise},
      {Accounting, {:throw, deep}},
      {Accounting, {:exit, huge}},
      {BadCorrelation, :normal},
      {BadPreflight, :normal},
      {BadNormalizer, {:return, {:error, huge}}}
    ]

    for {accounting, action} <- cases do
      before = :sys.get_state(store)
      {caller, monitor, token} = request(store, deadline(), accounting)

      try do
        assert_receive {:checked_provider_paused, ^store, pin}, 1_000
        send(store, {:continue_checked_pin, pin.operation, action})

        assert_receive {^token, {:error, :generation_unavailable, :cleanup_unconfirmed} = result},
                       1_000

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

    {worker, monitor} =
      spawn_monitor(fn ->
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

    assert Code.ensure_loaded?(Generation)

    assert function_exported?(Generation, :snapshot_for_request, 4),
           "missing checked snapshot API"
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

  defp handle(owner),
    do: %{provider: Provider, owner: owner, owner_epoch: make_ref(), resource: make_ref()}

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

    {caller, monitor} =
      spawn_monitor(fn ->
        result = GenServer.call(store, {:snapshot_for_request, self(), d, accounting}, 3_000)
        send(observer, {token, result})

        receive do
          :finish -> :ok
        after
          3_000 -> exit(:checked_requester_not_finished)
        end
      end)

    on_exit(fn -> join_or_finish(caller) end)
    {caller, monitor, token}
  end

  defp idle do
    {pid, monitor} =
      spawn_monitor(fn ->
        receive do
          :finish -> :ok
        after
          4_000 -> :ok
        end
      end)

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

# Runtime cases are deliberately excluded from the Task 3.5 constructor gate.
# Execute only after the parent closes that gate on actual source constructors.
defmodule Gaoxy.HTTP.GenerationCheckedRuntimeTest do
  use ExUnit.Case, async: false
  @moduletag capture_log: true
  alias Gaoxy.Admission
  alias Gaoxy.HTTP.{Exchange, Generation, Request, Response, Router}
  alias Gaoxy.HTTP.GenerationCheckedCaptureTest.{Accounting, Provider}
  @fixture_budget 16_384
  @prior_route_bytes 37

  defmodule RuntimeAccounting do
    @budget 16_384
    def reservation(m, context) do
      %{observer: observer, token: token} = Process.get(__MODULE__)
      plan = {:native_generation_capture_v1, m, 65_536, 65_536, @budget}
      send(observer, {token, :reservation, self(), context, {:ok, plan}})
      {:ok, plan}
    end

    defdelegate validate_manifest(handles), to: Accounting
    defdelegate correlate(pin, entry, holder), to: Accounting
    defdelegate preflight_cons(pin, pins), to: Accounting
    defdelegate preflight_append(new, old), to: Accounting
    defdelegate finite_checked_reason(reason), to: Accounting

    def release(pin, dc) do
      %{observer: observer, token: token, cleanup: cleanup} = Process.get(__MODULE__)
      send(observer, {token, :release_attempt, self(), pin, dc})

      case cleanup do
        :ok ->
          Provider.release(pin, dc)

        :error ->
          {:error, {:release_raw, token, String.duplicate("r", 70_000)}}

        :raise ->
          raise "release fixture raised"

        :throw ->
          throw({:release_fixture_throw, token})

        :exit ->
          exit({:release_fixture_exit, token})

        :shared_deadline ->
          receive do
          after
            max(dc - System.monotonic_time(:millisecond), 0) -> {:error, :deadline_exceeded}
          end
      end
    end
  end

  defmodule Target do
    def init(options), do: {:ok, options}
    def resources(options), do: options.handles

    def call(exchange, options) do
      send(options.observer, {options.token, :router_entered, self(), exchange})
      latest = %{exchange | close: true}

      case options.primary do
        :ok ->
          result = {:ok, latest}
          send(options.observer, {options.token, :router_expected, result})
          result

        :returned_error ->
          result = {:error, options.raw, latest}
          send(options.observer, {options.token, :router_expected, result})
          result

        kind when kind in [:raise, :throw, :exit] ->
          original_marker(options.observer, options.token, kind, options.raw)

        :ordinary_io ->
          ordinary_io(latest, options)
      end
    end

    # The exact captured stack is evidence; independently invoking a throwing
    # endpoint and comparing two newly generated stacks would be insufficient.
    def original_marker(observer, token, kind, raw) do
      try do
        case kind do
          :raise -> raise RuntimeError, message: inspect(raw, limit: :infinity)
          :throw -> throw(raw)
          :exit -> exit(raw)
        end
      catch
        class, value ->
          stack = __STACKTRACE__
          send(observer, {token, :router_original_abnormal, class, value, stack})
          :erlang.raise(class, value, stack)
      end
    end

    defp ordinary_io(exchange, options) do
      {:more, polled} = Exchange.poll_connection(exchange, 500)
      checkpoint(options, :poll, polled)
      {body, read} = read_all(polled, "", options)
      true = body == "abc"
      true = Exchange.request_trailers(read) == [{"x-proof", "kept"}]
      checkpoint(options, :body_and_request_trailers, read)
      {:ok, chunked} = Response.send_chunked(read, 200, [{"trailer", "x-out"}])
      checkpoint(options, :response_head, chunked)
      :ok = Response.chunk(chunked, "reply")
      checkpoint(options, :response_chunk, chunked)
      {:ok, finished} = Response.finish(chunked, [{"x-out", "kept"}])
      checkpoint(options, :response_trailers_and_finish, finished)
      send(options.observer, {options.token, :io_finished, self(), finished})

      receive do
        {:peer_closed, token} when token == options.token -> :ok
      after
        2_000 -> raise "ordinary I/O peer-close barrier not released"
      end

      {:error, :closed, failed} = Exchange.poll_connection(finished, 500)
      checkpoint(options, :peer_error, failed)
      result = {:error, {:ordinary_peer_error, :closed}, failed}
      send(options.observer, {options.token, :router_expected, result})
      result
    end

    defp read_all(exchange, acc, options) do
      case Exchange.read_body_step(exchange, 3, 500) do
        {:more, bytes, next} ->
          checkpoint(options, :body_piece, next)
          read_all(next, acc <> bytes, options)

        {:ok, bytes, next} ->
          {acc <> bytes, next}

        {:pending, next} ->
          if Gaoxy.Lifecycle.remaining(next.deadline) <= 0,
            do: raise("ordinary body deadline exceeded")

          read_all(next, acc, options)
      end
    end

    defp checkpoint(options, stage, exchange) do
      send(
        options.observer,
        {options.token, :retained_checkpoint, stage, exchange, Admission.status(exchange.gate)}
      )
    end
  end

  setup do
    assert Code.ensure_loaded?(Gaoxy.HTTP.Resources)
    assert function_exported?(Gaoxy.HTTP.Resources, :pin_many_checked, 4)
    assert function_exported?(Gaoxy.HTTP.Resources, :release_checked, 3)
    assert function_exported?(Generation, :snapshot_for_request, 4)
    :ok
  end

  @tag :checked_capture_runtime
  test "one byte short of fixture B refuses before Store provider or Router effects" do
    fixture = fixture(:ok, @fixture_budget - 1)
    request = request(fixture, :ok)
    snapshot_debug = observe_snapshots(fixture, request.token, false)
    handlers = observe_cleanup(request, :ok)
    d = deadline(1_000)

    try do
      send(request.caller, {:run, d})
      assert_reservation(fixture, request, d)

      assert_receive {token, :outcome, {:returned, {:error, :byte_limit, charged}}}
                     when token == request.token,
                     1_000

      assert charged.route_bytes == @prior_route_bytes + @fixture_budget
      assert Admission.status(fixture.gate).retained_bytes == request.initial
      assert Admission.status(fixture.gate).active == 1
      assert GenServer.call(hd(fixture.owners), :count) == 1
      request_token = request.token
      refute_receive {^request_token, :snapshot_entered, _, _, _, _}, 0
      refute_receive {:checked_provider_entered, _, _, _}, 0
      request_token = request.token
      refute_receive {^request_token, :router_entered, _, _}, 0
      request_token = request.token
      refute_receive {^request_token, :cleanup_event, _, _, _}, 0
      request_token = request.token
      refute_receive {^request_token, :release_attempt, _, _, _}, 0
    after
      remove_snapshots(fixture.store, snapshot_debug)
      detach(handlers)
      finish_request(request, fixture.gate)
    end
  end

  @tag :checked_capture_runtime
  test "real gate contains prior route bytes plus B at Store entry and held provider entry" do
    fixture = fixture(:ok, @fixture_budget)
    owner = hd(fixture.owners)
    :ok = GenServer.call(owner, {:mode, :pause})
    request = request(fixture, :ok)
    debug = observe_snapshots(fixture, request.token, true)
    d = deadline(1_000)

    try do
      send(request.caller, {:run, d})
      assert_reservation(fixture, request, d)

      assert_receive {token, :snapshot_entered, store_caller, holder, ^d, at_store}
                     when token == request.token,
                     1_000

      assert store_caller === request.caller and holder === request.caller
      assert at_store.retained_bytes == request.initial + @fixture_budget
      assert_receive {:checked_provider_paused, store, pin} when store == fixture.store, 1_000

      try do
        assert pin.holder === request.caller
        assert Admission.status(fixture.gate).retained_bytes == request.initial + @fixture_budget
        assert Admission.status(fixture.gate).active == 1
        request_token = request.token
        refute_receive {^request_token, :router_entered, _, _}, 0
      after
        send(fixture.store, {:continue_checked_pin, pin.operation, :normal})
      end

      assert_receive {token, :outcome, {:returned, {:ok, _}}} when token == request.token, 1_000
      assert Admission.status(fixture.gate).retained_bytes == request.initial + @fixture_budget
      assert GenServer.call(owner, :count) == 1
    after
      remove_snapshots(fixture.store, debug)
      finish_request(request, fixture.gate)
    end
  end

  @tag :checked_capture_runtime
  test "suspended real gate timeout starts no Store provider or Router and does not refund a queued update" do
    fixture = fixture(:ok, @fixture_budget)
    request = request(fixture, :ok)
    debug = observe_snapshots(fixture, request.token, false)
    handlers = observe_cleanup(request, :ok)
    :ok = :sys.suspend(fixture.gate)
    assert :erlang.trace(request.caller, true, [:send, {:tracer, self()}]) == 1
    d = deadline(100)

    try do
      send(request.caller, {:run, d})
      assert_reservation(fixture, request, d)
      caller = request.caller
      lease = request.lease
      gate = fixture.gate
      charged_bytes = request.initial + @fixture_budget

      assert_receive {:trace, ^caller, :send,
                      {:"$gen_call", {^caller, _}, {:update, ^lease, ^charged_bytes}}, ^gate},
                     1_000

      assert_receive {token, :outcome, {:returned, {:error, :deadline_exceeded, charged}}}
                     when token == request.token,
                     1_000

      assert charged.route_bytes == @prior_route_bytes + @fixture_budget
      request_token = request.token
      refute_receive {^request_token, :snapshot_entered, _, _, _, _}, 0
      refute_receive {:checked_provider_entered, _, _, _}, 0
      request_token = request.token
      refute_receive {^request_token, :router_entered, _, _}, 0
      request_token = request.token
      refute_receive {^request_token, :cleanup_event, _, _, _}, 0
      :ok = :sys.resume(fixture.gate)
      assert Admission.status(fixture.gate).retained_bytes == charged_bytes
      assert GenServer.call(hd(fixture.owners), :count) == 1
    after
      if Process.alive?(fixture.gate), do: :sys.resume(fixture.gate)
      if Process.alive?(request.caller), do: :erlang.trace(request.caller, false, [:send])
      remove_snapshots(fixture.store, debug)
      detach(handlers)
      finish_request(request, fixture.gate)
    end
  end

  for observer <- [:ok, :raise, :throw, :exit] do
    @tag :checked_capture_runtime
    test "acquisition uncertainty preserves finite primary with observer #{observer}" do
      run_acquisition_failure(unquote(observer))
    end
  end

  for primary <- [:ok, :returned_error, :raise, :throw, :exit],
      cleanup <- [:ok, :error, :raise, :throw, :exit, :shared_deadline],
      observer <- [:ok, :raise, :throw, :exit] do
    @tag :checked_capture_runtime
    test "C5 #{primary} / release #{cleanup} / observer #{observer}" do
      run_c5(unquote(primary), unquote(cleanup), unquote(observer))
    end
  end

  @tag :checked_capture_runtime
  test "ordinary body poll retained updates sends trailers finalization and peer error preserve B until teardown" do
    fixture = fixture(:ordinary_io, @fixture_budget + 65_536)
    {template, client, raw} = socket_exchange(fixture)
    request = request(fixture, :ok, template)
    :ok = :gen_tcp.controlling_process(raw, request.caller)
    update_debug = observe_updates(fixture.gate, request)
    handlers = observe_cleanup(request, :ok)
    d = deadline(3_000)

    try do
      :ok = :gen_tcp.send(client, "3\r\nabc\r\n0\r\nx-proof: kept\r\n\r\n")
      send(request.caller, {:run, d})

      assert_receive {token, :io_finished, caller, finished}
                     when token == request.token,
                     2_000

      assert caller === request.caller
      assert finished.response === :sent
      assert finished.response_trailers == []
      assert finished.route_bytes == @prior_route_bytes + @fixture_budget
      wire = receive_until(client, "0\r\nx-out: kept\r\n\r\n", deadline(1_000), "")
      assert wire =~ "HTTP/1.1 200"
      assert wire =~ "5\r\nreply\r\n"
      :ok = :gen_tcp.close(client)
      send(request.caller, {:peer_closed, request.token})
      assert_receive {token, :router_expected, expected} when token == request.token, 1_000
      assert_receive {token, :outcome, {:returned, actual}} when token == request.token, 1_000
      assert actual === expected
      assert {:error, {:ordinary_peer_error, :closed}, latest} = actual
      assert Admission.status(fixture.gate).retained_bytes == Exchange.retained_bytes(latest)
      checkpoints = drain_checkpoints(request.token, [])
      stages = Enum.map(checkpoints, &elem(&1, 0))

      for required <- [
            :poll,
            :body_and_request_trailers,
            :response_head,
            :response_chunk,
            :response_trailers_and_finish,
            :peer_error
          ],
          do: assert(required in stages)

      for {_stage, exchange, status} <- checkpoints do
        assert exchange.route_bytes == @prior_route_bytes + @fixture_budget
        assert status.retained_bytes == Exchange.retained_bytes(exchange)
        assert status.retained_bytes >= @prior_route_bytes + @fixture_budget
        assert status.active == 1
      end

      updates = drain_updates(request.token, [])
      assert length(updates) >= 8
      assert Enum.all?(updates, &(&1 >= @prior_route_bytes + @fixture_budget))
      assert GenServer.call(hd(fixture.owners), :count) == 1
      request_token = request.token
      refute_receive {^request_token, :cleanup_event, _, _, _}, 0
    after
      :gen_tcp.close(client)
      remove_snapshots(fixture.gate, update_debug)
      detach(handlers)
      finish_request(request, fixture.gate)
    end
  end

  defp run_acquisition_failure(observer) do
    fixture = fixture(:ok, @fixture_budget)
    owner = hd(fixture.owners)
    :ok = GenServer.call(owner, {:mode, :pause})
    request = request(fixture, :ok)
    handlers = observe_cleanup(request, observer)
    d = deadline(1_000)

    try do
      send(request.caller, {:run, d})
      assert_reservation(fixture, request, d)
      assert_receive {:checked_provider_paused, store, pin} when store == fixture.store, 1_000
      raw = {:provider_raw, String.duplicate("a", 70_000)}
      send(fixture.store, {:continue_checked_pin, pin.operation, {:return, {:error, raw}}})

      assert_receive {token, :outcome, {:returned, {:error, :generation_unavailable, charged}}}
                     when token == request.token,
                     1_000

      assert charged.route_bytes == @prior_route_bytes + @fixture_budget
      operation = pin.operation
      store = fixture.store
      assert_receive {:checked_cancelled, ^owner, ^store, ^operation}, 1_000
      assert GenServer.call(owner, :count) == 1
      assert Admission.status(fixture.gate).retained_bytes == request.initial + @fixture_budget
      assert Admission.status(fixture.gate).active == 1

      assert_receive {token, :cleanup_event, [:gaoxy, :generation_capture_cleanup], measurements,
                      metadata}
                     when token == request.token,
                     0

      assert measurements === %{count: 1}

      assert metadata === %{
               store: fixture.store,
               holder: request.caller,
               lease: request.lease,
               stage: :acquisition,
               cleanup: :cleanup_unconfirmed
             }

      assert_receive {token, :observer_invoked} when token == request.token, 0
      request_token = request.token
      refute_receive {^request_token, :cleanup_event, _, _, _}, 0
      request_token = request.token
      refute_receive {^request_token, :observer_invoked}, 0
      request_token = request.token
      refute_receive {^request_token, :router_entered, _, _}, 0
      request_token = request.token
      refute_receive {^request_token, :release_attempt, _, _, _}, 0
    after
      detach(handlers)
      finish_request(request, fixture.gate)
    end
  end

  defp run_c5(primary, cleanup, observer) do
    fixture = fixture(primary, @fixture_budget, 2)
    request = request(fixture, cleanup)
    handlers = observe_cleanup(request, observer)
    d = deadline(500)

    try do
      send(request.caller, {:run, d})
      assert_reservation(fixture, request, d)
      assert_receive {token, :router_entered, caller, captured} when token == request.token, 1_000
      assert caller === request.caller
      assert length(captured.resource_pins) == 2
      assert Enum.all?(captured.resource_pins, &(&1.holder === caller and &1.kind === :request))
      assert_receive {token, :outcome, observed} when token == request.token, 2_500

      if primary in [:ok, :returned_error] do
        assert_receive {token, :router_expected, original} when token == request.token, 0

        expected =
          case {original, cleanup} do
            {{:ok, latest}, failed} when failed != :ok ->
              {:error, :generation_pin_release_failed, latest}

            _ ->
              original
          end

        assert observed === {:returned, expected}
      else
        assert_receive {token, :router_original_abnormal, class, value, stack}
                       when token == request.token,
                       0

        assert observed === {:caught, class, value, stack}

        assert Enum.any?(stack, fn
                 {Target, :original_marker, _, _} -> true
                 _ -> false
               end)
      end

      # Call result is joined before checking synchronous callbacks/events.
      # The requester remains live so its real lease and failed pins persist.
      assert Process.alive?(request.caller)
      assert Admission.status(fixture.gate).retained_bytes == request.initial + @fixture_budget
      assert Admission.status(fixture.gate).active == 1
      attempts = drain_releases(request.token, [])
      assert attempts != []
      assert length(attempts) <= length(captured.resource_pins)

      refs =
        Enum.map(attempts, fn {who, pin, dc} ->
          assert who === request.caller
          assert pin in captured.resource_pins
          assert dc === d + 1_000
          pin.ref
        end)

      assert length(refs) == length(Enum.uniq(refs))
      if cleanup == :ok, do: assert(length(attempts) == 2)
      if cleanup == :shared_deadline, do: assert(length(attempts) == 1)

      if cleanup == :ok do
        request_token = request.token
        refute_receive {^request_token, :cleanup_event, _, _, _}, 0
        request_token = request.token
        refute_receive {^request_token, :observer_invoked}, 0
        for owner <- fixture.owners, do: assert(GenServer.call(owner, :count) == 1)
      else
        assert_receive {token, :cleanup_event, [:gaoxy, :generation_capture_cleanup],
                        measurements, metadata}
                       when token == request.token,
                       0

        assert measurements === %{count: 1}

        assert metadata === %{
                 store: fixture.store,
                 holder: request.caller,
                 lease: request.lease,
                 stage: :release,
                 cleanup: :cleanup_unconfirmed
               }

        assert :erlang.external_size({measurements, metadata}) < 1_024
        assert_receive {token, :observer_invoked} when token == request.token, 0
        request_token = request.token
        refute_receive {^request_token, :cleanup_event, _, _, _}, 0
        request_token = request.token
        refute_receive {^request_token, :observer_invoked}, 0
        for owner <- fixture.owners, do: assert(GenServer.call(owner, :count) == 2)
      end

      request_token = request.token
      refute_receive {^request_token, :router_entered, _, _}, 0
      request_token = request.token
      refute_receive {^request_token, :release_attempt, _, _, _}, 0
    after
      detach(handlers)
      finish_request(request, fixture.gate)
    end
  end

  defp fixture(primary, available, owner_count \\ 1) do
    token = make_ref()

    owners =
      for i <- 1..owner_count,
          do: start_supervised!({Provider, self()}, id: {:runtime_provider, i})

    handles =
      Enum.map(owners, fn owner ->
        %{provider: Provider, owner: owner, owner_epoch: make_ref(), resource: make_ref()}
      end)

    raw = {:router_raw, token, [String.duplicate("p", 70_000), %{nested: {:exact, token}}]}
    options = %{observer: self(), token: token, handles: handles, primary: primary, raw: raw}
    assert {:ok, router} = Router.compile([%{target: {Target, options}}])
    store = start_supervised!({Generation, router: router})
    assert {:ok, spec} = Gaoxy.HTTP.service_spec(endpoint: {Target, options})

    template = %Exchange{
      request: %Request{
        method: "GET",
        path: "/",
        host: "localhost",
        version: :"HTTP/1.1",
        head_bytes: 0,
        keep_alive: true
      },
      buffer: "",
      route_bytes: @prior_route_bytes,
      limits: spec.handler_options.http_limits,
      body: Gaoxy.HTTP.HTTP1.Body.new(:none),
      instance: make_ref(),
      service: :runtime_fixture
    }

    initial = Exchange.retained_bytes(template)

    gate =
      start_supervised!(
        {Admission,
         {%{spec.limits | max_bytes: initial + available},
          %{scope_marker: :must_not_appear_in_cleanup}}}
      )

    %{
      store: store,
      owners: owners,
      gate: gate,
      token: token,
      template: template,
      http_limits: spec.handler_options.http_limits,
      available: available
    }
  end

  defp request(fixture, cleanup, template \\ nil) do
    template = template || fixture.template
    observer = self()
    token = fixture.token
    gate = fixture.gate
    store = fixture.store
    initial = Exchange.retained_bytes(template)

    {caller, monitor} =
      spawn_monitor(fn ->
        {:ok, lease} = Admission.acquire(gate, initial)
        {:ok, config} = Generation.init({store, accounting: RuntimeAccounting})
        exchange = %{template | gate: gate, lease: lease}
        Process.put(RuntimeAccounting, %{observer: observer, token: token, cleanup: cleanup})
        send(observer, {token, :request_ready, self(), lease})

        receive do
          {:run, d} ->
            outcome =
              try do
                {:returned, Generation.call(%{exchange | deadline: d}, config)}
              catch
                class, value -> {:caught, class, value, __STACKTRACE__}
              end

            send(observer, {token, :outcome, outcome})

            receive do
              :finish -> :ok
            after
              4_000 -> exit(:runtime_requester_not_finished)
            end

          :finish ->
            :ok
        after
          4_000 -> exit(:runtime_requester_not_started)
        end
      end)

    on_exit(fn -> join_or_finish(caller) end)
    assert_receive {^token, :request_ready, ^caller, lease}, 1_000
    %{caller: caller, monitor: monitor, token: token, lease: lease, initial: initial}
  end

  defp assert_reservation(fixture, request, d) do
    assert_receive {token, :reservation, caller, context, result} when token == request.token,
                   1_000

    assert caller === request.caller

    assert context ===
             {fixture.store, request.caller, fixture.gate, request.lease, :request, d,
              request.initial}

    assert result ===
             {:ok, {:native_generation_capture_v1, 1_048_576, 65_536, 65_536, @fixture_budget}}
  end

  defp observe_snapshots(fixture, token, capture_status) do
    observer = self()
    id = make_ref()
    gate = fixture.gate

    :ok =
      :sys.install(
        fixture.store,
        {id,
         fn state, event, _ ->
           case event do
             {:in,
              {:"$gen_call", {caller, _}, {:snapshot_for_request, holder, d, RuntimeAccounting}}} ->
               status = if capture_status, do: Admission.status(gate), else: nil
               send(observer, {token, :snapshot_entered, caller, holder, d, status})

             _ ->
               :ok
           end

           state
         end, nil}
      )

    id
  end

  defp observe_updates(gate, request) do
    observer = self()
    id = make_ref()
    lease = request.lease
    token = request.token

    :ok =
      :sys.install(
        gate,
        {id,
         fn state, event, _ ->
           case event do
             {:in, {:"$gen_call", _, {:update, ^lease, bytes}}} ->
               send(observer, {token, :gate_update, bytes})

             _ ->
               :ok
           end

           state
         end, nil}
      )

    id
  end

  defp remove_snapshots(pid, id) do
    if Process.alive?(pid), do: :sys.remove(pid, id)
  end

  defp observe_cleanup(request, mode) do
    witness = make_ref()
    failing_observer = make_ref()

    config = %{
      observer: self(),
      holder: request.caller,
      lease: request.lease,
      token: request.token,
      mode: mode
    }

    :ok =
      :telemetry.attach(
        witness,
        [:gaoxy, :generation_capture_cleanup],
        &__MODULE__.cleanup_witness/4,
        config
      )

    :ok =
      :telemetry.attach(
        failing_observer,
        [:gaoxy, :generation_capture_cleanup],
        &__MODULE__.cleanup_observer/4,
        config
      )

    [witness, failing_observer]
  end

  def cleanup_witness(event, measurements, metadata, config) do
    if metadata[:holder] === config.holder and metadata[:lease] === config.lease,
      do: send(config.observer, {config.token, :cleanup_event, event, measurements, metadata})
  end

  def cleanup_observer(_, _, metadata, config) do
    if metadata[:holder] === config.holder and metadata[:lease] === config.lease do
      send(config.observer, {config.token, :observer_invoked})

      case config.mode do
        :ok -> :ok
        :raise -> raise "cleanup observer raised"
        :throw -> throw({:observer_throw, config.token})
        :exit -> exit({:observer_exit, config.token})
      end
    end
  end

  defp detach(ids), do: Enum.each(ids, &:telemetry.detach/1)

  defp finish_request(request, gate) do
    send(request.caller, :finish)

    assert_receive {:DOWN, monitor, :process, caller, :normal}
                   when monitor == request.monitor and caller == request.caller,
                   4_000

    eventually(
      fn -> Admission.status(gate).active == 0 and Admission.status(gate).retained_bytes == 0 end,
      deadline(1_000)
    )
  end

  defp join_or_finish(caller) do
    monitor = Process.monitor(caller)
    send(caller, :finish)

    receive do
      {:DOWN, ^monitor, :process, ^caller, _} -> :ok
    after
      4_000 -> flunk("runtime test-owned caller did not join")
    end
  end

  defp eventually(fun, d) do
    unless fun.() do
      assert System.monotonic_time(:millisecond) < d

      receive do
      after
        2 -> :ok
      end

      eventually(fun, d)
    end
  end

  defp drain_releases(token, acc) do
    receive do
      {^token, :release_attempt, caller, pin, dc} ->
        drain_releases(token, [{caller, pin, dc} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp drain_checkpoints(token, acc) do
    receive do
      {^token, :retained_checkpoint, stage, exchange, status} ->
        drain_checkpoints(token, [{stage, exchange, status} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp drain_updates(token, acc) do
    receive do
      {^token, :gate_update, bytes} -> drain_updates(token, [bytes | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp socket_exchange(fixture) do
    {:ok, request, ""} =
      Gaoxy.HTTP.HTTP1.Parser.parse_head(
        "POST / HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\n\r\n",
        fixture.http_limits
      )

    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {ip, port}} = :inet.sockname(listener)
    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)
    {:ok, raw} = :gen_tcp.accept(listener, 1_000)
    :ok = :gen_tcp.close(listener)

    on_exit(fn ->
      :gen_tcp.close(client)
      :gen_tcp.close(raw)
    end)

    socket =
      struct!(ThousandIsland.Socket,
        socket: raw,
        transport_module: ThousandIsland.Transports.TCP,
        read_timeout: 1_000,
        handshake_timeout: 1_000,
        silent_terminate_on_error: false,
        span: ThousandIsland.Telemetry.start_span(:connection, %{}, %{handler: __MODULE__})
      )

    exchange = Exchange.new(request, socket, nil, nil, deadline(3_000), fixture.http_limits, "")
    {%{exchange | route_bytes: @prior_route_bytes}, client, raw}
  end

  defp receive_until(client, suffix, d, acc) do
    if String.ends_with?(acc, suffix) do
      acc
    else
      remaining = max(d - System.monotonic_time(:millisecond), 0)
      assert remaining > 0
      assert {:ok, bytes} = :gen_tcp.recv(client, 0, remaining)
      receive_until(client, suffix, d, acc <> bytes)
    end
  end

  defp deadline(ms), do: System.monotonic_time(:millisecond) + ms
end

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
    assert Code.ensure_loaded?(Generation)
    assert function_exported?(Generation, :snapshot_for_request, 4)
    :ok
  end

  @tag :checked_capture_runtime
  test "compact success payload validates exact marker M H Q B and tuple grammar before effects" do
    fixture = fixture()

    invalid = [
      {:field, 0, :another_profile},
      {:field, 0, nil},
      {:field, 1, 1_048_577},
      {:field, 1, 0},
      {:field, 1, :wrong_m},
      {:field, 2, 65_535},
      {:field, 2, :wrong_h},
      {:field, 3, 65_537},
      {:field, 3, :wrong_q},
      {:field, 4, -1},
      {:field, 4, 1.5},
      {:field, 4, nil},
      :short_plan,
      :long_plan,
      :non_tuple_plan
    ]

    for mode <- invalid,
        do: assert_reservation_refusal(fixture, mode, :invalid_generation_capture)
  end

  @tag :checked_capture_runtime
  test "non-contract outer reservation results normalize to generation unavailable before effects" do
    fixture = fixture()

    for value <- [
          :ok,
          nil,
          {:unexpected, :outer},
          {:ok, :extra, :arity},
          %{raw: String.duplicate("r", 70_000)}
        ] do
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
          {:byte_limit, :byte_limit},
          {:generation_capture_capacity, :generation_capture_capacity},
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

      assert context ===
               {fixture.store, caller, fixture.gate, request.lease, :request, d, request.initial}

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

      assert_receive {^token, :outcome,
                      {:returned, {:error, :generation_capture_capacity, charged}}},
                     1_000

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
        assert_receive {^token, :cleanup_event, [:gaoxy, :generation_capture_cleanup], measures,
                        metadata},
                       0

        assert measures === %{count: 1}

        assert metadata === %{
                 store: fixture.store,
                 holder: caller,
                 lease: request.lease,
                 stage: :acquisition,
                 cleanup: :cleanup_unconfirmed
               }

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

    assert MapSet.new(
             Enum.map(attempts, fn {who, pin, actual_dc} ->
               assert who === caller
               assert actual_dc === dc
               assert pin in pins
               pin.ref
             end)
           ) == MapSet.new(Enum.map(pins, & &1.ref))

    assert length(Enum.uniq_by(attempts, fn {_, pin, _} -> pin.ref end)) == length(pins)
  end

  defp fixture do
    token = make_ref()

    new_owners =
      for i <- 1..2,
          do: start_supervised!({Provider, self()}, id: {:contract_new_owner, make_ref(), i})

    old_owner = start_supervised!({Provider, self()}, id: {:contract_old_owner, make_ref()})
    new_handles = Enum.map(new_owners, &handle/1)

    assert {:ok, router} =
             Router.compile([%{target: {Target, %{observer: self(), handles: new_handles}}}])

    store = start_supervised!({Generation, router: router}, id: {:contract_store, token})

    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Target, %{observer: self(), handles: new_handles}}
             )

    template = %Exchange{
      request: %Request{
        method: "GET",
        path: "/",
        host: "localhost",
        version: :"HTTP/1.1",
        head_bytes: 0,
        keep_alive: true
      },
      buffer: "",
      route_bytes: @prior,
      body: Gaoxy.HTTP.HTTP1.Body.new(:none),
      limits: spec.handler_options.http_limits
    }

    gate =
      start_supervised!(
        {Admission,
         {%{spec.limits | max_bytes: @prior + @budget}, %{scope_marker: :must_not_leak}}},
        id: {:contract_gate, token}
      )

    observer = self()
    store_debug = make_ref()

    :ok =
      :sys.install(
        store,
        {store_debug,
         fn state, event, _ ->
           case event do
             {:in, {:"$gen_call", {caller, _}, {:snapshot_for_request, holder, d, accounting}}} ->
               send(observer, {:contract_snapshot, caller, holder, d, accounting})

             _ ->
               :ok
           end

           state
         end, nil}
      )

    gate_debug = make_ref()

    :ok =
      :sys.install(
        gate,
        {gate_debug,
         fn state, event, _ ->
           case event do
             {:in, {:"$gen_call", {caller, _}, {:update, lease, bytes}}} ->
               send(observer, {:contract_gate_update, caller, lease, bytes})

             _ ->
               :ok
           end

           state
         end, nil}
      )

    on_exit(fn ->
      if Process.alive?(store), do: :sys.remove(store, store_debug)
      if Process.alive?(gate), do: :sys.remove(gate, gate_debug)
    end)

    %{
      store: store,
      gate: gate,
      template: template,
      old_owner: old_owner,
      old_handle: handle(old_owner),
      new_owners: new_owners
    }
  end

  defp request(fixture, reservation, cleanup, existing_count) do
    observer = self()
    token = make_ref()

    {caller, monitor} =
      spawn_monitor(fn ->
        Process.put(ContractAccounting, %{
          observer: observer,
          token: token,
          reservation: reservation,
          cleanup: cleanup
        })

        initial = Exchange.retained_bytes(fixture.template)
        {:ok, lease} = Admission.acquire(fixture.gate, initial)

        existing =
          if existing_count == 0 do
            []
          else
            d = deadline(5_000)

            Enum.reduce(1..existing_count, [], fn _, accepted ->
              {:ok, [pin]} =
                apply(Resources, :pin_many_checked, [
                  [fixture.old_handle],
                  self(),
                  d,
                  ContractAccounting
                ])

              {:ok, _} = Accounting.preflight_cons(pin, accepted)
              [pin | accepted]
            end)
          end

        exchange = %{fixture.template | gate: fixture.gate, lease: lease, resource_pins: existing}
        {:ok, config} = Generation.init({fixture.store, accounting: ContractAccounting})
        send(observer, {token, :ready, self(), lease, exchange, existing})

        receive do
          {:run, d} ->
            result =
              try do
                {:returned, Generation.call(%{exchange | deadline: d}, config)}
              catch
                class, value -> {:caught, class, value, __STACKTRACE__}
              end

            send(observer, {token, :outcome, result})

            receive do
              :finish -> :ok
            after
              4_000 -> exit(:contract_requester_not_finished)
            end

          :finish ->
            :ok
        after
          4_000 -> exit(:contract_requester_not_started)
        end
      end)

    on_exit(fn -> join_or_finish(caller) end)
    assert_receive {^token, :ready, ^caller, lease, exchange, existing}, 6_000

    %{
      caller: caller,
      monitor: monitor,
      token: token,
      lease: lease,
      exchange: exchange,
      initial: Exchange.retained_bytes(exchange),
      existing: existing
    }
  end

  defp observe_cleanup(request) do
    id = make_ref()

    :ok =
      :telemetry.attach(
        id,
        [:gaoxy, :generation_capture_cleanup],
        &__MODULE__.cleanup_witness/4,
        %{observer: self(), token: request.token, holder: request.caller, lease: request.lease}
      )

    id
  end

  def cleanup_witness(event, measurements, metadata, config) do
    if metadata[:holder] === config.holder and metadata[:lease] === config.lease,
      do: send(config.observer, {config.token, :cleanup_event, event, measurements, metadata})
  end

  defp drain_releases(token, acc) do
    receive do
      {^token, :release_attempt, caller, pin, dc} ->
        drain_releases(token, [{caller, pin, dc} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp finish_request(request, fixture) do
    send(request.caller, :finish)
    monitor = request.monitor
    caller = request.caller
    assert_receive {:DOWN, ^monitor, :process, ^caller, :normal}, 4_000

    eventually(
      fn ->
        Admission.status(fixture.gate).active == 0 and
          Admission.status(fixture.gate).retained_bytes == 0 and
          GenServer.call(fixture.old_owner, :count) == 0 and
          Enum.all?(fixture.new_owners, &(GenServer.call(&1, :count) == 1))
      end,
      deadline(1_000)
    )
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

      receive do
      after
        2 -> :ok
      end

      eventually(fun, d)
    end
  end

  defp handle(owner),
    do: %{provider: Provider, owner: owner, owner_epoch: make_ref(), resource: make_ref()}

  defp deadline(ms), do: System.monotonic_time(:millisecond) + ms
end
