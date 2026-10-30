defmodule Gaoxy.HTTP.HTTP3.ResourceBudgetNetworkTest do
  use ExUnit.Case, async: false
  @moduletag :protocol

  defmodule Endpoint do
    def init(observer), do: {:ok, observer}

    def call(exchange, observer) do
      send(observer, {:h3_budget_request, self(), exchange.request.path})

      receive do
        :release -> Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "budget-ok")
      after
        Gaoxy.Lifecycle.remaining(exchange.deadline) -> {:error, :timeout, exchange}
      end
    end
  end

  @tag :tmp_dir
  test "concurrent H3 requests refuse only the excess stream and release every ownership lifetime",
       %{tmp_dir: directory} do
    root = Path.expand("../../..", __DIR__)

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), directory],
               stderr_to_stdout: true
             )

    {:ok, spec} =
      Gaoxy.HTTP.HTTP3.service_spec(
        endpoint: {Endpoint, self()},
        limits: %{max_streams: 2},
        tls: %{
          certfile: Path.join(directory, "cert.pem"),
          keyfile: Path.join(directory, "key.pem")
        }
      )

    {:ok, server} =
      Gaoxy.start_link(
        services: [spec],
        resource_budget: %{soft_limit: 16_777_216, hard_limit: 33_554_432}
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {_, port}} = Gaoxy.info(server, :http3).local
    python = Path.join(root, ".audit/h2peer/bin/python")

    script = ~S'''
    import asyncio, sys
    from types import SimpleNamespace
    sys.path.insert(0, 'integration/http3')
    from peer import opened
    async def run():
        args=SimpleNamespace(port=int(sys.argv[1]),ca=sys.argv[2],mode='startup')
        async with opened(args) as client:
            await client.until(lambda: client.http.received_settings is not None)
            a=client.request(path=b'/first')
            b=client.request(path=b'/second')
            # The Elixir endpoint sends the authoritative two-worker barrier.
            await asyncio.to_thread(sys.stdin.readline)
            refused=client.request(path=b'/refused')
            await client.until(lambda: refused in client.resets)
            assert client.resets[refused]==0x107, client.resets
            assert a not in client.resets and b not in client.resets, client.resets
            assert a not in client.ended and b not in client.ended
            await asyncio.wait_for(client.ping(),2)
            print('H3_BUDGET_REFUSAL_PASS',flush=True)
            await asyncio.gather(client.response(a,b'budget-ok'),client.response(b,b'budget-ok'))
            await asyncio.wait_for(client.ping(),2)
            assert client.terminated is None, client.terminated
        print('H3_BUDGET_CONCURRENCY_PASS',flush=True)
    asyncio.run(run())
    '''

    peer =
      Port.open(
        {:spawn_executable, String.to_charlist(python)},
        [
          :binary,
          :exit_status,
          :stderr_to_stdout,
          args: ["-c", script, to_string(port), Path.join(directory, "ca.pem")],
          cd: root
        ]
      )

    on_exit(fn -> if Port.info(peer), do: Port.close(peer) end)
    assert_receive {:h3_budget_request, first, "/first"}, 5_000
    assert_receive {:h3_budget_request, second, "/second"}, 5_000
    assert first != second and Process.alive?(first) and Process.alive?(second)

    assert %{active_connections: 1, active_requests: 2, active_h3_streams: 2, usage: bytes} =
             Gaoxy.resource_budget(server)

    assert bytes > 0
    assert Port.command(peer, "admit-third\n")
    output = await_marker(peer, "H3_BUDGET_REFUSAL_PASS", "", Gaoxy.Lifecycle.deadline(5_000))
    assert Process.alive?(first) and Process.alive?(second)

    assert %{active_connections: 1, active_requests: 2, active_h3_streams: 2} =
             Gaoxy.resource_budget(server)

    refute_receive {:h3_budget_request, _, "/refused"}
    send(first, :release)
    send(second, :release)
    output = await_exit(peer, output, Gaoxy.Lifecycle.deadline(10_000))
    assert output =~ "H3_BUDGET_CONCURRENCY_PASS"
    await_idle(server, Gaoxy.Lifecycle.deadline(5_000))
    assert :ok = Gaoxy.stop(server)
    IO.puts(output)
  end

  @tag :tmp_dir
  test "a killed request leaves its H3 sibling live and service drain settles active workers", %{
    tmp_dir: directory
  } do
    root = Path.expand("../../..", __DIR__)

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), directory],
               stderr_to_stdout: true
             )

    {:ok, spec} =
      Gaoxy.HTTP.HTTP3.service_spec(
        endpoint: {Endpoint, self()},
        tls: %{
          certfile: Path.join(directory, "cert.pem"),
          keyfile: Path.join(directory, "key.pem")
        }
      )

    {:ok, server} = Gaoxy.start_link(services: [spec])
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http3).local
    python = Path.join(root, ".audit/h2peer/bin/python")

    script = ~S'''
    import asyncio, sys
    from types import SimpleNamespace
    sys.path.insert(0, 'integration/http3')
    from peer import opened
    async def run():
        args=SimpleNamespace(port=int(sys.argv[1]),ca=sys.argv[2],mode='startup')
        async with opened(args) as client:
            await client.until(lambda: client.http.received_settings is not None)
            failed=client.request(path=b'/crash')
            sibling=client.request(path=b'/sibling')
            await client.until(lambda: failed in client.resets)
            assert client.resets[failed]==0x102, client.resets
            assert sibling not in client.resets and sibling not in client.ended
            await asyncio.wait_for(client.ping(),2)
            print('H3_BUDGET_CRASH_PASS',flush=True)
            await client.response(sibling,b'budget-ok')
            client.request(path=b'/drain')
            await client.until(lambda: client.terminated is not None,allow_close=True)
        print('H3_BUDGET_DRAIN_PASS',flush=True)
    asyncio.run(run())
    '''

    peer =
      Port.open(
        {:spawn_executable, String.to_charlist(python)},
        [
          :binary,
          :exit_status,
          :stderr_to_stdout,
          args: ["-c", script, to_string(port), Path.join(directory, "ca.pem")],
          cd: root
        ]
      )

    on_exit(fn -> if Port.info(peer), do: Port.close(peer) end)
    assert_receive {:h3_budget_request, failed, "/crash"}, 5_000
    assert_receive {:h3_budget_request, sibling, "/sibling"}, 5_000
    monitor = Process.monitor(failed)
    Process.exit(failed, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^failed, :killed}, 1_000
    output = await_marker(peer, "H3_BUDGET_CRASH_PASS", "", Gaoxy.Lifecycle.deadline(5_000))
    assert Process.alive?(sibling)
    send(sibling, :release)
    assert_receive {:h3_budget_request, draining, "/drain"}, 5_000
    draining_monitor = Process.monitor(draining)
    assert :ok = Gaoxy.remove(server, :http3, 3_000)
    assert_receive {:DOWN, ^draining_monitor, :process, ^draining, _}, 1_000
    output = await_exit(peer, output, Gaoxy.Lifecycle.deadline(5_000))
    assert output =~ "H3_BUDGET_DRAIN_PASS"
    await_budget_idle(server, Gaoxy.Lifecycle.deadline(5_000))
    assert {:ok, socket} = :gen_udp.open(port, [:binary, active: false, ip: ip])
    :ok = :gen_udp.close(socket)
    assert :ok = Gaoxy.stop(server)
    IO.puts(output)
  end

  defp await_budget_idle(server, deadline) do
    case Gaoxy.resource_budget(server) do
      %{usage: 0, active_connections: 0, active_requests: 0, active_h3_streams: 0} ->
        :ok

      status ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)

        receive do
        after
          5 -> await_budget_idle(server, deadline)
        end
    end
  end

  defp await_marker(peer, marker, output, deadline) do
    if String.contains?(output, marker) do
      output
    else
      receive do
        {^peer, {:data, bytes}} -> await_marker(peer, marker, output <> bytes, deadline)
        {^peer, {:exit_status, code}} -> flunk("peer exited #{code}: #{output}")
      after
        Gaoxy.Lifecycle.remaining(deadline) -> flunk("peer marker timeout: #{output}")
      end
    end
  end

  defp await_exit(peer, output, deadline) do
    receive do
      {^peer, {:data, bytes}} -> await_exit(peer, output <> bytes, deadline)
      {^peer, {:exit_status, 0}} -> output
      {^peer, {:exit_status, code}} -> flunk("peer exited #{code}: #{output}")
    after
      Gaoxy.Lifecycle.remaining(deadline) -> flunk("peer exit timeout: #{output}")
    end
  end

  defp await_idle(server, deadline) do
    case {Gaoxy.resource_budget(server), Gaoxy.status(server, :http3)} do
      {%{usage: 0, active_connections: 0, active_requests: 0, active_h3_streams: 0},
       %{active: 0, retained_bytes: 0, cleanup_pending: 0, cleanup_failed: nil}} ->
        :ok

      status ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)

        receive do
        after
          5 -> await_idle(server, deadline)
        end
    end
  end
end
