defmodule Gaoxy.Proxy.GatewayTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.Gateway
  alias Gaoxy.Proxy.Gateway.Upstream
  alias Gaoxy.HTTP.Router
  @moduletag :capture_log

  defmodule Endpoint do
    def init(body), do: {:ok, body}
    def call(exchange, body), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], body)
  end

  defmodule Blocked do
    def init(body) do
      send(Process.whereis(Gaoxy.Proxy.GatewayTest.Gate), {:preparing, self()})

      receive do
        :continue -> {:ok, body}
      after
        3000 -> {:error, :gate_timeout}
      end
    end

    def call(exchange, body), do: Endpoint.call(exchange, body)
  end

  test "pure plans retain file references and never initialize route endpoints" do
    assert {:ok, target} =
             Upstream.fixed(%{
               upstream: "https://example.test",
               connect_address: {127, 0, 0, 1},
               cacertfile: "/does/not/exist"
             })

    options = options("web", [%{target: target}, %{target: {Blocked, "never initialized"}}])
    assert {:ok, first} = Gateway.compile(options)
    assert {:ok, ^first} = Gateway.compile(options)
    assert {:ok, ^first} = Gateway.compile(first)
    assert Gaoxy.Proxy.Gateway.Declaration.owner_independent?(first)
    refute_receive {:preparing, _}
    assert {:error, _} = Gateway.compile(options("web", [%{target: {Endpoint, self()}}]))

    for invalid <- [
          [id: nil],
          [id: :ok, name: "invalid"],
          [services: [%{}]],
          %Gaoxy.Proxy.Gateway.Plan{sets: :invalid}
        ] do
      assert {:error, _} = Gateway.compile(invalid)
    end
  end

  @tag :tmp_dir
  test "invalid trust files produce a structured preparation error", %{tmp_dir: dir} do
    path = Path.join(dir, "empty.pem")

    for bytes <- ["", "not a certificate"] do
      File.write!(path, bytes)

      assert {:ok, {_, declaration}} =
               Upstream.fixed(%{
                 upstream: "https://localhost:443",
                 connect_address: {127, 0, 0, 1},
                 cacertfile: path
               })

      assert {:error, :invalid_trust} = Upstream.materialize(declaration)
    end
  end

  test "two gateways share IDs while routes, owners and stop remain isolated" do
    a = start_supervised!({Gateway, options("web", routes("one"))}, id: :a)
    b = start_supervised!({Gateway, options("web", routes("two"))}, id: :b)
    assert %{phase: :ready, listener_sets: %{"web" => %{revision: 1}}} = Gateway.info(a)
    assert body(a) == "one"
    assert body(b) == "two"

    assert {:ok, %{revision: 2}} =
             Gateway.reload_routes(a, "web", routes("new"), expected_revision: 1, timeout: 2000)

    assert body(a) == "new"
    assert body(b) == "two"

    assert {:error, :stale_revision} =
             Gateway.reload_routes(a, "web", routes("stale"), expected_revision: 1, timeout: 2000)

    monitor = Process.monitor(a)
    assert :ok = Gateway.stop(a, 3000)
    assert_receive {:DOWN, ^monitor, :process, ^a, :normal}, 1000
    refute Process.alive?(a)
    assert body(b) == "two"
  end

  test "accepted managed routes survive owner recovery and allow another reload" do
    origin = start_supervised!({Gaoxy.HTTP, id: :origin, endpoint: {Endpoint, "upstream"}})
    {:ok, {_, port}} = Gaoxy.info(origin, :origin).local
    assert {:ok, target} = Upstream.fixed(%{upstream: "http://127.0.0.1:#{port}"})
    gateway = start_supervised!({Gateway, options("web", routes("startup"))})

    assert {:ok, %{revision: 2}} =
             Gateway.reload_routes(gateway, "web", [%{target: target}],
               expected_revision: 1,
               timeout: 3000
             )

    assert body(gateway) == "upstream"
    before = Gateway.info(gateway)
    %{transports: owner} = :sys.get_state(before.coordinator)
    Process.exit(owner, :kill)

    await(fn ->
      case Gateway.info(gateway) do
        %{phase: :ready, runtime_epoch: epoch} -> epoch != before.runtime_epoch
        _ -> false
      end
    end)

    assert %{listener_sets: %{"web" => %{revision: 2}}} = Gateway.info(gateway)
    assert body(gateway) == "upstream"

    assert {:ok, %{revision: 3}} =
             Gateway.reload_routes(gateway, "web", routes("final"),
               expected_revision: 2,
               timeout: 3000
             )

    assert body(gateway) == "final"
  end

  test "caller loss after owned submission leaves a committed, reconcilable receipt" do
    Process.register(self(), Gaoxy.Proxy.GatewayTest.Gate)
    gateway = start_supervised!({Gateway, options("web", routes("old"))})
    operation = make_ref()

    caller =
      spawn(fn ->
        Gateway.reload_routes(gateway, "web", [%{target: {Blocked, "accepted"}}],
          expected_revision: 1,
          timeout: 2500,
          operation_id: operation
        )
      end)

    assert_receive {:preparing, worker}, 1000
    Process.exit(caller, :kill)
    send(worker, :continue)

    await(fn ->
      match?({:ok, %{status: :committed}}, Gateway.operation_status(gateway, {"web", operation}))
    end)

    assert body(gateway) == "accepted"

    assert {:ok, %{revision: 2}} =
             Gateway.reload_routes(gateway, "web", [%{target: {Blocked, "accepted"}}],
               expected_revision: 1,
               timeout: 1000,
               operation_id: operation
             )

    assert {:error, :operation_conflict} =
             Gateway.reload_routes(gateway, "web", routes("different"),
               expected_revision: 2,
               timeout: 1000,
               operation_id: operation
             )
  end

  test "an expired preparation cannot become accepted and its outcome is inspectable" do
    Process.register(self(), Gaoxy.Proxy.GatewayTest.Gate)
    gateway = start_supervised!({Gateway, options("web", routes("old"))})
    operation = make_ref()
    test = self()

    spawn(fn ->
      send(
        test,
        {:reload,
         Gateway.reload_routes(gateway, "web", [%{target: {Blocked, "expired"}}],
           expected_revision: 1,
           timeout: 150,
           operation_id: operation
         )}
      )
    end)

    assert_receive {:preparing, _worker}, 1000
    assert_receive {:reload, result}, 1500
    assert match?({:error, _}, result)

    await(fn ->
      match?({:ok, %{status: :rejected}}, Gateway.operation_status(gateway, {"web", operation}))
    end)

    assert %{listener_sets: %{"web" => %{revision: 1}}} = Gateway.info(gateway)
    assert body(gateway) == "old"
  end

  test "stop serializes a barrier against in-flight preparation and terminates the root" do
    Process.register(self(), Gaoxy.Proxy.GatewayTest.Gate)
    gateway = start_supervised!({Gateway, options("web", routes("old"))})
    operation = make_ref()

    spawn(fn ->
      Gateway.reload_routes(gateway, "web", [%{target: {Blocked, "late"}}],
        expected_revision: 1,
        timeout: 2500,
        operation_id: operation
      )
    end)

    assert_receive {:preparing, worker}, 1000
    test = self()
    spawn(fn -> send(test, {:stopped, Gateway.stop(gateway, 3000)}) end)
    await(fn -> match?(%{phase: :draining}, Gateway.info(gateway)) end)
    send(worker, :continue)
    assert_receive {:stopped, :ok}, 3500
    refute Process.alive?(gateway)
  end

  defp options(id, routes),
    do: [
      id: id,
      listener_sets: [[id: id, endpoint: {Router, routes}, listeners: [http: [port: 0]]]]
    ]

  defp routes(body), do: [%{target: {Endpoint, body}}]

  defp body(gateway) do
    %{listeners: [%{local: {:ok, {ip, port}}}]} = Gateway.info(gateway)
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    :ok = :gen_tcp.send(socket, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    response = recv(socket, "")
    :gen_tcp.close(socket)
    assert String.starts_with?(response, "HTTP/1.1 200"), response
    [_, body] = String.split(response, "\r\n\r\n", parts: 2)
    body
  end

  defp recv(socket, data) do
    case :gen_tcp.recv(socket, 0, 2000) do
      {:ok, more} -> recv(socket, data <> more)
      {:error, :closed} -> data
    end
  end

  defp await(fun, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(4000)

    if not fun.() do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, "gateway state deadline"

      receive do
      after
        5 -> await(fun, deadline)
      end
    end
  end
end
