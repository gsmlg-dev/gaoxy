defmodule Gaoxy.HTTP.HTTP2StartupPeerCloseTest do
  use ExUnit.Case, async: true
  alias Gaoxy.Admission
  alias Gaoxy.HTTP.Connection

  defmodule Endpoint do
    def init(owner), do: {:ok, owner}
    def call(_, _), do: raise("startup must not dispatch a request")
  end

  defmodule Transport do
    def secure?, do: true
    def negotiated_protocol(_), do: {:ok, "h2"}

    def peername(agent) do
      Agent.get(agent, fn state ->
        if state.failed, do: state.peer_after, else: {:ok, {{127, 0, 0, 1}, 1234}}
      end)
    end

    def sockname(_), do: {:ok, {{127, 0, 0, 1}, 443}}
    def connection_information(_), do: {:ok, [protocol: :"tlsv1.3"]}
    def peercert(_), do: {:error, :no_peercert}

    def setopts(agent, options) do
      Agent.get_and_update(agent, fn state ->
        send(state.owner, {:receive_options, options})
        {{:error, state.error}, %{state | failed: true}}
      end)
    end
  end

  for reason <- [:closed, :einval, :enotconn], wrapped <- [false, true] do
    test "#{if wrapped, do: "SSL-wrapped", else: "bare"} #{reason} closes a disconnected peer normally" do
      reason = unquote(reason)
      wrapped = unquote(wrapped)
      error = if wrapped, do: wrapped(reason), else: reason
      {socket, context, hook} = startup(error, {:error, reason})
      gate = context.gate

      assert {:stop, {:shutdown, :local_closed}, {_, %{gate: ^gate}}} =
               Connection.handle_continue(:handle_connection, {socket, context})

      assert_receive {:receive_options, [recbuf: 16_384, buffer: 16_384]}
      assert_empty(context.gate, hook)
    end
  end

  test "a live peer retains the exact bare or wrapped receive-option failure" do
    for reason <- [:closed, :einval, :enotconn], wrapped <- [false, true] do
      error = if wrapped, do: wrapped(reason), else: reason
      {socket, context, hook} = startup(error, {:ok, {{127, 0, 0, 1}, 1234}})
      gate = context.gate

      assert {:stop, ^error, {_, %{gate: ^gate}}} =
               Connection.handle_continue(:handle_connection, {socket, context})

      assert_empty(context.gate, hook)
    end
  end

  test "invalid options and unrelated errors keep their original error disposition" do
    for error <- [
          {:options, {:socket_options, [buffer: -1], :einval}},
          {:options, {:socket_options, [buffer: :invalid]}},
          wrapped(:eio),
          :eio
        ] do
      {socket, context, hook} = startup(error, {:ok, {{127, 0, 0, 1}, 1234}})
      gate = context.gate

      assert {:stop, ^error, {_, %{gate: ^gate}}} =
               Connection.handle_continue(:handle_connection, {socket, context})

      assert_empty(context.gate, hook)
    end
  end

  defp wrapped(reason),
    do: {:options, {:socket_options, [buffer: 16_384, recbuf: 16_384], reason}}

  defp startup(error, peer_after) do
    owner = self()
    hook = make_ref()

    {:ok, spec} =
      Gaoxy.HTTP.service_spec(
        endpoint: {Endpoint, owner},
        protocols: [:http2],
        h2c: :prior_knowledge
      )

    gate =
      start_supervised!({Admission, {spec.limits, %{instance: hook}}}, id: make_ref())

    :ok =
      :sys.install(
        gate,
        {hook,
         fn previous, event, _ ->
           case event do
             {:in, {:"$gen_call", _, {:acquire, _, _}}} -> send(owner, {:acquired, hook})
             _ -> :ok
           end

           previous
         end, nil}
      )

    agent =
      start_supervised!(
        {Agent, fn -> %{owner: owner, error: error, peer_after: peer_after, failed: false} end},
        id: make_ref()
      )

    socket = %Hell.Socket{
      socket: agent,
      transport_module: Transport,
      read_timeout: 3000,
      handshake_timeout: 3000,
      silent_terminate_on_error: false,
      span: Hell.Telemetry.start_span(:connection, %{}, %{handler: Connection})
    }

    {socket, %{spec: spec, gate: gate}, hook}
  end

  defp assert_empty(gate, hook) do
    assert %{active: 0, retained_bytes: 0, cleanup_pending: 0} = Admission.status(gate)
    refute_received {:acquired, ^hook}
  end
end
