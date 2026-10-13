defmodule Gaoxy.HTTP2ControlRateTest do
  use ExUnit.Case, async: true

  alias Gaoxy.Lifecycle

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "control-rate")
  end

  @tag timeout: 10_000
  test "the production default allows exactly 256 control frames before GOAWAY 11" do
    assert_control_rate(%{}, 256)
  end

  @tag timeout: 10_000
  test "the selected fixture allows exactly 2048 control frames before GOAWAY 11" do
    assert_control_rate(%{control_rate: 2_048}, 2_048)
  end

  defp assert_control_rate(h2_limits, rate) do
    deadline = Lifecycle.deadline(5_000)

    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, nil},
               protocols: [:http2],
               h2c: :prior_knowledge,
               limits: %{max_bytes: 536_870_912, max_active: 128},
               h2_limits: h2_limits
             )

    assert spec.handler_options.h2_limits.control_rate == rate
    assert {:ok, runtime} = Gaoxy.start_link(services: [spec])
    on_exit(fn -> if Process.alive?(runtime), do: Gaoxy.stop(runtime, 1_000) end)
    assert {:ok, {ip, port}} = Gaoxy.info(runtime, :http).local

    [listener] =
      Enum.filter(:erlang.ports(), fn socket -> :inet.sockname(socket) == {:ok, {ip, port}} end)

    # Start before connecting: the server's one-second rate epoch starts later.
    started = Lifecycle.now()

    assert {:ok, socket} =
             :gen_tcp.connect(ip, port, [:binary, active: false], remaining(deadline))

    on_exit(fn -> :gen_tcp.close(socket) end)

    assert :ok =
             :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", frame(4, 0, "")])

    assert {4, 0, settings} = recv_frame(socket, deadline)
    assert byte_size(settings) > 0 and rem(byte_size(settings), 6) == 0
    assert :ok = :gen_tcp.send(socket, [frame(4, 1, ""), frame(6, 0, "initial!")])
    assert {4, 1, ""} = recv_frame(socket, deadline)
    assert {6, 1, "initial!"} = recv_frame(socket, deadline)

    # Client SETTINGS + its ACK of server SETTINGS + the initial PING = 3.
    # Valid connection WINDOW_UPDATEs add rate - 4; the barrier PING reaches rate.
    updates = List.duplicate(frame(8, 0, <<0::1, 1::31>>), rate - 4)
    assert :ok = :gen_tcp.send(socket, [updates, frame(6, 0, "at-limit")])
    assert {6, 1, "at-limit"} = recv_frame(socket, deadline)

    assert :ok = :gen_tcp.send(socket, frame(8, 0, <<0::1, 1::31>>))
    assert {7, 0, <<0::1, 0::31, 11::32, _debug::binary>>} = recv_frame(socket, deadline)

    assert Lifecycle.now() - started < 1_000,
           "the exact-count exchange crossed the server's one-second control-rate epoch"

    assert {:error, :closed} = :gen_tcp.recv(socket, 0, remaining(deadline))
    assert :ok = await_baseline(runtime, deadline)
    monitor = Process.monitor(runtime)
    assert :ok = Gaoxy.stop(runtime, remaining(deadline))
    assert_receive {:DOWN, ^monitor, :process, ^runtime, :normal}, remaining(deadline)
    assert {:error, _} = :inet.sockname(listener)

    result = :gen_tcp.listen(port, [:binary, ip: ip, active: false, reuseaddr: true])

    if match?({:error, _}, result) do
      IO.inspect({port, :inet.info(listener), System.cmd("ss", ["-tnap", "sport = :#{port}"])},
        label: "control-rate rebind diagnostic"
      )
    end

    assert {:ok, rebound} = result

    assert :ok = :gen_tcp.close(rebound)
    assert Lifecycle.remaining(deadline) > 0
  end

  defp await_baseline(runtime, deadline) do
    state = Gaoxy.status(runtime, :http)

    if state.active == 0 and state.retained_bytes == 0 and state.cleanup_pending == 0 and
         is_nil(state.cleanup_failed) do
      :ok
    else
      assert Lifecycle.remaining(deadline) > 0, inspect(state)

      receive do
      after
        1 -> await_baseline(runtime, deadline)
      end
    end
  end

  defp recv_frame(socket, deadline) do
    assert {:ok, <<length::24, type, flags, 0::1, 0::31>>} =
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
    do: <<byte_size(payload)::24, type, flags, 0::1, 0::31, payload::binary>>

  defp remaining(deadline) do
    remaining = Lifecycle.remaining(deadline)
    assert remaining > 0, "original control-rate test deadline expired"
    remaining
  end
end
