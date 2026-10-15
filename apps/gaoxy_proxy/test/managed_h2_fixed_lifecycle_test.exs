defmodule Gaoxy.Proxy.ManagedH2FixedLifecycleTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH2FixedFixture, as: F
  alias Gaoxy.Proxy.HTTP.Session
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports
  @client Gaoxy.Proxy.ManagedH2Client
  @moduletag :capture_log
  @timeout 5_000

  defmodule CapturedPinEndpoint do
    @behaviour Gaoxy.HTTP.Endpoint
    def init(options), do: Gaoxy.Proxy.HTTP.init(options)
    def resources(config), do: Gaoxy.Proxy.HTTP.resources(config)

    def call(exchange, config) do
      {:ok, pins} =
        Gaoxy.HTTP.Resources.pin_many([config.transport], self(), :request, exchange.deadline)

      try do
        Gaoxy.Proxy.HTTP.call(%{exchange | resource_pins: pins}, config)
      after
        :ok = Gaoxy.HTTP.Resources.release(pins)
      end
    end
  end

  defmodule MutatingEndpoint do
    @behaviour Gaoxy.HTTP.Endpoint
    def init(options) do
      {mutation, options} = Map.pop(options, :mutation)
      with {:ok, config} <- Gaoxy.Proxy.HTTP.init(options), do: {:ok, {mutation, config}}
    end

    def resources({_, config}), do: Gaoxy.Proxy.HTTP.resources(config)

    def call(exchange, {mutation, config}) do
      exchange =
        case mutation do
          :target ->
            %{exchange | request: %{exchange.request | target: "/mismatch", path: "/valid"}}

          :field_count ->
            %{
              exchange
              | request: %{exchange.request | headers: List.duplicate({"x-check", "x"}, 257)}
            }

          :improper ->
            %{exchange | request: %{exchange.request | headers: [{"x-check", "x"} | :improper]}}

          :backing ->
            backing = String.duplicate("accepted", 13) <> String.duplicate("x", 65_537)
            value = binary_part(backing, 0, 100)
            %{exchange | request: %{exchange.request | headers: [{"x-check", value}]}}

          :body ->
            %{
              exchange
              | request: %{exchange.request | body: {:length, 18_446_744_073_709_551_616}}
            }

          :limits ->
            %{exchange | limits: Map.put(exchange.limits, :max_headers, 0)}
        end

      Gaoxy.Proxy.HTTP.call(exchange, config)
    end
  end

  for mutation <- [:target, :field_count, :improper, :backing, :body, :limits] do
    @mutation mutation
    test "#{mutation} malformed request rejects400 before Session admission checkout upload or Fetch bytes" do
      f =
        F.fixture(:h2c, :http1, [], %{
          endpoint_module: MutatingEndpoint,
          endpoint: %{mutation: @mutation}
        })

      before = Transports.status(f.owner)
      assert :erlang.trace(f.owner, true, [:receive]) == 1
      assert %{status: 400} = F.request(f, "GET", "/valid")
      refute_receive {:trace, _, :receive, {:"$gen_call", _, {:checkout, _, _, _, _}}}, 0
      assert Transports.status(f.owner) == before
      F.no_event(f.peer, "accept")
      F.no_event(f.peer, "request")
      # This no-I/O fixture has no physical connection and consequently no EOF.
      stop_without_connection(f)
    end
  end

  test "a cancelled Session without Service activation never checks out or starts Fetch" do
    f = F.fixture(:h2c)

    assert {:ok, config} =
             Gaoxy.Proxy.HTTP.init(%{
               upstream: f.origin,
               upstream_protocol: :h2c,
               transport: f.handle
             })

    assert {:ok, session} = Session.start_link(session_args(f, config))
    Process.unlink(session)
    monitor = Process.monitor(session)
    state = :sys.get_state(session)
    assert state.token == nil
    assert state.request == nil
    assert state.original_request == nil
    assert state.transport_selection == nil
    assert {:ok, %{request_tokens: 0}} = Transports.status(f.owner)
    F.no_event(f.peer, "accept")
    Session.cancel(session)
    assert_receive {:DOWN, ^monitor, :process, ^session, :normal}, @timeout
    assert {:ok, %{request_tokens: 0, pins: 1}} = Transports.status(f.owner)
    stop_without_connection(f)
  end

  for protocol <- [:http2, :h2c] do
    @protocol protocol
    test "#{protocol} pending original completion retains token pins and combined Service reserve after consumption" do
      f = F.fixture(@protocol)
      {socket, _, guardian, completion} = F.hold(f)
      state = :sys.get_state(guardian)
      assert state.managed_path == true
      assert state.managed_transport == nil
      assert state.config.uri == nil
      assert state.selector == nil
      assert state.awaiting_transport == nil
      assert state.submitted_url == f.origin <> "/hold"
      assert state.client.completion(state.original_request) == completion

      assert Enum.sort(Map.keys(state.original_request)) == [
               :completion,
               :promise,
               :resolved,
               :stream
             ]

      assert Enum.sort(Map.keys(state.request)) == [:completion, :promise, :resolved, :stream]
      assert map_size(state.monitors) <= 4
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
      assert {:ok, %{request_tokens: 1, pins: 3, helpers: 0}} = Transports.status(f.owner)
      assert %{cleanup_pending: 1, retained_bytes: retained} = Gaoxy.status(f.instance, :http)
      assert retained >= 9_444_956
      Session.consumed(guardian)
      F.eventually(fn -> :sys.get_state(guardian).consumed end)
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
      assert {:ok, %{request_tokens: 1, pins: 3}} = Transports.status(f.owner)
      assert %{cleanup_pending: 1, retained_bytes: ^retained} = Gaoxy.status(f.instance, :http)
      monitor = Process.monitor(guardian)
      Session.cancel(guardian)
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout
      assert :ok = HTTP.RequestCompletion.abort_and_await(completion, 0)
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      # Request cancellation must leave the shared physical connection usable.
      assert %{status: 200, body: "/sibling"} = F.request(f, "GET", "/sibling")
      assert %{"connection" => 1} = F.event(f.peer, "request")
      F.close(f)
    end

    test "#{protocol} one tracked poll timer and residual submitted URL clear at validated head" do
      f = F.fixture(@protocol, :http1, ["--manual"])
      {socket, seen, guardian, completion} = F.hold(f)
      state = :sys.get_state(guardian)
      assert is_reference(state.poll_timer)
      for _ <- 1..16, do: send(guardian, :poll)
      :sys.get_state(guardian)
      state = :sys.get_state(guardian)
      assert is_reference(state.poll_timer)
      assert state.submitted_url == f.origin <> "/hold"
      :ok = :sys.suspend(guardian)

      try do
        paused = :sys.get_state(guardian)
        assert is_reference(paused.poll_timer)

        F.eventually(fn ->
          {:messages, messages} = Process.info(guardian, :messages)
          Process.read_timer(paused.poll_timer) == false and :poll in messages
        end)

        {:messages, messages} = Process.info(guardian, :messages)
        assert Enum.count(messages, &(&1 == :poll)) == 1
      after
        :ok = :sys.resume(guardian)
      end

      F.command(f.peer, seen, "respond", %{"fields" => [["content-length", "0"]]})
      assert %{status: 200, body: ""} = F.response(f, socket)
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      assert :ok = HTTP.RequestCompletion.await(completion, 0)
      F.close(f)
    end

    test "#{protocol} timed-out opening aborts and joins original completion with no replay" do
      f =
        F.fixture(@protocol, :http1, ["--manual"], %{
          endpoint: %{opening_timeout: 100, max_lifetime: 2_000}
        })

      socket = F.connect(f)
      :ok = F.send_request(f, socket, "GET", "/hold")
      F.event(f.peer, "request")

      F.eventually(fn ->
        Enum.any?(:sys.get_state(f.owner).tokens, fn {_, hold} ->
          match?(%HTTP.RequestCompletion{}, hold.completion)
        end)
      end)

      [held] = :sys.get_state(f.owner).tokens |> Map.values()
      monitor = Process.monitor(held.guardian)
      assert %{status: 504} = F.response(f, socket)
      assert :ok = HTTP.RequestCompletion.await(held.completion, @timeout)
      assert_receive {:DOWN, ^monitor, :process, _, reason}, @timeout
      assert reason in [:normal, :noproc]
      F.no_event(f.peer, "request")
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      F.close_aborted(f, 1)
    end
  end

  test "authenticated public DATA accepts16385 65536 and1MiB and rejects logical/backing excess before copying" do
    f = F.fixture(:h2c)
    {socket, _, guardian, completion} = F.hold(f)
    original = :sys.get_state(guardian).original_request
    handle = %{original | stream: self(), resolved: true}

    for count <- [16_385, 65_536, 1_048_576] do
      bytes =
        :binary.copy(<<0, 255>>, div(count, 2)) <> if(rem(count, 2) == 1, do: <<0>>, else: "")

      ref = make_ref()

      assert {{:chunk, ^bytes, ^ref}, ^handle} =
               client(:event, [{handle, nil}, {:stream_chunk, self(), bytes, ref}])
    end

    over = :binary.copy("x", 1_048_577)
    retained = binary_part(over, 0, 1_048_576)
    assert :binary.referenced_byte_size(retained) > 1_048_576

    for bytes <- [over, retained, ["wrong-type"]] do
      assert {{:error, :upstream_delivery_limit}, ^handle} =
               client(:event, [{handle, nil}, {:stream_chunk, self(), bytes, make_ref()}])
    end

    # An unauthenticated stream never reaches payload validation or changes state.
    assert {:none, ^handle} =
             client(:event, [{handle, nil}, {:stream_chunk, guardian, over, make_ref()}])

    cancel_and_join(f, socket, guardian, completion)
  end

  test "authenticated terminal Headers enforce128 fields before cache and reject malformed backing" do
    f = F.fixture(:h2c)
    {socket, _, guardian, completion} = F.hold(f)
    handle = %{:sys.get_state(guardian).original_request | stream: self(), resolved: true}
    fields = for index <- 1..128, do: {"x-check", Integer.to_string(index)}

    assert {{:trailers, ^fields}, ^handle} =
             client(:event, [
               {handle, nil},
               {:stream_trailers, self(), %HTTP.Headers{headers: fields}}
             ])

    backing = String.duplicate("accepted", 13) <> String.duplicate("x", 65_537)
    retained = binary_part(backing, 0, 100)
    assert :binary.referenced_byte_size(retained) > 65_536

    for raw <- [
          %HTTP.Headers{headers: fields ++ [{"x-check", "129"}]},
          %HTTP.Headers{headers: [{"x-check", retained}]},
          %HTTP.Headers{headers: [{"x-check", "x"} | :improper]},
          Map.put(%HTTP.Headers{}, :extra, true),
          fields
        ] do
      assert {{:error, reason}, ^handle} =
               client(:event, [{handle, nil}, {:stream_trailers, self(), raw}])

      assert reason in [:upstream_trailer_limit, :invalid_response]
    end

    cancel_and_join(f, socket, guardian, completion)
  end

  test "authenticated metadata and raw task errors normalize before Session or pump cache" do
    f = F.fixture(:h2c)
    {socket, _, guardian, completion} = F.hold(f)
    handle = :sys.get_state(guardian).original_request
    ref = handle.promise.task.ref
    submitted_url = :binary.copy(f.origin <> "/hold")

    response = %HTTP.Response{
      status: 200,
      http_version: :http2,
      stream: self(),
      body: self(),
      url: URI.parse(submitted_url)
    }

    for raw <- [
          Map.put(response, :extra, String.duplicate("x", 65_537)),
          %{response | http_version: :http1},
          %{response | status: 199},
          %{response | url: URI.parse("http://attacker.invalid/hold")},
          %{response | headers: %HTTP.Headers{headers: List.duplicate({"x-check", "x"}, 257)}},
          %{response | informational: List.duplicate({103, %HTTP.Headers{}}, 129)},
          %{response | body: "buffered"}
        ] do
      assert {{:error, :invalid_response}, updated} =
               client(:event, [{handle, submitted_url}, {ref, raw}])

      assert client(:completion, [updated]) == completion
      assert Enum.sort(Map.keys(updated)) == [:completion, :promise, :resolved, :stream]
    end

    for reason <- [
          String.duplicate("secret", 1024),
          %{unbounded: make_ref()},
          {:error, fn -> :secret end}
        ] do
      assert {{:error, finite}, updated} =
               client(:event, [
                 {handle, submitted_url},
                 {:DOWN, ref, :process, handle.promise.task.pid, reason}
               ])

      assert finite in [:upstream_task, :upstream_failure]
      assert client(:completion, [updated]) == completion
    end

    assert {:none, ^handle} =
             client(:event, [{handle, submitted_url}, {make_ref(), response}])

    cancel_and_join(f, socket, guardian, completion)
  end

  for action <- [:disconnect, :pump_owner_death, :session_cancel] do
    @action action
    test "#{action} joins a real held completion and preserves healthy connection siblings" do
      f = F.fixture(:h2c)
      {socket, _, guardian, completion} = F.hold(f)
      monitor = Process.monitor(guardian)

      case @action do
        :disconnect -> :gen_tcp.close(socket)
        :pump_owner_death -> Process.exit(:sys.get_state(guardian).owner, :kill)
        :session_cancel -> Session.cancel(guardian)
      end

      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      assert %{status: 200, body: "/healthy"} = F.request(f, "GET", "/healthy")
      assert %{"connection" => 1} = F.event(f.peer, "request")
      F.close(f)
    end
  end

  test "whole downstream write precedes exactly one ACK and failed write sends no ACK" do
    for failed <- [false, true] do
      f = F.fixture(:h2c, :http1, ["--manual"])
      {socket, seen, guardian, completion} = F.hold(f)
      pump = :sys.get_state(guardian).owner
      assert :erlang.trace(guardian, true, [:send]) == 1
      assert :erlang.suspend_process(pump)

      try do
        F.command(f.peer, seen, "respond", %{
          "ended" => false,
          "fields" => [["content-length", "65536"]]
        })

        F.command(f.peer, seen, "data", %{
          "body64" => Base.encode64(String.duplicate("d", 65_536)),
          "ended" => true
        })

        F.eventually(fn -> :sys.get_state(guardian).delivery != nil end)
        state = :sys.get_state(guardian)
        stream = state.request.stream
        ref = state.delivery
        refute_receive {:trace, ^guardian, :send, {:stream_chunk_ack, ^ref}, ^stream}, 0
        assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
        assert {:ok, %{request_tokens: 1, pins: 3}} = Transports.status(f.owner)
        if failed, do: :ok = :gen_tcp.close(socket)
        assert :erlang.resume_process(pump)

        if failed do
          assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
          F.clean(f)
          refute_receive {:trace, ^guardian, :send, {:stream_chunk_ack, ^ref}, ^stream}, 0
        else
          assert %{status: 200, body: bytes} = F.response(f, socket)
          assert bytes == String.duplicate("d", 65_536)
          assert_receive {:trace, ^guardian, :send, {:stream_chunk_ack, ^ref}, ^stream}, @timeout
          refute_receive {:trace, ^guardian, :send, {:stream_chunk_ack, ^ref}, ^stream}, 0
          :ok = :gen_tcp.close(socket)
          F.clean(f)
        end
      after
        if Process.alive?(pump), do: safe_resume(pump)
      end

      if failed, do: F.close_aborted(f, 1), else: F.close(f)
    end
  end

  test "overlapping authenticated DATA fails without retaining a second event" do
    f = F.fixture(:h2c, :http1, ["--manual"])
    {socket, seen, guardian, completion} = F.hold(f)
    pump = :sys.get_state(guardian).owner
    assert :erlang.suspend_process(pump)

    try do
      F.command(f.peer, seen, "respond", %{"ended" => false})
      F.command(f.peer, seen, "data", %{"body64" => Base.encode64("first"), "ended" => false})
      F.eventually(fn -> :sys.get_state(guardian).delivery != nil end)
      stream = :sys.get_state(guardian).request.stream
      send(guardian, {:stream_chunk, stream, "second", make_ref()})
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert :erlang.resume_process(pump)
      :ok = :gen_tcp.close(socket)
      F.clean(f)
    after
      if Process.alive?(pump), do: safe_resume(pump)
    end

    F.close_aborted(f, 1)
  end

  test "native-valid terminal trailer129 rejects before Session cache or successful downstream termination" do
    f = F.fixture(:h2c, :http1, ["--manual"])
    {socket, seen, guardian, completion} = F.hold(f)
    F.command(f.peer, seen, "respond", %{"fields" => [["trailer", "x-check"]], "ended" => false})
    assert F.h1_head(socket) =~ "200 OK"
    fields = for index <- 1..129, do: ["x-check", Integer.to_string(index)]

    F.command(f.peer, seen, "data", %{
      "body64" => Base.encode64("wire"),
      "trailers" => fields,
      "ended" => true
    })

    bytes = F.until_closed(socket)
    refute bytes =~ "x-check: 129"
    refute String.ends_with?(bytes, "0\r\n\r\n")
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
    monitor = Process.monitor(guardian)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, reason}, @timeout
    assert reason in [:normal, :noproc]
    F.clean(f)
    F.close(f)
  end

  test "exact128 native trailer fields retain ordered duplicates through downstream completion" do
    f = F.fixture(:h2c, :http1, ["--manual"])
    {socket, seen, _, completion} = F.hold(f)
    fields = for index <- 1..128, do: ["x-check", Integer.to_string(index)]

    F.command(f.peer, seen, "respond", %{
      "fields" => [["trailer", "x-check"]],
      "body64" => Base.encode64("wire"),
      "trailers" => fields
    })

    assert %{status: 200, body: "wire", trailers: trailers} = F.response(f, socket)
    assert trailers == Enum.map(fields, &List.to_tuple/1)
    :ok = :gen_tcp.close(socket)
    F.clean(f)
    assert :ok = HTTP.RequestCompletion.await(completion, 0)
    F.close(f)
  end

  test "native informational128 blocks validate before final head and129 rejects with finite502" do
    for count <- [128, 129] do
      f = F.fixture(:h2c, :http1, ["--manual"])
      {socket, seen, _, completion} = F.hold(f)

      for _ <- 1..count,
          do:
            F.command(f.peer, seen, "inform", %{
              "status" => 103,
              "fields" => [["link", "</asset>"]]
            })

      if count == 128,
        do: F.command(f.peer, seen, "respond", %{"fields" => [["content-length", "0"]]})

      expected = if count == 128, do: 200, else: 502
      assert %{status: ^expected} = F.response(f, socket)
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      assert :ok = HTTP.RequestCompletion.await(completion, 0)
      F.close(f)
    end
  end

  test "native final255 regular fields plus status fit its256 decoded-field boundary" do
    f = F.fixture(:h2c, :http1, ["--manual"])
    {socket, seen, _, completion} = F.hold(f)
    fields = for index <- 1..255, do: ["x-check", Integer.to_string(index)]
    F.command(f.peer, seen, "respond", %{"fields" => fields})
    assert %{status: 200, headers: forwarded} = F.response(f, socket)

    assert Enum.filter(forwarded, &(elem(&1, 0) == "x-check")) ==
             Enum.map(fields, &List.to_tuple/1)

    :ok = :gen_tcp.close(socket)
    F.clean(f)
    assert :ok = HTTP.RequestCompletion.await(completion, 0)
    F.close(f)
  end

  for count <- [256, 257] do
    @native_field_count count
    test "native #{@native_field_count} regular fields rejects HPACK before the adapter and retains cleanup uncertainty" do
      f = F.fixture(:h2c, :http1, ["--manual"])
      {socket, seen, guardian, completion} = F.hold(f)
      {:ok, service, _} = GenServer.call(f.instance, {:lookup, :http})
      state = :sys.get_state(guardian)
      barrier = uncertain_service_down_barrier(service, guardian, state.token)
      {_, token} = state.transport_selection
      assert :sys.get_state(f.owner).tokens[token].completion == completion
      custodians = :sys.get_state(f.owner).records |> Map.values() |> Enum.map(& &1.custodian)
      on_exit(fn -> dispose_failed_gaoxy_actors([f.owner | custodians]) end)
      original = :sys.get_state(guardian).original_request
      ref = original.promise.task.ref
      monitor = Process.monitor(guardian)
      assert :erlang.trace(guardian, true, [:receive]) == 1
      fields = for index <- 1..@native_field_count, do: ["x-check", Integer.to_string(index)]
      F.command(f.peer, seen, "respond", %{"fields" => fields})

      assert_receive {:trace, ^guardian, :receive,
                      {^ref, {:error, {:transport_error, {:hpack, :hpack_field_count_exceeded}}}}},
                     @timeout

      assert %{status: 502, body: ""} = F.response(f, socket)

      assert_receive {:DOWN, ^monitor, :process, ^guardian,
                      {:cleanup_failed, :cleanup_unconfirmed}},
                     @timeout

      assert_receive {:fixed_h2_service_down_held, ^service, ^guardian,
                      {:cleanup_failed, :cleanup_unconfirmed}},
                     @timeout

      assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, @timeout)

      assert {:error, :cleanup_unconfirmed} =
               HTTP.RequestCompletion.abort_and_await(completion, 0)

      assert {:ok, %{request_tokens: 1}} = Transports.status(f.owner)
      refute_receive {:fixed_h2_service_receipt, ^service, ^guardian}, 0
      F.no_event(f.peer, "request")
      :ok = :gen_tcp.close(socket)
      # Missing public cleanup evidence remains a failed shutdown, even though
      # the independent peer can prove physical termination and zero replay.
      stop_uncertain_service(f, service, barrier, guardian, token, completion, custodians)
    end
  end

  test "GOAWAY never replays a failed request and a later request opens a healthy connection" do
    f = F.fixture(:h2c, :http1, ["--manual"])
    {socket, seen, _, completion} = F.hold(f)
    F.command(f.peer, seen, "goaway", %{"last_stream" => 0, "code" => 0})
    assert %{status: 502} = F.response(f, socket)
    :ok = :gen_tcp.close(socket)
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
    F.clean(f)
    F.no_event(f.peer, "request")
    {second, next, _, next_completion} = F.hold(f, "/hold/later")
    refute next["connection"] == seen["connection"]
    F.command(f.peer, next, "respond", %{"fields" => [["content-length", "0"]]})
    assert %{status: 200} = F.response(f, second)
    :ok = :gen_tcp.close(second)
    F.clean(f)
    assert :ok = HTTP.RequestCompletion.await(next_completion, 0)
    F.close(f)
  end

  test "public producer death aborts the request and joins its original completion" do
    f = F.fixture(:h2c, :http1, ["--manual"])
    barrier = owner_barrier(f.owner, :bind_completion)
    socket = F.connect(f)
    :ok = F.send_request(f, socket, "POST", "/echo", [{"content-length", "3"}], false)

    assert_receive {:fixed_h2_owner_held, _, guardian, {:bind_completion, _, _, completion}},
                   @timeout

    assert %HTTP.RequestCompletion{} = completion
    assert :erlang.trace(guardian, true, [:send]) == 1
    refute_receive {:trace, ^guardian, :send, {:gaoxy_proxy_http, _, {:ready, _, _, _}}, _}, 0
    send(f.owner, {:fixed_h2_continue, barrier})

    assert_receive {:trace, ^guardian, :send,
                    {:gaoxy_proxy_http, ^guardian, {:ready, upload, _, _}}, _},
                   @timeout

    assert is_pid(upload)
    assert %{"target" => "/echo"} = F.event(f.peer, "request")
    monitor = Process.monitor(upload)
    Process.exit(upload, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^upload, :killed}, @timeout
    assert %{status: 502} = F.response(f, socket)
    :ok = :gen_tcp.close(socket)
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
    F.clean(f)
    F.close_aborted(f, 1)
  end

  test "bounded instance stop joins a held original completion and every owner helper" do
    f = F.fixture(:h2c)
    {socket, _, guardian, completion} = F.hold(f)
    monitor = Process.monitor(guardian)
    assert :ok = Gaoxy.stop(f.instance, @timeout)
    assert :ok = HTTP.RequestCompletion.await(completion, 0)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout
    :ok = :gen_tcp.close(socket)
    F.physical_termination(f.peer)
    monitor = Process.monitor(f.embedding)
    send(f.embedding, {:stop, self()})
    assert_receive {:fixed_h2_embedding_stopped, _, {:error, :not_running}}, @timeout
    assert_receive {:DOWN, ^monitor, :process, _, :normal}, @timeout
    monitor = Process.monitor(f.peer)
    send(f.peer, {:command, %{"op" => "stop"}})

    assert %{"forced" => 0, "live" => 0, "failed" => false, "requests" => 1} =
             F.event(f.peer, "joined")

    assert_receive {:fixed_h2_peer_exit, _, 0}, @timeout
    assert_receive {:DOWN, ^monitor, :process, _, :normal}, @timeout
  end

  test "exact seven-key open receives the original eight-key envelope and checked client before original binding" do
    f = F.fixture(:h2c, :http1, ["--manual"])
    barrier = owner_barrier(f.owner, :checkout)
    socket = F.connect(f)

    :ok =
      F.send_request(
        f,
        socket,
        "POST",
        "/echo?",
        [{"content-length", "3"}, {"x-check", "first"}, {"x-check", "second"}],
        false
      )

    assert_receive {:fixed_h2_owner_held, _, guardian, {:checkout, _, _, _, _}}, @timeout
    assert :erlang.trace_pattern({@client, :open, 1}, true, [:local]) == 1
    on_exit(fn -> :erlang.trace_pattern({@client, :open, 1}, false, [:local]) end)
    assert :erlang.trace(guardian, true, [:call, :send]) == 1
    send(f.owner, {:fixed_h2_continue, barrier})
    assert_receive {:trace, ^guardian, :call, {@client, :open, [options]}}, @timeout

    assert Enum.sort(Map.keys(options)) == [
             :deadline,
             :managed_transport,
             :opening_deadline,
             :opening_timeout,
             :request,
             :timeout,
             :write_timeout
           ]

    assert Enum.sort(Map.keys(options.request)) == [
             :body_mode,
             :fields,
             :max_upload_bytes,
             :method,
             :protocol,
             :request_limits,
             :target,
             :url
           ]

    assert Enum.sort(Map.keys(options.managed_transport)) == [
             :fetch_options,
             :policy,
             :transport_scope
           ]

    assert options.request.protocol == :h2c
    assert options.request.target == "/echo?"
    assert options.request.url == f.origin <> "/echo?"
    assert options.request.body_mode == {:length, 3}

    assert Enum.filter(options.request.fields, &(elem(&1, 0) in ["content-length", "x-check"])) ==
             [{"content-length", "3"}, {"x-check", "first"}, {"x-check", "second"}]

    assert options.request.request_limits == %{
             max_headers: 256,
             max_header_bytes: 65_536,
             max_trailers: 128,
             max_trailer_bytes: 65_536
           }

    assert options.opening_deadline <= options.deadline
    assert %{"target" => "/echo?"} = F.event(f.peer, "request")

    assert_receive {:trace, ^guardian, :send,
                    {:gaoxy_proxy_http, ^guardian, {:ready, upload, _, _}}, _},
                   @timeout

    assert is_pid(upload)
    [hold] = :sys.get_state(f.owner).tokens |> Map.values()
    assert %HTTP.RequestCompletion{} = hold.completion
    state = :sys.get_state(guardian)
    assert state.client.completion(state.original_request) == hold.completion
    assert state.request_options == nil
    assert state.managed_transport == nil
    F.no_event(f.peer, "upload")
    cancel_and_join(f, socket, guardian, hold.completion)
  end

  test "validated response head clears submitted URL while preserving original cleanup identity" do
    f = F.fixture(:h2c, :http1, ["--manual"])
    {socket, seen, guardian, completion} = F.hold(f)
    assert :sys.get_state(guardian).submitted_url == f.origin <> "/hold"
    F.command(f.peer, seen, "respond", %{"fields" => [["content-length", "5"]], "ended" => false})
    assert F.h1_head(socket) =~ "200 OK"
    F.eventually(fn -> :sys.get_state(guardian).headers end)
    state = :sys.get_state(guardian)
    assert state.submitted_url == nil
    assert state.managed_path == true
    assert state.managed_transport == nil
    assert state.client.completion(state.request) == completion
    assert state.client.completion(state.original_request) == completion
    assert state.poll_timer == nil
    F.command(f.peer, seen, "data", %{"body64" => Base.encode64("final"), "ended" => true})
    assert {:ok, "final"} = :gen_tcp.recv(socket, 5, @timeout)
    :ok = :gen_tcp.close(socket)
    F.clean(f)
    assert :ok = HTTP.RequestCompletion.await(completion, 0)
    F.close(f)
  end

  test "upload65536 reaches a public Stream while65537 and retained backing reject without a chunk message" do
    assert {:ok, upload} = HTTP.Stream.start_link(0)
    Process.unlink(upload)
    upload_monitor = Process.monitor(upload)

    on_exit(fn ->
      if Process.alive?(upload) do
        monitor = Process.monitor(upload)
        HTTP.Stream.stop(upload, :cancelled)
        assert_receive {:DOWN, ^monitor, :process, ^upload, :normal}, @timeout
      end
    end)

    over = :binary.copy("u", 65_537)
    retained = binary_part(over, 0, 65_536)
    assert :binary.referenced_byte_size(retained) > 65_536
    assert :erlang.trace(upload, true, [:receive]) == 1

    for bytes <- [over, retained, ["improper-type"]] do
      assert {:error, :invalid_request} = client(:write_body, [upload, bytes, @timeout])
      refute_receive {:trace, ^upload, :receive, {:chunk, _, _, _}}, 0
    end

    caller = self()
    bytes = :binary.copy("u", 65_536)

    writer =
      spawn(fn ->
        send(
          caller,
          {:upload_write_result, self(), client(:write_body, [upload, bytes, @timeout])}
        )
      end)

    writer_monitor = Process.monitor(writer)
    send(upload, {:read_chunk, self(), :ack})
    assert_receive {:stream_chunk, ^upload, ^bytes, ack}, @timeout
    send(upload, {:stream_chunk_ack, ack})
    assert_receive {:upload_write_result, ^writer, :ok}, @timeout
    assert_receive {:DOWN, ^writer_monitor, :process, ^writer, :normal}, @timeout
    assert :ok = client(:finish_body, [upload, []])
    assert_receive {:stream_end, ^upload}, @timeout
    assert_receive {:DOWN, ^upload_monitor, :process, ^upload, :normal}, @timeout
  end

  test "Session death retains owner token and Service budget until real completion then reports missing receipt" do
    f = F.fixture(:h2c)
    {socket, _, guardian, completion} = F.hold(f)
    {:ok, service, _} = GenServer.call(f.instance, {:lookup, :http})
    service_barrier = service_down_barrier(service, guardian)
    owner_barrier = owner_down_barrier(f.owner, guardian)
    [hold] = :sys.get_state(f.owner).tokens |> Map.values()
    assert hold.completion == completion
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
    assert %{cleanup_pending: 1, retained_bytes: retained} = Gaoxy.status(f.instance, :http)
    assert retained >= 9_444_956
    monitor = Process.monitor(guardian)
    Process.exit(guardian, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :killed}, @timeout
    assert_receive {:fixed_h2_service_down_held, ^service, ^guardian, :killed}, @timeout
    assert_receive {:fixed_h2_owner_down_held, _, ^guardian}, @timeout
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
    refute_receive {:fixed_h2_service_receipt, ^service, ^guardian}, 0
    # The owner ledger is deliberately held at DOWN: only its original public
    # completion, rather than Session death, may authorize its abort/refund.
    send(f.owner, {:fixed_h2_owner_down_continue, owner_barrier})
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)

    F.eventually(fn ->
      match?({:ok, %{request_tokens: 0, pins: 1, helpers: 0}}, Transports.status(f.owner))
    end)

    refute_receive {:fixed_h2_service_receipt, ^service, ^guardian}, 0
    :ok = :gen_tcp.close(socket)
    stop_failed_service(f, service, service_barrier)
  end

  test "transport owner death at original binding joins public completion but cannot issue Service receipt" do
    f = F.fixture(:h2c, :http1, ["--manual"])
    {:ok, service, _} = GenServer.call(f.instance, {:lookup, :http})
    [custodian] = :sys.get_state(f.owner).records |> Map.values() |> Enum.map(& &1.custodian)
    custodian_barrier = custodian_owner_down_barrier(custodian, f.owner)
    custodian_monitor = Process.monitor(custodian)
    barrier = owner_barrier(f.owner, :bind_completion)
    socket = F.connect(f)
    :ok = F.send_request(f, socket, "GET", "/hold")

    assert_receive {:fixed_h2_owner_held, _, guardian, {:bind_completion, _, _, completion}},
                   @timeout

    service_barrier = service_down_barrier(service, guardian)
    assert %HTTP.RequestCompletion{} = completion
    assert %{"target" => "/hold"} = F.event(f.peer, "request")
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
    # Keep the original scope creator alive until Session joins its original
    # request; scope retirement must not race away that public evidence.
    assert :erlang.suspend_process(guardian)
    on_exit(fn -> safe_resume(guardian) end)
    owner_monitor = Process.monitor(f.owner)
    guardian_monitor = Process.monitor(guardian)
    Process.exit(f.owner, :kill)
    assert_receive {:DOWN, ^owner_monitor, :process, _, :killed}, @timeout
    assert_receive {:fixed_h2_custodian_owner_down_held, ^custodian}, @timeout
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
    send(f.owner, {:fixed_h2_continue, barrier})
    safe_resume(guardian)

    assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian,
                    {:cleanup_failed, {:transport_cleanup_failed, :unavailable}}},
                   @timeout

    assert_receive {:fixed_h2_service_down_held, ^service, ^guardian,
                    {:cleanup_failed, {:transport_cleanup_failed, :unavailable}}},
                   @timeout

    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
    refute_receive {:fixed_h2_service_receipt, ^service, ^guardian}, 0
    send(custodian, {:fixed_h2_custodian_owner_down_continue, custodian_barrier})
    assert_receive {:DOWN, ^custodian_monitor, :process, ^custodian, :normal}, @timeout
    assert :ok = HTTP.RequestCompletion.await(completion, 0)
    :ok = :gen_tcp.close(socket)
    stop_failed_service(f, service, service_barrier, true)
  end

  test "cancelled late authenticated handoff is revoked before checkout and emits no Fetch bytes" do
    f = F.fixture(:h2c, :http1, [], %{endpoint_module: CapturedPinEndpoint})
    barrier = owner_barrier(f.owner, :delegate_request_pin)
    socket = F.connect(f)
    :ok = F.send_request(f, socket, "GET", "/late")

    assert_receive {:fixed_h2_owner_held, _, pump,
                    {:delegate_request_pin, _, source_pin, guardian, _, _, operation, _}},
                   @timeout

    assert is_reference(operation)
    assert source_pin.holder == pump
    assert source_pin.kind == :request
    assert source_pin.handles == [f.handle]
    assert :sys.get_state(guardian).awaiting_transport != nil
    assert :sys.get_state(guardian).original_request == nil
    guardian_monitor = Process.monitor(guardian)
    Session.cancel(guardian)
    assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
    send(f.owner, {:fixed_h2_continue, barrier})
    # The still-authenticated original pump must process the late result and
    # revoke/cancel the same operation before its captured source pin releases.
    F.eventually(fn ->
      match?({:ok, %{request_tokens: 0, pins: 1, helpers: 0}}, Transports.status(f.owner))
    end)

    F.no_event(f.peer, "accept")
    F.no_event(f.peer, "request")
    :ok = :gen_tcp.close(socket)
    F.clean(f)
    stop_without_connection(f)
  end

  defp service_down_barrier(service, guardian) do
    caller = self()
    barrier = make_ref()

    debug = fn state, event, _ ->
      case event do
        {:in, {:"$gen_call", {^guardian, _}, {:complete_cleanup, _}}} ->
          send(caller, {:fixed_h2_service_receipt, self(), guardian})

        {:in, {:DOWN, _, :process, ^guardian, reason}} ->
          send(caller, {:fixed_h2_service_down_held, self(), guardian, reason})

          receive do
            {:fixed_h2_service_down_continue, ^barrier} -> :ok
          after
            @timeout -> raise "Service DOWN barrier expired"
          end

        _ ->
          :ok
      end

      state
    end

    :ok = :sys.install(service, {debug, nil})
    on_exit(fn -> send(service, {:fixed_h2_service_down_continue, barrier}) end)
    barrier
  end

  defp uncertain_service_down_barrier(service, guardian, token) do
    caller = self()
    barrier = make_ref()

    debug = fn phase, event, _ ->
      case {phase, event} do
        {_, {:in, {:"$gen_call", {^guardian, _}, {:complete_cleanup, _}}}} ->
          send(caller, {:fixed_h2_service_receipt, self(), guardian})
          phase

        {:start, {:in, {:DOWN, _, :process, ^guardian, reason}}} ->
          send(caller, {:fixed_h2_service_down_held, self(), guardian, reason})
          await_uncertain_service_release(barrier)
          :handling

        {:handling, {:noreply, app_state}} ->
          send(
            caller,
            {:fixed_h2_service_missing_receipt, self(), app_state.cleanup_failed,
             Map.has_key?(app_state.cleanups, token), app_state.drain.outcome}
          )

          await_uncertain_service_release(barrier)
          :done

        _ ->
          phase
      end
    end

    :ok = :sys.install(service, {make_ref(), debug, :start})

    on_exit(fn ->
      send(service, {:fixed_h2_uncertain_service_continue, barrier})
      send(service, {:fixed_h2_uncertain_service_continue, barrier})
    end)

    barrier
  end

  defp await_uncertain_service_release(barrier) do
    receive do
      {:fixed_h2_uncertain_service_continue, ^barrier} -> :ok
    after
      @timeout -> raise "uncertain Service barrier expired"
    end
  end

  defp custodian_owner_down_barrier(custodian, owner) do
    caller = self()
    barrier = make_ref()
    owner_monitor = :sys.get_state(custodian).owner_monitor

    debug = fn state, event, _ ->
      case event do
        {:in, {:DOWN, ^owner_monitor, :process, ^owner, :killed}} ->
          send(caller, {:fixed_h2_custodian_owner_down_held, self()})

          receive do
            {:fixed_h2_custodian_owner_down_continue, ^barrier} -> :ok
          after
            @timeout -> raise "Custodian owner DOWN barrier expired"
          end

        _ ->
          :ok
      end

      state
    end

    :ok = :sys.install(custodian, {make_ref(), debug, nil})
    on_exit(fn -> send(custodian, {:fixed_h2_custodian_owner_down_continue, barrier}) end)
    barrier
  end

  defp owner_down_barrier(owner, guardian) do
    caller = self()
    barrier = make_ref()
    hold = :sys.get_state(owner).tokens |> Map.values() |> Enum.find(&(&1.guardian == guardian))
    guardian_monitor = hold.guardian_monitor

    debug = fn state, event, _ ->
      case event do
        {:in, {:DOWN, ^guardian_monitor, :process, ^guardian, _}} ->
          send(caller, {:fixed_h2_owner_down_held, self(), guardian})

          receive do
            {:fixed_h2_owner_down_continue, ^barrier} -> :ok
          after
            @timeout -> raise "owner DOWN barrier expired"
          end

        _ ->
          :ok
      end

      state
    end

    :ok = :sys.install(owner, {debug, nil})
    on_exit(fn -> send(owner, {:fixed_h2_owner_down_continue, barrier}) end)
    barrier
  end

  defp stop_uncertain_service(f, service, barrier, guardian, token, completion, custodians) do
    embedding_monitor = Process.monitor(f.embedding)
    instance_monitor = Process.monitor(f.instance)
    service_monitor = Process.monitor(service)
    send(f.embedding, {:stop, self()})

    F.eventually(fn ->
      {:messages, messages} = Process.info(service, :messages)
      Enum.any?(messages, &match?({:"$gen_call", _, {:drain, _, _}}, &1))
    end)

    send(service, {:fixed_h2_uncertain_service_continue, barrier})

    assert_receive {:fixed_h2_service_missing_receipt, ^service, :cleanup_receipt_missing, false,
                    {:cleanup_failed, :cleanup_receipt_missing}},
                   @timeout

    assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
    assert :sys.get_state(f.owner).tokens[token].completion == completion
    refute_receive {:fixed_h2_service_receipt, ^service, ^guardian}, 0
    send(service, {:fixed_h2_uncertain_service_continue, barrier})
    embedding = f.embedding
    instance = f.instance

    assert_receive {:fixed_h2_embedding_stopped, ^embedding,
                    {:error, {:deadline_exceeded, :cleanup_pending}}},
                   2 * @timeout

    assert_receive {:DOWN, ^embedding_monitor, :process, ^embedding, :normal}, @timeout
    assert_receive {:DOWN, ^instance_monitor, :process, ^instance, :normal}, @timeout
    assert_receive {:DOWN, ^service_monitor, :process, ^service, :normal}, @timeout
    assert {:ok, retirement} = Transports.retire(f.owner, F.deadline())

    assert {:error, {:deadline_exceeded, :cleanup_pending}} =
             Transports.await_retirement(retirement, F.deadline())

    assert {:error, {:deadline_exceeded, :cleanup_pending}} =
             Transports.await_retirement(retirement, F.deadline())

    F.eventually(fn ->
      match?(
        {:ok,
         %{
           resources: 1,
           reserved_connections: 0,
           failed_resources: 0,
           request_tokens: 1,
           helpers: 0,
           pins: 0
         }},
        Transports.status(f.owner)
      )
    end)

    owner_state = :sys.get_state(f.owner)
    assert [^token] = Map.keys(owner_state.tokens)
    hold = owner_state.tokens[token]
    assert hold.completion == completion
    assert hold.guardian == guardian
    assert hold.guardian_down
    assert hold.abort_helper == nil
    [entry] = Map.values(owner_state.records)
    assert entry.transport_confirmed
    assert entry.custodian_down
    assert map_size(entry.helpers) == 0
    assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
    refute_receive {:fixed_h2_service_receipt, ^service, ^guardian}, 0

    # Public scope retirement and physical termination do not confirm the
    # original request. Joining failed test-owned Gaoxy actors is disposal.
    dispose_failed_gaoxy_actors([f.owner | custodians])
    assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
    F.physical_termination(f.peer)
    peer = f.peer
    peer_monitor = Process.monitor(peer)
    send(peer, {:command, %{"op" => "stop"}})

    assert %{"forced" => 0, "live" => 0, "failed" => false, "requests" => 1} =
             F.event(peer, "joined")

    assert_receive {:fixed_h2_peer_exit, ^peer, 0}, @timeout
    assert_receive {:DOWN, ^peer_monitor, :process, ^peer, :normal}, @timeout
  end

  defp stop_failed_service(f, service, barrier, dead_owner \\ false) do
    send(f.embedding, {:stop, self()})

    F.eventually(fn ->
      {:messages, messages} = Process.info(service, :messages)
      Enum.any?(messages, &match?({:"$gen_call", _, {:drain, _, _}}, &1))
    end)

    send(service, {:fixed_h2_service_down_continue, barrier})

    assert_receive {:fixed_h2_embedding_stopped, _,
                    {:error,
                     {:shutdown, [{:http, {:error, {:cleanup_failed, :cleanup_receipt_missing}}}],
                      participants}}},
                   2 * @timeout

    if dead_owner do
      assert [{_, {:error, :cleanup_unconfirmed}}] = participants
    else
      assert participants == []
    end

    F.physical_termination(f.peer)
    monitor = Process.monitor(f.peer)
    send(f.peer, {:command, %{"op" => "stop"}})

    assert %{"forced" => 0, "live" => 0, "failed" => false, "requests" => 1} =
             F.event(f.peer, "joined")

    assert_receive {:fixed_h2_peer_exit, _, 0}, @timeout
    assert_receive {:DOWN, ^monitor, :process, _, :normal}, @timeout
  end

  defp owner_barrier(owner, operation) do
    caller = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      case event do
        {:in, {:"$gen_call", {sender, _}, message}}
        when not held and elem(message, 0) == operation ->
          send(caller, {:fixed_h2_owner_held, self(), sender, message})

          receive do
            {:fixed_h2_continue, ^barrier} -> :ok
          after
            @timeout -> raise "owner barrier exceeded finite deadline"
          end

          true

        _ ->
          held
      end
    end

    :ok = :sys.install(owner, {debug, false})
    on_exit(fn -> send(owner, {:fixed_h2_continue, barrier}) end)
    barrier
  end

  defp client(function, arguments), do: apply(@client, function, arguments)

  defp dispose_failed_gaoxy_actors(actors) do
    live = Enum.filter(actors, &Process.alive?/1)

    if live != [] do
      IO.puts(
        JSON.encode!(%{
          event: "fixed_h2_negative_forced_gaoxy_disposal",
          actors: length(live),
          public_cleanup: "cleanup_unconfirmed"
        })
      )

      for actor <- live do
        monitor = Process.monitor(actor)
        Process.exit(actor, :kill)
        assert_receive {:DOWN, ^monitor, :process, ^actor, :killed}, @timeout
      end
    end
  end

  defp safe_resume(pid) do
    try do
      :erlang.resume_process(pid)
    catch
      :error, :badarg -> :ok
    end
  end

  defp cancel_and_join(f, socket, guardian, completion) do
    monitor = Process.monitor(guardian)
    Session.cancel(guardian)
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout
    :ok = :gen_tcp.close(socket)
    F.clean(f)
    F.close_aborted(f, 1)
  end

  defp stop_without_connection(f) do
    monitor = Process.monitor(f.embedding)
    send(f.embedding, {:stop, self()})
    assert_receive {:fixed_h2_embedding_stopped, _, :ok}, 2 * @timeout
    assert_receive {:DOWN, ^monitor, :process, _, :normal}, @timeout
    monitor = Process.monitor(f.peer)
    send(f.peer, {:command, %{"op" => "stop"}})

    assert %{"accepts" => 0, "requests" => 0, "forced" => 0, "live" => 0, "failed" => false} =
             F.event(f.peer, "joined")

    assert_receive {:fixed_h2_peer_exit, _, 0}, @timeout
    assert_receive {:DOWN, ^monitor, :process, _, :normal}, @timeout
  end

  defp session_args(f, config) do
    %{
      owner: self(),
      service: self(),
      instance: f.instance,
      gate: self(),
      started_at: Gaoxy.Lifecycle.now(),
      deadline: F.deadline(),
      config: config,
      selector: {:fixed, config},
      transport_handoff: nil,
      request_options: %{
        protocol: :h2c,
        url: f.origin <> "/",
        target: "/",
        method: :get,
        fields: [],
        body_mode: :none,
        request_limits: %{
          max_headers: 256,
          max_header_bytes: 65_536,
          max_trailers: 128,
          max_trailer_bytes: 65_536
        },
        max_upload_bytes: 65_536
      }
    }
  end
end
