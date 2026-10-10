defmodule Gaoxy.Proxy.StreamRelayTLSTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.StreamRelay
  @timeout 3_000

  setup %{tmp_dir: dir} do
    script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
    assert {_, 0} = System.cmd("bash", [script, dir], stderr_to_stdout: true)
    {:ok, fixtures: dir}
  end

  @tag :tmp_dir
  test "TLS modes reject an unaudited OTP internal active receive count" do
    previous = Application.fetch_env(:ssl, :internal_active_n)

    try do
      for active <- [0, 101, :unbounded] do
        Application.put_env(:ssl, :internal_active_n, active)

        assert {:error, _} =
                 StreamRelay.validate_options(%{
                   upstream: {{127, 0, 0, 1}, 80},
                   mode: :tls_termination
                 })
      end
    after
      case previous do
        {:ok, value} -> Application.put_env(:ssl, :internal_active_n, value)
        :error -> Application.delete_env(:ssl, :internal_active_n)
      end
    end
  end

  @tag :tmp_dir
  test "TLS bursts reserve conservative OTP delivery windows before either receive direction", %{
    fixtures: dir
  } do
    payload = :binary.copy(<<0, 255, 1, 2>>, 786_432)

    for {mode, downstream, upstream_mode} <- [
          {:tls_termination, :tls, :tcp},
          {:tls_upstream, :tcp, :tls}
        ] do
      {upstream, peer} =
        peer(upstream_mode, dir, fn socket, transport ->
          assert {:ok, ^payload} =
                   if(transport == :tcp,
                     do: :gen_tcp.recv(socket, byte_size(payload), @timeout),
                     else: :ssl.recv(socket, byte_size(payload), @timeout)
                   )

          assert :ok =
                   if(transport == :tcp,
                     do: :gen_tcp.send(socket, payload),
                     else: :ssl.send(socket, payload)
                   )

          assert {:ok, "done"} =
                   if(transport == :tcp,
                     do: :gen_tcp.recv(socket, 4, @timeout),
                     else: :ssl.recv(socket, 4, @timeout)
                   )
        end)

      options = %{mode: mode}

      options =
        if mode == :tls_upstream,
          do: Map.put(options, :upstream_tls, tls_options(dir)),
          else: options

      server = relay(upstream, options, downstream, dir)
      socket = if downstream == :tls, do: tls_connect(server, dir), else: tcp_connect(server)
      await_active(server, Gaoxy.Lifecycle.deadline(@timeout))
      assert %{retained_bytes: reserved} = Gaoxy.status(server, :relay)
      delivery = 100 * 16_384 + 18_437
      assert reserved >= 4 * delivery + 4 * 16_384 + 4_096

      assert :ok =
               if(downstream == :tls,
                 do: :ssl.send(socket, payload),
                 else: :gen_tcp.send(socket, payload)
               )

      assert {:ok, ^payload} =
               if(downstream == :tls,
                 do: :ssl.recv(socket, byte_size(payload), @timeout),
                 else: :gen_tcp.recv(socket, byte_size(payload), @timeout)
               )

      assert :ok =
               if(downstream == :tls,
                 do: :ssl.send(socket, "done"),
                 else: :gen_tcp.send(socket, "done")
               )

      assert_peer(peer)
      assert_restored(server)
    end
  end

  @tag :tmp_dir
  test "TLS termination forwards bytes to TCP and explicitly closes on TLS EOF", %{fixtures: dir} do
    telemetry = make_ref()
    :ok = :telemetry.attach(telemetry, [:gaoxy, :relay_closed], &__MODULE__.closed/4, self())
    on_exit(fn -> :telemetry.detach(telemetry) end)

    {upstream, peer} =
      peer(:tcp, dir, fn socket, :tcp ->
        assert {:ok, "request"} = :gen_tcp.recv(socket, 7, @timeout)
        :ok = :gen_tcp.send(socket, "response")
        :ok = :gen_tcp.shutdown(socket, :write)
      end)

    server = relay(upstream, %{mode: :tls_termination}, :tls, dir)
    socket = tls_connect(server, dir)
    :ok = :ssl.send(socket, "request")
    assert {:ok, "response"} = :ssl.recv(socket, 8, @timeout)
    assert {:error, :closed} = :ssl.recv(socket, 0, @timeout)

    assert_receive {:relay_closed, %{count: 1},
                    %{mode: :tls_termination, reason: :tls_directional_shutdown_not_supported}},
                   @timeout

    assert_peer(peer)
    assert_restored(server)
  end

  @tag :tmp_dir
  test "independent Python TLS client verifies termination and opaque passthrough", %{
    fixtures: dir
  } do
    payload = :binary.copy(<<0, 255, 1, 2>>, 256)

    for {mode, downstream, upstream_mode} <- [
          {:tls_termination, :tls, :tcp},
          {:tls_passthrough, :tcp, :tls}
        ] do
      {upstream, peer} =
        peer(upstream_mode, dir, fn socket, transport ->
          assert {:ok, ^payload} =
                   if(transport == :tcp,
                     do: :gen_tcp.recv(socket, byte_size(payload), @timeout),
                     else: :ssl.recv(socket, byte_size(payload), @timeout)
                   )

          assert :ok =
                   if(transport == :tcp,
                     do: :gen_tcp.send(socket, payload),
                     else: :ssl.send(socket, payload)
                   )
        end)

      server = relay(upstream, %{mode: mode}, downstream, dir)
      {:ok, {ip, port}} = Gaoxy.info(server, :relay).local

      code = """
      import socket, ssl, sys
      ctx = ssl.create_default_context(cafile=sys.argv[3])
      raw = socket.create_connection((sys.argv[1], int(sys.argv[2])), timeout=2)
      with ctx.wrap_socket(raw, server_hostname='localhost') as conn:
          data = bytes([0,255,1,2]) * 256
          conn.sendall(data)
          reply = b''
          while len(reply) < len(data):
              piece = conn.recv(len(data)-len(reply))
              assert piece, 'unexpected TLS EOF'
              reply += piece
          assert reply == data, 'relay changed application bytes'
          print('PASS verified independent TLS peer')
      """

      assert {"PASS verified independent TLS peer\n", 0} =
               System.cmd(
                 "python3",
                 [
                   "-c",
                   code,
                   to_string(:inet.ntoa(ip)),
                   Integer.to_string(port),
                   Path.join(dir, "ca.pem")
                 ],
                 stderr_to_stdout: true
               )

      assert_peer(peer)
      assert_restored(server)
    end
  end

  @tag :tmp_dir
  test "verified upstream TLS interoperates with an independent Python TLS server", %{
    fixtures: dir
  } do
    code = """
    import socket, ssl, sys
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(sys.argv[1], sys.argv[2])
    with socket.socket() as listener:
        listener.settimeout(2)
        listener.bind(('127.0.0.1', 0))
        listener.listen(1)
        print('READY ' + str(listener.getsockname()[1]), flush=True)
        raw, _ = listener.accept()
        raw.settimeout(2)
        with ctx.wrap_socket(raw, server_side=True) as conn:
            request = b''
            while len(request) < 7:
                piece = conn.recv(7-len(request))
                assert piece, 'unexpected TLS EOF'
                request += piece
            assert request == b'request'
            conn.sendall(b'python-verified')
    print('PASS independent verified upstream', flush=True)
    """

    port =
      Port.open({:spawn_executable, System.find_executable("python3")}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        {:line, 1024},
        args: ["-u", "-c", code, Path.join(dir, "cert.pem"), Path.join(dir, "key.pem")]
      ])

    on_exit(fn -> if Port.info(port), do: Port.close(port) end)
    assert_receive {^port, {:data, {:eol, "READY " <> upstream_port}}}, @timeout
    upstream = {{127, 0, 0, 1}, String.to_integer(upstream_port)}
    server = relay(upstream, %{mode: :tls_upstream, upstream_tls: tls_options(dir)}, :tcp, dir)
    socket = tcp_connect(server)
    :ok = :gen_tcp.send(socket, "request")
    assert {:ok, "python-verified"} = :gen_tcp.recv(socket, 15, @timeout)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    assert_receive {^port, {:data, {:eol, "PASS independent verified upstream"}}}, @timeout
    assert_receive {^port, {:exit_status, 0}}, @timeout
    assert_restored(server)
  end

  def closed(_, measurements, metadata, owner),
    do: send(owner, {:relay_closed, measurements, metadata})

  @tag :tmp_dir
  test "verified upstream TLS dials the numeric IP with the explicit hostname and CA", %{
    fixtures: dir
  } do
    {upstream, peer} =
      peer(:tls, dir, fn socket, :tls ->
        assert {:ok, "request"} = :ssl.recv(socket, 7, @timeout)
        :ok = :ssl.send(socket, "verified")
      end)

    server = relay(upstream, %{mode: :tls_upstream, upstream_tls: tls_options(dir)}, :tcp, dir)
    socket = tcp_connect(server)
    :ok = :gen_tcp.send(socket, "request")
    assert {:ok, "verified"} = :gen_tcp.recv(socket, 8, @timeout)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    assert_peer(peer)
    assert_restored(server)
  end

  @tag :tmp_dir
  test "incorrect upstream TLS hostname or trust closes without sending application bytes", %{
    fixtures: dir
  } do
    other = Path.join(dir, "other")
    File.mkdir_p!(other)
    script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
    assert {_, 0} = System.cmd("bash", [script, other], stderr_to_stdout: true)

    for tls <- [
          %{tls_options(dir) | server_name: "wrong.example"},
          %{tls_options(dir) | cacertfile: Path.join(other, "ca.pem")}
        ] do
      {upstream, peer} =
        peer(
          :tls,
          dir,
          fn socket, :tls ->
            assert {:error, :closed} = :ssl.recv(socket, 0, @timeout)
          end,
          :rejection
        )

      server = relay(upstream, %{mode: :tls_upstream, upstream_tls: tls}, :tcp, dir)
      socket = tcp_connect(server)
      :ok = :gen_tcp.send(socket, "must-not-reach-upstream")
      assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      assert_peer(peer)
      assert_restored(server)
    end
  end

  @tag :tmp_dir
  test "opaque passthrough preserves the end-to-end TLS handshake and certificate identity", %{
    fixtures: dir
  } do
    {upstream, peer} =
      peer(:tls, dir, fn socket, :tls ->
        assert {:ok, "opaque"} = :ssl.recv(socket, 6, @timeout)
        :ok = :ssl.send(socket, "end-to-end")
      end)

    server = relay(upstream, %{mode: :tls_passthrough}, :tcp, dir)
    socket = tls_connect(server, dir)
    :ok = :ssl.send(socket, "opaque")
    assert {:ok, "end-to-end"} = :ssl.recv(socket, 10, @timeout)
    assert {:error, :closed} = :ssl.recv(socket, 0, @timeout)
    assert_peer(peer)
    assert_restored(server)
  end

  defp relay(upstream, options, transport, dir) do
    spec = %{
      id: :relay,
      transport: transport,
      handler_mode: :native,
      handler: StreamRelay,
      handler_options:
        Map.merge(%{upstream: upstream, max_lifetime: 10_000, write_timeout: 1_000}, options),
      limits: %{max_active: 32, max_bytes: 16_777_216, callback_timeout: 3_000}
    }

    spec =
      if transport == :tls,
        do:
          Map.put(spec, :tls, %{
            certfile: Path.join(dir, "cert.pem"),
            keyfile: Path.join(dir, "key.pem")
          }),
        else: spec

    assert {:ok, server} = Gaoxy.start_link(services: [spec])
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, @timeout) end)
    server
  end

  defp tcp_connect(server) do
    {:ok, {ip, port}} = Gaoxy.info(server, :relay).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)
    socket
  end

  defp tls_connect(server, dir) do
    {:ok, {ip, port}} = Gaoxy.info(server, :relay).local

    assert {:ok, socket} =
             :ssl.connect(
               ip,
               port,
               [
                 :binary,
                 active: false,
                 verify: :verify_peer,
                 cacertfile: String.to_charlist(Path.join(dir, "ca.pem")),
                 server_name_indication: ~c"localhost"
               ],
               @timeout
             )

    on_exit(fn -> :ssl.close(socket) end)
    socket
  end

  defp tls_options(dir), do: %{server_name: "localhost", cacertfile: Path.join(dir, "ca.pem")}

  defp peer(mode, dir, exchange, expected \\ :success) do
    options = [:binary, active: false, ip: {127, 0, 0, 1}]

    {:ok, listener} =
      if mode == :tcp,
        do: :gen_tcp.listen(0, [exit_on_close: false] ++ options),
        else:
          :ssl.listen(
            0,
            options ++
              [
                certfile: String.to_charlist(Path.join(dir, "cert.pem")),
                keyfile: String.to_charlist(Path.join(dir, "key.pem"))
              ]
          )

    {:ok, upstream} = if mode == :tcp, do: :inet.sockname(listener), else: :ssl.sockname(listener)
    owner = self()

    peer =
      spawn(fn ->
        try do
          {:ok, socket} =
            if mode == :tcp,
              do: :gen_tcp.accept(listener, @timeout),
              else: :ssl.transport_accept(listener, @timeout)

          try do
            case if(mode == :tls, do: :ssl.handshake(socket, @timeout), else: {:ok, socket}) do
              {:ok, ready} -> exchange.(ready, mode)
              {:error, _} when expected == :rejection -> :ok
              error -> raise "unexpected TLS peer handshake: #{inspect(error)}"
            end

            send(owner, {:peer_done, self()})
          after
            if mode == :tcp, do: :gen_tcp.close(socket), else: :ssl.close(socket, 0)
          end
        rescue
          error ->
            send(owner, {:peer_error, self(), Exception.format(:error, error, __STACKTRACE__)})
        after
          if mode == :tcp, do: :gen_tcp.close(listener), else: :ssl.close(listener, 0)
        end
      end)

    on_exit(fn ->
      if Process.alive?(peer), do: Process.exit(peer, :kill)
      if mode == :tcp, do: :gen_tcp.close(listener), else: :ssl.close(listener, 0)
    end)

    {upstream, peer}
  end

  defp assert_peer(peer) do
    receive do
      {:peer_done, ^peer} -> :ok
      {:peer_error, ^peer, error} -> flunk(error)
    after
      @timeout -> flunk("TLS relay peer did not finish")
    end
  end

  defp assert_restored(server, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(@timeout)
    status = Gaoxy.status(server, :relay)

    if match?(%{active: 0, retained_bytes: 0, cleanup_pending: 0}, status) do
      assert %{state: :ready, cleanup_failed: nil} = status
    else
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)

      receive do
      after
        2 -> assert_restored(server, deadline)
      end
    end
  end

  defp await_active(server, deadline) do
    status = Gaoxy.status(server, :relay)

    if status.active == 3 do
      :ok
    else
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)

      receive do
      after
        2 -> await_active(server, deadline)
      end
    end
  end
end
