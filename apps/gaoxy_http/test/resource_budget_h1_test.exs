defmodule Gaoxy.HTTP.ResourceBudgetH1Test do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.{Exchange, Response}
  @timeout 3_000

  defmodule Endpoint do
    def init(owner), do: {:ok, owner}

    def call(exchange, owner) do
      send(owner, {:budget_h1, self(), exchange.request.path})

      receive do
        :respond ->
          if exchange.request.path == "/upload",
            do: echo(exchange, ""),
            else: Response.send_resp(exchange, 200, [], exchange.request.path)
      after
        Gaoxy.Lifecycle.remaining(exchange.deadline) -> {:error, :timeout, exchange}
      end
    end

    defp echo(exchange, result) do
      case Exchange.read_body_step(exchange, 16_384, 1_000) do
        {:more, bytes, next} -> echo(next, result <> bytes)
        {:ok, bytes, next} -> Response.send_resp(next, 200, [], result <> bytes)
        {:pending, next} -> echo(next, result)
        {:error, reason, next} -> {:error, reason, next}
      end
    end
  end

  test "independent H1 connections count requests separately and release keep-alive ownership" do
    server = server()
    a = connect(server)
    b = connect(server)
    request(a, "/first")
    request(b, "/second")
    assert_receive {:budget_h1, wa, "/first"}, @timeout
    assert_receive {:budget_h1, wb, "/second"}, @timeout
    assert wa != wb
    assert %{active_connections: 2, active_requests: 2} = Gaoxy.resource_budget(server)
    busy = Gaoxy.resource_budget(server).usage
    send(wa, :respond)
    send(wb, :respond)
    assert response(a) == {200, "/first"}
    assert response(b) == {200, "/second"}
    await(server, &(&1.active_connections == 2 and &1.active_requests == 0))
    assert Gaoxy.resource_budget(server).usage < busy
    request(a, "/again")
    assert_receive {:budget_h1, ^wa, "/again"}, @timeout
    assert %{active_connections: 2, active_requests: 1} = Gaoxy.resource_budget(server)
    send(wa, :respond)
    assert response(a) == {200, "/again"}
    :gen_tcp.close(a)
    :gen_tcp.close(b)
    await(server, &(&1.active_connections == 0 and &1.active_requests == 0 and &1.usage == 0))
  end

  test "ordinary H1 request quota returns bounded 503 while an admitted sibling completes" do
    server = server(limits: %{max_requests: 1})
    a = connect(server)
    b = connect(server)
    request(a, "/first")
    assert_receive {:budget_h1, worker, "/first"}, @timeout
    request(b, "/refused")
    assert response(b) == {503, ""}
    assert Process.alive?(worker)
    refute_receive {:budget_h1, _, "/refused"}, 0
    send(worker, :respond)
    assert response(a) == {200, "/first"}
    await(server, &(&1.active_requests == 0))
    request(a, "/recovered")
    assert_receive {:budget_h1, ^worker, "/recovered"}, @timeout
    send(worker, :respond)
    assert response(a) == {200, "/recovered"}
    :gen_tcp.close(a)
    :gen_tcp.close(b)
    await(server, &(&1.usage == 0 and &1.active_requests == 0 and &1.active_connections == 0))
  end

  test "overlapping ordinary body uploads retain two requests and return credits on completion" do
    server = server()
    sockets = for _ <- 1..2, do: connect(server)

    for socket <- sockets,
        do:
          :ok =
            :gen_tcp.send(
              socket,
              "POST /upload HTTP/1.1\r\nHost: localhost\r\nContent-Length: 4\r\n\r\na"
            )

    assert_receive {:budget_h1, first, "/upload"}, @timeout
    assert_receive {:budget_h1, second, "/upload"}, @timeout
    assert first != second
    assert %{active_connections: 2, active_requests: 2} = Gaoxy.resource_budget(server)
    for worker <- [first, second], do: send(worker, :respond)
    for socket <- sockets, do: :ok = :gen_tcp.send(socket, "bcd")
    for socket <- sockets, do: assert(response(socket) == {200, "abcd"})
    await(server, &(&1.active_connections == 2 and &1.active_requests == 0))
    for socket <- sockets, do: :gen_tcp.close(socket)
    await(server, &(&1.active_connections == 0 and &1.usage == 0))
  end

  defp server(extra \\ []) do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        Keyword.merge(
          [
            endpoint: {Endpoint, self()},
            protocols: [:http1],
            http_limits: %{request_timeout: @timeout}
          ],
          extra
        )
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, @timeout) end)
    server
  end

  defp connect(server) do
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)
    socket
  end

  defp request(socket, path),
    do: :ok = :gen_tcp.send(socket, "GET #{path} HTTP/1.1\r\nHost: localhost\r\n\r\n")

  defp response(socket, buffer \\ "") do
    case :binary.match(buffer, "\r\n\r\n") do
      :nomatch ->
        assert {:ok, bytes} = :gen_tcp.recv(socket, 0, @timeout)
        response(socket, buffer <> bytes)

      {size, 4} ->
        <<head::binary-size(^size), _::binary-size(4), body::binary>> = buffer
        [status | headers] = String.split(head, "\r\n")
        [_, code | _] = String.split(status, " ")

        length =
          Enum.find_value(headers, fn line ->
            case String.split(line, ":", parts: 2) do
              [key, value] ->
                if String.downcase(key) == "content-length",
                  do: String.to_integer(String.trim(value))

              _ ->
                nil
            end
          end)

        assert is_integer(length)
        missing = length - byte_size(body)

        body =
          if missing > 0,
            do: body <> elem(:gen_tcp.recv(socket, missing, @timeout), 1),
            else: body

        {String.to_integer(code), body}
    end
  end

  defp await(server, predicate, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(@timeout)
    status = Gaoxy.resource_budget(server)

    unless predicate.(status) do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)
      Process.sleep(1)
      await(server, predicate, deadline)
    end
  end
end
