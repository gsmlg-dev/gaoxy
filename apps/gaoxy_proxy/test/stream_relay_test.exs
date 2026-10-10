defmodule Gaoxy.Proxy.StreamRelayTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.StreamRelay
  @timeout 3_000

  defmodule BridgeHandler do
    use ThousandIsland.Handler
    alias Gaoxy.{Admission, Lifecycle}
    alias Gaoxy.Proxy.StreamRelay
    @timeout 3_000

    def validate_options(options) do
      with {:ok, config} <- StreamRelay.validate_options(Map.delete(options, :owner)),
           do: {:ok, Map.put(config, :owner, options.owner)}
    end

    def handle_connection(socket, %{spec: spec, gate: gate} = context) do
      config = Map.delete(spec.handler_options, :owner)
      deadline = Lifecycle.deadline(config.max_lifetime)
      {:ok, lease} = Admission.acquire(gate, 65_536, drain_notify: true)
      :ok = Admission.begin_request(gate, lease, 65_536, deadline)
      {:ok, buffered} = ThousandIsland.Socket.recv(socket, 9, @timeout)
      {:ok, upstream} = StreamRelay.connect(config, deadline)
      send(spec.handler_options.owner, {:bridge_dialled, self(), lease, deadline})
      result = StreamRelay.bridge(socket, upstream, context, config, lease, deadline, buffered)
      send(spec.handler_options.owner, {:bridge_result, result})
      result
    end
  end

  test "relay modes and finite limits are validated before binding" do
    assert {:ok, config} = StreamRelay.validate_options(%{upstream: {{127, 0, 0, 1}, 80}})
    assert {:ok, ^config} = StreamRelay.validate_options(config)

    for options <- [
          %{},
          %{upstream: {{127, 0, 0, 1}, 0}},
          %{upstream: {{256, 0, 0, 1}, 80}},
          %{upstream: {{127, 0, 0, 1}, 80}, mode: :mitm},
          %{upstream: {{127, 0, 0, 1}, 80}, idle_timeout: 0},
          %{upstream: {{127, 0, 0, 1}, 80}, mode: :tls_upstream}
        ] do
      assert {:error, _} = StreamRelay.validate_options(options)
    end
  end

  test "CONNECT dial rejects an expired original deadline before opening an upstream" do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    on_exit(fn -> :gen_tcp.close(listener) end)
    {:ok, upstream} = :inet.sockname(listener)

    assert {:error, :deadline_exceeded} =
             StreamRelay.connect(%{upstream: upstream}, Gaoxy.Lifecycle.now())

    assert {:error, :timeout} = :gen_tcp.accept(listener, 50)
  end

  test "bridge rejects oversized initial bytes and closes the supplied upstream before handoff" do
    {upstream, peer} =
      peer(fn socket -> assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout) end)

    options = %{upstream: upstream}
    deadline = Gaoxy.Lifecycle.deadline(@timeout)
    assert {:ok, dialled} = StreamRelay.connect(options, deadline)

    assert {:error, :initial_buffer_limit, %{}} =
             StreamRelay.bridge(
               nil,
               dialled,
               %{},
               options,
               make_ref(),
               deadline,
               :binary.copy("x", 65_537)
             )

    assert_peer(peer)
  end

  test "downstream FIN drains all request bytes and still permits the upstream reply" do
    request = :binary.copy(<<0, 255, 1>>, 70_000)
    response = "reply-after-fin"

    {upstream, peer} =
      peer(fn socket ->
        assert ^request = until_fin(socket)
        :ok = :gen_tcp.send(socket, response)
        :ok = :gen_tcp.shutdown(socket, :write)
      end)

    server = relay(upstream)
    socket = connect(server)
    :ok = :gen_tcp.send(socket, request)
    :ok = :gen_tcp.shutdown(socket, :write)
    assert ^response = until_fin(socket)
    assert_peer(peer)
    assert_restored(server)
  end

  test "upstream FIN permits a later downstream request in the remaining direction" do
    owner = self()

    {upstream, peer} =
      peer(fn socket ->
        :ok = :gen_tcp.send(socket, "greeting")
        :ok = :gen_tcp.shutdown(socket, :write)
        send(owner, {:upstream_fin, self()})
        assert "later-request" = until_fin(socket)
      end)

    server = relay(upstream)
    socket = connect(server)
    assert "greeting" = until_fin(socket)
    assert_receive {:upstream_fin, ^peer}, @timeout
    :ok = :gen_tcp.send(socket, "later-request")
    :ok = :gen_tcp.shutdown(socket, :write)
    assert_peer(peer)
    assert_restored(server)
  end

  test "finite lifetime closes both owned sockets and restores all admission reservations" do
    owner = self()

    {upstream, peer} =
      peer(fn socket ->
        send(owner, {:accepted, self()})
        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      end)

    server = relay(upstream, %{max_lifetime: 100})
    socket = connect(server)
    assert_receive {:accepted, ^peer}, @timeout
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    assert_peer(peer)
    assert_restored(server)
  end

  test "force stop closes upstream and downstream while a separate relay remains usable" do
    owner = self()

    {upstream, peer} =
      peer(fn socket ->
        send(owner, {:accepted, self()})
        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      end)

    {other_upstream, other_peer} =
      peer(fn socket ->
        assert "live" = until_fin(socket)
        :ok = :gen_tcp.send(socket, "other")
        :ok = :gen_tcp.shutdown(socket, :write)
      end)

    server = relay(upstream)
    other = relay(other_upstream)
    socket = connect(server)
    assert_receive {:accepted, ^peer}, @timeout
    await_active(server, 3, Gaoxy.Lifecycle.deadline(@timeout))
    assert :ok = Gaoxy.stop(server, 100)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    assert_peer(peer)
    live = connect(other)
    :ok = :gen_tcp.send(live, "live")
    :ok = :gen_tcp.shutdown(live, :write)
    assert "other" = until_fin(live)
    assert_peer(other_peer)
    assert_restored(other)
  end

  test "existing admitted owner bridges already dialled upstream and buffered bytes exactly once" do
    request = "prebuffer" <> :binary.copy("tail", 20_000)

    {upstream, peer} =
      peer(fn socket ->
        assert ^request = until_fin(socket)
        :ok = :gen_tcp.send(socket, "after-buffered-fin")
        :ok = :gen_tcp.shutdown(socket, :write)
      end)

    server = relay(upstream, %{owner: self()}, %{}, BridgeHandler)
    socket = connect(server)
    :ok = :gen_tcp.send(socket, request)
    :ok = :gen_tcp.shutdown(socket, :write)
    assert_receive {:bridge_dialled, owner, lease, deadline}, @timeout
    assert is_pid(owner) and is_reference(lease) and is_integer(deadline)
    assert "after-buffered-fin" = until_fin(socket)
    assert_receive {:bridge_result, {:close, %{relay_reason: :normal}}}, @timeout
    assert_peer(peer)
    assert_restored(server)
  end

  test "bridge adds its windows to the existing reservation and retains the original deadline" do
    {upstream, peer} =
      peer(fn socket ->
        assert {:ok, "prebuffer"} = :gen_tcp.recv(socket, 9, @timeout)
        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      end)

    server = relay(upstream, %{owner: self(), max_lifetime: 250}, %{}, BridgeHandler)
    socket = connect(server)
    :ok = :gen_tcp.send(socket, "prebuffer")
    assert_receive {:bridge_dialled, _, _, deadline}, @timeout
    await_active(server, 3, Gaoxy.Lifecycle.deadline(@timeout))
    assert %{retained_bytes: retained} = Gaoxy.status(server, :relay)
    assert retained == 65_536 + 4 * 65_536 + 4 * 16_384 + 4_096 + 2 * (2 * 16_384 + 1_024)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    assert Gaoxy.Lifecycle.remaining(deadline) == 0
    assert_peer(peer)
    assert_restored(server)
  end

  test "idle timeout closes both sockets and restores reservations" do
    {upstream, peer} =
      peer(fn socket -> assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout) end)

    server = relay(upstream, %{idle_timeout: 75, max_lifetime: 2_000})
    socket = connect(server)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    assert_peer(peer)
    assert_restored(server)
  end

  test "a stalled upstream writer leaves reverse traffic live and queues one bounded piece" do
    test_owner = self()

    {upstream, peer} =
      peer(fn socket ->
        receive do
          :reverse -> :ok
        after
          @timeout -> flunk("reverse traffic barrier was not released")
        end

        :ok = :gen_tcp.send(socket, "reverse-while-stalled")
        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
        send(test_owner, {:stall_peer_closed, self()})
      end)

    server = relay(upstream)
    socket = connect(server)
    %{up: up, down: down} = writers(server, upstream)
    :ok = :sys.suspend(up)
    on_exit(fn -> if Process.alive?(up), do: :sys.resume(up) end)
    payload = :binary.copy("x", 65_536)
    :ok = :gen_tcp.send(socket, payload)
    await_write(up, Gaoxy.Lifecycle.deadline(@timeout))
    assert {:messages, [{:relay_write, _, _, piece, _}]} = Process.info(up, :messages)
    assert byte_size(piece) <= 16_384
    send(peer, :reverse)
    assert {:ok, "reverse-while-stalled"} = :gen_tcp.recv(socket, 21, @timeout)
    up_monitor = Process.monitor(up)
    down_monitor = Process.monitor(down)
    assert :ok = Gaoxy.stop(server, 100)
    assert_receive {:DOWN, ^up_monitor, :process, ^up, _}, @timeout
    assert_receive {:DOWN, ^down_monitor, :process, ^down, _}, @timeout
    assert_receive {:stall_peer_closed, ^peer}, @timeout
    assert_peer(peer)
  end

  test "writer crash closes the owner and the other writer and releases every lease" do
    {upstream, peer} =
      peer(fn socket -> assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout) end)

    server = relay(upstream)
    socket = connect(server)
    %{up: up, down: down, owner: owner} = writers(server, upstream)
    monitors = Enum.map([up, down, owner], &{&1, Process.monitor(&1)})
    Process.exit(up, :kill)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)

    for {pid, monitor} <- monitors do
      assert_receive {:DOWN, ^monitor, :process, ^pid, _}, @timeout
    end

    assert_peer(peer)
    assert_restored(server)
  end

  test "real upstream send backpressure preserves reverse bytes and expires without replay" do
    payload_size = 32 * 1_048_576

    {upstream, peer} =
      peer(fn socket ->
        :ok = :inet.setopts(socket, recbuf: 1_024)

        receive do
          :reverse -> :ok
        after
          @timeout -> flunk("backpressure barrier was not released")
        end

        :ok = :gen_tcp.send(socket, "reverse-during-send")

        # Wait until the finite writer timeout has closed the relay, without
        # draining the receive window and releasing its send backpressure.
        receive do
          :relay_closed -> :ok
        after
          @timeout -> flunk("blocked send did not close the relay")
        end

        received = until_fin(socket)
        assert byte_size(received) > 0 and byte_size(received) < payload_size
      end)

    server = relay(upstream, %{write_timeout: 100, max_lifetime: 5_000})
    socket = connect(server)
    %{up: up, owner: relay_owner} = writers(server, upstream)
    %{target: {:upstream, {:tcp, upstream_socket}}} = :sys.get_state(up)
    :ok = :inet.setopts(upstream_socket, sndbuf: 1_024)
    owner = self()

    sender =
      spawn(fn ->
        result = :gen_tcp.send(socket, :binary.copy("x", payload_size))
        send(owner, {:backpressure_sender, self(), result})
      end)

    on_exit(fn -> if Process.alive?(sender), do: Process.exit(sender, :kill) end)
    await_socket_send(up, Gaoxy.Lifecycle.deadline(@timeout))
    send(peer, :reverse)
    assert {:ok, "reverse-during-send"} = :gen_tcp.recv(socket, 19, @timeout)
    closed = :gen_tcp.recv(socket, 0, @timeout)

    assert closed == {:error, :closed},
           inspect(%{
             status: Gaoxy.status(server, :relay),
             owner: Process.info(relay_owner, :current_stacktrace),
             writer: Process.info(up, :current_stacktrace)
           })

    send(peer, :relay_closed)
    assert_receive {:backpressure_sender, ^sender, _}, @timeout
    assert_peer(peer)
    assert_restored(server)
  end

  test "drain controls normal EOF cleanup while the half-closed peer withholds reads" do
    owner = self()

    {upstream, peer} =
      peer(
        fn socket ->
          :ok = :gen_tcp.shutdown(socket, :write)
          send(owner, {:normal_cleanup_fin, self()})

          receive do
            {:read, accepted} ->
              :ok = :inet.setopts(socket, recbuf: 1_048_576, buffer: 65_536)
              received = until_fin(socket)
              assert byte_size(received) <= accepted
              assert received == :binary.copy("x", byte_size(received))
          after
            @timeout -> flunk("normal cleanup read barrier was not released")
          end
        end,
        recbuf: 1_024
      )

    server = relay(upstream, %{write_timeout: 2_000, max_lifetime: 10_000})
    socket = connect(server)
    %{up: up, down: down} = writers(server, upstream)
    %{gate: gate, target: {:upstream, {:tcp, upstream_socket}}} = :sys.get_state(up)
    telemetry = make_ref()
    :ok = :telemetry.attach(telemetry, [:gaoxy, :send], &__MODULE__.relay_send/4, {self(), gate})
    on_exit(fn -> :telemetry.detach(telemetry) end)
    assert_receive {:normal_cleanup_fin, ^peer}, @timeout
    assert "" = until_fin(socket)
    {accepted, pending} = fill_until_queued(socket, upstream_socket, 0)
    assert pending > 0
    :ok = :gen_tcp.shutdown(socket, :write)

    # Both send children terminate only after both EOFs have reached cleanup.
    # Fresh DOWN receipts prove cleanup started while peer reads remain gated.
    for writer <- [up, down] do
      monitor = Process.monitor(writer)
      assert_receive {:DOWN, ^monitor, :process, ^writer, _}, @timeout
    end

    assert :ok = Gaoxy.stop(server, 100)
    send(peer, {:read, accepted})
    assert_peer(peer)
  end

  def relay_send(_, %{bytes: bytes}, %{outcome: outcome}, {owner, gate}) do
    if self() == gate, do: send(owner, {:relay_send, bytes, outcome})
  end

  test "normal EOF cleanup preserves queued bytes when the half-closed peer resumes reads" do
    owner = self()

    {upstream, peer} =
      peer(
        fn socket ->
          :ok = :gen_tcp.shutdown(socket, :write)
          send(owner, {:output_fin, self()})

          receive do
            {:read_exact, accepted} ->
              :ok = :inet.setopts(socket, recbuf: 1_048_576, buffer: 65_536)
              assert until_fin(socket) == :binary.copy("x", accepted)
          after
            @timeout -> flunk("output read barrier was not released")
          end
        end,
        recbuf: 1_024
      )

    server = relay(upstream, %{write_timeout: 2_000, max_lifetime: 10_000})
    socket = connect(server)
    %{up: up, down: down} = writers(server, upstream)
    %{gate: gate, target: {:upstream, {:tcp, upstream_socket}}} = :sys.get_state(up)
    telemetry = make_ref()
    :ok = :telemetry.attach(telemetry, [:gaoxy, :send], &__MODULE__.relay_send/4, {self(), gate})
    on_exit(fn -> :telemetry.detach(telemetry) end)
    assert_receive {:output_fin, ^peer}, @timeout
    assert "" = until_fin(socket)
    {accepted, pending} = fill_until_queued(socket, upstream_socket, 0)
    assert pending > 0
    :ok = :gen_tcp.shutdown(socket, :write)

    for writer <- [up, down] do
      monitor = Process.monitor(writer)
      assert_receive {:DOWN, ^monitor, :process, ^writer, _}, @timeout
    end

    send(peer, {:read_exact, accepted})
    assert_peer(peer)
    assert_restored(server)
  end

  test "owner byte admission rejection occurs before dial or payload handoff" do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    on_exit(fn -> :gen_tcp.close(listener) end)
    {:ok, upstream} = :inet.sockname(listener)
    server = relay(upstream, %{}, %{max_bytes: 1})
    socket = connect(server)
    :ok = :gen_tcp.send(socket, "rejected-payload")
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    assert {:error, :timeout} = :gen_tcp.accept(listener, 50)
    assert_restored(server)
  end

  test "writer item admission rejection forwards no payload and cleans up partial startup" do
    {upstream, peer} =
      peer(fn socket -> assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout) end)

    server = relay(upstream, %{}, %{max_active: 2})
    socket = connect(server)
    :ok = :gen_tcp.send(socket, "rejected-payload")
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    assert_peer(peer)
    assert_restored(server)
  end

  defp relay(upstream, extra \\ %{}, limits \\ %{}, handler \\ StreamRelay) do
    assert {:ok, server} =
             Gaoxy.start_link(
               services: [
                 %{
                   id: :relay,
                   transport: :tcp,
                   handler_mode: :native,
                   handler: handler,
                   handler_options: Map.merge(%{upstream: upstream}, extra),
                   limits:
                     Map.merge(
                       %{
                         max_active: 32,
                         max_bytes: 16_777_216,
                         callback_timeout: 1_000,
                         drain_timeout: 500
                       },
                       limits
                     )
                 }
               ]
             )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, @timeout) end)
    server
  end

  defp connect(server) do
    {:ok, {ip, port}} = Gaoxy.info(server, :relay).local

    {:ok, socket} =
      :gen_tcp.connect(ip, port, [:binary, active: false, exit_on_close: false], @timeout)

    on_exit(fn -> :gen_tcp.close(socket) end)
    socket
  end

  defp peer(exchange, extra \\ []) do
    {:ok, listener} =
      :gen_tcp.listen(
        0,
        [:binary, active: false, exit_on_close: false, ip: {127, 0, 0, 1}] ++ extra
      )

    {:ok, upstream} = :inet.sockname(listener)
    owner = self()

    peer =
      spawn(fn ->
        try do
          {:ok, socket} = :gen_tcp.accept(listener, @timeout)

          try do
            exchange.(socket)
            send(owner, {:peer_done, self()})
          after
            :gen_tcp.close(socket)
          end
        rescue
          error ->
            send(owner, {:peer_error, self(), Exception.format(:error, error, __STACKTRACE__)})
        after
          :gen_tcp.close(listener)
        end
      end)

    on_exit(fn ->
      if Process.alive?(peer), do: Process.exit(peer, :kill)
      :gen_tcp.close(listener)
    end)

    {upstream, peer}
  end

  defp assert_peer(peer) do
    receive do
      {:peer_done, ^peer} -> :ok
      {:peer_error, ^peer, error} -> flunk(error)
    after
      @timeout -> flunk("relay peer did not finish")
    end
  end

  defp until_fin(socket, bytes \\ "") do
    case :gen_tcp.recv(socket, 0, @timeout) do
      {:ok, data} -> until_fin(socket, bytes <> data)
      {:error, :closed} -> bytes
    end
  end

  defp await_active(server, expected, deadline) do
    status = Gaoxy.status(server, :relay)

    if status.active == expected do
      :ok
    else
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)

      receive do
      after
        2 -> await_active(server, expected, deadline)
      end
    end
  end

  defp writers(server, upstream) do
    await_active(server, 3, Gaoxy.Lifecycle.deadline(@timeout))

    states =
      for {_, pid, _, [Gaoxy.Proxy.StreamRelay.Writer]} <-
            DynamicSupervisor.which_children(Gaoxy.Proxy.SessionSupervisor),
          do: {pid, :sys.get_state(pid)}

    {up, state} =
      Enum.find(states, fn
        {_, %{target: {:upstream, {:tcp, socket}}}} -> :inet.peername(socket) == {:ok, upstream}
        _ -> false
      end)

    {down, _} =
      Enum.find(states, fn
        {_, %{owner: owner, target: {:downstream, _}}} -> owner == state.owner
        _ -> false
      end)

    %{up: up, down: down, owner: state.owner}
  end

  defp await_write(writer, deadline) do
    case Process.info(writer, :messages) do
      {:messages, [{:relay_write, _, _, _, _}]} ->
        :ok

      _ ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0

        receive do
        after
          2 -> await_write(writer, deadline)
        end
    end
  end

  defp await_socket_send(writer, deadline) do
    case Process.info(writer, :current_stacktrace) do
      {:current_stacktrace, stack} ->
        if Enum.any?(stack, fn {module, _, _, _} -> module == :prim_inet end) do
          :ok
        else
          assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(stack)

          receive do
          after
            2 -> await_socket_send(writer, deadline)
          end
        end

      nil ->
        flunk("upstream writer terminated before a blocked send was observed")
    end
  end

  defp fill_until_queued(socket, upstream, accepted) do
    assert accepted < 16_777_216
    :ok = :gen_tcp.send(socket, :binary.copy("x", 16_384))
    assert_receive {:relay_send, 16_384, :ok}, @timeout
    {:ok, [send_pend: pending]} = :inet.getstat(upstream, [:send_pend])

    if pending > 0,
      do: {accepted + 16_384, pending},
      else: fill_until_queued(socket, upstream, accepted + 16_384)
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
end
