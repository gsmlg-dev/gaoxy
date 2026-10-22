defmodule Gaoxy.HTTP.GatewayGenerationTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.{Generation, Router}
  alias Gaoxy.Lifecycle

  defmodule Target do
    def init(body), do: {:ok, body}
    def call(exchange, body), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], body)
  end

  test "accepted declaration, router and operation receipt commit together and survive epochs" do
    store = start_supervised!({Generation, []})
    epoch = make_ref()
    routes = [%{target: {Target, "accepted"}}]
    assert :ok = Generation.begin_epoch(store, epoch)
    operation = make_ref()
    deadline = Lifecycle.deadline(1000)
    assert {:ok, :admitted} = Generation.admit(store, operation, 0, routes, deadline)
    assert {:ok, router} = Router.compile(routes)

    assert {:ok, %{revision: 1, generation: generation}} =
             Generation.commit(store, operation, 0, epoch, router, routes, deadline)

    assert {:ok, %{revision: 1, declaration: ^routes, epoch: ^epoch}} = Generation.accepted(store)
    assert {:ok, ^generation, ^router} = Generation.snapshot(store)

    assert {:ok, %{status: :committed, revision: 1, generation: ^generation}} =
             Generation.operation_status(store, operation)

    assert {:ok, %{status: :committed}} = Generation.admit(store, operation, 0, routes, deadline)
    assert {:error, :operation_conflict} = Generation.admit(store, operation, 1, [], deadline)

    next_epoch = make_ref()
    assert :ok = Generation.begin_epoch(store, next_epoch)

    assert {:ok, %{revision: 1, declaration: ^routes, epoch: ^next_epoch}} =
             Generation.accepted(store)
  end

  test "stale epoch, expired candidate and draining barrier cannot accept a declaration" do
    store = start_supervised!({Generation, []})
    old_epoch = make_ref()
    assert :ok = Generation.begin_epoch(store, old_epoch)
    operation = make_ref()
    deadline = Lifecycle.deadline(1000)
    routes = [%{target: {Target, "late"}}]
    assert {:ok, :admitted} = Generation.admit(store, operation, 0, routes, deadline)
    assert {:ok, router} = Router.compile(routes)
    assert :ok = Generation.begin_epoch(store, make_ref())

    assert {:error, :stale_runtime_epoch} =
             Generation.commit(store, operation, 0, old_epoch, router, routes, deadline)

    assert {:ok, %{revision: 0, declaration: nil}} = Generation.accepted(store)

    assert {:ok, %{epoch: epoch}} = Generation.accepted(store)
    expired = make_ref()
    assert {:ok, :admitted} = Generation.admit(store, expired, 0, routes, deadline)

    assert {:error, :activation_timeout} =
             Generation.commit(store, expired, 0, epoch, router, routes, Lifecycle.deadline(0))

    draining = make_ref()
    assert {:ok, :admitted} = Generation.admit(store, draining, 0, routes, deadline)
    assert :ok = Generation.drain(store, deadline)

    assert {:error, :gateway_draining} =
             Generation.commit(store, draining, 0, epoch, router, routes, deadline)

    assert {:error, :gateway_draining} = Generation.begin_epoch(store, make_ref())
    assert {:ok, %{revision: 0, declaration: nil, phase: :draining}} = Generation.accepted(store)
  end

  test "a discarded commit reply retains its receipt through drain and bounded receipt eviction" do
    store = start_supervised!({Generation, []})
    epoch = make_ref()
    assert :ok = Generation.begin_epoch(store, epoch)
    deadline = Lifecycle.deadline(1000)
    routes = [%{target: {Target, "accepted"}}]
    operation = make_ref()
    assert {:ok, :admitted} = Generation.admit(store, operation, 0, routes, deadline)
    assert {:ok, router} = Router.compile(routes)

    request =
      :gen_server.send_request(store, {:commit, operation, 0, epoch, router, routes, deadline})

    # Same-sender ordering observes the transition before intentionally dropping
    # its reply alias; status remains the authority for the lost reply.
    assert {:ok, %{status: :committed, revision: 1}} =
             Generation.operation_status(store, operation)

    _ = :gen_server.receive_response(request, 0)
    next = make_ref()
    assert {:ok, :admitted} = Generation.admit(store, next, 1, routes, deadline)
    assert :ok = Generation.reject(store, next, :candidate_rejected)
    assert {:ok, %{status: :unknown}} = Generation.operation_status(store, operation)
    assert :ok = Generation.drain(store, deadline)

    assert {:ok, %{status: :rejected, reason: :candidate_rejected}} =
             Generation.operation_status(store, next)

    assert {:ok, %{revision: 1, declaration: ^routes, phase: :draining}} =
             Generation.accepted(store)
  end
end
