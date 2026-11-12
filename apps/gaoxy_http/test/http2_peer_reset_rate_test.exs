defmodule Gaoxy.HTTP2PeerResetRateTest do
  use ExUnit.Case, async: true

  alias Gaoxy.Lifecycle

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    # Keep every stream open so a later frame on it is a protocol violation.
    def call(_exchange, _), do: Process.sleep(:infinity)
  end

  @tag timeout: 10_000
  test "resets provoked on live streams count against the control rate" do
    {socket, authority, deadline} = connect()

    # Each pair opens a request and violates it with DATA after END_STREAM.
    assert :ok = :gen_tcp.send(socket, Enum.map(1..300, &violation(&1, authority)))

    assert {:goaway, 11, resets} = collect(socket, deadline, 0, 300)
    assert resets <= 256
  end

  @tag timeout: 10_000
  test "a bounded number of provoked resets leaves the connection usable" do
    {socket, authority, deadline} = connect()

    assert :ok = :gen_tcp.send(socket, Enum.map(1..100, &violation(&1, authority)))
    assert {:resets, 100} = collect(socket, deadline, 0, 100)

    assert :ok = :gen_tcp.send(socket, frame(6, 0, 0, "survives"))
    assert {:ping, "survives"} = collect(socket, deadline, 0, 1)
  end

  defp connect do
    deadline = Lifecycle.deadline(5_000)

    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, nil},
               protocols: [:http2],
               h2c: :prior_knowledge,
               limits: %{max_bytes: 536_870_912, max_active: 128}
             )

    assert spec.handler_options.h2_limits.control_rate == 256
    assert {:ok, runtime} = Gaoxy.start_link(services: [spec])
    on_exit(fn -> if Process.alive?(runtime), do: Gaoxy.stop(runtime, 1_000) end)
    assert {:ok, {ip, port}} = Gaoxy.info(runtime, :http).local

    assert {:ok, socket} =
             :gen_tcp.connect(ip, port, [:binary, active: false], remaining(deadline))

    on_exit(fn -> :gen_tcp.close(socket) end)

    assert :ok =
             :gen_tcp.send(socket, [
               "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n",
               frame(4, 0, 0, ""),
               frame(4, 1, 0, "")
             ])

    {socket, "127.0.0.1:#{port}", deadline}
  end

  defp violation(index, authority) do
    id = index * 2 - 1
    # :method GET, :scheme http, :path /, literal :authority without indexing.
    block = <<0x82, 0x86, 0x84, 0x01, byte_size(authority), authority::binary>>
    [frame(1, 5, id, block), frame(0, 0, id, "")]
  end

  defp collect(socket, deadline, resets, wanted) do
    case recv_frame(socket, deadline) do
      {7, _, <<_::32, code::32, _::binary>>} -> {:goaway, code, resets}
      {6, 1, payload} -> {:ping, payload}
      {3, _, _} when resets + 1 == wanted -> {:resets, wanted}
      {3, _, _} -> collect(socket, deadline, resets + 1, wanted)
      _ -> collect(socket, deadline, resets, wanted)
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

  defp frame(type, flags, id, payload),
    do: <<byte_size(payload)::24, type, flags, 0::1, id::31, payload::binary>>

  defp remaining(deadline) do
    remaining = Lifecycle.remaining(deadline)
    assert remaining > 0, "peer reset rate test deadline expired"
    remaining
  end
end
