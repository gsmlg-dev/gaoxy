defmodule Gaoxy.Server.StandaloneGenerationTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Server.{Config, RouteConfig}

  test "data-only native HTTP services validate before starting configuration owners" do
    assert {:ok, options} = Config.decode(config())

    assert {:ok, %{services: [%{id: "web", handler: Gaoxy.HTTP.Connection}]}} =
             Gaoxy.Config.validate(options)

    refute Process.whereis(Gaoxy.Server.RouteStores)

    for invalid <- [
          put_in(config(), ["services", Access.at(0), "protocols"], ["invented"]),
          put_in(config(), ["services", Access.at(0), "transport"], "udp"),
          put_in(
            config(),
            ["services", Access.at(0), "routes", "routes", Access.at(0), "target", "type"],
            "System.cmd"
          ),
          put_in(config(), ["services", Access.at(0), "limits", "max_bytes"], 1)
        ] do
      assert {:error, _} = Config.decode(invalid)
    end
  end

  @tag :tmp_dir
  test "mixed standalone runtime reloads routes on one stable listener and rolls back invalid files",
       %{tmp_dir: dir} do
    data = config()

    data =
      update_in(
        data["services"],
        &(&1 ++ [%{"id" => "udp", "transport" => "udp", "handler" => "datagram_echo"}])
      )

    path = Path.join(dir, "config.json")
    File.write!(path, JSON.encode!(data))
    assert {:ok, options} = Config.load(path)
    assert Code.ensure_loaded?(Gaoxy.Server.Supervisor)
    start_supervised!({Gaoxy.Server.Supervisor, options})
    before = Gaoxy.info(Gaoxy.Server.Runtime, "web")
    assert request(before.local) =~ "\r\n\r\nold"
    %{local: {ip, port}} = Gaoxy.info(Gaoxy.Server.Runtime, "udp")
    {:ok, socket} = :gen_udp.open(0, [:binary, active: false])
    on_exit(fn -> :gen_udp.close(socket) end)
    :ok = :gen_udp.send(socket, ip, port, "")
    assert {:ok, {^ip, ^port, ""}} = :gen_udp.recv(socket, 0, 1_000)

    route_path = Path.join(dir, "routes.json")
    File.write!(route_path, JSON.encode!(routes("new")))
    assert {:ok, _generation} = apply(Gaoxy.Server, :reload_routes, ["web", route_path, 1_000])
    assert Gaoxy.info(Gaoxy.Server.Runtime, "web").local == before.local
    assert request(before.local) =~ "\r\n\r\nnew"

    File.write!(
      route_path,
      JSON.encode!(%{"version" => 1, "routes" => [%{"target" => %{"type" => "unknown"}}]})
    )

    assert {:error, _} = apply(Gaoxy.Server, :reload_routes, ["web", route_path, 1_000])
    assert request(before.local) =~ "\r\n\r\nnew"

    assert {:error, :unknown_http_service} =
             apply(Gaoxy.Server, :reload_routes, ["udp", route_path, 1_000])

    assert :ok = Gaoxy.stop(Gaoxy.Server.Runtime, 1_000)
    :ok = stop_supervised(Gaoxy.Server.Supervisor)
    refute Process.whereis(Gaoxy.Server.Runtime)
    refute Process.whereis(Gaoxy.Server.RouteStores)
    {:ok, {ip, port}} = before.local
    assert {:error, :econnrefused} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)

    assert {:ok, rebound} =
             :gen_tcp.listen(port, [:binary, active: false, ip: ip, reuseaddr: true])

    :gen_tcp.close(rebound)
  end

  test "failed mixed startup stops generation owners and releases the already-bound HTTP port" do
    Process.flag(:trap_exit, true)
    {:ok, tcp} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {ip, port}} = :inet.sockname(tcp)
    :gen_tcp.close(tcp)
    {:ok, udp} = :gen_udp.open(0, [:binary, active: false, ip: ip])
    on_exit(fn -> :gen_udp.close(udp) end)
    {:ok, {_, occupied}} = :inet.sockname(udp)
    data = config()
    data = put_in(data, ["services", Access.at(0), "port"], port)

    data =
      update_in(
        data["services"],
        &(&1 ++
            [
              %{
                "id" => "blocked",
                "transport" => "udp",
                "port" => occupied,
                "handler" => "datagram_echo"
              }
            ])
      )

    assert {:ok, options} = Config.decode(data)
    assert Code.ensure_loaded?(Gaoxy.Server.Supervisor)
    assert {:error, _} = apply(Gaoxy.Server.Supervisor, :start_link, [options])
    refute Process.whereis(Gaoxy.Server.RouteStores)
    refute Process.whereis(Gaoxy.Server.Runtime)
    assert {:error, :econnrefused} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)

    assert {:ok, rebound} =
             :gen_tcp.listen(port, [:binary, active: false, ip: ip, reuseaddr: true])

    :gen_tcp.close(rebound)
  end

  @tag :tmp_dir
  test "oversized standalone files fail before decoding or opening services", %{tmp_dir: dir} do
    path = Path.join(dir, "large.json")
    File.write!(path, String.duplicate(" ", 1_048_577))
    assert {:error, :configuration_too_large} = Config.load(path)
    assert {:ok, _} = RouteConfig.decode(routes("ok"))
  end

  defp config do
    %{
      "version" => 1,
      "services" => [
        %{
          "id" => "web",
          "transport" => "tcp",
          "handler" => "http",
          "routes" => routes("old"),
          "limits" => %{"max_bytes" => 8_388_608}
        }
      ]
    }
  end

  defp routes(body),
    do: %{"version" => 1, "routes" => [%{"target" => %{"type" => "static", "body" => body}}]}

  defp request({:ok, {ip, port}}) do
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)

    try do
      :ok =
        :gen_tcp.send(socket, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")

      receive_all(socket, "")
    after
      :gen_tcp.close(socket)
    end
  end

  defp receive_all(socket, bytes) do
    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, more} -> receive_all(socket, bytes <> more)
      {:error, :closed} -> bytes
    end
  end
end
