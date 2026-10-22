defmodule Gaoxy.Test.LifecycleTest do
  use ExUnit.Case, async: true
  alias Gaoxy.Test, as: Fixture
  alias Gaoxy.Test.Instance

  defp connect(fixture) do
    port = URI.parse(Fixture.url(fixture)).port
    :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false], 1_000)
  end

  defp start_request(fixture) do
    {:ok, socket} = connect(fixture)
    :ok = :gen_tcp.send(socket, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    socket
  end

  defp wait_state(fixture, predicate, deadline \\ nil) do
    deadline = deadline || System.monotonic_time(:millisecond) + 1_000
    state = :sys.get_state(fixture.pid)

    if predicate.(state) do
      state
    else
      assert System.monotonic_time(:millisecond) < deadline
      wait_state(fixture, predicate, deadline)
    end
  end

  defp blocked_fixture(options \\ []) do
    fixture = Fixture.open(Keyword.merge([mode: :manual, timeout: 600], options))
    owner = self()

    Fixture.expect_once(fixture, :get, "/", fn conn ->
      send(owner, {:entered, self()})

      receive do
        :release -> Plug.Conn.send_resp(conn, 200, "released")
      after
        2_000 -> flunk("request barrier deadline exceeded")
      end
    end)

    socket = start_request(fixture)
    assert_receive {:entered, executor}, 1_000
    {fixture, socket, executor}
  end

  test "finalizer seals admissions yet accepts terminal outcomes without blocking" do
    {fixture, socket, executor} = blocked_fixture()
    closing = Task.async(fn -> Fixture.close(fixture) end)
    wait_state(fixture, &(&1.phase == :closing))

    assert_raise ArgumentError, ~r/finalization/, fn ->
      Fixture.stub(fixture, :get, "/later", & &1)
    end

    assert {:error, :sealed} =
             Instance.admit(fixture.pid, fixture.id, %{method: "GET", path: "/late"})

    send(executor, :release)
    assert %{status: :ok, completed: 1} = Task.await(closing)
    :gen_tcp.close(socket)
  end

  test "ordinary blocked callback fails within one total close deadline and socket closes" do
    {fixture, socket, executor} = blocked_fixture(timeout: 300)
    monitor = Process.monitor(executor)
    started = System.monotonic_time(:millisecond)
    report = Fixture.close(fixture)
    assert System.monotonic_time(:millisecond) - started < 1_300
    assert report.status == :error
    assert Enum.any?(report.failures, &(&1.type in [:pending, :terminated]))
    assert_receive {:DOWN, ^monitor, :process, ^executor, _}, 1_000
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1_000)
    :gen_tcp.close(socket)
  end

  test "verify snapshot waits for terminal callback and times out pending admission" do
    {fixture, socket, executor} = blocked_fixture()

    assert_raise Gaoxy.Test.VerificationError, ~r/pending/, fn ->
      Fixture.verify!(fixture, timeout: 20)
    end

    verification = Task.async(fn -> Fixture.verify!(fixture) end)
    wait_state(fixture, &(map_size(&1.verifiers) == 1))
    send(executor, :release)
    assert :ok = Task.await(verification)
    assert %{status: :ok} = Fixture.close(fixture)
    :gen_tcp.close(socket)
  end

  test "snapshot excludes later pending callbacks without waiving their final errors" do
    {fixture, socket, executor} = blocked_fixture()
    owner = self()

    Fixture.stub(fixture, :get, "/later", fn _conn ->
      send(owner, {:later, self()})

      receive do
        :fail -> raise "late failure"
      after
        2_000 -> flunk("late barrier deadline")
      end
    end)

    verification = Task.async(fn -> Fixture.verify!(fixture) end)
    wait_state(fixture, &(map_size(&1.verifiers) == 1))
    {:ok, later_socket} = connect(fixture)

    :ok =
      :gen_tcp.send(
        later_socket,
        "GET /later HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
      )

    assert_receive {:later, later}, 1_000
    send(executor, :release)
    assert :ok = Task.await(verification)
    send(later, :fail)
    wait_state(fixture, &(map_size(&1.ledger.active) == 0))

    assert %{
             status: :error,
             failures: [%{type: :callback, reason: %RuntimeError{message: "late failure"}}]
           } = Fixture.close(fixture)

    :gen_tcp.close(socket)
    :gen_tcp.close(later_socket)
  end

  test "concurrent and repeated closes return one retained final report" do
    {fixture, socket, executor} = blocked_fixture()
    first = Task.async(fn -> Fixture.close(fixture) end)
    wait_state(fixture, &(&1.phase == :closing))
    second = Task.async(fn -> Fixture.close(fixture) end)
    wait_state(fixture, &(length(&1.closers) == 2))
    send(executor, :release)
    assert report = Task.await(first)
    assert Task.await(second) == report
    assert Fixture.close(fixture) == report
    :gen_tcp.close(socket)
  end

  test "owner death closes listener and leaves obligations reportable" do
    parent = self()

    owner =
      spawn(fn ->
        fixture = Fixture.open(mode: :manual, timeout: 500)
        Fixture.expect_once(fixture, :get, "/missing", &Plug.Conn.send_resp(&1, 200, "ok"))
        send(parent, {:fixture, fixture, Fixture.info(fixture)})

        receive do
          :die -> :ok
        end
      end)

    assert_receive {:fixture, fixture, info}, 1_000
    state = :sys.get_state(fixture.pid)
    monitor = Process.monitor(state.server)
    send(owner, :die)
    assert_receive {:DOWN, ^monitor, :process, _, _}, 1_500
    report = Fixture.close(fixture)
    assert report.status == :error
    assert Enum.any?(report.failures, &(&1.type == :missing))

    assert {:error, :econnrefused} =
             :gen_tcp.connect(
               ~c"127.0.0.1",
               URI.parse(info.url).port,
               [:binary, active: false],
               500
             )
  end

  test "manual owner abandonment is unverified even without unmet expectations" do
    parent = self()

    spawn(fn ->
      fixture = Fixture.open(mode: :manual)
      send(parent, {:abandoned, fixture})
    end)

    assert_receive {:abandoned, fixture}, 1_000
    wait_state(fixture, &(&1.phase != :open))
    assert %{status: :error, failures: [%{type: :owner_abandoned}]} = Fixture.close(fixture)
  end

  test "abrupt coordinator death cleans server without restarting an empty ledger" do
    fixture = Fixture.open(mode: :manual, timeout: 500)
    port = URI.parse(Fixture.url(fixture)).port
    server = :sys.get_state(fixture.pid).server
    monitor = Process.monitor(server)
    Process.exit(fixture.pid, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^server, _}, 1_500
    assert_raise Gaoxy.Test.UnavailableError, fn -> Fixture.verify!(fixture) end

    assert {:error, :econnrefused} =
             :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false], 500)
  end

  test "retained reports expire and cannot be verified successfully afterward" do
    fixture = Fixture.open(mode: :manual, retention: 30)
    monitor = Process.monitor(fixture.pid)
    assert %{status: :ok} = Fixture.close(fixture)
    assert_receive {:DOWN, ^monitor, :process, _, :normal}, 1_000
    assert_raise Gaoxy.Test.UnavailableError, ~r/expired/, fn -> Fixture.verify!(fixture) end
  end

  test "abrupt callback death consumes reservation and fails verification" do
    {fixture, socket, executor} = blocked_fixture()
    Process.exit(executor, :kill)
    wait_state(fixture, &(map_size(&1.ledger.active) == 0))

    assert %{status: :error, admitted: 1, failures: [%{type: :terminated}]} =
             Fixture.close(fixture)

    :gen_tcp.close(socket)
  end

  test "normal shutdown sessions pass while actual abnormal sessions fail" do
    for {reason, status} <- [{{:shutdown, :local_closed}, :ok}, {:session_broken, :error}] do
      fixture = Fixture.open(mode: :manual)
      Fixture.expect_once(fixture, :get, "/", & &1)

      session =
        spawn(fn ->
          receive do
            {:die, reason} -> exit(reason)
          end
        end)

      {:ok, id, _, _} = Instance.admit(fixture.pid, fixture.id, %{method: "GET", path: "/"})
      assert :ok = Instance.establish(fixture.pid, id, session)
      assert :ok = Instance.complete(fixture.pid, id, :ok)
      send(session, {:die, reason})
      wait_state(fixture, &(map_size(&1.sessions) == 0))
      assert Fixture.close(fixture).status == status
    end
  end

  test "original error throw and exit are reraised with original callback stack" do
    for kind <- [:error, :throw, :exit] do
      fixture = Fixture.open(mode: :manual)

      Fixture.expect_once(fixture, :get, "/", fn _conn ->
        case kind do
          :error -> raise "original callback"
          :throw -> throw(:original_throw)
          :exit -> exit(:original_exit)
        end
      end)

      conn = Plug.Test.conn(:get, "/")

      caught =
        try do
          Gaoxy.Test.DispatchPlug.call(conn, {fixture.pid, fixture.id})
        catch
          actual_kind, reason -> {actual_kind, reason, __STACKTRACE__}
        end

      {^kind, original, stacktrace} = caught

      reraised =
        try do
          Fixture.verify_and_close!(fixture)
        catch
          actual_kind, reason -> {actual_kind, reason, __STACKTRACE__}
        end

      assert {^kind, ^original, ^stacktrace} = reraised
    end
  end
end
