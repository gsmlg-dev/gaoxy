defmodule Gaoxy.Server.RouteResourcesTest do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.{Generation, Router}
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.UpstreamTransports
  alias Gaoxy.Server.{Config, RouteResources, UpstreamEndpoint}
  @moduletag :capture_log

  defmodule RejectedCandidate do
    def init(test) do
      send(test, {:candidate_ready, self()})

      receive do
        :reject_candidate -> {:error, :rejected_candidate}
      after
        2000 -> {:error, :gate_timeout}
      end
    end

    def call(exchange, _), do: {:ok, exchange}
  end

  test "startup preserves compiled exact paths and method sets" do
    routes = [
      %{"path" => "/exact", "methods" => ["GET"], "target" => static("matched")},
      %{"target" => static("fallback")}
    ]

    assert {:ok, options} = Config.decode(config(routes))
    start_supervised!({Gaoxy.Server.Supervisor, options})
    local = Gaoxy.info(Gaoxy.Server.Runtime, "web").local
    assert request(local, "GET", "/exact") =~ "\r\n\r\nmatched"
    assert request(local, "POST", "/exact") =~ "\r\n\r\nfallback"
    assert request(local, "GET", "/other") =~ "\r\n\r\nfallback"
  end

  test "unconfirmed candidate preparation releases block activation until reconciled" do
    assert {:ok, options} = Config.decode(config([%{"target" => static("old")}]))
    start_supervised!({Gaoxy.Server.Supervisor, options})
    store = Gaoxy.Server.Supervisor.route_store("web")
    assert {:ok, expected, original} = Generation.snapshot(store)

    assert {:ok, target} =
             UpstreamEndpoint.fixed(%{
               "upstream" => "http://127.0.0.1:9000",
               "managed" => true
             })

    candidate = %Router{routes: [%{target: target}, %{target: {RejectedCandidate, self()}}]}
    test = self()

    spawn_link(fn ->
      send(
        test,
        {:activation_result,
         RouteResources.activate(store, expected, candidate, Lifecycle.deadline(3000))}
      )
    end)

    assert_receive {:candidate_ready, coordinator}, 2000

    [{_, owner, _, _}] =
      Enum.filter(DynamicSupervisor.which_children(Gaoxy.Server.UpstreamOwners), fn
        {_, _, _, modules} -> UpstreamTransports in modules
      end)

    assert {:ok, %{pins: 1}} = UpstreamTransports.status(owner)
    :ok = :sys.suspend(owner)

    try do
      send(coordinator, :reject_candidate)
      assert_receive {:activation_result, {:error, :rejected_candidate}}, 2000
      assert {:ok, ^expected, _} = Generation.snapshot(store)

      assert {:error, :resource_release_pending} =
               RouteResources.activate(store, expected, original, Lifecycle.deadline(2000))
    after
      if Process.alive?(owner), do: :sys.resume(owner)
    end

    await_reconciled(Lifecycle.deadline(2000))
    assert {:ok, %{pins: 0}} = UpstreamTransports.status(owner)
    assert {:ok, _} = RouteResources.activate(store, expected, original, Lifecycle.deadline(2000))
  end

  defp await_reconciled(deadline) do
    case :sys.get_state(RouteResources).pending_pins do
      [] ->
        :ok

      _ ->
        assert Lifecycle.remaining(deadline) > 0

        receive do
        after
          10 -> await_reconciled(deadline)
        end
    end
  end

  defp static(body), do: %{"type" => "static", "body" => body}

  defp config(routes),
    do: %{
      "version" => 1,
      "services" => [
        %{
          "id" => "web",
          "transport" => "tcp",
          "handler" => "http",
          "limits" => %{"max_bytes" => 67_108_864},
          "routes" => %{"version" => 1, "routes" => routes}
        }
      ]
    }

  defp request({:ok, {ip, port}}, method, path) do
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)

    try do
      :ok =
        :gen_tcp.send(socket, [
          method,
          " ",
          path,
          " HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\nContent-Length: 0\r\n\r\n"
        ])

      read(socket, "")
    after
      :gen_tcp.close(socket)
    end
  end

  defp read(socket, bytes) do
    case :gen_tcp.recv(socket, 0, 2000) do
      {:ok, more} -> read(socket, bytes <> more)
      {:error, :closed} -> bytes
    end
  end
end
