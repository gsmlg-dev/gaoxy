defmodule Gaoxy.Test.SubprocessTest do
  use ExUnit.Case, async: false

  @network """
  def request(fixture), do: request(fixture, "/")
  def request(fixture, path) do
    port = URI.parse(Gaoxy.Test.url(fixture)).port
    {:ok, socket} = :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false], 1000)
    :ok = :gen_tcp.send(socket, ["GET ", path, " HTTP/1.1\\r\\nHost: localhost\\r\\nConnection: close\\r\\n\\r\\n"])
    result = :gen_tcp.recv(socket, 0, 2000)
    :gen_tcp.close(socket)
    result
  end
  """

  defp run(code) do
    executable = System.find_executable("elixir")
    paths = Path.wildcard(Path.expand("../../../_build/test/lib/*/ebin", __DIR__))
    assert paths != []
    arguments = ["--erl", "+S 2:2"] ++ Enum.flat_map(paths, &["-pa", &1])
    watchdog = "spawn(fn -> Process.sleep(15_000); System.halt(99) end)\n"
    System.cmd(executable, arguments ++ ["-e", watchdog <> code], stderr_to_stdout: true)
  end

  defp suite(body) do
    """
    ExUnit.start(autorun: false)
    defmodule FixtureSubprocess do
      use ExUnit.Case
      #{@network}
      #{body}
    end
    result = ExUnit.run()
    IO.puts("FIXTURE_RESULT tests=\#{result.total} failures=\#{result.failures}")
    System.halt(if result.failures == 0, do: 0, else: 1)
    """
  end

  for {name, body, evidence} <- [
        {:missing,
         """
         test "missing" do
           fixture = Gaoxy.Test.open()
           Gaoxy.Test.expect_once(fixture, :get, "/missing", &Plug.Conn.send_resp(&1, 200, "ok"))
         end
         """, "GET /missing"},
        {:excessive,
         """
         test "excessive" do
           fixture = Gaoxy.Test.open()
           Gaoxy.Test.expect_once(fixture, :get, "/", &Plug.Conn.send_resp(&1, 200, "ok"))
           request(fixture)
           request(fixture)
         end
         """, "excessive"},
        {:unexpected,
         """
         test "unexpected" do
           fixture = Gaoxy.Test.open()
           request(fixture, "/unexpected")
         end
         """, "GET /unexpected"}
      ] do
    test "automatic #{name} request fails an isolated ExUnit suite" do
      {output, exit_code} = run(suite(unquote(body)))
      assert exit_code == 1, output
      assert output =~ "FIXTURE_RESULT tests=1 failures=1"
      assert output =~ unquote(evidence)
    end
  end

  test "HTTP callback assertion fails automatic ExUnit with original callback location" do
    {output, exit_code} =
      run(
        suite("""
        def original_callback(conn) do
          assert conn.request_path == "/expected", "original network assertion"
          Plug.Conn.send_resp(conn, 200, "ok")
        end
        test "callback" do
          fixture = Gaoxy.Test.open()
          Gaoxy.Test.expect_once(fixture, :get, "/", &original_callback/1)
          request(fixture)
        end
        """)
      )

    assert exit_code == 1, output
    assert output =~ "FIXTURE_RESULT tests=1 failures=1"
    assert output =~ "original network assertion"
    assert output =~ "original_callback/1"
  end

  test "automatic report survives test-supervised client teardown" do
    {output, exit_code} =
      run(
        suite("""
        test "test-supervised client" do
          fixture = Gaoxy.Test.open()
          Gaoxy.Test.expect_once(fixture, :get, "/", &Plug.Conn.send_resp(&1, 200, "ok"))
          client = start_supervised!({Agent, fn -> :client end})
          Agent.get(client, fn _ -> request(fixture) end)
          on_exit(fn ->
            refute Process.alive?(client)
            assert :ok = Gaoxy.Test.verify!(fixture)
          end)
        end
        """)
      )

    assert exit_code == 0, output
    assert output =~ "FIXTURE_RESULT tests=1 failures=0"
  end

  test "setup failure after open preserves missing obligation in on_exit" do
    {output, exit_code} =
      run(
        suite("""
        setup do
          {:ok, keeper} = Agent.start(fn -> nil end)
          on_exit(fn ->
            fixture = Agent.get(keeper, & &1)
            monitor = Process.monitor(fixture.pid)
            assert_receive {:DOWN, ^monitor, :process, _, _}, 1000
            IO.puts("AUTOMATIC_HOOK_CONSUMED_REPORT")
            Agent.stop(keeper)
          end)
          fixture = Gaoxy.Test.open()
          Agent.update(keeper, fn _ -> fixture end)
          Gaoxy.Test.expect_once(fixture, :get, "/setup-missing", &Plug.Conn.send_resp(&1, 200, "ok"))
          port = URI.parse(Gaoxy.Test.url(fixture)).port
          on_exit(fn ->
            report = Gaoxy.Test.close(fixture)
            assert %{status: :error, failures: [%{type: :missing, route: {"GET", "/setup-missing"}}]} = report
            assert {:error, :econnrefused} = :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false], 500)
            IO.puts("RETAINED GET /setup-missing; LISTENER_CLOSED")
          end)
          raise "setup exploded"
        end
        test "setup failure" do
          flunk("unreachable")
        end
        """)
      )

    assert exit_code == 1, output
    assert output =~ "setup exploded"
    assert output =~ "GET /setup-missing"
    assert output =~ "LISTENER_CLOSED"
    assert output =~ "AUTOMATIC_HOOK_CONSUMED_REPORT"
    assert output =~ "FIXTURE_RESULT tests=1 failures=1"
  end

  test "explicit automatic close cannot suppress the retained failing hook" do
    {output, exit_code} =
      run(
        suite("""
        test "explicit close" do
          fixture = Gaoxy.Test.open()
          Gaoxy.Test.expect_once(fixture, :get, "/retained", &Plug.Conn.send_resp(&1, 200, "ok"))
          assert %{status: :error} = Gaoxy.Test.close(fixture)
        end
        """)
      )

    assert exit_code == 1, output
    assert output =~ "GET /retained"
    assert output =~ "FIXTURE_RESULT tests=1 failures=1"
  end

  test "manual mode and startup rollback never start ExUnit application or runner" do
    {output, exit_code} =
      run("""
      loaded = fn -> Enum.any?(Application.started_applications(), fn {app, _, _} -> app == :ex_unit end) end
      false = loaded.()
      nil = Process.whereis(ExUnit.Server)
      fixture = Gaoxy.Test.open(mode: :manual)
      false = loaded.()
      nil = Process.whereis(ExUnit.Server)
      :ok = Gaoxy.Test.verify!(fixture)
      %{status: :ok} = Gaoxy.Test.close(fixture)
      children = DynamicSupervisor.count_children(Gaoxy.Test.Supervisor).active
      try do
        Gaoxy.Test.open()
        raise "automatic open should fail outside test process"
      rescue
        _error -> :ok
      end
      ^children = DynamicSupervisor.count_children(Gaoxy.Test.Supervisor).active
      false = loaded.()
      nil = Process.whereis(ExUnit.Server)
      IO.puts("MANUAL_AND_ROLLBACK_OK")
      """)

    assert exit_code == 0, output
    assert output =~ "MANUAL_AND_ROLLBACK_OK"
  end
end
