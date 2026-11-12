defmodule Gaoxy.HTTP2PartialFrameProgressTest do
  use ExUnit.Case, async: true

  alias Gaoxy.Lifecycle

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "ok")
  end

  @frame_timeout 300

  @tag timeout: 10_000
  test "frames that each complete promptly survive deliveries that always end mid-frame" do
    {socket, deadline} = connect()

    pings = for index <- 1..15, do: frame(6, 0, <<index::64>>)
    <<head::binary-size(5), carry::binary>> = hd(pings)
    assert :ok = :gen_tcp.send(socket, head)

    # Every write finishes the pending frame and starts the next one, so the
    # connection stays mid-frame for three frame timeouts while making progress.
    last =
      Enum.reduce(tl(pings), carry, fn <<head::binary-size(5), carry::binary>>, pending ->
        pause(div(@frame_timeout, 5))
        assert :ok = :gen_tcp.send(socket, [pending, head])
        carry
      end)

    assert :ok = :gen_tcp.send(socket, last)

    for index <- 1..15 do
      assert {6, 1, <<^index::64>>} = recv_frame(socket, deadline)
    end
  end

  @tag timeout: 10_000
  test "a frame that stays incomplete past the frame timeout closes the connection" do
    {socket, deadline} = connect()

    <<head::binary-size(5), _::binary>> = frame(6, 0, "stalled!")
    assert :ok = :gen_tcp.send(socket, head)
    assert {7, 0, <<_::32, 1::32, _::binary>>} = recv_frame(socket, deadline)
  end

  defp connect do
    deadline = Lifecycle.deadline(5_000)

    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, nil},
               protocols: [:http2],
               h2c: :prior_knowledge,
               limits: %{max_bytes: 536_870_912, max_active: 128},
               h2_limits: %{frame_timeout: @frame_timeout}
             )

    assert {:ok, runtime} = Gaoxy.start_link(services: [spec])
    on_exit(fn -> if Process.alive?(runtime), do: Gaoxy.stop(runtime, 1_000) end)
    assert {:ok, {ip, port}} = Gaoxy.info(runtime, :http).local

    assert {:ok, socket} =
             :gen_tcp.connect(
               ip,
               port,
               [:binary, active: false, nodelay: true],
               remaining(deadline)
             )

    on_exit(fn -> :gen_tcp.close(socket) end)
    assert :ok = :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", frame(4, 0, "")])
    assert {4, 0, _settings} = recv_frame(socket, deadline)
    assert :ok = :gen_tcp.send(socket, frame(4, 1, ""))
    assert {4, 1, ""} = recv_frame(socket, deadline)
    {socket, deadline}
  end

  defp pause(milliseconds) do
    receive do
    after
      milliseconds -> :ok
    end
  end

  defp recv_frame(socket, deadline) do
    assert {:ok, <<length::24, type, flags, _::32>>} =
             :gen_tcp.recv(socket, 9, remaining(deadline))

    payload =
      if length == 0 do
        ""
      else
        assert {:ok, bytes} = :gen_tcp.recv(socket, length, remaining(deadline))
        bytes
      end

    {type, flags, payload}
  end

  defp frame(type, flags, payload),
    do: <<byte_size(payload)::24, type, flags, 0::32, payload::binary>>

  defp remaining(deadline) do
    remaining = Lifecycle.remaining(deadline)
    assert remaining > 0, "partial frame progress test deadline expired"
    remaining
  end
end
