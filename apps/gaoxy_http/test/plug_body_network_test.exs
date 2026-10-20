Code.require_file("support/plug_body_fixture.exs", __DIR__)

defmodule Gaoxy.PlugBodyNetworkTest do
  use ExUnit.Case, async: true

  test "real H1 Plug parsers accept JSON and form bodies above native chunk size" do
    {server, port} = start_server()

    for {type, body} <- [
          {"application/json", JSON.encode!(%{value: String.duplicate("x", 20_000)})},
          {"application/x-www-form-urlencoded", "value=" <> String.duplicate("x", 20_000)}
        ] do
      socket = connect(port)
      :ok = :gen_tcp.send(socket, request("/parse", type, body))
      assert {200, "20000", ""} = response(socket)
      :gen_tcp.close(socket)
    end

    assert :ok = Gaoxy.stop(server)
  end

  test "real H1 parser length rejection remains 413" do
    {server, port} = start_server()
    socket = connect(port)
    body = JSON.encode!(%{value: String.duplicate("x", 20_000)})
    :ok = :gen_tcp.send(socket, request("/parser-limit", "application/json", body))
    assert {413, "", ""} = response(socket)
    assert :ok = Gaoxy.stop(server)
  end

  test "chunked H1 parser preserves terminal framing and a pipelined next request" do
    {server, port} = start_server()
    socket = connect(port)
    body = "value=" <> String.duplicate("x", 20_000)

    wire = [
      "POST /parse HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/x-www-form-urlencoded\r\nTransfer-Encoding: chunked\r\n\r\n",
      Integer.to_string(byte_size(body), 16),
      "\r\n",
      body,
      "\r\n0\r\nx-check: ok\r\n\r\n",
      "GET /status HTTP/1.1\r\nHost: localhost\r\n\r\n"
    ]

    :ok = :gen_tcp.send(socket, wire)
    assert {200, "20000", rest} = response(socket)
    assert {200, "ready", ""} = response(socket, rest)
    assert :ok = Gaoxy.stop(server)
  end

  test "independent H2 peer runs the real JSON/form parsers and parser limit" do
    {server, port} = start_server(protocols: [:http2], h2c: :prior_knowledge)
    root = Path.expand("../../..", __DIR__)
    python = System.get_env("GAOXY_H2_PYTHON") || Path.join(root, ".audit/h2peer/bin/python")

    {output, exit} =
      System.cmd(python, [Path.join(__DIR__, "support/plug_body_peer.py"), "h2", to_string(port)],
        cd: root,
        stderr_to_stdout: true
      )

    assert exit == 0, output
    IO.write(output)
    assert length(Regex.scan(~r/PASS H2 Plug parser/, output)) == 3, output
    assert :ok = Gaoxy.stop(server)
  end

  defp start_server(options \\ []) do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        [plug: {Gaoxy.PlugBodyFixture, []}, http_limits: %{request_timeout: 5_000}] ++ options
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {_, port}} = Gaoxy.info(server, :http).local
    {server, port}
  end

  defp connect(port) do
    {:ok, socket} = :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false], 1_000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    socket
  end

  defp request(path, type, body),
    do: [
      "POST ",
      path,
      " HTTP/1.1\r\nHost: localhost\r\nContent-Type: ",
      type,
      "\r\nContent-Length: ",
      to_string(byte_size(body)),
      "\r\n\r\n",
      body
    ]

  defp response(socket, buffer \\ "") do
    case :binary.split(buffer, "\r\n\r\n") do
      [head, body] ->
        [status_line | fields] = String.split(head, "\r\n")
        [_, status | _] = String.split(status_line, " ")

        length =
          Enum.find_value(fields, 0, fn line ->
            case String.split(line, ":", parts: 2) do
              [name, value] ->
                if String.downcase(name) == "content-length",
                  do: String.to_integer(String.trim(value))
            end
          end)

        if byte_size(body) >= length do
          <<value::binary-size(^length), rest::binary>> = body
          {String.to_integer(status), value, rest}
        else
          {:ok, bytes} = :gen_tcp.recv(socket, 0, 2_000)
          response(socket, buffer <> bytes)
        end

      [_] ->
        {:ok, bytes} = :gen_tcp.recv(socket, 0, 2_000)
        response(socket, buffer <> bytes)
    end
  end
end
