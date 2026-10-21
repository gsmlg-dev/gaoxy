defmodule Gaoxy.HTTP.ListenerSetTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.ListenerSet

  defmodule Endpoint do
    def init(options) do
      if options[:observer], do: send(options[:observer], :initialized)
      {:ok, options}
    end

    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "listener-set")
  end

  defmodule FailingEndpoint do
    def init(_), do: {:error, :target_refused}
    def call(_, _), do: raise("failed target must not serve requests")
  end

  test "planning is stable, preserves the target declaration and performs no initialization" do
    declaration = [id: :site, endpoint: {Endpoint, []}, listeners: [http: [port: 0]]]
    assert {:ok, first} = ListenerSet.plan(declaration)
    assert {:ok, ^first} = ListenerSet.plan(declaration)
    assert first.target == {:endpoint, Endpoint, []}
    assert first.service_ids == %{http: "site:http"}
    refute_received :initialized
  end

  test "pure declarations reject runtime capabilities and field errors identify the listener" do
    assert {:error, {:field, [:target], :runtime_value}} =
             ListenerSet.plan(
               id: :site,
               endpoint: {Endpoint, [observer: self()]},
               listeners: [http: []]
             )

    assert {:error, {:field, [:listeners, :http, :port], :invalid_port}} =
             ListenerSet.plan(id: :site, endpoint: {Endpoint, []}, listeners: [http: [port: -1]])

    assert {:error, {:field, [:listeners, :http, :initialized], :unknown_option}} =
             ListenerSet.plan(
               id: :site,
               endpoint: {Endpoint, []},
               listeners: [http: [initialized: true]]
             )

    assert {:error, {:field, [:listeners, :http, :limits], :invalid_limits}} =
             ListenerSet.plan(
               id: :site,
               endpoint: {Endpoint, []},
               listeners: [http: [limits: []]]
             )

    assert {:error, {:field, [:listeners, :http, :protocols], :invalid_http_protocols}} =
             ListenerSet.plan(
               id: :site,
               endpoint: {Endpoint, []},
               listeners: [http: [protocols: :http2]]
             )
  end

  test "same-family conflicts and duplicate physical IDs fail before any preparation" do
    assert {:error, {:binding_conflict, "site:https", "site:http"}} =
             ListenerSet.plan(
               id: :site,
               endpoint: {Endpoint, []},
               listeners: [
                 http: [port: 8443],
                 https: [port: 8443, certfile: "missing", keyfile: "missing"]
               ]
             )

    assert {:error, {:duplicate_service, :same}} =
             ListenerSet.plan(
               id: :site,
               endpoint: {Endpoint, []},
               listeners: [http: [], https: []],
               service_ids: %{http: :same, https: :same}
             )
  end

  test "preparation initializes the real target once and repeated service validation reuses it" do
    {:ok, plan} =
      ListenerSet.plan(id: :prepared, endpoint: {Endpoint, []}, listeners: [http: [port: 0]])

    assert {:ok, [_]} = ListenerSet.planned_services(plan)
    refute_received :initialized
    assert {:ok, [service]} = ListenerSet.prepare(plan, target: {Endpoint, [observer: self()]})
    assert_receive :initialized
    assert {:ok, _} = Gaoxy.Config.service(service)
    refute_received :initialized
  end

  test "all disabled Phoenix roles preserve the empty child list and true H3 is rejected" do
    assert [] = Gaoxy.PhoenixAdapter.child_specs(Endpoint, http: false, https: nil, http3: false)
    assert_raise ArgumentError, fn -> Gaoxy.PhoenixAdapter.child_specs(Endpoint, http3: true) end

    assert_raise ArgumentError, fn ->
      Gaoxy.PhoenixAdapter.child_specs(Endpoint, http3: [port: 0])
    end
  end

  test "generation snapshot reservation is preflighted together with H1 and H2 worker budgets" do
    alias Gaoxy.HTTP.ListenerSet.PreparedTarget
    provider = Gaoxy.HTTP.ListenerProvider.HTTP
    target = %PreparedTarget{endpoint: {Gaoxy.HTTP.Generation, %{snapshot_bytes: 4_096}}}

    for protocols <- [[:http1], [:http2]] do
      options = [id: :budget, ip: {127, 0, 0, 1}, port: 0, protocols: protocols]

      options =
        if protocols == [:http2], do: Keyword.put(options, :h2c, :prior_knowledge), else: options

      assert {:ok, base} = provider.materialize(:http, options, :planned)
      http = base.handler_options.http_limits

      floor =
        if protocols == [:http2] do
          reserve = Gaoxy.HTTP.HTTP2.Limits.reservation(http, base.handler_options.h2_limits)
          reserve.connection + reserve.decode + reserve.stream + reserve.writer
        else
          2 * http.max_header_bytes + http.max_buffer_bytes + 4 * http.max_read_chunk
        end

      insufficient = Keyword.put(options, :limits, %{max_bytes: floor + 4_095})
      assert {:error, :generation_byte_budget} = provider.materialize(:http, insufficient, target)
      sufficient = Keyword.put(options, :limits, %{max_bytes: floor + 4_096})
      assert {:ok, _} = provider.materialize(:http, sufficient, target)
    end
  end

  test "one owner starts one core instance and reports its actual physical listener" do
    {:ok, owner} =
      ListenerSet.start_link(id: :site, endpoint: {Endpoint, []}, listeners: [http: []])

    Process.unlink(owner)
    on_exit(fn -> if Process.alive?(owner), do: GenServer.stop(owner) end)
    assert %{phase: :ready, instance: instance, listeners: [listener]} = ListenerSet.info(owner)

    assert %{
             role: :http,
             transport: :tcp,
             local: {:ok, {ip, port}},
             protocols: [:http1],
             state: :ready
           } = listener

    assert port > 0
    assert ["site:http"] = Gaoxy.services(instance)
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)
    :ok = :gen_tcp.send(socket, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    assert {:ok, response} = :gen_tcp.recv(socket, 0, 1_000)
    assert response =~ "HTTP/1.1 200"
    :gen_tcp.close(socket)
  end

  test "supervisor shutdown drains the core before the child shutdown deadline" do
    child =
      ListenerSet.child_spec(id: :supervised, endpoint: {Endpoint, []}, listeners: [http: []])
      |> Map.put(:shutdown, 2_000)

    {:ok, supervisor} = Supervisor.start_link([child], strategy: :one_for_one)
    Process.unlink(supervisor)

    on_exit(fn ->
      if Process.alive?(supervisor), do: Supervisor.stop(supervisor, :normal, 3_000)
    end)

    [{_, owner, _, _}] = Supervisor.which_children(supervisor)
    %{instance: instance} = ListenerSet.info(owner)
    owner_monitor = Process.monitor(owner)
    core_monitor = Process.monitor(instance)
    test = self()

    participant =
      spawn_link(fn ->
        {:ok, registration} = Gaoxy.register_lifecycle_participant(instance, 1_000)
        send(test, :participant_ready)

        receive do
          {:gaoxy_lifecycle_drain, ^registration, operation, coordinator, _} ->
            send(test, :core_draining)

            receive do
              :release ->
                send(coordinator, {:gaoxy_lifecycle_result, registration, operation, self(), :ok})
            end
        end
      end)

    on_exit(fn -> if Process.alive?(participant), do: Process.exit(participant, :kill) end)
    assert_receive :participant_ready, 1_000
    stopping = Task.async(fn -> Supervisor.stop(supervisor, :normal, 3_000) end)
    assert_receive :core_draining, 1_000
    assert Process.alive?(owner)
    assert Process.alive?(instance)
    send(participant, :release)
    assert :ok = Task.await(stopping, 3_000)
    assert_receive {:DOWN, ^core_monitor, :process, ^instance, :normal}, 1_000
    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :shutdown}, 1_000
  end

  test "direct parent normal exit stops its linked owner and unrelated exits are ignored" do
    test = self()

    parent =
      spawn(fn ->
        {:ok, owner} =
          ListenerSet.start_link(id: :direct, endpoint: {Endpoint, []}, listeners: [http: []])

        send(test, {:direct_owner, owner})

        receive do
          :finish -> :ok
        end
      end)

    on_exit(fn -> if Process.alive?(parent), do: Process.exit(parent, :kill) end)
    assert_receive {:direct_owner, owner}, 1_000
    %{instance: instance} = ListenerSet.info(owner)
    owner_monitor = Process.monitor(owner)
    core_monitor = Process.monitor(instance)
    send(owner, {:EXIT, self(), :unrelated})
    assert %{phase: :ready, instance: ^instance} = ListenerSet.info(owner)
    send(parent, :finish)
    assert_receive {:DOWN, ^core_monitor, :process, ^instance, :normal}, 1_000
    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :normal}, 1_000
  end

  test "target initialization failure leaves its planned listener and owned runtime absent" do
    {:ok, probe} = :gen_tcp.listen(0, ip: {127, 0, 0, 1}, active: false)
    {:ok, {ip, port}} = :inet.sockname(probe)
    :gen_tcp.close(probe)

    assert {:error, :target_refused} =
             ListenerSet.start_link(
               id: :failed_target,
               endpoint: {FailingEndpoint, []},
               listeners: [http: [ip: ip, port: port]],
               name: __MODULE__.FailedOwner,
               instance_name: __MODULE__.FailedCore
             )

    assert Process.whereis(__MODULE__.FailedOwner) == nil
    assert Process.whereis(__MODULE__.FailedCore) == nil
    assert {:ok, available} = :gen_tcp.listen(port, ip: ip, active: false)
    :gen_tcp.close(available)
  end
end
