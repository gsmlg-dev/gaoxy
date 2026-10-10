defmodule Gaoxy.Proxy.UpstreamGroupMemberLimitsTest do
  use ExUnit.Case, async: true
  alias Gaoxy.{Lifecycle, Proxy.UpstreamGroups}
  alias Gaoxy.HTTP.Resources
  @timeout 3_000
  @common %{
    opening_timeout: 2_000,
    idle_timeout: 2_000,
    write_timeout: 2_000,
    max_lifetime: 2_000
  }

  defmodule SocketObserver do
    import Kernel, except: [send: 2]
    def secure?, do: false
    def close(socket), do: :gen_tcp.close(socket)
    def setopts(socket, options), do: :inet.setopts(socket, options)
    def recv(socket, bytes, timeout), do: :gen_tcp.recv(socket, bytes, timeout)

    def send(socket, bytes) do
      {:ok, options} = :inet.getopts(socket, [:send_timeout])

      Kernel.send(
        Process.get(:member_limits_parent),
        {:actual_write, self(), options[:send_timeout]}
      )

      :gen_tcp.send(socket, bytes)
    end
  end

  defmodule Observed do
    def init({config, parent}) do
      with {:ok, config} <- Gaoxy.Proxy.GroupEndpoint.init(config), do: {:ok, {config, parent}}
    end

    def resources({config, _}), do: Gaoxy.Proxy.GroupEndpoint.resources(config)

    def call(exchange, {config, parent}) do
      Process.put(:member_limits_parent, parent)
      send(parent, {:member_owner, self(), exchange.deadline})

      receive do
        :dispatch -> :ok
      after
        1_000 -> raise "member endpoint dispatch barrier expired"
      end

      socket = %{exchange.socket | transport_module: SocketObserver}
      Gaoxy.Proxy.GroupEndpoint.call(%{exchange | socket: socket}, config)
    end
  end

  test "a tighter member opening deadline closes the peer and counts an upstream failure" do
    with_proxy(%{opening_timeout: 80}, fn context ->
      start_request(context)
      assert_receive {:member_request, worker, _}, @timeout
      send(worker, :await_close)
      assert receive_all(context.client, 500) =~ "504 Gateway Timeout"
      assert_receive {:member_closed, ^worker}, 500
      await_unused(context)
      assert member(context).health == :unhealthy
    end)
  end

  test "a tighter member idle deadline closes a stalled response body" do
    with_proxy(%{idle_timeout: 80}, fn context ->
      start_request(context)
      assert_receive {:member_request, worker, _}, @timeout
      send(worker, :stream)
      assert receive_head(context.client) =~ "200 OK"
      assert {:error, :closed} = :gen_tcp.recv(context.client, 0, 500)
      assert_receive {:member_closed, ^worker}, 500
      await_unused(context)
      assert member(context).health == :healthy
    end)
  end

  test "member lifetime expiry keeps established passive health unchanged" do
    with_proxy(%{max_lifetime: 80}, fn context ->
      start_request(context)
      assert_receive {:member_request, worker, _}, @timeout
      send(worker, :await_close)
      assert receive_all(context.client, 500) == ""
      assert_receive {:member_closed, ^worker}, 500
      await_unused(context)
      assert member(context).health == :healthy
    end)
  end

  test "effective member limits reach the pump before a real downstream write" do
    with_proxy(%{write_timeout: 80, max_chunk_bytes: 4_096}, fn context ->
      :ok = :gen_tcp.send(context.client, request())
      assert_receive {:member_owner, native, downstream_deadline}, @timeout
      assert :erlang.trace(native, true, [:receive]) == 1

      try do
        send(native, :dispatch)

        assert_receive {:trace, ^native, :receive, {:gaoxy_proxy_http, session, ready}}, 500
        assert {:ready, _upload, effective, deadline} = ready
        assert effective == Map.merge(@common, %{write_timeout: 80, max_chunk_bytes: 4_096})
        assert deadline <= downstream_deadline
        assert :sys.get_state(session).deadline == deadline
        assert_receive {:member_request, worker, _}, @timeout
        send(worker, :reply)

        assert receive_all(context.client, 500) ==
                 "HTTP/1.1 200 OK\r\nconnection: close\r\ncontent-length: 5\r\n\r\nhello"

        assert_receive {:actual_write, ^native, 80}, 500
        assert_receive {:member_closed, ^worker}, 500
        await_unused(context)
        assert member(context).health == :healthy
      after
        if Process.alive?(native), do: :erlang.trace(native, false, [:receive])
      end
    end)
  end

  defp with_proxy(member_limits, fun) do
    url = peer()
    groups = start_supervised!({UpstreamGroups, instance: self()})

    {:ok, compiled} =
      UpstreamGroups.compile(%{
        id: "member-limits",
        members: [Map.merge(%{id: "one", upstream: url}, member_limits)],
        health: %{interval: 5_000, stale_after: 10_000, jitter: 0, failure_threshold: 1}
      })

    {:ok, handle, preparation} =
      UpstreamGroups.prepare(groups, compiled, self(), Lifecycle.deadline(@timeout))

    assert_receive :member_probe, @timeout
    eventually(fn -> hd(UpstreamGroups.status(handle).members).health == :healthy end)

    {:ok, baseline} =
      Resources.pin_many([handle], self(), :baseline, Lifecycle.deadline(@timeout))

    :ok = Resources.release(preparation)

    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint: {Observed, {Map.put(@common, :group, handle), self()}},
        limits: %{max_bytes: 67_108_864}
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    assert port > 0
    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    context = %{server: server, client: client, handle: handle}

    try do
      fun.(context)
    after
      :gen_tcp.close(client)
      assert :ok = Gaoxy.stop(server, @timeout)
      eventually(fn -> UpstreamGroups.status(handle).inflight == 0 end)
      assert :ok = Resources.release(baseline)
    end
  end

  defp start_request(context) do
    :ok = :gen_tcp.send(context.client, request())
    assert_receive {:member_owner, native, _}, @timeout
    send(native, :dispatch)
  end

  defp request, do: "GET /member HTTP/1.1\r\nHost: edge.test\r\nConnection: close\r\n\r\n"
  defp member(context), do: hd(UpstreamGroups.status(context.handle).members)

  defp await_unused(context) do
    eventually(fn ->
      UpstreamGroups.status(context.handle).inflight == 0 and
        match?(
          %{active: 0, retained_bytes: 0, cleanup_pending: 0},
          Gaoxy.status(context.server, :http)
        )
    end)
  end

  defp peer do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)
    parent = self()
    acceptor = spawn(fn -> accept_loop(listener, parent) end)

    on_exit(fn ->
      :gen_tcp.close(listener)
      if Process.alive?(acceptor), do: Process.exit(acceptor, :kill)
    end)

    "http://127.0.0.1:#{port}"
  end

  defp accept_loop(listener, parent) do
    case :gen_tcp.accept(listener, @timeout) do
      {:ok, socket} ->
        worker = spawn_link(fn -> serve(socket, parent) end)
        :ok = :gen_tcp.controlling_process(socket, worker)
        send(worker, :ready)
        accept_loop(listener, parent)

      {:error, :timeout} ->
        accept_loop(listener, parent)

      {:error, :closed} ->
        :ok
    end
  end

  defp serve(socket, parent) do
    receive do
      :ready -> :ok
    end

    head = receive_head(socket)

    if String.starts_with?(head, "HEAD ") do
      :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
      send(parent, :member_probe)
    else
      send(parent, {:member_request, self(), head})

      receive do
        :await_close -> :ok
        :stream -> :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n")
        :reply -> :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello")
      after
        @timeout -> raise "member peer response barrier expired"
      end
    end

    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    :gen_tcp.close(socket)
    send(parent, {:member_closed, self()})
  end

  defp receive_head(socket, bytes \\ "") do
    if String.contains?(bytes, "\r\n\r\n") do
      bytes
    else
      assert {:ok, more} = :gen_tcp.recv(socket, 0, @timeout)
      receive_head(socket, bytes <> more)
    end
  end

  defp receive_all(socket, wait, bytes \\ "") do
    case :gen_tcp.recv(socket, 0, wait) do
      {:ok, more} -> receive_all(socket, wait, bytes <> more)
      {:error, :closed} -> bytes
      error -> flunk("member response did not close in its bound: #{inspect(error)}")
    end
  end

  defp eventually(predicate, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(@timeout)

    unless predicate.() do
      assert Lifecycle.remaining(deadline) > 0

      receive do
      after
        2 -> eventually(predicate, deadline)
      end
    end
  end
end
