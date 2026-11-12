defmodule Gaoxy.HTTP2DrainGoawayTest do
  use ExUnit.Case, async: true

  alias Gaoxy.Lifecycle

  defmodule Endpoint do
    def init(options), do: {:ok, options}

    def call(exchange, test) do
      send(test, :executed)
      Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "done")
    end
  end

  @tag timeout: 15_000
  test "a drain GOAWAY covers every stream the endpoint runs" do
    for _round <- 1..5 do
      deadline = Lifecycle.deadline(5_000)

      assert {:ok, spec} =
               Gaoxy.HTTP.service_spec(
                 endpoint: {Endpoint, self()},
                 protocols: [:http2],
                 h2c: :prior_knowledge,
                 limits: %{max_bytes: 536_870_912, max_active: 128}
               )

      assert {:ok, runtime} = Gaoxy.start_link(services: [spec])
      assert {:ok, {ip, port}} = Gaoxy.info(runtime, :http).local

      assert {:ok, socket} =
               :gen_tcp.connect(ip, port, [:binary, active: false], remaining(deadline))

      authority = "127.0.0.1:#{port}"
      block = <<0x82, 0x86, 0x84, 0x01, byte_size(authority), authority::binary>>
      requests = for index <- 1..32, do: frame(1, 5, index * 2 - 1, block)

      assert :ok =
               :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", frame(4, 0, 0, "")])

      # The server's SETTINGS prove the connection is running before the drain.
      assert {:ok, <<length::24, 4, 0, 0::32>>} = :gen_tcp.recv(socket, 9, remaining(deadline))
      assert {:ok, _settings} = :gen_tcp.recv(socket, length, remaining(deadline))
      assert :ok = :gen_tcp.send(socket, [frame(4, 1, 0, ""), requests])

      # Drain once the first stream is answered: later ones are admitted but
      # still queued behind worker startup.
      first = first_answer(socket, deadline)
      assert :ok = Gaoxy.stop(runtime, remaining(deadline))
      {last, answered} = collect(socket, deadline, nil, [first])
      :gen_tcp.close(socket)

      assert is_integer(last), "the drain sent no GOAWAY"
      assert Enum.filter(answered, &(&1 > last)) == []
      # A stream above the advertised id may be retried elsewhere by the client,
      # so the endpoint must not have run for any stream that got no answer.
      assert executed(0) == length(answered)
    end
  end

  defp executed(count) do
    receive do
      :executed -> executed(count + 1)
    after
      100 -> count
    end
  end

  defp first_answer(socket, deadline) do
    assert {:ok, <<length::24, type, _flags, 0::1, id::31>>} =
             :gen_tcp.recv(socket, 9, remaining(deadline))

    if length > 0, do: assert({:ok, _} = :gen_tcp.recv(socket, length, remaining(deadline)))
    if type == 1, do: id, else: first_answer(socket, deadline)
  end

  defp collect(socket, deadline, last, answered) do
    case :gen_tcp.recv(socket, 9, remaining(deadline)) do
      {:ok, <<length::24, type, _flags, 0::1, id::31>>} ->
        payload =
          if length == 0 do
            ""
          else
            assert {:ok, bytes} = :gen_tcp.recv(socket, length, remaining(deadline))
            bytes
          end

        case {type, payload} do
          {7, <<0::1, last::31, 0::32, _::binary>>} -> collect(socket, deadline, last, answered)
          {1, _} -> collect(socket, deadline, last, [id | answered])
          _ -> collect(socket, deadline, last, answered)
        end

      {:error, :closed} ->
        {last, answered}
    end
  end

  defp frame(type, flags, id, payload),
    do: <<byte_size(payload)::24, type, flags, 0::1, id::31, payload::binary>>

  defp remaining(deadline) do
    remaining = Lifecycle.remaining(deadline)
    assert remaining > 0, "drain GOAWAY test deadline expired"
    remaining
  end
end
