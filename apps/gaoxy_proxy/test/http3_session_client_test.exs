defmodule Gaoxy.Proxy.HTTP3SessionClientTest do
  use ExUnit.Case, async: true
  alias Gaoxy.{Admission, Lifecycle, Service}
  alias Gaoxy.Proxy.HTTP3SessionClient

  @moduletag :tmp_dir

  setup %{tmp_dir: directory} do
    ca = Path.join(directory, "ca.pem")
    File.write!(ca, "fixture trust file; no network operation in pre-allocation tests")
    {:ok, ca: ca}
  end

  test "an expired request fails before allocating bootstrap work", %{ca: ca} do
    assert Code.ensure_loaded?(HTTP3SessionClient)
    options = options(ca)

    assert {:error, :request_timeout} =
             apply(HTTP3SessionClient, :open, [%{options | deadline: Lifecycle.now() - 1}])
  end

  test "an expired opening budget fails before allocating bootstrap work", %{ca: ca} do
    assert Code.ensure_loaded?(HTTP3SessionClient)
    options = options(ca)

    assert {:error, :timeout} =
             apply(HTTP3SessionClient, :open, [%{options | opening_deadline: Lifecycle.now() - 1}])
  end

  test "expired upload and finish calls never send work to the guardian" do
    assert Code.ensure_loaded?(HTTP3SessionClient)
    id = make_ref()
    token = {:http3_session_upload, self(), id, Lifecycle.now() - 1, 100}
    assert {:error, :timeout} = apply(HTTP3SessionClient, :write_body, [token, "abc", 100])
    assert {:error, :timeout} = apply(HTTP3SessionClient, :finish_body, [token, []])
    refute_receive _, 0
  end

  test "oversized DATA rejects before sending a guardian command" do
    assert Code.ensure_loaded?(HTTP3SessionClient)
    token = {:http3_session_upload, self(), make_ref(), Lifecycle.deadline(1_000), 100}

    assert {:error, :invalid_upload_chunk} =
             apply(HTTP3SessionClient, :write_body, [token, :binary.copy("a", 16_385), 100])

    refute_receive _, 0
  end

  test "Session completion cannot be consumed by H1 group completion APIs" do
    assert Code.ensure_loaded?(HTTP3SessionClient)
    completion = {:http3_session, self(), make_ref()}

    for cancelled <- [false, true] do
      assert {:error, :unsupported_group_completion} =
               apply(HTTP3SessionClient, :await_completion, [completion, cancelled])
    end
  end

  test "reservation includes the configured upload allowance and complete input bytes" do
    assert Code.ensure_loaded?(HTTP3SessionClient)
    fields = [{"x-duplicate", "one"}, {"x-duplicate", "two"}]
    small = apply(HTTP3SessionClient, :reservation_bytes, [fields, 100, 3])
    large = apply(HTTP3SessionClient, :reservation_bytes, [fields, 150, 16_384])
    assert small >= 8 * 262_144 + 2 * :erlang.external_size({fields, ""}) + 200
    assert large - small == 8 * (16_384 - 3) + 100
  end

  test "public Session configuration fragments frames at 8192 while retaining application DATA allowance",
       %{ca: ca} do
    observer = self()
    public_driver = driver(observer)

    traced_driver = fn module, operation, arguments ->
      if module == QuicHttp3.Session and operation == :new,
        do: send(observer, {:session_options, arguments})

      public_driver.(module, operation, arguments)
    end

    {guardian, monitor} = guardian(options(ca), traced_driver)
    assert_receive {:session_options, [session_options]}, 1_000
    assert session_options[:max_frame] == 8_192
    assert session_options[:max_retained_bytes] == 262_144
    assert_receive {:opened, ^guardian, _}, 1_000
    assert snapshot(guardian).max_upload_bytes == 16_384
    assert_receive {:endpoint_created, creator, endpoint, descriptor}, 1_000
    send(creator, {:public_return, {:ok, descriptor}})
    assert_receive {:public_operation, _, :connect, _}, 1_000
    cleanup(guardian, monitor, endpoint)
  end

  test "production options reject driver and transport injection before allocation", %{ca: ca} do
    for field <- [:driver, :transport, :tls, :socket_opts, :client] do
      assert {:error, :invalid_http3_options} =
               apply(HTTP3SessionClient, :open, [Map.put(options(ca), field, :untrusted)])
    end

    refute_receive _, 0
  end

  test "cancellation before descriptor adoption waits for confirmed endpoint teardown", %{ca: ca} do
    {guardian, monitor} = guardian(options(ca), driver(self()))
    assert_receive {:opened, ^guardian, _upload}, 1_000
    assert_receive {:endpoint_created, creator, endpoint, descriptor}, 1_000
    creator_monitor = Process.monitor(creator)
    endpoint_monitor = Process.monitor(endpoint)

    send(guardian, {:begin_cleanup, true, Lifecycle.deadline(500)})
    assert_receive {:cleanup_started, ^guardian}, 100
    refute_receive {:cleanup_complete, ^guardian}, 0
    send(creator, {:public_return, {:ok, descriptor}})

    assert_receive {:endpoint_stop, _stopper, ^endpoint}, 1_000
    assert_receive {:DOWN, ^endpoint_monitor, :process, ^endpoint, :normal}, 1_000
    assert_receive {:DOWN, ^creator_monitor, :process, ^creator, _}, 1_000
    assert_receive {:cleanup_complete, ^guardian}, 1_000
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
    refute_receive {:public_operation, _, :connect, _}, 0
  end

  test "creator normal exit preserves the adopted endpoint before connect", %{ca: ca} do
    {guardian, monitor} = guardian(options(ca), driver(self()))
    assert_receive {:opened, ^guardian, _upload}, 1_000
    assert_receive {:endpoint_created, creator, endpoint, descriptor}, 1_000
    creator_monitor = Process.monitor(creator)
    send(creator, {:public_return, {:ok, descriptor}})

    assert_receive {:DOWN, ^creator_monitor, :process, ^creator, :normal}, 1_000
    assert Process.alive?(endpoint)

    assert_receive {:public_operation, connector, :connect, [session, "localhost", 443, opts]},
                   1_000

    assert opts[:endpoint] == descriptor
    assert opts[:consumer] == connector
    refute connector in [guardian, creator]
    send(connector, {:public_return, {:error, session, :tls_failed}})
    assert_receive {:adapter_event, ^guardian, {:error, :tls_failed}}, 1_000

    send(guardian, {:begin_cleanup, true, Lifecycle.deadline(500)})
    assert_receive {:endpoint_stop, _, ^endpoint}, 1_000
    assert_receive {:cleanup_complete, ^guardian}, 1_000
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
  end

  test "a blocked public connect does not block guardian cancellation", %{ca: ca} do
    {guardian, monitor} = guardian(options(ca), driver(self()))
    assert_receive {:opened, ^guardian, _upload}, 1_000
    assert_receive {:endpoint_created, creator, endpoint, descriptor}, 1_000
    send(creator, {:public_return, {:ok, descriptor}})
    assert_receive {:public_operation, connector, :connect, _}, 1_000
    connector_monitor = Process.monitor(connector)
    endpoint_monitor = Process.monitor(endpoint)

    send(guardian, {:begin_cleanup, true, Lifecycle.deadline(500)})
    assert_receive {:cleanup_started, ^guardian}, 100
    assert_receive {:endpoint_stop, _, ^endpoint}, 1_000
    assert_receive {:DOWN, ^endpoint_monitor, :process, ^endpoint, :normal}, 1_000
    assert_receive {:DOWN, ^connector_monitor, :process, ^connector, _}, 1_000
    assert_receive {:cleanup_complete, ^guardian}, 1_000
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
  end

  test "endpoint stop failure never becomes successful cleanup", %{ca: ca} do
    {guardian, monitor} = guardian(options(ca), driver(self(), {:error, :stop_failed}))
    assert_receive {:opened, ^guardian, _upload}, 1_000
    assert_receive {:endpoint_created, creator, endpoint, descriptor}, 1_000
    send(creator, {:public_return, {:ok, descriptor}})
    assert_receive {:public_operation, connector, :connect, _}, 1_000
    connector_monitor = Process.monitor(connector)

    send(guardian, {:begin_cleanup, true, Lifecycle.deadline(200)})
    assert_receive {:cleanup_started, ^guardian}, 100
    assert_receive {:endpoint_stop, _, ^endpoint}, 1_000
    assert_receive {:cleanup_failed, ^guardian, _reason}, 1_000
    refute_receive {:cleanup_complete, ^guardian}, 0
    assert_receive {:DOWN, ^connector_monitor, :process, ^connector, _}, 1_000
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
    stop(endpoint)
  end

  test "one stable caller executes connect request and poll with advanced Session values", %{
    ca: ca
  } do
    {guardian, monitor, caller, endpoint, session, request_ref, _upload} = streaming(ca)
    assert_receive {:public_operation, ^caller, :poll, [^session, 16, opts]}, 1_000
    assert opts[:max_read_batches] == 1
    assert opts[:paused] == MapSet.new()

    advanced = %{session | test_session: make_ref()}

    send(
      caller,
      {:public_return, {:ok, advanced, [{:headers, request_ref, [{":status", "200"}]}]}}
    )

    assert_receive {:adapter_event, ^guardian, {:headers, 200, []}}, 1_000
    assert [^advanced, ^request_ref] = await_operation(caller, :reset_send)
    send(caller, {:public_return, {:ok, advanced}})
    assert_receive {:public_operation, ^caller, :poll, [^advanced, 16, _]}, 1_000
    cleanup(guardian, monitor, endpoint)
  end

  test "unknown request admission resumes the same advanced operation without replay", %{ca: ca} do
    {guardian, monitor, caller, endpoint, session, _upload} = connected(ca)
    assert_receive {:public_operation, ^caller, :request, [^session, _fields, :stream, _]}, 1_000
    advanced = %{session | test_session: make_ref()}
    operation_ref = make_ref()
    send(caller, {:public_return, {:unknown, advanced, operation_ref}})

    assert_receive {:public_operation, ^caller, :resume, [^advanced]}, 1_000
    request_ref = make_ref()
    accepted = %{advanced | test_session: make_ref()}
    send(caller, {:public_return, {:ok, accepted, request_ref}})
    assert_receive {:public_operation, ^caller, :poll, [^accepted, 16, _]}, 1_000
    refute_receive {:public_operation, _, :request, _}, 0
    cleanup(guardian, monitor, endpoint)
  end

  test "normal guardian loss during a public call stops caller after the call returns", %{ca: ca} do
    {guardian, monitor} = guardian(options(ca), driver(self()))
    assert_receive {:opened, ^guardian, _}, 1_000
    assert_receive {:endpoint_created, creator, endpoint, descriptor}, 1_000
    send(creator, {:public_return, {:ok, descriptor}})
    assert_receive {:public_operation, caller, :connect, [session, _, _, _]}, 1_000
    caller_monitor = Process.monitor(caller)
    endpoint_monitor = Process.monitor(endpoint)

    send(guardian, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
    assert_receive {:DOWN, ^endpoint_monitor, :process, ^endpoint, :normal}, 1_000
    # A synchronous public call cannot be interrupted by its guardian monitor.
    assert Process.alive?(caller)
    send(caller, {:public_return, {:ok, session}})
    assert_receive {:DOWN, ^caller_monitor, :process, ^caller, :normal}, 1_000
    refute_receive {:public_operation, _, _, _}, 0
    refute_receive {:cleanup_complete, ^guardian}, 0
  end

  test "normal guardian loss during bootstrap does not wait forever for adoption", %{ca: ca} do
    {guardian, monitor} = guardian(options(ca), driver(self()))
    assert_receive {:opened, ^guardian, _}, 1_000
    assert_receive {:endpoint_created, creator, endpoint, descriptor}, 1_000
    creator_monitor = Process.monitor(creator)
    endpoint_monitor = Process.monitor(endpoint)

    send(guardian, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
    assert_receive {:DOWN, ^endpoint_monitor, :process, ^endpoint, :normal}, 1_000
    send(creator, {:public_return, {:ok, descriptor}})
    assert_receive {:endpoint_stop, ^creator, ^endpoint}, 1_000
    assert_receive {:DOWN, ^creator_monitor, :process, ^creator, :normal}, 2_000
    refute_receive {:public_operation, _, :connect, _}, 0
  end

  test "normal guardian loss terminates the stable caller between finite polls", %{ca: ca} do
    {guardian, monitor, caller, endpoint, _session, _request_ref, _upload} =
      streaming(ca, driver(self(), :ok, true))

    caller_monitor = Process.monitor(caller)
    endpoint_monitor = Process.monitor(endpoint)
    barrier = make_ref()
    send(guardian, {:barrier, self(), barrier})
    assert_receive {:barrier, ^guardian, ^barrier}, 1_000
    send(guardian, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
    assert_receive {:DOWN, ^endpoint_monitor, :process, ^endpoint, :normal}, 1_000
    assert_receive {:DOWN, ^caller_monitor, :process, ^caller, :normal}, 1_000
    refute_receive {:cleanup_complete, ^guardian}, 0
  end

  test "caller death fails the request and never starts a replacement caller", %{ca: ca} do
    {guardian, monitor, caller, endpoint, _session, _upload} = connected(ca)
    assert_receive {:public_operation, ^caller, :request, _}, 1_000
    caller_monitor = Process.monitor(caller)
    Process.exit(caller, :kill)
    assert_receive {:DOWN, ^caller_monitor, :process, ^caller, :killed}, 1_000
    assert_receive {:adapter_event, ^guardian, {:error, _reason}}, 1_000
    cleanup(guardian, monitor, endpoint)
    refute_receive {:public_operation, _, :connect, _}, 0
    refute_receive {:public_operation, _, :request, _}, 0
  end

  test "normal guardian loss leaves the stop task responsible for its one stop", %{ca: ca} do
    {guardian, monitor, caller, endpoint, session, _upload} =
      connected(ca, driver(self(), :deferred))

    assert_receive {:public_operation, ^caller, :request, _}, 1_000
    caller_monitor = Process.monitor(caller)
    send(guardian, {:begin_cleanup, true, Lifecycle.deadline(500)})
    assert_receive {:endpoint_stop, stopper, ^endpoint}, 1_000
    stopper_monitor = Process.monitor(stopper)
    endpoint_monitor = Process.monitor(endpoint)

    send(guardian, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
    assert_receive {:DOWN, ^endpoint_monitor, :process, ^endpoint, :normal}, 1_000
    send(stopper, {:public_return, :ok})
    send(caller, {:public_return, {:ok, session, make_ref()}})
    assert_receive {:DOWN, ^stopper_monitor, :process, ^stopper, :normal}, 2_000
    assert_receive {:DOWN, ^caller_monitor, :process, ^caller, _}, 1_000
    refute_receive {:endpoint_stop, _, ^endpoint}, 0
    refute_receive {:cleanup_complete, ^guardian}, 0
  end

  test "late public success cannot acknowledge upload or revive terminal work", %{ca: ca} do
    {guardian, monitor, caller, endpoint, session, request_ref, upload} = streaming(ca)
    assert_receive {:public_operation, ^caller, :poll, _}, 1_000
    send(caller, {:public_return, {:ok, session, []}})
    writer = upload_call(upload, "abc", 500)

    assert_receive {:public_operation, ^caller, :send_data, [_, ^request_ref, "abc", false, _]},
                   1_000

    send(guardian, {:begin_cleanup, true, Lifecycle.deadline(500)})
    assert_receive {:cleanup_started, ^guardian}, 100
    assert_receive {:endpoint_stop, _, ^endpoint}, 1_000
    # If the endpoint DOWN already killed the owned caller, this late message
    # is harmless; if it is still returning, terminal state rejects the result.
    send(caller, {:public_return, {:ok, session}})
    assert_receive {:upload_result, ^writer, {:error, _}}, 1_000
    assert_receive {:cleanup_complete, ^guardian}, 1_000
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
    refute_receive {:upload_result, ^writer, :ok}, 0
    refute_receive {:public_operation, _, :send_data, _}, 0
  end

  test "bootstrap and connect retain original absolute opening and total deadlines", %{ca: ca} do
    initial = %{
      options(ca)
      | deadline: Lifecycle.deadline(1_500),
        opening_deadline: Lifecycle.deadline(800)
    }

    {guardian, monitor} = guardian(initial, driver(self()))
    assert_receive {:opened, ^guardian, _}, 1_000
    assert_receive {:endpoint_created, creator, endpoint, descriptor}, 1_000
    assert %{deadline: total, opening_deadline: opening} = snapshot(guardian)
    assert total == initial.deadline
    assert opening == initial.opening_deadline
    before_connect = Lifecycle.remaining(initial.opening_deadline)
    send(creator, {:public_return, {:ok, descriptor}})
    assert_receive {:public_operation, caller, :connect, [session, _, _, opts]}, 1_000
    assert opts[:timeout] > 0
    assert opts[:timeout] <= before_connect
    barrier = make_ref()
    send(guardian, {:barrier, self(), barrier})
    assert_receive {:barrier, ^guardian, ^barrier}, 1_000
    assert %{deadline: ^total, opening_deadline: ^opening} = snapshot(guardian)
    send(caller, {:public_return, {:error, session, :connect_failed}})
    assert_receive {:adapter_event, ^guardian, {:error, :connect_failed}}, 1_000
    cleanup(guardian, monitor, endpoint)
  end

  test "unknown DATA resumption keeps its original write deadline and rejects late success", %{
    ca: ca
  } do
    {guardian, monitor, caller, endpoint, session, request_ref, upload} = streaming(ca)
    writer = upload_call(upload, "abc", 100)
    assert [_, ^request_ref, "abc", false, first_opts] = await_operation(caller, :send_data)
    assert first_opts[:timeout] <= 100
    assert %{operation: %{deadline: original_write_deadline}} = snapshot(guardian)
    advanced = %{session | test_session: make_ref()}
    send(caller, {:public_return, {:unknown, advanced, make_ref()}})
    assert [^advanced] = await_operation(caller, :resume)
    assert %{operation: %{deadline: ^original_write_deadline}} = snapshot(guardian)
    assert_receive {:upload_result, ^writer, {:error, _}}, 500
    send(caller, {:public_return, {:ok, advanced}})
    refute_receive {:upload_result, ^writer, :ok}, 0
    refute_receive {:public_operation, _, :send_data, _}, 0
    cleanup(guardian, monitor, endpoint)
  end

  test "cleanup grace uses the earlier supplied deadline without restarting on repeated checks",
       %{ca: ca} do
    {guardian, monitor, caller, endpoint, _session, _upload} =
      connected(ca, driver(self(), :deferred))

    assert_receive {:public_operation, ^caller, :request, _}, 1_000
    original = snapshot(guardian)
    supplied = Lifecycle.deadline(300)
    send(guardian, {:begin_cleanup, true, supplied})
    assert_receive {:endpoint_stop, stopper, ^endpoint}, 1_000
    assert %{cleanup_deadline: deadline} = snapshot(guardian)
    assert deadline == min(supplied, original.deadline + Lifecycle.cleanup_headroom())
    send(guardian, {:cleanup_check, self()})
    assert_receive {:cleanup_checked, ^guardian}, 1_000
    assert %{cleanup_deadline: ^deadline} = snapshot(guardian)
    send(stopper, {:public_return, :ok})
    assert_receive {:cleanup_complete, ^guardian}, 1_000
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
  end

  test "cleanup grace is capped by original total deadline plus fixed headroom", %{ca: ca} do
    {guardian, monitor, caller, endpoint, _session, _upload} =
      connected(ca, driver(self(), :deferred))

    assert_receive {:public_operation, ^caller, :request, _}, 1_000
    original = snapshot(guardian)
    send(guardian, {:begin_cleanup, true, original.deadline + 10_000})
    assert_receive {:endpoint_stop, stopper, ^endpoint}, 1_000
    assert %{cleanup_deadline: deadline} = snapshot(guardian)
    assert deadline == original.deadline + Lifecycle.cleanup_headroom()
    send(stopper, {:public_return, :ok})
    assert_receive {:cleanup_complete, ^guardian}, 1_000
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
  end

  test "blocked DATA suspends once and resumes its continuation using the latest polled Session",
       %{ca: ca} do
    {guardian, monitor, caller, endpoint, session, request_ref, upload} = streaming(ca)
    writer = upload_call(upload, "abc", 500)
    assert [_, ^request_ref, "abc", false, _] = await_operation(caller, :send_data)
    blocked = %{session | test_session: make_ref()}
    send(caller, {:public_return, {:blocked, blocked, :flow_control}})
    assert [^blocked] = await_operation(caller, :suspend_blocked)
    suspended = %{blocked | test_session: make_ref()}
    continuation = make_ref()
    send(caller, {:public_return, {:ok, suspended, continuation}})
    assert [^suspended, 16, _] = await_operation(caller, :poll)
    latest = %{suspended | test_session: make_ref()}
    send(caller, {:public_return, {:ok, latest, [{:writable, request_ref}]}})
    assert [^latest, ^continuation] = await_operation(caller, :resume)
    send(caller, {:public_return, {:ok, latest}})
    assert_receive {:upload_result, ^writer, :ok}, 1_000
    refute_receive {:public_operation, _, :send_data, _}, 0
    refute_receive {:public_operation, _, :suspend_blocked, _}, 0
    cleanup(guardian, monitor, endpoint)
  end

  test "the public atom writable resumes a suspended upload without replay", %{ca: ca} do
    {guardian, monitor, caller, endpoint, session, request_ref, upload} = streaming(ca)
    writer = upload_call(upload, "abc", 500)
    assert [_, ^request_ref, "abc", false, _] = await_operation(caller, :send_data)
    send(caller, {:public_return, {:blocked, session, :flow_control}})
    assert [^session] = await_operation(caller, :suspend_blocked)
    continuation = make_ref()
    send(caller, {:public_return, {:ok, session, continuation}})
    assert [^session, 16, _] = await_operation(caller, :poll)
    latest = %{session | test_session: make_ref()}
    send(caller, {:public_return, {:ok, latest, [:writable]}})
    assert [^latest, ^continuation] = await_operation(caller, :resume)
    send(caller, {:public_return, {:ok, latest}})
    assert_receive {:upload_result, ^writer, :ok}, 1_000
    refute_receive {:public_operation, _, :send_data, _}, 0
    cleanup(guardian, monitor, endpoint)
  end

  test "unknown trailing HEADERS preserves duplicate order and reconciles FIN without replay", %{
    ca: ca
  } do
    {guardian, monitor, caller, endpoint, session, request_ref, upload} = streaming(ca)
    writer = upload_call(upload, "abc", 500)
    assert [_, ^request_ref, "abc", false, _] = await_operation(caller, :send_data)
    send(caller, {:public_return, {:ok, session}})
    assert_receive {:upload_result, ^writer, :ok}, 1_000
    trailers = [{"x-check", "one"}, {"x-check", "two"}]
    finisher = finish_call(upload, trailers)
    assert [_, ^request_ref, ^trailers, _] = await_operation(caller, :send_trailers)
    advanced = %{session | test_session: make_ref()}
    send(caller, {:public_return, {:unknown, advanced, make_ref()}})
    assert [^advanced] = await_operation(caller, :resume)
    refute_receive {:finish_result, ^finisher, :ok}, 0
    send(caller, {:public_return, {:ok, advanced}})
    assert_receive {:finish_result, ^finisher, :ok}, 1_000
    refute_receive {:public_operation, _, :send_trailers, _}, 0
    refute_receive {:public_operation, _, :send_data, _}, 0
    assert {:error, _} = apply(HTTP3SessionClient, :finish_body, [upload, trailers])
    cleanup(guardian, monitor, endpoint)
  end

  test "zero body keeps a finish token and emits exactly one DATA FIN when trailers are absent",
       %{ca: ca} do
    {guardian, monitor} = guardian(options(ca), driver(self()))
    assert_receive {:opened, ^guardian, upload}, 1_000
    assert match?({:http3_session_upload, ^guardian, _, _, _}, upload)
    assert_receive {:endpoint_created, creator, endpoint, descriptor}, 1_000
    send(creator, {:public_return, {:ok, descriptor}})
    assert_receive {:public_operation, caller, :connect, [session, _, _, _]}, 1_000
    send(caller, {:public_return, {:ok, session}})
    assert [^session, _, :stream, _] = await_operation(caller, :request)
    request_ref = make_ref()
    send(caller, {:public_return, {:ok, session, request_ref}})
    finisher = finish_call(upload, [])
    assert [_, ^request_ref, <<>>, true, _] = await_operation(caller, :send_data)
    send(caller, {:public_return, {:ok, session}})
    assert_receive {:finish_result, ^finisher, :ok}, 1_000
    assert {:error, _} = apply(HTTP3SessionClient, :finish_body, [upload, []])
    refute_receive {:public_operation, _, :send_data, _}, 0
    cleanup(guardian, monitor, endpoint)
  end

  test "queued DATA splits at 16 KiB and trailers and done wait for the last matching ACK", %{
    ca: ca
  } do
    {guardian, monitor, caller, endpoint, session, request_ref, _upload} = streaming(ca)
    assert [^session, 16, _] = await_operation(caller, :poll)
    trailers = [{"x-check", "one"}, {"x-check", "two"}]

    send(
      caller,
      {:public_return,
       {:ok, session,
        [
          {:headers, request_ref, [{":status", "200"}]},
          {:data, request_ref, :binary.copy("a", 16_384) <> "tail"},
          {:trailers, request_ref, trailers},
          {:done, request_ref}
        ]}}
    )

    assert_receive {:adapter_event, ^guardian, {:headers, 200, []}}, 1_000
    assert_receive {:adapter_event, ^guardian, {:chunk, first, first_ack}}, 1_000
    assert first == :binary.copy("a", 16_384)
    assert [_, 16, paused_opts] = await_operation(caller, :poll)
    refute_receive {:public_operation, _, :reset_send, _}, 0
    assert paused_opts[:paused] == MapSet.new([request_ref])
    assert paused_opts[:max_read_batches] == 1
    send(guardian, {:ack, make_ref()})
    assert_receive {:acknowledged, ^guardian}, 1_000
    refute_receive {:adapter_event, ^guardian, {:chunk, _, _}}, 0
    refute_receive {:adapter_event, ^guardian, {:trailers, _}}, 0
    refute_receive {:adapter_event, ^guardian, :end}, 0
    send(guardian, {:ack, first_ack})
    assert_receive {:acknowledged, ^guardian}, 1_000
    send(caller, {:public_return, {:ok, session, []}})
    assert_receive {:adapter_event, ^guardian, {:chunk, "tail", last_ack}}, 1_000
    send(guardian, {:ack, first_ack})
    assert_receive {:acknowledged, ^guardian}, 1_000
    refute_receive {:adapter_event, ^guardian, {:trailers, _}}, 0
    refute_receive {:adapter_event, ^guardian, :end}, 0
    send(guardian, {:ack, last_ack})
    assert_receive {:acknowledged, ^guardian}, 1_000
    assert {:trailers, ^trailers} = await_event(caller, guardian)
    assert :end = await_event(caller, guardian)
    cleanup(guardian, monitor, endpoint)
  end

  test "a same-batch final head and done uses public terminal retirement without another upload reset",
       %{ca: ca} do
    {guardian, monitor, caller, endpoint, session, request_ref, _upload} = streaming(ca)
    assert [^session, 16, _] = await_operation(caller, :poll)
    advanced = %{session | test_session: make_ref()}

    send(
      caller,
      {:public_return,
       {:ok, advanced,
        [
          {:headers, request_ref, [{":status", "204"}]},
          {:done, request_ref}
        ]}}
    )

    assert_receive {:adapter_event, ^guardian, {:headers, 204, []}}, 1_000
    assert_receive {:adapter_event, ^guardian, :end}, 1_000

    assert %{session: ^advanced, request_ref: ^request_ref, upload_stopped: true} =
             snapshot(guardian)

    refute_receive {:public_operation, _, :reset_send, _}, 0
    cleanup(guardian, monitor, endpoint)
  end

  test "the actual public stream reset shape fails visibly and cannot emit response completion",
       %{ca: ca} do
    {guardian, monitor, caller, endpoint, session, request_ref, _upload} = streaming(ca)
    assert [^session, 16, _] = await_operation(caller, :poll)
    advanced = %{session | test_session: make_ref()}
    send(caller, {:public_return, {:ok, advanced, [{:stream_reset, request_ref, 0x10C, 3}]}})
    assert_receive {:adapter_event, ^guardian, {:error, {:upstream_reset, 0x10C, 3}}}, 1_000
    assert %{session: ^advanced} = snapshot(guardian)
    refute_receive {:adapter_event, ^guardian, :end}, 0
    cleanup(guardian, monitor, endpoint)
  end

  test "event queue rejects more than 262144 retained payload bytes visibly", %{ca: ca} do
    {guardian, monitor, caller, endpoint, session, request_ref, _upload} = streaming(ca)
    assert [_, 16, _] = await_operation(caller, :poll)

    send(
      caller,
      {:public_return,
       {:ok, session,
        [
          {:headers, request_ref, [{":status", "200"}]},
          {:data, request_ref, :binary.copy("a", 262_145)}
        ]}}
    )

    assert_receive {:adapter_event, ^guardian, {:error, _}}, 1_000
    refute_receive {:adapter_event, ^guardian, {:chunk, _, _}}, 0
    cleanup(guardian, monitor, endpoint)
  end

  test "event queue bounds informational and control events at 256 entries", %{ca: ca} do
    {guardian, monitor, caller, endpoint, session, request_ref, _upload} = streaming(ca)
    assert [_, 16, _] = await_operation(caller, :poll)
    events = List.duplicate({:informational, request_ref, 103, []}, 257)
    send(caller, {:public_return, {:ok, session, events}})
    assert_receive {:adapter_event, ^guardian, {:error, _}}, 1_000
    refute_receive {:adapter_event, ^guardian, {:headers, _, _}}, 0
    cleanup(guardian, monitor, endpoint)
  end

  test "early final response fails a suspended writer once and never resumes its DATA", %{ca: ca} do
    {guardian, monitor, caller, endpoint, session, request_ref, upload} = streaming(ca)
    writer = upload_call(upload, "abc", 500)
    assert [_, ^request_ref, "abc", false, _] = await_operation(caller, :send_data)
    send(caller, {:public_return, {:blocked, session, :flow_control}})
    assert [^session] = await_operation(caller, :suspend_blocked)
    continuation = make_ref()
    send(caller, {:public_return, {:ok, session, continuation}})
    assert [_, 16, _] = await_operation(caller, :poll)

    send(
      caller,
      {:public_return, {:ok, session, [{:headers, request_ref, [{":status", "413"}]}]}}
    )

    assert_receive {:adapter_event, ^guardian, {:headers, 413, []}}, 1_000
    assert_receive {:upload_result, ^writer, {:error, _}}, 1_000
    assert [_, ^request_ref] = await_operation(caller, :reset_send)
    send(caller, {:public_return, {:ok, session}})
    assert {:error, _} = apply(HTTP3SessionClient, :write_body, [upload, "later", 100])
    refute_receive {:upload_result, ^writer, _}, 0
    refute_receive {:public_operation, _, :resume, [_, ^continuation]}, 0
    refute_receive {:public_operation, _, :send_data, _}, 0
    cleanup(guardian, monitor, endpoint)
  end

  test "a second upload cannot overlap the outstanding write or add a second continuation", %{
    ca: ca
  } do
    {guardian, monitor, caller, endpoint, session, request_ref, upload} = streaming(ca)
    first = upload_call(upload, "first", 500)
    assert [_, ^request_ref, "first", false, _] = await_operation(caller, :send_data)
    second = upload_call(upload, "second", 500)
    assert_receive {:upload_result, ^second, {:error, _}}, 1_000
    refute_receive {:public_operation, _, :send_data, [_, _, "second", _, _]}, 0
    send(caller, {:public_return, {:ok, session}})
    assert_receive {:upload_result, ^first, :ok}, 1_000
    cleanup(guardian, monitor, endpoint)
  end

  test "oversized response fields fail visibly before a final head is exposed", %{ca: ca} do
    {guardian, monitor, caller, endpoint, session, request_ref, _upload} = streaming(ca)
    assert [_, 16, _] = await_operation(caller, :poll)
    fields = [{":status", "200"}, {"x-large", :binary.copy("x", 65_537)}]
    send(caller, {:public_return, {:ok, session, [{:headers, request_ref, fields}]}})
    assert_receive {:adapter_event, ^guardian, {:error, _}}, 1_000
    refute_receive {:adapter_event, ^guardian, {:headers, _, _}}, 0
    cleanup(guardian, monitor, endpoint)
  end

  test "actual Service retains its reservation while H3 endpoint cleanup is unconfirmed", %{
    ca: ca
  } do
    {runtime, owner, context, deadline} = native_owner()
    {guardian, monitor} = guardian(%{options(ca) | deadline: deadline}, driver(self(), :deferred))
    assert_receive {:opened, ^guardian, _}, 1_000
    assert_receive {:endpoint_created, creator, endpoint, descriptor}, 1_000
    send(creator, {:public_return, {:ok, descriptor}})
    assert_receive {:public_operation, caller, :connect, _}, 1_000
    reservation = apply(HTTP3SessionClient, :reservation_bytes, [[], 50, 16_384])
    send(guardian, {:service_cleanup, context.service})
    _ = snapshot(guardian)
    send(owner, {:attach, guardian, reservation})
    assert_receive {:attached, {:ok, token}}, 1_000
    assert_receive {:cleanup_activated, ^guardian, ^token}, 1_000
    assert %{cleanup_pending: 1, retained_bytes: bytes} = Gaoxy.status(runtime, "h3-cleanup")
    assert bytes >= reservation
    assert {:error, :stale_cleanup} = Service.complete_cleanup(context.service, token)
    owner_monitor = Process.monitor(owner)
    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :killed}, 1_000
    eventually(fn -> Admission.status(context.gate).active == 0 end)
    assert %{cleanup_pending: 1, retained_bytes: ^reservation} = Admission.status(context.gate)
    send(guardian, {:begin_cleanup, true, Lifecycle.deadline(500)})
    assert_receive {:endpoint_stop, stopper, ^endpoint}, 1_000
    assert Process.alive?(caller)
    assert %{cleanup_pending: 1, retained_bytes: ^reservation} = Admission.status(context.gate)
    send(stopper, {:public_return, {:error, :stop_failed}})
    assert_receive {:cleanup_failed, ^guardian, _}, 1_000
    assert Process.alive?(guardian)
    assert %{cleanup_pending: 1, retained_bytes: ^reservation} = Admission.status(context.gate)
    refute_receive {:service_receipt, ^guardian, _}, 0
    refute_receive {:cleanup_complete, ^guardian}, 0
    service_monitor = Process.monitor(context.service)
    send(guardian, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
    assert_receive {:DOWN, ^service_monitor, :process, _, _}, 1_500
    assert {:error, :not_running} = Gaoxy.info(runtime, "h3-cleanup")
    stop(endpoint)
  end

  test "adoption ACK and observed creator DOWN cancellation barriers never launch a caller", %{
    ca: ca
  } do
    for stage <- [:adoption_ack, :creator_down] do
      {guardian, monitor} = guardian(options(ca), driver(self()), stage)
      assert_receive {:opened, ^guardian, _}, 1_000
      assert_receive {:endpoint_created, creator, endpoint, descriptor}, 1_000
      creator_monitor = Process.monitor(creator)
      send(creator, {:public_return, {:ok, descriptor}})
      assert_receive {:lifecycle_barrier, ^guardian, ^stage, held}, 1_000
      assert held.endpoint == descriptor
      assert held.caller == nil

      if stage == :creator_down,
        do: assert_receive({:DOWN, ^creator_monitor, :process, ^creator, :normal}, 1_000)

      send(guardian, {:barrier_cleanup, Lifecycle.deadline(500)})
      assert_receive {:endpoint_stop, _, ^endpoint}, 1_000
      assert_receive {:cleanup_complete, ^guardian}, 1_000
      assert_receive {:cleanup_receipt, ^guardian, receipt}, 1_000
      assert_cleanup_receipt(receipt)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
      refute_receive {:public_operation, _, :connect, _}, 0
    end
  end

  test "creator loss before a descriptor stays uncertain and adopted descriptor loss retains teardown",
       %{ca: ca} do
    observer = self()
    base = driver(observer)

    before_allocation = fn
      QuicHttp3.Transport.Quic, :client, _ ->
        send(observer, {:creator_before_allocation, self()})
        public_reply()

      module, operation, arguments ->
        base.(module, operation, arguments)
    end

    {guardian, monitor} = guardian(options(ca), before_allocation)
    assert_receive {:opened, ^guardian, _}, 1_000
    assert_receive {:creator_before_allocation, creator}, 1_000
    Process.exit(creator, :kill)
    assert_receive {:adapter_event, ^guardian, {:error, {:upstream_bootstrap, :killed}}}, 1_000
    send(guardian, {:begin_cleanup, true, Lifecycle.deadline(200)})
    assert_receive {:cleanup_failed, ^guardian, {:cleanup_unconfirmed, _}}, 1_000
    assert_receive {:cleanup_failure_receipt, ^guardian, lost}, 1_000
    assert lost.endpoint == nil
    assert lost.bootstrap.down == :killed
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
    refute_receive {:cleanup_complete, ^guardian}, 0

    {guardian, monitor} = guardian(options(ca), base, :adoption_ack)
    assert_receive {:opened, ^guardian, _}, 1_000
    assert_receive {:endpoint_created, creator, endpoint, descriptor}, 1_000
    send(creator, {:public_return, {:ok, descriptor}})
    assert_receive {:lifecycle_barrier, ^guardian, :adoption_ack, held}, 1_000
    assert held.endpoint == descriptor
    ref = make_ref()
    send(endpoint, {:unlink_creator, creator, self(), ref})
    assert_receive {:creator_unlinked, ^endpoint, ^ref}, 1_000
    Process.exit(creator, :kill)
    send(guardian, :barrier_release)
    assert_receive {:adapter_event, ^guardian, {:error, {:upstream_bootstrap, :killed}}}, 1_000
    assert Process.alive?(endpoint)
    cleanup(guardian, monitor, endpoint)
    assert_receive {:cleanup_receipt, ^guardian, retained}, 1_000
    assert_cleanup_receipt(retained)
    assert retained.bootstrap.down == :killed
    refute_receive {:public_operation, _, :connect, _}, 0
  end

  test "normal guardian loss after adoption ACK leaves no caller or Service completion", %{ca: ca} do
    {guardian, monitor} = guardian(options(ca), driver(self()), :adoption_ack)
    assert_receive {:opened, ^guardian, _}, 1_000
    assert_receive {:endpoint_created, creator, endpoint, descriptor}, 1_000
    creator_monitor = Process.monitor(creator)
    endpoint_monitor = Process.monitor(endpoint)
    send(creator, {:public_return, {:ok, descriptor}})
    assert_receive {:lifecycle_barrier, ^guardian, :adoption_ack, held}, 1_000
    assert held.endpoint == descriptor
    assert held.caller == nil
    send(guardian, :barrier_finish)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
    assert_receive {:DOWN, ^endpoint_monitor, :process, ^endpoint, :normal}, 1_000
    assert_receive {:DOWN, ^creator_monitor, :process, ^creator, :normal}, 1_000
    refute_receive {:public_operation, _, :connect, _}, 0
    refute_receive {:cleanup_complete, ^guardian}, 0
    refute_receive {:service_receipt, ^guardian, _}, 0
  end

  test "caller loss before connect admission and while idle after connect never replaces its owner",
       %{ca: ca} do
    for stage <- [:before_admission, :idle_connected] do
      {guardian, monitor} = guardian(options(ca), driver(self()))
      assert_receive {:opened, ^guardian, _}, 1_000
      assert_receive {:endpoint_created, creator, endpoint, descriptor}, 1_000
      send(creator, {:public_return, {:ok, descriptor}})
      assert_receive {:public_operation, caller, :connect, [session, _, _, _]}, 1_000

      if stage == :idle_connected do
        before_return = snapshot(guardian)
        command_ref = before_return.operation.ref
        id = before_return.id
        generation = before_return.generation
        true = :erlang.suspend_process(guardian)

        try do
          :erlang.trace(caller, true, [:send, :receive, {:tracer, self()}])
          send(caller, {:public_return, {:ok, session}})

          assert_receive {:trace, ^caller, :send,
                          {:h3_result, ^id, ^generation, ^caller, ^command_ref, {:ok, ^session}},
                          ^guardian},
                         1_000

          # The returned public result and consumed hint establish the owned
          # caller's idle loop while the suspended guardian cannot send work.
          send(caller, {:quic_ready, :public_hint, %{}})
          assert_receive {:trace, ^caller, :receive, {:quic_ready, :public_hint, %{}}}, 1_000
          Process.exit(caller, :kill)
        after
          if Process.alive?(guardian), do: true = :erlang.resume_process(guardian)
        end
      else
        Process.exit(caller, :kill)
      end

      assert_receive {:adapter_event, ^guardian, {:error, {:upstream_caller, :killed}}}, 1_000
      cleanup(guardian, monitor, endpoint)
      assert_receive {:cleanup_receipt, ^guardian, receipt}, 1_000
      assert_cleanup_receipt(receipt)
      refute_receive {:public_operation, _, :connect, _}, 0
      refute_receive {:public_operation, _, :request, _}, 0
    end
  end

  test "stale generations duplicate results and repeated caller command sequences cannot admit work",
       %{ca: ca} do
    {guardian, monitor, caller, endpoint, session, request_ref, _upload} = finished_streaming(ca)
    assert [^session, 16, _] = await_operation(caller, :poll)
    state = snapshot(guardian)
    ref = state.operation.ref
    sequence = state.caller.sequence
    stale = %{session | test_session: make_ref()}

    send(
      guardian,
      {:h3_result, state.id, make_ref(), caller, ref, {:ok, stale, [{:done, request_ref}]}}
    )

    send(
      caller,
      {:h3_command, guardian, state.id, make_ref(), make_ref(), sequence + 1, :send_data,
       [stale, request_ref, "replay", false, []], state.deadline}
    )

    send(
      caller,
      {:h3_command, guardian, state.id, state.generation, ref, sequence, :send_data,
       [stale, request_ref, "replay", false, []], state.deadline}
    )

    assert %{session: ^session, operation: %{ref: ^ref}} = snapshot(guardian)

    send(
      caller,
      {:public_return,
       {:ok, session,
        [
          {:headers, request_ref, [{":status", "200"}]},
          {:data, request_ref, "one"},
          {:done, request_ref}
        ]}}
    )

    assert_receive {:adapter_event, ^guardian, {:headers, 200, []}}, 1_000
    assert_receive {:adapter_event, ^guardian, {:chunk, "one", ack}}, 1_000

    send(
      guardian,
      {:h3_result, state.id, state.generation, caller, ref, {:ok, stale, [{:done, request_ref}]}}
    )

    assert %{session: ^session, delivery: ^ack} = snapshot(guardian)
    refute_receive {:adapter_event, ^guardian, :end}, 0
    refute_receive {:public_operation, _, :send_data, _}, 0
    send(guardian, {:ack, ack})
    assert_receive {:adapter_event, ^guardian, :end}, 1_000
    cleanup(guardian, monitor, endpoint)
  end

  test "unrelated DOWN during paused ACK is ignored and normal guardian loss terminates owned resources",
       %{ca: ca} do
    {guardian, monitor, caller, endpoint, session, request_ref, _upload} = finished_streaming(ca)
    assert [^session, 16, _] = await_operation(caller, :poll)

    send(
      caller,
      {:public_return,
       {:ok, session,
        [{:headers, request_ref, [{":status", "200"}]}, {:data, request_ref, "held"}]}}
    )

    assert_receive {:adapter_event, ^guardian, {:headers, 200, []}}, 1_000
    assert_receive {:adapter_event, ^guardian, {:chunk, "held", ack}}, 1_000
    assert [_, 16, poll_opts] = await_operation(caller, :poll)
    assert poll_opts[:paused] == MapSet.new([request_ref])
    send(caller, {:public_return, {:ok, session, []}})
    send(guardian, {:DOWN, make_ref(), :process, self(), :normal})
    send(caller, {:DOWN, make_ref(), :process, guardian, :normal})
    assert %{delivery: ^ack, terminal: false} = snapshot(guardian)
    assert Process.alive?(caller)
    caller_monitor = Process.monitor(caller)
    endpoint_monitor = Process.monitor(endpoint)
    send(guardian, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
    assert_receive {:DOWN, ^endpoint_monitor, :process, ^endpoint, :normal}, 1_000
    # A queued authorized poll may have entered its whole-call barrier first.
    send(caller, {:public_return, {:ok, session, []}})
    assert_receive {:DOWN, ^caller_monitor, :process, ^caller, :normal}, 1_000
    refute_receive {:cleanup_complete, ^guardian}, 0
    refute_receive {:service_receipt, ^guardian, _}, 0
  end

  test "repeated unknown connect keeps one identity and drains supported hints without mailbox growth",
       %{ca: ca} do
    {guardian, monitor} = guardian(options(ca), driver(self()))
    assert_receive {:opened, ^guardian, upload}, 1_000
    assert_receive {:endpoint_created, creator, endpoint, descriptor}, 1_000
    send(creator, {:public_return, {:ok, descriptor}})
    assert_receive {:public_operation, caller, :connect, [session, _, _, _]}, 1_000
    original = snapshot(guardian)
    identity = make_ref()

    advanced =
      Enum.reduce(1..12, session, fn index, current ->
        assert {:message_queue_len, 0} = Process.info(caller, :message_queue_len)

        for _ <- 1..16,
            do: send(caller, {:quic_ready, :supported_hint, :binary.copy("x", index * 128)})

        assert {:message_queue_len, queued} = Process.info(caller, :message_queue_len)
        assert queued <= 16
        next = %{current | test_session: make_ref()}
        send(caller, {:public_return, {:unknown, next, identity}})
        assert [^next] = await_operation(caller, :resume)
        state = snapshot(guardian)
        assert state.operation.public_identity == identity
        assert state.deadline == original.deadline
        assert state.opening_deadline == original.opening_deadline
        next
      end)

    send(caller, {:public_return, {:ok, advanced}})
    assert [^advanced, _, :stream, _] = await_operation(caller, :request)
    request_ref = make_ref()
    send(caller, {:public_return, {:ok, advanced, request_ref}})
    finisher = finish_call(upload, [])
    assert [^advanced, ^request_ref, <<>>, true, _] = await_operation(caller, :send_data)
    send(caller, {:public_return, {:ok, advanced}})
    assert_receive {:finish_result, ^finisher, :ok}, 1_000
    assert [^advanced, 16, _] = await_operation(caller, :poll)

    send(
      caller,
      {:public_return,
       {:ok, advanced,
        [
          {:headers, request_ref, [{":status", "200"}]},
          {:data, request_ref, :binary.copy("x", 16_384)}
        ]}}
    )

    assert_receive {:adapter_event, ^guardian, {:headers, 200, []}}, 1_000
    assert_receive {:adapter_event, ^guardian, {:chunk, _, ack}}, 1_000
    assert [^advanced, 16, paused] = await_operation(caller, :poll)
    assert paused[:paused] == MapSet.new([request_ref])

    for index <- 1..12 do
      assert {:message_queue_len, 0} = Process.info(caller, :message_queue_len)

      for _ <- 1..16,
          do: send(caller, {:quic_ready, :supported_hint, :binary.copy("y", index * 128)})

      assert {:message_queue_len, queued} = Process.info(caller, :message_queue_len)
      assert queued <= 16
      send(caller, {:public_return, {:ok, advanced, []}})
      assert [^advanced, 16, paused] = await_operation(caller, :poll)
      assert paused[:paused] == MapSet.new([request_ref])
      assert %{delivery: ^ack, deadline: total, opening_deadline: opening} = snapshot(guardian)
      assert total == original.deadline
      assert opening == original.opening_deadline
    end

    assert {:message_queue_len, 0} = Process.info(caller, :message_queue_len)
    refute_receive {:adapter_event, ^guardian, {:chunk, _, _}}, 0
    refute_receive {:public_operation, _, :connect, _}, 0
    cleanup(guardian, monitor, endpoint)
    assert_receive {:cleanup_receipt, ^guardian, receipt}, 1_000
    assert_cleanup_receipt(receipt)
  end

  test "an advanced public error is retained before endpoint teardown", %{ca: ca} do
    {guardian, monitor, caller, endpoint, session, _upload} = connected(ca)
    assert [^session, _, :stream, _] = await_operation(caller, :request)
    advanced = %{session | test_session: make_ref()}
    send(caller, {:public_return, {:error, advanced, :indeterminate_admission}})
    assert_receive {:adapter_event, ^guardian, {:error, :indeterminate_admission}}, 1_000
    assert %{session: ^advanced, terminal: true} = snapshot(guardian)
    cleanup(guardian, monitor, endpoint)
    assert_receive {:cleanup_receipt, ^guardian, receipt}, 1_000
    assert_cleanup_receipt(receipt)
    refute_receive {:public_operation, _, :request, _}, 0
  end

  test "endpoint and caller DOWN cannot complete cleanup ahead of a deferred public stop result",
       %{ca: ca} do
    {guardian, monitor, caller, endpoint, _session, _upload} =
      connected(ca, driver(self(), :deferred))

    assert_receive {:public_operation, ^caller, :request, _}, 1_000
    caller_monitor = Process.monitor(caller)
    endpoint_monitor = Process.monitor(endpoint)
    send(guardian, {:begin_cleanup, true, Lifecycle.deadline(500)})
    assert_receive {:endpoint_stop, stopper, ^endpoint}, 1_000
    stopper_monitor = Process.monitor(stopper)
    send(endpoint, :stop)
    assert_receive {:DOWN, ^endpoint_monitor, :process, ^endpoint, :normal}, 1_000
    assert_receive {:DOWN, ^caller_monitor, :process, ^caller, :killed}, 1_000
    refute_receive {:cleanup_complete, ^guardian}, 0

    assert %{stop_result: nil, caller: %{down: :killed}, endpoint_down: :normal} =
             snapshot(guardian)

    send(stopper, {:public_return, :ok})
    assert_receive {:DOWN, ^stopper_monitor, :process, ^stopper, :normal}, 1_000
    assert_receive {:cleanup_complete, ^guardian}, 1_000
    assert_receive {:cleanup_receipt, ^guardian, receipt}, 1_000
    assert_cleanup_receipt(receipt)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
  end

  test "abnormal endpoint DOWN retains an actual Service reservation and never forges a receipt",
       %{ca: ca} do
    {runtime, owner, context, deadline} = native_owner()
    {guardian, monitor, caller, endpoint, _session, _upload} = connected(ca)
    assert_receive {:public_operation, ^caller, :request, _}, 1_000
    reservation = HTTP3SessionClient.reservation_bytes([], 50, 16_384)
    send(guardian, {:service_cleanup, context.service})
    _ = snapshot(guardian)
    send(owner, {:attach, guardian, reservation})
    assert_receive {:attached, {:ok, token}}, 1_000
    assert_receive {:cleanup_activated, ^guardian, ^token}, 1_000
    assert Lifecycle.remaining(deadline) > 0
    Process.exit(endpoint, :kill)
    assert_receive {:adapter_event, ^guardian, {:error, {:upstream_endpoint, :killed}}}, 1_000
    send(guardian, {:begin_cleanup, true, Lifecycle.deadline(200)})
    assert_receive {:endpoint_stop, _, ^endpoint}, 1_000
    assert_receive {:cleanup_failed, ^guardian, {:cleanup_unconfirmed, _}}, 1_000
    assert_receive {:cleanup_failure_receipt, ^guardian, receipt}, 1_000
    assert receipt.endpoint_down == :killed
    assert Enum.all?([receipt.bootstrap, receipt.caller, receipt.stop_task], &(&1.down != nil))
    assert %{cleanup_pending: 1, retained_bytes: retained} = Admission.status(context.gate)
    assert retained >= reservation
    refute_receive {:service_receipt, ^guardian, _}, 0
    refute_receive {:cleanup_complete, ^guardian}, 0
    service_monitor = Process.monitor(context.service)
    send(guardian, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
    assert_receive {:DOWN, ^service_monitor, :process, _, _}, 1_500
    assert {:error, :not_running} = Gaoxy.info(runtime, "h3-cleanup")
  end

  test "public done keeps caller and Service reservation until consumption confirms all owned teardown",
       %{ca: ca} do
    {runtime, owner, context, deadline} = native_owner()
    {guardian, monitor, caller, endpoint, session, request_ref, _upload} = finished_streaming(ca)
    reservation = HTTP3SessionClient.reservation_bytes([], 50, 16_384)
    send(guardian, {:service_cleanup, context.service})
    _ = snapshot(guardian)
    send(owner, {:attach, guardian, reservation})
    assert_receive {:attached, {:ok, token}}, 1_000
    assert_receive {:cleanup_activated, ^guardian, ^token}, 1_000
    assert Lifecycle.remaining(deadline) > 0
    assert [^session, 16, _] = await_operation(caller, :poll)

    send(
      caller,
      {:public_return,
       {:ok, session, [{:headers, request_ref, [{":status", "204"}]}, {:done, request_ref}]}}
    )

    assert_receive {:adapter_event, ^guardian, {:headers, 204, []}}, 1_000
    assert_receive {:adapter_event, ^guardian, :end}, 1_000
    assert Process.alive?(caller)
    assert Process.alive?(endpoint)
    assert %{cleanup_pending: 1, retained_bytes: retained} = Admission.status(context.gate)
    assert retained >= reservation
    refute_receive {:endpoint_stop, _, _}, 0
    refute_receive {:service_receipt, ^guardian, _}, 0
    cleanup(guardian, monitor, endpoint, false)
    assert_receive {:service_receipt, ^guardian, :ok}, 1_000
    assert_receive {:cleanup_receipt, ^guardian, receipt}, 1_000
    assert_cleanup_receipt(receipt)
    assert receipt.cleanup_cancelled == false
    assert receipt.cleanup_session_result == :ok
    Process.exit(owner, :kill)

    eventually(fn ->
      match?(%{active: 0, cleanup_pending: 0, retained_bytes: 0}, Admission.status(context.gate))
    end)

    assert match?(%{local: _}, Gaoxy.info(runtime, "h3-cleanup"))
  end

  test "idle abort precedes stop on its public result fallback or caller loss without extending cleanup",
       %{ca: ca} do
    observer = self()

    for stage <- [:released, :blocked, :caller_loss] do
      base = driver(observer, :deferred)

      controlled = fn
        QuicHttp3.Session, :abort, [session] ->
          send(observer, {:abort_entered, self(), session})
          public_reply()

        module, operation, arguments ->
          base.(module, operation, arguments)
      end

      {guardian, monitor, caller, endpoint, session, request_ref, _upload} =
        finished_streaming(ca, controlled)

      assert [^session, 16, _] = await_operation(caller, :poll)

      send(
        caller,
        {:public_return,
         {:ok, session, [{:headers, request_ref, [{":status", "204"}]}, {:done, request_ref}]}}
      )

      assert_receive {:adapter_event, ^guardian, :end}, 1_000
      supplied = Lifecycle.deadline(500)
      send(guardian, {:begin_cleanup, true, supplied})
      assert_receive {:abort_entered, ^caller, ^session}, 1_000
      state = snapshot(guardian)
      assert state.cleanup_deadline == min(supplied, state.deadline + 1_000)
      assert state.cleanup_stop_due <= Lifecycle.now() + 100
      refute_receive {:endpoint_stop, _, _}, 0

      case stage do
        :released -> send(caller, {:public_return, {:ok, session}})
        :blocked -> :ok
        :caller_loss -> Process.exit(caller, :kill)
      end

      assert_receive {:endpoint_stop, stopper, ^endpoint}, 250
      stopped = snapshot(guardian)
      expected = %{released: :public_result, blocked: :fallback, caller_loss: :caller_down}[stage]
      assert stopped.stop_trigger == expected
      assert stopped.cleanup_deadline == state.cleanup_deadline
      assert stopped.stop_result == nil
      refute_receive {:cleanup_complete, ^guardian}, 0
      send(stopper, {:public_return, :ok})
      assert_receive {:cleanup_complete, ^guardian}, 1_000
      assert_receive {:cleanup_receipt, ^guardian, receipt}, 1_000
      assert_cleanup_receipt(receipt)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
      if stage == :released, do: assert(receipt.cleanup_session_result == {:ok, session})
      if stage == :blocked, do: assert(receipt.cleanup_session_result == nil)
    end
  end

  defp finished_streaming(ca, public_driver \\ nil) do
    {guardian, monitor, caller, endpoint, session, request_ref, upload} =
      streaming(ca, public_driver)

    finisher = finish_call(upload, [])
    assert [_, ^request_ref, <<>>, true, _] = await_operation(caller, :send_data)
    send(caller, {:public_return, {:ok, session}})
    assert_receive {:finish_result, ^finisher, :ok}, 1_000
    {guardian, monitor, caller, endpoint, session, request_ref, upload}
  end

  defp assert_cleanup_receipt(receipt) do
    assert receipt.endpoint_down == :normal
    assert receipt.stop_result == :ok

    assert Enum.all?([receipt.bootstrap, receipt.caller, receipt.stop_task], fn
             nil -> true
             %{down: down} -> down != nil
           end)
  end

  defp connected(ca, public_driver \\ nil) do
    open_options = %{options(ca) | body: :chunked, headers: []}
    {guardian, monitor} = guardian(open_options, public_driver || driver(self()))
    assert_receive {:opened, ^guardian, upload}, 1_000
    assert_receive {:endpoint_created, creator, endpoint, descriptor}, 1_000
    creator_monitor = Process.monitor(creator)
    send(creator, {:public_return, {:ok, descriptor}})
    assert_receive {:DOWN, ^creator_monitor, :process, ^creator, :normal}, 1_000
    assert_receive {:public_operation, caller, :connect, [session, _, _, opts]}, 1_000
    assert opts[:consumer] == caller
    refute caller in [guardian, creator]
    send(caller, {:public_return, {:ok, session}})
    {guardian, monitor, caller, endpoint, session, upload}
  end

  defp streaming(ca, public_driver \\ nil) do
    {guardian, monitor, caller, endpoint, session, upload} = connected(ca, public_driver)
    assert_receive {:public_operation, ^caller, :request, [^session, fields, :stream, _]}, 1_000

    assert fields |> Enum.filter(fn {name, _} -> String.starts_with?(name, ":") end) == [
             {":method", "POST"},
             {":scheme", "https"},
             {":authority", "localhost"},
             {":path", "/escaped%2F?"}
           ]

    request_ref = make_ref()
    send(caller, {:public_return, {:ok, session, request_ref}})
    {guardian, monitor, caller, endpoint, session, request_ref, upload}
  end

  defp cleanup(guardian, monitor, endpoint, cancelled \\ true) do
    send(guardian, {:begin_cleanup, cancelled, Lifecycle.deadline(500)})
    assert_receive {:endpoint_stop, _, ^endpoint}, 1_000
    assert_receive {:cleanup_complete, ^guardian}, 1_000
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 1_000
  end

  defp upload_call(upload, bytes, timeout) do
    observer = self()

    pid =
      spawn(fn ->
        result = apply(HTTP3SessionClient, :write_body, [upload, bytes, timeout])
        send(observer, {:upload_result, self(), result})
      end)

    on_exit(fn -> stop(pid) end)
    pid
  end

  defp guardian(options, driver, lifecycle_barrier \\ nil) do
    assert Code.ensure_loaded?(HTTP3SessionClient)
    owner = self()

    {pid, monitor} =
      spawn_monitor(fn ->
        Process.flag(:trap_exit, true)
        Process.put(:lifecycle_barrier, lifecycle_barrier)
        {:ok, handle, upload} = apply(HTTP3SessionClient, :open, [options, driver])
        send(owner, {:opened, self(), upload})
        guardian_loop(handle, owner, false)
      end)

    on_exit(fn -> stop(pid) end)
    {pid, monitor}
  end

  defp guardian_loop(handle, owner, cleaning?) do
    receive do
      :finish ->
        :ok

      {:snapshot, observer, ref} ->
        send(observer, {:snapshot, self(), ref, handle})
        guardian_loop(handle, owner, cleaning?)

      {:ack, ref} ->
        next =
          case apply(HTTP3SessionClient, :acknowledge, [handle, ref]) do
            :ok -> handle
            {:ok, next} -> next
          end

        send(owner, {:acknowledged, self()})
        guardian_loop(next, owner, cleaning?)

      {:cleanup_check, observer} ->
        send(observer, {:cleanup_checked, self()})
        guardian_cleanup(handle, owner)

      {:service_cleanup, service} ->
        Process.put(:service_cleanup, service)
        guardian_loop(handle, owner, cleaning?)

      {:gaoxy_cleanup_activate, token} ->
        Process.put(:service_token, token)
        send(owner, {:cleanup_activated, self(), token})
        guardian_loop(handle, owner, cleaning?)

      {:gaoxy_cleanup_cancel, _token, _reason, deadline} ->
        {:ok, next} = apply(HTTP3SessionClient, :begin_cleanup, [handle, true, deadline])
        guardian_cleanup(next, owner)

      {:barrier, observer, ref} ->
        send(observer, {:barrier, self(), ref})
        guardian_loop(handle, owner, cleaning?)

      {:begin_cleanup, cancelled?, deadline} ->
        {:ok, next} = apply(HTTP3SessionClient, :begin_cleanup, [handle, cancelled?, deadline])
        send(owner, {:cleanup_started, self()})
        guardian_cleanup(next, owner)

      message ->
        {handle, message} = lifecycle_barrier(handle, message, owner)
        {event, next} = apply(HTTP3SessionClient, :event, [handle, message])
        if event != :none, do: send(owner, {:adapter_event, self(), event})

        if cleaning? or next.cleanup != :not_started,
          do: guardian_cleanup(next, owner),
          else: guardian_loop(next, owner, false)
    after
      2_000 -> raise "test guardian exceeded its finite lifetime"
    end
  end

  defp guardian_cleanup(handle, owner) do
    case apply(HTTP3SessionClient, :cleanup, [handle, true]) do
      {:pending, next} ->
        guardian_loop(next, owner, true)

      {:ok, next} ->
        if service = Process.get(:service_cleanup) do
          result = Service.complete_cleanup(service, Process.get(:service_token))
          send(owner, {:service_receipt, self(), result})
        end

        send(owner, {:cleanup_receipt, self(), next})
        send(owner, {:cleanup_complete, self()})

      {:error, reason, next} ->
        send(owner, {:cleanup_failure_receipt, self(), next})
        send(owner, {:cleanup_failed, self(), reason})
        if Process.get(:service_cleanup), do: guardian_loop(next, owner, false)
    end
  end

  defp lifecycle_barrier(handle, {:h3_endpoint, _, _, creator, _} = message, owner) do
    if Process.get(:lifecycle_barrier) == :adoption_ack do
      Process.delete(:lifecycle_barrier)
      true = :erlang.suspend_process(creator)

      try do
        {:none, adopted} = HTTP3SessionClient.event(handle, message)
        send(owner, {:lifecycle_barrier, self(), :adoption_ack, adopted})
        {barrier_control(adopted), :fixture_barrier_released}
      after
        if Process.alive?(creator), do: true = :erlang.resume_process(creator)
      end
    else
      {handle, message}
    end
  end

  defp lifecycle_barrier(
         %{bootstrap: %{pid: creator, monitor: monitor}} = handle,
         {:DOWN, monitor, :process, creator, :normal} = message,
         owner
       ) do
    if Process.get(:lifecycle_barrier) == :creator_down do
      Process.delete(:lifecycle_barrier)
      send(owner, {:lifecycle_barrier, self(), :creator_down, handle})
      {barrier_control(handle), message}
    else
      {handle, message}
    end
  end

  defp lifecycle_barrier(handle, message, _), do: {handle, message}

  defp barrier_control(handle) do
    receive do
      {:barrier_cleanup, deadline} ->
        {:ok, next} = HTTP3SessionClient.begin_cleanup(handle, true, deadline)
        next

      :barrier_release ->
        handle

      :barrier_finish ->
        exit(:normal)
    after
      500 -> raise "lifecycle barrier exceeded its original finite budget"
    end
  end

  # This double replaces only complete public calls. Its Session is opaque to
  # Gaoxy and its known endpoint models acceptor ownership without SDK state.
  defp driver(owner, stop_result \\ :ok, automatic_poll? \\ false) do
    fn
      QuicHttp3.Session, :new, [_opts] ->
        {:ok, %{test_session: make_ref()}}

      QuicHttp3.Transport.Quic, :client, [opts] ->
        acceptor = Keyword.fetch!(opts, :acceptor)
        endpoint = spawn_link(fn -> endpoint_loop(Process.monitor(acceptor)) end)
        descriptor = %{pid: endpoint}
        send(owner, {:endpoint_created, self(), endpoint, descriptor})
        public_reply()

      QuicHttp3.Transport.Quic, :stop_endpoint, [%{pid: endpoint}] ->
        send(owner, {:endpoint_stop, self(), endpoint})
        result = if stop_result == :deferred, do: public_reply(), else: stop_result

        if result == :ok do
          monitor = Process.monitor(endpoint)
          send(endpoint, :stop)

          receive do
            {:DOWN, ^monitor, :process, ^endpoint, reason} when reason in [:normal, :noproc] ->
              :ok
          after
            1_000 -> {:error, :test_endpoint_stop_timeout}
          end
        else
          result
        end

      QuicHttp3.Session, :ready, [_session] ->
        :ready

      QuicHttp3.Session, :open, [session] ->
        {:ok, session}

      QuicHttp3.Session, :abort, [session] ->
        {:ok, session}

      QuicHttp3.Session, :close, [_session] ->
        :ok

      QuicHttp3.Session, :poll, [session, _max, _opts] when automatic_poll? ->
        {:ok, session, []}

      QuicHttp3.Session, operation, arguments ->
        send(owner, {:public_operation, self(), operation, arguments})
        public_reply()
    end
  end

  defp public_reply do
    receive do
      {:public_return, result} -> result
    after
      2_000 -> raise "test public call was not released"
    end
  end

  defp endpoint_loop(acceptor_monitor) do
    receive do
      :stop ->
        :ok

      {:unlink_creator, creator, observer, ref} ->
        Process.unlink(creator)
        send(observer, {:creator_unlinked, self(), ref})
        endpoint_loop(acceptor_monitor)

      {:DOWN, ^acceptor_monitor, :process, _, _} ->
        :ok
    end
  end

  defp stop(pid) do
    monitor = Process.monitor(pid)
    if Process.alive?(pid), do: Process.exit(pid, :kill)

    receive do
      {:DOWN, ^monitor, :process, ^pid, _} -> :ok
    after
      1_000 -> raise "owned test process did not stop"
    end
  end

  # Public-operation doubles are scheduling regressions, not TLS/protocol proof.
  # The real Service/Admission fixture below exercises authenticated receipts.
  defmodule NativeCleanupOwner do
    use ThousandIsland.Handler

    def validate_options(%{owner: owner} = options) when is_pid(owner), do: {:ok, options}

    def handle_connection(_socket, state) do
      {:ok, lease} = Admission.acquire(state.gate, 10, drain_notify: true)
      deadline = Lifecycle.deadline(5_000)
      :ok = Admission.begin_request(state.gate, lease, 10, deadline)
      send(state.spec.handler_options.owner, {:native_owner, self(), state, deadline})
      {:continue, Map.merge(state, %{lease: lease, deadline: deadline})}
    end

    def handle_info({:attach, guardian, bytes}, {socket, state}) do
      result =
        Service.attach_cleanup(
          state.service,
          state.gate,
          state.lease,
          guardian,
          bytes,
          state.deadline
        )

      send(state.spec.handler_options.owner, {:attached, result})
      {:noreply, {socket, state}}
    end

    def handle_info({:gaoxy_drain, _, _, _}, {socket, state}),
      do: {:stop, :normal, {socket, state}}
  end

  defp native_owner do
    runtime =
      start_supervised!(
        {Gaoxy,
         services: [
           %{
             id: "h3-cleanup",
             transport: :tcp,
             handler_mode: :native,
             handler: NativeCleanupOwner,
             handler_options: %{owner: self()},
             limits: %{drain_timeout: 200, max_bytes: 4_194_304}
           }
         ]}
      )

    {:ok, {ip, port}} = Gaoxy.info(runtime, "h3-cleanup").local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    assert_receive {:native_owner, owner, context, deadline}, 1_000
    {runtime, owner, context, deadline}
  end

  defp eventually(fun, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(1_000)

    if fun.() do
      :ok
    else
      assert Lifecycle.remaining(deadline) > 0

      receive do
      after
        2 -> eventually(fun, deadline)
      end
    end
  end

  defp snapshot(guardian) do
    ref = make_ref()
    send(guardian, {:snapshot, self(), ref})
    assert_receive {:snapshot, ^guardian, ^ref, handle}, 1_000
    handle
  end

  defp await_operation(caller, operation, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(1_000)
    remaining = Lifecycle.remaining(deadline)
    assert remaining > 0, "public #{operation} exceeded finite test deadline"

    receive do
      {:public_operation, ^caller, ^operation, arguments} ->
        arguments

      {:public_operation, ^caller, :poll, [session, 16, _]} when operation != :poll ->
        send(caller, {:public_return, {:ok, session, []}})
        await_operation(caller, operation, deadline)
    after
      remaining -> flunk("expected public #{operation}")
    end
  end

  defp await_event(caller, guardian, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(1_000)
    remaining = Lifecycle.remaining(deadline)
    assert remaining > 0, "adapter event exceeded finite test deadline"

    receive do
      {:adapter_event, ^guardian, event} ->
        event

      {:public_operation, ^caller, :poll, [session, 16, _]} ->
        send(caller, {:public_return, {:ok, session, []}})
        await_event(caller, guardian, deadline)
    after
      remaining -> flunk("expected adapter event")
    end
  end

  defp finish_call(upload, trailers) do
    observer = self()

    pid =
      spawn(fn ->
        result = apply(HTTP3SessionClient, :finish_body, [upload, trailers])
        send(observer, {:finish_result, self(), result})
      end)

    on_exit(fn -> stop(pid) end)
    pid
  end

  defp options(ca) do
    %{
      url: "https://localhost:443/escaped%2F?",
      method: :post,
      headers: [{"content-length", "0"}],
      body: {:length, 0},
      cacertfile: ca,
      connect_address: nil,
      timeout: 1_000,
      opening_timeout: 1_000,
      deadline: Lifecycle.deadline(1_000),
      opening_deadline: Lifecycle.deadline(1_000),
      write_timeout: 100
    }
  end
end
