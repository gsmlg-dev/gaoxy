defmodule Gaoxy.HTTP2StaleStartTest do
  alias HTTP.HTTP2.HPACK
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.Response
  alias Gaoxy.HTTP.HTTP2.Frame
  @timeout 2_000

  defmodule Endpoint do
    def init(owner), do: {:ok, owner}

    def call(exchange, owner) do
      if exchange.request.path == "/seed",
        do: send(owner, {:stale_start_owner, exchange.transport_state, exchange.gate})

      Response.send_resp(exchange, 200, [], exchange.request.path)
    end
  end

  @tag :controlled_late_receipt
  test "a canceled starter's late failure cannot replace the current admission starter" do
    {socket, server} = connect()
    # Precharge decoding before suspending Admission to isolate worker startup.
    send_headers(socket, 1, "/seed", [{"x-precharge", String.duplicate("a", 128)}])
    assert_receive {:stale_start_owner, {owner, 1, _}, gate}, @timeout
    assert responses(socket, [1]) == %{1 => %{status: "200", body: "/seed"}}
    await_owner(owner, &(not Map.has_key?(&1.streams, 1) and &1.starting == nil))
    :ok = :sys.suspend(gate)

    try do
      send_headers(socket, 3, "/canceled")

      old =
        await_owner(owner, fn state ->
          state.starting == 3 and
            match?(
              %{worker: nil, lease: nil, startup: %{request: request}} when is_reference(request),
              state.streams[3]
            )
        end).streams[3]

      :ok = :gen_tcp.send(socket, Frame.encode(3, 0, 3, <<Frame.code(:cancel)::32>>))
      send_headers(socket, 5, "/five")
      send_headers(socket, 7, "/seven")

      before_receipt =
        await_owner(owner, fn state ->
          state.starting == 5 and not Map.has_key?(state.streams, 3) and
            match?(
              %{worker: nil, lease: nil, startup: %{request: request}} when is_reference(request),
              state.streams[5]
            ) and
            match?(%{worker: nil, startup: nil}, state.streams[7])
        end)

      # Schedule a delayed receipt using the actual canceled public request id.
      # No child exists before the Gate accepts the new pre-admitted startup.
      send(owner, {[:alias | old.startup.request], {:error, :active_limit}})
      {_socket, after_receipt} = :sys.get_state(owner, @timeout)
      assert after_receipt.starting == 5
      assert after_receipt.streams[5].worker == before_receipt.streams[5].worker
      assert after_receipt.streams[5].startup == before_receipt.streams[5].startup
      assert after_receipt.streams[5].token == before_receipt.streams[5].token
      assert after_receipt.streams[7].worker == nil
      assert after_receipt.streams[7].startup == nil

      :ok = :sys.resume(gate)

      assert responses(socket, [5, 7]) == %{
               5 => %{status: "200", body: "/five"},
               7 => %{status: "200", body: "/seven"}
             }
    after
      safe_resume(gate)
      :ok = :gen_tcp.close(socket)

      eventually(fn ->
        match?(%{active: 0, retained_bytes: 0, cleanup_pending: 0}, Gaoxy.status(server, :http))
      end)
    end
  end

  defp connect do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint: {Endpoint, self()},
        protocols: [:http2],
        h2c: :prior_knowledge,
        limits: %{max_bytes: 536_870_912, max_active: 128},
        http_limits: %{request_timeout: 5_000}
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, @timeout) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)
    :ok = :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", Frame.encode(4, 0, 0, "")])
    {socket, server}
  end

  defp send_headers(socket, id, path, extra \\ []) do
    fields = [
      {":method", "GET"},
      {":scheme", "http"},
      {":authority", "localhost"},
      {":path", path}
    ]

    {_, block} =
      HPACK.encode_headers(HPACK.new_encoder(), fields ++ extra,
        indexing: :never,
        huffman: :never
      )

    :ok = :gen_tcp.send(socket, Frame.encode(1, 5, id, block))
  end

  defp responses(socket, ids) do
    collect(
      socket,
      Map.new(ids, &{&1, %{status: nil, body: ""}}),
      ids,
      HPACK.new_decoder(max_dynamic_size: 4_096)
    )
  end

  defp collect(_socket, results, [], _decoder), do: results

  defp collect(socket, results, remaining, decoder) do
    {:ok, <<size::24, type, flags, _::1, id::31>>} = :gen_tcp.recv(socket, 9, @timeout)

    bytes =
      if size == 0 do
        ""
      else
        {:ok, bytes} = :gen_tcp.recv(socket, size, @timeout)
        bytes
      end

    case {type, id} do
      {1, id} when is_map_key(results, id) ->
        assert Frame.flag?(flags, 4)
        {:ok, decoder, fields} = HPACK.decode(decoder, bytes)
        {":status", status} = List.keyfind(fields, ":status", 0)
        results = put_in(results[id].status, status)
        remaining = if Frame.flag?(flags, 1), do: List.delete(remaining, id), else: remaining
        collect(socket, results, remaining, decoder)

      {0, id} when is_map_key(results, id) ->
        results = update_in(results[id].body, &(&1 <> bytes))
        remaining = if Frame.flag?(flags, 1), do: List.delete(remaining, id), else: remaining
        collect(socket, results, remaining, decoder)

      {4, 0} ->
        unless Frame.flag?(flags, 1), do: :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
        collect(socket, results, remaining, decoder)

      {3, _} ->
        flunk("unexpected RST_STREAM for #{id}: #{inspect(bytes)}")

      {7, 0} ->
        flunk("unexpected GOAWAY: #{inspect(bytes)}")

      _ ->
        flunk("unexpected frame #{type} for stream #{id}")
    end
  end

  defp await_owner(owner, predicate, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(@timeout)
    {_socket, state} = :sys.get_state(owner, @timeout)

    if predicate.(state) do
      state
    else
      assert Gaoxy.Lifecycle.remaining(deadline) > 0

      receive do
      after
        1 -> await_owner(owner, predicate, deadline)
      end
    end
  end

  defp eventually(predicate, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(@timeout)

    unless predicate.() do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0

      receive do
      after
        1 -> eventually(predicate, deadline)
      end
    end
  end

  defp safe_resume(gate) do
    if Process.alive?(gate), do: :sys.resume(gate, 100)
  catch
    :exit, _ -> :ok
  end
end
