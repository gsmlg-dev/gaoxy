defmodule Gaoxy.HTTP.GenerationResourcesTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Generation, Router}

  defmodule Prepared do
    def init(parent) do
      send(parent, {:initialized, self()})
      {:ok, parent}
    end

    def call(exchange, _), do: {:ok, exchange}
  end

  defmodule Provider do
    use GenServer
    @behaviour Gaoxy.HTTP.Resources
    def start_link(parent), do: GenServer.start_link(__MODULE__, parent)
    def init(parent), do: {:ok, %{parent: parent, pins: %{}, release_failure: false}}

    def pin_many([handle | _] = handles, holder, kind, operation, deadline) do
      result =
        Gaoxy.Lifecycle.call(handle.owner, {:pin, handles, holder, kind, operation}, deadline)

      if Map.get(handle, :delay, false) and match?({:ok, _}, result) do
        send(handle.parent, {:resource_acquired, self()})

        receive do
          :return_pin -> :ok
        after
          1_000 -> :ok
        end
      end

      result
    end

    def release(pin), do: GenServer.call(pin.owner, {:release, pin})

    def cancel(owner, operation),
      do:
        (
          send(owner, {:cancel, self(), operation})
          :ok
        )

    def handle_call({:pin, handles, holder, kind, operation}, {caller, _}, state) do
      if Enum.any?(handles, &Map.get(&1, :reject, false)) do
        {:reply, {:error, :provider_rejected}, state}
      else
        ref = make_ref()

        pin = %{
          provider: __MODULE__,
          owner: self(),
          operation: operation,
          ref: ref,
          handles: handles,
          kind: kind
        }

        record = %{
          holder: holder,
          acquirer: caller,
          operation: operation,
          monitor: Process.monitor(holder)
        }

        {:reply, {:ok, pin}, %{state | pins: Map.put(state.pins, ref, record)}}
      end
    end

    def handle_call({:release, _}, _, %{release_failure: true} = state),
      do: {:reply, {:error, :release_pending}, state}

    def handle_call({:release, pin}, {caller, _}, state) do
      case state.pins[pin.ref] do
        nil -> {:reply, :ok, state}
        %{holder: ^caller} -> {:reply, :ok, remove(state, pin.ref)}
        _ -> {:reply, {:error, :unauthorized}, state}
      end
    end

    def handle_call(:count, _, state), do: {:reply, map_size(state.pins), state}

    def handle_call({:release_failure, value}, _, state),
      do: {:reply, :ok, %{state | release_failure: value}}

    def handle_info({:cancel, caller, operation}, state) do
      refs =
        for {ref, pin} <- state.pins,
            pin.acquirer == caller and pin.operation == operation,
            do: ref

      {:noreply, Enum.reduce(refs, state, &remove(&2, &1))}
    end

    def handle_info({:DOWN, monitor, :process, _, _}, state) do
      refs = for {ref, pin} <- state.pins, pin.monitor == monitor, do: ref
      {:noreply, Enum.reduce(refs, state, &remove(&2, &1))}
    end

    defp remove(state, ref) do
      Process.demonitor(state.pins[ref].monitor, [:flush])
      %{state | pins: Map.delete(state.pins, ref)}
    end
  end

  defmodule ResourceEndpoint do
    def init(handles), do: {:ok, handles}
    def resources(handles), do: handles
    def call(exchange, _), do: {:ok, exchange}
  end

  test "a compiled initial router and Registry name activate without endpoint recompilation" do
    registry = start_supervised!({Registry, keys: :unique, name: __MODULE__.Registry})
    assert is_pid(registry)
    name = {:via, Registry, {__MODULE__.Registry, make_ref()}}
    assert {:ok, router} = Router.compile([%{target: {Prepared, self()}}])
    assert_receive {:initialized, _}
    assert {:ok, store} = Generation.start_link(router: router, name: name)
    on_exit(fn -> if Process.alive?(store), do: GenServer.stop(store) end)
    assert {:ok, _, ^router} = Generation.snapshot(store)
    refute_receive {:initialized, _}, 25
    assert {:ok, %{store: ^store}} = Generation.init(name)

    assert {:error, :invalid_generation_options} =
             Generation.start_link(router: router, routes: [])

    assert {:error, :invalid_generation_options} = Generation.start_link(name: "not-an-otp-name")
  end

  test "router resource sidecars are bounded and snapshot-for-request returns pins" do
    assert Map.has_key?(%Router{}, :resources)
    store = start_supervised!({Generation, []})
    deadline = Gaoxy.Lifecycle.deadline(1_000)

    assert {:ok, _, %Router{routes: []}, []} =
             apply(Generation, :snapshot_for_request, [store, self(), deadline])
  end

  test "static nested resources deduplicate across routes and malformed sidecars return errors" do
    provider = start_supervised!({Provider, self()})
    handle = handle(provider)
    routes = List.duplicate(%{target: {ResourceEndpoint, [handle]}}, 70)
    assert {:ok, router} = Router.compile(routes)
    assert router.resources == [handle]
    assert {:ok, nested} = Router.compile([%{target: {Router, router}}])
    assert nested.resources == [handle]

    assert {:error, :invalid_endpoint_resources} =
             Router.compile([%{target: {ResourceEndpoint, :malformed}}])

    assert {:error, :invalid_endpoint_resources} =
             Router.compile([%{target: {ResourceEndpoint, List.duplicate(handle, 65)}}])

    store = start_supervised!({Generation, router: router})
    assert {:ok, dynamic} = Router.compile([%{target: {Generation, store}}])
    assert dynamic.resources == []
  end

  test "failed candidate acquisition preserves the old router and operation cancellation rolls back earlier batches" do
    providers = for id <- [:one, :two], do: start_supervised!({Provider, self()}, id: id)
    [first, second] = Enum.sort(providers)
    old = start_supervised!({Generation, []})
    assert {:ok, generation, router} = Generation.snapshot(old)

    assert {:ok, candidate} =
             Router.compile([
               %{
                 target:
                   {ResourceEndpoint, [handle(first), Map.put(handle(second), :reject, true)]}
               }
             ])

    assert {:error, :provider_rejected} = Generation.activate(old, generation, candidate)
    assert {:ok, ^generation, ^router} = Generation.snapshot(old)

    for provider <- providers do
      assert GenServer.call(provider, :count) == 0
    end
  end

  test "a late provider result cannot publish after activation deadline and its baseline is released" do
    provider = start_supervised!({Provider, self()})
    store = start_supervised!({Generation, []})
    assert {:ok, generation, router} = Generation.snapshot(store)
    delayed = Map.merge(handle(provider), %{delay: true, parent: self()})
    assert {:ok, candidate} = Router.compile([%{target: {ResourceEndpoint, [delayed]}}])
    task = Task.async(fn -> Generation.activate(store, generation, candidate, 30) end)
    assert_receive {:resource_acquired, ^store}, 1_000
    assert {:error, :generation_unavailable} = Task.await(task, 1_000)
    send(store, :return_pin)
    assert {:ok, ^generation, ^router} = Generation.snapshot(store)
    eventually(fn -> GenServer.call(provider, :count) == 0 end)
  end

  @tag :retired_pending
  test "post-publication release failure retains pins and reconciles while old request pins protect snapshots" do
    provider = start_supervised!({Provider, self()})
    assert {:ok, router} = Router.compile([%{target: {ResourceEndpoint, [handle(provider)]}}])
    store = start_supervised!({Generation, router: router})

    assert {:ok, original, ^router, request} =
             Generation.snapshot_for_request(store, self(), Gaoxy.Lifecycle.deadline(1_000))

    assert GenServer.call(provider, :count) == 2
    :ok = GenServer.call(provider, {:release_failure, true})
    assert {:ok, replacement} = Router.compile([])
    assert {:ok, _} = Generation.activate(store, original, replacement)
    assert {:ok, current, ^replacement} = Generation.snapshot(store)
    assert GenServer.call(provider, :count) == 2
    assert {:ok, next} = Router.compile([])
    assert {:error, :resource_release_pending} = Generation.activate(store, current, next)
    assert {:ok, ^current, ^replacement} = Generation.snapshot(store)
    :ok = GenServer.call(provider, {:release_failure, false})
    eventually(fn -> GenServer.call(provider, :count) == 1 end)
    assert {:ok, _} = Generation.activate(store, current, next)
    assert :ok = Gaoxy.HTTP.Resources.release(request)
    assert GenServer.call(provider, :count) == 0
  end

  defp handle(provider), do: %{provider: Provider, owner: provider, owner_epoch: make_ref()}

  defp eventually(fun, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(1_000)

    if fun.(),
      do: :ok,
      else:
        (
          assert Gaoxy.Lifecycle.remaining(deadline) > 0

          receive do
          after
            2 -> eventually(fun, deadline)
          end
        )
  end
end
