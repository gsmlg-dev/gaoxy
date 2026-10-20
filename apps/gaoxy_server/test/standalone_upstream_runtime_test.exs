Code.require_file("../../gaoxy_proxy/test/support/managed_h2_fixed_fixture.exs", __DIR__)

defmodule Gaoxy.Server.StandaloneUpstreamRuntimeTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Server.Config
  alias Gaoxy.Proxy.ManagedH2FixedFixture, as: Peer
  @moduletag :capture_log

  defmodule Origin do
    def init(options), do: {:ok, options}

    def call(exchange, _),
      do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], exchange.request.path)
  end

  test "direct standalone supervisor shutdown joins every live managed custodian" do
    assert {:ok, options} = Config.decode(config(target(:fixed, origin(:http1))))
    assert {:ok, supervisor} = Gaoxy.Server.Supervisor.start_link(options)

    on_exit(fn ->
      if Process.alive?(supervisor), do: Supervisor.stop(supervisor, :normal, 7000)
    end)

    local = Gaoxy.info(Gaoxy.Server.Runtime, "web").local
    assert request(local, "/live-scope") =~ "\r\n\r\n/live-scope"

    %{transports: owner} = :sys.get_state(Gaoxy.Server.RouteResources)
    %{records: records} = :sys.get_state(owner)
    assert [custodian] = Enum.map(records, fn {_, record} -> record.custodian end)
    assert Process.alive?(custodian)
    custodian_monitor = Process.monitor(custodian)
    :ok = :sys.suspend(custodian)
    on_exit(fn -> resume_custodian(custodian) end)
    observer = self()

    {stopper, stopper_monitor} =
      spawn_monitor(fn ->
        result = Supervisor.stop(supervisor, :normal, 7000)
        send(observer, {:standalone_stopped, self(), result, Process.alive?(custodian)})
      end)

    try do
      # Hold only our custodian at a deterministic lifecycle barrier. A correct
      # shutdown reaches transport retirement while keeping the owner alive,
      # and cannot report completion until this custodian resumes and exits.
      await_transport_retirement(owner, Gaoxy.Lifecycle.deadline(2000))
      refute_receive {:standalone_stopped, ^stopper, _, _}, 50
    after
      resume_custodian(custodian)
    end

    assert_receive {:standalone_stopped, ^stopper, :ok, false}, 7000
    assert_receive {:DOWN, ^custodian_monitor, :process, ^custodian, :normal}, 1000
    assert_receive {:DOWN, ^stopper_monitor, :process, ^stopper, :normal}, 1000
    refute Process.whereis(Gaoxy.Server.Runtime)
    refute Process.whereis(Gaoxy.Server.UpstreamOwners)
    {:ok, {ip, port}} = local
    assert {:error, :econnrefused} = :gen_tcp.connect(ip, port, [:binary, active: false], 500)
  end

  test "standalone supervisor joins an explicit runtime stop already in progress" do
    assert {:ok, options} = Config.decode(config(target(:fixed, origin(:http1))))
    assert {:ok, supervisor} = Gaoxy.Server.Supervisor.start_link(options)

    on_exit(fn ->
      if Process.alive?(supervisor), do: Supervisor.stop(supervisor, :normal, 7000)
    end)

    instance = Process.whereis(Gaoxy.Server.Runtime)
    instance_monitor = Process.monitor(instance)
    local = Gaoxy.info(instance, "web").local
    assert request(local, "/live-scope") =~ "\r\n\r\n/live-scope"

    %{transports: owner} = :sys.get_state(Gaoxy.Server.RouteResources)
    %{records: records} = :sys.get_state(owner)
    assert [custodian] = Enum.map(records, fn {_, record} -> record.custodian end)
    custodian_monitor = Process.monitor(custodian)
    :ok = :sys.suspend(custodian)
    on_exit(fn -> resume_custodian(custodian) end)
    observer = self()

    {runtime_stopper, runtime_stopper_monitor} =
      spawn_monitor(fn ->
        result = Gaoxy.stop(instance, 5000)
        send(observer, {:runtime_stopped, self(), result, Process.alive?(custodian)})
      end)

    try do
      # Establish that the explicit stop already owns the drain operation before
      # asking the supervisor to stop the same instance and its resource owners.
      await_transport_retirement(owner, Gaoxy.Lifecycle.deadline(2000))

      {stopper, stopper_monitor} =
        spawn_monitor(fn ->
          result = Supervisor.stop(supervisor, :normal, 7000)
          send(observer, {:standalone_stopped, self(), result, Process.alive?(custodian)})
        end)

      try do
        refute_receive {:standalone_stopped, ^stopper, _, _}, 50
        refute_receive {:runtime_stopped, ^runtime_stopper, _, _}, 50
      after
        resume_custodian(custodian)
      end

      assert_receive {:standalone_stopped, ^stopper, :ok, false}, 7000
      assert_receive {:DOWN, ^stopper_monitor, :process, ^stopper, :normal}, 1000
    after
      resume_custodian(custodian)
    end

    assert_receive {:runtime_stopped, ^runtime_stopper, :ok, false}, 1000
    assert_receive {:DOWN, ^runtime_stopper_monitor, :process, ^runtime_stopper, :normal}, 1000
    assert_receive {:DOWN, ^custodian_monitor, :process, ^custodian, :normal}, 1000
    assert_receive {:DOWN, ^instance_monitor, :process, ^instance, :normal}, 1000
    refute Process.whereis(Gaoxy.Server.Runtime)
    refute Process.whereis(Gaoxy.Server.UpstreamOwners)
    {:ok, {ip, port}} = local
    assert {:error, :econnrefused} = :gen_tcp.connect(ip, port, [:binary, active: false], 500)
  end

  for protocol <- [:http1, :h2c, :http2], kind <- [:fixed, :group] do
    @protocol protocol
    @kind kind
    test "JSON #{@kind} #{@protocol} upstream serves real requests and stops its owners" do
      member = origin(@protocol)
      target = target(@kind, member)
      assert {:ok, options} = Config.decode(config(target))
      start_supervised!({Gaoxy.Server.Supervisor, options})
      local = Gaoxy.info(Gaoxy.Server.Runtime, "web").local

      response =
        if @kind == :group,
          do: await_response(local, "/configured"),
          else: request(local, "/configured")

      assert response =~ "HTTP/1.1 200"
      assert response =~ "\r\n\r\n/configured"

      assert :ok = Gaoxy.stop(Gaoxy.Server.Runtime, 5000)
      assert :ok = stop_supervised(Gaoxy.Server.Supervisor)
      refute Process.whereis(Gaoxy.Server.Runtime)
      refute Process.whereis(Gaoxy.Server.UpstreamOwners)
      {:ok, {ip, port}} = local
      assert {:error, :econnrefused} = :gen_tcp.connect(ip, port, [:binary, active: false], 500)
    end
  end

  @tag :tmp_dir
  test "a static listener reloads managed routes atomically and keeps old config on rejection", %{
    tmp_dir: dir
  } do
    assert {:ok, options} = Config.decode(config(%{"type" => "static", "body" => "old"}))
    start_supervised!({Gaoxy.Server.Supervisor, options})
    local = Gaoxy.info(Gaoxy.Server.Runtime, "web").local
    assert request(local, "/before") =~ "\r\n\r\nold"
    path = Path.join(dir, "routes.json")
    replacement = target(:group, origin(:h2c))
    File.write!(path, JSON.encode!(routes(replacement)))
    assert {:ok, generation} = Gaoxy.Server.reload_routes("web", path, 5000)
    assert await_response(local, "/new") =~ "\r\n\r\n/new"
    assert Gaoxy.info(Gaoxy.Server.Runtime, "web").local == local

    File.write!(path, JSON.encode!(routes(put_in(replacement, ["health", "timeout"], 0))))
    assert {:error, _} = Gaoxy.Server.reload_routes("web", path, 1000)

    assert {:ok, ^generation, _} =
             Gaoxy.HTTP.Generation.snapshot(Gaoxy.Server.Supervisor.route_store("web"))

    assert request(local, "/retained") =~ "\r\n\r\n/retained"

    File.write!(path, JSON.encode!(routes(%{"type" => "static", "body" => "final"})))
    assert {:ok, _} = Gaoxy.Server.reload_routes("web", path, 5000)
    assert request(local, "/final") =~ "\r\n\r\nfinal"
  end

  defp origin(:http1) do
    spec = [id: :origin, endpoint: {Origin, []}]
    instance = start_supervised!({Gaoxy.HTTP, spec})
    {:ok, {_, port}} = Gaoxy.info(instance, :origin).local
    %{"upstream" => "http://127.0.0.1:#{port}", "upstream_protocol" => "http1"}
  end

  defp origin(protocol) do
    {_peer, ready} = Peer.peer(protocol)

    base = %{
      "upstream" =>
        "#{if protocol == :http2, do: "https", else: "http"}://localhost:#{ready["port"]}",
      "upstream_protocol" => Atom.to_string(protocol),
      "connect_address" => "127.0.0.1"
    }

    if protocol == :http2, do: Map.put(base, "cacertfile", ready["ca"]), else: base
  end

  defp target(:fixed, member),
    do: Map.merge(member, %{"type" => "reverse_proxy", "managed" => true})

  defp target(:group, member),
    do: %{
      "type" => "upstream_group",
      "id" => "api",
      "members" => [Map.merge(member, %{"id" => "one", "max_inflight" => 4})],
      "health" => %{"interval" => 100, "timeout" => 500, "jitter" => 0, "recovery_threshold" => 1}
    }

  defp routes(target), do: %{"version" => 1, "routes" => [%{"target" => target}]}

  defp config(target),
    do: %{
      "version" => 1,
      "services" => [
        %{
          "id" => "web",
          "transport" => "tcp",
          "handler" => "http",
          "routes" => routes(target),
          "limits" => %{"max_bytes" => 67_108_864}
        }
      ]
    }

  defp await_response(local, path, deadline \\ nil) do
    deadline = deadline || System.monotonic_time(:millisecond) + 3000
    response = request(local, path)

    if String.starts_with?(response, "HTTP/1.1 200") or
         System.monotonic_time(:millisecond) >= deadline do
      response
    else
      receive do
      after
        10 -> await_response(local, path, deadline)
      end
    end
  end

  defp await_transport_retirement(owner, deadline) do
    assert Gaoxy.Lifecycle.remaining(deadline) > 0, "managed owner did not begin shutdown"

    state =
      try do
        :sys.get_state(owner, min(500, Gaoxy.Lifecycle.remaining(deadline)))
      catch
        :exit, _ -> :stopped
      end

    unless state == :stopped or state.lifecycle != :running do
      receive do
      after
        1 -> await_transport_retirement(owner, deadline)
      end
    end
  end

  defp resume_custodian(custodian) do
    if Process.alive?(custodian), do: :sys.resume(custodian, 1000)
  catch
    :exit, _ -> :ok
  end

  defp request({:ok, {ip, port}}, path) do
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)

    try do
      :ok =
        :gen_tcp.send(socket, [
          "GET ",
          path,
          " HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
        ])

      read(socket, "")
    after
      :gen_tcp.close(socket)
    end
  end

  defp read(socket, bytes) do
    case :gen_tcp.recv(socket, 0, 2000) do
      {:ok, more} -> read(socket, bytes <> more)
      {:error, :closed} -> bytes
    end
  end
end
