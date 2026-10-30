defmodule Gaoxy.Server.StandaloneRecoveryTest do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.Generation
  alias Gaoxy.Lifecycle
  alias Gaoxy.Server.{Config, RouteResources}
  @moduletag :capture_log
  @moduletag :tmp_dir

  defmodule ExpiredCandidate do
    def init({test, gate}) do
      send(test, {:activation_compiling, self(), gate})

      receive do
        {^gate, :finish} -> {:ok, []}
      after
        2000 -> {:error, :expiry_gate_timeout}
      end
    end

    def call(exchange, _), do: {:ok, exchange}
  end

  for kind <- [:fixed, :group] do
    @kind kind
    test "#{kind} recovery preserves accepted routes and permits subsequent reload", %{
      tmp_dir: dir
    } do
      startup = origin("startup")
      accepted = origin("accepted")
      final = origin("final")
      assert {:ok, options} = Config.decode(config(target(@kind, startup)))
      start_supervised!({Gaoxy.Server.Supervisor, options})
      await_ready(@kind)
      assert body() == "startup"
      path = Path.join(dir, "routes.json")
      File.write!(path, JSON.encode!(routes(target(@kind, accepted))))
      assert {:ok, generation} = Gaoxy.Server.reload_routes("web", path)
      await_ready(@kind)
      assert body() == "accepted"
      settle_retirements()

      # A stale candidate must not replace the declaration used by recovery.
      store = Gaoxy.Server.Supervisor.route_store("web")
      assert {:ok, decoded} = Gaoxy.Server.RouteConfig.decode(routes(target(@kind, final)))
      assert {:ok, candidate} = Generation.prepare(store, decoded)

      assert {:error, :stale_generation} =
               RouteResources.activate(store, make_ref(), candidate, Lifecycle.deadline(3000))

      assert {:ok, ^generation, _} = Generation.snapshot(store)
      reject_expired_candidate(store, generation, candidate)
      assert body() == "accepted"

      %{transports: transports, groups: groups} = :sys.get_state(RouteResources)
      owner_monitors = Enum.map([transports, groups], &{&1, Process.monitor(&1)})

      custodians =
        for {_, record} <- :sys.get_state(transports).records,
            record.lifecycle == :active and not record.retirement_requested,
            do: {record.custodian, Process.monitor(record.custodian)}

      assert custodians != []

      for {custodian, _} <- custodians do
        :ok = :sys.suspend(custodian)

        on_exit(fn ->
          try do
            if Process.alive?(custodian), do: :sys.resume(custodian, 1000)
          catch
            :exit, _ -> :ok
          end
        end)
      end

      coordinator = Process.whereis(RouteResources)
      coordinator_monitor = Process.monitor(coordinator)

      # Exercise the documented owner-subtree recovery path. Readiness is
      # synchronized through the replacement coordinator, without requiring a
      # particular generation-store PID or supervisor layout.
      Process.exit(Process.whereis(Gaoxy.Server.UpstreamOwners), :kill)

      for {owner, monitor} <- owner_monitors do
        assert_receive {:DOWN, ^monitor, :process, ^owner, _}, 1000
      end

      # Scope cleanup remains owned even after the pin metadata owner dies.
      for {custodian, _} <- custodians do
        assert Process.alive?(custodian)
        :ok = :sys.resume(custodian)
      end

      assert_receive {:DOWN, ^coordinator_monitor, :process, ^coordinator, _}, 5000
      await_recovered(coordinator, Lifecycle.deadline(2000))

      for {custodian, monitor} <- custodians do
        assert_receive {:DOWN, ^monitor, :process, ^custodian, :normal}, 5000
      end

      await_ready(@kind)
      recovered = body()
      settle_retirements()
      File.write!(path, JSON.encode!(routes(target(@kind, final))))
      reloaded = Gaoxy.Server.reload_routes("web", path)
      assert match?({"accepted", {:ok, _}}, {recovered, reloaded})
      await_ready(@kind)
      assert body() == "final"
      settle_retirements()
      assert body() == "final"
      %{transports: current} = :sys.get_state(RouteResources)

      assert {:ok, %{resources: 1, failed_resources: 0}} =
               Gaoxy.Proxy.UpstreamTransports.status(current)
    end
  end

  defp reject_expired_candidate(store, generation, candidate) do
    coordinator = Process.whereis(RouteResources)
    runtime = Process.whereis(Gaoxy.Server.Runtime)
    before = :sys.get_state(coordinator)
    baseline = :sys.get_state(GenServer.whereis(store)).baseline
    assert {:ok, ^generation, declaration} = Generation.declared_snapshot(store)
    gate = make_ref()
    test = self()
    deadline = Lifecycle.deadline(1000)

    expiring = %Gaoxy.HTTP.Router{
      routes: candidate.routes ++ [%{target: {ExpiredCandidate, {test, gate}}}]
    }

    {caller, monitor} =
      spawn_monitor(fn ->
        result = RouteResources.activate(store, generation, expiring, deadline)
        send(test, {:expired_activation, self(), result})
      end)

    assert_receive {:activation_compiling, worker, ^gate}, 1000
    refute worker == coordinator
    worker_monitor = Process.monitor(worker)
    # Keep release unconfirmed until the bounded initializer is terminated.
    # Preparation and its pins remain owned by the responsive coordinator.
    :ok = :sys.suspend(before.transports)

    on_exit(fn ->
      try do
        if Process.alive?(before.transports), do: :sys.resume(before.transports, 1000)
      catch
        :exit, _ -> :ok
      end
    end)

    # The preparation timer and caller deadline can expire in the same tick.
    # Hold the coordinator's reply until the caller observes its own deadline;
    # the generation store remains runnable and still terminates the worker.
    true = :erlang.suspend_process(coordinator)

    try do
      assert_receive {:expired_activation, ^caller,
                      {:error, {:deadline_exceeded, :cleanup_pending}}},
                     2000
    after
      if Process.alive?(coordinator), do: :erlang.resume_process(coordinator)
    end

    assert_receive {:DOWN, ^monitor, :process, ^caller, :normal}, 1000
    assert Lifecycle.remaining(deadline) == 0
    assert_receive {:DOWN, ^worker_monitor, :process, ^worker, :killed}, 1000
    send(worker, {gate, :finish})

    # Compilation has finished after D. This barrier must return from the same
    # coordinator, with no accepted declaration/baseline or runtime replacement.
    after_expiry = :sys.get_state(coordinator, 1000)
    assert Process.whereis(RouteResources) == coordinator
    assert Process.whereis(Gaoxy.Server.Runtime) == runtime
    assert after_expiry.transports == before.transports
    assert after_expiry.groups == before.groups
    assert :sys.get_state(GenServer.whereis(store)).baseline == baseline
    assert {:ok, ^generation, ^declaration} = Generation.declared_snapshot(store)

    # The expired caller cannot join preparation cleanup; the coordinator keeps
    # those pins and reconciles them under its existing finite cleanup budget.
    assert after_expiry.pending_pins != []
    :ok = :sys.resume(before.transports)
    send(coordinator, :reconcile_preparations)
    assert :sys.get_state(coordinator, 1000).pending_pins == []
  end

  defp await_recovered(previous, deadline) do
    assert Lifecycle.remaining(deadline) > 0, "standalone recovery readiness deadline"

    case Process.whereis(RouteResources) do
      pid when is_pid(pid) and pid != previous ->
        :sys.get_state(pid, Lifecycle.remaining(deadline))
        :ok

      _ ->
        await_recovered(previous, deadline)
    end
  end

  defp await_ready(:fixed), do: :ok

  defp await_ready(:group) do
    assert {:ok, _, %{routes: [%{target: {_, %{group: group}}}]}} =
             Generation.snapshot(Gaoxy.Server.Supervisor.route_store("web"))

    await_group(group, Lifecycle.deadline(2000))
  end

  defp await_group(group, deadline) do
    case Gaoxy.Proxy.UpstreamGroups.status(group) do
      %{members: [%{health: :healthy, probe: false}]} ->
        :ok

      status ->
        assert Lifecycle.remaining(deadline) > 0, "group readiness deadline: #{inspect(status)}"
        await_group(group, deadline)
    end
  end

  defp settle_retirements(attempts \\ 64)
  defp settle_retirements(0), do: flunk("generation retirement did not settle")

  defp settle_retirements(attempts) do
    store = GenServer.whereis(Gaoxy.Server.Supervisor.route_store("web"))
    send(store, :reconcile_resources)

    case :sys.get_state(store, 1000).retired do
      [] -> :ok
      _ -> settle_retirements(attempts - 1)
    end
  end

  defp origin(body) do
    id = body

    instance =
      start_supervised!(
        {Gaoxy.HTTP,
         id: id, endpoint: {Gaoxy.Server.StaticEndpoint, %{status: 200, body: body, headers: []}}},
        id: id
      )

    {:ok, {_, port}} = Gaoxy.info(instance, id).local
    %{"upstream" => "http://127.0.0.1:#{port}", "upstream_protocol" => "http1"}
  end

  defp target(:fixed, member),
    do: Map.merge(member, %{"type" => "reverse_proxy", "managed" => true})

  defp target(:group, member),
    do: %{
      "type" => "upstream_group",
      "id" => "api",
      "members" => [Map.merge(member, %{"id" => "one", "max_inflight" => 4})],
      "health" => %{
        "interval" => 60000,
        "stale_after" => 120_000,
        "timeout" => 500,
        "jitter" => 0,
        "recovery_threshold" => 1
      }
    }

  defp routes(target), do: %{"version" => 1, "routes" => [%{"target" => target}]}

  defp config(target),
    do: %{
      "version" => 1,
      "services" => [
        %{
          "id" => "web",
          "transport" => "tcp",
          "handler" => "http",
          "routes" => routes(target),
          "limits" => %{"max_bytes" => 67_108_864, "drain_timeout" => 1000}
        }
      ]
    }

  defp body do
    {:ok, {ip, port}} = Gaoxy.info(Gaoxy.Server.Runtime, "web").local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)

    try do
      :ok =
        :gen_tcp.send(socket, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")

      response = read(socket, "")
      assert String.starts_with?(response, "HTTP/1.1 200")
      [_, body] = String.split(response, "\r\n\r\n", parts: 2)
      body
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
