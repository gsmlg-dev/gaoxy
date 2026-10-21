defmodule Gaoxy.Server.HTTP3GenerationTest do
  use ExUnit.Case, async: false
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Exchange, Generation, Request, Router}
  alias Gaoxy.Server.{Config, RouteConfig}
  @moduletag :tmp_dir
  @timeout 3_000

  defmodule Transport do
    defdelegate send_resp(exchange, status, headers, body), to: Gaoxy.HTTP.FramedResponse
    def body_complete?(_), do: true

    def operation(exchange, operation) do
      state = exchange.transport_state
      send(state.observer, {:response_operation, self(), operation})

      if state.hold and match?({:head, _, _, _}, operation) do
        ref = make_ref()
        send(state.observer, {:held, self(), ref})

        receive do
          {:release, ^ref} -> :ok
        after
          Lifecycle.remaining(exchange.deadline) -> {:error, :timeout}
        end
      else
        :ok
      end
    end
  end

  defmodule Provider do
    use GenServer
    @behaviour Gaoxy.HTTP.Resources
    def start_link(_), do: GenServer.start_link(__MODULE__, %{})
    def init(pins), do: {:ok, pins}

    def pin_many([handle], holder, kind, operation, deadline),
      do: Lifecycle.call(handle.owner, {:pin, holder, kind, operation}, deadline)

    def release(pin), do: GenServer.call(pin.owner, {:release, pin.ref})
    def cancel(owner, operation), do: GenServer.cast(owner, {:cancel, operation})

    def handle_call({:pin, holder, kind, operation}, _, pins) do
      ref = make_ref()
      pin = %{provider: __MODULE__, owner: self(), ref: ref, kind: kind, operation: operation}
      {:reply, {:ok, pin}, Map.put(pins, ref, {Process.monitor(holder), operation})}
    end

    def handle_call({:release, ref}, _, pins), do: {:reply, :ok, remove(pins, ref)}
    def handle_call(:count, _, pins), do: {:reply, map_size(pins), pins}

    def handle_cast({:cancel, operation}, pins) do
      refs = for {ref, {_, op}} <- pins, op == operation, do: ref
      {:noreply, Enum.reduce(refs, pins, &remove(&2, &1))}
    end

    def handle_info({:DOWN, monitor, :process, _, _}, pins) do
      refs = for {ref, {mon, _}} <- pins, mon == monitor, do: ref
      {:noreply, Enum.reduce(refs, pins, &remove(&2, &1))}
    end

    defp remove(pins, ref) do
      case Map.pop(pins, ref) do
        {nil, pins} ->
          pins

        {{monitor, _}, pins} ->
          Process.demonitor(monitor, [:flush])
          pins
      end
    end
  end

  defmodule PinnedEndpoint do
    def init(handle), do: {:ok, handle}
    def resources(handle), do: [handle]
    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "pinned")
  end

  setup %{tmp_dir: directory} do
    root = Path.expand("../../..", __DIR__)

    {output, code} =
      System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), directory],
        stderr_to_stdout: true
      )

    assert code == 0, output
    %{directory: directory}
  end

  test "H3 standalone starts its generation before runtime and retains a framed profile", %{
    directory: directory
  } do
    {spec, store, profile} = runtime(directory)
    assert profile.protocols == [:http3]
    assert profile.http_limits == spec.handler_options.http_limits

    assert {:ok, %{store: ^store, snapshot_bytes: 2_097_152} = initialized} =
             Generation.init(Gaoxy.Server.Supervisor.route_store("h3"))

    worker = request(spec, initialized)
    assert_receive {:response_operation, ^worker, {:head, 200, _, false}}, @timeout
    assert_receive {:response_operation, ^worker, {:data, "old", true}}, @timeout
    assert_receive {:request_done, ^worker, {:ok, %{response: :sent}}}, @timeout
  end

  test "route-store restart initializes the new H3 runtime against the new PID", %{
    directory: directory
  } do
    {_, old_store, _} = runtime(directory)
    old_runtime = Process.whereis(Gaoxy.Server.Runtime)
    store_monitor = Process.monitor(old_store)
    runtime_monitor = Process.monitor(old_runtime)
    Process.exit(old_store, :kill)
    assert_receive {:DOWN, ^store_monitor, :process, ^old_store, :killed}, @timeout
    assert_receive {:DOWN, ^runtime_monitor, :process, ^old_runtime, _}, @timeout

    {new_store, _} =
      wait_until(fn ->
        case Registry.lookup(Gaoxy.Server.RouteStores, "h3") do
          [{store, profile}] when store != old_store ->
            # The supported staged instance registers before activation. Wait
            # for complete Gateway readiness, rather than treating a PID as a
            # bound H3 service.
            case Gaoxy.Proxy.Gateway.info(Gaoxy.Server.Supervisor) do
              %{phase: :ready, instance: runtime} when is_pid(runtime) -> {store, profile}
              _ -> false
            end

          _ ->
            false
        end
      end)

    assert {:ok, %{store: ^new_store}} =
             Generation.init(Gaoxy.Server.Supervisor.route_store("h3"))

    refute Process.whereis(Gaoxy.Server.Runtime) == old_runtime
    assert {:ok, _} = Gaoxy.info(Gaoxy.Server.Runtime, "h3").local
  end

  test "H3 local reload retains listener and in-flight old snapshot and rejects invalid framing",
       %{directory: directory} do
    {spec, store, _} = runtime(directory, %{"max_headers" => 3, "max_header_bytes" => 124})
    original_listener = Gaoxy.info(Gaoxy.Server.Runtime, "h3").local
    assert {:ok, initialized} = Generation.init(store)
    old = request(spec, initialized, true)
    assert_receive {:held, ^old, ref}, @timeout
    path = Path.join(directory, "routes.json")
    File.write!(path, JSON.encode!(routes("new")))
    assert {:ok, current} = Gaoxy.Server.reload_routes("h3", path, 1_000)
    assert Gaoxy.info(Gaoxy.Server.Runtime, "h3").local == original_listener
    fresh = request(spec, initialized)
    assert_receive {:response_operation, ^fresh, {:data, "new", true}}, @timeout
    assert_receive {:request_done, ^fresh, {:ok, _}}, @timeout
    send(old, {:release, ref})
    assert_receive {:response_operation, ^old, {:data, "old", true}}, @timeout
    assert_receive {:request_done, ^old, {:ok, _}}, @timeout

    for headers <- [[["x", String.duplicate("é", 64)]], [["x-one", "a"], ["x-two", "b"]]] do
      File.write!(path, JSON.encode!(routes("bad", headers)))
      assert {:error, :static_response_limit} = Gaoxy.Server.reload_routes("h3", path, 1_000)
      assert {:ok, ^current, _} = Generation.snapshot(store)
      assert Gaoxy.info(Gaoxy.Server.Runtime, "h3").local == original_listener
    end
  end

  test "H3 generation request death releases its snapshot reservation and resource pin", %{
    directory: directory
  } do
    {spec, store, _} = runtime(directory)
    provider = start_supervised!({Provider, []})
    handle = %{provider: Provider, owner: provider, owner_epoch: make_ref()}
    assert {:ok, router} = Router.compile([%{target: {PinnedEndpoint, handle}}])
    assert {:ok, current, _} = Generation.snapshot(store)
    assert {:ok, _} = Generation.activate(store, current, router)
    assert GenServer.call(provider, :count) == 1
    assert {:ok, initialized} = Generation.init(store)
    gate = gate(spec)
    worker = request(spec, initialized, true, gate)
    assert_receive {:held, ^worker, _}, @timeout
    assert GenServer.call(provider, :count) == 2
    assert Admission.status(gate).retained_bytes >= 2_097_152
    monitor = Process.monitor(worker)
    Process.exit(worker, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, @timeout

    assert :ok =
             wait_until(fn ->
               state = Admission.status(gate)

               if state.active == 0 and state.retained_bytes == 0 and
                    GenServer.call(provider, :count) == 1,
                  do: :ok,
                  else: false
             end)

    assert {:ok, decoded} = Gaoxy.Server.RouteConfig.decode(routes("new"))
    assert {:ok, _} = Generation.reload(store, decoded)

    assert :ok =
             wait_until(fn -> if GenServer.call(provider, :count) == 0, do: :ok, else: false end)
  end

  test "data-only routes default to H1 and accept its explicit enum" do
    target = %{"type" => "reverse_proxy", "upstream" => "http://localhost:1234"}

    assert {:ok, [%{target: {Gaoxy.Proxy.HTTP, default}}]} =
             RouteConfig.decode(proxy_routes(target))

    assert {:ok, [%{target: {Gaoxy.Proxy.HTTP, explicit}}]} =
             RouteConfig.decode(proxy_routes(Map.put(target, "upstream_protocol", "http1")))

    assert default == explicit
    assert default.upstream_protocol == :http1
    assert default.client == Gaoxy.Proxy.HTTPFetchClient
  end

  test "data-only H3 route selects the fixed Session client and preserves compiled options", %{
    directory: directory
  } do
    assert {:ok, [%{target: {Gaoxy.Proxy.HTTP, config}}]} =
             RouteConfig.decode(proxy_routes(h3_target(directory)))

    assert config.upstream_protocol == :http3
    assert config.client == Gaoxy.Proxy.HTTP3SessionClient
    assert config.cacertfile == Path.join(directory, "ca.pem")
    assert config.limits.max_chunk_bytes == 16_384
    assert {:ok, ^config} = Gaoxy.Proxy.HTTP.init(config)
  end

  test "data-only upstream protocol rejects values outside the registered strings", %{
    directory: directory
  } do
    for value <- [nil, "http4", "HTTP3", "Elixir.Gaoxy.Proxy.HTTP3SessionClient", :http3, %{}] do
      target = Map.put(h3_target(directory), "upstream_protocol", value)

      assert {:error, :invalid_upstream_protocol} = RouteConfig.decode(proxy_routes(target))
    end
  end

  test "data-only H3 routes require HTTPS and a regular explicit trust file", %{
    directory: directory
  } do
    target = h3_target(directory)

    for invalid <- [
          Map.put(target, "upstream", "http://localhost:443"),
          Map.delete(target, "cacertfile"),
          Map.put(target, "cacertfile", directory),
          Map.put(target, "cacertfile", Path.join(directory, "missing.pem"))
        ] do
      assert {:error, :invalid_http_proxy_options} = RouteConfig.decode(proxy_routes(invalid))
    end
  end

  test "data-only H3 routes reject injected clients and dial or TLS overrides", %{
    directory: directory
  } do
    for {key, value} <- [
          {"client", "Elixir.Gaoxy.Proxy.HTTPFetchClient"},
          {"connect_address", "127.0.0.1"},
          {"tls", %{"verify" => "verify_none"}}
        ] do
      target = Map.put(h3_target(directory), key, value)
      assert {:error, :invalid_route_configuration} = RouteConfig.decode(proxy_routes(target))
    end
  end

  test "invalid H3 origin reload preserves the listener and complete current generation", %{
    directory: directory
  } do
    {_, store, _} = runtime(directory)
    listener = Gaoxy.info(Gaoxy.Server.Runtime, "h3").local
    assert {:ok, initial, original} = Generation.snapshot(store)
    path = Path.join(directory, "h3-origin-routes.json")

    for {target, reason} <- [
          {Map.put(h3_target(directory), "upstream_protocol", "http4"),
           :invalid_upstream_protocol},
          {Map.delete(h3_target(directory), "cacertfile"), :invalid_http_proxy_options}
        ] do
      File.write!(path, JSON.encode!(proxy_routes(target)))
      assert {:error, ^reason} = Gaoxy.Server.reload_routes("h3", path, 1_000)
      assert {:ok, ^initial, ^original} = Generation.snapshot(store)
      assert Gaoxy.info(Gaoxy.Server.Runtime, "h3").local == listener
    end

    File.write!(path, JSON.encode!(proxy_routes(h3_target(directory))))
    assert {:ok, current} = Gaoxy.Server.reload_routes("h3", path, 1_000)
    assert current != initial

    assert {:ok, ^current, %Router{routes: [%{target: {Gaoxy.Proxy.HTTP, config}}]}} =
             Generation.snapshot(store)

    assert config.upstream_protocol == :http3
    assert config.client == Gaoxy.Proxy.HTTP3SessionClient
    assert Gaoxy.info(Gaoxy.Server.Runtime, "h3").local == listener
  end

  defp h3_target(directory),
    do: %{
      "type" => "reverse_proxy",
      "upstream" => "https://localhost:443",
      "upstream_protocol" => "http3",
      "cacertfile" => Path.join(directory, "ca.pem")
    }

  defp proxy_routes(target), do: %{"version" => 1, "routes" => [%{"target" => target}]}

  defp runtime(directory, http_limits \\ %{}) do
    data = %{
      "version" => 1,
      "services" => [
        %{
          "id" => "h3",
          "handler" => "http3",
          "transport" => "quic",
          "protocols" => ["http3"],
          "ip" => "127.0.0.1",
          "port" => 0,
          "tls" => %{
            "certfile" => Path.join(directory, "cert.pem"),
            "keyfile" => Path.join(directory, "key.pem")
          },
          "limits" => %{"max_bytes" => 33_554_432},
          "http_limits" => http_limits,
          "routes" => routes("old")
        }
      ]
    }

    assert {:ok, [services: [spec]] = options} = Config.decode(data)
    start_supervised!({Gaoxy.Server.Supervisor, options})
    [{store, profile}] = Registry.lookup(Gaoxy.Server.RouteStores, "h3")
    {spec, store, profile}
  end

  defp gate(spec),
    do:
      start_supervised!(
        {Admission, {spec.limits, %{instance: make_ref(), service: :semantic_h3}}},
        id: make_ref()
      )

  defp request(spec, initialized, hold \\ false, gate \\ nil) do
    observer = self()
    gate = gate || gate(spec)

    worker =
      spawn(fn ->
        {:ok, lease} = Admission.acquire(gate, 0)
        deadline = Lifecycle.deadline(@timeout)
        :ok = Admission.begin_request(gate, lease, 0, deadline)

        exchange = %Exchange{
          request: %Request{method: "GET", version: :"HTTP/3", path: "/", head_bytes: 0},
          gate: gate,
          lease: lease,
          deadline: deadline,
          limits: spec.handler_options.http_limits,
          body: %{phase: :done, total: 0, trailers: [], trailer_bytes: 0},
          buffer: "",
          transport: Transport,
          transport_state: %{observer: observer, hold: hold},
          secure: true
        }

        result = Generation.call(exchange, initialized)
        send(observer, {:request_done, self(), result})
      end)

    on_exit(fn -> if Process.alive?(worker), do: Process.exit(worker, :kill) end)
    worker
  end

  defp wait_until(fun), do: wait_until(fun, Lifecycle.deadline(@timeout))

  defp wait_until(fun, deadline) do
    case fun.() do
      false ->
        assert Lifecycle.remaining(deadline) > 0, "condition deadline"

        receive do
        after
          2 -> wait_until(fun, deadline)
        end

      value ->
        value
    end
  end

  defp routes(body, headers \\ []),
    do: %{
      "version" => 1,
      "routes" => [%{"target" => %{"type" => "static", "body" => body, "headers" => headers}}]
    }
end
