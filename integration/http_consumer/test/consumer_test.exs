defmodule HTTPConsumerTest do
  use ExUnit.Case, async: true

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "consumer")
  end

  test "H1/H2 consumer resolves and starts without optional QUIC or proxy applications" do
    forbidden = [
      :thousand_island,
      :gaoxy_http3,
      :elixir_quic,
      :elixir_quic_http3,
      :ex_ssl,
      :http_fetch,
      :bandit
    ]

    resolved = for dependency <- Mix.Dep.load_and_cache(), do: dependency.app
    running = for {app, _, _} <- Application.started_applications(), do: app

    assert :hell in resolved
    assert :hell in running
    assert :gaoxy_http in resolved
    assert :gaoxy_http in running

    for app <- forbidden do
      refute app in resolved
      refute app in running
      assert {:error, :bad_name} = :code.lib_dir(app)
      refute File.exists?(Path.join(Mix.Project.deps_path(), Atom.to_string(app)))
    end
  end

  test "the clean consumer serves native H1 and H2 through the public endpoint" do
    {:ok, h1_spec} =
      Gaoxy.HTTP.service_spec(id: :h1, endpoint: {Endpoint, nil})

    {:ok, h2_spec} =
      Gaoxy.HTTP.service_spec(
        id: :h2,
        endpoint: {Endpoint, nil},
        protocols: [:http2],
        h2c: :prior_knowledge,
        limits: %{max_bytes: 536_870_912}
      )

    {:ok, instance} = Gaoxy.start_link(services: [h1_spec, h2_spec])
    on_exit(fn -> if Process.alive?(instance), do: Gaoxy.stop(instance, 1_000) end)
    %{local: {:ok, {ip, h1_port}}} = Gaoxy.info(instance, :h1)
    %{local: {:ok, {^ip, h2_port}}} = Gaoxy.info(instance, :h2)

    {:ok, h1} = :gen_tcp.connect(ip, h1_port, [:binary, active: false], 1_000)
    :ok = :gen_tcp.send(h1, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    response = receive_h1(h1, "")
    assert response =~ "HTTP/1.1 200"
    assert String.ends_with?(response, "consumer")
    :gen_tcp.close(h1)

    {:ok, h2} = :gen_tcp.connect(ip, h2_port, [:binary, active: false], 1_000)

    {block, _} =
      HPAX.encode(
        :never_store,
        [{":method", "GET"}, {":scheme", "http"}, {":authority", "localhost"}, {":path", "/"}],
        HPAX.new(0)
      )

    :ok =
      :gen_tcp.send(h2, [
        "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n",
        frame(4, 0, 0, ""),
        frame(1, 5, 1, IO.iodata_to_binary(block))
      ])

    assert {"200", "consumer"} = receive_h2(h2, HPAX.new(4_096), nil, "")
    :gen_tcp.close(h2)
    assert :ok = Gaoxy.stop(instance, 1_000)
  end

  defp receive_h1(socket, bytes) do
    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, more} -> receive_h1(socket, bytes <> more)
      {:error, :closed} -> bytes
    end
  end

  defp receive_h2(socket, decoder, status, body) do
    assert {:ok, <<size::24, type, flags, _::1, id::31>>} = :gen_tcp.recv(socket, 9, 1_000)

    payload =
      if size == 0 do
        ""
      else
        assert {:ok, bytes} = :gen_tcp.recv(socket, size, 1_000)
        bytes
      end

    case {type, id} do
      {4, 0} ->
        if Bitwise.band(flags, 1) == 0, do: :gen_tcp.send(socket, frame(4, 1, 0, ""))
        receive_h2(socket, decoder, status, body)

      {1, 1} ->
        assert {:ok, fields, decoder} = HPAX.decode(payload, decoder)
        status = List.keyfind(fields, ":status", 0) |> elem(1)

        if Bitwise.band(flags, 1) == 1,
          do: {status, body},
          else: receive_h2(socket, decoder, status, body)

      {0, 1} ->
        body = body <> payload

        if Bitwise.band(flags, 1) == 1,
          do: {status, body},
          else: receive_h2(socket, decoder, status, body)

      other ->
        flunk("unexpected H2 frame #{inspect(other)}")
    end
  end

  defp frame(type, flags, id, payload),
    do: <<byte_size(payload)::24, type, flags, 0::1, id::31, payload::binary>>
end
