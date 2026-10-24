defmodule Gaoxy.HTTP.HTTP3.LifecycleTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.HTTP3.{Connection, Options}

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(_, _), do: raise("unexpected application execution")
  end

  defp state do
    {:ok, spec} =
      Options.normalize(
        endpoint: {Endpoint, %{profile: :minimal}},
        tls: %{certfile: "fixture.pem", keyfile: "key.pem"}
      )

    opts = %{spec.handler_options | endpoint: {Gaoxy.HTTP3Fixture.Endpoint, %{profile: :minimal}}}
    {:ok, state} = Connection.init(%{gate: nil, limits: spec.limits}, %{alpn: "h3"}, opts)
    state
  end

  test "closed notification releases retained parser and output ownership" do
    state = state()
    {:ok, state} = Connection.handle_event({:stream_open, make_ref(), :bidi}, state)
    assert {:stop, :normal, next} = Connection.handle_event({:closed, :peer_close}, state)
    assert next.streams == %{}
    assert next.protocol.streams == %{}
    assert next.pending == %{}
    assert next.control == nil
  end

  test "termination after closure does not attempt further capability I/O" do
    {:stop, :normal, state} = Connection.handle_event({:closed, :peer_close}, state())
    assert :ok = Connection.terminate(:normal, state)
  end

  test "peer STOP preserves an existing cancellation and sibling ownership" do
    state = state()

    state =
      Enum.reduce(1..8, state, fn _, acc ->
        {:ok, next} = Connection.handle_event({:stream_open, make_ref(), :bidi}, acc)
        next
      end)

    key = make_ref()
    {:ok, state} = Connection.handle_event({:stream_open, key, :bidi}, state)
    assert state.streams[key].cancel == [{:reset, 0x107}, {:stop, 0x107}]
    assert {:ok, ^state} = Connection.handle_event({:stopped, key, 0x10C}, state)
  end

  test "peer STOP cannot replay an admitted reset or replace an uncertain cleanup" do
    key = make_ref()
    {:ok, state} = Connection.handle_event({:stream_open, key, :bidi}, state())
    {:ok, state} = Connection.handle_event({:stopped, key, 0x10E}, state)
    assert state.streams[key].cancel == [{:reset, 0x10E}, {:stop, 0x10E}]

    # RESET has been admitted; STOP has an unresolved public operation reference.
    entry = %{state.streams[key] | cancel: [{:stop, 0x10E}]}
    reference = make_ref()

    state = %{
      state
      | streams: Map.put(state.streams, key, entry),
        pending: %{{key, :stop} => {reference, entry.output_deadline}}
    }

    assert {:ok, ^state} = Connection.handle_event({:stopped, key, 0x10C}, state)
  end

  test "shared endpoint ownership is initialized without executing its callback" do
    {:ok, spec} =
      Options.normalize(
        endpoint: {Endpoint, %{}},
        tls: %{certfile: "fixture.pem", keyfile: "key.pem"}
      )

    assert {:ok, state} =
             Connection.init(
               %{gate: nil, limits: spec.limits},
               %{alpn: "h3"},
               spec.handler_options
             )

    assert :ets.info(state.operations, :owner) == self()
    assert :ok = Connection.terminate(:test, state)
    assert :ets.info(state.operations) == :undefined
  end

  test "empty ordinary connection idle is suspended by request ownership and restored after cleanup" do
    now = Gaoxy.Lifecycle.now()
    initial = state()
    timeout = initial.connection.limits.idle_timeout
    assert {:ok, idle} = Connection.persistence(initial, now)
    assert idle.idle_deadline == now + timeout
    assert {:error, :idle_timeout, _} = Connection.persistence(idle, now + timeout)

    request = %{kind: :bidi, mode: :websocket, cancel: []}
    active = %{idle | streams: %{ws: request}, metadata: %{idle_timeout: %{peer_ms: :infinity}}}
    assert {:ok, active} = Connection.persistence(active, now + timeout)
    assert active.idle_deadline == nil
    assert active.keepalive == nil

    closing = %{active | streams: %{ws: %{request | mode: :websocket_closing}}}
    assert {:ok, closing} = Connection.persistence(closing, now + 2 * timeout)
    assert closing.idle_deadline == nil
    assert {:ok, restored} = Connection.persistence(%{closing | streams: %{}}, now + 2 * timeout)
    assert restored.idle_deadline == now + 3 * timeout
  end

  test "finite peer idle creates a reusable cadence only for active websockets" do
    now = Gaoxy.Lifecycle.now()
    request = %{kind: :bidi, mode: :websocket, cancel: []}
    initial = %{state() | streams: %{ws: request}, metadata: %{idle_timeout: %{peer_ms: 300}}}
    assert {:ok, active} = Connection.persistence(initial, now)
    assert active.keepalive == %{interval: 100, next: now + 100, deadline: nil}
    assert {:ok, ^active} = Connection.persistence(active, now + 50)
    assert {:ok, closed} = Connection.persistence(%{active | streams: %{}}, now + 60)
    assert closed.keepalive == nil

    ordinary = %{initial | streams: %{http: %{request | mode: nil}}}
    assert {:ok, ordinary} = Connection.persistence(ordinary, now)
    assert ordinary.keepalive == nil
    assert ordinary.idle_deadline == nil
  end
end
