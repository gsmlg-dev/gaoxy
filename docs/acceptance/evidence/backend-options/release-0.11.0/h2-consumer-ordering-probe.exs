
defmodule H2ConsumerOrderingProbe do
  import ExUnit.Assertions
  def run(order) do
    observer = self()
    fixture = Gaoxy.Test.open(mode: :manual, profile: :h2c)
    Gaoxy.Test.expect_once(fixture, :get, "/h2", fn conn ->
      assert Plug.Conn.get_http_protocol(conn) == :"HTTP/2"
      result = Plug.Conn.send_resp(conn, 200, "external h2")
      send(observer, {:callback_after_response, self()})
      receive do
        :return_callback -> result
      after
        2_000 -> raise "probe callback barrier expired"
      end
    end)
    uri = URI.parse(Gaoxy.Test.url(fixture))
    {:ok, socket} = :gen_tcp.connect(~c"127.0.0.1", uri.port, [:binary, active: false], 2_000)
    {block, _} = HPAX.encode(:never_store, [{":method", "GET"}, {":scheme", "http"}, {":authority", "localhost"}, {":path", "/h2"}], HPAX.new(0))
    :ok = :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", frame(4, 0, 0, ""), frame(1, 5, 1, IO.iodata_to_binary(block))])
    assert {"200", "external h2"} = receive_h2(socket, HPAX.new(4_096), nil, "")
    worker = receive do
      {:callback_after_response, pid} -> pid
    after
      2_000 -> raise "probe response barrier missing"
    end
    monitor = Process.monitor(worker)
    assert Process.alive?(worker)
    case order do
      :close_before_callback_returns ->
        :gen_tcp.close(socket)
        assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, 2_000
        error = assert_raise Gaoxy.Test.VerificationError, fn -> Gaoxy.Test.verify!(fixture) end
        assert [%{type: :terminated, reason: {:terminated, :killed}}] = error.report.failures
        IO.puts("ORDERING_PROBE expected_failure close_before_callback_returns reason={:terminated,:killed}")
      :verify_before_close ->
        send(worker, :return_callback)
        assert :ok = Gaoxy.Test.verify!(fixture)
        :gen_tcp.close(socket)
        IO.puts("ORDERING_PROBE pass verify_before_close")
    end
    assert %{cleanup: :ok} = Gaoxy.Test.close(fixture)
  end
  defp receive_h2(socket, decoder, status, body) do
    assert {:ok, <<size::24, type, flags, _::1, stream::31>>} = :gen_tcp.recv(socket, 9, 2_000)
    payload = if size == 0, do: "", else: elem(:gen_tcp.recv(socket, size, 2_000), 1)

    case {type, stream} do
      {4, 0} ->
        if Bitwise.band(flags, 1) == 0, do: :gen_tcp.send(socket, frame(4, 1, 0, ""))
        receive_h2(socket, decoder, status, body)

      {1, 1} ->
        assert {:ok, fields, decoder} = HPAX.decode(payload, decoder)
        status = fields |> List.keyfind(":status", 0) |> elem(1)

        if Bitwise.band(flags, 1) == 1,
          do: {status, body},
          else: receive_h2(socket, decoder, status, body)

      {0, 1} ->
        body = body <> payload

        if Bitwise.band(flags, 1) == 1,
          do: {status, body},
          else: receive_h2(socket, decoder, status, body)

      _ ->
        receive_h2(socket, decoder, status, body)
    end
  end

  defp frame(type, flags, stream, payload),
    do: <<byte_size(payload)::24, type, flags, 0::1, stream::31, payload::binary>>


end
H2ConsumerOrderingProbe.run(:close_before_callback_returns)
H2ConsumerOrderingProbe.run(:verify_before_close)
