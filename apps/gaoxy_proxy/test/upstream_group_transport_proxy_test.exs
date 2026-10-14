defmodule Gaoxy.Proxy.UpstreamGroupTransportProxyTest do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.{GroupEndpoint, UpstreamGroups}
  alias Gaoxy.Proxy.HTTP.Session
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports

  @moduletag :capture_log
  @timeout 3_000

  defmodule InvalidOpenEndpoint do
    @behaviour Gaoxy.HTTP.Endpoint
    def init(options), do: GroupEndpoint.init(options)
    def resources(config), do: GroupEndpoint.resources(config)

    def call(exchange, config) do
      GroupEndpoint.call(%{exchange | request: %{exchange.request | path: "/invalid%XX"}}, config)
    end
  end

  setup_all do
    directory =
      Path.join(System.tmp_dir!(), "gaoxy-managed-group-#{System.unique_integer([:positive])}")

    script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
    on_exit(fn -> File.rm_rf!(directory) end)

    for name <- ["trusted", "untrusted"] do
      {log, status} =
        System.cmd("bash", [script, Path.join(directory, name)], stderr_to_stdout: true)

      assert status == 0, log
    end

    rotated = Path.join(directory, "rotated")
    rotation_certificates(rotated)

    {:ok,
     trusted: Path.join(directory, "trusted"),
     untrusted: Path.join(directory, "untrusted"),
     rotated: rotated}
  end

  for protocol <- [:tcp, :tls] do
    @protocol protocol
    test "#{protocol} selected member reuses the HEAD connection for two raw GET responses",
         context do
      {source, peer, listener} = peer(@protocol, context)
      fixture = managed([source])
      assert_receive {:peer_head, ^peer, worker, health}, @timeout
      assert_receive {:peer_accepted, ^peer, ^worker}, @timeout
      assert health =~ "HEAD /health HTTP/1.1\r\n"

      if @protocol == :tls do
        assert_receive {:peer_tls, ^peer, ^worker, "localhost", nil}, @timeout
        [handle] = fixture.transports

        assert %{policy: %{connect_address: {127, 0, 0, 1}, open_options: options}} =
                 :sys.get_state(fixture.transport_owner).records[handle.resource]

        trust = options[:ssl][:cacerts]
        assert trust == ca(context.trusted)
        assert Enum.all?(trust, &is_binary/1)
      end

      encoded = :zlib.gzip(<<0, "raw", 255>>)

      for target <- ["/a%2Fb?q=%2F", "/empty?"] do
        socket = connect(fixture.instance)

        :ok =
          :gen_tcp.send(socket, request("GET", target, [{"X-Trace", "one"}, {"X-Trace", "two"}]))

        assert_receive {:peer_request, ^peer, ^worker, upstream}, @timeout
        assert upstream =~ "GET #{target} HTTP/1.1\r\n"
        assert String.downcase(upstream) =~ "x-trace: one\r\nx-trace: two\r\n"
        assert String.downcase(upstream) =~ "host: #{URI.parse(source.origin).authority}\r\n"

        send(
          worker,
          {:respond,
           [
             "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nSet-Cookie: one=1\r\nSet-Cookie: two=2\r\nContent-Length: #{byte_size(encoded)}\r\n\r\n",
             encoded
           ]}
        )

        response = head(:gen_tcp, socket)
        assert response =~ "200 OK"
        assert response =~ "content-encoding: gzip\r\n"
        assert response =~ "set-cookie: one=1\r\nset-cookie: two=2\r\n"
        assert {:ok, ^encoded} = :gen_tcp.recv(socket, byte_size(encoded), @timeout)
        :ok = :gen_tcp.close(socket)
        assert_clean(fixture)
      end

      refute_receive {:peer_head, ^peer, _, _}, 0
      assert {:error, :timeout} = accept(@protocol, listener, 0)
      stop_and_join(fixture, [{peer, listener, @protocol}])
      refute_receive {:peer_accepted, ^peer, _}, 0
    end
  end

  for protocol <- [:tcp, :tls] do
    @protocol protocol
    test "#{protocol} managed group preserves ordered request and response trailers", context do
      {source, peer, listener} = peer(@protocol, context)
      fixture = managed([source])
      assert_receive {:peer_head, ^peer, worker, _}, @timeout
      socket = connect(fixture.instance)

      :ok =
        :gen_tcp.send(socket, [
          request("DELETE", "/trailers", [
            {"Transfer-Encoding", "chunked"},
            {"Trailer", "X-Trace"}
          ]),
          "2\r\n",
          <<0, 255>>,
          "\r\n0\r\nX-Trace: one\r\nX-Trace: two\r\n\r\n"
        ])

      assert_receive {:peer_request, ^peer, ^worker, upstream}, @timeout
      assert String.downcase(upstream) =~ "transfer-encoding: chunked\r\n"
      assert String.downcase(upstream) =~ "trailer: x-trace\r\n"

      assert_receive {:peer_upload, ^worker,
                      {<<0, 255>>, [{"x-trace", "one"}, {"x-trace", "two"}]}},
                     @timeout

      send(
        worker,
        {:respond,
         [
           "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nTrailer: X-Trace\r\n\r\n2\r\n",
           <<255, 0>>,
           "\r\n0\r\nX-Trace: first\r\nX-Trace: last\r\n\r\n"
         ]}
      )

      assert head(:gen_tcp, socket) =~ "trailer: x-trace\r\n"
      assert {<<255, 0>>, [{"x-trace", "first"}, {"x-trace", "last"}]} = chunks(:gen_tcp, socket)
      :ok = :gen_tcp.close(socket)
      assert_clean(fixture)
      stop_and_join(fixture, [{peer, listener, @protocol}])
    end

    test "#{protocol} managed group returns redirects and early final without replay or upload EOF",
         context do
      {source, peer, listener} = peer(@protocol, context)
      fixture = managed([source])
      assert_receive {:peer_head, ^peer, worker, _}, @timeout
      socket = connect(fixture.instance)
      :ok = :gen_tcp.send(socket, request("GET", "/redirect"))
      assert_receive {:peer_request, ^peer, ^worker, upstream}, @timeout
      assert upstream =~ "GET /redirect HTTP/1.1\r\n"

      send(
        worker,
        {:respond,
         "HTTP/1.1 302 Found\r\nLocation: http://127.0.0.1:1/do-not-follow\r\nContent-Length: 0\r\n\r\n"}
      )

      response = head(:gen_tcp, socket)
      assert response =~ "302 Found"
      assert response =~ "location: http://127.0.0.1:1/do-not-follow\r\n"
      :ok = :gen_tcp.close(socket)
      assert_clean(fixture)
      socket = connect(fixture.instance)
      :ok = :gen_tcp.send(socket, request("POST", "/early", [{"Content-Length", "1000000"}]))
      assert_receive {:peer_request, ^peer, ^worker, upstream}, @timeout
      assert upstream =~ "POST /early HTTP/1.1\r\n"
      send(worker, {:respond, "HTTP/1.1 413 Payload Too Large\r\nContent-Length: 2\r\n\r\nno"})
      response = head(:gen_tcp, socket)
      assert response =~ "413 "
      assert response =~ "connection: close\r\n"
      assert {:ok, "no"} = :gen_tcp.recv(socket, 2, @timeout)
      assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      assert_clean(fixture)
      refute_receive {:peer_request, ^peer, _, _}, 0
      stop_and_join(fixture, [{peer, listener, @protocol}])
    end
  end

  test "Session pins its selected transport and binds both original completions before upload readiness" do
    {source, peer, listener} = peer(:tcp, %{})
    fixture = managed([source])
    assert_receive {:peer_head, ^peer, worker, _}, @timeout
    barrier = call_barrier(fixture.groups, :bind)
    socket = connect(fixture.instance)

    :ok = :gen_tcp.send(socket, [request("POST", "/bound", [{"Content-Length", "3"}]), "abc"])

    groups = fixture.groups
    group = fixture.group

    assert_receive {:owner_call_held, ^groups, guardian,
                    {:bind, ^group, group_token, completion}},
                   @timeout

    assert %HTTP.RequestCompletion{} = completion
    assert_receive {:peer_request, ^peer, ^worker, upstream}, @timeout
    assert upstream =~ "POST /bound HTTP/1.1\r\n"
    send(worker, {:check_upload, self()})
    assert_receive {:upload_not_ready, ^worker, {:error, :timeout}}, @timeout

    [{transport_token, held}] = Map.to_list(:sys.get_state(fixture.transport_owner).tokens)
    assert held.guardian == guardian
    assert held.completion == completion
    assert transport_token != group_token
    :erlang.trace(guardian, true, [:send])
    refute_receive {:trace, ^guardian, :send, {:gaoxy_proxy_http, _, {:ready, _, _, _}}, _}, 0
    send(groups, {:continue_owner_call, barrier})

    assert_receive {:trace, ^guardian, :send, {:gaoxy_proxy_http, ^guardian, {:ready, _, _, _}},
                    _},
                   @timeout

    assert_receive {:upload_body, ^worker, "abc"}, @timeout
    state = :sys.get_state(guardian)
    [transport] = fixture.transports
    assert state.selection == {group, group_token}
    assert state.transport_selection == {transport, transport_token}
    assert state.token != group_token and state.token != transport_token
    assert state.client.completion(state.original_request) == completion
    assert :sys.get_state(groups).tokens[group_token].completion == completion
    assert [%{holder: ^guardian, kind: :request}] = state.transport_pins

    assert {:error, :unauthorized} =
             Transports.checkout(transport, state.transport_pins, guardian, deadline())

    outer =
      for {_, pin} <- :sys.get_state(fixture.transport_owner).pins,
          pin.public.kind == :request and pin.public.holder != guardian,
          do: pin.public

    assert [_] = outer

    assert {:error, :invalid_resource_pin} =
             Transports.checkout(transport, outer, self(), deadline())

    send(worker, {:respond, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n"})
    assert head(:gen_tcp, socket) =~ "200 OK"
    :ok = :gen_tcp.close(socket)
    assert_clean(fixture)
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
    stop_and_join(fixture, [{peer, listener, :tcp}])
  end

  test "transport token denial cancels one selection neutrally without another GET or replay" do
    {first_source, first_peer, first_listener} = peer(:tcp, %{})
    {second_source, second_peer, second_listener} = peer(:tcp, %{})
    fixture = managed([first_source, second_source], 1)
    assert_receive {:peer_head, ^first_peer, first_worker, _}, @timeout
    assert_receive {:peer_head, ^second_peer, second_worker, _}, @timeout
    held_socket = connect(fixture.instance)
    :ok = :gen_tcp.send(held_socket, request("GET", "/held"))
    assert_receive {:peer_request, ^first_peer, ^first_worker, held_head}, @timeout
    assert held_head =~ "GET /held HTTP/1.1\r\n"

    eventually(fn ->
      match?({:ok, %{request_tokens: 1}}, Transports.status(fixture.transport_owner))
    end)

    before = health_state(fixture)

    denied = connect(fixture.instance)
    :ok = :gen_tcp.send(denied, request("GET", "/denied"))
    response = head(:gen_tcp, denied)
    assert response =~ "502 Bad Gateway" or response =~ "503 Service Unavailable"
    :ok = :gen_tcp.close(denied)
    eventually(fn -> UpstreamGroups.status(fixture.group).inflight == 1 end)
    assert health_state(fixture) == before
    assert {:ok, %{request_tokens: 1}} = Transports.status(fixture.transport_owner)
    refute_receive {:peer_request, ^second_peer, _, _}, 0
    refute_receive {:peer_request, ^first_peer, _, _}, 0

    send(first_worker, {:respond, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n"})
    assert head(:gen_tcp, held_socket) =~ "200 OK"
    :ok = :gen_tcp.close(held_socket)
    assert_clean(fixture)

    valid = connect(fixture.instance)
    :ok = :gen_tcp.send(valid, request("GET", "/valid"))
    assert_receive {:peer_request, ^first_peer, ^first_worker, valid_head}, @timeout
    assert valid_head =~ "GET /valid HTTP/1.1\r\n"
    send(first_worker, {:respond, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n"})
    assert head(:gen_tcp, valid) =~ "200 OK"
    :ok = :gen_tcp.close(valid)
    assert_clean(fixture)
    refute_receive {:peer_request, ^second_peer, ^second_worker, _}, 0

    stop_and_join(fixture, [
      {first_peer, first_listener, :tcp},
      {second_peer, second_listener, :tcp}
    ])
  end

  test "unactivated selected-member Session and cancellation allocate no pins, tokens or Fetch" do
    {source, peer, listener} = peer(:tcp, %{})
    fixture = managed([source])
    assert_receive {:peer_head, ^peer, _worker, _}, @timeout
    assert {:ok, config} = GroupEndpoint.init(%{group: fixture.group})
    transport_before = Transports.status(fixture.transport_owner)
    group_before = UpstreamGroups.status(fixture.group)

    args = %{
      owner: self(),
      service: self(),
      instance: fixture.instance,
      gate: self(),
      started_at: Lifecycle.now(),
      deadline: deadline(),
      config: config,
      selector: {:group, fixture.group, []},
      request_options: %{
        method: :get,
        headers: [],
        body: :none,
        path: "/unactivated",
        query: nil,
        limits: %{},
        max_upload_bytes: 65_536
      }
    }

    assert {:ok, session} = Session.start_link(args)
    monitor = Process.monitor(session)

    assert %{
             token: nil,
             request: nil,
             selection: nil,
             transport_selection: nil,
             transport_pins: []
           } =
             :sys.get_state(session)

    assert Transports.status(fixture.transport_owner) == transport_before
    assert UpstreamGroups.status(fixture.group).inflight == group_before.inflight
    Session.cancel(session)
    assert_receive {:DOWN, ^monitor, :process, ^session, :normal}, @timeout
    assert Transports.status(fixture.transport_owner) == transport_before
    refute_receive {:peer_request, ^peer, _, _}, 0
    assert {:error, :timeout} = :gen_tcp.accept(listener, 0)
    stop_and_join(fixture, [{peer, listener, :tcp}])
  end

  test "selected group token rejects wrong authority without Fetch or passive health change" do
    {source, peer, listener} = peer(:tcp, %{})
    fixture = managed([source])
    assert_receive {:peer_head, ^peer, _, _}, @timeout
    before = health_state(fixture)

    assert {:ok, pins} =
             Resources.pin_many(
               UpstreamGroups.resources(fixture.group),
               self(),
               :request,
               deadline()
             )

    assert {:ok, member, token} =
             UpstreamGroups.checkout(fixture.group, pins, self(), %{}, deadline())

    assert UpstreamGroups.status(fixture.group).inflight == 1

    identity = %{
      origin: "http://wrong.invalid",
      upstream_protocol: :http1,
      instance: fixture.instance
    }

    assert {:error, :transport_endpoint_mismatch} =
             Transports.validate_endpoint(member.config.transport, identity, deadline())

    assert :ok = UpstreamGroups.finish(fixture.group, token, :cancelled)
    assert :ok = Resources.release(pins)
    assert health_state(fixture) == before
    refute_receive {:peer_request, ^peer, _, _}, 0
    assert_clean(fixture)
    valid_request(fixture, peer, "/after-authority")
    stop_and_join(fixture, [{peer, listener, :tcp}])
  end

  test "cross-instance Session rejection preserves its selected token for neutral cleanup" do
    {source, peer, listener} = peer(:tcp, %{})
    fixture = managed([source])
    assert_receive {:peer_head, ^peer, _, _}, @timeout
    assert {:ok, other} = Gaoxy.start_link()
    Process.unlink(other)
    on_exit(fn -> if Process.alive?(other), do: Gaoxy.stop(other, @timeout) end)
    before = health_state(fixture)

    assert {:ok, pins} =
             Resources.pin_many(
               UpstreamGroups.resources(fixture.group),
               self(),
               :request,
               deadline()
             )

    assert {:ok, config} = GroupEndpoint.init(%{group: fixture.group})
    {:ok, service, _} = GenServer.call(fixture.instance, {:lookup, :http})

    assert {:ok, session} =
             Session.start_link(session_args(fixture, config, pins, other, service))

    monitor = Process.monitor(session)
    send(session, {:gaoxy_cleanup_activate, make_ref()})
    assert_receive {:gaoxy_proxy_http, ^session, {:error, :transport_endpoint_mismatch}}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^session, :normal}, @timeout
    assert :ok = Resources.release(pins)
    assert health_state(fixture) == before
    refute_receive {:peer_request, ^peer, _, _}, 0
    assert_clean(fixture)
    assert :ok = Gaoxy.stop(other, @timeout)
    valid_request(fixture, peer, "/after-instance")
    stop_and_join(fixture, [{peer, listener, :tcp}])
  end

  for action <- [:disconnect, :native_owner_death, :guardian_death] do
    @action action
    test "#{action} joins one original completion held independently by group and transport" do
      {source, peer, listener} = peer(:tcp, %{})
      fixture = managed([source])
      assert_receive {:peer_head, ^peer, worker, _}, @timeout
      {:ok, service, _} = GenServer.call(fixture.instance, {:lookup, :http})
      barrier = if @action == :guardian_death, do: service_down_barrier(service)
      socket = connect(fixture.instance)
      :ok = :gen_tcp.send(socket, request("GET", "/pending"))
      assert_receive {:peer_request, ^peer, ^worker, _}, @timeout
      send(worker, {:respond, "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n"})
      assert head(:gen_tcp, socket) =~ "200 OK"
      {guardian, completion, group_token} = bound_request(fixture)
      state = :sys.get_state(guardian)
      monitor = Process.monitor(guardian)
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
      assert_pending(fixture, group_token)

      case @action do
        :disconnect ->
          Session.consumed(guardian)
          eventually(fn -> :sys.get_state(guardian).consumed end)
          assert_pending(fixture, group_token)
          assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
          :ok = :gen_tcp.close(socket)

        :native_owner_death ->
          Process.exit(state.owner, :kill)

        :guardian_death ->
          expect_failed_cleanup(fixture)
          Process.exit(guardian, :kill)
      end

      assert_receive {:DOWN, ^monitor, :process, ^guardian, reason}, @timeout
      assert reason == if(@action == :guardian_death, do: :killed, else: :normal)
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      eventually(fn -> UpstreamGroups.status(fixture.group).inflight == 0 end)

      if @action == :guardian_death do
        assert_receive {:service_guardian_down_held, ^service, ^guardian, :killed}, @timeout
        refute_receive {:service_completion_received, ^service, ^guardian, _}, 0

        eventually(fn ->
          match?(
            {:ok, %{request_tokens: 0, pins: 2, helpers: 0}},
            Transports.status(fixture.transport_owner)
          )
        end)

        assert {:error,
                {:shutdown, [{:http, {:error, {:cleanup_failed, :cleanup_receipt_missing}}}], []}} =
                 stop_after_service_down(fixture.instance, service, barrier)

        join_peer(peer, listener, :tcp)
      else
        :gen_tcp.close(socket)
        assert_clean(fixture)
        stop_and_join(fixture, [{peer, listener, :tcp}])
      end
    end
  end

  for provider <- [:transport, :group] do
    @provider provider
    test "#{provider} owner death at bind aborts original completion and preserves failed Service receipt" do
      {source, peer, listener} = peer(:tcp, %{})
      fixture = managed([source])
      assert_receive {:peer_head, ^peer, worker, _}, @timeout
      owner = if @provider == :transport, do: fixture.transport_owner, else: fixture.groups
      operation = if @provider == :transport, do: :bind_completion, else: :bind
      registration = :sys.get_state(fixture.transport_owner).registration
      barrier = call_barrier(owner, operation)
      {:ok, service, _} = GenServer.call(fixture.instance, {:lookup, :http})
      service_barrier = service_down_barrier(service)
      socket = connect(fixture.instance)
      :ok = :gen_tcp.send(socket, request("GET", "/bind-failure"))
      assert_receive {:owner_call_held, ^owner, guardian, message}, @timeout
      completion = elem(message, 3)
      assert %HTTP.RequestCompletion{} = completion
      assert_receive {:peer_request, ^peer, ^worker, _}, @timeout
      send(worker, {:await_eof, self()})
      monitor = Process.monitor(guardian)
      owner_monitor = Process.monitor(owner)
      expect_failed_cleanup(fixture)
      Process.exit(owner, :kill)
      send(owner, {:continue_owner_call, barrier})
      assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :killed}, @timeout

      expected =
        if @provider == :transport,
          do: {:cleanup_failed, {:transport_cleanup_failed, :not_running}},
          else: {:selection_cleanup_failed, :not_running}

      assert_receive {:DOWN, ^monitor, :process, ^guardian, ^expected}, @timeout
      assert_receive {:service_guardian_down_held, ^service, ^guardian, ^expected}, @timeout
      refute_receive {:service_completion_received, ^service, ^guardian, _}, 0
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:peer_eof, ^worker}, @timeout

      if @provider == :group do
        assert {:ok, %{request_tokens: 0, helpers: 0}} =
                 Transports.status(fixture.transport_owner)
      else
        assert UpstreamGroups.status(fixture.group).inflight == 1
        [{_, unbound}] = Map.to_list(:sys.get_state(fixture.groups).tokens)
        assert unbound.completion == nil
      end

      result = stop_after_service_down(fixture.instance, service, service_barrier)

      participants =
        if @provider == :transport, do: [{registration, {:error, :cleanup_unconfirmed}}], else: []

      assert result ==
               {:error,
                {:shutdown, [{:http, {:error, {:cleanup_failed, :cleanup_receipt_missing}}}],
                 participants}}

      join_peer(peer, listener, :tcp)
    end
  end

  test "invalid managed open retains the unbound transport and group ledgers without successful cleanup" do
    {source, peer, listener} = peer(:tcp, %{})
    fixture = managed([source])
    assert_receive {:peer_head, ^peer, _, _}, @timeout

    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               id: :invalid_open,
               endpoint: {InvalidOpenEndpoint, %{group: fixture.group}},
               limits: %{max_bytes: 16_777_216}
             )

    assert {:ok, _} = Gaoxy.add(fixture.instance, spec)
    {:ok, service, _} = GenServer.call(fixture.instance, {:lookup, :invalid_open})
    barrier = service_down_barrier(service)
    socket = connect(fixture.instance, :invalid_open)
    :ok = :gen_tcp.send(socket, request("POST", "/valid", [{"Content-Length", "3"}]))
    assert head(:gen_tcp, socket) =~ "502 Bad Gateway"

    assert_receive {:service_guardian_down_held, ^service, guardian,
                    {:cleanup_failed, {:transport_cleanup_failed, :cleanup_unconfirmed}}},
                   @timeout

    refute_receive {:service_completion_received, ^service, ^guardian, _}, 0
    expect_failed_cleanup(fixture)

    eventually(fn ->
      match?(
        {:ok, %{request_tokens: 1, helpers: 0, pins: 2}},
        Transports.status(fixture.transport_owner)
      )
    end)

    [{_, hold}] = Map.to_list(:sys.get_state(fixture.transport_owner).tokens)
    assert hold.completion == nil and hold.guardian_down
    assert UpstreamGroups.status(fixture.group).inflight == 1
    [{_, group_hold}] = Map.to_list(:sys.get_state(fixture.groups).tokens)
    assert group_hold.completion == nil
    refute_receive {:peer_request, ^peer, _, _}, 0
    registration = :sys.get_state(fixture.transport_owner).registration

    assert {:error,
            {:shutdown, [{:invalid_open, {:error, {:cleanup_failed, :cleanup_receipt_missing}}}],
             [{^registration, {:error, :cleanup_unconfirmed}}]}} =
             stop_after_service_down(fixture.instance, service, barrier)

    assert {:ok, %{request_tokens: 1, pins: 0}} = Transports.status(fixture.transport_owner)
    join_peer(peer, listener, :tcp)
  end

  test "short stop preserves failed result while aborting a pending response ACK and both token holds" do
    {source, peer, listener} = peer(:tcp, %{})
    fixture = managed([source])
    assert_receive {:peer_head, ^peer, worker, _}, @timeout
    socket = connect(fixture.instance)
    :ok = :gen_tcp.send(socket, request("GET", "/ack"))
    assert_receive {:peer_request, ^peer, ^worker, _}, @timeout
    send(worker, {:respond, "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n"})
    assert head(:gen_tcp, socket) =~ "200 OK"
    {guardian, completion, group_token} = bound_request(fixture)
    [handle] = fixture.transports
    record = :sys.get_state(fixture.transport_owner).records[handle.resource]
    scope = record.scope
    custodian = record.custodian
    custodian_monitor = Process.monitor(custodian)
    native = :sys.get_state(guardian).owner
    monitor = Process.monitor(guardian)
    instance_monitor = Process.monitor(fixture.instance)
    assert :erlang.suspend_process(native)

    try do
      send(worker, {:send_chunk, "4\r\nbody\r\n", self()})
      assert_receive {:peer_chunk_sent, ^worker}, @timeout
      eventually(fn -> :sys.get_state(guardian).delivery != nil end)
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
      assert_pending(fixture, group_token)
      assert {:error, {:deadline_exceeded, :cleanup_pending}} = Gaoxy.stop(fixture.instance, 0)
      assert {:ok, receipt} = Transports.retire(fixture.transport_owner, deadline())
      expect_short_stop_cleanup(fixture, receipt)

      assert {:error, {:deadline_exceeded, :cleanup_pending}} =
               Transports.await_retirement(receipt, Lifecycle.deadline(20))

      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout
      instance = fixture.instance
      assert_receive {:DOWN, ^instance_monitor, :process, ^instance, :normal}, @timeout
      eventually(fn -> UpstreamGroups.status(fixture.group).inflight == 0 end)
      join_peer(peer, listener, :tcp)
      assert {:ok, scope_receipt} = HTTP.ManagedTransport.retire(scope, mode: :abort)
      assert :ok = HTTP.ManagedTransport.await_retired(scope_receipt, @timeout)
      assert_receive {:DOWN, ^custodian_monitor, :process, ^custodian, :normal}, @timeout

      eventually(fn ->
        match?(
          {:ok,
           %{
             resources: 0,
             request_tokens: 0,
             pins: 0,
             helpers: 0,
             reserved_connections: 0,
             failed_resources: 0,
             owned_serialized_payload_bytes: 0
           }},
          Transports.status(fixture.transport_owner)
        )
      end)

      assert {:ok, ^receipt} = Transports.retire(fixture.transport_owner, deadline())

      assert {:error, {:deadline_exceeded, :cleanup_pending}} =
               Transports.await_retirement(receipt, Lifecycle.deadline(20))
    after
      if Process.alive?(native), do: :erlang.resume_process(native)
    end
  end

  for reason <- [:wrong_ca, :wrong_hostname] do
    @reason reason
    @tag :tmp_dir
    test "TLS #{@reason} after genuine healthy HEAD rejects without fallback and preserves immutable DER trust",
         context do
      directory = Path.join(context.tmp_dir, "certificates")
      File.mkdir_p!(directory)

      for name <- ["ca.pem", "cert.pem", "key.pem", "wrong-cert.pem"],
          do: File.cp!(Path.join(context.rotated, name), Path.join(directory, name))

      {source, peer, listener} = peer(:tls, %{trusted: directory})
      fixture = managed([source])
      assert_receive {:peer_head, ^peer, worker, _}, @timeout
      assert_receive {:peer_tls, ^peer, ^worker, "localhost", nil}, @timeout
      [handle] = fixture.transports
      policy = :sys.get_state(fixture.transport_owner).records[handle.resource].policy
      assert policy.open_options[:ssl][:cacerts] == source.trust
      assert policy.connect_address == {127, 0, 0, 1}

      # Change the embedding's source file after preparation. Fetch must retain DER.
      File.cp!(Path.join(context.untrusted, "ca.pem"), Path.join(directory, "ca.pem"))
      assert ca(directory) != source.trust
      send(worker, {:close_peer, self()})
      assert_receive {:peer_closed, ^worker}, @timeout
      join_peer(peer, listener, :tls)
      port = URI.parse(source.origin).port

      certificate =
        if @reason == :wrong_ca,
          do: Path.join(context.untrusted, "cert.pem"),
          else: Path.join(directory, "wrong-cert.pem")

      key =
        if @reason == :wrong_ca,
          do: Path.join(context.untrusted, "key.pem"),
          else: Path.join(directory, "key.pem")

      {rejecting, rejected_listener} = rejecting_tls_peer(port, certificate, key)
      {:ok, service, _} = GenServer.call(fixture.instance, {:lookup, :http})
      service_barrier = service_down_barrier(service)
      group_barrier = call_barrier(fixture.groups, :bind)
      socket = connect(fixture.instance)
      :ok = :gen_tcp.send(socket, request("GET", "/unverified"))
      groups = fixture.groups

      assert_receive {:owner_call_held, ^groups, guardian, {:bind, _, group_token, completion}},
                     @timeout

      monitor = Process.monitor(guardian)
      assert %HTTP.RequestCompletion{} = completion
      assert :sys.get_state(fixture.transport_owner).records[handle.resource].policy == policy
      expect_failed_cleanup(fixture)
      send(groups, {:continue_owner_call, group_barrier})
      assert head(:gen_tcp, socket) =~ "502 Bad Gateway"
      assert_receive {:handshake_failed, ^rejecting, _}, @timeout
      assert_receive {:rejected_peer_joined, ^rejecting}, @timeout

      assert_receive {:DOWN, ^monitor, :process, ^guardian,
                      {:cleanup_failed, :cleanup_unconfirmed}},
                     @timeout

      assert_receive {:service_guardian_down_held, ^service, ^guardian,
                      {:cleanup_failed, :cleanup_unconfirmed}},
                     @timeout

      refute_receive {:service_completion_received, ^service, ^guardian, _}, 0
      assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, @timeout)
      assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
      assert :sys.get_state(fixture.groups).tokens[group_token].completion == completion
      assert UpstreamGroups.status(fixture.group).inflight == 1
      [{_, hold}] = Map.to_list(:sys.get_state(fixture.transport_owner).tokens)
      assert hold.completion == completion and hold.guardian_down
      registration = :sys.get_state(fixture.transport_owner).registration

      assert {:error,
              {:shutdown, [{:http, {:error, {:cleanup_failed, :cleanup_receipt_missing}}}],
               [{^registration, {:error, :cleanup_unconfirmed}}]}} =
               stop_after_service_down(fixture.instance, service, service_barrier)

      assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)

      eventually(fn ->
        match?(
          {:ok,
           %{
             resources: 1,
             request_tokens: 1,
             helpers: 0,
             pins: 0,
             failed_resources: 1,
             reserved_connections: 2
           }},
          Transports.status(fixture.transport_owner)
        )
      end)

      assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)

      assert {:error, :timeout} = :ssl.transport_accept(rejected_listener, 0)
      :ok = :ssl.close(rejected_listener)
      refute_receive {:peer_request, ^rejecting, _, _}, 0
    end
  end

  defp managed(sources, tokens \\ 64) do
    parent = self()

    embedding =
      spawn(fn ->
        {:ok, instance} = Gaoxy.start_link()
        Process.unlink(instance)

        {:ok, transport_owner} =
          Transports.start_link(
            instance: instance,
            limits: %{
              max_resources: 4,
              max_pins: 32,
              max_request_tokens: tokens,
              max_owned_payload_bytes: 4_194_304
            }
          )

        Process.unlink(transport_owner)
        {:ok, groups} = UpstreamGroups.start_link(instance: instance, limits: %{max_probes: 1})
        Process.unlink(groups)
        send(parent, {:embedding_ready, self(), instance, transport_owner, groups})
        embedding_loop(instance, transport_owner, groups, [], [], [])
      end)

    assert_receive {:embedding_ready, ^embedding, instance, transport_owner, groups}, @timeout
    on_exit(fn -> cleanup_embedding(embedding) end)

    transports =
      for source <- sources do
        assert {:ok, handle, preparation} =
                 Transports.prepare(transport_owner, source, self(), deadline())

        assert {:ok, _} = Resources.pin_many([handle], embedding, :baseline, deadline())
        assert :ok = Resources.release(preparation)
        creator = :sys.get_state(transport_owner).records[handle.resource].custodian
        send(embedding, {:track_creator, creator, self()})
        assert_receive {:creator_tracked, ^embedding, ^creator}, @timeout
        handle
      end

    members =
      for {{source, transport}, index} <- Enum.with_index(Enum.zip(sources, transports)),
          do: %{id: "member-#{index}", upstream: source.origin, transport: transport}

    assert {:ok, compiled} =
             UpstreamGroups.compile(%{
               id: "managed",
               members: members,
               health: %{
                 path: "/health",
                 interval: 60_000,
                 stale_after: 120_000,
                 timeout: 2_000,
                 jitter: 0,
                 recovery_threshold: 1
               }
             })

    assert {:ok, group, preparation} =
             UpstreamGroups.prepare(groups, compiled, self(), deadline())

    assert group.transports == transports
    resources = apply(UpstreamGroups, :resources, [group])
    assert resources == [group | transports]
    assert {:ok, baseline} = Resources.pin_many(resources, embedding, :baseline, deadline())
    send(embedding, {:track_group, group, baseline, self()})
    assert_receive {:group_tracked, ^embedding, ^group}, @timeout
    assert :ok = Resources.release(preparation)

    eventually(fn ->
      status = UpstreamGroups.status(group)

      Enum.all?(status.members, &(&1.health == :healthy and not &1.probe)) and
        status.probes == 0 and
        match?({:ok, %{request_tokens: 0}}, Transports.status(transport_owner))
    end)

    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               id: :http,
               endpoint: {GroupEndpoint, %{group: group}},
               limits: %{max_bytes: 16_777_216}
             )

    assert {:ok, _} = Gaoxy.add(instance, spec)

    %{
      instance: instance,
      transport_owner: transport_owner,
      groups: groups,
      group: group,
      transports: transports,
      embedding: embedding
    }
  end

  defp embedding_loop(
         instance,
         transport_owner,
         groups,
         creators,
         handles,
         baselines,
         cleanup \\ :ok
       ) do
    receive do
      {:expect_short_stop_cleanup, receipt, caller} ->
        send(caller, {:short_stop_cleanup_expected, self(), receipt})

        embedding_loop(
          instance,
          transport_owner,
          groups,
          creators,
          handles,
          baselines,
          {:short_stop, receipt}
        )

      {:expect_failed_cleanup, caller} ->
        send(caller, {:failed_cleanup_expected, self()})
        embedding_loop(instance, transport_owner, groups, creators, handles, baselines, :failed)

      {:track_creator, actor, caller} ->
        send(caller, {:creator_tracked, self(), actor})

        embedding_loop(
          instance,
          transport_owner,
          groups,
          [{actor, Process.monitor(actor)} | creators],
          handles,
          baselines,
          cleanup
        )

      {:track_group, handle, baseline, caller} ->
        send(caller, {:group_tracked, self(), handle})

        embedding_loop(
          instance,
          transport_owner,
          groups,
          creators,
          [handle | handles],
          baseline ++ baselines,
          cleanup
        )

      {:cleanup, caller} ->
        result =
          try do
            if cleanup == :failed do
              # Tests assert failed public receipts before dismantling their actors.
              if Process.alive?(instance) do
                monitor = Process.monitor(instance)
                Process.exit(instance, :kill)
                assert_receive {:DOWN, ^monitor, :process, ^instance, :killed}, @timeout
              end

              if Process.alive?(groups), do: GenServer.stop(groups, :normal, @timeout)

              for {actor, _} <- creators,
                  Process.alive?(actor),
                  do: GenServer.stop(actor, :normal, @timeout)

              if Process.alive?(transport_owner),
                do: GenServer.stop(transport_owner, :normal, @timeout)
            else
              if Process.alive?(instance), do: assert(:ok == Gaoxy.stop(instance, @timeout))

              for pin <- baselines,
                  pin.provider == UpstreamGroups,
                  do: assert(:ok == UpstreamGroups.release(pin))

              eventually(fn ->
                state = :sys.get_state(groups)

                state.groups == %{} and state.tokens == %{} and state.probes == %{} and
                  state.pins == %{}
              end)

              GenServer.stop(groups, :normal, @timeout)

              if Process.alive?(transport_owner) do
                assert {:ok, receipt} = Transports.retire(transport_owner, deadline())

                case cleanup do
                  {:short_stop, original_receipt} ->
                    assert receipt == original_receipt

                    assert {:error, {:deadline_exceeded, :cleanup_pending}} =
                             Transports.await_retirement(receipt, Lifecycle.deadline(20))

                  :ok ->
                    assert :ok = Transports.await_retirement(receipt, deadline())
                end

                assert {:ok,
                        %{
                          resources: 0,
                          request_tokens: 0,
                          pins: 0,
                          helpers: 0,
                          reserved_connections: 0
                        }} = Transports.status(transport_owner)

                owner_monitor = Process.monitor(transport_owner)
                GenServer.stop(transport_owner, :normal, @timeout)

                assert_receive {:DOWN, ^owner_monitor, :process, ^transport_owner, :normal},
                               @timeout
              end
            end

            for {actor, monitor} <- creators do
              assert_receive {:DOWN, ^monitor, :process, ^actor, :normal}, @timeout
            end

            :ok
          rescue
            error -> {:error, Exception.format(:error, error, __STACKTRACE__)}
          end

        send(caller, {:embedding_cleaned, self(), result})
    after
      30_000 -> raise "managed group embedding was not cleaned"
    end
  end

  defp cleanup_embedding(embedding) do
    monitor = Process.monitor(embedding)
    send(embedding, {:cleanup, self()})
    assert_receive {:embedding_cleaned, ^embedding, result}, 3 * @timeout
    assert result == :ok, inspect(result)
    assert_receive {:DOWN, ^monitor, :process, ^embedding, :normal}, @timeout
  end

  defp assert_clean(fixture) do
    baseline_pins = 2 * length(fixture.transports)

    eventually(
      fn ->
        match?(
          %{active: 0, cleanup_pending: 0, retained_bytes: 0},
          Gaoxy.status(fixture.instance, :http)
        ) and
          UpstreamGroups.status(fixture.group).inflight == 0 and
          match?(
            {:ok, %{request_tokens: 0, helpers: 0, pins: ^baseline_pins}},
            Transports.status(fixture.transport_owner)
          )
      end,
      nil,
      fn ->
        inspect(
          %{
            expected_transport_pins: baseline_pins,
            service: Gaoxy.status(fixture.instance, :http),
            group: UpstreamGroups.status(fixture.group),
            transport: Transports.status(fixture.transport_owner),
            transport_holds:
              Enum.map(:sys.get_state(fixture.transport_owner).pins, fn {_, held} ->
                Map.take(held.public, [:holder, :kind, :handles])
              end)
          },
          pretty: true,
          limit: :infinity
        )
      end
    )

    assert %{cleanup_failed: nil} = Gaoxy.status(fixture.instance, :http)

    assert Enum.all?(:sys.get_state(fixture.transport_owner).pins, fn {_, held} ->
             held.public.kind == :baseline
           end)
  end

  defp health_state(fixture) do
    group = :sys.get_state(fixture.groups).groups[{fixture.group.group, fixture.group.generation}]
    Enum.map(group.members, &Map.take(&1, [:id, :health, :checked, :failures, :successes]))
  end

  defp stop_and_join(fixture, peers) do
    monitor = Process.monitor(fixture.transport_owner)
    assert :ok = Gaoxy.stop(fixture.instance, @timeout)
    assert_receive {:DOWN, ^monitor, :process, _, :normal}, @timeout

    for {peer, listener, protocol} <- peers, do: join_peer(peer, listener, protocol)
  end

  defp join_peer(peer, listener, protocol) do
    peer_monitor = Process.monitor(peer)
    :ok = wire(protocol).close(listener)
    assert_receive {:peer_joined, ^peer, result}, @timeout
    assert result == :ok, inspect(result)
    assert_receive {:DOWN, ^peer_monitor, :process, ^peer, :normal}, @timeout
  end

  defp valid_request(fixture, peer, target) do
    socket = connect(fixture.instance)
    :ok = :gen_tcp.send(socket, request("GET", target))
    assert_receive {:peer_request, ^peer, worker, upstream}, @timeout
    assert upstream =~ "GET #{target} HTTP/1.1\r\n"
    send(worker, {:respond, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n"})
    assert head(:gen_tcp, socket) =~ "200 OK"
    :ok = :gen_tcp.close(socket)
    assert_clean(fixture)
  end

  defp session_args(fixture, config, pins, instance, service) do
    %{
      owner: self(),
      service: service,
      instance: instance,
      gate: self(),
      started_at: Lifecycle.now(),
      deadline: deadline(),
      config: config,
      selector: {:group, fixture.group, pins},
      request_options: %{
        method: :get,
        headers: [],
        body: :none,
        path: "/foreign",
        query: nil,
        limits: %{},
        max_upload_bytes: 65_536
      }
    }
  end

  defp bound_request(fixture) do
    [{_, transport_hold}] = Map.to_list(:sys.get_state(fixture.transport_owner).tokens)
    [{group_token, group_hold}] = Map.to_list(:sys.get_state(fixture.groups).tokens)
    assert %HTTP.RequestCompletion{} = transport_hold.completion
    assert transport_hold.completion == group_hold.completion
    assert transport_hold.guardian == group_hold.guardian
    {transport_hold.guardian, transport_hold.completion, group_token}
  end

  defp assert_pending(fixture, group_token) do
    assert %{active: 1, cleanup_pending: 1, cleanup_failed: nil} =
             Gaoxy.status(fixture.instance, :http)

    assert UpstreamGroups.status(fixture.group).inflight == 1
    assert :sys.get_state(fixture.groups).tokens[group_token] != nil
    assert {:ok, %{request_tokens: 1, pins: 4}} = Transports.status(fixture.transport_owner)
  end

  defp expect_failed_cleanup(fixture) do
    send(fixture.embedding, {:expect_failed_cleanup, self()})
    embedding = fixture.embedding
    assert_receive {:failed_cleanup_expected, ^embedding}, @timeout
  end

  defp expect_short_stop_cleanup(fixture, receipt) do
    send(fixture.embedding, {:expect_short_stop_cleanup, receipt, self()})
    embedding = fixture.embedding
    assert_receive {:short_stop_cleanup_expected, ^embedding, ^receipt}, @timeout
  end

  defp service_down_barrier(service) do
    parent = self()
    barrier = make_ref()

    debug = fn guardian, event, _ ->
      case event do
        {:in, {:"$gen_call", _, {:attach_cleanup, _, _, next_guardian, _, _}}} ->
          next_guardian

        {:in, {:"$gen_call", {caller, _}, {:complete_cleanup, token}}} ->
          send(parent, {:service_completion_received, self(), caller, token})
          guardian

        {:in, {:DOWN, _, :process, pid, reason}} when pid == guardian ->
          send(parent, {:service_guardian_down_held, self(), pid, reason})

          receive do
            {:continue_service_down, ^barrier} -> :ok
          after
            @timeout -> raise "managed group Service DOWN barrier expired"
          end

          guardian

        _ ->
          guardian
      end
    end

    :ok = :sys.install(service, {debug, nil})
    on_exit(fn -> send(service, {:continue_service_down, barrier}) end)
    barrier
  end

  defp stop_after_service_down(instance, service, barrier) do
    parent = self()
    caller = spawn(fn -> send(parent, {:stop_result, self(), Gaoxy.stop(instance, @timeout)}) end)
    monitor = Process.monitor(caller)

    eventually(fn ->
      {:messages, messages} = Process.info(service, :messages)
      Enum.any?(messages, &match?({:"$gen_call", _, {:drain, _, _}}, &1))
    end)

    send(service, {:continue_service_down, barrier})
    assert_receive {:stop_result, ^caller, result}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^caller, :normal}, @timeout
    result
  end

  defp peer(protocol, context) do
    transport = wire(protocol)
    options = [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true]

    options =
      if protocol == :tls,
        do:
          options ++
            [
              certfile: Path.join(context.trusted, "cert.pem"),
              keyfile: Path.join(context.trusted, "key.pem")
            ],
        else: options

    assert {:ok, listener} = transport.listen(0, options)

    assert {:ok, {_, port}} =
             if(protocol == :tls, do: :ssl.sockname(listener), else: :inet.sockname(listener))

    parent = self()
    peer = spawn(fn -> accept_loop(protocol, listener, parent, []) end)

    on_exit(fn ->
      monitor = Process.monitor(peer)
      transport.close(listener)

      assert_receive {:DOWN, ^monitor, :process, ^peer, reason} when reason in [:normal, :noproc],
                     @timeout + 500
    end)

    source = %{
      origin: "#{if protocol == :tls, do: "https://localhost", else: "http://127.0.0.1"}:#{port}",
      connect_address: {127, 0, 0, 1},
      trust: if(protocol == :tls, do: ca(context.trusted), else: nil)
    }

    {source, peer, listener}
  end

  defp rejecting_tls_peer(port, certificate, key) do
    assert {:ok, listener} =
             :ssl.listen(port, [
               :binary,
               active: false,
               ip: {127, 0, 0, 1},
               reuseaddr: true,
               certfile: certificate,
               keyfile: key
             ])

    parent = self()

    peer =
      spawn(fn ->
        assert {:ok, socket} = :ssl.transport_accept(listener, @timeout)

        try do
          assert {:error, reason} = :ssl.handshake(socket, @timeout)
          send(parent, {:handshake_failed, self(), reason})
        after
          :ssl.close(socket)
        end

        send(parent, {:rejected_peer_joined, self()})
      end)

    on_exit(fn ->
      monitor = Process.monitor(peer)
      :ssl.close(listener)

      assert_receive {:DOWN, ^monitor, :process, ^peer, reason} when reason in [:normal, :noproc],
                     @timeout
    end)

    {peer, listener}
  end

  defp rotation_certificates(directory) do
    File.mkdir_p!(directory)
    config = Path.join(directory, "openssl.cnf")
    File.write!(config, "[req]\ndistinguished_name=subject\nprompt=no\n[subject]\nCN=localhost\n")
    ca_file = Path.join(directory, "ca.pem")
    ca_key = Path.join(directory, "ca-key.pem")
    key = Path.join(directory, "key.pem")
    request_file = Path.join(directory, "request.pem")

    commands = [
      [
        "req",
        "-x509",
        "-newkey",
        "rsa:2048",
        "-nodes",
        "-days",
        "2",
        "-sha256",
        "-config",
        config,
        "-subj",
        "/CN=Gaoxy rotation CA",
        "-addext",
        "basicConstraints=critical,CA:TRUE,pathlen:0",
        "-addext",
        "keyUsage=critical,keyCertSign,cRLSign",
        "-keyout",
        ca_key,
        "-out",
        ca_file
      ],
      [
        "req",
        "-new",
        "-newkey",
        "rsa:2048",
        "-nodes",
        "-sha256",
        "-config",
        config,
        "-subj",
        "/CN=localhost",
        "-keyout",
        key,
        "-out",
        request_file
      ]
    ]

    for command <- commands, do: openssl(command, config)

    for {filename, hostname, serial} <- [
          {"cert.pem", "localhost", "1"},
          {"wrong-cert.pem", "other.invalid", "2"}
        ] do
      extensions = Path.join(directory, "#{filename}.ext")

      File.write!(
        extensions,
        "basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\nsubjectAltName=DNS:#{hostname}\n"
      )

      openssl(
        [
          "x509",
          "-req",
          "-in",
          request_file,
          "-CA",
          ca_file,
          "-CAkey",
          ca_key,
          "-set_serial",
          serial,
          "-days",
          "2",
          "-sha256",
          "-extfile",
          extensions,
          "-out",
          Path.join(directory, filename)
        ],
        config
      )

      openssl(
        [
          "verify",
          "-purpose",
          "sslserver",
          "-verify_hostname",
          hostname,
          "-CAfile",
          ca_file,
          Path.join(directory, filename)
        ],
        config
      )
    end

    File.rm!(ca_key)
  end

  defp openssl(arguments, config) do
    {log, status} =
      System.cmd(System.get_env("OPENSSL_BIN", "openssl"), arguments,
        env: [{"OPENSSL_CONF", config}],
        stderr_to_stdout: true
      )

    assert status == 0, log
  end

  defp accept_loop(protocol, listener, parent, workers) do
    case accept(protocol, listener, @timeout) do
      {:ok, socket} ->
        peer = self()

        {worker, monitor} =
          spawn_monitor(fn ->
            receive do
              :ready ->
                result =
                  try do
                    accepted =
                      if protocol == :tls,
                        do: :ssl.handshake(socket, @timeout),
                        else: {:ok, socket}

                    assert {:ok, connected} = accepted

                    if protocol == :tls do
                      assert {:ok, info} = :ssl.connection_information(connected, [:sni_hostname])

                      assert {:error, :protocol_not_negotiated} =
                               :ssl.negotiated_protocol(connected)

                      send(parent, {:peer_tls, peer, self(), to_string(info[:sni_hostname]), nil})
                    end

                    serve(wire(protocol), connected, parent, peer)
                    :ok
                  rescue
                    error -> {:error, Exception.format(:error, error, __STACKTRACE__)}
                  after
                    wire(protocol).close(socket)
                  end

                send(peer, {:worker_finished, self(), result})
            after
              @timeout -> raise "peer ownership barrier expired"
            end
          end)

        :ok = wire(protocol).controlling_process(socket, worker)
        send(parent, {:peer_accepted, peer, worker})
        send(worker, :ready)
        accept_loop(protocol, listener, parent, [{worker, monitor} | workers])

      {:error, :timeout} ->
        accept_loop(protocol, listener, parent, workers)

      {:error, :closed} ->
        results =
          for {worker, monitor} <- workers do
            assert_receive {:worker_finished, ^worker, result}, @timeout
            assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, @timeout
            result
          end

        send(parent, {:peer_joined, self(), Enum.find(results, :ok, &(&1 != :ok))})
    end
  end

  defp serve(transport, socket, parent, peer) do
    receive do
      {:close_peer, caller} ->
        :ok = transport.close(socket)
        send(caller, {:peer_closed, self()})
        :ok

      {:send_chunk, bytes, caller} ->
        :ok = transport.send(socket, bytes)
        send(caller, {:peer_chunk_sent, self()})
        serve(transport, socket, parent, peer)
    after
      0 -> serve_wire(transport, socket, parent, peer)
    end
  end

  defp serve_wire(transport, socket, parent, peer) do
    case transport.recv(socket, 1, 50) do
      {:error, reason} when reason in [:closed, :enotconn] ->
        :ok

      {:error, :timeout} ->
        serve(transport, socket, parent, peer)

      {:ok, first} ->
        upstream = head(transport, socket, first)

        if String.starts_with?(upstream, "HEAD ") do
          send(parent, {:peer_head, peer, self(), upstream})
          :ok = transport.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
        else
          send(parent, {:peer_request, peer, self(), upstream})

          if String.starts_with?(upstream, "POST ") and
               not String.starts_with?(upstream, "POST /early ") do
            receive do
              {:check_upload, caller} ->
                send(caller, {:upload_not_ready, self(), transport.recv(socket, 1, 0)})
            after
              @timeout -> flunk("upload readiness barrier expired")
            end

            assert {:ok, body} = transport.recv(socket, 3, @timeout)
            send(parent, {:upload_body, self(), body})
          end

          if String.starts_with?(upstream, "DELETE /trailers "),
            do: send(parent, {:peer_upload, self(), chunks(transport, socket)})

          receive do
            {:respond, response} ->
              :ok = transport.send(socket, response)

            {:await_eof, caller} ->
              assert {:error, :closed} = transport.recv(socket, 0, @timeout)
              send(caller, {:peer_eof, self()})
          after
            @timeout -> flunk("managed group response barrier expired")
          end
        end

        serve(transport, socket, parent, peer)
    end
  end

  defp call_barrier(owner, operation) do
    parent = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      case event do
        {:in, {:"$gen_call", {caller, _}, message}}
        when not held and is_tuple(message) and elem(message, 0) == operation ->
          send(parent, {:owner_call_held, self(), caller, message})

          receive do
            {:continue_owner_call, ^barrier} -> :ok
          after
            @timeout -> raise "managed group owner barrier expired"
          end

          true

        _ ->
          held
      end
    end

    :ok = :sys.install(owner, {debug, false})
    on_exit(fn -> send(owner, {:continue_owner_call, barrier}) end)
    barrier
  end

  defp connect(instance, id \\ :http) do
    {:ok, {ip, port}} = Gaoxy.info(instance, id).local
    assert {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)
    socket
  end

  defp request(method, target, fields \\ []),
    do: [
      "#{method} #{target} HTTP/1.1\r\nHost: downstream.test\r\n",
      Enum.map(fields, fn {name, value} -> [name, ": ", value, "\r\n"] end),
      "\r\n"
    ]

  defp head(transport, socket, bytes \\ "") do
    assert byte_size(bytes) <= 65_536

    if String.ends_with?(bytes, "\r\n\r\n") do
      bytes
    else
      assert {:ok, byte} = transport.recv(socket, 1, @timeout)
      head(transport, socket, bytes <> byte)
    end
  end

  defp ca(directory),
    do:
      for(
        {:Certificate, der, :not_encrypted} <-
          :public_key.pem_decode(File.read!(Path.join(directory, "ca.pem"))),
        do: der
      )

  defp line(transport, socket, bytes \\ "") do
    assert byte_size(bytes) <= 65_536
    assert {:ok, byte} = transport.recv(socket, 1, @timeout)
    next = bytes <> byte
    if String.ends_with?(next, "\r\n"), do: next, else: line(transport, socket, next)
  end

  defp chunks(transport, socket, bytes \\ "") do
    size = transport |> line(socket) |> String.trim() |> String.to_integer(16)
    assert size in 0..65_536

    if size == 0 do
      {bytes, trailers(transport, socket)}
    else
      assert {:ok, chunk} = transport.recv(socket, size, @timeout)
      assert {:ok, "\r\n"} = transport.recv(socket, 2, @timeout)
      chunks(transport, socket, bytes <> chunk)
    end
  end

  defp trailers(transport, socket, fields \\ []) do
    case line(transport, socket) do
      "\r\n" ->
        Enum.reverse(fields)

      field ->
        [name, value] = String.split(String.trim_trailing(field, "\r\n"), ":", parts: 2)
        trailers(transport, socket, [{String.downcase(name), String.trim(value)} | fields])
    end
  end

  defp wire(:tcp), do: :gen_tcp
  defp wire(:tls), do: :ssl
  defp accept(:tcp, listener, timeout), do: :gen_tcp.accept(listener, timeout)
  defp accept(:tls, listener, timeout), do: :ssl.transport_accept(listener, timeout)
  defp deadline, do: Lifecycle.deadline(@timeout)

  defp eventually(fun, d \\ nil, diagnostic \\ nil) do
    d = d || deadline()

    if fun.() do
      :ok
    else
      assert Lifecycle.remaining(d) > 0,
             if(Lifecycle.remaining(d) == 0 and diagnostic,
               do: diagnostic.(),
               else: "managed group accounting did not settle"
             )

      receive do
      after
        2 -> eventually(fun, d, diagnostic)
      end
    end
  end
end
