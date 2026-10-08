defmodule CoreConsumerTest do
  use ExUnit.Case, async: true

  defmodule Echo do
    def init(_, _), do: {:ok, nil}
    def handle_data(bytes, state), do: {:send, bytes, state}
    def handle_datagram(%{data: bytes}, _), do: {:reply, bytes}
  end

  test "external core consumer exchanges TCP and UDP with no optional application installed" do
    forbidden = [:plug, :phoenix, :bandit, :http_fetch, :elixir_quic, :ex_ssl]

    for app <- forbidden do
      refute File.exists?(Path.join(Mix.Project.deps_path(), Atom.to_string(app)))
      assert {:error, :bad_name} = :code.lib_dir(app)
    end

    running = for {app, _, _} <- Application.started_applications(), do: app

    for app <- forbidden,
        do: refute(app in running)

    {:ok, instance} =
      Gaoxy.start_link(
        services: [
          %{id: "tcp", transport: :tcp, handler: Echo},
          %{id: "udp", transport: :udp, handler: Echo}
        ]
      )

    %{local: {:ok, {ip, tcp}}} = Gaoxy.info(instance, "tcp")
    %{local: {^ip, udp}} = Gaoxy.info(instance, "udp")
    {:ok, client} = :gen_tcp.connect(ip, tcp, [:binary, active: false], 1_000)
    :ok = :gen_tcp.send(client, "external")
    assert {:ok, "external"} = :gen_tcp.recv(client, 0, 1_000)
    :gen_tcp.close(client)
    {:ok, datagram} = :gen_udp.open(0, [:binary, active: false])
    :ok = :gen_udp.send(datagram, ip, udp, "")
    assert {:ok, {^ip, ^udp, ""}} = :gen_udp.recv(datagram, 0, 1_000)
    :gen_udp.close(datagram)
    assert :ok = Gaoxy.stop(instance, 1_000)
  end
end
