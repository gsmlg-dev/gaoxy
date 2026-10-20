defmodule Gaoxy.HTTP2DefaultConcurrencyTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.Response
  alias Gaoxy.HTTP.HTTP2.Frame
  @timeout 3_000

  defmodule Endpoint do
    def init(owner), do: {:ok, owner}

    def call(exchange, owner) do
      send(owner, {:default_h2_request, self(), exchange.request.path, exchange.transport_state})

      receive do
        :respond -> Response.send_resp(exchange, 200, [], exchange.request.path)
      after
        Gaoxy.Lifecycle.remaining(exchange.deadline) -> {:error, :timeout, exchange}
      end
    end
  end

  @tag :tmp_dir
  test "default HTTPS serves overlapping requests on two independent H2 connections", %{
    tmp_dir: dir
  } do
    root = Path.expand("../../..", __DIR__)

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), dir],
               stderr_to_stdout: true
             )

    options = [
      endpoint: {Endpoint, self()},
      transport: :tls,
      tls: %{certfile: Path.join(dir, "cert.pem"), keyfile: Path.join(dir, "key.pem")}
    ]

    assert {:ok, spec} = Gaoxy.HTTP.service_spec(options)
    assert spec.limits.max_bytes == 268_435_456
    assert spec.handler_options.protocols == [:http2, :http1]
    {:ok, server} = Gaoxy.HTTP.start_link(options)
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, @timeout) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local

    first = connect(ip, port, dir)
    send_request(first, 1, "/first")
    assert_receive {:default_h2_request, first_worker, "/first", {first_owner, 1, _}}, @timeout

    second = connect(ip, port, dir)
    send_request(second, 1, "/second")
    assert_receive {:default_h2_request, second_worker, "/second", {second_owner, 1, _}}, @timeout
    assert first_owner != second_owner
    assert Process.alive?(first_worker)
    assert Process.alive?(second_worker)

    send(first_worker, :respond)
    send(second_worker, :respond)
    assert response(first) == %{status: "200", body: "/first"}
    assert response(second) == %{status: "200", body: "/second"}

    for {socket, owner} <- [{first, first_owner}, {second, second_owner}] do
      send_request(socket, 3, "/again")
      assert_receive {:default_h2_request, worker, "/again", {^owner, 3, _}}, @timeout
      send(worker, :respond)
      assert response(socket) == %{status: "200", body: "/again"}
    end

    assert %{rejected: 0} = Gaoxy.status(server, :http)
    :ok = :ssl.close(first)
    :ok = :ssl.close(second)

    eventually(fn ->
      match?(%{active: 0, retained_bytes: 0, cleanup_pending: 0}, Gaoxy.status(server, :http))
    end)

    assert :ok = Gaoxy.stop(server, @timeout)
  end

  defp connect(ip, port, dir) do
    {:ok, socket} =
      :ssl.connect(
        ip,
        port,
        [
          :binary,
          active: false,
          verify: :verify_peer,
          cacertfile: String.to_charlist(Path.join(dir, "ca.pem")),
          server_name_indication: ~c"localhost",
          alpn_advertised_protocols: ["h2", "http/1.1"]
        ],
        @timeout
      )

    on_exit(fn -> :ssl.close(socket) end)
    assert {:ok, "h2"} = :ssl.negotiated_protocol(socket)
    :ok = :ssl.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", Frame.encode(4, 0, 0, "")])
    socket
  end

  defp send_request(socket, id, path) do
    fields = [
      {":method", "GET"},
      {":scheme", "https"},
      {":authority", "localhost"},
      {":path", path}
    ]

    {block, _} = HPAX.encode(:never_store, fields, HPAX.new(4_096))
    assert :ok = :ssl.send(socket, Frame.encode(1, 5, id, block))
  end

  defp response(socket, result \\ %{status: nil, body: ""}, decoder \\ HPAX.new(4_096)) do
    assert {:ok, <<size::24, type, flags, _::1, id::31>>} = :ssl.recv(socket, 9, @timeout)
    bytes = if size == 0, do: "", else: elem(:ssl.recv(socket, size, @timeout), 1)

    case {type, id} do
      {1, id} when id in [1, 3] ->
        assert Frame.flag?(flags, 4)
        {:ok, fields, decoder} = HPAX.decode(bytes, decoder)
        {":status", status} = List.keyfind(fields, ":status", 0)
        next = %{result | status: status}
        if Frame.flag?(flags, 1), do: next, else: response(socket, next, decoder)

      {0, id} when id in [1, 3] ->
        next = %{result | body: result.body <> bytes}
        if Frame.flag?(flags, 1), do: next, else: response(socket, next, decoder)

      {4, 0} ->
        unless Frame.flag?(flags, 1), do: :ssl.send(socket, Frame.encode(4, 1, 0, ""))
        response(socket, result, decoder)

      _ ->
        flunk("unexpected H2 frame #{type} for stream #{id}: #{inspect(bytes)}")
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
end
