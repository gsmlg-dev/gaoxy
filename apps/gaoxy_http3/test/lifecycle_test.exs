defmodule Gaoxy.HTTP.HTTP3.LifecycleTest do
  use ExUnit.Case, async: true
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
end
