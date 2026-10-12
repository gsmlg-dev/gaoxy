defmodule Gaoxy.HTTP.HTTP3.ConnectionTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.HTTP3.{Connection, Options}

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(_, _), do: raise("endpoint callbacks must not run inside the QUIC owner")
  end

  defp init do
    {:ok, spec} =
      Options.normalize(
        endpoint: {Endpoint, %{profile: :minimal}},
        tls: %{certfile: "fixture.pem", keyfile: "key.pem"}
      )

    connection = %{gate: self(), limits: spec.limits}

    options = %{
      spec.handler_options
      | endpoint: {Gaoxy.HTTP3Fixture.Endpoint, %{profile: :minimal, observer: self(), id: :main}}
    }

    Connection.init(
      connection,
      %{alpn: "h3", tls_complete: false, parameters_valid: false},
      options
    )
  end

  test "init and ticks do not perform I/O before authenticated readiness" do
    assert {:ok, state} = init()
    assert_receive {:http3_fixture_connection, :main, gate}
    assert gate == self()
    assert {:ok, ^state} = Connection.handle_event(:tick, state)
    assert {:ok, ^state} = Connection.handle_event(:writable, state)
  end

  test "pre-ready peer streams retain opaque keys without reading or assigning IDs" do
    {:ok, state} = init()
    key = make_ref()
    assert {:ok, state} = Connection.handle_event({:stream_open, key, :bidi}, state)
    assert Map.has_key?(state.protocol.streams, key)
    assert {:ok, ^state} = Connection.handle_event({:readable, key}, state)
  end

  test "late open event for the local control stream never enters the peer parser" do
    {:ok, state} = init()
    key = make_ref()
    state = %{state | control: key}
    assert {:ok, ^state} = Connection.handle_event({:stream_open, key, :uni}, state)
    refute Map.has_key?(state.protocol.streams, key)
  end

  test "response owners remain bounded after receive FIN frees parser slots" do
    {:ok, state} = init()

    state =
      Enum.reduce(1..8, state, fn _, acc ->
        {:ok, next} = Connection.handle_event({:stream_open, make_ref(), :bidi}, acc)
        next
      end)

    # Receive FIN releases pure parsers; blocked response owners retain their slots.
    state = %{state | protocol: %{state.protocol | streams: %{}}}
    key = make_ref()
    {:ok, next} = Connection.handle_event({:stream_open, key, :bidi}, state)
    refute Map.has_key?(next.protocol.streams, key)
    assert next.streams[key].cancel == [{:reset, 0x107}, {:stop, 0x107}]
    assert map_size(state.streams) == 8
  end

  test "wrong negotiated ALPN is rejected before control stream activation" do
    {:ok, state} = init()

    assert {:stop, :unsupported_http3_alpn, _} =
             Connection.handle_event(
               {:ready, %{alpn: "h2", tls_complete: true, parameters_valid: true}},
               state
             )
  end

  test "incomplete authentication cannot activate the owner" do
    {:ok, state} = init()

    assert {:stop, :http3_not_authenticated, _} =
             Connection.handle_event(
               {:ready, %{alpn: "h3", tls_complete: false, parameters_valid: false}},
               state
             )
  end

  test "arbitrary application events do not execute endpoints" do
    {:ok, state} = init()
    assert {:ok, ^state} = Connection.handle_event({:application_call, :payload}, state)
  end
end
