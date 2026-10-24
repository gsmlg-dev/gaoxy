defmodule Gaoxy.HTTP.WebSocket.EventRetentionTest do
  use ExUnit.Case, async: true
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Exchange, Request, WebSocket}
  alias Gaoxy.HTTP.WebSocket.Stream

  defmodule Handler do
    def init(owner), do: {:ok, owner}

    def handle_in({"pause", opcode: :binary}, owner) do
      send(owner, {:callback_paused, self()})

      receive do
        :resume -> {:ok, owner}
      end
    end

    def handle_in({bytes, opcode: :binary}, owner) do
      send(owner, {:received, self(), bytes})
      {:ok, owner}
    end

    def handle_info({:invalid_output, reference}, owner),
      do: {:gaoxy_push, {:text, <<255>>}, {owner, reference}, owner}

    def handle_info(_, owner), do: {:ok, owner}
  end

  defmodule Transport do
    def websocket_open(exchange, _, deadline), do: {:ok, %{exchange | deadline: deadline}}

    def websocket_demand(exchange, credit, reference) do
      send(elem(exchange.transport_state, 0), {:demand, self(), credit, reference})
      :ok
    end

    def websocket_send(exchange, bytes) do
      send(elem(exchange.transport_state, 0), {:written, self(), bytes})
      :ok
    end

    def websocket_finish(_), do: :ok
    def abort(exchange, _), do: {:ok, exchange}
  end

  setup do
    limits = %{max_active: 1, max_bytes: 8192, max_state: 1, callback_timeout: 5000}
    gate = start_supervised!({Admission, {limits, %{service: :event_retention}}})
    owner = self()
    token = make_ref()

    worker =
      spawn(fn ->
        {:ok, lease} = Admission.acquire(gate, 0, drain_notify: true)
        deadline = Lifecycle.deadline(5000)
        :ok = Admission.begin_request(gate, lease, 0, deadline)

        request = %Request{
          method: "CONNECT",
          protocol: "websocket",
          version: :"HTTP/2",
          scheme: :https,
          host: "example.test",
          port: 443,
          target: "/ws",
          target_form: :origin,
          path: "/ws",
          body: :tunnel,
          headers: [{"sec-websocket-version", "13"}]
        }

        exchange = %Exchange{
          request: request,
          gate: gate,
          lease: lease,
          deadline: deadline,
          buffer: "",
          transport: Transport,
          transport_state: {owner, 1, token},
          body: :tunnel,
          limits: %{
            max_read_chunk: 2048,
            max_write_chunk: 64,
            max_header_bytes: 4096,
            write_timeout: 1000,
            max_body_bytes: 1
          }
        }

        {:ok, exchange} = WebSocket.prepare(exchange, {Handler, owner, []})
        send(owner, {:result, self(), Stream.run(exchange, limits)})
      end)

    on_exit(fn -> if Process.alive?(worker), do: Process.exit(worker, :kill) end)
    assert_receive {:demand, ^worker, 2048, reference}, 1000
    %{worker: worker, token: token, gate: gate, limits: limits, demand: reference}
  end

  test "undispatched coalesced messages stay observed while an earlier callback owns execution",
       %{
         worker: worker,
         token: token,
         gate: gate,
         limits: limits,
         demand: reference
       } do
    payload = :binary.copy("x", 1024)
    coalesced = masked("pause") <> masked(payload)
    send(worker, {:gaoxy_websocket_data, token, reference, coalesced, false})
    assert_receive {:callback_paused, ^worker}, 1000

    assert %{websocket_bytes: retained, transport_bytes: transport} = Admission.status(gate)
    assert retained >= byte_size(payload)
    assert transport <= limits.max_bytes

    send(worker, :resume)
    assert_receive {:received, ^worker, ^payload}, 1000
    assert_receive {:demand, ^worker, 2048, _}, 1000
    assert %{websocket_bytes: retained} = Admission.status(gate)
    assert retained < byte_size(payload)
  end

  test "a rejected push reports an error even when its close frame is written", %{worker: worker} do
    reference = make_ref()
    send(worker, {:invalid_output, reference})
    assert_receive {:written, ^worker, <<0x88, 2, 1011::16>>}, 1000
    assert_receive {:gaoxy_websocket_written, ^reference, {:error, :invalid_utf8}}, 1000
    refute_receive {:gaoxy_websocket_written, ^reference, :ok}
  end

  defp masked(payload) do
    size = byte_size(payload)
    prefix = if size < 126, do: <<0x82, 0x80 + size>>, else: <<0x82, 0xFE, size::16>>
    prefix <> <<0::32>> <> payload
  end
end
