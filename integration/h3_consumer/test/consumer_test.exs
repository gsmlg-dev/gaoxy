defmodule H3ConsumerTest do
  use ExUnit.Case, async: true

  defmodule ConsumerPlug do
    def init(options), do: options

    def call(conn, _) do
      "HTTP/3" = to_string(Plug.Conn.get_http_protocol(conn))
      {conn, body} = if conn.request_path == "/echo", do: read(conn, ""), else: {conn, "consumer"}
      Plug.Conn.send_resp(conn, 200, body)
    end

    defp read(conn, body) do
      case Plug.Conn.read_body(conn, length: 1_048_576, read_length: 4_096, read_timeout: 3_000) do
        {:more, bytes, conn} -> read(conn, body <> bytes)
        {:ok, bytes, conn} -> {conn, body <> bytes}
      end
    end
  end

  test "explicit H3 consumer resolves without proxy, Phoenix or production-server dependencies" do
    resolved = for dependency <- Mix.Dep.load_and_cache(), do: dependency.app
    running = for {app, _, _} <- Application.started_applications(), do: app

    for app <- [:gaoxy_http3, :elixir_quic, :elixir_quic_http3] do
      assert app in resolved
      assert app in running
    end

    for app <- [:gaoxy_proxy, :gaoxy_server, :http_fetch, :phoenix, :phoenix_live_view, :bandit] do
      refute app in resolved
      refute app in running
      assert {:error, :bad_name} = :code.lib_dir(app)
      refute File.exists?(Path.join(Mix.Project.deps_path(), Atom.to_string(app)))
    end
  end

  @tag timeout: 30_000
  test "a clean H3 consumer serves an independently decoded verified-CA request and DATA upload" do
    directory = System.fetch_env!("GAOXY_H3_CONSUMER_CERT_DIR")

    {:ok, spec} =
      Gaoxy.HTTP.HTTP3.service_spec(
        id: :consumer,
        ip: {127, 0, 0, 1},
        port: 0,
        plug: {ConsumerPlug, []},
        tls: %{
          certfile: Path.join(directory, "cert.pem"),
          keyfile: Path.join(directory, "key.pem")
        }
      )

    {:ok, runtime} = Gaoxy.start_link(services: [spec])
    on_exit(fn -> if Process.alive?(runtime), do: Gaoxy.stop(runtime, 5_000) end)
    %{local: {:ok, {ip, port}}} = Gaoxy.info(runtime, :consumer)

    {output, exit} =
      System.cmd(
        System.fetch_env!("GAOXY_H3_CONSUMER_PYTHON"),
        [
          Path.expand("peer.py"),
          "--port",
          to_string(port),
          "--ca",
          Path.join(directory, "ca.pem")
        ],
        stderr_to_stdout: true
      )

    assert exit == 0, output
    assert output =~ "H3_CONSUMER_PASS cases=2 verified_ca=true protocol=h3"
    assert :ok = await_baseline(runtime, Gaoxy.Lifecycle.deadline(3_000))
    monitor = Process.monitor(runtime)
    assert :ok = Gaoxy.stop(runtime, 5_000)
    assert_receive {:DOWN, ^monitor, :process, ^runtime, _}, 1_000
    assert {:ok, socket} = :gen_udp.open(port, [:binary, ip: ip])
    assert :ok = :gen_udp.close(socket)
  end

  defp await_baseline(runtime, deadline) do
    state = Gaoxy.status(runtime, :consumer)

    if state.active == 0 and state.retained_bytes == 0 and state.cleanup_pending == 0 and
         is_nil(state.cleanup_failed) do
      :ok
    else
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(state)

      receive do
      after
        1 -> await_baseline(runtime, deadline)
      end
    end
  end
end
