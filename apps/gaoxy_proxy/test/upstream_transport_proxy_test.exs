defmodule Gaoxy.Proxy.UpstreamTransportProxyTest do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Proxy.HTTP, as: ProxyHTTP
  alias Gaoxy.Proxy.HTTP.Session
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports
  alias Gaoxy.Proxy.UpstreamGroups

  @moduletag :capture_log
  @timeout 5_000

  defmodule InvalidOpenEndpoint do
    @behaviour Gaoxy.HTTP.Endpoint
    def init(options), do: ProxyHTTP.init(options)
    def resources(config), do: apply(ProxyHTTP, :resources, [config])

    def call(exchange, config) do
      request = %{exchange.request | path: "/invalid%XX"}
      ProxyHTTP.call(%{exchange | request: request}, config)
    end
  end

  setup_all do
    directory =
      Path.join(System.tmp_dir!(), "gaoxy-managed-endpoint-#{System.unique_integer([:positive])}")

    script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
    on_exit(fn -> File.rm_rf!(directory) end)

    for name <- ["trusted", "untrusted"] do
      {log, status} =
        System.cmd("bash", [script, Path.join(directory, name)], stderr_to_stdout: true)

      assert status == 0, log
    end

    {:ok, trusted: Path.join(directory, "trusted"), untrusted: Path.join(directory, "untrusted")}
  end

  test "managed init is pure for an unreachable owner and declares the exact handle" do
    owner =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    on_exit(fn -> send(owner, :stop) end)
    handle = %{provider: Transports, owner: owner, owner_epoch: make_ref(), resource: make_ref()}

    assert {:ok, config} =
             ProxyHTTP.init(%{upstream: "https://unresolved.invalid", transport: handle})

    assert config.transport == handle
    assert [^handle] = apply(ProxyHTTP, :resources, [config])
    assert {:ok, ^config} = ProxyHTTP.init(config)
    assert {:message_queue_len, 0} = Process.info(owner, :message_queue_len)
    assert {:ok, dedicated} = ProxyHTTP.init(%{upstream: "http://localhost"})
    assert dedicated.transport == nil
    assert [] = apply(ProxyHTTP, :resources, [dedicated])
  end

  test "managed init rejects expanded handles, overrides, raw options and non-H1 protocols" do
    handle = %{provider: Transports, owner: self(), owner_epoch: make_ref(), resource: make_ref()}
    assert {:ok, _} = ProxyHTTP.init(%{upstream: "http://example.test", transport: handle})
    backing = "http://" <> String.duplicate("a", 100) <> String.duplicate("x", 65_537)
    retained_origin = binary_part(backing, 0, 107)
    assert :binary.referenced_byte_size(retained_origin) > 65_536

    assert {:error, :invalid_http_proxy_options} =
             ProxyHTTP.init(%{upstream: retained_origin, transport: handle})

    for change <- [
          %{transport: Map.put(handle, :policy, %{})},
          %{transport: Map.delete(handle, :resource)},
          %{transport: %{handle | owner: :not_a_pid}},
          %{transport: %{handle | provider: __MODULE__}},
          %{transport: %{handle | owner_epoch: 1}},
          %{transport: %{handle | resource: 1}},
          %{upstream_protocol: :http2},
          %{upstream_protocol: :http3},
          %{cacertfile: "/does/not/exist"},
          %{connect_address: {127, 0, 0, 1}},
          %{ssl: []},
          %{transport_scope: make_ref()},
          %{http1_reuse: true},
          %{upstream: "http://user:pass@example.test"},
          %{upstream: "http://example.test/path"},
          %{upstream: "http://example.test?"},
          %{upstream: "http://example.test#fragment"},
          %{upstream: "http://bad host"},
          %{upstream: "http://example.test:abc"},
          %{upstream: "http://example.test:"},
          %{upstream: "http://example.test:80extra"},
          %{upstream: "http://example.test/%XX"},
          %{upstream: "http://" <> String.duplicate("a", 65_537)},
          %{idle_timeout: :infinity},
          %{max_chunk_bytes: 65_537}
        ] do
      assert {:error, :invalid_http_proxy_options} =
               ProxyHTTP.init(
                 Map.merge(%{upstream: "http://example.test", transport: handle}, change)
               )
    end
  end

  test "group compilation rejects a raw managed member instead of activating it" do
    handle = %{provider: Transports, owner: self(), owner_epoch: make_ref(), resource: make_ref()}

    assert {:error, :invalid_upstream_group} =
             UpstreamGroups.compile(%{
               id: "dedicated-only",
               members: [%{id: "a", upstream: "http://example.test", transport: handle}]
             })
  end

  test "group compilation rejects managed config in a compiled group instead of erasing it" do
    assert {:ok, dedicated} =
             UpstreamGroups.compile(%{
               id: "dedicated-only",
               members: [%{id: "a", upstream: "http://example.test"}]
             })

    assert {:ok, ^dedicated} = UpstreamGroups.compile(dedicated)
    handle = %{provider: Transports, owner: self(), owner_epoch: make_ref(), resource: make_ref()}
    assert {:ok, managed} = ProxyHTTP.init(%{upstream: "http://example.test", transport: handle})
    [member] = dedicated.members
    tampered = %{dedicated | members: [%{member | config: managed}]}
    assert {:error, :invalid_upstream_group} = UpstreamGroups.compile(tampered)
    assert {:ok, ^dedicated} = UpstreamGroups.compile(dedicated)
  end

  for protocol <- [:tcp, :tls] do
    @protocol protocol
    test "#{protocol} reuses exactly one connection for escaped and empty targets with raw gzip and duplicates",
         context do
      protocol = @protocol
      encoded = :zlib.gzip(<<0, "raw", 255>>)

      {source, peer, _listener} =
        peer(protocol, context, fn wire, socket, owner ->
          if wire == :ssl do
            assert {:ok, info} = :ssl.connection_information(socket, [:sni_hostname])
            assert to_string(info[:sni_hostname]) == "localhost"
            assert {:error, :protocol_not_negotiated} = :ssl.negotiated_protocol(socket)
          end

          for target <- ["/a%2Fb?q=%2F", "/empty?"] do
            upstream = head(wire, socket)
            assert upstream =~ "GET #{target} HTTP/1.1\r\n"
            assert String.downcase(upstream) =~ "x-trace: one\r\nx-trace: two\r\n"

            assert String.downcase(upstream) =~
                     "host: #{URI.parse(source_origin(wire, socket)).host}"

            :ok =
              wire.send(socket, [
                "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nSet-Cookie: one=1\r\nSet-Cookie: two=2\r\nContent-Length: #{byte_size(encoded)}\r\n\r\n",
                encoded
              ])

            send(owner, {:request_seen, self(), target})
          end

          assert {:error, :closed} = wire.recv(socket, 0, @timeout)
        end)

      {instance, owner, _handle} = managed(source)

      for target <- ["/a%2Fb?q=%2F", "/empty?"] do
        socket = connect(instance)

        :ok =
          :gen_tcp.send(socket, request("GET", target, [{"X-Trace", "one"}, {"X-Trace", "two"}]))

        response = head(:gen_tcp, socket)
        assert response =~ "200 OK"
        assert response =~ "content-encoding: gzip\r\n"
        assert response =~ "set-cookie: one=1\r\nset-cookie: two=2\r\n"
        assert {:ok, ^encoded} = :gen_tcp.recv(socket, byte_size(encoded), @timeout)
        assert_receive {:request_seen, ^peer, ^target}, @timeout
        :ok = :gen_tcp.close(socket)
        assert_clean(instance, owner)
      end

      stop_and_join(instance, owner, peer)
    end

    test "#{protocol} binary upload arrives before EOF and binds original completion before pumping",
         context do
      first = <<0, 255, 1>>
      last = <<2, 254, 0>>

      {source, peer, _} =
        peer(@protocol, context, fn wire, socket, owner ->
          assert head(wire, socket) =~ "POST /upload?raw=%2F HTTP/1.1\r\n"
          assert {:ok, ^first} = wire.recv(socket, 3, @timeout)
          send(owner, {:first_upload, self()})
          assert {:ok, ^last} = wire.recv(socket, 3, @timeout)
          :ok = wire.send(socket, ["HTTP/1.1 200 OK\r\nContent-Length: 6\r\n\r\n", first, last])
          assert {:error, :closed} = wire.recv(socket, 0, @timeout)
        end)

      {instance, owner, handle} = managed(source)
      socket = connect(instance)

      :ok =
        :gen_tcp.send(socket, [
          request("POST", "/upload?raw=%2F", [{"Content-Length", "6"}]),
          first
        ])

      assert_receive {:first_upload, ^peer}, @timeout
      [{token, hold}] = Map.to_list(:sys.get_state(owner).tokens)
      guardian = hold.guardian
      state = :sys.get_state(guardian)
      assert state.transport_selection == {handle, token}
      assert state.selection == nil
      assert state.token != token
      assert hold.completion == state.client.completion(state.request)
      assert match?(%HTTP.RequestCompletion{}, hold.completion)
      assert Enum.all?(state.transport_pins, &(&1.holder == guardian and &1.kind == :request))

      assert {:error, :unauthorized} =
               Transports.checkout(handle, state.transport_pins, guardian, deadline())

      outer_pins =
        for {_, pin} <- :sys.get_state(owner).pins,
            pin.public.kind == :request and pin.public.holder != guardian,
            do: pin.public

      assert [_] = outer_pins

      assert {:error, :invalid_resource_pin} =
               Transports.checkout(handle, outer_pins, self(), deadline())

      assert {:ok, %{pins: 3, request_tokens: 1}} = Transports.status(owner)
      :ok = :gen_tcp.send(socket, last)
      assert head(:gen_tcp, socket) =~ "200 OK"
      assert {:ok, bytes} = :gen_tcp.recv(socket, 6, @timeout)
      assert bytes == first <> last
      :ok = :gen_tcp.close(socket)
      assert_clean(instance, owner)
      stop_and_join(instance, owner, peer)
    end

    test "#{protocol} preserves ordered declared request and response trailers", context do
      {source, peer, _} =
        peer(@protocol, context, fn wire, socket, _owner ->
          upstream = head(wire, socket)
          assert String.downcase(upstream) =~ "transfer-encoding: chunked\r\n"
          assert String.downcase(upstream) =~ "trailer: x-trace\r\n"
          assert {<<0, 255>>, [{"x-trace", "one"}, {"x-trace", "two"}]} = chunks(wire, socket)

          :ok =
            wire.send(socket, [
              "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nTrailer: X-Trace\r\n\r\n2\r\n",
              <<255, 0>>,
              "\r\n0\r\nX-Trace: first\r\nX-Trace: last\r\n\r\n"
            ])

          assert {:error, :closed} = wire.recv(socket, 0, @timeout)
        end)

      {instance, owner, _} = managed(source)
      socket = connect(instance)

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

      assert head(:gen_tcp, socket) =~ "trailer: x-trace\r\n"
      assert {<<255, 0>>, [{"x-trace", "first"}, {"x-trace", "last"}]} = chunks(:gen_tcp, socket)
      :ok = :gen_tcp.close(socket)
      assert_clean(instance, owner)
      stop_and_join(instance, owner, peer)
    end

    test "#{protocol} returns redirects without following and an early final without upload EOF",
         context do
      {source, peer, _} =
        peer(@protocol, context, fn wire, socket, _owner ->
          assert head(wire, socket) =~ "GET /redirect HTTP/1.1\r\n"

          :ok =
            wire.send(
              socket,
              "HTTP/1.1 302 Found\r\nLocation: http://127.0.0.1:1/do-not-follow\r\nContent-Length: 0\r\n\r\n"
            )

          assert head(wire, socket) =~ "POST /early HTTP/1.1\r\n"
          :ok = wire.send(socket, "HTTP/1.1 413 Payload Too Large\r\nContent-Length: 2\r\n\r\nno")
          assert {:error, :closed} = wire.recv(socket, 0, @timeout)
        end)

      {instance, owner, _} = managed(source)
      socket = connect(instance)
      :ok = :gen_tcp.send(socket, request("GET", "/redirect"))
      response = head(:gen_tcp, socket)
      assert response =~ "302 Found"
      assert response =~ "location: http://127.0.0.1:1/do-not-follow\r\n"
      :ok = :gen_tcp.close(socket)
      assert_clean(instance, owner)
      socket = connect(instance)
      :ok = :gen_tcp.send(socket, request("POST", "/early", [{"Content-Length", "1000000"}]))
      response = head(:gen_tcp, socket)
      assert response =~ "413 "
      assert response =~ "connection: close\r\n"
      assert {:ok, "no"} = :gen_tcp.recv(socket, 2, @timeout)
      assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      :ok = :gen_tcp.close(socket)
      assert_clean(instance, owner)
      stop_and_join(instance, owner, peer)
    end
  end

  for reason <- [:wrong_ca, :wrong_host] do
    @reason reason
    test "TLS #{@reason} rejects without plaintext fallback or replay", context do
      hostname = if @reason == :wrong_host, do: "127.0.0.2", else: "localhost"

      {source, peer, _} =
        peer(:tls, context, fn _, _, _ -> flunk("unverified TLS request opened") end, hostname)

      source = if @reason == :wrong_ca, do: %{source | trust: ca(context.untrusted)}, else: source
      {instance, owner, handle} = managed(source)
      {:ok, service, _} = GenServer.call(instance, {:lookup, :http})
      service_barrier = service_down_barrier(service)
      owner_barrier = call_barrier(owner, :bind_completion)
      socket = connect(instance)

      :ok =
        :gen_tcp.send(
          socket,
          request("POST", "/once", [{"Content-Length", "0"}, {"Authorization", "secret"}])
        )

      assert_receive {:owner_call_held, ^owner, guardian,
                      {:bind_completion, ^handle, token, completion}},
                     @timeout

      guardian_monitor = Process.monitor(guardian)
      scope = :sys.get_state(owner).records[handle.resource].scope
      registration = :sys.get_state(owner).registration
      send(owner, {:continue_owner_call, owner_barrier})
      assert head(:gen_tcp, socket) =~ "502 Bad Gateway"
      assert_receive {:handshake_failed, ^peer, _}, @timeout
      :ok = :gen_tcp.close(socket)

      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian,
                      {:cleanup_failed, :cleanup_unconfirmed}},
                     @timeout

      assert_receive {:service_guardian_down_held, ^service, ^guardian,
                      {:cleanup_failed, :cleanup_unconfirmed}},
                     @timeout

      refute_receive {:service_completion_received, ^service, ^guardian, _}, 0
      assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, @timeout)
      assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
      assert {:error, :transport_scope_retired} = HTTP.ManagedTransport.snapshot(scope, @timeout)
      assert {:ok, scope_receipt} = HTTP.ManagedTransport.retire(scope, mode: :abort)

      assert {:error, :cleanup_unconfirmed} =
               HTTP.ManagedTransport.await_retired(scope_receipt, @timeout)

      assert {:error, :cleanup_unconfirmed} =
               HTTP.ManagedTransport.await_retired(scope_receipt, 0)

      eventually(fn ->
        match?(
          {:ok, %{resources: 1, pins: 1, request_tokens: 1, reserved_connections: 2, helpers: 0}},
          Transports.status(owner)
        )
      end)

      assert Process.alive?(:sys.get_state(instance).parent)
      hold = :sys.get_state(owner).tokens[token]
      assert hold.completion == completion
      assert hold.guardian_down
      assert hold.abort_helper == nil
      assert_peer(peer)
      expect_cleanup(instance, :tls_unconfirmed)
      observe_tls_retirement_phases(owner, handle)

      assert {:error,
              {:shutdown, [{:http, {:error, {:cleanup_failed, :cleanup_receipt_missing}}}],
               [{^registration, {:error, :cleanup_unconfirmed}}]}} =
               stop_after_service_down(instance, service, service_barrier)

      # Observe both authenticated helper lifetimes and the genuine failure
      # before instance death escalates graceful retirement to its abort retry.
      for expected <- [
            :custodian_retiring,
            :custodian_helper_started,
            :custodian_helper_finished,
            :custodian_failed,
            :instance_down,
            :custodian_retiring,
            :custodian_helper_started,
            :custodian_helper_finished
          ] do
        assert_receive {:tls_owner_phase, ^owner, event}, @timeout
        assert event == expected
      end

      eventually(fn ->
        match?(
          {:ok,
           %{
             resources: 1,
             pins: 0,
             request_tokens: 1,
             reserved_connections: 2,
             failed_resources: 1,
             helpers: 0
           }},
          Transports.status(owner)
        )
      end)

      record = :sys.get_state(owner).records[handle.resource]
      assert record.lifecycle == :failed
      assert record.transport_confirmed == false
      custodian = :sys.get_state(record.custodian)
      assert custodian.failed
      assert custodian.confirmed == false
      assert custodian.control_calls == 2
      assert custodian.initial_mode == :graceful
      assert custodian.mode == :abort
      assert custodian.retire_helper == nil
      assert custodian.retry_helper == nil
      refute_receive {:tls_owner_phase, ^owner, :custodian_retired}, 0

      assert {:ok, receipt} = Transports.retire(owner, deadline())
      assert {:error, :cleanup_unconfirmed} = Transports.await_retirement(receipt, deadline())
      assert {:error, :cleanup_unconfirmed} = Transports.await_retirement(receipt, deadline())
      assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)

      assert {:error, :cleanup_unconfirmed} =
               HTTP.ManagedTransport.await_retired(scope_receipt, 0)
    end
  end

  test "Session init and cancellation before activation allocate no guardian pin, token or Fetch" do
    {source, _peer, listener} =
      peer(:tcp, %{}, fn _, _, _ -> flunk("unactivated Session opened Fetch") end)

    {instance, owner, handle} = managed(source)
    {:ok, config} = ProxyHTTP.init(%{upstream: source.origin, transport: handle})
    {:ok, session} = Session.start_link(session_args(instance, config))
    Process.unlink(session)
    monitor = Process.monitor(session)
    assert :sys.get_state(session).request == nil
    assert {:ok, %{pins: 1, request_tokens: 0}} = Transports.status(owner)
    assert {:error, :timeout} = :gen_tcp.accept(listener, 0)
    expired_args = %{session_args(instance, config) | deadline: Gaoxy.Lifecycle.now() - 1}
    {:ok, expired} = Session.start_link(expired_args)
    Process.unlink(expired)
    expired_monitor = Process.monitor(expired)
    Session.expire(expired)
    assert_receive {:DOWN, ^expired_monitor, :process, ^expired, :normal}, @timeout
    assert {:ok, %{pins: 1, request_tokens: 0}} = Transports.status(owner)
    assert {:error, :timeout} = :gen_tcp.accept(listener, 0)
    Session.cancel(session)
    assert_receive {:DOWN, ^monitor, :process, ^session, :normal}, @timeout
    assert {:ok, %{pins: 1, request_tokens: 0}} = Transports.status(owner)
    assert {:error, :timeout} = :gen_tcp.accept(listener, 0)
  end

  test "Service admission denial occurs before Fetch and leaves a later admitted request usable" do
    {source, peer, listener} =
      peer(:tcp, %{}, fn wire, socket, _ ->
        assert head(wire, socket) =~ "GET /valid HTTP/1.1"
        :ok = wire.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
        assert {:error, :closed} = wire.recv(socket, 0, @timeout)
      end)

    {instance, owner, handle} = managed(source, %{}, %{max_bytes: 1_048_576})
    socket = connect(instance)
    :ok = :gen_tcp.send(socket, request("GET", "/denied"))
    assert head(:gen_tcp, socket) =~ "503 Service Unavailable"
    :ok = :gen_tcp.close(socket)
    assert_clean(instance, owner)
    assert {:error, :timeout} = :gen_tcp.accept(listener, 0)
    add_service(instance, source.origin, handle, :valid, %{max_bytes: 16_777_216})
    socket = connect(instance, :valid)
    :ok = :gen_tcp.send(socket, request("GET", "/valid"))
    assert head(:gen_tcp, socket) =~ "200 OK"
    :ok = :gen_tcp.close(socket)
    assert_clean(instance, owner, true, :valid)
    stop_and_join(instance, owner, peer)
  end

  test "mismatched origin and cross-instance handles allocate no token and do not poison valid endpoint" do
    {source, peer, listener} =
      peer(:tcp, %{}, fn wire, socket, _ ->
        assert head(wire, socket) =~ "GET /valid HTTP/1.1"
        :ok = wire.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
        assert {:error, :closed} = wire.recv(socket, 0, @timeout)
      end)

    {instance, owner, handle} = managed(source, %{upstream: "http://other.invalid"})
    socket = connect(instance)
    :ok = :gen_tcp.send(socket, request("GET", "/invalid"))
    assert head(:gen_tcp, socket) =~ "502 Bad Gateway"
    :ok = :gen_tcp.close(socket)
    assert_clean(instance, owner)
    assert {:error, :timeout} = :gen_tcp.accept(listener, 0)
    {:ok, other} = Gaoxy.start_link()
    Process.unlink(other)
    on_exit(fn -> if Process.alive?(other), do: Gaoxy.stop(other, @timeout) end)
    add_service(other, source.origin, handle, :http, %{max_bytes: 16_777_216})
    socket = connect(other)
    :ok = :gen_tcp.send(socket, request("GET", "/cross-instance"))
    assert head(:gen_tcp, socket) =~ "502 Bad Gateway"
    :ok = :gen_tcp.close(socket)
    assert_clean(other, owner)
    assert {:error, :timeout} = :gen_tcp.accept(listener, 0)
    assert :ok = Gaoxy.stop(other, @timeout)
    add_service(instance, source.origin, handle, :valid, %{max_bytes: 16_777_216})
    socket = connect(instance, :valid)
    :ok = :gen_tcp.send(socket, request("GET", "/valid"))
    assert head(:gen_tcp, socket) =~ "200 OK"
    :ok = :gen_tcp.close(socket)
    assert_clean(instance, owner, true, :valid)
    stop_and_join(instance, owner, peer)
  end

  test "native owner death before headers aborts and joins the original managed request" do
    {source, peer, _} =
      peer(:tcp, %{}, fn wire, upstream, test_owner ->
        assert head(wire, upstream) =~ "GET /before-headers HTTP/1.1\r\n"
        send(test_owner, {:before_headers_request, self()})
        # This real peer never sends response headers. Only public request
        # cancellation can close its already-open request connection.
        assert {:error, :closed} = wire.recv(upstream, 0, @timeout)
        send(test_owner, {:before_headers_eof, self()})
      end)

    {instance, owner, handle} = managed(source)
    barrier = call_barrier(owner, :bind_completion)
    socket = connect(instance)
    :ok = :gen_tcp.send(socket, request("GET", "/before-headers"))

    assert_receive {:owner_call_held, ^owner, guardian,
                    {:bind_completion, ^handle, token, completion}},
                   @timeout

    assert match?(%HTTP.RequestCompletion{}, completion)
    assert_receive {:before_headers_request, ^peer}, @timeout
    send(owner, {:continue_owner_call, barrier})

    state = :sys.get_state(guardian)
    native = state.owner
    assert native != owner
    assert native != guardian
    assert state.headers == false
    assert state.transport_selection == {handle, token}
    assert state.client.completion(state.original_request) == completion
    hold = :sys.get_state(owner).tokens[token]
    assert hold.guardian == guardian
    assert hold.completion == completion
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)

    assert {:ok, %{resources: 1, request_tokens: 1, pins: 3, helpers: 0, reserved_connections: 2}} =
             Transports.status(owner)

    assert %{active: 1, cleanup_pending: 1, cleanup_failed: nil} = Gaoxy.status(instance, :http)
    assert {:error, :timeout} = :gen_tcp.recv(socket, 1, 0)
    native_monitor = Process.monitor(native)
    guardian_monitor = Process.monitor(guardian)
    peer_monitor = Process.monitor(peer)

    Process.exit(native, :kill)
    assert_receive {:DOWN, ^native_monitor, :process, ^native, :killed}, @timeout
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
    assert :ok = HTTP.RequestCompletion.await(completion, 0)
    assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
    assert_receive {:before_headers_eof, ^peer}, @timeout
    :ok = :gen_tcp.close(socket)
    assert_clean(instance, owner)
    assert_peer(peer)
    assert_receive {:DOWN, ^peer_monitor, :process, ^peer, :normal}, @timeout

    owner_monitor = Process.monitor(owner)
    instance_monitor = Process.monitor(instance)
    assert :ok = Gaoxy.stop(instance, @timeout)
    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :normal}, @timeout
    assert_receive {:DOWN, ^instance_monitor, :process, ^instance, :normal}, @timeout
  end

  for action <- [:disconnect, :owner_death, :guardian_death, :stop] do
    @action action
    test "#{action} joins a held request and original cleanup without refunding pending ownership" do
      {source, peer, _} =
        peer(:tcp, %{}, fn wire, socket, test_owner ->
          _ = head(wire, socket)
          :ok = wire.send(socket, "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n")
          send(test_owner, {:held_response, self()})
          assert {:error, :closed} = wire.recv(socket, 0, @timeout)
        end)

      {instance, owner, _} = managed(source)

      service_barrier =
        if @action == :guardian_death do
          {:ok, service, _} = GenServer.call(instance, {:lookup, :http})
          {service, service_down_barrier(service)}
        end

      socket = connect(instance)
      :ok = :gen_tcp.send(socket, request("GET", "/held"))
      assert head(:gen_tcp, socket) =~ "200 OK"
      assert_receive {:held_response, ^peer}, @timeout
      [{_, hold}] = Map.to_list(:sys.get_state(owner).tokens)
      guardian = hold.guardian
      state = :sys.get_state(guardian)
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(hold.completion, 0)
      assert {:ok, %{request_tokens: 1, pins: 3}} = Transports.status(owner)
      assert %{cleanup_pending: 1} = Gaoxy.status(instance, :http)
      guardian_monitor = Process.monitor(guardian)

      if @action == :disconnect do
        Session.consumed(guardian)
        eventually(fn -> :sys.get_state(guardian).consumed end)
        assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(hold.completion, 0)
        assert {:ok, %{request_tokens: 1, pins: 3}} = Transports.status(owner)
        assert %{cleanup_pending: 1} = Gaoxy.status(instance, :http)
      end

      case @action do
        :disconnect -> :gen_tcp.close(socket)
        :owner_death -> Process.exit(state.owner, :kill)
        :guardian_death -> Process.exit(guardian, :kill)
        :stop -> assert :ok = Gaoxy.stop(instance, @timeout)
      end

      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, _}, @timeout
      assert :ok = HTTP.RequestCompletion.await(hold.completion, @timeout)

      if @action == :guardian_death do
        {service, barrier} = service_barrier
        assert_receive {:service_guardian_down_held, ^service, ^guardian, :killed}, @timeout
        refute_receive {:service_completion_received, ^service, ^guardian, _}, 0

        eventually(fn ->
          match?({:ok, %{request_tokens: 0, pins: 1}}, Transports.status(owner))
        end)

        assert {:error,
                {:shutdown, [{:http, {:error, {:cleanup_failed, :cleanup_receipt_missing}}}], []}} =
                 stop_after_service_down(instance, service, barrier)
      else
        if @action != :stop do
          :ok = :gen_tcp.close(socket)
          assert_clean(instance, owner, false)
          assert :ok = Gaoxy.stop(instance, @timeout)
        end
      end

      assert_peer(peer)
    end
  end

  test "original completion binding precedes ready and upload bytes" do
    {source, peer, _} =
      peer(:tcp, %{}, fn wire, socket, test_owner ->
        _ = head(wire, socket)
        assert {:error, :timeout} = wire.recv(socket, 1, 0)
        send(test_owner, {:upload_waiting, self()})
        assert {:ok, "abc"} = wire.recv(socket, 3, @timeout)

        receive do
          :respond -> :ok
        after
          @timeout -> flunk("response barrier timed out")
        end

        :ok = wire.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
        assert {:error, :closed} = wire.recv(socket, 0, @timeout)
      end)

    {instance, owner, handle} = managed(source)
    barrier = call_barrier(owner, :bind_completion)
    socket = connect(instance)
    :ok = :gen_tcp.send(socket, [request("POST", "/bound", [{"Content-Length", "3"}]), "abc"])

    assert_receive {:owner_call_held, ^owner, guardian,
                    {:bind_completion, ^handle, token, completion}},
                   @timeout

    assert match?(%HTTP.RequestCompletion{}, completion)
    :erlang.trace(guardian, true, [:send])
    refute_receive {:trace, ^guardian, :send, {:gaoxy_proxy_http, _, {:ready, _, _, _}}, _}, 0
    assert_receive {:upload_waiting, ^peer}, @timeout
    send(owner, {:continue_owner_call, barrier})

    assert_receive {:trace, ^guardian, :send, {:gaoxy_proxy_http, ^guardian, {:ready, _, _, _}},
                    _},
                   @timeout

    state = :sys.get_state(guardian)
    assert state.transport_selection == {handle, token}
    assert state.client.completion(state.request) == completion
    send(peer, :respond)
    assert head(:gen_tcp, socket) =~ "200 OK"
    :ok = :gen_tcp.close(socket)
    assert_clean(instance, owner)
    stop_and_join(instance, owner, peer)
  end

  test "retirement queued after validation rejects checkout before Fetch" do
    {source, _peer, listener} =
      peer(:tcp, %{}, fn _, _, _ -> flunk("retirement race opened Fetch") end)

    {instance, owner, _} = managed(source)
    barrier = call_barrier(owner, :validate_endpoint)
    socket = connect(instance)
    :ok = :gen_tcp.send(socket, request("GET", "/retiring"))

    assert_receive {:owner_call_held, ^owner, _guardian, {:validate_endpoint, _, _, _, _}},
                   @timeout

    test_owner = self()

    caller =
      spawn(fn ->
        receive do
          :retire ->
            send(test_owner, {:retirement_result, self(), Transports.retire(owner, deadline())})
        end
      end)

    caller_monitor = Process.monitor(caller)
    :erlang.trace(caller, true, [:send])
    send(caller, :retire)

    assert_receive {:trace, ^caller, :send, {:"$gen_call", _, {:retire_owner, _}}, ^owner},
                   @timeout

    send(owner, {:continue_owner_call, barrier})
    assert_receive {:retirement_result, ^caller, {:ok, receipt}}, @timeout
    assert_receive {:DOWN, ^caller_monitor, :process, ^caller, :normal}, @timeout
    response = head(:gen_tcp, socket)
    assert response =~ "502 Bad Gateway" or response =~ "503 Service Unavailable"
    assert :ok = Transports.await_retirement(receipt, deadline())
    assert {:ok, %{request_tokens: 0, pins: 0, resources: 0}} = Transports.status(owner)
    assert {:error, :timeout} = :gen_tcp.accept(listener, 0)
    assert :ok = Gaoxy.stop(instance, @timeout)
  end

  test "bounded stop aborts an outstanding response ACK and joins the original completion" do
    {source, peer, _} =
      peer(:tcp, %{}, fn wire, socket, test_owner ->
        _ = head(wire, socket)
        :ok = wire.send(socket, "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n")
        send(test_owner, {:response_head_sent, self()})

        receive do
          :chunk -> :ok
        after
          @timeout -> flunk("chunk barrier timed out")
        end

        :ok = wire.send(socket, "4\r\nbody\r\n")
        assert {:error, :closed} = wire.recv(socket, 0, @timeout)
      end)

    {instance, owner, _} = managed(source)
    socket = connect(instance)
    :ok = :gen_tcp.send(socket, request("GET", "/ack"))
    assert head(:gen_tcp, socket) =~ "200 OK"
    assert_receive {:response_head_sent, ^peer}, @timeout
    [{_, hold}] = Map.to_list(:sys.get_state(owner).tokens)
    guardian = hold.guardian
    native = :sys.get_state(guardian).owner
    guardian_monitor = Process.monitor(guardian)
    instance_monitor = Process.monitor(instance)
    assert :erlang.suspend_process(native)

    try do
      send(peer, :chunk)
      eventually(fn -> :sys.get_state(guardian).delivery != nil end)
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(hold.completion, 0)
      assert {:ok, %{request_tokens: 1, pins: 3}} = Transports.status(owner)
      assert {:error, {:deadline_exceeded, :cleanup_pending}} = Gaoxy.stop(instance, 0)
      assert :ok = HTTP.RequestCompletion.await(hold.completion, @timeout)
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
      assert_receive {:DOWN, ^instance_monitor, :process, ^instance, :normal}, @timeout
      assert_peer(peer)
    after
      if Process.alive?(native), do: :erlang.resume_process(native)
    end
  end

  test "expanded and stale runtime handles cannot allocate tokens or poison a later valid request" do
    {source, peer, listener} =
      peer(:tcp, %{}, fn wire, socket, _ ->
        assert head(wire, socket) =~ "GET /valid HTTP/1.1"
        :ok = wire.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
        assert {:error, :closed} = wire.recv(socket, 0, @timeout)
      end)

    {instance, owner, handle} = managed(source)

    assert {:error, :invalid_http_proxy_options} =
             ProxyHTTP.init(%{upstream: source.origin, transport: Map.put(handle, :extra, true)})

    for {id, stale} <- [
          {:stale_epoch, %{handle | owner_epoch: make_ref()}},
          {:stale_resource, %{handle | resource: make_ref()}}
        ] do
      add_service(instance, source.origin, stale, id, %{max_bytes: 16_777_216})
      socket = connect(instance, id)
      :ok = :gen_tcp.send(socket, request("GET", "/stale"))
      assert head(:gen_tcp, socket) =~ "503 Service Unavailable"
      :ok = :gen_tcp.close(socket)
      assert_clean(instance, owner, true, id)
      assert {:error, :timeout} = :gen_tcp.accept(listener, 0)
    end

    socket = connect(instance)
    :ok = :gen_tcp.send(socket, request("GET", "/valid"))
    assert head(:gen_tcp, socket) =~ "200 OK"
    :ok = :gen_tcp.close(socket)
    assert_clean(instance, owner)
    stop_and_join(instance, owner, peer)
  end

  test "post-checkout preparation rejection retains an unbound token and immutable cleanup failure" do
    {source, _peer, listener} =
      peer(:tcp, %{}, fn _, _, _ -> flunk("invalid preparation opened Fetch") end)

    {instance, owner, handle} = managed(source)

    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               id: :invalid_open,
               endpoint: {InvalidOpenEndpoint, %{upstream: source.origin, transport: handle}},
               limits: %{max_bytes: 16_777_216}
             )

    assert {:ok, _} = Gaoxy.add(instance, spec)
    {:ok, service, _} = GenServer.call(instance, {:lookup, :invalid_open})
    service_barrier = service_down_barrier(service)
    socket = connect(instance, :invalid_open)
    :ok = :gen_tcp.send(socket, request("POST", "/valid", [{"Content-Length", "3"}]))
    assert head(:gen_tcp, socket) =~ "502 Bad Gateway"

    eventually(fn ->
      match?(
        {:ok, %{request_tokens: 1, reserved_connections: 0, helpers: 0, pins: 1}},
        Transports.status(owner)
      )
    end)

    assert_receive {:service_guardian_down_held, ^service, guardian,
                    {:cleanup_failed, {:transport_cleanup_failed, :cleanup_unconfirmed}}},
                   @timeout

    refute_receive {:service_completion_received, ^service, ^guardian, _}, 0
    assert Process.alive?(:sys.get_state(instance).parent)
    expect_cleanup(instance, :unconfirmed)
    [{_, hold}] = Map.to_list(:sys.get_state(owner).tokens)
    assert hold.completion == nil
    assert hold.guardian_down
    assert {:error, :timeout} = :gen_tcp.accept(listener, 0)
    registration = :sys.get_state(owner).registration

    assert {:error,
            {:shutdown, [{:invalid_open, {:error, {:cleanup_failed, :cleanup_receipt_missing}}}],
             [{^registration, {:error, :cleanup_unconfirmed}}]}} =
             stop_after_service_down(instance, service, service_barrier)

    assert {:ok, %{request_tokens: 1, resources: 1, reserved_connections: 0, pins: 0}} =
             Transports.status(owner)
  end

  test "owner death at original bind aborts usable public completion and cannot claim Service cleanup" do
    {source, peer, _} =
      peer(:tcp, %{}, fn wire, socket, test_owner ->
        _ = head(wire, socket)
        send(test_owner, {:unbound_request_seen, self()})
        assert {:error, :closed} = wire.recv(socket, 0, @timeout)
      end)

    {instance, owner, handle} = managed(source)
    barrier = call_barrier(owner, :bind_completion)
    {:ok, service, _} = GenServer.call(instance, {:lookup, :http})
    service_barrier = service_down_barrier(service)
    socket = connect(instance)
    :ok = :gen_tcp.send(socket, request("GET", "/bind-failure"))

    assert_receive {:owner_call_held, ^owner, guardian,
                    {:bind_completion, ^handle, _, completion}},
                   @timeout

    assert_receive {:unbound_request_seen, ^peer}, @timeout
    guardian_monitor = Process.monitor(guardian)
    registration = :sys.get_state(instance).participants |> Map.keys() |> List.first()
    owner_monitor = Process.monitor(owner)
    expect_cleanup(instance, :failed_owner)
    Process.exit(owner, :kill)
    send(owner, {:continue_owner_call, barrier})
    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :killed}, @timeout

    assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian,
                    {:cleanup_failed, {:transport_cleanup_failed, :not_running}}},
                   @timeout

    assert_receive {:service_guardian_down_held, ^service, ^guardian,
                    {:cleanup_failed, {:transport_cleanup_failed, :not_running}}},
                   @timeout

    refute_receive {:service_completion_received, ^service, ^guardian, _}, 0
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
    assert_peer(peer)

    assert {:error,
            {:shutdown, [{:http, {:error, {:cleanup_failed, :cleanup_receipt_missing}}}],
             [{^registration, {:error, :cleanup_unconfirmed}}]}} =
             stop_after_service_down(instance, service, service_barrier)
  end

  defp observe_tls_retirement_phases(owner, handle) do
    test_owner = self()
    resource = handle.resource
    instance_monitor = :sys.get_state(owner).instance_monitor

    debug = fn state, event, _ ->
      case event do
        {:in, {kind, ^resource, _, _}}
        when kind in [:custodian_retiring, :custodian_failed, :custodian_retired] ->
          send(test_owner, {:tls_owner_phase, self(), kind})

        {:in, {kind, ^resource, _, _, _}}
        when kind in [:custodian_helper_started, :custodian_helper_finished] ->
          send(test_owner, {:tls_owner_phase, self(), kind})

        {:in, {:DOWN, ^instance_monitor, :process, _, _}} ->
          send(test_owner, {:tls_owner_phase, self(), :instance_down})

        _ ->
          :ok
      end

      state
    end

    :ok = :sys.install(owner, {debug, nil})
  end

  defp service_down_barrier(service) do
    test_owner = self()
    barrier = make_ref()

    debug = fn guardian, event, _ ->
      case event do
        {:in, {:"$gen_call", _, {:attach_cleanup, _, _, next_guardian, _, _}}} ->
          next_guardian

        {:in, {:"$gen_call", {caller, _}, {:complete_cleanup, token}}} ->
          send(test_owner, {:service_completion_received, self(), caller, token})
          guardian

        {:in, {:DOWN, _, :process, pid, reason}} when pid == guardian ->
          send(test_owner, {:service_guardian_down_held, self(), pid, reason})

          receive do
            {:continue_service_down, ^barrier} -> :ok
          after
            @timeout -> raise "test-owned Service DOWN barrier timed out"
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
    test_owner = self()

    caller =
      spawn(fn -> send(test_owner, {:stop_result, self(), Gaoxy.stop(instance, @timeout)}) end)

    monitor = Process.monitor(caller)

    # The guardian DOWN is held inside Gaoxy's own Service. Queue the public
    # stop coordinator's drain before releasing it, so its waiter observes the
    # missing-receipt failure before finish_drain removes the service spec.
    eventually(fn ->
      {:messages, messages} = Process.info(service, :messages)
      Enum.any?(messages, &match?({:"$gen_call", _, {:drain, _, _}}, &1))
    end)

    send(service, {:continue_service_down, barrier})
    assert_receive {:stop_result, ^caller, result}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^caller, :normal}, @timeout
    result
  end

  defp call_barrier(owner, operation) do
    test_owner = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      case event do
        {:in, {:"$gen_call", {caller, _}, message}}
        when not held and elem(message, 0) == operation ->
          send(test_owner, {:owner_call_held, self(), caller, message})

          receive do
            {:continue_owner_call, ^barrier} -> :ok
          after
            2_000 -> raise "test-owned owner call barrier timed out"
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

  defp session_args(instance, config) do
    %{
      owner: self(),
      service: self(),
      instance: instance,
      gate: self(),
      started_at: Gaoxy.Lifecycle.now(),
      deadline: deadline(),
      config: config,
      selector: {:fixed, config},
      request_options: %{
        method: :get,
        headers: [],
        body: :none,
        path: "/",
        query: nil,
        limits: %{},
        max_upload_bytes: 65_536
      }
    }
  end

  defp managed(source, endpoint_options \\ %{}, service_limits \\ %{max_bytes: 16_777_216}) do
    test_owner = self()

    embedding =
      spawn(fn ->
        {:ok, instance} = Gaoxy.start_link()
        Process.unlink(instance)

        {:ok, owner} =
          Transports.start_link(
            instance: instance,
            limits: %{
              max_resources: 2,
              max_pins: 16,
              max_request_tokens: 64,
              max_owned_payload_bytes: 2_097_152
            }
          )

        Process.unlink(owner)
        send(test_owner, {:embedding_ready, self(), instance, owner})
        embedding_loop(instance, owner, [], :ok)
      end)

    assert_receive {:embedding_ready, ^embedding, instance, owner}, @timeout

    on_exit(fn ->
      monitor = Process.monitor(embedding)
      send(embedding, {:cleanup, self()})
      assert_receive {:embedding_cleanup, ^embedding, result}, 2 * @timeout + 1000
      assert result == :ok, inspect(result)
      assert_receive {:DOWN, ^monitor, :process, ^embedding, :normal}, @timeout
    end)

    assert {:ok, handle, preparation} = Transports.prepare(owner, source, self(), deadline())
    assert {:ok, _baseline} = Resources.pin_many([handle], embedding, :baseline, deadline())
    assert :ok = Resources.release(preparation)
    creator = :sys.get_state(owner).records[handle.resource].custodian
    send(embedding, {:track, creator, self()})
    assert_receive {:tracking, ^embedding, ^creator}, @timeout
    add_service(instance, source.origin, handle, :http, service_limits, endpoint_options)
    {instance, owner, handle}
  end

  defp embedding_loop(instance, owner, monitors, cleanup) do
    receive do
      {:expect_cleanup, mode, caller} ->
        send(caller, {:cleanup_expected, self(), mode})
        embedding_loop(instance, owner, monitors, mode)

      {:track, actor, caller} ->
        monitor = Process.monitor(actor)
        send(caller, {:tracking, self(), actor})
        embedding_loop(instance, owner, [{actor, monitor} | monitors], cleanup)

      {:cleanup, caller} ->
        result =
          try do
            if cleanup == :ok do
              if Process.alive?(instance), do: assert(:ok == Gaoxy.stop(instance, @timeout))

              if Process.alive?(owner) do
                assert {:ok, receipt} = Transports.retire(owner, deadline())
                assert :ok = Transports.await_retirement(receipt, deadline())

                assert {:ok,
                        %{
                          resources: 0,
                          request_tokens: 0,
                          helpers: 0,
                          pins: 0,
                          reserved_connections: 0
                        }} = Transports.status(owner)

                GenServer.stop(owner)
              end
            else
              if Process.alive?(owner) do
                assert cleanup in [:unconfirmed, :tls_unconfirmed]
                assert {:ok, receipt} = Transports.retire(owner, deadline())

                assert {:error, :cleanup_unconfirmed} =
                         Transports.await_retirement(receipt, deadline())

                assert {:error, :cleanup_unconfirmed} =
                         Transports.await_retirement(receipt, deadline())

                if cleanup == :tls_unconfirmed do
                  assert {:ok,
                          %{
                            resources: 1,
                            request_tokens: 1,
                            reserved_connections: 2,
                            failed_resources: 1,
                            helpers: 0,
                            pins: 0
                          }} =
                           Transports.status(owner)

                  # The ledger and public uncertainty remain above. Only these
                  # test-owned failed actors are dismantled; this does not
                  # establish transport retirement or refund physical capacity.
                  for {actor, _monitor} <- monitors do
                    assert Process.alive?(actor)
                    GenServer.stop(actor, :normal, @timeout)
                  end
                else
                  assert {:ok, %{request_tokens: 1, reserved_connections: 0, helpers: 0, pins: 0}} =
                           Transports.status(owner)
                end

                GenServer.stop(owner)
              end

              # Expected uncertain accounting is asserted before these test-owned
              # actors are dismantled; this is not a successful lifecycle receipt.
              if Process.alive?(instance) do
                instance_monitor = Process.monitor(instance)
                Process.exit(instance, :kill)
                assert_receive {:DOWN, ^instance_monitor, :process, ^instance, :killed}, @timeout
              end
            end

            for {actor, monitor} <- monitors do
              assert_receive {:DOWN, ^monitor, :process, ^actor, :normal}, @timeout
            end

            :ok
          rescue
            error -> {:error, Exception.format(:error, error, __STACKTRACE__)}
          end

        send(caller, {:embedding_cleanup, self(), result})
    after
      30_000 -> raise "embedding cleanup was not requested"
    end
  end

  defp expect_cleanup(instance, mode) do
    embedding = :sys.get_state(instance).parent
    send(embedding, {:expect_cleanup, mode, self()})
    assert_receive {:cleanup_expected, ^embedding, ^mode}, @timeout
  end

  defp add_service(instance, origin, handle, id, limits, options \\ %{}) do
    options = Map.merge(%{upstream: origin, transport: handle}, options)

    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(id: id, endpoint: {ProxyHTTP, options}, limits: limits)

    assert {:ok, _} = Gaoxy.add(instance, spec)
  end

  defp assert_clean(instance, owner, capacity \\ true, id \\ :http) do
    eventually(fn ->
      match?(%{active: 0, cleanup_pending: 0, retained_bytes: 0}, Gaoxy.status(instance, id)) and
        match?({:ok, %{request_tokens: 0, pins: 1, helpers: 0}}, Transports.status(owner))
    end)

    assert %{cleanup_failed: nil} = Gaoxy.status(instance, id)

    if capacity,
      do: assert({:ok, %{resources: 1, reserved_connections: 2}} = Transports.status(owner))
  end

  defp stop_and_join(instance, owner, peer) do
    owner_monitor = Process.monitor(owner)
    assert :ok = Gaoxy.stop(instance, @timeout)
    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :normal}, @timeout
    assert_peer(peer)
  end

  defp peer(protocol, context, exchange, hostname \\ "localhost") do
    wire = if protocol == :tls, do: :ssl, else: :gen_tcp
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

    {:ok, listener} = wire.listen(0, options)

    {:ok, {_, port}} =
      if protocol == :tls, do: :ssl.sockname(listener), else: :inet.sockname(listener)

    test_owner = self()

    peer =
      spawn(fn ->
        try do
          accepted =
            if protocol == :tls,
              do: :ssl.transport_accept(listener, @timeout),
              else: :gen_tcp.accept(listener, @timeout)

          case accepted do
            {:ok, transport} ->
              result =
                if protocol == :tls,
                  do: :ssl.handshake(transport, @timeout),
                  else: {:ok, transport}

              case result do
                {:ok, socket} ->
                  try do
                    exchange.(wire, socket, test_owner)
                  after
                    wire.close(socket)
                  end

                {:error, reason} ->
                  wire.close(transport)
                  send(test_owner, {:handshake_failed, self(), reason})
              end

              second =
                if protocol == :tls,
                  do: :ssl.transport_accept(listener, 100),
                  else: :gen_tcp.accept(listener, 100)

              assert second == {:error, :timeout},
                     "unexpected second connection/replay: #{inspect(second)}"

              send(test_owner, {:peer_done, self()})

            {:error, :closed} ->
              :ok
          end
        rescue
          error ->
            send(
              test_owner,
              {:peer_error, self(), Exception.format(:error, error, __STACKTRACE__)}
            )
        after
          wire.close(listener)
        end
      end)

    on_exit(fn ->
      monitor = Process.monitor(peer)
      wire.close(listener)

      receive do
        {:DOWN, ^monitor, :process, ^peer, _} -> :ok
      after
        @timeout + 1000 -> flunk("test peer did not join")
      end
    end)

    source = %{
      origin:
        "#{if protocol == :tls, do: "https", else: "http"}://#{if protocol == :tls, do: hostname, else: "127.0.0.1"}:#{port}",
      connect_address: {127, 0, 0, 1},
      trust: if(protocol == :tls, do: ca(context.trusted), else: nil)
    }

    {source, peer, listener}
  end

  defp source_origin(:ssl, socket) do
    {:ok, {_, port}} = :ssl.sockname(socket)
    "https://localhost:#{port}"
  end

  defp source_origin(:gen_tcp, socket) do
    {:ok, {_, port}} = :inet.sockname(socket)
    "http://127.0.0.1:#{port}"
  end

  defp ca(directory),
    do:
      for(
        {:Certificate, der, :not_encrypted} <-
          :public_key.pem_decode(File.read!(Path.join(directory, "ca.pem"))),
        do: der
      )

  defp assert_peer(peer) do
    monitor = Process.monitor(peer)

    receive do
      {:peer_done, ^peer} -> :ok
      {:peer_error, ^peer, error} -> flunk(error)
    after
      @timeout -> flunk("real peer did not finish")
    end

    assert_receive {:DOWN, ^monitor, :process, ^peer, reason} when reason in [:normal, :noproc],
                   @timeout
  end

  defp connect(instance, id \\ :http) do
    {:ok, {ip, port}} = Gaoxy.info(instance, id).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)
    socket
  end

  defp request(method, target, fields \\ []),
    do: [
      "#{method} #{target} HTTP/1.1\r\nHost: downstream.test\r\n",
      Enum.map(fields, fn {k, v} -> [k, ": ", v, "\r\n"] end),
      "\r\n"
    ]

  defp head(wire, socket, acc \\ "") do
    next = acc <> line(wire, socket)
    assert byte_size(next) <= 65_536
    if String.ends_with?(next, "\r\n\r\n"), do: next, else: head(wire, socket, next)
  end

  defp line(wire, socket, acc \\ "") do
    assert byte_size(acc) <= 65_536
    assert {:ok, byte} = wire.recv(socket, 1, @timeout)
    next = acc <> byte
    if String.ends_with?(next, "\r\n"), do: next, else: line(wire, socket, next)
  end

  defp chunks(wire, socket, acc \\ "") do
    size = wire |> line(socket) |> String.trim() |> String.to_integer(16)
    assert size <= 65_536

    if size == 0 do
      {acc, trailers(wire, socket)}
    else
      assert {:ok, bytes} = wire.recv(socket, size, @timeout)
      assert {:ok, "\r\n"} = wire.recv(socket, 2, @timeout)
      chunks(wire, socket, acc <> bytes)
    end
  end

  defp trailers(wire, socket, acc \\ []) do
    case line(wire, socket) do
      "\r\n" ->
        Enum.reverse(acc)

      field ->
        [name, value] = String.split(String.trim_trailing(field, "\r\n"), ":", parts: 2)
        trailers(wire, socket, [{String.downcase(name), String.trim(value)} | acc])
    end
  end

  defp deadline, do: Gaoxy.Lifecycle.deadline(@timeout)

  defp eventually(fun, d \\ nil) do
    d = d || deadline()

    if fun.() do
      :ok
    else
      assert Gaoxy.Lifecycle.remaining(d) > 0, "bounded endpoint accounting did not settle"

      receive do
      after
        2 -> eventually(fun, d)
      end
    end
  end
end
