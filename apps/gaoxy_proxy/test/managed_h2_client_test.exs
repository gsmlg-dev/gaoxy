defmodule Gaoxy.Proxy.ManagedH2ClientTest do
  use ExUnit.Case, async: true

  @client Gaoxy.Proxy.ManagedH2Client
  @errors [
    :invalid_request,
    :invalid_policy,
    :invalid_response,
    :upstream_failure,
    :upstream_task,
    :upstream_delivery_limit,
    :upstream_delivery_overlap,
    :upstream_trailer_limit,
    :timeout,
    :request_timeout,
    :unavailable,
    :cancelled,
    :cleanup_pending,
    :cleanup_unconfirmed,
    :invalid_resource,
    :invalid_resource_pin,
    :invalid_transport_endpoint,
    :unauthorized,
    :retiring,
    :resource_unavailable
  ]
  @timeout 5_000

  test "adapter exports only the existing callbacks and has no begin_cleanup variant" do
    assert Code.ensure_loaded?(@client)

    assert apply(@client, :__info__, [:functions]) == [
             acknowledge: 2,
             await_completion: 2,
             cleanup: 2,
             completion: 1,
             event: 2,
             finish_body: 2,
             host_supported?: 0,
             open: 1,
             poll_headers: 1,
             reservation_bytes: 3,
             subscribe: 1,
             write_body: 3
           ]

    refute function_exported?(@client, :begin_cleanup, 3)
    assert call(:host_supported?, []) == Gaoxy.Proxy.HTTPFetchClient.host_supported?()
    assert call(:reservation_bytes, [[], 1, 1]) == 9_444_956
  end

  test "open rejects expanded maps, aliases and omissions before creating an upload or Fetch" do
    original = options()

    for bad <- [
          nil,
          [],
          %{},
          Map.put(original, :headers, []),
          Map.put(original, :body, self()),
          Map.put(original, :url, original.request.url),
          Map.put(original, :ssl, []),
          Map.put(original, :connect_address, {127, 0, 0, 1}),
          Map.put(original, :transport_scope, original.managed_transport.transport_scope),
          Map.put(original, :__struct__, URI)
        ] do
      finite_error(call(:open, [bad]))
    end

    for key <- Map.keys(original) do
      finite_error(call(:open, [Map.delete(original, key)]))
    end
  end

  test "opening timeouts and signed64 deadlines reject malformed and overflowing arithmetic" do
    original = options()

    for key <- [:timeout, :opening_timeout, :write_timeout],
        value <- [0, 86_400_001, :infinity, 1.0, nil] do
      finite_error(call(:open, [Map.put(original, key, value)]))
    end

    for key <- [:deadline, :opening_deadline],
        value <- [-9_223_372_036_854_775_809, 9_223_372_036_854_775_808, :infinity, 1.0, nil] do
      finite_error(call(:open, [Map.put(original, key, value)]))
    end

    finite_error(call(:open, [%{original | opening_deadline: original.deadline + 1}]))

    finite_error(
      call(:open, [
        %{
          original
          | deadline: -9_223_372_036_854_775_808,
            opening_deadline: -9_223_372_036_854_775_808
        }
      ])
    )

    finite_error(
      call(:open, [
        %{
          original
          | deadline: 9_223_372_036_854_775_807,
            opening_deadline: 9_223_372_036_854_775_807
        }
      ])
    )
  end

  test "open nested envelopes and checked clients reject aliases, forged structs and protocol mismatch" do
    original = options()

    for bad <- [
          %{original | request: Map.put(original.request, :headers, [])},
          %{original | request: Map.delete(original.request, :target)},
          %{original | request: %{original.request | fields: [{"x", oversized_slice(65_537)}]}},
          %{original | request: %{original.request | protocol: :http2}},
          %{original | request: %{original.request | url: "http://other.test/a?"}},
          %{original | managed_transport: nil},
          %{original | managed_transport: Map.put(original.managed_transport, :extra, [])},
          %{
            original
            | managed_transport: %{original.managed_transport | transport_scope: make_ref()}
          },
          %{original | managed_transport: %{original.managed_transport | fetch_options: []}}
        ] do
      finite_error(call(:open, [bad]))
    end
  end

  test "real lazy public scope opens exact handle and binds original completion before cleanup" do
    # No hidden server/native state is injected. The TCP listener deliberately
    # withholds H2 response bytes while the original public completion is held.
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    on_exit(fn -> :gen_tcp.close(listener) end)
    {:ok, {_, port}} = :inet.sockname(listener)

    {:ok, policy, _} =
      Gaoxy.Proxy.ManagedH2Preparation.prepare_policy(%{
        protocol: :h2c,
        origin: "http://upstream.test:#{port}",
        connect_address: {127, 0, 0, 1},
        trust: nil
      })

    {:ok, scope} = HTTP.ManagedTransport.open(policy.open_options)

    on_exit(fn ->
      assert {:ok, receipt} = HTTP.ManagedTransport.retire(scope, mode: :abort)
      assert :ok = HTTP.ManagedTransport.await_retired(receipt, @timeout)
    end)

    client = %{checked_client() | policy: policy, transport_scope: scope}

    input = %{
      options()
      | managed_transport: client,
        request: %{request() | url: "http://upstream.test:#{port}/a?"}
    }

    assert {:ok, handle, nil} = call(:open, [input])
    assert_handle(handle)
    original = HTTP.Promise.completion(handle.promise)
    assert handle.completion == original
    assert call(:completion, [handle]) == original
    assert {:error, :cleanup_pending} = call(:cleanup, [handle, false])
    assert {:error, :cleanup_pending} = call(:await_completion, [original, false])
    {:ok, socket} = :gen_tcp.accept(listener, @timeout)
    :ok = :inet.setopts(socket, active: false)
    on_exit(fn -> :gen_tcp.close(socket) end)
    assert :ok = HTTP.RequestCompletion.abort_and_await(original, @timeout)
    assert :ok = call(:cleanup, [handle, true])
    assert :ok = call(:cleanup, [handle, false])
    assert :ok = call(:await_completion, [original, false])
    assert {:ok, receipt} = HTTP.ManagedTransport.retire(scope, mode: :abort)
    assert :ok = HTTP.ManagedTransport.await_retired(receipt, @timeout)
    assert {:error, :closed} = drain_eof(socket, System.monotonic_time(:millisecond) + @timeout)
  end

  test "task-message delivery authenticates ref and extracts only bounded head and stream" do
    handle = handle()
    response = response()

    assert {{:headers, 200, fields}, updated} =
             call(:event, [{handle, request().url}, {handle.promise.task.ref, response}])

    assert fields == response.headers.headers
    assert_handle(updated)
    assert updated.resolved
    assert updated.stream == self()
    assert updated.completion == handle.completion
    assert updated.promise == handle.promise
    assert call(:completion, [updated]) == handle.completion
    refute Map.has_key?(updated, :url)
    refute Map.has_key?(updated, :response)
  end

  test "task head accepts the exact native normalized URI without retaining or rewriting Response" do
    original = handle()
    native = %{response() | url: %{response().url | authority: nil}}

    assert {{:headers, 200, fields}, updated} =
             call(:event, [{original, request().url}, {original.promise.task.ref, native}])

    assert fields == native.headers.headers
    assert_handle(updated)
    assert updated.stream == self()
    assert updated.completion == original.completion
    assert updated.promise == original.promise
    assert native.url.authority == nil
    refute Map.has_key?(updated, :response)
    refute Map.has_key?(updated, :url)

    attacker = %{native | url: %{native.url | path: "/other"}}

    assert {{:error, :invalid_response}, rejected} =
             call(:event, [{original, request().url}, {original.promise.task.ref, attacker}])

    assert rejected.completion == original.completion
  end

  test "polling uses submitted URL context and returns the same exact four-key shell" do
    handle = handle()
    send(self(), {handle.promise.task.ref, response()})
    assert {{:headers, 200, fields}, updated} = call(:poll_headers, [{handle, request().url}])
    assert fields == response().headers.headers
    assert_handle(updated)
    assert updated.completion == handle.completion
    assert {:none, ^updated} = call(:poll_headers, [{updated, nil}])
  end

  test "unresolved task polling is nonblocking and does not invent a head or completion" do
    handle = handle()
    assert {:none, ^handle} = call(:poll_headers, [{handle, request().url}])
    assert call(:completion, [handle]) == handle.completion
  end

  test "handle context validates exact handle Promise and Task public shells before use" do
    original = handle()

    for bad <- [
          Map.put(original, :url, request().url),
          Map.delete(original, :completion),
          %{original | resolved: :yes},
          %{original | stream: make_ref()},
          %{original | promise: Map.put(original.promise, :extra, [])},
          %{
            original
            | promise: %{original.promise | task: Map.put(original.promise.task, :extra, [])}
          },
          %{
            original
            | promise: %{original.promise | task: %{original.promise.task | owner: nil}}
          },
          %{
            original
            | promise: %{original.promise | task: %{original.promise.task | ref: self()}}
          },
          %{
            original
            | promise: %{
                original.promise
                | task: %{original.promise.task | mfa: {:erlang, :apply, [fn -> :bad end]}}
              }
          }
        ] do
      assert {{:error, reason}, _} = call(:poll_headers, [{bad, request().url}])
      assert reason in @errors
    end

    for context <- [original, {original, nil}, {original, request().url, :extra}] do
      assert {{:error, reason}, _} = call(:poll_headers, [context])
      assert reason in @errors
    end
  end

  test "wrong task refs and stream PIDs drop unknown payloads without retaining them" do
    original = handle()
    alien = :erlang.list_to_pid(~c"<0.1.0>")

    for message <- [
          {make_ref(), response()},
          {:DOWN, make_ref(), :process, alien, :normal},
          {:stream_chunk, alien, "body", make_ref()},
          {:stream_trailers, alien, %HTTP.Headers{}},
          {:stream_end, alien},
          {:unexpected, fn -> :bad end}
        ] do
      assert {:none, ^original} = call(:event, [{original, request().url}, message])
    end
  end

  test "task DOWN authenticates task PID and normalizes arbitrary diagnostics to finite error" do
    original = handle()
    ref = original.promise.task.ref
    pid = original.promise.task.pid

    for reason <- [
          :normal,
          {%RuntimeError{message: :binary.copy("diagnostic", 1000)}, [:stack]},
          %{deep: List.duplicate([:arbitrary], 2000)}
        ] do
      assert {{:error, :upstream_task}, updated} =
               call(:event, [{original, request().url}, {:DOWN, ref, :process, pid, reason}])

      assert_handle(updated)
      assert updated.completion == original.completion
    end

    assert {:none, ^original} =
             call(:event, [
               {original, request().url},
               {:DOWN, ref, :process, :erlang.list_to_pid(~c"<0.1.0>"), :normal}
             ])
  end

  test "task errors and malformed successful wrappers retain only finite atoms" do
    original = handle()

    for result <- [
          {:error, {:tcp, :econnreset}},
          {:error, %RuntimeError{message: "raw"}},
          {:ok, response()},
          Map.put(response(), :extra, []),
          %{response() | url: URI.parse("http://other.test/a?")},
          %{response() | http_version: :h2c}
        ] do
      assert {{:error, reason}, updated} =
               call(:event, [{original, request().url}, {original.promise.task.ref, result}])

      assert reason in @errors
      assert_handle(updated)
      assert updated.completion == original.completion
    end
  end

  for delivery <- [:event, :poll_headers], kind <- [:requests, :connections] do
    test "#{delivery} normalizes public #{kind} capacity to unavailable without retaining its tuple" do
      original = handle()
      result = {:error, {:transport_scope_capacity, unquote(kind)}}

      received =
        case unquote(delivery) do
          :event ->
            call(:event, [{original, request().url}, {original.promise.task.ref, result}])

          :poll_headers ->
            send(self(), {original.promise.task.ref, result})
            call(:poll_headers, [{original, request().url}])
        end

      assert {{:error, :unavailable}, updated} = received
      assert updated == %{original | resolved: true}
      assert updated.completion == original.completion
      assert_handle(updated)
    end
  end

  for delivery <- [:event, :poll_headers] do
    test "#{delivery} rejects malformed capacity diagnostics without retaining their payloads" do
      for reason <- [
            {:transport_scope_capacity, :unknown},
            {:transport_scope_capacity, "requests"},
            {:transport_scope_capacity, :connections, :extra},
            %{
              reason: {:transport_scope_capacity, :connections},
              diagnostic: :binary.copy("x", 1_048_577)
            }
          ] do
        original = handle()
        result = {:error, reason}

        received =
          case unquote(delivery) do
            :event ->
              call(:event, [{original, request().url}, {original.promise.task.ref, result}])

            :poll_headers ->
              send(self(), {original.promise.task.ref, result})
              call(:poll_headers, [{original, request().url}])
          end

        assert {{:error, :upstream_failure}, updated} = received
        assert updated == %{original | resolved: true}
        assert updated.completion == original.completion
        assert_handle(updated)
      end
    end
  end

  test "resolved handles ignore repeated task results while preserving original completion" do
    original = handle(true)

    assert {:none, ^original} =
             call(:event, [{original, nil}, {original.promise.task.ref, response()}])

    assert {:none, ^original} =
             call(:event, [
               {original, nil},
               {:DOWN, original.promise.task.ref, :process, original.promise.task.pid, :normal}
             ])
  end

  test "bodyless head and status responses leave stream nil without fabricating completion" do
    for status <- [200, 204, 205, 304], body <- [nil, ""] do
      original = handle()
      response = %{response() | status: status, stream: nil, body: body}

      assert {{:headers, ^status, _}, updated} =
               call(:event, [{original, request().url}, {original.promise.task.ref, response}])

      assert updated.stream == nil
      assert updated.completion == original.completion
      assert :ok = call(:subscribe, [updated])
      refute_received {:read_chunk, _, _}
    end
  end

  test "encoded compression and Content-Length pass unchanged through head and DATA" do
    original = handle()
    bytes = :zlib.gzip("raw-compression")

    fields = [
      {"content-encoding", "gzip"},
      {"content-length", Integer.to_string(byte_size(bytes))}
    ]

    response = %{response() | headers: %HTTP.Headers{headers: fields}}

    assert {{:headers, 200, ^fields}, updated} =
             call(:event, [{original, request().url}, {original.promise.task.ref, response}])

    ref = make_ref()

    assert {{:chunk, ^bytes, ^ref}, ^updated} =
             call(:event, [{updated, nil}, {:stream_chunk, self(), bytes, ref}])

    refute_received {:stream_chunk_ack, _}
  end

  test "DATA above16KiB through exact1MiB remains one event and only explicit ACK sends credit" do
    original = handle(true)

    for bytes <- [16_385, 65_536, 1_048_576] do
      payload = :binary.copy("d", bytes)
      ref = make_ref()

      assert {{:chunk, ^payload, ^ref}, ^original} =
               call(:event, [{original, nil}, {:stream_chunk, self(), payload, ref}])

      refute_received {:stream_chunk_ack, _}
      assert :ok = call(:acknowledge, [original, ref])
      assert_receive {:stream_chunk_ack, ^ref}, 1000
      refute_received {:stream_chunk_ack, ^ref}
    end
  end

  test "DATA logical backing and scalar failures never acknowledge rejected bytes" do
    original = handle(true)

    for payload <- [:binary.copy("d", 1_048_577), oversized_slice(1_048_577), ["body"]] do
      ref = make_ref()

      assert {{:error, :upstream_delivery_limit}, updated} =
               call(:event, [{original, nil}, {:stream_chunk, self(), payload, ref}])

      assert_handle(updated)
      assert updated.completion == original.completion
      refute_received {:stream_chunk_ack, _}
    end

    assert {{:error, reason}, _} =
             call(:event, [{original, nil}, {:stream_chunk, self(), "body", :not_a_ref}])

    assert reason in @errors
    refute_received {:stream_chunk_ack, _}
  end

  test "admissible backed DATA is copied compactly after preflight" do
    original = handle(true)
    payload = oversized_slice(1_048_576)
    ref = make_ref()

    assert {{:chunk, compact, ^ref}, ^original} =
             call(:event, [{original, nil}, {:stream_chunk, self(), payload, ref}])

    assert compact == payload
    assert :binary.referenced_byte_size(compact) == byte_size(compact)
    refute_received {:stream_chunk_ack, _}
  end

  test "terminal trailers preserve duplicate order at128 and reject native-valid129" do
    original = handle(true)
    fields = List.duplicate({"x-check", "value"}, 128)

    assert {{:trailers, ^fields}, ^original} =
             call(:event, [
               {original, nil},
               {:stream_trailers, self(), %HTTP.Headers{headers: fields}}
             ])

    for fields <- [
          fields ++ [{"x-check", "over"}],
          [{"x", oversized_slice(65_537)}],
          [{"x", "v"} | :improper],
          [{"bad name", "v"}],
          [{"x", :bad}]
        ] do
      assert {{:error, :upstream_trailer_limit}, updated} =
               call(:event, [
                 {original, nil},
                 {:stream_trailers, self(), %HTTP.Headers{headers: fields}}
               ])

      assert_handle(updated)
      assert updated.completion == original.completion
      refute_received {:stream_chunk_ack, _}
    end

    assert {{:error, :upstream_trailer_limit}, _} =
             call(:event, [
               {original, nil},
               {:stream_trailers, self(), Map.put(%HTTP.Headers{}, :extra, [])}
             ])
  end

  test "terminal and stream errors retain original completion with finite normalized reason" do
    original = handle(true)
    assert {:end, ^original} = call(:event, [{original, nil}, {:stream_end, self()}])

    for reason <- [:timeout, {:tcp, :econnreset}, %RuntimeError{message: "private diagnostic"}] do
      assert {{:error, finite}, updated} =
               call(:event, [{original, nil}, {:stream_error, self(), reason}])

      assert finite in @errors
      assert updated.completion == original.completion
      assert_handle(updated)
    end
  end

  test "subscribe emits exactly the public ACK-mode read request" do
    original = handle(true)
    assert :ok = call(:subscribe, [original])
    owner = self()
    assert_receive {:read_chunk, ^owner, :ack}, 1000
    refute_received {:read_chunk, _, _}
  end

  test "upload accepts exact64KiB using public Stream and finish joins its actor" do
    {stream, monitor} = upload_stream()
    send(stream, {:read_chunk, self()})
    payload = :binary.copy("u", 65_536)
    assert :ok = call(:write_body, [stream, payload, 1000])
    assert_receive {:stream_chunk, ^stream, ^payload}, 1000
    assert :ok = call(:finish_body, [stream, []])
    assert_receive {:stream_end, ^stream}, 1000
    assert_receive {:DOWN, ^monitor, :process, ^stream, :normal}, 1000
  end

  test "rejected upload logical backing and timeout inputs send no public chunk" do
    {stream, monitor} = upload_stream()
    send(stream, {:read_chunk, self()})

    for payload <- [:binary.copy("u", 65_537), oversized_slice(65_537), ["body"]] do
      assert {:error, :invalid_request} = call(:write_body, [stream, payload, 1000])
    end

    for timeout <- [0, 86_400_001, :infinity, 1.0] do
      finite_error(call(:write_body, [stream, "body", timeout]))
    end

    assert :ok = call(:finish_body, [stream, []])
    assert_receive {:stream_end, ^stream}, 1000
    assert_receive {:DOWN, ^monitor, :process, ^stream, :normal}, 1000
    refute_received {:stream_chunk, ^stream, _}
  end

  test "upload finish validates128 proper ordered trailers before public Stream.finish" do
    {stream, monitor} = upload_stream()
    send(stream, {:read_chunk, self()})
    fields = List.duplicate({"x-check", "value"}, 128)
    finite_error(call(:finish_body, [stream, fields ++ [{"x-check", "over"}]]))
    finite_error(call(:finish_body, [stream, [{"x", oversized_slice(65_537)}]]))
    finite_error(call(:finish_body, [stream, [{"x", "v"} | :improper]]))
    assert :ok = call(:finish_body, [stream, fields])
    assert_receive {:stream_trailers, ^stream, %HTTP.Headers{headers: ^fields}}, 1000
    assert_receive {:stream_end, ^stream}, 1000
    assert_receive {:DOWN, ^monitor, :process, ^stream, :normal}, 1000
  end

  test "cleanup and waits normalize opaque unsupported completion to a finite error only" do
    completion = %HTTP.RequestCompletion{unsupported: :http_version}
    original = %{handle(true) | completion: completion}
    original = %{original | promise: %{original.promise | completion: completion}}

    for abort? <- [true, false] do
      finite_error(call(:cleanup, [original, abort?]))
      finite_error(call(:await_completion, [completion, abort?]))
    end
  end

  defp call(function, args), do: apply(@client, function, args)

  defp finite_error(result) do
    assert {:error, reason} = result
    assert reason in @errors
  end

  defp assert_handle(handle) do
    assert Enum.sort(Map.keys(handle)) == [:completion, :promise, :resolved, :stream]
    assert is_boolean(handle.resolved)
    assert handle.stream == nil or is_pid(handle.stream)
    assert %HTTP.Promise{task: %Task{}, completion: original} = handle.promise
    assert handle.completion == original
    marker = {:opaque, HTTP.RequestCompletion}
    projection = %{handle | completion: marker, promise: %{handle.promise | completion: marker}}
    assert :erlang.external_size(projection) <= 4096
  end

  defp handle(resolved \\ false) do
    completion = %HTTP.RequestCompletion{}
    task = %Task{owner: self(), pid: self(), ref: make_ref(), mfa: {:erlang, :apply, 2}}

    %{
      promise: %HTTP.Promise{task: task, completion: completion},
      completion: completion,
      stream: if(resolved, do: self(), else: nil),
      resolved: resolved
    }
  end

  defp response do
    %HTTP.Response{
      status: 200,
      status_text: "OK",
      ok: true,
      headers: %HTTP.Headers{headers: [{"x-repeat", "first"}, {"x-repeat", "second"}]},
      body: self(),
      body_used: false,
      stream: self(),
      url: URI.parse(request().url),
      redirected: false,
      type: :basic,
      http_version: :http2,
      informational: [],
      trailers: %HTTP.Headers{}
    }
  end

  defp request do
    %{
      protocol: :h2c,
      url: "http://upstream.test/a?",
      target: "/a?",
      method: :get,
      fields: [],
      body_mode: :none,
      max_upload_bytes: 65_536,
      request_limits: %{
        max_headers: 256,
        max_header_bytes: 65_536,
        max_trailers: 128,
        max_trailer_bytes: 65_536
      }
    }
  end

  defp checked_client do
    {:ok, policy, _} =
      Gaoxy.Proxy.ManagedH2Preparation.prepare_policy(%{
        protocol: :h2c,
        origin: "http://upstream.test",
        connect_address: {127, 0, 0, 1},
        trust: nil
      })

    %{
      policy: policy,
      transport_scope: struct(HTTP.ManagedTransport),
      fetch_options: [
        http_version: :h2c,
        tls_backend: :ssl,
        http2_profile: :native_v1,
        http2_reuse: true,
        redirect: :manual,
        request_mode: :proxy,
        decode_body: false,
        stream_response: true,
        telemetry: false
      ]
    }
  end

  defp options do
    deadline = System.monotonic_time(:millisecond) + @timeout

    %{
      request: request(),
      managed_transport: checked_client(),
      timeout: @timeout,
      opening_timeout: @timeout,
      write_timeout: @timeout,
      deadline: deadline,
      opening_deadline: deadline
    }
  end

  defp oversized_slice(bytes), do: binary_part(:binary.copy("s", bytes), 0, 100)

  defp upload_stream do
    {:ok, stream} = HTTP.Stream.start_link(0)
    Process.unlink(stream)
    monitor = Process.monitor(stream)

    on_exit(fn ->
      shutdown_monitor = Process.monitor(stream)
      :ok = HTTP.Stream.error(stream, :aborted)
      assert_receive {:DOWN, ^shutdown_monitor, :process, ^stream, reason}, 1000
      assert reason in [:normal, :noproc]
    end)

    {stream, monitor}
  end

  defp drain_eof(socket, deadline) do
    case :gen_tcp.recv(socket, 0, max(deadline - System.monotonic_time(:millisecond), 0)) do
      {:ok, _bytes} -> drain_eof(socket, deadline)
      result -> result
    end
  end
end
