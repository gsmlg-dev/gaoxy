defmodule Gaoxy.QUICContextTest do
  use ExUnit.Case, async: true
  alias Gaoxy.{Admission, QUICBridge}

  defmodule Handler do
    def init(connection, _, observer) do
      send(observer, {:quic_context, connection})
      {:ok, %{}}
    end
  end

  test "QUIC callback receives runtime owners separately from telemetry identity" do
    limits = %{max_active: 4, max_bytes: 1_048_576, max_state: 65_536, callback_timeout: 5_000}
    scope = %{service: :listener, instance: make_ref(), generation: make_ref()}
    gate = start_supervised!({Admission, {limits, Map.put(scope, :service_pid, self())}})

    context = %{
      spec: %{handler: Handler, handler_options: self(), limits: limits},
      gate: gate,
      scope: scope,
      service: self(),
      instance: self()
    }

    assert {:ok, state} = QUICBridge.init(:opaque_handle, %{}, context)
    assert_receive {:quic_context, connection}
    assert Map.get(connection, :service) == self()
    assert Map.get(connection, :instance) == self()
    assert connection.scope == scope
    assert state.connection == connection
  end

  test "QUIC keepalive rejects unbounded and duplicate operation options before backend access" do
    connection = %Gaoxy.QUIC.Connection{
      handle: :unused,
      gate: self(),
      lease: make_ref(),
      limits: %{callback_timeout: 50},
      scope: %{}
    }

    for options <- [
          [timeout: :infinity],
          [timeout: 0],
          [timeout: 51],
          [deadline: :infinity],
          [timeout: 1, timeout: 2],
          [unknown: true]
        ] do
      assert {:error, :invalid_operation_options} = Gaoxy.QUIC.ping(connection, options)
    end
  end
end
