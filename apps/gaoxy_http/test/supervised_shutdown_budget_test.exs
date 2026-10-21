defmodule Gaoxy.HTTP.SupervisedShutdownBudgetTest do
  use ExUnit.Case, async: true
  @moduletag :capture_log

  defmodule BodyPlug do
    def init(owner), do: owner

    def call(conn, owner) do
      send(owner, {:body_worker, self()})
      read(conn)
    end

    defp read(conn) do
      case Plug.Conn.read_body(conn, length: 16_384) do
        {:more, _, conn} -> read(conn)
        {:ok, _, conn} -> Plug.Conn.send_resp(conn, 200, "complete")
      end
    end
  end

  defmodule InitializationPlug do
    def init(owner) do
      send(owner, {:plug_initialized, self()})
      owner
    end

    def call(conn, _), do: Plug.Conn.send_resp(conn, 200, "ready")
  end

  defmodule RaisingPlug do
    def init(_), do: raise("startup initialization")
    def call(conn, _), do: conn
  end

  @tag :child_spec_initialization
  test "child spec is pure and supervised startup initializes the Plug exactly once" do
    options = [plug: {InitializationPlug, self()}]
    child_spec = Gaoxy.HTTP.child_spec(options)
    refute_receive {:plug_initialized, _}, 20

    parent =
      start_supervised!(%{
        id: make_ref(),
        type: :supervisor,
        start: {Supervisor, :start_link, [[child_spec], [strategy: :one_for_one]]}
      })

    assert_receive {:plug_initialized, _}, 1_000
    refute_receive {:plug_initialized, _}, 20
    assert :ok = Supervisor.terminate_child(parent, child_spec.id)

    raising = [plug: {RaisingPlug, []}]
    assert %{start: {Gaoxy.HTTP, :start_link, [^raising]}} = Gaoxy.HTTP.child_spec(raising)
    assert_raise RuntimeError, "startup initialization", fn -> Gaoxy.HTTP.start_link(raising) end
  end

  test "HTTP child spec inherits the validated instance budget and defers invalid startup errors" do
    for limits <- [%{}, %{drain_timeout: 5_500}] do
      options = [id: :budget, plug: {BodyPlug, self()}, limits: limits]
      assert {:ok, service} = Gaoxy.HTTP.service_spec(options)
      expected = Gaoxy.child_spec(services: [service])
      actual = Gaoxy.HTTP.child_spec(options)
      assert Map.get(actual, :shutdown) == expected.shutdown
      assert actual.id == {Gaoxy.HTTP, :budget}
      assert actual.start == {Gaoxy.HTTP, :start_link, [options]}
      assert actual.restart == :transient
    end

    invalid = [plug: {BodyPlug, self()}, limits: %{drain_timeout: -1}]

    assert %{shutdown: 7_000, start: {Gaoxy.HTTP, :start_link, [^invalid]}} =
             Gaoxy.HTTP.child_spec(invalid)

    assert {:error, _} = Gaoxy.HTTP.start_link(invalid)
  end

  test "supervised idle HTTP shutdown acknowledges runtime and listener cleanup" do
    fixture = server(%{})
    stop_and_assert(fixture, nil)
  end

  for drain_timeout <- [5_000, 5_500] do
    @tag timeout: 15_000
    test "active upload survives supervised #{drain_timeout}ms drain and completes cleanup" do
      fixture = server(%{drain_timeout: unquote(drain_timeout), max_bytes: 8_388_608})
      {:ok, socket} = :gen_tcp.connect(fixture.ip, fixture.port, [:binary, active: false], 1_000)
      on_exit(fn -> :gen_tcp.close(socket) end)

      assert :ok =
               :gen_tcp.send(
                 socket,
                 "POST / HTTP/1.1\r\nHost: localhost\r\nExpect: 100-continue\r\nContent-Length: 2097152\r\n\r\n"
               )

      assert {:ok, continue} = :gen_tcp.recv(socket, 0, 1_000)
      assert continue =~ "HTTP/1.1 100 Continue"
      assert_receive {:body_worker, worker}, 1_000
      assert %{active: 1} = Gaoxy.status(fixture.instance, :http)
      monitor = Process.monitor(worker)
      owner = self()
      sender = spawn_link(fn -> progress(socket, owner) end)
      started = System.monotonic_time(:millisecond)
      stop_and_assert(fixture, socket)
      elapsed = System.monotonic_time(:millisecond) - started
      send(sender, :stop)
      assert elapsed >= unquote(drain_timeout)
      assert elapsed < unquote(drain_timeout) + 2_000
      assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
      assert_receive {:body_progress, bytes}, 1_000
      assert bytes >= 16_384
    end
  end

  defp server(limits) do
    options = [
      plug: {BodyPlug, self()},
      limits: limits,
      http_limits: %{read_timeout: 2_000, request_timeout: 20_000}
    ]

    parent =
      start_supervised!(%{
        id: make_ref(),
        type: :supervisor,
        start: {Supervisor, :start_link, [[{Gaoxy.HTTP, options}], [strategy: :one_for_one]]}
      })

    [{child, instance, _, _}] = Supervisor.which_children(parent)
    {:ok, service, _} = GenServer.call(instance, {:lookup, :http})
    state = :sys.get_state(service)
    resources = Gaoxy.Lifecycle.resources(state.backend, service)
    assert [_ | _] = resources
    assert {:ok, {ip, port}} = Gaoxy.info(instance, :http).local

    %{
      parent: parent,
      child: child,
      instance: instance,
      ip: ip,
      port: port,
      owned: Enum.uniq([service, state.backend, state.gate | resources])
    }
  end

  defp stop_and_assert(fixture, socket) do
    instance_monitor = Process.monitor(fixture.instance)
    monitors = Enum.map(fixture.owned, &{&1, Process.monitor(&1)})
    assert :ok = Supervisor.terminate_child(fixture.parent, fixture.child)
    assert_receive {:DOWN, ^instance_monitor, :process, instance, :shutdown}, 1_000
    assert instance == fixture.instance

    for {pid, monitor} <- monitors do
      assert_receive {:DOWN, ^monitor, :process, ^pid, _}, 1_000
      refute Process.alive?(pid)
    end

    if socket, do: assert({:error, :closed} = :gen_tcp.recv(socket, 0, 1_000))

    assert {:ok, rebound} =
             :gen_tcp.listen(fixture.port, ip: fixture.ip, active: false, reuseaddr: true)

    :gen_tcp.close(rebound)
  end

  defp progress(socket, owner, bytes \\ 0) do
    receive do
      :stop -> send(owner, {:body_progress, bytes})
    after
      100 ->
        case :gen_tcp.send(socket, :binary.copy("x", 16_384)) do
          :ok -> progress(socket, owner, bytes + 16_384)
          {:error, _} -> send(owner, {:body_progress, bytes})
        end
    end
  end
end
