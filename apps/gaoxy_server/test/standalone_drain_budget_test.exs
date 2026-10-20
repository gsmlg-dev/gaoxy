defmodule Gaoxy.Server.StandaloneDrainBudgetTest do
  use ExUnit.Case, async: false

  test "deferred standalone startup preserves configured drain and OTP shutdown budgets" do
    assert {:ok, options} =
             Gaoxy.Server.Config.decode(%{
               "version" => 1,
               "services" => [
                 %{
                   "id" => "custom-drain",
                   "transport" => "tcp",
                   "handler" => "stream_echo",
                   "limits" => %{"drain_timeout" => 6000}
                 }
               ]
             })

    assert {:ok, supervisor} = start_supervised({Gaoxy.Server.Supervisor, options})
    assert Gaoxy.services(Gaoxy.Server.Runtime) == ["custom-drain"]
    assert %{drain_timeout: 6000} = :sys.get_state(Gaoxy.Server.Runtime)

    [{Gaoxy.Server.UpstreamSupervisor, upstream_supervisor, :supervisor, _}] =
      Enum.filter(Supervisor.which_children(supervisor), fn {id, _, _, _} ->
        id == Gaoxy.Server.UpstreamSupervisor
      end)

    [{{Gaoxy, _} = runtime_id, _, :worker, _}] =
      Enum.filter(Supervisor.which_children(upstream_supervisor), fn {id, _, _, _} ->
        match?({Gaoxy, _}, id)
      end)

    assert {:ok, %{shutdown: 8000}} = :supervisor.get_childspec(upstream_supervisor, runtime_id)

    assert {:ok, %{shutdown: 8000}} =
             :supervisor.get_childspec(upstream_supervisor, Gaoxy.Server.RouteResources)

    {:ok, {ip, port}} = Gaoxy.info(Gaoxy.Server.Runtime, "custom-drain").local
    assert {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    assert :ok = :gen_tcp.send(socket, "preserved")
    assert {:ok, "preserved"} = :gen_tcp.recv(socket, 9, 1000)
    assert :ok = :gen_tcp.close(socket)

    assert {:error, :shutdown_budget_exceeded} =
             Gaoxy.add(Gaoxy.Server.Runtime, service(6001))

    assert :ok = stop_supervised(Gaoxy.Server.Supervisor)
    refute Process.whereis(Gaoxy.Server.Runtime)
  end

  test "ordinary empty instances retain their original immutable shutdown limit" do
    instance = start_supervised!({Gaoxy, []})
    assert %{drain_timeout: 5000} = :sys.get_state(instance)
    assert {:error, :shutdown_budget_exceeded} = Gaoxy.add(instance, service(6000))
    assert Gaoxy.services(instance) == []
    assert {:error, _} = Gaoxy.Config.validate(services: [], defer_services: true)
  end

  defp service(drain_timeout) do
    %{
      id: "dynamic",
      transport: :tcp,
      handler: Gaoxy.Server.StreamEcho,
      limits: %{drain_timeout: drain_timeout}
    }
  end
end
