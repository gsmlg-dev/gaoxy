Code.require_file("support/managed_h2_group_fixture.exs", __DIR__)

defmodule Gaoxy.Proxy.ManagedH2GroupEndpointTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH2GroupFixture, as: G
  alias Gaoxy.Proxy.{ManagedH2GroupBoundary, UpstreamGroups, UpstreamTransports}
  alias Gaoxy.Proxy.HTTP.Session
  @moduletag :capture_log
  @timeout 5_000
  @reserve 16_478_862

  setup do
    # Authenticated pre-F RED; there is no bypass or skip for the real wire gate.
    assert :ok === boundary(:activation)
    :ok
  end

  for downstream <- [:http1, :http2], protocol <- [:http2, :h2c] do
    @downstream downstream
    @protocol protocol
    test "#{downstream} -> group #{protocol} preserves exact targets ordered fields raw responses trailers and bodyless methods" do
      f = G.fixture(@protocol, @downstream)

      for target <- ["/a%2Fb?q=%2F", "/empty?"] do
        assert %{status: 200, body: ^target} =
                 G.request(f, "GET", target, [
                   {"x-trace", "first"},
                   {"x-trace", "second"},
                   {"x-forwarded-for", "spoofed"}
                 ])

        seen = G.event(f.peer, "request")
        assert seen["target"] === target
        assert seen["connection"] === 1

        assert Enum.filter(seen["headers"], &(hd(&1) == "x-trace")) ===
                 [["x-trace", "first"], ["x-trace", "second"]]

        assert [":authority", "localhost:#{f.ready["port"]}"] in seen["headers"]
        refute Enum.any?(seen["headers"], &(List.last(&1) == "spoofed"))
      end

      if @protocol == :http2,
        do: assert(%{"alpn" => "h2", "sni" => "localhost"} = G.event(f.peer, "tls"))

      assert %{status: 200, headers: fields, body: compressed} = G.request(f, "GET", "/gzip")
      assert :zlib.gunzip(compressed) === "raw-compression"
      assert {"content-encoding", "gzip"} in fields
      assert {"content-length", Integer.to_string(byte_size(compressed))} in fields
      assert G.event(f.peer, "request")["connection"] === 1
      assert %{status: 302, headers: fields, body: "redirect"} = G.request(f, "GET", "/redirect")
      assert {"location", "http://unfollowed.invalid/never"} in fields
      assert G.event(f.peer, "request")["connection"] === 1
      bytes = "managed-h2-stream:" <> String.duplicate("s", 65_536)
      assert %{status: 200, body: ^bytes} = G.request(f, "GET", "/stream")
      assert G.event(f.peer, "request")["connection"] === 1

      assert %{
               status: 200,
               body: "trailers",
               headers: fields,
               trailers: [{"x-check", "first"}, {"x-check", "second"}]
             } = G.request(f, "GET", "/trailers")

      assert Enum.filter(fields, &(elem(&1, 0) == "set-cookie")) ===
               [{"set-cookie", "one=1"}, {"set-cookie", "two=2"}]

      G.event(f.peer, "request")

      for code <- [204, 205, 304] do
        assert %{status: ^code, body: ""} = G.request(f, "GET", "/#{code}")
        G.event(f.peer, "request")
      end

      assert %{status: 200, body: "", headers: fields} = G.request(f, "HEAD", "/head")
      assert {"content-length", "5"} in fields
      assert [":method", "HEAD"] in G.event(f.peer, "request")["headers"]
      G.no_event(f.peer, "request")
      G.close(f)
    end

    test "#{downstream} -> group #{protocol} original G and T binding precedes bounded upload with ordered request trailers and early final" do
      f = G.fixture(@protocol, @downstream)
      socket = G.connect(f)

      :ok =
        G.send_request(
          f,
          socket,
          "POST",
          "/echo?raw=%2F",
          [{"content-length", "6"}, {"x-trace", "first"}],
          false
        )

      :ok = G.send_body(f, socket, "abc", false)
      seen = G.event(f.peer, "request")
      assert seen["target"] === "/echo?raw=%2F"
      assert ["content-length", "6"] in seen["headers"]
      assert %{"total_bytes" => 3} = G.upload_through(f.peer, seen, "abc")
      G.no_event(f.peer, "upload_end")
      [{group_token, group_hold}] = Map.to_list(:sys.get_state(f.groups).tokens)
      [{transport_token, transport_hold}] = Map.to_list(:sys.get_state(f.owner).tokens)
      guardian = group_hold.guardian
      completion = group_hold.completion
      assert %HTTP.RequestCompletion{} = completion
      assert transport_hold.guardian === guardian
      assert transport_hold.completion === completion
      refute group_token === transport_token
      state = :sys.get_state(guardian)
      assert state.selection === {f.group, group_token}
      assert state.transport_selection === {f.handle, transport_token}
      assert state.client.completion(state.original_request) === completion
      assert state.managed_path === true
      assert state.managed_transport === nil
      assert state.request_options === nil
      assert state.selector === nil
      assert state.awaiting_transport === nil
      assert state.submitted_url === f.origin <> "/echo?raw=%2F"
      assert :binary.referenced_byte_size(state.submitted_url) === byte_size(state.submitted_url)
      assert Enum.sort(Map.keys(state.request)) === [:completion, :promise, :resolved, :stream]
      assert Enum.all?(state.transport_pins, &(&1.holder === guardian and &1.kind === :request))
      assert G.assert_cleanup(f, 1) === @reserve
      G.assert_exact_controls(:sys.get_state(f.groups))
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
      :ok = G.send_body(f, socket, "def", true)
      assert %{"total_bytes" => 6} = G.upload_through(f.peer, seen, "abcdef", 3)
      connection = seen["connection"]
      stream = seen["stream"]
      upload_hash = Base.encode16(:crypto.hash(:sha256, "abcdef"), case: :lower)

      assert %{
               "connection" => ^connection,
               "stream" => ^stream,
               "chunk_bytes" => 0,
               "total_bytes" => 6,
               "sha256" => ^upload_hash
             } = G.event(f.peer, "upload")

      assert %{"connection" => ^connection, "stream" => ^stream, "total_bytes" => 6} =
               G.event(f.peer, "upload_end")

      assert %{status: 200, body: "abcdef"} = G.response(f, socket)
      :ok = :gen_tcp.close(socket)
      G.clean(f)
      assert :ok = HTTP.RequestCompletion.await(completion, 0)
      socket = G.connect(f)

      fields =
        [{"trailer", "x-check"}] ++
          if(@downstream == :http1, do: [{"transfer-encoding", "chunked"}], else: [])

      :ok = G.send_request(f, socket, "DELETE", "/echo", fields, false)

      if @downstream == :http1 do
        :ok = :gen_tcp.send(socket, "4\r\nwire\r\n0\r\nX-Check: first\r\nX-Check: second\r\n\r\n")
      else
        :ok = G.send_body(f, socket, "wire", false)

        {block, _} =
          HPAX.encode(:never_store, [{"x-check", "first"}, {"x-check", "second"}], HPAX.new(4096))

        :ok = :gen_tcp.send(socket, Gaoxy.HTTP.HTTP2.Frame.encode(1, 5, 1, block))
      end

      seen = G.event(f.peer, "request")
      assert seen["target"] === "/echo"
      assert [":method", "DELETE"] in seen["headers"]
      assert %{"total_bytes" => 4} = G.upload_through(f.peer, seen, "wire")

      assert %{"fields" => [["x-check", "first"], ["x-check", "second"]]} =
               G.event(f.peer, "upload_trailers")

      assert %{"total_bytes" => 4} = G.event(f.peer, "upload_end")
      assert %{status: 200, body: "wire"} = G.response(f, socket, "DELETE")
      :ok = :gen_tcp.close(socket)
      G.clean(f)
      socket = G.connect(f)
      :ok = G.send_request(f, socket, "POST", "/early", [{"content-length", "1000000"}], false)
      assert %{status: 413, body: "early-final"} = G.response(f, socket)
      assert %{"target" => "/early"} = G.event(f.peer, "request")
      G.no_event(f.peer, "upload")
      :ok = :gen_tcp.close(socket)
      G.clean(f)
      assert %{status: 200, body: "/healthy"} = G.request(f, "GET", "/healthy")
      assert %{"target" => "/healthy"} = G.event(f.peer, "request")
      G.no_event(f.peer, "request")
      G.close(f)
    end

    test "#{downstream} -> group #{protocol} real stream reset preserves a simultaneous healthy sibling" do
      f = G.fixture(@protocol, @downstream, ["--manual"])
      {first, one, guardian, completion} = G.hold(f, "/hold/one")
      {second, two, sibling, sibling_completion} = G.hold(f, "/hold/two")
      assert one["connection"] === two["connection"]
      refute one["stream"] === two["stream"]
      refute guardian === sibling
      assert G.assert_cleanup(f, 2) === 2 * @reserve
      assert %{inflight: 2} = UpstreamGroups.status(f.group)
      assert {:ok, %{request_tokens: 2}} = UpstreamTransports.status(f.owner)
      G.command(f.peer, one, "reset")
      assert %{status: 502} = G.response(f, first)
      monitor = Process.monitor(guardian)
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, reason}, @timeout
      assert reason in [:normal, :noproc]
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(sibling_completion, 0)

      G.command(f.peer, two, "respond", %{
        "body64" => Base.encode64("healthy"),
        "fields" => [["content-length", "7"]]
      })

      assert %{status: 200, body: "healthy"} = G.response(f, second)
      :ok = :gen_tcp.close(first)
      :ok = :gen_tcp.close(second)
      assert :ok = HTTP.RequestCompletion.await(sibling_completion, @timeout)
      G.clean(f)
      G.no_event(f.peer, "request")
      G.close(f)
    end
  end

  for protocol <- [:http2, :h2c] do
    @protocol protocol
    @tag timeout: 120_000
    test "group #{protocol} C2 R32 P0 holds32 actual forwards and exact527323584 cleanup bytes then refuses one over without peer effect" do
      f =
        G.fixture(@protocol, :http1, ["--manual"], %{transport_limits: %{max_request_tokens: 32}})

      held = for index <- 1..32, do: G.hold(f, "/hold/#{index}")

      assert {:ok, %{resources: 1, reserved_connections: 2, request_tokens: 32, pins: 65}} =
               UpstreamTransports.status(f.owner)

      assert %{inflight: 32, probes: 0, probe_bytes: 0} = UpstreamGroups.status(f.group)
      state = :sys.get_state(f.groups)
      assert map_size(state.tokens) === 32
      assert map_size(state.pins) === 33
      G.assert_exact_controls(state)
      assert G.assert_cleanup(f, 32) === 527_323_584
      gate = :sys.get_state(f.gate)
      assert gate.limits.max_bytes >= 1_073_741_824
      assert gate.high_water >= 527_323_584
      assert gate.high_water <= gate.limits.max_bytes
      [entry] = Map.values(:sys.get_state(f.owner).records)
      assert entry.policy.open_options[:max_connections] === 2
      assert entry.policy.open_options[:max_requests] === 32
      assert entry.policy.open_options[:max_pending] === 0

      IO.puts(
        JSON.encode!(%{
          event: "managed_h2_group_capacity",
          actual_requests: 32,
          cleanup_bytes: 527_323_584,
          retained_bytes: gate.bytes,
          retained_high_water: gate.high_water,
          service_max_bytes: gate.limits.max_bytes
        })
      )

      assert Enum.all?(held, fn {_, seen, _, _} -> seen["connection"] in [1, 2] end)
      identities = for {_, seen, _, _} <- held, do: {seen["connection"], seen["stream"]}
      assert length(Enum.uniq(identities)) === 32
      socket = G.connect(f)
      :ok = G.send_request(f, socket, "GET", "/refused33")
      assert %{status: 503} = G.response(f, socket)
      :ok = :gen_tcp.close(socket)
      G.no_event(f.peer, "request")
      assert %{inflight: 32} = UpstreamGroups.status(f.group)
      assert {:ok, %{request_tokens: 32}} = UpstreamTransports.status(f.owner)
      assert G.assert_cleanup(f, 32) === 527_323_584

      for {socket, seen, _, completion} <- held do
        G.command(f.peer, seen, "respond", %{"fields" => [["content-length", "0"]]})
        assert %{status: 200, body: ""} = G.response(f, socket)
        :ok = :gen_tcp.close(socket)
        assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      end

      G.clean(f)
      G.close(f)
    end

    test "group #{protocol} cancellation keeps the full Service and G T holds until original completion then a sibling progresses" do
      f = G.fixture(@protocol, :http1, ["--manual"])
      {socket, seen, guardian, completion} = G.hold(f)
      state = :sys.get_state(guardian)
      assert state.client.completion(state.original_request) === completion
      assert G.assert_cleanup(f, 1) === @reserve
      Session.consumed(guardian)
      G.eventually(fn -> :sys.get_state(guardian).consumed end)
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
      assert %{inflight: 1} = UpstreamGroups.status(f.group)
      assert {:ok, %{request_tokens: 1, pins: 3}} = UpstreamTransports.status(f.owner)
      assert G.assert_cleanup(f, 1) === @reserve
      monitor = Process.monitor(guardian)
      Session.cancel(guardian)
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout
      :ok = :gen_tcp.close(socket)
      G.clean(f)
      {next_socket, next_seen, _, next_completion} = G.hold(f, "/hold/sibling")
      assert next_seen["connection"] === seen["connection"]
      G.command(f.peer, next_seen, "respond", %{"fields" => [["content-length", "0"]]})
      assert %{status: 200, body: ""} = G.response(f, next_socket)
      :ok = :gen_tcp.close(next_socket)
      assert :ok = HTTP.RequestCompletion.await(next_completion, @timeout)
      G.clean(f)
      G.close(f)
    end

    test "group #{protocol} selected effective limits and original root remain exact before the real response" do
      member = %{
        max_chunk_bytes: 8_192,
        opening_timeout: 1_500,
        idle_timeout: 3_000,
        write_timeout: 1_000,
        max_lifetime: 5_000
      }

      endpoint = %{
        max_chunk_bytes: 16_384,
        opening_timeout: 3_000,
        idle_timeout: 6_000,
        write_timeout: 2_000,
        max_lifetime: 10_000
      }

      f = G.fixture(@protocol, :http1, ["--manual"], %{member: member, endpoint: endpoint})
      {socket, seen, guardian, completion} = G.hold(f, "/hold/limits?raw=%2F")
      state = :sys.get_state(guardian)
      assert state.config === %{limits: member}
      assert state.submitted_url === f.origin <> "/hold/limits?raw=%2F"
      assert [":authority", "localhost:#{f.ready["port"]}"] in seen["headers"]
      assert G.assert_cleanup(f, 1) === @reserve
      G.command(f.peer, seen, "respond", %{"fields" => [["content-length", "0"]]})
      assert %{status: 200, body: ""} = G.response(f, socket)
      :ok = :gen_tcp.close(socket)
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      G.clean(f)
      G.close(f)
    end

    test "group #{protocol} opening timeout joins the original completion without replay" do
      f =
        G.fixture(@protocol, :http1, ["--manual"], %{
          endpoint: %{opening_timeout: 100, max_lifetime: 2_000}
        })

      {barrier, debug} = bind_barrier(f.groups)
      socket = G.connect(f)
      :ok = G.send_request(f, socket, "GET", "/hold/timeout")
      groups = f.groups
      group = f.group

      assert_receive {:group_bind_held, ^groups, guardian, {:bind, ^group, _, completion}},
                     @timeout

      assert %HTTP.RequestCompletion{} = completion
      assert %{"target" => "/hold/timeout"} = G.event(f.peer, "request")
      monitor = Process.monitor(guardian)
      send(groups, {:continue_group_bind, barrier})
      :ok = :sys.remove(groups, debug)
      assert %{status: 504} = G.response(f, socket)
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, reason}, @timeout
      assert reason in [:normal, :noproc]
      :ok = :gen_tcp.close(socket)
      G.clean(f)
      G.no_event(f.peer, "request")
      G.close(f)
    end

    test "group #{protocol} actual HEAD health failure blocks selection and actual recovery re-enables forwarding" do
      f =
        G.fixture(@protocol, :http1, ["--manual"], %{
          health: %{
            interval: 1_000,
            stale_after: 10_000,
            failure_threshold: 1,
            recovery_threshold: 1
          }
        })

      failed = G.event(f.peer, "request")
      assert failed["target"] === "/health"
      assert [":method", "HEAD"] in failed["headers"]

      G.command(f.peer, failed, "respond", %{
        "status" => 500,
        "fields" => [["content-length", "0"]]
      })

      G.eventually(fn ->
        match?(%{members: [%{health: :unhealthy}], probes: 0}, UpstreamGroups.status(f.group))
      end)

      socket = G.connect(f)
      :ok = G.send_request(f, socket, "GET", "/must-not-forward")
      assert %{status: 503} = G.response(f, socket)
      :ok = :gen_tcp.close(socket)
      G.eventually(fn -> Gaoxy.status(f.instance, :http).cleanup_pending === 0 end)
      assert :sys.get_state(f.groups).tokens === %{}
      recovered = G.event(f.peer, "request")
      assert recovered["target"] === "/health"
      assert [":method", "HEAD"] in recovered["headers"]
      G.command(f.peer, recovered, "respond", %{"fields" => [["content-length", "0"]]})

      G.eventually(fn ->
        match?(%{members: [%{health: :healthy}], probes: 0}, UpstreamGroups.status(f.group))
      end)

      {socket, seen, _, completion} = G.hold(f, "/hold/recovered")

      G.command(f.peer, seen, "respond", %{
        "body64" => Base.encode64("recovered"),
        "fields" => [["content-length", "9"]]
      })

      assert %{status: 200, body: "recovered"} = G.response(f, socket)
      :ok = :gen_tcp.close(socket)
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      G.clean(f)
      G.close(f)
    end

    test "group #{protocol} authentic baseline retirement drains admitted work and denies stale admission" do
      f = G.fixture(@protocol, :http1, ["--manual"])
      {socket, seen, _, completion} = G.hold(f, "/hold/retiring")
      assert G.assert_cleanup(f, 1) === @reserve
      G.release_baseline(f)
      assert %{lifecycle: :retiring, inflight: 1} = UpstreamGroups.status(f.group)
      next = G.connect(f)
      :ok = G.send_request(f, next, "GET", "/stale-must-not-forward")
      assert %{status: 503} = G.response(f, next)
      :ok = :gen_tcp.close(next)
      G.no_event(f.peer, "request")
      assert %{lifecycle: :retiring, inflight: 1} = UpstreamGroups.status(f.group)
      assert {:ok, %{request_tokens: 1}} = UpstreamTransports.status(f.owner)
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
      G.command(f.peer, seen, "respond", %{"fields" => [["content-length", "0"]]})
      assert %{status: 200, body: ""} = G.response(f, socket)
      :ok = :gen_tcp.close(socket)
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      G.clean_retired(f)
      G.close(f, :retired)
    end

    test "group #{protocol} queued cancellation at genuine original bind releases both owners without producer bytes" do
      f = G.fixture(@protocol, :http1, ["--manual"])
      {barrier, debug} = bind_barrier(f.groups)
      socket = G.connect(f)
      :ok = G.send_request(f, socket, "POST", "/echo?cancelled", [{"content-length", "3"}], false)
      :ok = G.send_body(f, socket, "abc", true)
      groups = f.groups
      group = f.group

      assert_receive {:group_bind_held, ^groups, guardian, {:bind, ^group, token, completion}},
                     @timeout

      assert is_reference(token)
      assert %HTTP.RequestCompletion{} = completion
      seen = G.event(f.peer, "request")
      assert seen["target"] === "/echo?cancelled"
      [{_, transport}] = Map.to_list(:sys.get_state(f.owner).tokens)
      assert transport.guardian === guardian
      assert transport.completion === completion
      G.no_event(f.peer, "upload")
      G.no_event(f.peer, "upload_end")
      monitor = Process.monitor(guardian)
      Session.cancel(guardian)

      G.eventually(fn ->
        {:messages, messages} = Process.info(guardian, :messages)
        Enum.any?(messages, &match?({:"$gen_cast", :cancel}, &1))
      end)

      send(groups, {:continue_group_bind, barrier})
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout
      :ok = :sys.remove(groups, debug)
      :ok = :gen_tcp.close(socket)
      G.clean(f)
      G.no_event(f.peer, "upload")
      G.no_event(f.peer, "upload_end")
      G.no_event(f.peer, "request")
      G.close(f)
    end
  end

  for protocol <- [:http2, :h2c] do
    @probe_protocol protocol
    test "group #{@probe_protocol} four real Probes own full65915448 bytes and the fifth starts only after an actual cleanup" do
      alias Gaoxy.HTTP.Resources
      f = G.fixture(@probe_protocol, :http1, ["--manual"])

      prepare = fn index ->
        assert {:ok, compiled} =
                 UpstreamGroups.compile(%{
                   id: "probe-#{index}",
                   members: [
                     %{
                       id: "only",
                       upstream: f.origin,
                       upstream_protocol: @probe_protocol,
                       transport: f.handle
                     }
                   ],
                   health: %{
                     path: "/four-health",
                     interval: 3_600_000,
                     stale_after: 3_600_000,
                     timeout: 5_000,
                     jitter: 0
                   }
                 })

        assert {:ok, group, preparation} =
                 UpstreamGroups.prepare(f.groups, compiled, self(), G.deadline())

        assert {:ok, baseline} = Resources.pin_many([group], self(), :baseline, G.deadline())
        assert :ok = Resources.release(preparation)
        {group, baseline}
      end

      first = for index <- 1..4, do: prepare.(index)

      requests =
        for _ <- 1..4 do
          seen = G.event(f.peer, "request")
          assert seen["target"] === "/four-health"
          assert [":method", "HEAD"] in seen["headers"]
          seen
        end

      G.eventually(fn ->
        state = :sys.get_state(f.groups)

        map_size(state.probes) === 4 and
          Enum.all?(
            state.probes,
            fn {_, probe} ->
              probe.claimed and match?(%HTTP.RequestCompletion{}, probe.completion)
            end
          )
      end)

      before = :sys.get_state(f.groups)
      assert before.probe_bytes === 65_915_448
      assert Enum.all?(before.probes, fn {_, probe} -> probe.bytes === @reserve end)
      G.assert_exact_controls(before)
      assert {:ok, %{request_tokens: 4}} = UpstreamTransports.status(f.owner)
      assert %{cleanup_pending: 0, retained_bytes: 0} = Gaoxy.status(f.instance, :http)
      {fifth, fifth_baseline} = prepare.(5)
      after_fifth = :sys.get_state(f.groups)
      assert after_fifth.probes === before.probes
      assert after_fifth.probe_bytes === before.probe_bytes
      assert after_fifth.probe_cursor === before.probe_cursor
      assert %{members: [%{health: :unknown, probe: false}]} = UpstreamGroups.status(fifth)
      G.no_event(f.peer, "request")

      for seen <- requests,
          do: G.command(f.peer, seen, "respond", %{"fields" => [["content-length", "0"]]})

      for {_, probe} <- before.probes,
          do: assert(:ok === HTTP.RequestCompletion.await(probe.completion, @timeout))

      seen = G.event(f.peer, "request")
      assert seen["target"] === "/four-health"
      assert [":method", "HEAD"] in seen["headers"]
      G.command(f.peer, seen, "respond", %{"fields" => [["content-length", "0"]]})
      G.eventually(fn -> map_size(:sys.get_state(f.groups).probes) === 0 end)
      assert :sys.get_state(f.groups).probe_bytes === 0

      for {group, baseline} <- first ++ [{fifth, fifth_baseline}] do
        assert %{members: [%{health: :healthy}]} = UpstreamGroups.status(group)
        assert :ok = Resources.release(baseline)
        assert {:error, :stale_group} = UpstreamGroups.status(group)
      end

      G.clean(f)
      G.close(f)
    end
  end

  defp bind_barrier(owner) do
    parent = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      case event do
        {:in, {:"$gen_call", {guardian, _}, {:bind, _, _, _} = request}} when not held ->
          send(parent, {:group_bind_held, self(), guardian, request})
          monitor = Process.monitor(parent)

          try do
            receive do
              {:continue_group_bind, ^barrier} -> :ok
              {:DOWN, ^monitor, :process, ^parent, _} -> :ok
            after
              @timeout -> raise "real group bind barrier expired"
            end
          after
            Process.demonitor(monitor, [:flush])
          end

          true

        _ ->
          held
      end
    end

    :ok = :sys.install(owner, {debug, false})

    on_exit(fn ->
      send(owner, {:continue_group_bind, barrier})
      if Process.alive?(owner), do: :sys.remove(owner, debug)
    end)

    {barrier, debug}
  end

  defp boundary(function), do: apply(ManagedH2GroupBoundary, function, [])
end
