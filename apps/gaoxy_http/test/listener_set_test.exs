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
