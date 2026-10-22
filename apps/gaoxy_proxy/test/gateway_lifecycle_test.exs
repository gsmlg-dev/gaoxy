defmodule Gaoxy.Proxy.GatewayLifecycleTest do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.Router
  alias Gaoxy.Proxy.Gateway
  alias Gaoxy.Proxy.Gateway.Control
  @moduletag :capture_log

  defmodule Endpoint do
    def init(body), do: {:ok, body}
    def call(exchange, body), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], body)
  end

  defmodule HostSupervisor do
    use Supervisor
    def start_link(options), do: Supervisor.start_link(__MODULE__, options)
    def init(options), do: Supervisor.init([{Gateway, options}], strategy: :one_for_one)
  end

  defmodule Blocked do
    def init(body) do
      send(Process.whereis(Gaoxy.Proxy.GatewayLifecycleTest.Gate), {:initializing, self()})

      receive do
        :continue -> {:ok, body}
      end
    end

    def call(exchange, body), do: Endpoint.call(exchange, body)
  end

  test "an explicit reload deadline is validated and expired input is never admitted" do
    gateway = start_supervised!({Gateway, options()})
    operation = make_ref()

    assert {:error, :invalid_reload_deadline} =
             Gateway.reload_routes(gateway, "web", [],
               expected_revision: 1,
               timeout: 500,
               deadline: :invalid
             )

    assert {:error, :reload_timeout} =
             Gateway.reload_routes(gateway, "web", routes("late"),
               expected_revision: 1,
               timeout: 500,
               deadline: Gaoxy.Lifecycle.deadline(0),
               operation_id: operation
             )

    assert {:ok, %{status: :unknown}} = Gateway.operation_status(gateway, {"web", operation})
    assert %{listener_sets: %{"web" => %{revision: 1}}} = Gateway.info(gateway)
  end

  test "a timed out generation barrier retains an owner that completes stop" do
    gateway = start_supervised!({Gateway, options()})
    {:ok, control} = Gateway.control(gateway)
    context = Control.context(control)
    store = GenServer.whereis(context.stores["web"])
    :ok = :sys.suspend(store)
    on_exit(fn -> resume(store) end)
    stopped = Process.monitor(gateway)
    owner = pending_stop(gateway)
    :ok = :sys.resume(store)
    assert_receive {:DOWN, ^stopped, :process, ^gateway, :normal}, 2_000
    await_down(owner)
  end

  test "a timed out control lookup retains an owner that completes stop" do
    gateway = start_supervised!({Gateway, options()})
    {:ok, control} = Gateway.control(gateway)
    :ok = :sys.suspend(control)
    on_exit(fn -> resume(control) end)
    stopped = Process.monitor(gateway)
    owner = pending_stop(gateway)
    :ok = :sys.resume(control)
    assert_receive {:DOWN, ^stopped, :process, ^gateway, :normal}, 2_000
    await_down(owner)
  end

  test "reload context lookup respects the caller deadline and preserves its identity" do
    gateway = start_supervised!({Gateway, options()})
    {:ok, control} = Gateway.control(gateway)
    :ok = :sys.suspend(control)
    on_exit(fn -> resume(control) end)
    parent = self()
    operation = make_ref()

    caller =
      spawn(fn ->
        result =
          Gateway.reload_routes(gateway, "web", routes("new"),
            expected_revision: 1,
            timeout: 80,
            deadline: Gaoxy.Lifecycle.deadline(5_000),
            operation_id: operation
          )

        send(parent, {:reload_result, result})
      end)

    on_exit(fn -> if Process.alive?(caller), do: Process.exit(caller, :kill) end)
    assert_receive {:reload_result, {:error, {:operation_pending, {"web", ^operation}}}}, 500
    :ok = :sys.resume(control)
    assert {:ok, %{status: :unknown}} = Gateway.operation_status(gateway, {"web", operation})
    assert %{listener_sets: %{"web" => %{revision: 1}}} = Gateway.info(gateway)
  end

  test "operation inspection returns bounded uncertainty when control is unavailable" do
    gateway = start_supervised!({Gateway, options()})
    {:ok, control} = Gateway.control(gateway)
    :ok = :sys.suspend(control)
    on_exit(fn -> resume(control) end)
    parent = self()

    {caller, monitor} =
      spawn_monitor(fn ->
        send(parent, {:operation_status, Gateway.operation_status(gateway, {"web", make_ref()})})
      end)

    on_exit(fn -> if Process.alive?(caller), do: Process.exit(caller, :kill) end)
    assert_receive {:operation_status, {:error, :gateway_unavailable}}, 500
    assert_receive {:DOWN, ^monitor, :process, ^caller, :normal}, 500
    :ok = :sys.resume(control)
  end

  test "a required bind failure returns an error without killing its caller" do
    {:ok, occupied} = :gen_tcp.listen(0, [:binary, ip: {127, 0, 0, 1}])
    on_exit(fn -> :gen_tcp.close(occupied) end)
    {:ok, {_, port}} = :inet.sockname(occupied)
    parent = self()

    {caller, monitor} =
      spawn_monitor(fn ->
        result = Gateway.start_link(options(5_000, port))
        send(parent, {:startup_result, result, Process.info(self(), :trap_exit)})

        receive do
          :finish -> :ok
        end
      end)

    assert_receive {:startup_result, {:error, _}, {:trap_exit, false}}, 2_000
    send(caller, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^caller, :normal}, 1_000
  end

  test "normal host supervision shuts down the actual Gateway root and core" do
    host = start_supervised!({HostSupervisor, options()})
    [{_, gateway, :supervisor, _}] = Supervisor.which_children(host)
    %{instance: instance} = Gateway.info(gateway)
    root_monitor = Process.monitor(gateway)
    core_monitor = Process.monitor(instance)
    assert :ok = Supervisor.stop(host, :normal, 2_000)
    assert_receive {:DOWN, ^root_monitor, :process, ^gateway, :shutdown}, 1_000
    assert_receive {:DOWN, ^core_monitor, :process, ^instance, _}, 1_000
  end

  test "temporary startup trapping preserves unrelated abnormal linked exits" do
    Process.register(self(), Gaoxy.Proxy.GatewayLifecycleTest.Gate)
    parent = self()

    blocked = [
      id: :blocked,
      listener_sets: [[id: "web", endpoint: {Blocked, "old"}, listeners: [http: []]]]
    ]

    {caller, monitor} =
      spawn_monitor(fn ->
        peer =
          spawn_link(fn ->
            receive do
              :fail -> exit(:unrelated_link_failure)
            end
          end)

        send(parent, {:linked_peer, peer})
        Gateway.start_link(blocked)
      end)

    assert_receive {:linked_peer, peer}, 1_000
    assert_receive {:initializing, worker}, 1_000
    send(peer, :fail)

    await(fn ->
      case Process.info(caller, :messages) do
        {:messages, messages} -> {:EXIT, peer, :unrelated_link_failure} in messages
        nil -> false
      end
    end)

    send(worker, :continue)
    assert_receive {:DOWN, ^monitor, :process, ^caller, :unrelated_link_failure}, 2_000
  end

  test "inspection exposes unknown preparation cleanup while coordinator is busy" do
    gateway = start_supervised!({Gateway, options()})
    %{coordinator: coordinator} = Gateway.info(gateway)
    :ok = :sys.suspend(coordinator)
    on_exit(fn -> resume(coordinator) end)

    assert %{cleanup: :pending, preparations: %{preparation_pins: :unknown}} =
             Gateway.info(gateway)

    :ok = :sys.resume(coordinator)
    assert %{cleanup: :confirmed, preparations: %{preparation_pins: 0}} = Gateway.info(gateway)
  end

  test "queued readiness and recovery cannot publish after their caller deadline" do
    gateway = start_supervised!({Gateway, options()})
    {:ok, control} = Gateway.control(gateway)
    %{runtime_epoch: epoch} = Gateway.info(gateway)
    assert :ok = Control.recovering(control, epoch)
    :ok = :sys.suspend(control)
    on_exit(fn -> resume(control) end)
    parent = self()
    deadline = Gaoxy.Lifecycle.deadline(80)
    spawn(fn -> send(parent, {:ready_result, Control.ready(control, epoch, deadline)}) end)
    assert_receive {:ready_result, {:error, {:deadline_exceeded, :cleanup_pending}}}, 500
    :ok = :sys.resume(control)
    assert Control.phase(control) == :recovering

    assert :ok = Control.ready(control, epoch)
    :ok = :sys.suspend(control)
    deadline = Gaoxy.Lifecycle.deadline(80)

    spawn(fn ->
      send(parent, {:recovering_result, Control.recovering(control, make_ref(), deadline)})
    end)

    assert_receive {:recovering_result, {:error, {:deadline_exceeded, :cleanup_pending}}}, 500
    :ok = :sys.resume(control)
    assert Control.phase(control) == :ready
  end

  defp pending_stop(gateway) do
    parent = self()
    caller = spawn(fn -> send(parent, {:stop_result, Gateway.stop(gateway, 80)}) end)
    on_exit(fn -> if Process.alive?(caller), do: Process.exit(caller, :kill) end)
    assert_receive {:stop_result, {:error, {:deadline_exceeded, :cleanup_pending, owner}}}, 500
    assert is_pid(owner) and Process.alive?(owner)
    owner
  end

  defp await_down(pid) do
    monitor = Process.monitor(pid)
    assert_receive {:DOWN, ^monitor, :process, ^pid, _}, 1_000
  end

  defp resume(pid) do
    if Process.alive?(pid), do: :sys.resume(pid)
  catch
    :exit, _ -> :ok
  end

  defp await(fun, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(1_000)

    if not fun.() do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, "lifecycle synchronization deadline"

      receive do
      after
        5 -> await(fun, deadline)
      end
    end
  end

  defp routes(body), do: [%{target: {Endpoint, body}}]

  defp options(drain \\ 5_000, port \\ 0),
    do: [
      id: :lifecycle,
      listener_sets: [
        [
          id: "web",
          endpoint: {Router, routes("old")},
          listeners: [http: [port: port, limits: %{drain_timeout: drain}]]
        ]
      ]
    ]
end
