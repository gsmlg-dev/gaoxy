Code.require_file("support/plug_response_headers_fixture.exs", __DIR__)

defmodule Gaoxy.PlugResponseHeadersNetworkTest do
  use ExUnit.Case, async: true

  for protocol <- ["h1", "h2"], mode <- ["operations", "notifications"] do
    @protocol protocol
    @mode mode
    @tag :tmp_dir
    test "#{protocol} normalizes legacy Plug headers for #{mode}", %{tmp_dir: dir} do
      path = Path.join(dir, "body")
      File.write!(path, "0123456789")

      {:ok, server} =
        Gaoxy.HTTP.start_link(
          plug: {Gaoxy.PlugResponseHeadersFixture, {self(), path}},
          protocols: [:http2, :http1],
          h2c: :prior_knowledge,
          http_limits: %{request_timeout: 5_000}
        )

      on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, 1_000) end)
      {:ok, {_, port}} = Gaoxy.info(server, :http).local
      root = Path.expand("../../..", __DIR__)

      python =
        System.get_env("GAOXY_H2_PYTHON") || System.get_env("GAOXY_QUIC_PYTHON") ||
          Path.join(root, ".audit/h2peer/bin/python")

      task =
        Task.async(fn ->
          System.cmd(
            python,
            [
              Path.join(__DIR__, "support/plug_response_headers_peer.py"),
              @protocol,
              @mode,
              to_string(port)
            ],
            cd: root,
            stderr_to_stdout: true
          )
        end)

      on_exit(fn -> if Process.alive?(task.pid), do: Process.exit(task.pid, :kill) end)

      if @mode == "notifications" do
        ref = task.ref

        worker =
          receive do
            {:notification_started, worker} -> worker
            {^ref, result} -> flunk("peer stopped before stream started: #{inspect(result)}")
          after
            5_000 -> flunk("notification stream did not start")
          end

        assert_receive :notification_received, 5_000
        assert Process.alive?(worker)
        send(worker, :send_notification)
      end

      {output, exit} = Task.await(task, 12_000)
      assert exit == 0, output
      assert output =~ "PASS #{@protocol} Plug response #{@mode}", output
      IO.write(output)
      assert_idle(server, Gaoxy.Lifecycle.deadline(1_000))
      assert :ok = Gaoxy.stop(server)
    end
  end

  defp assert_idle(server, deadline) do
    case Gaoxy.status(server, :http) do
      %{active: 0, retained_bytes: 0} ->
        :ok

      _ ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0

        receive do
        after
          5 -> :ok
        end

        assert_idle(server, deadline)
    end
  end
end
