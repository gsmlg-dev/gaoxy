defmodule Gaoxy.DatagramEgressTest do
  use ExUnit.Case, async: true

  defmodule Forward do
    @behaviour Gaoxy.DatagramHandler
    def handle_datagram(%{data: bytes}, destination), do: {:send, destination, bytes}
  end

  defp events(runtime, id) do
    owner = self()
    reference = make_ref()
    %{generation: generation} = Gaoxy.handle(runtime, id)

    :ok =
      :telemetry.attach_many(
        reference,
        [[:gaoxy, :send], [:gaoxy, :admission_rejected]],
        fn event, measurements, metadata, _ ->
          if metadata.generation == generation,
            do: send(owner, {reference, event, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(reference) end)
    reference
  end

  @tag :loopback
  test "an IPv6 link-local destination without scope fails before submission" do
    ip = {0, 0, 0, 0, 0, 0, 0, 1}

    runtime =
      start_supervised!(
        {Gaoxy,
         services: [
           %{
             id: "scoped",
             transport: :udp,
             ip: ip,
             handler: Forward,
             handler_options: {{0xFE80, 0, 0, 0, 0, 0, 0, 1}, 49_999}
           }
         ]}
      )

    reference = events(runtime, "scoped")
    %{local: {^ip, port}} = Gaoxy.info(runtime, "scoped")
    {:ok, client} = :gen_udp.open(0, [:inet6, :binary, active: false, ip: ip])
    on_exit(fn -> :gen_udp.close(client) end)
    :ok = :gen_udp.send(client, ip, port, "scope")

    assert_receive {^reference, [:gaoxy, :send], %{bytes: 5},
                    %{outcome: {:error, :destination_scope_required}}},
                   2_000

    assert :ok = Gaoxy.stop(runtime, 1_000)
  end

  @tag :loopback
  test "addressed output is bounded and reports local outcomes without exposing the socket" do
    ip = {127, 0, 0, 1}
    {:ok, receiver} = :gen_udp.open(0, [:binary, active: false, ip: ip])
    {:ok, {^ip, target_port}} = :inet.sockname(receiver)
    {:ok, client} = :gen_udp.open(0, [:binary, active: false, ip: ip])

    on_exit(fn ->
      :gen_udp.close(receiver)
      :gen_udp.close(client)
    end)

    runtime =
      start_supervised!(
        {Gaoxy,
         services: [
           %{
             id: "bounded",
             transport: :udp,
             handler: Forward,
             handler_options: {ip, target_port},
             limits: %{max_output: 4, max_bytes: 6}
           }
         ]}
      )

    reference = events(runtime, "bounded")
    %{local: {^ip, port}} = Gaoxy.info(runtime, "bounded")

    :ok = :gen_udp.send(client, ip, port, "ok")
    assert {:ok, {^ip, ^port, "ok"}} = :gen_udp.recv(receiver, 0, 2_000)
    assert_receive {^reference, [:gaoxy, :send], %{bytes: 2}, %{outcome: :ok}}, 2_000

    for {bytes, reason} <- [{"12345", :output_limit}, {"1234", :byte_limit}] do
      quiescent(runtime, "bounded")
      :ok = :gen_udp.send(client, ip, port, bytes)

      assert_receive {^reference, [:gaoxy, :admission_rejected], %{count: 1}, %{reason: ^reason}},
                     2_000

      assert {:error, :timeout} = :gen_udp.recv(receiver, 0, 100)
    end

    :ok = :gen_udp.send(client, ip, port, "")
    assert {:ok, {^ip, ^port, ""}} = :gen_udp.recv(receiver, 0, 2_000)
    assert :ok = Gaoxy.stop(runtime, 1_000)
  end

  defp quiescent(runtime, id, deadline \\ nil) do
    deadline = deadline || System.monotonic_time(:millisecond) + 2_000

    if Gaoxy.status(runtime, id).active == 0 do
      :ok
    else
      assert System.monotonic_time(:millisecond) < deadline, "worker completion deadline"

      receive do
      after
        5 -> quiescent(runtime, id, deadline)
      end
    end
  end

  @tag :loopback
  @tag :capture_log
  test "addressed sends preserve empty datagrams and the listener's source port" do
    ip = {127, 0, 0, 1}
    {:ok, receiver} = :gen_udp.open(0, [:binary, active: false, ip: ip])
    {:ok, {^ip, destination_port}} = :inet.sockname(receiver)
    {:ok, sender} = :gen_udp.open(0, [:binary, active: false, ip: ip])

    on_exit(fn ->
      :gen_udp.close(receiver)
      :gen_udp.close(sender)
    end)

    runtime =
      start_supervised!(
        {Gaoxy,
         services: [
           %{
             id: "forward",
             transport: :udp,
             handler: Forward,
             handler_options: {ip, destination_port}
           }
         ]}
      )

    %{local: {^ip, port}} = Gaoxy.info(runtime, "forward")

    for packet <- ["", "directed"] do
      :ok = :gen_udp.send(sender, ip, port, packet)
      assert {:ok, {^ip, ^port, ^packet}} = :gen_udp.recv(receiver, 0, 2_000)
    end

    assert {:error, :timeout} = :gen_udp.recv(sender, 0, 100)
    assert :ok = Gaoxy.stop(runtime, 1_000)
  end
end
