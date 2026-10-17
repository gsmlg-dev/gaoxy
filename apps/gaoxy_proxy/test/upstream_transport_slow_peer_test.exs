Code.require_file("support/managed_h2_group_fixture.exs", __DIR__)

defmodule Gaoxy.Proxy.UpstreamTransportSlowPeerTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH2FixedFixture, as: F
  alias Gaoxy.Proxy.ManagedH2GroupFixture, as: G
  alias Gaoxy.Proxy.{ManagedH2GroupBoundary, UpstreamGroups, UpstreamTransports}
  @moduletag :capture_log
  @timeout 5_000
  @fixed_reserve 9_444_956
  @group_reserve 16_478_862

  defmodule ObservedEndpoint do
    @behaviour Gaoxy.HTTP.Endpoint
    def init(options) do
      {observer, options} = Map.pop(options, :observer)
      {delegate, options} = Map.pop(options, :delegate)
      with {:ok, config} <- delegate.init(options), do: {:ok, {observer, delegate, config}}
    end

    def resources({_, delegate, config}), do: delegate.resources(config)

    def call(exchange, {observer, delegate, config}) do
      send(
        observer,
        {:slow_exchange, self(), exchange.transport_state, exchange.gate, exchange.deadline,
         exchange.request.target}
      )

      delegate.call(exchange, config)
    end
  end

  for mount <- [:fixed, :group], upstream <- [:h2c, :http2] do
    @mount mount
    @upstream upstream
    test "#{mount} native H2 -> #{upstream} independent slow upload and response preserve sibling and finite originals" do
      if @mount == :group, do: assert(:ok === ManagedH2GroupBoundary.activation())
      run_profile(@mount, @upstream)
    end
  end

  defp run_profile(mount, upstream) do
    Process.put(:slow_deadline, now() + @timeout)
    Process.put(:slow_order, [])
    Process.put(:slow_checkpoints, [])
    Process.put(:slow_sampler, nil)
    delegate = if mount == :fixed, do: Gaoxy.Proxy.HTTP, else: Gaoxy.Proxy.GroupEndpoint

    overrides = %{
      endpoint_module: ObservedEndpoint,
      endpoint: %{observer: self(), delegate: delegate}
    }

    options = ["--manual", "--hold-upload-credit", "--slow-peer-profile"]

    f =
      if mount == :fixed,
        do: F.fixture(upstream, :http2, options, overrides),
        else: G.fixture(upstream, :http2, options, overrides)

    # Startup has its existing independent budgets; no request exists until open_upload.
    Process.put(:slow_deadline, now() + @timeout)
    baseline = baseline(mount, f)
    {ip, port} = Gaoxy.info(f.instance, :http).local |> then(fn {:ok, value} -> value end)
    assert ip == {127, 0, 0, 1}
    client = client(port)

    try do
      assert %{"initial_window" => 16_384, "safety_seconds" => 20} =
               client_event(client, "profile_client_ready")

      command_client(client, "open_upload")
      one = capture(mount, f, 1, "/hold/upload-credit")
      Process.put(:slow_sampler, sampler(mount, f, one.native_owner, one.deadline))
      first = peer_event(f.peer, "request")
      assert first["target"] === one.target
      assert [":method", "POST"] in first["headers"]
      one = Map.put(one, :seen, first)

      assert %{"initial_window" => 1, "connection" => connection} =
               peer_event(f.peer, "settings_ack")

      assert connection === first["connection"]
      assert %{"connection" => ^connection} = peer_event(f.peer, "accept")

      if upstream == :http2 do
        assert %{"connection" => ^connection, "alpn" => "h2", "sni" => "localhost"} =
                 peer_event(f.peer, "tls")
      end

      held1 = peer_event(f.peer, "upload_credit_held")
      assert held1["connection"] === connection and held1["stream"] === first["stream"]
      assert held1["held_bytes"] === 1 and held1["total_bytes"] === 1
      assert held1["stream_window"] === 0 and held1["connection_window"] > 0
      assert held1["sha256"] === digest(<<0>>)
      mark("upload1_actual_window1_hold")
      checkpoint(mount, f, baseline, [one], "upload1_held")

      command_client(client, "open_response")
      three = capture(mount, f, 3, "/hold/slow-response")
      seen3 = peer_event(f.peer, "request")
      three = Map.put(three, :seen, seen3)
      assert seen3["target"] === three.target and seen3["connection"] === connection
      assert [":method", "GET"] in seen3["headers"]
      assert_zero_upload(f.peer, seen3)
      refute seen3["stream"] === first["stream"]
      producer_command = respond(f.peer, seen3, body())
      producer_state = peer_profile_state(f.peer, producer_command["command_id"])
      assert producer_state["pending_bytes"] <= 1_048_576
      held3 = response_hold(client, 16_384)
      assert held3["stream_window"] === 0 and held3["connection_window"] > 0
      mark("response3_actual_unconsumed16384_hold")
      assert_pending_three(three)
      checkpoint(mount, f, baseline, [one, three], "both_holds")

      command_client(client, "open_sibling")
      five = capture(mount, f, 5, "/hold/healthy")
      seen5 = peer_event(f.peer, "request")
      five = Map.put(five, :seen, seen5)
      assert seen5["connection"] === connection and seen5["target"] === five.target
      assert [":method", "GET"] in seen5["headers"]
      assert_zero_upload(f.peer, seen5)
      originals = [one, three, five]
      assert Enum.uniq(Enum.map(originals, & &1.native_owner)) === [one.native_owner]
      assert Enum.map(originals, & &1.id) === [1, 3, 5]
      assert length(Enum.uniq(Enum.map(originals, & &1.seen["stream"]))) === 3
      peak = checkpoint(mount, f, baseline, originals, "overlap3_before_sibling_response")
      assert peak.native.pressure
      assert_pending_three(three)
      assert_upload_hold(f.peer, first)
      assert_response_hold(client)
      mark("actual_peak3_originals")
      respond(f.peer, seen5, "s")
      sibling_result = terminal(client, 5, "s")
      join_original(five)
      mark("healthy5_complete_before_either_release")
      checkpoint(mount, f, baseline, [one, three], "after_sibling2")
      assert_upload_hold(f.peer, first)
      assert_response_hold(client)
      assert_pending_three(three)

      resumed = peer_command(f.peer, first, "resume_upload_profile", %{"credit_bytes" => 65_536})
      assert resumed["credit_bytes"] === 65_536 and resumed["connection_credit_bytes"] === 1
      mark("release_only_upload1_exact65536")
      uploaded = peer_event(f.peer, "upload_end", first["stream"])
      assert uploaded["connection"] === connection and uploaded["total_bytes"] === 65_537
      assert Base.decode64!(uploaded["body64"]) === body()
      respond(f.peer, first, "u")
      upload_result = terminal(client, 1, "u")
      join_original(one)
      mark("upload1_complete_while_response3_held")
      checkpoint(mount, f, baseline, [three], "after_upload1")
      assert_response_hold(client)
      assert_pending_three(three)

      consumes = consume_response(client, 0, [])
      assert length(consumes) === 5
      response_result = terminal(client, 3, body())
      join_original(three)
      mark("response3_fully_consumed_and_complete")
      checkpoint(mount, f, baseline, [], "request0_socket_still_live")
      assert Process.alive?(one.native_owner)
      summary = stop_sampler()
      assert summary.samples > 0 and summary.maxima.pressure === 1
      assert summary.maxima.request_tokens === 3 and summary.maxima.cleanup_pending === 3
      if mount == :group, do: assert(summary.maxima.group_inflight === 3)
      native = system(one.native_owner)
      assert {%ThousandIsland.Socket{}, %{phase: :http2, writer: writer}} = native
      joins = for actor <- [one.native_owner, writer], do: {actor, Process.monitor(actor)}
      finish_id = command_client(client, "finish")

      assert %{"command_id" => ^finish_id, "socket_closed" => false, "forced" => 0, "live" => 0} =
               client_event(client, "profile_client_finished")

      assert %{
               "socket_closed" => true,
               "forced" => 0,
               "live" => 0,
               "consume_commands" => 5,
               "upload_bytes" => 65_537
             } = client_joined = client_event(client, "profile_client_joined")

      assert_client_exit(client, 0)

      physical_joins =
        for {actor, monitor} <- joins do
          receive do
            {:DOWN, ^monitor, :process, ^actor, reason} ->
              assert reason ===
                       if(actor === one.native_owner,
                         do: {:shutdown, :peer_closed},
                         else: :normal
                       )

              %{actor: digest(:erlang.term_to_binary(actor)), reason: inspect(reason)}
          after
            wait_budget() -> flunk("physical native actor did not join")
          end
        end

      if mount == :fixed, do: F.clean(f), else: G.clean(f)
      status = service_status(f)
      assert %{active: 0, cleanup_pending: 0, retained_bytes: 0, cleanup_failed: nil} = status

      assert status.retained_high_water <=
               if(mount == :fixed, do: 536_870_912, else: 1_073_741_824)

      assert Process.get({F, :observed_requests, f.peer}, 0) === baseline.setup_requests + 3
      F.no_event(f.peer, "request")
      state_command = peer_command(f.peer, first, "profile_snapshot")
      final_peer = peer_profile_state(f.peer, state_command["command_id"])

      assert final_peer["accepts"] === 1 and
               final_peer["requests"] === baseline.setup_requests + 3

      if mount == :fixed, do: F.close(f), else: G.close(f)
      mark("normal_physical_joins")

      receipt = %{
        tag: "GAOXY_SLOW_PEER_RECEIPT",
        mount: mount,
        upstream: upstream,
        downstream: :http2,
        order: Enum.reverse(Process.get(:slow_order)),
        body: %{bytes: byte_size(body()), sha256: digest(body())},
        upload_hold: held1,
        upload_complete: %{
          bytes: uploaded["total_bytes"],
          sha256: digest(Base.decode64!(uploaded["body64"]))
        },
        response_hold: held3,
        consumes: consumes,
        upstream_response_producer: producer_state,
        results:
          Enum.map([upload_result, response_result, sibling_result], &Map.drop(&1, ["body64"])),
        originals: Enum.map(originals, &identity_receipt/1),
        checkpoints: Enum.reverse(Process.get(:slow_checkpoints)),
        sampled: summary,
        persistent_retained_high_water: status.retained_high_water,
        client_joined: client_joined,
        final_peer: final_peer,
        joins: %{
          original_workers: 3,
          original_guardians: 3,
          native: physical_joins,
          fixture: :existing_normal_join_contract_pass,
          peer_forced: 0,
          peer_live: 0
        }
      }

      IO.puts("GAOXY_SLOW_PEER_RECEIPT " <> JSON.encode!(receipt))
    catch
      kind, reason ->
        stack = __STACKTRACE__
        failures = cleanup_case(client)

        if failures == [],
          do: :erlang.raise(kind, reason, stack),
          else:
            :erlang.raise(
              kind,
              {:slow_peer_case_failure, reason, cleanup_failures: failures},
              stack
            )
    end
  end

  defp body, do: :binary.copy(:erlang.list_to_binary(Enum.to_list(0..255)), 256) <> <<0>>
  defp digest(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)
  defp now, do: System.monotonic_time(:millisecond)
  defp remaining, do: max(0, Process.get(:slow_deadline) - now())

  defp wait_budget do
    value = min(@timeout, remaining())
    assert value > 0, "original absolute request deadline expired"
    value
  end

  defp system(actor), do: :sys.get_state(actor, min(500, wait_budget()))
  defp service_status(f), do: observe_status(fn -> Gaoxy.status(f.instance, :http) end)
  defp transport_status(f), do: observe_status(fn -> UpstreamTransports.status(f.owner) end)
  defp group_status(f), do: observe_status(fn -> UpstreamGroups.status(f.group) end)

  # Public status APIs have their own default timeout. This owned, unlinked
  # observer clips the whole call and its actual normal join to our deadline.
  defp observe_status(function) do
    expires = Process.get(:slow_deadline)
    _ = wait_budget()
    caller = self()
    tag = make_ref()

    {observer, monitor} =
      spawn_monitor(fn ->
        result =
          try do
            {:returned, function.()}
          catch
            kind, reason -> {:raised, kind, reason, __STACKTRACE__}
          end

        send(caller, {tag, result})
      end)

    case await_status(observer, monitor, tag, expires, nil) do
      {:returned, value} -> value
      {:raised, kind, reason, stack} -> :erlang.raise(kind, reason, stack)
    end
  end

  defp await_status(observer, monitor, tag, expires, result) do
    budget = min(@timeout, max(0, expires - now()))

    receive do
      {^tag, value} ->
        await_status(observer, monitor, tag, expires, value)

      {:DOWN, ^monitor, :process, ^observer, :normal} when result != nil ->
        assert now() < expires, "public status observer joined after original deadline"
        result

      {:DOWN, ^monitor, :process, ^observer, reason} ->
        flunk("public status observer failed before result: #{inspect(reason)}")
    after
      budget ->
        # Separate finite cleanup headroom cannot turn a timed-out observation
        # into success, even if a late result or normal exit is already queued.
        Process.exit(observer, :kill)

        joined =
          receive do
            {:DOWN, ^monitor, :process, ^observer, reason} -> {:joined, reason}
          after
            @timeout -> :unjoined
          end

        receive do
          {^tag, _late_result} -> :ok
        after
          0 -> :ok
        end

        flunk("public status observation exceeded original deadline; cleanup=#{inspect(joined)}")
    end
  end

  defp mark(value), do: Process.put(:slow_order, [value | Process.get(:slow_order)])

  defp await(predicate) do
    if predicate.(),
      do: :ok,
      else:
        (
          receive do
            {:slow_sampler_failure, kind, reason, stack} -> :erlang.raise(kind, reason, stack)
          after
            min(5, wait_budget()) -> :ok
          end

          await(predicate)
        )
  end

  defp baseline(mount, f) do
    transport = system(f.owner)
    assert transport.tokens === %{}
    pins = Map.new(transport.pins, fn {ref, held} -> {ref, held.public} end)
    assert Enum.all?(pins, fn {_, held} -> held.kind === :baseline end)

    group_pins =
      if mount == :group do
        state = system(f.groups)
        assert state.tokens === %{}
        assert Enum.all?(state.pins, fn {_, held} -> held.kind === :baseline end)
        state.pins
      else
        %{}
      end

    assert %{cleanup_pending: 0} = service_status(f)
    setup = Process.get({F, :observed_requests, f.peer}, 0)
    assert setup === if(mount == :group, do: 1, else: 0)
    %{transport_pins: pins, group_pins: group_pins, setup_requests: setup}
  end

  defp capture(mount, f, id, target) do
    {worker, native_owner, token, gate, deadline} =
      receive do
        {:slow_exchange, worker, {owner, ^id, token}, gate, deadline, ^target} ->
          {worker, owner, token, gate, deadline}
      after
        wait_budget() -> flunk("missing original native exchange #{id}")
      end

    # First actual deadline replaces the pre-request startup barrier. Later originals cannot extend it.
    earliest = Process.get(:slow_original_deadline, deadline) |> min(deadline)
    Process.put(:slow_original_deadline, earliest)
    Process.put(:slow_deadline, earliest)

    await(fn ->
      Enum.any?(system(f.owner).tokens, fn {_, held} ->
        Process.alive?(held.guardian) and system(held.guardian).owner === worker
      end)
    end)

    transport = system(f.owner)

    [{transport_token, hold}] =
      Enum.filter(transport.tokens, fn {_, held} -> system(held.guardian).owner === worker end)

    state = system(hold.guardian)
    assert state.submitted_url === f.origin <> target
    assert state.client.completion(state.original_request) === hold.completion
    assert state.transport_selection === {f.handle, transport_token}
    assert state.managed_path === true and state.managed_transport === nil

    assert state.request_options === nil and state.selector === nil and
             state.awaiting_transport === nil

    pins =
      Map.new(
        for {ref, held} <- transport.pins,
            held.public.kind === :request and held.public.holder in [worker, hold.guardian],
            do: {ref, held.public}
      )

    assert Enum.any?(pins, fn {_, pin} -> pin.holder === worker end)
    assert [_ | _] = state.transport_pins

    assert Enum.all?(state.transport_pins, fn pin ->
             pins[pin.ref] === pin and pin.holder === hold.guardian
           end)

    assert Enum.all?(pins, fn {_, pin} -> pin.handles === [f.handle] and pin.owner === f.owner end)

    held = %{
      id: id,
      target: target,
      worker: worker,
      guardian: hold.guardian,
      native_owner: native_owner,
      native_token: token,
      gate: gate,
      deadline: deadline,
      transport_token: transport_token,
      completion: hold.completion,
      original_request: state.original_request,
      transport_pins: state.transport_pins,
      request_pins: pins,
      worker_monitor: Process.monitor(worker),
      guardian_monitor: Process.monitor(hold.guardian)
    }

    if mount == :group do
      groups = system(f.groups)

      [{group_token, group_hold}] =
        Enum.filter(groups.tokens, fn {_, value} -> value.guardian === hold.guardian end)

      assert group_hold.completion === hold.completion and
               state.selection === {f.group, group_token}

      group_pins =
        Map.new(
          for {ref, pin} <- groups.pins,
              pin.kind === :request and pin.holder in [worker, hold.guardian],
              do: {ref, pin}
        )

      assert map_size(group_pins) > 0
      assert Enum.all?(group_pins, fn {_, pin} -> pin.keys === [group_hold.key] end)
      Map.merge(held, %{group_token: group_token, group_pins: group_pins})
    else
      assert state.selection === nil
      held
    end
  end

  defp checkpoint(mount, f, baseline, originals, name) do
    tokens = MapSet.new(originals, & &1.transport_token)
    pins = Enum.reduce(originals, baseline.transport_pins, &Map.merge(&2, &1.request_pins))
    group_tokens = MapSet.new(originals, &Map.get(&1, :group_token))

    group_pins =
      Enum.reduce(originals, baseline.group_pins, &Map.merge(&2, Map.get(&1, :group_pins, %{})))

    count = length(originals)

    await(fn ->
      transport = system(f.owner)

      MapSet.new(Map.keys(transport.tokens)) === tokens and
        Map.new(transport.pins, fn {ref, held} -> {ref, held.public} end) === pins and
        service_status(f).cleanup_pending === count and
        (mount == :fixed or
           (MapSet.new(Map.keys(system(f.groups).tokens)) === group_tokens and
              system(f.groups).pins === group_pins))
    end)

    assert {:ok,
            %{request_tokens: ^count, resources: 1, reserved_connections: 2, helpers: 0} =
              transport_status} = transport_status(f)

    assert transport_status.owned_serialized_payload_bytes <= 4_194_304

    assert system(f.owner).limits === %{
             max_resources: 2,
             max_pins: 256,
             max_request_tokens: 64,
             max_owned_payload_bytes: 4_194_304
           }

    status = service_status(f)
    assert status.cleanup_pending === count and status.cleanup_failed === nil
    native_owner = Process.get(:slow_native_owner) || hd(originals).native_owner
    Process.put(:slow_native_owner, native_owner)
    native = native_snapshot(native_owner, Enum.map(originals, &{&1.id, &1.native_token}))
    gate = system(native.gate)
    reserve = if mount == :fixed, do: @fixed_reserve, else: @group_reserve
    assert map_size(gate.cleanups) === count
    assert Enum.all?(gate.cleanups, fn {_, value} -> value.bytes === reserve end)
    assert gate.high_water <= gate.limits.max_bytes and gate.bytes <= gate.limits.max_bytes
    assert gate.limits.max_active === 64
    assert gate.limits.max_bytes === if(mount == :fixed, do: 536_870_912, else: 1_073_741_824)
    assert status.retained_bytes >= count * reserve
    assert status.retained_bytes <= gate.limits.max_bytes

    if mount == :group do
      assert %{inflight: ^count, probes: 0, probe_bytes: 0} = group_status(f)
      G.assert_exact_controls(system(f.groups))
    end

    for held <- originals do
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(held.completion, 0)
      state = system(held.guardian)
      assert state.original_request === held.original_request
      assert state.client.completion(state.original_request) === held.completion
      assert state.transport_selection === {f.handle, held.transport_token}
      assert state.transport_pins === held.transport_pins
      assert state.owner === held.worker and Process.alive?(held.worker)
      if mount == :group, do: assert(state.selection === {f.group, held.group_token})
    end

    value = %{
      name: name,
      at_ms: now(),
      deadline_ms: Process.get(:slow_deadline),
      remaining_ms: remaining(),
      requests: count,
      request_tokens: count,
      cleanup_pending: status.cleanup_pending,
      group_inflight: if(mount == :group, do: count, else: nil),
      retained_bytes: status.retained_bytes,
      persistent_retained_high_water: status.retained_high_water,
      native: Map.delete(native, :gate)
    }

    value =
      Map.merge(value, %{
        transport_limits: system(f.owner).limits,
        transport: transport_status,
        service_limits: gate.limits,
        per_resource_request_limit_source_contract: 32,
        mailbox_ceiling: 64,
        actor_mailboxes:
          mailbox_sizes(
            [f.owner | Enum.flat_map(originals, &[&1.worker, &1.guardian])] ++
              if(mount == :group, do: [f.groups], else: [])
          )
      })

    Process.put(:slow_checkpoints, [value | Process.get(:slow_checkpoints)])
    sample_barrier()
    value
  end

  defp native_snapshot(owner, expected) do
    assert {%ThousandIsland.Socket{}, %{phase: :http2, owner: ^owner} = state} = system(owner)

    for {id, token} <- expected do
      assert %{token: ^token} = Map.fetch!(state.streams, id)
    end

    parser = byte_size(state.buffer)
    output = :queue.len(state.output)
    assert parser <= state.limits.max_buffer_bytes
    assert output <= state.h2.control_rate + state.h2.max_streams * 8

    streams =
      for {id, stream} <- state.streams do
        pending =
          case stream.write do
            nil -> 0
            %{kind: :data, bytes: bytes} -> byte_size(bytes)
            %{kind: :headers} -> 0
          end

        assert pending <= 16_384
        assert stream.queued_wire >= 0 and stream.delivered_wire >= 0
        assert stream.queued_wire + stream.delivered_wire <= state.h2.receive_window
        assert byte_size(stream.input) <= stream.queued_wire

        %{
          id: id,
          input_bytes: byte_size(stream.input),
          queued_wire: stream.queued_wire,
          delivered_wire: stream.delivered_wire,
          pending_write_bytes: pending,
          write_kind: if(stream.write, do: stream.write.kind, else: nil),
          receive_window: stream.recv_window,
          send_window: stream.send_window
        }
      end

    actors = [owner, state.writer | Enum.map(state.streams, fn {_, stream} -> stream.worker end)]
    mailboxes = mailbox_sizes(actors)

    pressure =
      output > 0 or
        Enum.any?(
          streams,
          &(&1.input_bytes > 0 or &1.queued_wire > 0 or
              &1.delivered_wire > 0 or &1.pending_write_bytes > 0)
        )

    %{
      gate: state.gate,
      parser_bytes: parser,
      output_items: output,
      streams: streams,
      pressure: pressure,
      mailboxes: mailboxes,
      http_limits: state.limits,
      h2_limits: state.h2,
      physical_reserves: state.reserves,
      inflight_data_bytes: if(state.inflight_write, do: state.inflight_write.credit, else: 0)
    }
  end

  defp mailbox_sizes(actors) do
    Enum.reduce(Enum.uniq(actors), [], fn actor, values ->
      case is_pid(actor) && Process.info(actor, :message_queue_len) do
        {:message_queue_len, size} ->
          assert size <= 64,
                 "owned actor exceeded fixed-profile mailbox ceiling: #{inspect(actor)} #{size}"

          [%{actor: digest(:erlang.term_to_binary(actor)), messages: size} | values]

        false ->
          values

        nil ->
          values
      end
    end)
  end

  defp sampler(mount, f, owner, deadline) do
    caller = self()

    spawn_monitor(fn ->
      Process.put(:slow_deadline, deadline)
      monitor = Process.monitor(caller)
      sample_loop(caller, monitor, mount, f, owner, %{samples: 0, maxima: %{}})
    end)
  end

  defp sample_loop(caller, monitor, mount, f, owner, totals) do
    receive do
      {:stop_sampler, ^caller} ->
        send(caller, {:slow_samples, self(), totals})

      {:DOWN, ^monitor, :process, ^caller, _} ->
        :ok

      {:sample_now, ^caller, reference} ->
        sample_turn(caller, monitor, mount, f, owner, totals, reference)
    after
      5 -> sample_turn(caller, monitor, mount, f, owner, totals, nil)
    end
  end

  defp sample_turn(caller, monitor, mount, f, owner, totals, reference) do
    result =
      try do
        snapshot = native_snapshot(owner, [])
        transport = system(f.owner)
        guardians = Enum.map(transport.tokens, fn {_, held} -> held.guardian end)
        actors = [f.owner | guardians] ++ if(mount == :group, do: [f.groups], else: [])
        boxes = snapshot.mailboxes ++ mailbox_sizes(actors)
        status = service_status(f)
        assert {:ok, transport_status} = transport_status(f)

        assert transport_status.owned_serialized_payload_bytes <=
                 transport.limits.max_owned_payload_bytes

        assert status.retained_bytes <= if(mount == :fixed, do: 536_870_912, else: 1_073_741_824)

        assert status.retained_high_water <=
                 if(mount == :fixed, do: 536_870_912, else: 1_073_741_824)

        maxima = %{
          parser_bytes: snapshot.parser_bytes,
          output_items: snapshot.output_items,
          input_bytes: maximum(snapshot.streams, :input_bytes),
          queued_wire: maximum(snapshot.streams, :queued_wire),
          delivered_wire: maximum(snapshot.streams, :delivered_wire),
          pending_write_bytes: maximum(snapshot.streams, :pending_write_bytes),
          mailbox_messages: maximum(boxes, :messages),
          pressure: if(snapshot.pressure, do: 1, else: 0),
          request_tokens: map_size(transport.tokens),
          cleanup_pending: status.cleanup_pending,
          owned_serialized_payload_bytes: transport_status.owned_serialized_payload_bytes,
          retained_bytes: status.retained_bytes,
          group_inflight: if(mount == :group, do: group_status(f).inflight, else: 0)
        }

        assert maxima.request_tokens <= 3 and maxima.cleanup_pending <= 3 and
                 maxima.group_inflight <= 3

        maxima = Map.merge(totals.maxima, maxima, fn _, old, value -> max(old, value) end)
        {:ok, maxima}
      catch
        kind, reason ->
          send(caller, {:slow_sampler_failure, kind, reason, __STACKTRACE__})
          :failed
      end

    case result do
      {:ok, maxima} ->
        if reference != nil, do: send(caller, {:slow_sampled, self(), reference})

        sample_loop(caller, monitor, mount, f, owner, %{
          samples: totals.samples + 1,
          maxima: maxima
        })

      :failed ->
        :ok
    end
  end

  defp sample_barrier do
    {pid, _} = Process.get(:slow_sampler)
    reference = make_ref()
    send(pid, {:sample_now, self(), reference})

    receive do
      {:slow_sampled, ^pid, ^reference} -> :ok
      {:slow_sampler_failure, kind, reason, stack} -> :erlang.raise(kind, reason, stack)
    after
      wait_budget() -> flunk("sampler did not observe actual checkpoint")
    end
  end

  defp maximum(values, key), do: Enum.reduce(values, 0, &max(Map.fetch!(&1, key), &2))

  defp stop_sampler do
    {pid, monitor} = Process.get(:slow_sampler)
    send(pid, {:stop_sampler, self()})

    result =
      receive do
        {:slow_samples, ^pid, totals} -> totals
        {:slow_sampler_failure, kind, reason, stack} -> :erlang.raise(kind, reason, stack)
      after
        wait_budget() -> flunk("sampler failed to return finite observations")
      end

    receive do
      {:DOWN, ^monitor, :process, ^pid, reason} -> assert reason === :normal
    after
      wait_budget() -> flunk("sampler did not normally join")
    end

    Process.put(:slow_sampler, nil)
    result
  end

  defp assert_pending_three(three) do
    await(fn ->
      assert {%ThousandIsland.Socket{}, %{phase: :http2} = state} = system(three.native_owner)

      case Map.get(state.streams, 3) do
        %{token: token, send_window: 0, write: %{kind: :data, bytes: bytes}} ->
          token === three.native_token and byte_size(bytes) > 0

        _ ->
          false
      end
    end)

    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(three.completion, 0)
  end

  defp peer_event(peer, event, stream \\ nil) do
    receive do
      {:fixed_h2_peer, ^peer, %{"event" => ^event, "stream" => ^stream} = value}
      when stream != nil ->
        value

      {:fixed_h2_peer, ^peer, %{"event" => ^event} = value} when stream == nil ->
        if event == "request" do
          key = {F, :observed_requests, peer}
          Process.put(key, Process.get(key, 0) + 1)
        end

        value

      {:fixed_h2_peer, ^peer, %{"event" => "failure"} = value} ->
        flunk(inspect(value))

      {:fixed_h2_peer_exit, ^peer, status} ->
        flunk("peer exited #{status} before #{event}")

      {:slow_sampler_failure, kind, reason, stack} ->
        :erlang.raise(kind, reason, stack)
    after
      wait_budget() -> flunk("missing independent peer #{event} stream #{inspect(stream)}")
    end
  end

  defp peer_command(peer, request, op, extra \\ %{}) do
    id = System.unique_integer([:positive])

    send(
      peer,
      {:command,
       Map.merge(
         %{
           "op" => op,
           "connection" => request["connection"],
           "stream" => request["stream"],
           "command_id" => id
         },
         extra
       )}
    )

    value = peer_event(peer, "command")
    assert value["command_id"] === id and value["op"] === op
    value
  end

  defp respond(peer, seen, bytes) do
    peer_command(peer, seen, "respond", %{
      "status" => 200,
      "fields" => [
        ["content-type", "application/octet-stream"],
        ["content-length", Integer.to_string(byte_size(bytes))]
      ],
      "body64" => Base.encode64(bytes),
      "ended" => true
    })
  end

  defp assert_zero_upload(peer, seen) do
    value = peer_event(peer, "upload_end", seen["stream"])
    assert value["total_bytes"] === 0 and value["connection"] === seen["connection"]
  end

  defp assert_upload_hold(peer, seen) do
    command = peer_command(peer, seen, "profile_snapshot")
    id = command["command_id"]
    value = peer_profile_state(peer, id)
    assert value["upload_bytes"] === 1 and value["upload_sha256"] === digest(<<0>>)
    assert value["credit_released"] === false and value["upload_window"] === 0
    assert value["connection_receive_window"] > 0
  end

  defp peer_profile_state(peer, id) do
    value = peer_event(peer, "profile_peer_state")
    if value["command_id"] === id, do: value, else: peer_profile_state(peer, id)
  end

  defp client(port) do
    script = Path.expand("support/managed_h2_fixed_peer.py", __DIR__)

    Port.open(
      {:spawn_executable, ~c"/tmp/gaoxy-m3-h2-soak-venv/bin/python"},
      [
        :binary,
        :exit_status,
        {:line, 262_144},
        {:args,
         [
           script,
           "--client",
           "--downstream",
           "h2",
           "--port",
           Integer.to_string(port),
           "--controlled",
           "--events",
           "--slow-peer-profile"
         ]}
      ]
    )
  end

  defp command_client(port, op, values \\ %{}) do
    id = System.unique_integer([:positive])

    true =
      Port.command(port, [
        JSON.encode!(Map.merge(%{"op" => op, "command_id" => id}, values)),
        "\n"
      ])

    id
  end

  defp client_event(port, event, stream \\ nil) do
    key = {:slow_client_events, port}
    queued = Process.get(key, [])

    case Enum.split_while(queued, fn value ->
           value["event"] != event or (stream != nil and value["stream"] != stream)
         end) do
      {before, [value | rest]} ->
        Process.put(key, before ++ rest)
        value

      _ ->
        receive do
          {^port, {:data, {:eol, line}}} ->
            value = JSON.decode!(line)
            if value["event"] == "client_failure", do: flunk(inspect(value))
            assert length(queued) < 256
            Process.put(key, queued ++ [value])
            client_event(port, event, stream)

          {^port, {:data, {:noeol, _}}} ->
            flunk("profile client exceeded finite event line")

          {^port, {:exit_status, status}} ->
            flunk("client exited #{status} before #{event}")

          {:slow_sampler_failure, kind, reason, stack} ->
            :erlang.raise(kind, reason, stack)
        after
          wait_budget() -> flunk("missing independent client #{event} stream #{inspect(stream)}")
        end
    end
  end

  defp response_hold(port, expected) do
    value = client_event(port, "profile_client_data", 3)
    assert value["held_bytes"] <= expected
    assert value["ended"] === false
    if value["held_bytes"] === expected, do: value, else: response_hold(port, expected)
  end

  defp assert_response_hold(port) do
    id = command_client(port, "snapshot", %{"stream" => 3})
    value = client_event(port, "profile_client_state", 3)
    assert value["command_id"] === id and value["held_bytes"] === 16_384
    assert value["stream_window"] === 0 and value["ended"] === false
  end

  defp consume_response(port, total, receipts) do
    if total === 65_537 do
      Enum.reverse(receipts)
    else
      expected = min(16_384, 65_537 - total)

      hold =
        if total == 0 do
          %{"held_bytes" => 16_384}
        else
          response_hold_final(port, expected)
        end

      assert hold["held_bytes"] === expected
      id = command_client(port, "consume_response", %{"bytes" => expected})
      value = client_event(port, "profile_client_consumed", 3)
      assert value["command_id"] === id and value["before"] === expected
      assert value["bytes"] === expected and value["after"] === 0
      assert value["count"] === length(receipts) + 1 and value["count"] <= 5
      consume_response(port, total + expected, [value | receipts])
    end
  end

  defp response_hold_final(port, expected) do
    value = client_event(port, "profile_client_data", 3)
    assert value["held_bytes"] <= expected
    if value["held_bytes"] === expected, do: value, else: response_hold_final(port, expected)
  end

  defp terminal(port, stream, bytes) do
    value = client_event(port, "profile_client_end", stream)
    assert value["status"] === 200 and value["complete"] === true and value["ended"] === true
    assert value["received_bytes"] === byte_size(bytes)
    assert value["body_sha256"] === digest(bytes) and Base.decode64!(value["body64"]) === bytes
    value
  end

  defp join_original(held) do
    assert :ok = HTTP.RequestCompletion.await(held.completion, wait_budget())

    for {actor, monitor} <- [
          {held.worker, held.worker_monitor},
          {held.guardian, held.guardian_monitor}
        ] do
      receive do
        {:DOWN, ^monitor, :process, ^actor, reason} -> assert reason === :normal
      after
        wait_budget() -> flunk("original request actor did not normally join")
      end
    end
  end

  defp assert_client_exit(port, expected) do
    receive do
      {^port, {:exit_status, status}} -> assert status === expected
    after
      wait_budget() -> flunk("independent profile client failed to join")
    end
  end

  defp identity_receipt(held) do
    %{
      native_stream: held.id,
      native_token_sha256: digest(:erlang.term_to_binary(held.native_token)),
      original_request_sha256: digest(:erlang.term_to_binary(held.original_request)),
      completion_sha256: digest(:erlang.term_to_binary(held.completion)),
      transport_token_sha256: digest(:erlang.term_to_binary(held.transport_token)),
      upstream_connection: held.seen["connection"],
      upstream_stream: held.seen["stream"],
      deadline_ms: held.deadline,
      worker_sha256: digest(:erlang.term_to_binary(held.worker)),
      guardian_sha256: digest(:erlang.term_to_binary(held.guardian)),
      request_pin_count: map_size(held.request_pins),
      group_pin_count: map_size(Map.get(held, :group_pins, %{}))
    }
  end

  defp cleanup_case(client) do
    sampler_failures =
      case Process.get(:slow_sampler) do
        nil ->
          []

        {actor, monitor} ->
          send(actor, {:stop_sampler, self()})

          receive do
            {:DOWN, ^monitor, :process, ^actor, :normal} -> []
            {:DOWN, ^monitor, :process, ^actor, reason} -> [{:sampler_exit, inspect(reason)}]
          after
            @timeout -> [:sampler_unjoined]
          end
      end

    client_failures =
      if Port.info(client) == nil do
        []
      else
        try do
          true = Port.command(client, [JSON.encode!(%{"op" => "stop"}), "\n"])

          receive do
            {^client, {:exit_status, _}} -> []
          after
            @timeout ->
              Port.close(client)
              [:client_forced_unjoined]
          end
        catch
          kind, reason -> [{:client_cleanup_failed, kind, inspect(reason)}]
        end
      end

    sampler_failures ++ client_failures
  end
end
