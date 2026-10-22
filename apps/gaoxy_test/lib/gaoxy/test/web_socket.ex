defmodule Gaoxy.Test.WebSocket do
  @moduledoc """
  H1 WebSock echo sessions with journal events and controlled send/close.

  `upgrade/2` defaults to echoing text and binary messages. Set `echo: false`
  for receive observation only. An established session PID is exposed by the
  `:websocket_established` journal event; use `send/3` or `close/3` on that PID.
  H2/H3 extended CONNECT is deliberately unsupported by this helper.
  """
  @behaviour WebSock
  import Kernel, except: [send: 2]

  def upgrade(conn, options \\ []) do
    unless Plug.Conn.get_http_protocol(conn) in [:"HTTP/1.0", :"HTTP/1.1"],
      do: raise(ArgumentError, "fixture WebSocket helper requires HTTP/1")

    context = Map.fetch!(conn.private, :gaoxy_test)
    echo = Keyword.get(options, :echo, true)
    unless is_boolean(echo), do: raise(ArgumentError, "echo must be boolean")
    state = %{context: context, echo: echo, peer_closed: false}
    wire_options = Keyword.drop(options, [:echo])
    Plug.Conn.upgrade_adapter(conn, :websocket, {__MODULE__, state, wire_options})
  end

  def send(session, opcode, payload) when is_pid(session) and opcode in [:text, :binary] do
    Kernel.send(session, {:gaoxy_test_ws_send, opcode, IO.iodata_to_binary(payload)})
    :ok
  end

  def close(session, code \\ 1000, reason \\ "") when is_pid(session) do
    unless valid_code?(code) and is_binary(reason) and String.valid?(reason) and
             byte_size(reason) <= 123,
           do: raise(ArgumentError, "invalid WebSocket close code or reason")

    Kernel.send(session, {:gaoxy_test_ws_close, code, reason})
    :ok
  end

  @impl true
  def init(state) do
    %{instance: instance, request_id: request_id} = state.context
    :ok = Gaoxy.Test.Instance.establish(instance, request_id, self())
    event(state, %{type: :websocket_established, session: self()})
    {:ok, state}
  end

  @impl true
  def handle_in({payload, options}, state) do
    opcode = Keyword.fetch!(options, :opcode)
    event(state, %{type: :websocket_received, opcode: opcode, payload: payload})

    if state.echo do
      event(state, %{type: :websocket_sent, opcode: opcode, payload: payload})
      {:push, {opcode, payload}, state}
    else
      {:ok, state}
    end
  end

  @impl true
  def handle_info({:gaoxy_test_ws_send, opcode, payload}, state) do
    event(state, %{type: :websocket_sent, opcode: opcode, payload: payload})
    {:push, {opcode, payload}, state}
  end

  def handle_info({:gaoxy_test_ws_close, code, reason}, state),
    do: {:stop, :normal, {code, reason}, state}

  def handle_info({:gaoxy_test_cancel, reason}, state) do
    event(state, %{type: :session_cancelled, reason: reason})
    {:stop, :normal, {1001, "fixture closed"}, state}
  end

  def handle_info(:gaoxy_test_cancel, state),
    do: handle_info({:gaoxy_test_cancel, :shutdown}, state)

  def handle_info(_, state), do: {:ok, state}

  def gaoxy_close(_detail, state), do: {:ok, %{state | peer_closed: true}}

  @impl true
  def terminate(reason, state) do
    unless reason in [:normal, :shutdown] or (reason == :remote and state.peer_closed) do
      event(state, %{type: :session_failure, kind: :exit, reason: reason, stacktrace: []})
    end

    event(state, %{type: :websocket_closed, reason: reason})
    :ok
  end

  defp event(state, event) do
    %{instance: instance, request_id: request_id} = state.context
    Gaoxy.Test.Instance.event(instance, request_id, event)
  end

  defp valid_code?(code),
    do:
      code in [1000, 1001, 1002, 1003, 1007, 1008, 1009, 1010, 1011, 1012, 1013, 1014] or
        code in 3000..4999
end
