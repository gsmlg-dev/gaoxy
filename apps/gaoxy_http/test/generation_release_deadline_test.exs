defmodule Gaoxy.HTTP.GenerationReleaseDeadlineTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Generation, Router}

  defmodule Provider do
    use GenServer
    @behaviour Gaoxy.HTTP.Resources
    def start_link(parent), do: GenServer.start_link(__MODULE__, parent)
    def init(parent), do: {:ok, %{parent: parent, pins: %{}, waiting: nil}}

    def pin_many([handle], holder, kind, operation, deadline),
      do: Gaoxy.Lifecycle.call(handle.owner, {:pin, holder, kind, operation}, deadline)

    def release(pin), do: GenServer.call(pin.owner, {:release, pin}, 100)
    def cancel(owner, operation), do: send(owner, {:cancel, self(), operation}) && :ok

    def handle_call({:pin, holder, kind, operation}, _, state) do
      ref = make_ref()
      pin = %{provider: __MODULE__, owner: self(), ref: ref, operation: operation, kind: kind}
      {:reply, {:ok, pin}, %{state | pins: Map.put(state.pins, ref, holder)}}
    end

    def handle_call({:release, pin}, {holder, _} = from, state) do
      if state.pins[pin.ref] == holder do
        send(state.parent, {:resource_release_waiting, self()})
        {:noreply, %{state | waiting: {from, pin.ref}}}
      else
        {:reply, :ok, state}
      end
    end

    def handle_call(:count, _, state), do: {:reply, map_size(state.pins), state}

    def handle_info(:release, %{waiting: {from, ref}} = state) do
      GenServer.reply(from, :ok)
      {:noreply, %{state | pins: Map.delete(state.pins, ref), waiting: nil}}
    end

    def handle_info(_, state), do: {:noreply, state}
  end

  defmodule Endpoint do
    def init(handle), do: {:ok, handle}
    def resources(handle), do: [handle]
    def call(exchange, _), do: {:ok, exchange}
  end

  test "committed activation replies within its own deadline before old metadata release" do
    provider = start_supervised!({Provider, self()})
    handle = %{provider: Provider, owner: provider, owner_epoch: make_ref()}
    assert {:ok, router} = Router.compile([%{target: {Endpoint, handle}}])
    store = start_supervised!({Generation, router: router})
    assert {:ok, original, ^router} = Generation.snapshot(store)
    assert {:ok, replacement} = Router.compile([])
    task = Task.async(fn -> Generation.activate(store, original, replacement, 50) end)
    assert_receive {:resource_release_waiting, ^provider}, 1_000

    try do
      assert {:ok, generation} = Task.await(task, 1_000)
      assert generation == replacement.generation
    after
      send(provider, :release)
    end

    assert {:ok, _, ^replacement} = Generation.snapshot(store)
    assert GenServer.call(provider, :count) == 0
  end
end
