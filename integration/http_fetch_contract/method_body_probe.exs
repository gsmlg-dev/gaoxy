results =
  for method <- [:post, :delete, :get] do
    parent = self()

    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])

    {:ok, {_, port}} = :inet.sockname(listener)

    {_pid, monitor} =
      spawn_monitor(fn ->
        {:ok, socket} = :gen_tcp.accept(listener, 2_000)

        read_head = fn recurse, buffer ->
          case :binary.split(buffer, "\r\n\r\n") do
            [head, tail] ->
              {head, tail}

            [_] ->
              {:ok, next} = :gen_tcp.recv(socket, 0, 2_000)
              recurse.(recurse, buffer <> next)
          end
        end

        {head, tail} = read_head.(read_head, "")

        length =
          case Regex.run(~r/\r\ncontent-length: (\d+)/i, head) do
            [_, n] -> String.to_integer(n)
            nil -> 0
          end

        body =
          if byte_size(tail) < length do
            {:ok, rest} = :gen_tcp.recv(socket, length - byte_size(tail), 2_000)
            tail <> rest
          else
            tail
          end

        send(parent, {:wire, method, head, body})

        :ok =
          :gen_tcp.send(
            socket,
            "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"
          )

        :gen_tcp.close(socket)
        :gen_tcp.close(listener)
      end)

    # TODO(upstream): gsmlg-dev/http_fetch#45 - preserve admitted request bodies.
    response =
      HTTP.fetch("http://127.0.0.1:#{port}/",
        method: method,
        headers: [{"content-length", "3"}],
        body: "abc",
        redirect: :manual,
        http_version: :http1,
        telemetry: false,
        timeout: 2_000
      )
      |> HTTP.Promise.await(3_000)

    preserved =
      receive do
        {:wire, ^method, head, body} ->
          IO.puts(
            JSON.encode!(%{
              method: method,
              status: response.status,
              received_head: head,
              expected_body: "abc",
              actual_body: body,
              preserved: body == "abc"
            })
          )

          body == "abc"
      after
        1_000 -> raise "peer did not report request"
      end

    receive do
      {:DOWN, ^monitor, :process, _, :normal} -> :ok
    after
      1_000 -> raise "peer did not stop"
    end

    preserved
  end

if not Enum.all?(results), do: System.halt(1)
