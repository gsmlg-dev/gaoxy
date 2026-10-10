defmodule Gaoxy.Proxy.UpstreamGroupProxyTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Generation, Resources}
  alias Gaoxy.Proxy.{GroupEndpoint, UpstreamGroups}
  alias Gaoxy.Lifecycle
  @timeout 3_000

  defmodule Observed do
    @behaviour Gaoxy.HTTP.Endpoint
    def init({config, parent, hold}) do
      with {:ok, config} <- GroupEndpoint.init(config), do: {:ok, {config, parent, hold}}
    end

    def resources({config, _, _}), do: GroupEndpoint.resources(config)

    def call(exchange, {config, parent, hold}) do
      send(parent, {:group_owner, self(), config.group})

      if hold do
        receive do
          :dispatch -> :ok
        after
          2_000 -> raise "old snapshot dispatch barrier expired"
        end
      end

      GroupEndpoint.call(exchange, config)
    end
  end

  test "old request pin survives activation before checkout and exact old/new peers remain fixed" do
    {old_url, old_peer} = peer()
    {new_url, new_peer} = peer()
    groups = start_supervised!({UpstreamGroups, instance: self()})
    {old, old_preparation} = prepare(groups, "old", old_url)
    {new, new_preparation} = prepare(groups, "new", new_url)
    store = start_supervised!({Generation, routes: routes(old, true)})
    :ok = Resources.release(old_preparation)
    {server, old_client} = server({Generation, store})
    send_get(old_client, "/a%2Fb?q=%2F")
    assert_receive {:group_owner, old_owner, ^old}, @timeout
    assert {:ok, generation, _} = Generation.snapshot(store)
    assert {:ok, router} = Generation.prepare(store, routes(new, false))
    assert {:ok, _} = Generation.activate(store, generation, router)
    :ok = Resources.release(new_preparation)
    eventually(fn -> UpstreamGroups.status(old).lifecycle == :retiring end)
    new_client = connect(server)
    send_get(new_client, "/fresh?")
    assert_receive {:group_owner, _, ^new}, @timeout
    assert_receive {:group_request, ^new_peer, new_worker, new_head}, @timeout
    assert new_head =~ "GET /fresh? HTTP/1.1\r\n"
    send(new_worker, {:respond, 200, "new"})
    assert receive_all(new_client) =~ "\r\n\r\nnew"
    send(old_owner, :dispatch)
    assert_receive {:group_request, ^old_peer, old_worker, old_head}, @timeout
    assert old_head =~ "GET /a%2Fb?q=%2F HTTP/1.1\r\n"
    assert String.downcase(old_head) =~ "host: " <> URI.parse(old_url).authority <> "\r\n"
    refute String.downcase(old_head) =~ "\r\nhost: edge.test\r\n"
    send(old_worker, {:respond, 200, "old"})
    assert receive_all(old_client) =~ "\r\n\r\nold"
    eventually(fn -> UpstreamGroups.status(old) == {:error, :stale_group} end)
    assert Gaoxy.status(server, :http).retained_bytes == 0
  end

  test "saturation responds 503 without another upstream attempt or member health failure" do
    {url, upstream} = peer()
    groups = start_supervised!({UpstreamGroups, instance: self()})
    {handle, preparation} = prepare(groups, "api", url, max_inflight: 1)

    {:ok, baseline} =
      Resources.pin_many([handle], self(), :baseline, Lifecycle.deadline(@timeout))

    :ok = Resources.release(preparation)
    {server, first} = server({GroupEndpoint, %{group: handle}})
    send_get(first, "/held")
    assert_receive {:group_request, ^upstream, worker, _}, @timeout
    assert UpstreamGroups.status(handle).inflight == 1
    second = connect(server)
    send_get(second, "/denied")
    assert receive_all(second) =~ "503 Service Unavailable"
    refute_receive {:group_request, ^upstream, _, _}, 30
    assert hd(UpstreamGroups.status(handle).members).health == :healthy
    send(worker, {:respond, 200, "ok"})
    assert receive_all(first) =~ "\r\n\r\nok"
    eventually(fn -> UpstreamGroups.status(handle).inflight == 0 end)
    :ok = Resources.release(baseline)
  end

  test "redirect and connection failure keep one selected peer and never replay" do
    for {label, response, expected} <- [
          {"redirect", {:respond, 302, ""}, "302"},
          {"failure", :close, "502"}
        ] do
      {url, upstream} = peer()
      groups = start_supervised!({UpstreamGroups, instance: self()}, id: label)
      {handle, preparation} = prepare(groups, label, url)

      {:ok, baseline} =
        Resources.pin_many([handle], self(), :baseline, Lifecycle.deadline(@timeout))

      :ok = Resources.release(preparation)
      {server, client} = server({GroupEndpoint, %{group: handle}})
      send_get(client, "/once")
      assert_receive {:group_request, ^upstream, worker, _}, @timeout
      send(worker, response)
      assert receive_all(client) =~ expected
      eventually(fn -> UpstreamGroups.status(handle).inflight == 0 end)
      refute_receive {:group_request, ^upstream, _, _}, 30
      assert :ok = Gaoxy.stop(server)
      :ok = Resources.release(baseline)
    end
  end

  test "downstream reset retains a slot until public cleanup and bound guardian recovery confirms it" do
    {url, upstream} = peer()
    groups = start_supervised!({UpstreamGroups, instance: self()})
    {handle, preparation} = prepare(groups, "api", url)

    {:ok, baseline} =
      Resources.pin_many([handle], self(), :baseline, Lifecycle.deadline(@timeout))

    :ok = Resources.release(preparation)
    {_server, client} = server({Observed, {%{group: handle}, self(), false}})
    send_get(client, "/stream")
    assert_receive {:group_owner, request_owner, ^handle}, @timeout
    assert_receive {:group_request, ^upstream, worker, _}, @timeout
    send(worker, :stream)
    assert head(client) =~ "200 OK"
    guardian = guardian(request_owner)
    state = :sys.get_state(guardian)
    assert %HTTP.RequestCompletion{} = completion = state.request.completion
    stream = state.request.stream
    assert is_pid(stream)
    assert :erlang.suspend_process(stream)

    try do
      :ok = :gen_tcp.close(client)
      Process.exit(guardian, :kill)
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
      assert UpstreamGroups.status(handle).inflight == 1
      assert hd(UpstreamGroups.status(handle).members).health == :healthy
      assert :erlang.resume_process(stream)
      assert :ok = HTTP.RequestCompletion.abort_and_await(completion, @timeout)
      eventually(fn -> UpstreamGroups.status(handle).inflight == 0 end)
      assert hd(UpstreamGroups.status(handle).members).health == :healthy
    after
      if Process.alive?(stream), do: :erlang.resume_process(stream)
    end

    :ok = Resources.release(baseline)
  end

  for {limit, value, streamed} <- [
        {:opening_timeout, 80, false},
        {:idle_timeout, 80, true},
        {:max_lifetime, 120, true}
      ] do
    test "group #{limit} expires independently and closes its one upstream connection" do
      {url, upstream} = peer()
      groups = start_supervised!({UpstreamGroups, instance: self()})
      {handle, preparation} = prepare(groups, "api", url)

      {:ok, baseline} =
        Resources.pin_many([handle], self(), :baseline, Lifecycle.deadline(@timeout))

      :ok = Resources.release(preparation)

      options =
        Map.put(
          %{group: handle, idle_timeout: 2_000, max_lifetime: 2_000},
          unquote(limit),
          unquote(value)
        )

      {_server, client} = server({GroupEndpoint, options})
      send_get(client, "/stalled")
      assert_receive {:group_request, ^upstream, worker, _}, @timeout

      if unquote(streamed) do
        send(worker, :stream)
        assert head(client) =~ "200 OK"
        assert {:error, :closed} = :gen_tcp.recv(client, 0, @timeout)
      else
        send(worker, :await_close)
        assert receive_all(client) =~ "504 Gateway Timeout"
      end

      assert_receive {:group_closed, ^worker}, @timeout
      eventually(fn -> UpstreamGroups.status(handle).inflight == 0 end)
      :ok = Resources.release(baseline)
    end
  end

  defp routes(handle, hold), do: [%{target: {Observed, {%{group: handle}, self(), hold}}}]

  defp prepare(owner, id, url, options \\ []) do
    {:ok, compiled} =
      UpstreamGroups.compile(%{
        id: id,
        max_inflight: Keyword.get(options, :max_inflight, 16),
        members: [%{id: "one", upstream: url}]
      })

    {:ok, handle, preparation} =
      UpstreamGroups.prepare(owner, compiled, self(), Lifecycle.deadline(@timeout))

    eventually(fn -> hd(UpstreamGroups.status(handle).members).health == :healthy end)
    {handle, preparation}
  end

  defp server(endpoint) do
    {:ok, server} = Gaoxy.HTTP.start_link(endpoint: endpoint, limits: %{max_bytes: 67_108_864})
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {server, connect(server)}
  end

  defp connect(server) do
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(client) end)
    client
  end

  defp send_get(client, path),
    do:
      :gen_tcp.send(
        client,
        "GET #{path} HTTP/1.1\r\nHost: edge.test\r\nConnection: close\r\n\r\n"
      )

  defp peer do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)
    parent = self()
    pid = spawn(fn -> accept_loop(listener, parent) end)

    on_exit(fn ->
      :gen_tcp.close(listener)
      if Process.alive?(pid), do: Process.exit(pid, :kill)
    end)

    {"http://127.0.0.1:#{port}", pid}
  end

  defp accept_loop(listener, parent) do
    case :gen_tcp.accept(listener, @timeout) do
      {:ok, socket} ->
        peer = self()
        worker = spawn_link(fn -> serve(socket, parent, peer) end)
        :ok = :gen_tcp.controlling_process(socket, worker)
        send(worker, :ready)
        accept_loop(listener, parent)

      {:error, :closed} ->
        :ok

      {:error, :timeout} ->
        accept_loop(listener, parent)
    end
  end

  defp serve(socket, parent, peer) do
    receive do
      :ready -> :ok
    end

    request = head(socket)

    if String.starts_with?(request, "HEAD ") do
      :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
    else
      send(parent, {:group_request, peer, self(), request})

      receive do
        {:respond, status, body} ->
          :ok =
            :gen_tcp.send(
              socket,
              "HTTP/1.1 #{status} Response\r\nContent-Length: #{byte_size(body)}\r\nLocation: http://unreachable.invalid/\r\n\r\n#{body}"
            )

        :await_close ->
          :ok

        :stream ->
          :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n")

        :close ->
          :gen_tcp.close(socket)
          send(parent, {:group_closed, self()})
          exit(:normal)
      after
        @timeout -> flunk("group peer response barrier expired")
      end
    end

    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    :gen_tcp.close(socket)
    send(parent, {:group_closed, self()})
  end

  defp guardian(owner) do
    Enum.find_value(DynamicSupervisor.which_children(Gaoxy.Proxy.SessionSupervisor), fn
      {_, pid, _, [Gaoxy.Proxy.HTTP.Session]} ->
        try do
          if :sys.get_state(pid).owner == owner, do: pid
        catch
          :exit, _ -> nil
        end

      _ ->
        nil
    end) || flunk("group guardian missing")
  end

  defp head(socket, bytes \\ "") do
    if String.contains?(bytes, "\r\n\r\n"),
      do: bytes,
      else:
        (
          assert {:ok, more} = :gen_tcp.recv(socket, 0, @timeout)
          head(socket, bytes <> more)
        )
  end

  defp receive_all(socket, bytes \\ "") do
    case :gen_tcp.recv(socket, 0, @timeout) do
      {:ok, more} -> receive_all(socket, bytes <> more)
      {:error, :closed} -> bytes
    end
  end

  defp eventually(fun, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(@timeout)

    if fun.(),
      do: :ok,
      else:
        (
          assert Lifecycle.remaining(deadline) > 0

          receive do
          after
            2 -> eventually(fun, deadline)
          end
        )
  end
end
