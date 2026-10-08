defmodule Gaoxy.BackendTelemetryTest do
  use ExUnit.Case, async: true
  @moduletag :loopback

  defmodule Packet do
    @behaviour Gaoxy.DatagramHandler
    def handle_datagram(packet, owner) do
      send(owner, {:admitted, packet.data})
      {:reply, packet.data}
    end
  end

  test "backend oversize and paused drops carry the correct instance and generation" do
    spec = %{
      id: "shared",
      transport: :udp,
      handler: Packet,
      handler_options: self(),
      limits: %{max_packet: 4}
    }

    a = start_supervised!({Gaoxy, services: [spec]})
    b = start_supervised!({Gaoxy, services: [spec]})

    on_exit(fn ->
      for runtime <- [a, b], Process.alive?(runtime), do: Gaoxy.stop(runtime, 0)
    end)

    %{generation: generation_a, local: {ip, port}} = Gaoxy.info(a, "shared")
    %{generation: generation_b} = Gaoxy.info(b, "shared")
    owner = self()
    reference = make_ref()

    :ok =
      :telemetry.attach(
        reference,
        [:gaoxy, :admission_rejected],
        fn _, measurements, metadata, _ ->
          if metadata.generation in [generation_a, generation_b],
            do: send(owner, {reference, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(reference) end)
    {:ok, client} = :gen_udp.open(0, [:binary, active: false])
    on_exit(fn -> :gen_udp.close(client) end)
    :ok = :gen_udp.send(client, ip, port, "12345")

    assert_receive {^reference, %{count: 1, bytes: 5},
                    %{
                      generation: ^generation_a,
                      service: "shared",
                      source: :backend,
                      reason: :packet_too_large
                    }},
                   2_000

    :ok = Gaoxy.pause(a, "shared")
    :ok = :gen_udp.send(client, ip, port, "four")

    assert_receive {^reference, %{count: 1, bytes: 4},
                    %{generation: ^generation_a, source: :backend, reason: :paused}},
                   2_000

    assert %{active: 0, retained_bytes: 0, backend: %{dropped: 2}} = Gaoxy.status(a, "shared")
    assert %{backend: %{dropped: 0}} = Gaoxy.status(b, "shared")
    refute_receive {:admitted, _}, 100
    refute_receive {^reference, _, %{generation: ^generation_b}}, 100
  end
end
