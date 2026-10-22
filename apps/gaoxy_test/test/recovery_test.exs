defmodule Gaoxy.Test.RecoveryTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Test, as: Fixture
  alias Gaoxy.Test.Instance

  @tag :capture_log
  test "a TLS handshake accepted during drain is retained until forced cleanup" do
    fixture = Fixture.open(mode: :manual, profile: :http2, timeout: 1_000)
    [%{ip: ip, port: port}] = Fixture.info(fixture).endpoints
    server = :sys.get_state(fixture.pid).server
    runtime = :sys.get_state(server).runtime
    {:ok, service, _} = GenServer.call(runtime, {:lookup, :gaoxy_test})
    owner = self()
    token = make_ref()

    :sys.replace_state(service, fn state ->
      original = state.drain_fun

      %{
        state
        | drain_fun: fn transport, backend, gate, deadline ->
            send(owner, {token, :draining, self()})

            receive do
              ^token -> original.(transport, backend, gate, deadline)
            after
              2_000 -> raise "drain barrier expired"
            end
          end
      }
    end)

    :ok =
      :telemetry.attach(
        token,
        [:hell, :connection, :start],
        fn _, _, _, _ -> send(owner, {token, :accepted, self()}) end,
        nil
      )

    on_exit(fn -> :telemetry.detach(token) end)
    runtime_monitor = Process.monitor(runtime)
    Process.exit(fixture.pid, :kill)
    assert_receive {^token, :draining, helper}, 1_000
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    assert_receive {^token, :accepted, handler}, 1_000
    handler_monitor = Process.monitor(handler)
    refute handler in :sys.get_state(service).drain.resources
    send(helper, token)
    assert_receive {:DOWN, ^runtime_monitor, :process, ^runtime, _}, 2_000
    assert_receive {:DOWN, ^handler_monitor, :process, ^handler, _}, 1_000

    assert drain_socket(socket, System.monotonic_time(:millisecond) + 1_000) in [
             :closed,
             :econnreset
           ]

    assert {:error, :econnrefused} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)
  end

  for outcome <- [:event, :abnormal_down] do
    @outcome outcome
    test "final report retains session #{@outcome} after network cleanup" do
      {fixture, session, request_id} = established_session()
      closing = Task.async(fn -> Fixture.close(fixture) end)
      state = await_cleanup(fixture)
      assert state.cleanup == :ok
      assert state.phase == :closing
      send(session, {@outcome, fixture.pid, request_id})
      report = Task.await(closing, 2_000)
      assert report.status == :error

      case @outcome do
        :event ->
          assert [%{type: :callback, reason: :session_failed_after_cleanup}] = report.failures

        :abnormal_down ->
          assert [%{type: :session_terminated, reason: :session_failed_after_cleanup}] =
                   report.failures
      end

      assert Fixture.close(fixture) == report
    end
  end

  test "unresolved established sessions make deadline finalization uncertain" do
    {fixture, _session, request_id} = established_session(timeout: 100)
    report = Fixture.close(fixture)
    assert report.status == :error
    assert %{type: :session_cleanup_pending, request_id: request_id} in report.failures
  end

  defp established_session(options \\ []) do
    fixture = Fixture.open(Keyword.merge([mode: :manual, timeout: 1_000], options))
    Fixture.expect_once(fixture, :get, "/session", & &1)

    {:ok, request_id, _, _} =
      Instance.admit(fixture.pid, fixture.id, %{method: "GET", path: "/session"})

    session = spawn(fn -> session_loop() end)
    on_exit(fn -> Process.exit(session, :kill) end)
    :ok = Instance.complete(fixture.pid, request_id, :upgraded)
    :ok = Instance.establish(fixture.pid, request_id, session)
    {fixture, session, request_id}
  end

  defp session_loop do
    receive do
      {:gaoxy_test_cancel, :fixture_close} ->
        session_loop()

      {:event, instance, request_id} ->
        Instance.event(instance, request_id, %{
          type: :session_failure,
          kind: :exit,
          reason: :session_failed_after_cleanup,
          stacktrace: []
        })

      {:abnormal_down, _, _} ->
        exit(:session_failed_after_cleanup)
    after
      3_000 -> exit(:session_barrier_expired)
    end
  end

  defp await_cleanup(fixture, deadline \\ nil) do
    deadline = deadline || System.monotonic_time(:millisecond) + 1_000
    state = :sys.get_state(fixture.pid)

    if state.cleanup do
      state
    else
      assert System.monotonic_time(:millisecond) < deadline
      await_cleanup(fixture, deadline)
    end
  end

  defp drain_socket(socket, deadline) do
    case :gen_tcp.recv(socket, 0, max(deadline - System.monotonic_time(:millisecond), 0)) do
      {:ok, _packet} -> drain_socket(socket, deadline)
      {:error, reason} -> reason
    end
  end
end
