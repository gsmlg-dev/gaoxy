defmodule Gaoxy.HTTP.GenerationResourceConsistencyTest do
  use ExUnit.Case, async: true

  alias Gaoxy.HTTP.{Generation, Resources, Router}
  alias Gaoxy.Lifecycle

  # This owner is a public test fixture: no production owner state is inspected.
  # Its ledger records exact public pins, holders, and custody operations.
  defmodule Provider do
    use GenServer
    @behaviour Resources

    def start_link(_), do: GenServer.start_link(__MODULE__, nil)
    def init(_), do: {:ok, %{holds: %{}, events: [], initialized: []}}
    def status(owner), do: GenServer.call(owner, :status, 1_000)

    def initialized(owner, marker),
      do: GenServer.call(owner, {:initialized, marker}, 1_000)

    def pin_many([handle | _] = handles, holder, kind, operation, deadline),
      do: Lifecycle.call(handle.owner, {:pin, handles, holder, kind, operation}, deadline)

    def release(pin), do: GenServer.call(pin.owner, {:release, pin}, 1_000)
    def cancel(owner, operation), do: GenServer.call(owner, {:cancel, operation}, 1_000)

    def handle_call(:status, _, state), do: {:reply, state, state}

    def handle_call({:initialized, marker}, _, state),
      do: {:reply, :ok, %{state | initialized: state.initialized ++ [marker]}}

    def handle_call({:pin, handles, holder, kind, operation}, {caller, _}, state) do
      event = {:pin, handles, holder, kind, operation}
      state = %{state | events: state.events ++ [event]}

      if Enum.any?(handles, &Map.get(&1, :unavailable, false)) do
        {:reply, {:error, :test_resource_unavailable}, state}
      else
        ref = make_ref()
        pin = %{provider: __MODULE__, owner: self(), operation: operation, ref: ref, handles: handles}
        pin = if Map.get(hd(handles), :six_keys, false), do: Map.put(pin, :kind, kind), else: pin
        hold = %{pin: pin, holder: holder, kind: kind, acquirer: caller}
        {:reply, {:ok, pin}, %{state | holds: Map.put(state.holds, ref, hold)}}
      end
    end

    def handle_call({:release, pin}, {caller, _}, state) do
      case state.holds[pin.ref] do
        %{pin: ^pin, holder: ^caller} ->
          {:reply, :ok,
           %{state | holds: Map.delete(state.holds, pin.ref), events: state.events ++ [{:release, pin, caller}]}}

        _ ->
          {:reply, {:error, :invalid_test_release}, state}
      end
    end

    def handle_call({:cancel, operation}, {caller, _}, state) do
      holds = Map.reject(state.holds, fn {_, hold} ->
        hold.acquirer == caller and hold.pin.operation == operation
      end)

      {:reply, :ok, %{state | holds: holds, events: state.events ++ [{:cancel, operation, caller}]}}
    end
  end

  defmodule Endpoint do
    def init(config) do
      if marker = Map.get(config, :init_marker),
        do: Provider.initialized(config.observer, marker)

      {:ok, config}
    end

    def call(exchange, _), do: {:ok, exchange}
    def resources(%{handles: :raise}), do: raise("test-owned resource callback exception")
    def resources(%{handles: :throw}), do: throw(:test_resource_throw)
    def resources(%{handles: :exit}), do: exit(:test_resource_exit)
    def resources(%{handles: handles}), do: handles
  end

  defmodule Legacy do
    def init(config), do: {:ok, config}
    def call(exchange, _), do: {:ok, exchange}
  end

  defmodule Denied do
    def init(config), do: {:ok, config}
    def call(exchange, _), do: {:ok, exchange}
    def resources(_), do: raise("must not run before denied generation hook")
    def generation_validate(_), do: {:error, :test_generation_denied}
  end

  setup do
    old_owner = start_supervised!({Provider, []}, id: :old_owner)
    candidate_owner = start_supervised!({Provider, []}, id: :candidate_owner)
    old_handle = handle(old_owner, :old)
    {:ok, old_router} = Router.compile(routes([old_handle]))
    store = start_supervised!({Generation, router: old_router})

    {:ok, generation, ^old_router, [request_pin] = request_pins} =
      Generation.snapshot_for_request(store, self(), Lifecycle.deadline(1_000))

    status = Provider.status(old_owner)
    assert %{holder: holder, kind: :request, pin: ^request_pin} = status.holds[request_pin.ref]
    assert holder == self()
    assert Enum.count(status.holds, fn {_, hold} -> hold.kind == :baseline end) == 1

    context = %{
      store: store,
      generation: generation,
      old_router: old_router,
      old_owner: old_owner,
      candidate_owner: candidate_owner,
      request_pins: request_pins
    }

    # The request pin belongs to the test process, so release it here, never in on_exit.
    {:ok, context}
  end

  for path <- [:public, :direct, :prepare, :initial_router, :initial_routes],
      defect <- [:missing, :extra, :substituted, :old_epoch] do
    test "#{path} refuses a valid-shaped #{defect} resource sidecar before custody", context do
      with_request_cleanup(context, fn ->
        owner = context.candidate_owner
        old_epoch = make_ref()
        actual = handle(owner, :actual)
        extra = handle(owner, :extra)
        {:ok, candidate} = Router.compile(routes([actual]))

        supplied =
          case unquote(defect) do
            :missing -> []
            :extra -> [actual, extra]
            :substituted -> [extra]
            :old_epoch -> [%{actual | owner_epoch: old_epoch}]
          end

        assert {:ok, _} = Resources.validate(supplied)
        forged = %{candidate | resources: supplied}
        assert_refused(context, unquote(path), forged)
      end)
    end
  end

  for path <- [:public, :direct, :prepare, :initial_router, :initial_routes],
      defect <- [:missing, :extra, :substituted, :old_epoch] do
    test "#{path} walks two static levels with agreeing #{defect} false sidecars", context do
      with_request_cleanup(context, fn ->
        old_epoch = make_ref()
        actual = handle(context.candidate_owner, :deep_actual)
        {:ok, leaf} = Router.compile(routes([actual]))
        extra = handle(context.candidate_owner, :deep_extra)
        supplied =
          case unquote(defect) do
            :missing -> []
            :extra -> [actual, extra]
            :substituted -> [extra]
            :old_epoch -> [%{actual | owner_epoch: old_epoch}]
          end

        assert {:ok, _} = Resources.validate(supplied)
        leaf = %{leaf | resources: supplied}
        {:ok, middle} = Router.compile([%{target: {Router, leaf}}])
        {:ok, outer} = Router.compile([%{target: {Router, middle}}])
        assert leaf.resources == middle.resources
        assert middle.resources == outer.resources
        assert_refused(context, unquote(path), outer)
      end)
    end
  end

  for bad <- [:malformed, [nil], [%{provider: Provider}], :raise, :throw, :exit] do
    test "activation normalizes #{inspect(bad)} resource callback failures without custody", context do
      with_request_cleanup(context, fn ->
        {:ok, candidate} = Router.compile(routes([]))
        [route] = candidate.routes
        forged = %{candidate | routes: [%{route | target: {Endpoint, %{handles: unquote(Macro.escape(bad))}}}]}
        assert_refused(context, :public, forged)
        assert_refused(context, :direct, forged)
        assert_refused(context, :prepare, forged)
      end)
    end
  end

  test "malformed static routers fail finitely without endpoint ownership effects", context do
    with_request_cleanup(context, fn ->
      {:ok, candidate} = Router.compile([])

      for nested <- [:not_a_router, %Router{routes: :not_a_list}, %Router{routes: [%{}]}] do
        forged = %{candidate | routes: [compiled_route(Router, nested)]}
        assert_refused(context, :public, forged)
        assert_refused(context, :direct, forged)
        assert_refused(context, :prepare, forged)
      end
    end)
  end

  for six_keys <- [false, true] do
    test "equivalent reordered duplicates retain the exact router with generic #{if six_keys, do: 6, else: 5}-key pins", context do
      with_request_cleanup(context, fn ->
        first = Map.put(handle(context.candidate_owner, :first), :six_keys, unquote(six_keys))
        second = Map.put(handle(context.candidate_owner, :second), :six_keys, unquote(six_keys))
        {:ok, candidate} = Router.compile(routes([first]) ++ routes([second]))
        assert candidate.resources == [second, first]
        supplied = %{candidate | resources: [first, second, first]}
        assert {:ok, next} = Generation.activate(context.store, context.generation, supplied, 1_000)
        assert {:ok, ^next, ^supplied} = Generation.snapshot(context.store)

        assert [hold] = Provider.status(context.candidate_owner).holds |> Map.values()
        assert hold.kind == :baseline
        assert hold.holder == context.store
        assert hold.pin.handles == [first, second]
        assert map_size(hold.pin) == unquote(if(six_keys, do: 6, else: 5))
        assert Enum.sort(Map.keys(hold.pin)) ==
                 Enum.sort(unquote(if(six_keys, do: [:provider, :owner, :operation, :ref, :handles, :kind], else: [:provider, :owner, :operation, :ref, :handles])))
      end)
    end
  end

  test "raw 64 distinct handles preserve the bounded resource union", context do
    with_request_cleanup(context, fn ->
      handles = for id <- 1..64, do: handle(context.candidate_owner, id)
      assert {:ok, candidate} = Router.compile(routes(handles))
      assert {:ok, ^handles} = Resources.validate(handles)
      assert {:ok, next} = Generation.activate(context.store, context.generation, candidate, 1_000)
      assert {:ok, ^next, ^candidate} = Generation.snapshot(context.store)
      assert [hold] = Provider.status(context.candidate_owner).holds |> Map.values()
      assert hold.pin.handles == handles
    end)
  end

  test "raw 64 duplicate sidecar entries pass and raw 65 do not normalize past the bound", context do
    with_request_cleanup(context, fn ->
      one = handle(context.candidate_owner, :shared)
      {:ok, candidate} = Router.compile(routes([one]))
      assert_refused(context, :public, %{candidate | resources: List.duplicate(one, 65)})
      assert_refused(context, :direct, %{candidate | resources: List.duplicate(one, 65)})
      supplied = %{candidate | resources: List.duplicate(one, 64)}
      assert {:ok, next} = Generation.activate(context.store, context.generation, supplied, 1_000)
      assert {:ok, ^next, ^supplied} = Generation.snapshot(context.store)
      assert [hold] = Provider.status(context.candidate_owner).holds |> Map.values()
      assert hold.pin.handles == [one]
    end)
  end

  test "resource ETF 65536 is accepted and 65537 is refused without candidate custody", context do
    with_request_cleanup(context, fn ->
      base = Map.put(handle(context.candidate_owner, :sized), :payload, <<>>)
      padding = 65_536 - :erlang.external_size([base])
      exact = %{base | payload: :binary.copy(<<0>>, padding)}
      over = %{exact | payload: exact.payload <> <<0>>}
      assert :erlang.external_size([exact]) == 65_536
      assert :erlang.external_size([over]) == 65_537
      assert {:ok, [^exact]} = Resources.validate([exact])
      assert {:error, :invalid_endpoint_resources} = Resources.validate([over])
      assert {:ok, candidate} = Router.compile(routes([exact]))
      assert_refused(context, :public, %{candidate | resources: [over]})
      assert_refused(context, :direct, %{candidate | resources: [over]})
      assert {:ok, next} = Generation.activate(context.store, context.generation, candidate, 1_000)
      assert {:ok, ^next, ^candidate} = Generation.snapshot(context.store)
    end)
  end

  test "70 routes sharing one resource keep canonical union and do not reinitialize on publication", context do
    with_request_cleanup(context, fn ->
      one = handle(context.candidate_owner, :shared)
      marker = make_ref()
      config = %{handles: [one], observer: context.candidate_owner, init_marker: marker}
      assert {:ok, candidate} = Router.compile(List.duplicate(%{target: {Endpoint, config}}, 70))
      assert candidate.resources == [one]
      initialized = List.duplicate(marker, 70)
      assert Provider.status(context.candidate_owner).initialized == initialized
      assert {:ok, next} = Generation.activate(context.store, context.generation, candidate, 1_000)
      assert {:ok, ^next, ^candidate} = Generation.snapshot(context.store)
      assert Provider.status(context.candidate_owner).initialized == initialized
    end)
  end

  for path <- [:public, :direct, :initial_router] do
    test "#{path} preserves a once-initialized compiled endpoint", context do
      with_request_cleanup(context, fn ->
        marker = make_ref()
        config = %{handles: [], observer: context.candidate_owner, init_marker: marker}
        assert {:ok, candidate} = Router.compile([%{target: {Endpoint, config}}])
        assert Provider.status(context.candidate_owner).initialized == [marker]
        assert {:ok, _} = publish(context, unquote(path), candidate)
        assert Provider.status(context.candidate_owner).initialized == [marker]
      end)
    end
  end

  test "prepare initializes input endpoints once and activation reads compiled config", context do
    with_request_cleanup(context, fn ->
      marker = make_ref()
      config = %{handles: [], observer: context.candidate_owner, init_marker: marker}
      assert {:ok, candidate} = Generation.prepare(context.store, [%{target: {Endpoint, config}}], 1_000)
      assert Provider.status(context.candidate_owner).initialized == [marker]
      assert {:ok, _} = Generation.activate(context.store, context.generation, candidate, 1_000)
      assert Provider.status(context.candidate_owner).initialized == [marker]
    end)
  end

  test "legacy callbacks and an empty static Router without generation reference remain supported", context do
    with_request_cleanup(context, fn ->
      assert {:ok, candidate} = Router.compile([
        %{target: {Legacy, :unrestricted_config}},
        %{target: {Router, %Router{}}}
      ])
      assert candidate.resources == []
      assert {:ok, next} = Generation.activate(context.store, context.generation, candidate, 1_000)
      assert {:ok, ^next, ^candidate} = Generation.snapshot(context.store)
      assert Provider.status(context.candidate_owner).events == []
    end)
  end

  test "dynamic Generation targets contribute no resources and validation does not traverse stopped Stores", context do
    with_request_cleanup(context, fn ->
      # Each independent captured Store is locally bounded; their union exceeds 64.
      stores = for id <- [:first, :second] do
        handles = for number <- 1..40, do: handle(context.candidate_owner, {id, number})
        {:ok, router} = Router.compile(routes(handles))
        start_supervised!({Generation, router: router}, id: id)
      end

      assert {:ok, candidate} = Router.compile(Enum.map(stores, &%{target: {Generation, &1}}))
      assert candidate.resources == []
      for id <- [:first, :second], do: stop_supervised!(id)
      for store <- stores, do: refute(Process.alive?(store))
      before = Provider.status(context.candidate_owner)
      assert before.holds == %{}
      assert {:ok, next} = Generation.activate(context.store, context.generation, candidate, 1_000)
      assert {:ok, ^next, ^candidate} = Generation.snapshot(context.store)
      assert Provider.status(context.candidate_owner) == before
    end)
  end

  test "matching unavailable resources reach provider acquisition rather than consistency rejection", context do
    with_request_cleanup(context, fn ->
      unavailable = Map.put(handle(context.candidate_owner, :retired), :unavailable, true)
      assert {:ok, candidate} = Router.compile(routes([unavailable]))
      old_before = Provider.status(context.old_owner)
      assert {:error, :test_resource_unavailable} =
               Generation.activate(context.store, context.generation, candidate, 1_000)
      assert {:ok, generation, original} = Generation.snapshot(context.store)
      assert generation == context.generation
      assert original === context.old_router
      assert Provider.status(context.old_owner) == old_before
      status = Provider.status(context.candidate_owner)
      assert status.holds == %{}
      assert [pin_event, cancel_event] = status.events
      assert {:pin, [^unavailable], holder, :baseline, operation} = pin_event
      assert cancel_event == {:cancel, operation, holder}
      assert holder == context.store
    end)
  end

  test "existing generation hook errors retain precedence over recollection errors", context do
    with_request_cleanup(context, fn ->
      {:ok, empty} = Router.compile([])
      denied = %{empty | routes: [compiled_route(Denied, :config)]}
      for path <- [:public, :direct] do
        before = statuses(context)
        assert {:error, :test_generation_denied} = publish(context, path, denied)
        assert statuses(context) == before
        assert {:ok, generation, original} = Generation.snapshot(context.store)
        assert generation == context.generation
        assert original === context.old_router
      end
    end)
  end

  defp routes(handles), do: [%{target: {Endpoint, %{handles: handles}}}]

  defp compiled_route(module, config),
    do: %{host: :any, path: :any, methods: :any, target: {module, config}}

  defp handle(owner, id),
    do: %{provider: Provider, owner: owner, owner_epoch: make_ref(), id: id}

  defp statuses(context),
    do: {Provider.status(context.old_owner), Provider.status(context.candidate_owner)}

  defp assert_refused(context, path, forged) do
    before = statuses(context)
    assert {:error, :invalid_endpoint_resources} = publish(context, path, forged)
    assert {:ok, generation, router} = Generation.snapshot(context.store)
    assert generation == context.generation
    assert router === context.old_router
    assert statuses(context) == before
  end

  defp publish(context, :public, candidate),
    do: Generation.activate(context.store, context.generation, candidate, 1_000)

  defp publish(context, :direct, candidate),
    do: GenServer.call(context.store, {:activate, context.generation, candidate, Lifecycle.deadline(1_000)}, 2_000)

  defp publish(context, :prepare, candidate),
    do: Generation.prepare(context.store, [%{target: {Router, candidate}}], 1_000)

  defp publish(_context, :initial_router, candidate),
    do: initial_start(router: candidate)

  defp publish(_context, :initial_routes, candidate),
    do: initial_start(routes: [%{target: {Router, candidate}}])

  defp initial_start(options) do
    result = Generation.start_link(options)

    # Preserve cleanup even during intended RED when a forged initial router starts.
    if match?({:ok, _}, result) do
      {:ok, store} = result
      GenServer.stop(store, :normal, 1_000)
    end

    result
  end

  defp with_request_cleanup(context, fun) do
    try do
      fun.()
    after
      [request] = context.request_pins
      assert :ok = Resources.release(context.request_pins)
      status = Provider.status(context.old_owner)
      refute Map.has_key?(status.holds, request.ref)
      assert {:release, request, self()} in status.events
    end
  end
end
