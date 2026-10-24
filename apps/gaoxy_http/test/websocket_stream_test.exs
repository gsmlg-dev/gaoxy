defmodule Gaoxy.HTTP.WebSocket.StreamTest do
  use ExUnit.Case, async: true
  import Bitwise
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Exchange, Request, WebSocket}
  alias Gaoxy.HTTP.WebSocket.Stream

  defmodule Handler do
    def init(owner) do
      send(owner, {:initialized, self()})
      {:ok, owner}
    end

    def handle_in({bytes, opcode: opcode}, owner), do: {:push, {opcode, bytes}, owner}
    def handle_info({:push, bytes}, owner), do: {:push, {:text, bytes}, owner}
    def handle_info({:stop, reason}, owner), do: {:stop, reason, owner}
    def handle_info({:stop, reason, detail}, owner), do: {:stop, reason, detail, owner}

    def handle_info({:stop, reason, detail, messages}, owner),
      do: {:stop, reason, detail, messages, owner}

    def handle_info(:stall, owner) do
      send(owner, {:callback_stalled, self()})

      receive do
        :return -> {:ok, owner}
      end
    end

    def handle_info(:raise, owner) do
      send(owner, {:callback_exception_pending, self()})

      receive do
        :raise -> raise "callback failed"
      end
    end

    def handle_info(message, owner) do
      send(owner, {:application_message, message})
      {:ok, owner}
    end

    def terminate(reason, owner), do: send(owner, {:terminated, reason})
  end

  defmodule ControlledTerminateHandler do
    defdelegate init(owner), to: Handler
    defdelegate handle_in(message, owner), to: Handler
    defdelegate handle_info(message, owner), to: Handler

    def terminate(reason, owner) do
      send(owner, {:terminate_pending, self(), reason})

      receive do
        :terminate_return -> :ok
        :terminate_raise -> raise "terminate failed"
      end
    end
  end

  defmodule Transport do
    def websocket_open(exchange, headers, deadline) do
      owner = elem(exchange.transport_state, 0)
      send(owner, {:opened, self(), headers, deadline, exchange})
      {:ok, %{exchange | deadline: deadline, response: :upgraded}}
    end

    def websocket_demand(exchange, credit, ref) do
      owner = elem(exchange.transport_state, 0)
      send(owner, {:demand, self(), credit, ref, Admission.status(exchange.gate).retained_bytes})
      :ok
    end

    def websocket_send(exchange, bytes) do
      owner = elem(exchange.transport_state, 0)
      send(owner, {:written, self(), bytes, exchange.deadline})
      :ok
    end

    def websocket_finish(exchange) do
      owner = elem(exchange.transport_state, 0)
      send(owner, {:finished, self()})
      :ok
    end

    def abort(exchange, reason) do
      owner = elem(exchange.transport_state, 0)
      send(owner, {:aborted, self(), reason})
      {:ok, exchange}
    end
  end

  defmodule RejectTransport do
    def websocket_open(_, _, _), do: {:error, :opening_rejected}
    defdelegate abort(exchange, reason), to: Transport
  end

  defmodule BlockingTransport do
    defdelegate websocket_open(exchange, headers, deadline), to: Transport
    defdelegate websocket_demand(exchange, credit, ref), to: Transport
    defdelegate websocket_finish(exchange), to: Transport
    defdelegate abort(exchange, reason), to: Transport

    def websocket_send(exchange, bytes) do
      owner = elem(exchange.transport_state, 0)
      reference = make_ref()
      send(owner, {:send_pending, self(), reference, bytes})

      receive do
        {^reference, result} -> result
      end
    end
  end

  defmodule BlockingFinishTransport do
    defdelegate websocket_open(exchange, headers, deadline), to: Transport
    defdelegate websocket_demand(exchange, credit, ref), to: Transport
    defdelegate websocket_send(exchange, bytes), to: Transport
    defdelegate abort(exchange, reason), to: Transport

    def websocket_finish(exchange) do
      reference = make_ref()
      send(elem(exchange.transport_state, 0), {:finish_pending, self(), reference})

      receive do
        {^reference, result} -> result
      end
    end
  end

  defp start_session(options \\ [], transport \\ Transport, protocol \\ :h2, session \\ []) do
    assert Code.ensure_loaded?(Stream) and function_exported?(Stream, :run, 2),
           "missing shared WebSocket stream driver"

    limits =
      Map.merge(
        %{max_active: 4, max_bytes: 65_536, max_state: 4096, callback_timeout: 1000},
        Keyword.get(session, :limits, %{})
      )

    scope = %{service: :test, instance: self(), generation: make_ref(), service_pid: self()}
    gate = start_supervised!({Admission, {limits, scope}})
    owner = self()
    token = make_ref()

    worker =
      spawn(fn ->
        {:ok, lease} = Admission.acquire(gate, 0, drain_notify: true)
        deadline = Lifecycle.deadline(5000)
        :ok = Admission.begin_request(gate, lease, 0, deadline)
        old_token = :sys.get_state(gate).leases[lease].token
        send(owner, {:original_request, self(), lease, old_token, deadline})

        request =
          %Request{
            method: "CONNECT",
            version: if(protocol == :h3, do: :"HTTP/3", else: :"HTTP/2"),
            scheme: :https,
            host: "example.test",
            port: 443,
            target: "/ws",
            target_form: :origin,
            path: "/ws",
            body: :tunnel,
            headers: [{"sec-websocket-version", "13"}]
          }
          |> Map.put(:protocol, "websocket")

        exchange = %Exchange{
          request: request,
          gate: gate,
          lease: lease,
          deadline: deadline,
          transport: transport,
          transport_state:
            if(protocol == :h3,
              do: {owner, make_ref(), {:stream, 1}, token},
              else: {owner, 1, token}
            ),
          buffer: "",
          body: :tunnel,
          limits: %{
            max_read_chunk: 64,
            max_write_chunk: 64,
            max_header_bytes: 4096,
            write_timeout: Keyword.get(session, :write_timeout, 1000),
            max_body_bytes: 1
          }
        }

        handler = Keyword.get(session, :handler, Handler)
        {:ok, exchange} = WebSocket.prepare(exchange, {handler, owner, options})
        send(owner, {:result, self(), apply(Stream, :run, [exchange, limits])})
      end)

    on_exit(fn -> if Process.alive?(worker), do: Process.exit(worker, :kill) end)
    {worker, token, gate}
  end

  test "default upgraded ownership has no inactivity or lifetime watchdog" do
    {worker, _token, gate} = start_session()
    assert_receive {:original_request, ^worker, lease, stale, _}
    assert_receive {:opened, ^worker, [], :infinity, _}
    assert_receive {:initialized, ^worker}
    assert_receive {:demand, ^worker, 64, _, _}

    assert %{deadline: :infinity, timer: nil, token: nil, websocket_bytes: retained} =
             :sys.get_state(gate).leases[lease]

    assert retained > 0
    send(gate, {:expired, lease, stale})
    send(worker, {:push, "still persistent"})
    assert_receive {:written, ^worker, <<0x81, 16, "still persistent">>, _}
    assert Process.alive?(worker)
  end

  test "a progressing output outlives callback and individual send deadlines" do
    {worker, _token, gate} =
      start_session([callback_timeout: 40], BlockingTransport, :h2, write_timeout: 180)

    assert_receive {:original_request, ^worker, lease, _, _}
    assert_receive {:initialized, ^worker}
    assert_receive {:demand, ^worker, 64, _, _}
    payload = String.duplicate("x", 512)
    started = Lifecycle.now()
    send(worker, {:push, payload})

    wire =
      Enum.map(1..9, fn _ ->
        assert_receive {:send_pending, ^worker, reference, chunk}, 500

        assert %{send: %{operation: _}, timer: timer, websocket_bytes: retained} =
                 :sys.get_state(gate).leases[lease]

        assert is_reference(timer)
        assert retained >= byte_size(payload)
        Process.send_after(self(), {:progress, reference}, 50)
        assert_receive {:progress, ^reference}, 200
        send(worker, {reference, :ok})
        chunk
      end)

    assert Lifecycle.now() - started > 180
    assert IO.iodata_to_binary(wire) == <<0x81, 126, 512::16, payload::binary>>
    # A following application callback is an ordered completion barrier.
    send(worker, :barrier)
    assert_receive {:application_message, :barrier}, 500
    assert %{timer: nil, token: nil, send: nil} = :sys.get_state(gate).leases[lease]
    assert %{transport_bytes: transport, websocket_bytes: retained} = Admission.status(gate)
    assert transport <= 65_536
    assert retained < byte_size(payload)
  end

  test "an outstanding send that stops progressing still expires" do
    {worker, _, gate} = start_session([], BlockingTransport, :h2, write_timeout: 60)
    assert_receive {:initialized, ^worker}
    assert_receive {:demand, ^worker, 64, _, _}
    monitor = Process.monitor(worker)
    send(worker, {:push, "stalled"})
    assert_receive {:send_pending, ^worker, _, _}
    assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, 500

    assert %{active: 0, retained_bytes: 0, transport_bytes: 0, websocket_bytes: 0} =
             Admission.status(gate)
  end

  test "a callback that does not return retains its finite execution bound" do
    {worker, _, gate} = start_session(callback_timeout: 50)
    assert_receive {:initialized, ^worker}
    assert_receive {:demand, ^worker, 64, _, _}
    monitor = Process.monitor(worker)
    send(worker, :stall)
    assert_receive {:callback_stalled, ^worker}
    assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, 500
    assert %{active: 0, retained_bytes: 0} = Admission.status(gate)
  end

  test "a raised callback ends its execution watchdog before sending its close frame" do
    {worker, token, gate} =
      start_session([callback_timeout: 1000], BlockingTransport, :h2, write_timeout: 2000)

    assert_receive {:original_request, ^worker, lease, _, _}
    assert_receive {:initialized, ^worker}
    assert_receive {:demand, ^worker, 64, ref, _}
    send(worker, :raise)
    assert_receive {:callback_exception_pending, ^worker}
    assert %{token: callback_token} = :sys.get_state(gate).leases[lease]
    assert is_reference(callback_token)
    send(worker, :raise)
    assert_receive {:send_pending, ^worker, reference, <<0x88, 2, 1011::16>>}
    assert %{send: %{operation: _}, token: send_token} = :sys.get_state(gate).leases[lease]
    assert is_reference(send_token)
    assert send_token != callback_token
    send(gate, {:expired, lease, callback_token})
    assert %{leases: %{^lease => %{token: ^send_token}}} = :sys.get_state(gate)
    assert Process.alive?(worker)
    send(worker, {reference, :ok})
    send(worker, {:gaoxy_websocket_data, token, ref, masked(8, <<1011::16>>), false})
    assert_receive {:result, ^worker, {:error, {:error, %RuntimeError{}}, _}}
  end

  for action <- [:terminate_return, :terminate_raise] do
    test "#{action} ends its callback watchdog before transport finish" do
      {worker, token, gate} =
        start_session([callback_timeout: 1000], BlockingFinishTransport, :h2,
          handler: ControlledTerminateHandler
        )

      assert_receive {:original_request, ^worker, lease, _, _}
      assert_receive {:initialized, ^worker}
      assert_receive {:demand, ^worker, 64, ref, _}
      send(worker, {:gaoxy_websocket_data, token, ref, "", true})
      assert_receive {:terminate_pending, ^worker, :remote}
      assert %{timer: timer, token: callback_token} = :sys.get_state(gate).leases[lease]
      assert is_reference(timer) and is_reference(callback_token)
      send(worker, unquote(action))
      assert_receive {:finish_pending, ^worker, reference}
      assert %{timer: nil, token: nil, send: nil} = :sys.get_state(gate).leases[lease]
      send(gate, {:expired, lease, callback_token})
      assert %{leases: %{^lease => %{token: nil}}} = :sys.get_state(gate)
      assert Process.alive?(worker)
      send(worker, {reference, :ok})
      assert_receive {:result, ^worker, {:ok, _}}
    end
  end

  test "a nonreturning terminate callback retains its execution deadline" do
    {worker, token, gate} =
      start_session([callback_timeout: 100], BlockingFinishTransport, :h2,
        handler: ControlledTerminateHandler
      )

    assert_receive {:initialized, ^worker}
    assert_receive {:demand, ^worker, 64, ref, _}
    monitor = Process.monitor(worker)
    send(worker, {:gaoxy_websocket_data, token, ref, "", true})
    assert_receive {:terminate_pending, ^worker, :remote}
    assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, 1000

    assert %{active: 0, retained_bytes: 0, transport_bytes: 0, websocket_bytes: 0} =
             Admission.status(gate)

    refute_receive {:finish_pending, ^worker, _}, 10
  end

  test "H3-shaped transport identity remains intact through data and application pushes" do
    {worker, token, _} = start_session([], Transport, :h3)
    assert_receive {:opened, ^worker, [], deadline, exchange}
    assert {owner, table, {:stream, 1}, ^token} = exchange.transport_state
    assert owner == self()
    assert is_reference(table)
    assert_receive {:initialized, ^worker}
    assert_receive {:demand, ^worker, 64, ref, _}
    send(worker, {:push, "h3 push"})
    assert_receive {:written, ^worker, <<0x81, 7, "h3 push">>, ^deadline}
    send(worker, {:gaoxy_websocket_data, token, ref, masked(1, "h3 data"), false})
    assert_receive {:written, ^worker, <<0x81, 7, "h3 data">>, ^deadline}
    assert_receive {:demand, ^worker, 64, final, _}
    send(worker, {:gaoxy_websocket_data, token, final, masked(8, <<1000::16>>), false})
    assert_receive {:terminated, :remote}

    assert_receive {:result, ^worker,
                    {:ok, %{transport_state: {^owner, ^table, {:stream, 1}, ^token}}}}
  end

  test "owner rejection cleans up without initializing or finishing a tunnel" do
    {worker, _, _} = start_session([], RejectTransport)
    assert_receive {:aborted, ^worker, :opening_rejected}
    assert_receive {:result, ^worker, {:error, :opening_rejected, _}}
    refute_receive {:initialized, ^worker}, 10
    refute_receive {:finished, ^worker}, 10
    refute_receive {:terminated, _}, 10
  end

  test "opens once in the admitted worker and pushes while one bounded demand is pending" do
    {worker, token, gate} = start_session()
    assert_receive {:opened, ^worker, [], deadline, exchange}
    assert_receive {:initialized, ^worker}
    assert_receive {:demand, ^worker, 64, ref, reserved}
    assert reserved >= 128 + :erlang.external_size(self())
    assert %{leases: leases} = :sys.get_state(gate)
    assert %{deadline: ^deadline} = leases[exchange.lease]
    assert exchange.deadline == deadline
    send(worker, {:push, "idle push"})
    assert_receive {:written, ^worker, <<0x81, 9, "idle push">>, ^deadline}
    refute_receive {:demand, ^worker, _, _, _}, 10
    send(worker, {:gaoxy_websocket_data, make_ref(), ref, masked(1, "wrong"), false})
    send(worker, {:gaoxy_websocket_data, token, make_ref(), masked(1, "stale"), false})
    send(worker, {:push, "barrier"})
    assert_receive {:written, ^worker, <<0x81, 7, "barrier">>, ^deadline}
    assert Admission.status(gate).retained_bytes >= 128 + :erlang.external_size(self())
    refute_receive {:application_message, _}, 10
    send(worker, {:gaoxy_websocket_data, token, ref, masked(8, <<1000::16>>), false})
    assert_receive {:written, ^worker, <<0x88, 2, 1000::16>>, ^deadline}
    assert_receive {:demand, ^worker, 0, ^ref, _}
    assert_receive {:terminated, :remote}
    assert_receive {:finished, ^worker}
    assert_receive {:result, ^worker, {:ok, %{deadline: ^deadline}}}
    refute_receive {:terminated, _}, 10
  end

  test "ordinary drain shortens stream writes and terminates once after the peer close" do
    {worker, token, gate} = start_session()
    assert_receive {:opened, ^worker, [], deadline, exchange}
    assert_receive {:initialized, ^worker}
    assert_receive {:demand, ^worker, 64, ref, _}
    drain_deadline = min(deadline, Lifecycle.deadline(2000))
    send(worker, {:gaoxy_drain, gate, exchange.lease, drain_deadline})
    assert_receive {:written, ^worker, <<0x88, 2, 1001::16>>, ^drain_deadline}
    send(worker, {:gaoxy_websocket_data, token, ref, masked(8, <<1001::16>>), false})
    assert_receive {:terminated, :shutdown}
    assert_receive {:finished, ^worker}
    assert_receive {:result, ^worker, {:ok, %{deadline: ^drain_deadline}}}
    refute_receive {:terminated, _}, 10
  end

  test "split DATA and repeated messages retain framing while exceeding ordinary body totals" do
    {worker, token, _} = start_session()
    assert_receive {:opened, ^worker, [], deadline, _}
    assert_receive {:initialized, ^worker}
    assert_receive {:demand, ^worker, 64, ref, _}
    <<prefix::binary-size(3), rest::binary>> = masked(1, "hello")
    send(worker, {:gaoxy_websocket_data, token, ref, prefix, false})
    assert_receive {:demand, ^worker, 64, second, _}
    assert second != ref
    send(worker, {:gaoxy_websocket_data, token, second, rest <> masked(1, "again"), false})
    assert_receive {:written, ^worker, <<0x81, 5, "hello">>, ^deadline}
    assert_receive {:written, ^worker, <<0x81, 5, "again">>, ^deadline}
    assert_receive {:demand, ^worker, 64, third, _}
    send(worker, {:gaoxy_websocket_data, token, third, "", true})
    assert_receive {:demand, ^worker, 0, ^third, _}
    assert_receive {:terminated, :remote}
    assert_receive {:finished, ^worker}
    assert_receive {:result, ^worker, {:ok, _}}
  end

  test "adopted lifetime remains authoritative across the former request deadline boundary" do
    {worker, token, gate} = start_session(max_lifetime: 10_000)
    assert_receive {:original_request, ^worker, lease, old_token, old_deadline}
    assert_receive {:opened, ^worker, [], deadline, exchange}
    assert_receive {:initialized, ^worker}
    assert_receive {:demand, ^worker, 64, ref, _}
    assert deadline > old_deadline
    # Deterministically deliver the original request timer after upgrading.
    # Its stale token must leave the new lease and lifetime timer intact.
    send(gate, {:expired, lease, old_token})
    assert :sys.get_state(gate).leases[exchange.lease].deadline == deadline
    send(worker, {:gaoxy_websocket_lifetime, make_ref()})
    send(worker, {:push, "still live"})
    assert_receive {:written, ^worker, <<0x81, 10, "still live">>, ^deadline}
    send(worker, {:gaoxy_websocket_data, token, ref, "", true})
    assert_receive {:result, ^worker, {:ok, _}}
  end

  for {name, callback, payload, reason, pushed} <- [
        {"normal", {:stop, :normal}, <<1000::16>>, :normal, nil},
        {"Phoenix disconnect", {:stop, {:shutdown, :disconnected}}, <<1000::16>>, :normal, nil},
        {"restart", {:stop, {:shutdown, :restart}}, <<1012::16>>, :shutdown, nil},
        {"arbitrary shutdown", {:stop, {:shutdown, :other}}, <<1011::16>>,
         {:error, {:shutdown, :other}}, nil},
        {"arbitrary error", {:stop, :failed}, <<1011::16>>, {:error, :failed}, nil},
        {"explicit disconnect code", {:stop, {:shutdown, :disconnected}, 4001}, <<4001::16>>,
         :normal, nil},
        {"explicit restart code", {:stop, {:shutdown, :restart}, 4002}, <<4002::16>>, :shutdown,
         nil},
        {"explicit error code and final message",
         {:stop, {:shutdown, :other}, {4003, "application"}, [{:text, "final"}]},
         <<4003::16, "application">>, {:error, {:shutdown, :other}}, "final"}
      ] do
    test "stop callback preserves #{name} close and termination semantics" do
      {worker, token, _} = start_session()
      assert_receive {:opened, ^worker, [], deadline, _}
      assert_receive {:initialized, ^worker}
      assert_receive {:demand, ^worker, 64, ref, _}
      send(worker, unquote(Macro.escape(callback)))

      assert_final_push(worker, deadline, unquote(pushed))

      payload = unquote(payload)
      assert_receive {:written, ^worker, <<0x88, size, ^payload::binary>>, ^deadline}
      assert size == byte_size(payload)
      send(worker, {:gaoxy_websocket_data, token, ref, masked(8, payload), false})
      assert_receive {:terminated, unquote(Macro.escape(reason))}
      assert_stop_result(worker, unquote(Macro.escape(reason)))
      refute_receive {:terminated, _}, 10
    end
  end

  defp assert_final_push(_, _, nil), do: :ok

  defp assert_final_push(worker, deadline, payload) do
    assert_receive {:written, ^worker, <<0x81, 5, ^payload::binary>>, ^deadline}
  end

  defp assert_stop_result(worker, {:error, reason}) do
    assert_receive {:aborted, ^worker, ^reason}
    assert_receive {:result, ^worker, {:error, ^reason, _}}
    refute_receive {:finished, ^worker}, 10
  end

  defp assert_stop_result(worker, _) do
    assert_receive {:finished, ^worker}
    assert_receive {:result, ^worker, {:ok, _}}
  end

  defp masked(opcode, payload) do
    key = <<1, 2, 3, 4>>

    body =
      for {byte, index} <- Enum.with_index(:binary.bin_to_list(payload)),
          into: <<>>,
          do: <<bxor(byte, :binary.at(key, rem(index, 4)))>>

    <<1::1, 0::3, opcode::4, 1::1, byte_size(payload)::7, key::binary, body::binary>>
  end
end
