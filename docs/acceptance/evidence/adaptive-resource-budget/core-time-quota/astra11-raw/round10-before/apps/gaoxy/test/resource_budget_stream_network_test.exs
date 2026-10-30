defmodule Gaoxy.ResourceBudget.StreamNetworkTest do
  use ExUnit.Case, async: false
  @moduletag :protocol
  @moduletag :tmp_dir

  defmodule Echo do
    def init(context, owner) do
      send(owner, {:admitted, self(), context.peer})
      {:ok, owner}
    end

    def handle_data(bytes, owner) do
      send(owner, {:callback, self(), bytes})
      {:send, bytes, owner}
    end

    def terminate(reason, owner), do: send(owner, {:terminated, self(), reason})
  end

  for transport <- [:tcp, :tls] do
    test "admitted #{transport} callbacks complete after the listener drain barrier", context do
      transport = unquote(transport)
      tls = tls_options(transport, context.tmp_dir)

      runtime =
        start_supervised!(
          {Gaoxy,
           services: [
             %{id: "echo", transport: transport, handler: Echo, handler_options: self(), tls: tls}
           ]}
        )

      {:ok, {ip, port}} = Gaoxy.info(runtime, "echo").local
      {:ok, socket} = connect(transport, ip, port, context.tmp_dir)
      on_exit(fn -> close(transport, socket) end)
      assert_receive {:admitted, handler, _peer}, 1000
      monitor = Process.monitor(handler)
      exchange(transport, socket, "before", handler)

      eventually(fn ->
        Gaoxy.status(runtime, "echo").retained_bytes == :erlang.external_size(self())
      end)

      before = Gaoxy.status(runtime, "echo")
      assert before.active == 1
      assert before.usage == funded(2048, 65_536, 65_507)
      assert before.retained_bytes == :erlang.external_size(self())
      assert before.temporary_bytes == before.usage - before.retained_bytes

      removal = Task.async(fn -> Gaoxy.remove(runtime, "echo", 3000) end)
      eventually(fn -> Gaoxy.status(runtime, "echo").state == :draining end)

      eventually(fn ->
        case :gen_tcp.connect(ip, port, [:binary, active: false], 100) do
          {:error, :econnrefused} ->
            true

          {:ok, probe} ->
            :gen_tcp.close(probe)
            false

          _ ->
            false
        end
      end)

      assert Process.alive?(handler)
      exchange(transport, socket, "admitted-after-drain", handler)
      exchange(transport, socket, "second-admitted-after-drain", handler)
      eventually(fn -> Gaoxy.status(runtime, "echo").retained_bytes == before.retained_bytes end)
      after_callbacks = Gaoxy.status(runtime, "echo")
      assert after_callbacks.active == 1
      assert after_callbacks.usage == before.usage
      assert after_callbacks.retained_bytes == before.retained_bytes
      assert after_callbacks.temporary_bytes == before.temporary_bytes
      close(transport, socket)
      assert_receive {:DOWN, ^monitor, :process, ^handler, {:shutdown, :peer_closed}}, 1000
      assert :ok = Task.await(removal, 3500)
      assert {:error, :not_running} = Gaoxy.info(runtime, "echo")
      eventually(fn -> Gaoxy.resource_budget(runtime).usage == 0 end)
    end

    test "#{transport} exact explicit byte floor and max_active stay hard", context do
      transport = unquote(transport)
      floor = funded(2048, 256, 64)

      runtime =
        start_runtime(transport, context.tmp_dir,
          limits: %{max_bytes: floor, max_active: 1, max_state: 256, max_output: 64}
        )

      {:ok, {ip, port}} = Gaoxy.info(runtime, "echo").local
      {:ok, socket} = connect(transport, ip, port, context.tmp_dir)
      on_exit(fn -> close(transport, socket) end)
      assert_receive {:admitted, handler, _}, 1000
      exchange(transport, socket, "echo", handler)
      assert %{usage: ^floor, active: 1} = Gaoxy.status(runtime, "echo")
      rejected_connection(transport, ip, port, context.tmp_dir, true)
      refute_receive {:admitted, _, _}, 50
      assert %{usage: ^floor, active: 1} = Gaoxy.status(runtime, "echo")
      close(transport, socket)
      eventually(fn -> Gaoxy.resource_budget(runtime).usage == 0 end)
    end

    test "#{transport} explicit byte cap below completion floor refuses admission", context do
      transport = unquote(transport)
      floor = funded(2048, 256, 64)

      runtime =
        start_runtime(transport, context.tmp_dir,
          limits: %{max_bytes: floor - 1, max_state: 256, max_output: 64}
        )

      {:ok, {ip, port}} = Gaoxy.info(runtime, "echo").local
      rejected_connection(transport, ip, port, context.tmp_dir)
      refute_receive {:admitted, _, _}, 50
      eventually(fn -> Gaoxy.status(runtime, "echo").rejected == 1 end)
      assert %{usage: 0, active: 0} = Gaoxy.status(runtime, "echo")
      assert Gaoxy.resource_budget(runtime).usage == 0
    end

    test "#{transport} explicit receive buffer is preserved and funded", context do
      transport = unquote(transport)
      floor = funded(4096, 256, 64)

      runtime =
        start_runtime(transport, context.tmp_dir,
          limits: %{max_bytes: floor, max_state: 256, max_output: 64},
          hell_options: [transport_options: [buffer: 4096, recbuf: 4096]]
        )

      {:ok, {ip, port}} = Gaoxy.info(runtime, "echo").local
      {:ok, socket} = connect(transport, ip, port, context.tmp_dir)
      on_exit(fn -> close(transport, socket) end)
      assert_receive {:admitted, handler, _}, 1000
      exchange(transport, socket, "tuned", handler)
      assert %{usage: ^floor, active: 1} = Gaoxy.status(runtime, "echo")
      close(transport, socket)
      eventually(fn -> Gaoxy.resource_budget(runtime).usage == 0 end)
    end

    test "#{transport} funded connection still closes at the original drain deadline", context do
      transport = unquote(transport)
      runtime = start_runtime(transport, context.tmp_dir)
      {:ok, {ip, port}} = Gaoxy.info(runtime, "echo").local
      {:ok, socket} = connect(transport, ip, port, context.tmp_dir)
      on_exit(fn -> close(transport, socket) end)
      assert_receive {:admitted, handler, _}, 1000
      exchange(transport, socket, "before", handler)
      monitor = Process.monitor(handler)
      removal = Task.async(fn -> Gaoxy.remove(runtime, "echo", 200) end)
      eventually(fn -> Gaoxy.status(runtime, "echo").state == :draining end)
      exchange(transport, socket, "paid", handler)
      assert {:error, {:deadline_exceeded, :cleanup_pending}} = Task.await(removal, 1000)
      assert_receive {:DOWN, ^monitor, :process, ^handler, _reason}, 1000
      assert {:error, :closed} = recv(transport, socket, 1)
      eventually(fn -> Gaoxy.info(runtime, "echo") == {:error, :not_running} end)
      eventually(fn -> Gaoxy.resource_budget(runtime).usage == 0 end)
    end
  end

  defp funded(buffer, state, output), do: 2 * (100 * buffer + 18_437) + 2 * state + output

  defp start_runtime(transport, directory, options \\ []) do
    spec =
      Map.merge(
        %{
          id: "echo",
          transport: transport,
          handler: Echo,
          handler_options: self(),
          tls: tls_options(transport, directory)
        },
        Map.new(options)
      )

    start_supervised!({Gaoxy, services: [spec]})
  end

  defp rejected_connection(transport, ip, port, directory, at_connection_cap? \\ false) do
    case connect(transport, ip, port, directory) do
      {:ok, socket} ->
        assert {:error, :closed} = recv(transport, socket, 1)
        close(transport, socket)

      {:error, reason} ->
        # Hell's TLS connection cap can reject before finishing the handshake;
        # no second handler is admitted, and the client retains its finite deadline.
        assert reason in [:closed, :econnreset] or
                 (at_connection_cap? and transport == :tls and reason == :timeout)
    end
  end

  defp exchange(transport, socket, bytes, handler) do
    assert :ok = send_bytes(transport, socket, bytes)
    assert {:ok, ^bytes} = recv(transport, socket, byte_size(bytes))
    assert_receive {:callback, ^handler, ^bytes}, 1000
  end

  defp tls_options(:tcp, _), do: %{}

  defp tls_options(:tls, directory) do
    root = Path.expand("../../..", __DIR__)

    {_, 0} =
      System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), directory],
        stderr_to_stdout: true
      )

    %{
      provider: :otp,
      certfile: Path.join(directory, "cert.pem"),
      keyfile: Path.join(directory, "key.pem"),
      alpn: ["gaoxy-echo-v1"]
    }
  end

  defp connect(:tcp, ip, port, _), do: :gen_tcp.connect(ip, port, [:binary, active: false], 1000)

  defp connect(:tls, ip, port, directory) do
    :ssl.connect(
      ip,
      port,
      [
        :binary,
        active: false,
        verify: :verify_peer,
        alpn_advertised_protocols: ["gaoxy-echo-v1"],
        cacertfile: String.to_charlist(Path.join(directory, "ca.pem")),
        server_name_indication: ~c"localhost"
      ],
      1000
    )
  end

  defp send_bytes(:tcp, socket, bytes), do: :gen_tcp.send(socket, bytes)
  defp send_bytes(:tls, socket, bytes), do: :ssl.send(socket, bytes)
  defp recv(:tcp, socket, size), do: :gen_tcp.recv(socket, size, 1000)
  defp recv(:tls, socket, size), do: :ssl.recv(socket, size, 1000)
  defp close(:tcp, socket), do: :gen_tcp.close(socket)
  defp close(:tls, socket), do: :ssl.close(socket)

  defp eventually(fun, attempts \\ 100)
  defp eventually(fun, 0), do: assert(fun.())

  defp eventually(fun, attempts) do
    if fun.(),
      do: :ok,
      else:
        (
          Process.sleep(10)
          eventually(fun, attempts - 1)
        )
  end
end
