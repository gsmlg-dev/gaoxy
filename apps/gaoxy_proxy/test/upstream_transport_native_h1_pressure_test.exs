Code.require_file("support/managed_h1_matrix_fixture.exs", __DIR__)

defmodule Gaoxy.Proxy.UpstreamTransportNativeH1PressureTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH1MatrixFixture, as: Fixture
  alias Gaoxy.Proxy.{HTTPFetchClient, UpstreamGroups, UpstreamTransports}
  alias Gaoxy.HTTP.Resources
  alias Hell.Socket

  @moduletag :capture_log
  @moduletag timeout: 40_000
  @barrier 5_000
  @capacity 16_777_216
  @native_upper 149_504
  @original_upper 8_011_816
  @combined_upper 16_322_640
  @wire_limit 1_048_576
  @prefix_bytes 262_144

  defmodule ObservedEndpoint do
    @behaviour Gaoxy.HTTP.Endpoint

    def init(%{pressure_observer: observer, pressure_delegate: module} = options) do
      options = Map.drop(options, [:pressure_observer, :pressure_delegate])
      with {:ok, config} <- module.init(options), do: {:ok, {module, config, observer}}
    end

    def resources({module, config, _observer}), do: module.resources(config)

    def generation_validate({module, config, _observer}) do
      if function_exported?(module, :generation_validate, 1),
        do: module.generation_validate(config),
        else: :ok
    end

    def call(exchange, {module, config, observer}) do
      if exchange.request.path == "/pressure/slow" do
        :ok = Hell.Socket.setopts(exchange.socket, sndbuf: 1024)
      end

      send(
        observer,
        {:pressure_exchange,
         %{
           owner: self(),
           socket: exchange.socket,
           gate: exchange.gate,
           lease: exchange.lease,
           deadline: exchange.deadline,
           target: exchange.request.path,
           limits: exchange.limits,
           head_bytes: exchange.request.head_bytes,
           buffer_bytes: byte_size(exchange.buffer),
           poll_bytes: exchange.poll_buffer_bytes,
           route_bytes: exchange.route_bytes,
           protocol_bytes: exchange.protocol_bytes,
           trailer_bytes: exchange.body.trailer_bytes,
           response_trailers: exchange.response_trailers
         }}
      )

      module.call(exchange, config)
    end
  end

  for mount <- ["fixed", "group"], upstream <- ["tcp", "tls"] do
    @mount mount
    @upstream upstream

    test "#{mount}/#{upstream} native-H1 response pressure preserves a separate healthy connection" do
      Process.put(:pressure_controller, self())
      Process.put(:pressure_deadline, now() + @barrier)
      event_table = :ets.new(:pressure_events, [:set, :public])
      true = :ets.insert(event_table, {:count, 0})
      Process.put(:pressure_events, event_table)
      Process.put(:pressure_phases, [])
      Process.put(:pressure_last_snapshot, nil)
      Process.put(:pressure_clients, [])
      Process.put(:pressure_originals, [])
      Process.put(:pressure_requests, [])
      Process.put(:pressure_health_requests, [])
      Process.put(:pressure_actors, [])
      Process.put(:pressure_sampler, nil)
      Process.put(:pressure_handler, nil)
      Process.put(:pressure_stopped, false)
      Process.put(:pressure_group_joined, false)
      Process.put(:pressure_events_quiesced, false)
      Process.put(:pressure_observers, :ets.new(:pressure_observers, [:set, :public]))

      f =
        Fixture.start(%{"mount" => @mount, "downstream" => "h1", "upstream" => @upstream}, %{
          endpoint_module: ObservedEndpoint,
          endpoint: %{
            pressure_observer: self(),
            pressure_delegate:
              if(@mount == "group", do: Gaoxy.Proxy.GroupEndpoint, else: Gaoxy.Proxy.HTTP)
          }
        })

      try do
        run_probe(f)
        Process.put(:pressure_events_quiesced, true)
      catch
        kind, reason ->
          stack = __STACKTRACE__
          failure_chronology(kind, reason, stack)
          failures = failure_cleanup(f)
          if failures === [], do: Process.put(:pressure_events_quiesced, true)

          :erlang.raise(
            kind,
            {:native_h1_pressure_failed, reason, cleanup_failures: failures},
            stack
          )
      after
        if handler = Process.get(:pressure_handler), do: :telemetry.detach(handler)
        if Process.get(:pressure_events_quiesced), do: :ets.delete(Process.get(:pressure_events))
        :ets.delete(Process.get(:pressure_observers))
      end
    end
  end

  defp run_probe(f) do
    transport = system(f.owner)
    assert transport.tokens === %{}
    transport_baseline = Map.new(transport.pins, fn {ref, pin} -> {ref, pin.public} end)

    if f.group,
      do: assert(map_size(transport_baseline) === 2),
      else: assert([_] = Map.values(transport_baseline))

    assert Enum.all?(transport_baseline, fn {_, pin} ->
             pin.kind === :baseline and pin.holder === self() and
               pin.owner === f.owner and pin.handles === [f.handle]
           end)

    group_baseline =
      if f.group do
        groups = system(f.groups)
        assert groups.tokens === %{}
        [{ref, pin}] = Map.to_list(groups.pins)
        assert pin.kind === :baseline and pin.holder === self()
        assert pin.keys === [{f.group.group, f.group.generation}]
        assert groups.epoch === f.group.owner_epoch and f.group.owner === f.groups
        assert Map.fetch!(groups.groups, {f.group.group, f.group.generation}).handle === f.group
        assert is_reference(ref) and is_reference(pin.operation)
        # H1 group records retain the identity needed for the provider's public pin.
        public_pin =
          Map.merge(Map.take(f.group, [:provider, :owner, :owner_epoch]), %{
            ref: ref,
            operation: pin.operation,
            handles: [f.group],
            kind: pin.kind
          })

        assert %{inflight: 0, probes: 0, probe_bytes: 0} = group_status(f)
        health = Fixture.event(f, %{"event" => "request", "role" => "health"}, budget())
        assert health["method"] === "HEAD" and health["target"] === "/health"
        Process.put(:pressure_health_requests, [health])
        %{pins: groups.pins, public_pins: [public_pin]}
      else
        %{pins: %{}, public_pins: []}
      end

    baseline = %{
      transport_pins: transport_baseline,
      group_pins: group_baseline.pins,
      group_release_pins: group_baseline.public_pins
    }

    assert %{active: 0, cleanup_pending: 0, retained_bytes: 0, cleanup_failed: nil} = service(f)
    assert_transport_limits(transport.limits)

    slow_client = start_client(f, "/pressure/slow", :slow)
    slow_exchange = capture_exchange("/pressure/slow")
    gate = system(slow_exchange.gate)
    assert gate.limits.max_bytes === @capacity and gate.limits.max_active === 64
    assert slow_exchange.limits.request_timeout === 10_000
    assert slow_exchange.limits.write_timeout === 2_000
    assert slow_exchange.limits.max_buffer_bytes === 65_536
    assert Map.get(slow_exchange.limits, :max_write_chunk, 16_384) === 16_384
    {:ok, server_options} = observe(fn -> Socket.getopts(slow_exchange.socket, [:sndbuf]) end)
    assert Keyword.fetch!(server_options, :sndbuf) in 1..16_384
    attach_telemetry(gate.scope)

    first = request(f, "/pressure/slow")
    slow = bind_original(f, slow_exchange)
    checkpoint(f, baseline, [slow], "slow_original")
    start_sampler(f, slow_exchange)
    phase(:sampler_started)

    head =
      "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: application/octet-stream\r\n\r\n"

    send_raw(f, first, head, false)
    await_command(f, first, false, head)
    send(slow_client.pid, {:read_head, Process.get(:pressure_deadline)})
    slow_head = client_message(slow_client, :head)
    assert slow_head.status === 200 and slow_head.framing === :chunked
    phase(:head_received)

    assert slow_head.head_bytes in 1..8192

    await(fn ->
      values = events()
      starts = Enum.filter(values, &(&1.event === :send_started))

      starts !== [] and Enum.sum(Enum.map(starts, & &1.bytes)) === slow_head.head_bytes and
        Enum.all?(starts, fn started ->
          Enum.count(values, fn event ->
            event.event === :send and event.operation === started.operation and
              event.outcome === :ok and event.bytes === started.bytes
          end) === 1
        end)
    end)

    head_started = Enum.filter(events(), &(&1.event === :send_started))
    head_operations = Enum.map(head_started, & &1.operation)
    assert head_operations !== []
    assert length(Enum.uniq(head_operations)) === length(head_operations)
    assert Enum.sum(Enum.map(head_started, & &1.bytes)) === slow_head.head_bytes

    head_outcomes =
      Enum.map(head_started, fn started ->
        assert send_event(:send_started, started.operation) === started
        completed = send_event(:send, started.operation)
        assert completed.outcome === :ok and completed.bytes === started.bytes
        completed
      end)

    head_completed_us = Enum.max(Enum.map(head_outcomes, & &1.at_us))
    head_gate = system(slow_exchange.gate)
    assert %{pid: head_owner, send: nil} = Map.fetch!(head_gate.leases, slow_exchange.lease)
    assert head_owner === slow_exchange.owner

    prefix = binary_part(body(), 0, @prefix_bytes)
    raw_prefix = Integer.to_string(byte_size(prefix), 16) <> "\r\n" <> prefix <> "\r\n"
    assert byte_size(head) + byte_size(raw_prefix) + 11 <= @wire_limit
    send_raw(f, first, raw_prefix, false)
    phase(:prefix_dispatched)
    pressure1 = await_pressure(f, slow)
    phase(:first_pressure_found)
    operation = pressure1.operation
    framed_bytes = pressure1.bytes
    witness = {operation, framed_bytes}
    refute operation in head_operations
    started = send_event(:send_started, operation)
    assert started.bytes === framed_bytes and started.at_us >= head_completed_us
    Process.put(:pressure_send_deadline, div(started.at_us, 1000) + 2_000)
    send_sampler_deadline()

    healthy_client = start_client(f, "/pressure/healthy", :healthy)
    healthy_exchange = capture_exchange("/pressure/healthy")
    assert healthy_exchange.owner != slow_exchange.owner
    second = request(f, "/pressure/healthy")
    assert second["connection"] != first["connection"]
    healthy = bind_original(f, healthy_exchange)
    overlap = checkpoint(f, baseline, [slow, healthy], "two_originals")
    pressure_overlap = pressure(f, slow, witness)
    phase(:healthy_overlap)
    healthy_raw = "HTTP/1.1 200 OK\r\nContent-Length: 1\r\n\r\nh"
    send_raw(f, second, healthy_raw, true)
    await_command(f, second, true, healthy_raw)
    send(healthy_client.pid, {:read_head, Process.get(:pressure_deadline)})
    assert %{status: 200, framing: {:length, 1}} = client_message(healthy_client, :head)
    assert %{body: "h", bytes: 1} = healthy_reply = client_message(healthy_client, :complete)
    join_original(healthy)
    after_healthy = checkpoint(f, baseline, [slow], "healthy_joined")
    phase(:after_healthy)
    pressure2 = pressure(f, slow, witness)
    sample_barrier()
    before_release = pressure(f, slow, witness)
    refute Enum.any?(events(), &(&1.event === :send and &1.operation === operation))

    release = make_ref()
    send(slow_client.pid, {:release, release})
    phase(:release_dispatched)
    entered = client_message(slow_client, {:entered, release})
    assert entered.read_entered_us >= entered.release_us
    assert healthy_reply.at_us <= entered.release_us
    outcome = await_send_success(operation)
    assert outcome.at_us >= entered.read_entered_us
    assert outcome.bytes === framed_bytes and outcome.outcome === :ok
    Process.delete(:pressure_send_deadline)
    send_sampler_deadline()
    consumed_prefix = client_message(slow_client, :prefix)
    phase(:prefix_consumed)
    assert consumed_prefix.bytes === @prefix_bytes and consumed_prefix.sha256 === digest(prefix)
    assert consumed_prefix.at_us >= entered.read_entered_us
    await_command(f, first, false, raw_prefix)
    # The producer's last byte and terminator are still absent here. Socket
    # pressure was proved independently, and O really completed after reading.
    eof_held = checkpoint(f, baseline, [slow], "O_completed_upstream_EOF_still_held")
    {:ok, stats_after_read} = observe(fn -> Socket.getstat(slow_exchange.socket) end)
    assert Keyword.fetch!(stats_after_read, :send_pend) === 0
    final_raw = "1\r\n" <> <<0>> <> "\r\n0\r\n\r\n"
    eof_release_us = System.monotonic_time(:microsecond)
    send_raw(f, first, final_raw, true)
    phase(:eof_released)
    await_command(f, first, true, final_raw)
    result = client_message(slow_client, :complete)
    assert result.body === body() and result.bytes === 262_145
    assert result.sha256 === "c35991ad254f48ff8b02becb9f0cc56581e86a0b477b13e5ebb0030a3b91c848"
    assert result.wire_bytes <= @wire_limit and result.trailers === []
    assert result.at_us >= eof_release_us
    join_original(slow)
    final = checkpoint(f, baseline, [], "all_originals_joined")
    sample_barrier()
    samples = stop_sampler()
    phase(:sampler_stopped)
    close_client(slow_client)
    close_client(healthy_client)
    join_native(slow_exchange)
    join_native(healthy_exchange)

    await(fn ->
      match?(%{active: 0, retained_bytes: 0, cleanup_pending: 0, cleanup_failed: nil}, service(f))
    end)

    final_service = service(f)
    assert final_service.retained_high_water <= @combined_upper
    peer_connections = assert_exact_peer_counts(f, [first, second])
    retirement_deadline = Process.get(:pressure_deadline)

    if f.group do
      :ok = Resources.release(baseline.group_release_pins)

      await(fn ->
        groups = system(f.groups)

        groups.tokens === %{} and groups.pins === %{} and groups.groups === %{} and
          groups.probes === %{}
      end)

      group_monitor = Process.monitor(f.groups)
      :ok = observe(fn -> GenServer.stop(f.groups, :normal, timeout_at(retirement_deadline)) end)
      join(f.groups, group_monitor, :normal)
      Process.put(:pressure_group_joined, true)
    end

    assert Map.new(system(f.owner).pins, fn {ref, held} -> {ref, held.public} end) ===
             baseline.transport_pins

    :ok = Resources.release(Map.values(baseline.transport_pins))
    {:ok, retirement} = observe(fn -> UpstreamTransports.retire(f.owner, retirement_deadline) end)
    :ok = observe(fn -> UpstreamTransports.await_retirement(retirement, retirement_deadline) end)

    assert {:ok, %{resources: 0, pins: 0, request_tokens: 0, helpers: 0, reserved_connections: 0}} =
             transport_status(f)

    fixture_joins = Enum.map([f.owner, f.instance], &{&1, Process.monitor(&1)})
    joined = Fixture.stop(f, budget())
    Process.put(:pressure_stopped, true)
    expected_accepts = length(peer_connections)
    if is_nil(f.group), do: assert(expected_accepts === 2)

    assert joined["accepted"] === expected_accepts and joined["forced"] === 0 and
             joined["live"] === 0

    for {actor, monitor} <- fixture_joins, do: join(actor, monitor, :normal)

    {:ok, rebound} =
      :gen_tcp.listen(f.port, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])

    :ok = :gen_tcp.close(rebound)
    :ok = :telemetry.detach(Process.get(:pressure_handler))
    Process.put(:pressure_handler, nil)
    assert_events_complete()
    assert :ets.info(Process.get(:pressure_observers), :size) === 0

    receipt = %{
      mount: f.mount,
      upstream: f.upstream,
      downstream: "native_h1",
      actual_requests: 2,
      health_requests: length(Process.get(:pressure_health_requests)),
      health_connections: Enum.map(Process.get(:pressure_health_requests), & &1["connection"]),
      accepted_upstream_connections: peer_connections,
      upstream_request_ordinals:
        Enum.map(
          Process.get(:pressure_health_requests) ++ [first, second],
          &Map.take(&1, ["connection", "request", "role"])
        ),
      downstream_connections: 2,
      upstream_connections: Enum.map([first, second], & &1["connection"]),
      request_timeout_ms: 10_000,
      native_write_timeout_ms: 2_000,
      actual_sndbuf: Keyword.fetch!(server_options, :sndbuf),
      actual_recbuf: slow_client.recbuf,
      actual_client_buffer: slow_client.buffer,
      body_bytes: result.bytes,
      body_sha256: result.sha256,
      wire_bytes: result.wire_bytes,
      send_operation: identity(operation),
      send_framed_bytes: framed_bytes,
      send_started_us: started.at_us,
      head_bytes: slow_head.head_bytes,
      head_completed_us: head_completed_us,
      head_send_operations:
        Enum.zip_with(head_started, head_outcomes, fn started, completed ->
          %{
            operation: identity(started.operation),
            bytes: started.bytes,
            started_us: started.at_us,
            completed_us: completed.at_us
          }
        end),
      release_us: entered.release_us,
      read_entered_us: entered.read_entered_us,
      actual_send_ok_us: outcome.at_us,
      prefix_consumed_us: consumed_prefix.at_us,
      healthy_complete_us: healthy_reply.at_us,
      producer_EOF_release_us: eof_release_us,
      snapshots:
        Enum.map(
          Enum.zip(
            ["before_sibling", "two_originals", "after_healthy", "immediately_before_release"],
            [pressure1, pressure_overlap, pressure2, before_release]
          ),
          fn {phase, value} -> Map.put(pressure_receipt(value), :phase, phase) end
        ),
      checkpoints: [overlap, after_healthy, eof_held, final],
      originals: Enum.map([slow, healthy], &original_receipt/1),
      samples: samples,
      persistent_retained_high_water: final_service.retained_high_water,
      telemetry_events: length(events()),
      healthy_bytes: healthy_reply.bytes,
      joined: %{
        original_guardians: 2,
        native_owners: 2,
        clients: 2,
        fixture_owners: 2,
        group_owners: if(f.group, do: 1, else: 0),
        group_normal_joins: if(f.group, do: 1, else: 0),
        observer_helpers_live: :ets.info(Process.get(:pressure_observers), :size),
        peer_forced: 0,
        peer_live: 0
      }
    }

    IO.puts("GAOXY_NATIVE_H1_PRESSURE_RECEIPT " <> JSON.encode!(receipt))
  end

  def handle_send([:gaoxy, event], measurements, metadata, %{table: table, scope: scope}) do
    if Enum.all?(scope, fn {key, value} -> metadata[key] === value end) do
      value = %{
        event: event,
        at_us: System.monotonic_time(:microsecond),
        bytes: measurements.bytes,
        operation: metadata.operation,
        outcome: Map.get(metadata, :outcome)
      }

      slot = :ets.update_counter(table, :count, {2, 1, 129, 129})
      if slot <= 128, do: :ets.insert(table, {slot, value})
    end
  end

  defp attach_telemetry(scope) do
    handler = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach_many(
        handler,
        [[:gaoxy, :send_started], [:gaoxy, :send]],
        &__MODULE__.handle_send/4,
        %{table: Process.get(:pressure_events), scope: scope}
      )

    Process.put(:pressure_handler, handler)
  end

  defp event_rows(table) do
    for {slot, event} <- :ets.tab2list(table), is_integer(slot), do: {slot, event}
  end

  defp event_count, do: :ets.lookup_element(Process.get(:pressure_events), :count, 2)

  defp events do
    assert event_count() <= 128

    values =
      Process.get(:pressure_events)
      |> event_rows()
      |> Enum.sort_by(&elem(&1, 0), :desc)
      |> Enum.map(&elem(&1, 1))

    assert event_count() <= 128
    values
  end

  defp assert_events_complete do
    table = Process.get(:pressure_events)
    count = event_count()
    assert count in 0..128
    rows = event_rows(table)
    assert length(rows) === count
    assert Enum.sort(Enum.map(rows, &elem(&1, 0))) === Enum.take(1..128, count)
    assert :ets.info(table, :size) === count + 1
  end

  defp send_event(event, operation) do
    [found] = Enum.filter(events(), &(&1.event === event and &1.operation === operation))
    found
  end

  defp await_send_success(operation) do
    await(fn -> Enum.any?(events(), &(&1.event === :send and &1.operation === operation)) end)
    result = send_event(:send, operation)
    assert result.outcome === :ok
    result
  end

  defp capture_exchange(target) do
    exchange =
      receive do
        {:pressure_exchange, %{target: ^target} = value} -> value
      after
        budget() -> flunk("missing native H1 exchange")
      end

    Process.put(
      :pressure_deadline,
      min(Process.get(:pressure_original_deadline, exchange.deadline), exchange.deadline)
    )

    Process.put(:pressure_original_deadline, Process.get(:pressure_deadline))
    assert exchange.head_bytes <= 1024 and exchange.buffer_bytes <= 65_536
    assert exchange.poll_bytes <= 65_536 and exchange.route_bytes <= 65_536
    assert exchange.protocol_bytes === 0 and exchange.trailer_bytes === 0
    assert exchange.response_trailers === []
    monitor = Process.monitor(exchange.owner)
    Map.put(exchange, :owner_monitor, monitor)
  end

  defp request(f, target) do
    value = Fixture.event(f, %{"event" => "request", "target" => target}, budget())
    assert value["method"] === "GET" and value["role"] === "application"
    seen = Process.get(:pressure_requests, [])
    Process.put(:pressure_requests, [value | seen])

    upload =
      Fixture.event(
        f,
        %{
          "event" => "upload_end",
          "connection" => value["connection"],
          "request" => value["request"]
        },
        budget()
      )

    assert upload["body_bytes"] === 0 and upload["trailers"] === []
    value
  end

  defp send_raw(f, seen, raw, ended) do
    :ok =
      Fixture.dispatch_command(
        f,
        Map.merge(Map.take(seen, ["connection", "request"]), %{
          "action" => "send",
          "body64" => Base.encode64(raw),
          "ended" => ended
        })
      )
  end

  defp await_command(f, seen, ended, raw) do
    value =
      Fixture.event(
        f,
        Map.merge(Map.take(seen, ["connection", "request"]), %{
          "event" => "command",
          "action" => "send",
          "ended" => ended
        }),
        budget()
      )

    assert value["body_bytes"] === byte_size(raw) and value["body_sha256"] === digest(raw)
  end

  defp bind_original(f, exchange) do
    await(fn ->
      Enum.any?(system(f.owner).tokens, fn {_, hold} ->
        system(hold.guardian).owner === exchange.owner
      end)
    end)

    transport = system(f.owner)

    [{token, hold}] =
      Enum.filter(transport.tokens, fn {_, held} ->
        system(held.guardian).owner === exchange.owner
      end)

    state = system(hold.guardian)
    assert state.client === HTTPFetchClient
    assert state.owner === exchange.owner and state.transport_selection === {f.handle, token}
    assert state.client.completion(state.original_request) === hold.completion

    assert state.config.limits === %{
             max_chunk_bytes: 65_536,
             opening_timeout: 5_000,
             idle_timeout: 60_000,
             write_timeout: 5_000,
             max_lifetime: 30_000
           }

    assert state.request_options.query === nil
    fields = state.request_options.headers
    fields_bytes = :erlang.external_size({fields, ""})
    url_bytes = byte_size(f.origin <> exchange.target)
    assert fields_bytes <= 65_536 and url_bytes <= 65_536
    reserve = HTTPFetchClient.reservation_bytes(fields, url_bytes, 65_536)
    assert reserve === 7_749_672 + 2 * fields_bytes + 2 * url_bytes
    assert reserve <= @original_upper
    gate = system(exchange.gate)
    cleanup = Map.fetch!(gate.cleanups, state.token)
    assert cleanup.lease === exchange.lease and cleanup.bytes === reserve

    pins =
      Map.new(
        for {ref, pin} <- transport.pins,
            pin.public.kind === :request and pin.public.holder in [exchange.owner, hold.guardian],
            do: {ref, pin.public}
      )

    assert Enum.any?(pins, fn {_, pin} -> pin.holder === exchange.owner end)
    assert [_ | _] = state.transport_pins

    assert Enum.all?(state.transport_pins, fn pin ->
             pins[pin.ref] === pin and pin.holder === hold.guardian
           end)

    assert Enum.all?(pins, fn {_, pin} -> pin.handles === [f.handle] end)

    original = %{
      exchange: exchange,
      guardian: hold.guardian,
      guardian_monitor: Process.monitor(hold.guardian),
      transport_token: token,
      completion: hold.completion,
      original_request: state.original_request,
      session_token: state.token,
      pins: pins,
      transport_pins: state.transport_pins,
      reserve: reserve,
      fields_bytes: fields_bytes,
      url_bytes: url_bytes
    }

    original =
      if f.group do
        groups = system(f.groups)

        [{group_token, group_hold}] =
          Enum.filter(groups.tokens, fn {_, held} -> held.guardian === hold.guardian end)

        assert group_hold.completion === hold.completion
        assert state.selection === {f.group, group_token}

        group_pins =
          Map.new(
            for {ref, pin} <- groups.pins,
                pin.kind === :request and pin.holder in [exchange.owner, hold.guardian],
                do: {ref, pin}
          )

        assert map_size(group_pins) > 0
        assert Enum.all?(group_pins, fn {_, pin} -> pin.keys === [group_hold.key] end)
        Map.merge(original, %{group_token: group_token, group_pins: group_pins})
      else
        assert state.selection === nil
        original
      end

    Process.put(:pressure_originals, [original | Process.get(:pressure_originals)])
    original
  end

  defp checkpoint(f, baseline, originals, name) do
    tokens = MapSet.new(originals, & &1.transport_token)
    pins = Enum.reduce(originals, baseline.transport_pins, &Map.merge(&2, &1.pins))
    group_tokens = MapSet.new(originals, &Map.get(&1, :group_token))

    group_pins =
      Enum.reduce(originals, baseline.group_pins, &Map.merge(&2, Map.get(&1, :group_pins, %{})))

    count = length(originals)

    await(fn ->
      transport = system(f.owner)

      MapSet.new(Map.keys(transport.tokens)) === tokens and
        Map.new(transport.pins, fn {ref, held} -> {ref, held.public} end) === pins and
        service(f).cleanup_pending === count and
        (is_nil(f.group) or
           (MapSet.new(Map.keys(system(f.groups).tokens)) === group_tokens and
              system(f.groups).pins === group_pins))
    end)

    assert {:ok,
            %{request_tokens: ^count, resources: 1, reserved_connections: 2, helpers: 0} =
              transport} = transport_status(f)

    assert transport.pins <= 32 and transport.owned_serialized_payload_bytes <= 4_194_304
    if f.group, do: assert(%{inflight: ^count, probes: 0, probe_bytes: 0} = group_status(f))
    gate_pid = Process.get(:pressure_gate) || hd(originals).exchange.gate
    Process.put(:pressure_gate, gate_pid)
    gate = system(gate_pid)
    expected = Map.new(originals, &{&1.session_token, &1.reserve})
    assert Map.new(gate.cleanups, fn {token, cleanup} -> {token, cleanup.bytes} end) === expected
    assert gate.bytes <= @combined_upper and gate.high_water <= @combined_upper
    assert gate.limits.max_bytes === @capacity and gate.limits.max_active === 64

    for original <- originals do
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(original.completion, 0)
      state = system(original.guardian)
      assert state.original_request === original.original_request
      assert state.transport_selection === {f.handle, original.transport_token}
      assert state.transport_pins === original.transport_pins
      assert state.token === original.session_token and state.owner === original.exchange.owner

      if f.group,
        do: assert(state.selection === {f.group, original.group_token}),
        else: assert(state.selection === nil)
    end

    status = service(f)
    assert status.cleanup_failed === nil
    assert status.retained_bytes === gate.bytes

    %{
      name: name,
      at_us: System.monotonic_time(:microsecond),
      requests: count,
      retained_bytes: status.retained_bytes,
      cleanup_bytes: Enum.sum(Map.values(expected)),
      transport_pins: transport.pins,
      group_pins: map_size(group_pins),
      group_inflight: if(f.group, do: count, else: 0),
      original_remaining_ms: max(0, Process.get(:pressure_deadline) - now())
    }
  end

  defp join_original(original) do
    await(fn -> HTTP.RequestCompletion.await(original.completion, 0) === :ok end)

    receive do
      {:DOWN, ref, :process, actor, reason}
      when ref === original.guardian_monitor and actor === original.guardian ->
        assert reason === :normal
    after
      budget() -> flunk("original guardian did not join normally")
    end
  end

  defp pressure(f, original, {operation, framed_bytes}) do
    snapshot = pressure_snapshot(f, original.exchange)
    assert snapshot.operation === operation and snapshot.bytes === framed_bytes
    assert framed_bytes in 1..16_384
    assert snapshot.send_pend > 0 and snapshot.send_pend <= @wire_limit
    assert snapshot.native_tcp_send_wait
    refute Enum.any?(events(), &(&1.event === :send and &1.operation === operation))
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(original.completion, 0)
    snapshot
  end

  defp await_pressure(f, original) do
    await(fn ->
      snapshot = pressure_snapshot(f, original.exchange)

      snapshot.bytes in 1..16_384 and snapshot.operation !== nil and
        snapshot.send_pend > 0 and snapshot.native_tcp_send_wait
    end)

    snapshot = Process.get(:pressure_last_snapshot)
    pressure(f, original, {snapshot.operation, snapshot.bytes})
  end

  defp pressure_snapshot(_f, exchange) do
    gate = system(exchange.gate)
    %{pid: owner, send: pending, bytes: retained} = Map.fetch!(gate.leases, exchange.lease)
    assert owner === exchange.owner and retained <= @native_upper
    {:ok, stats} = observe(fn -> Socket.getstat(exchange.socket) end)
    send_pend = Keyword.fetch!(stats, :send_pend)
    assert send_pend >= 0 and send_pend <= @wire_limit

    {:current_stacktrace, stack} =
      observe(fn -> Process.info(exchange.owner, :current_stacktrace) end)

    frames =
      Enum.map(stack, fn {module, function, arity, _location} when is_integer(arity) ->
        {module, function, arity}
      end)

    assert length(frames) <= 64

    send_wait =
      Enum.any?(frames, fn
        {:prim_inet, :send, _} -> true
        {:prim_inet, :send0, _} -> true
        {:gen_tcp_socket, :send, _} -> true
        {:socket, :send, _} -> true
        _ -> false
      end) and
        Enum.any?(frames, fn
          {Gaoxy.HTTP.Exchange, :send_window, _} -> true
          {Gaoxy.HTTP.Exchange, :send_chunks, _} -> true
          _ -> false
        end)

    snapshot = %{
      operation: if(pending, do: pending.operation),
      bytes: if(pending, do: pending.bytes, else: 0),
      send_pend: send_pend,
      native_tcp_send_wait: send_wait,
      stack: frames,
      owner: exchange.owner,
      lease: exchange.lease,
      socket: exchange.socket,
      retained_bytes: retained,
      at_us: System.monotonic_time(:microsecond)
    }

    Process.put(:pressure_last_snapshot, snapshot)
    snapshot
  end

  defp pressure_receipt(value) do
    %{
      operation: identity(value.operation),
      bytes: value.bytes,
      send_pend: value.send_pend,
      owner: identity(value.owner),
      native_lease: identity(value.lease),
      native_socket: identity(value.socket),
      stack: Enum.map(value.stack, fn {m, f, a} -> [Atom.to_string(m), Atom.to_string(f), a] end),
      retained_bytes: value.retained_bytes,
      at_us: value.at_us
    }
  end

  defp original_receipt(value) do
    %{
      owner: identity(value.exchange.owner),
      guardian: identity(value.guardian),
      completion: identity(value.completion),
      transport_token: identity(value.transport_token),
      native_lease: identity(value.exchange.lease),
      session_token: identity(value.session_token),
      native_socket: identity(value.exchange.socket),
      reserve: value.reserve,
      fields_ETF_bytes: value.fields_bytes,
      url_bytes: value.url_bytes,
      request_pins: map_size(value.pins),
      group_token: if(Map.has_key?(value, :group_token), do: identity(value.group_token)),
      group_request_pins: map_size(Map.get(value, :group_pins, %{}))
    }
  end

  defp assert_transport_limits(limits) do
    assert limits === %{
             max_resources: 2,
             max_pins: 32,
             max_request_tokens: 64,
             max_owned_payload_bytes: 4_194_304
           }
  end

  defp assert_exact_peer_counts(f, requests) do
    assert Enum.reverse(Process.get(:pressure_requests)) === requests
    health = Process.get(:pressure_health_requests)
    assert length(health) === if(f.group, do: 1, else: 0)
    application_connections = Enum.map(requests, & &1["connection"])
    assert length(Enum.uniq(application_connections)) === 2
    connections = Enum.uniq(application_connections ++ Enum.map(health, & &1["connection"]))

    accepted =
      Enum.map(connections, fn connection ->
        event = Fixture.event(f, %{"event" => "accepted", "connection" => connection}, budget())
        assert event["wire"] === if(f.upstream == "tls", do: "tls-h1", else: "tcp-h1")
        event["connection"]
      end)

    assert MapSet.new(accepted) === MapSet.new(connections)
    queued = Process.get({Fixture, f.key, :events}, [])
    refute Enum.any?(queued, &(&1["event"] in ["request", "accepted"]))

    receive do
      {:matrix_peer, peer, %{"event" => event}}
      when peer === f.peer and event in ["request", "accepted"] ->
        flunk("unexpected extra upstream request or accept")
    after
      0 -> :ok
    end

    if is_nil(f.group) do
      assert Enum.all?(requests, &(&1["request"] === 1))
    else
      for {_, chronology} <- Enum.group_by(health ++ requests, & &1["connection"]) do
        assert Enum.map(chronology, & &1["request"]) === Enum.to_list(1..length(chronology))
      end
    end

    connections
  end

  defp start_sampler(f, exchange) do
    caller = self()
    deadline = Process.get(:pressure_deadline)
    observers = Process.get(:pressure_observers)
    event_table = Process.get(:pressure_events)
    clients = Enum.map(Process.get(:pressure_clients), & &1.pid)

    {pid, monitor} =
      spawn_monitor(fn ->
        Process.put(:pressure_controller, caller)
        Process.put(:pressure_deadline, deadline)
        Process.put(:pressure_observers, observers)
        Process.put(:pressure_events, event_table)
        Process.put(:pressure_sample_clients, clients)
        sample_loop(caller, Process.monitor(caller), f, exchange, %{turns: 0, maxima: %{}})
      end)

    Process.put(:pressure_sampler, {pid, monitor})
  end

  defp sample_loop(caller, caller_monitor, f, exchange, totals) do
    receive do
      {:stop_sampler, ^caller} ->
        send(caller, {:pressure_samples, self(), totals})

      {:DOWN, ^caller_monitor, :process, ^caller, _} ->
        :ok

      {:sample_deadline, value} ->
        if value,
          do: Process.put(:pressure_send_deadline, value),
          else: Process.delete(:pressure_send_deadline)

        sample_loop(caller, caller_monitor, f, exchange, totals)

      {:sample_client, pid} ->
        Process.put(:pressure_sample_clients, [pid | Process.get(:pressure_sample_clients)])
        sample_loop(caller, caller_monitor, f, exchange, totals)

      {:sample_now, ^caller, tag} ->
        sample_turn(caller, caller_monitor, f, exchange, totals, tag)
    after
      5 -> sample_turn(caller, caller_monitor, f, exchange, totals, nil)
    end
  end

  defp sample_turn(caller, caller_monitor, f, exchange, totals, tag) do
    try do
      assert totals.turns < 4096
      assert event_count() <= 128
      gate = system(exchange.gate)
      status = service(f)
      assert {:ok, transport} = transport_status(f)
      assert_transport_limits(transport.limits)
      assert transport.resources <= 1 and transport.reserved_connections <= 2
      assert transport.pins <= 32 and transport.request_tokens <= 2 and transport.helpers <= 2
      assert transport.owned_serialized_payload_bytes <= 4_194_304
      assert gate.limits.max_bytes === @capacity and gate.limits.max_active === 64
      assert gate.bytes <= @combined_upper and gate.high_water <= @combined_upper

      assert status.retained_bytes <= @combined_upper and
               status.retained_high_water <= @combined_upper

      assert status.cleanup_pending <= 2 and status.cleanup_failed === nil
      assert map_size(gate.leases) <= 2 and map_size(gate.cleanups) <= 2

      assert Enum.all?(gate.leases, fn {_, lease} ->
               lease.bytes <= @native_upper and
                 (lease.send === nil or lease.send.bytes <= 16_384)
             end)

      assert Enum.all?(gate.cleanups, fn {_, hold} -> hold.bytes <= @original_upper end)
      socket_result = observe(fn -> Socket.getstat(exchange.socket) end)

      if not match?({:ok, _}, socket_result) do
        lease = Map.get(gate.leases, exchange.lease)

        send(
          caller,
          {:pressure_socket_failure,
           %{
             at_us: System.monotonic_time(:microsecond),
             turn: totals.turns,
             result: diagnostic_reason(socket_result),
             owner: identity(exchange.owner),
             lease: identity(exchange.lease),
             socket: identity(exchange.socket),
             operation: if(lease && lease.send, do: identity(lease.send.operation)),
             bytes: if(lease && lease.send, do: lease.send.bytes, else: 0),
             retained_bytes: status.retained_bytes,
             cleanup_pending: status.cleanup_pending
           }}
        )
      end

      {:ok, socket_stats} = socket_result
      send_pend = Keyword.fetch!(socket_stats, :send_pend)
      assert send_pend >= 0 and send_pend <= @wire_limit

      if f.group do
        group = group_status(f)
        assert group.inflight <= 2 and group.probes === 0 and group.probe_bytes === 0
      end

      transport_state = system(f.owner)
      guardians = Enum.map(transport_state.tokens, fn {_, hold} -> hold.guardian end)
      {:links, links} = observe(fn -> Process.info(f.peer, :links) end)
      peer_workers = Enum.filter(links, &is_pid/1)
      clients = Process.get(:pressure_sample_clients)

      actors =
        Enum.uniq(
          [self(), caller, f.instance, exchange.gate, f.owner, f.peer | guardians] ++
            peer_workers ++
            clients ++
            Enum.map(gate.leases, fn {_, lease} -> lease.pid end) ++
            if(f.group, do: [f.groups], else: [])
        )

      boxes =
        Enum.map(actors, fn actor ->
          case observe(fn -> Process.info(actor, :message_queue_len) end) do
            {:message_queue_len, count} ->
              assert count <= 64,
                     (if(count > 64) do
                        role =
                          cond do
                            actor === caller -> "controller"
                            actor === self() -> "sampler"
                            actor === exchange.owner -> "slow_native_owner"
                            actor === exchange.gate -> "admission_gate"
                            actor === f.instance -> "instance"
                            actor === f.owner -> "transport_owner"
                            actor === f.peer -> "peer"
                            actor === f.groups -> "group_owner"
                            actor in guardians -> "guardian"
                            actor in peer_workers -> "peer_worker"
                            actor in clients -> "client"
                            true -> "other_owned_actor"
                          end

                        "native_h1_pressure_mailbox actor_sha256=#{identity(actor)} role=#{role} count=#{count} turn=#{totals.turns}"
                      else
                        ""
                      end)

              count

            nil ->
              assert actor in guardians or actor in peer_workers
              0
          end
        end)

      value = %{
        retained_bytes: status.retained_bytes,
        cleanup_pending: status.cleanup_pending,
        request_tokens: transport.request_tokens,
        mailbox_messages: Enum.reduce(boxes, 0, &max/2),
        transport_payload_bytes: transport.owned_serialized_payload_bytes,
        send_pend: send_pend,
        native_pending_bytes:
          Enum.reduce(gate.leases, 0, fn {_, lease}, acc ->
            max(acc, if(lease.send, do: lease.send.bytes, else: 0))
          end)
      }

      next = %{
        turns: totals.turns + 1,
        maxima: Map.merge(totals.maxima, value, fn _, old, new -> max(old, new) end)
      }

      if tag, do: send(caller, {:pressure_sampled, self(), tag})
      sample_loop(caller, caller_monitor, f, exchange, next)
    catch
      kind, reason ->
        send(caller, {:pressure_failure_at, self(), System.monotonic_time(:microsecond)})
        send(caller, {:pressure_sampler_failed, kind, reason, __STACKTRACE__})
    end
  end

  defp send_sampler_deadline do
    {pid, _} = Process.get(:pressure_sampler)
    send(pid, {:sample_deadline, Process.get(:pressure_send_deadline)})
  end

  defp sample_barrier do
    {pid, _} = Process.get(:pressure_sampler)
    tag = make_ref()
    send(pid, {:sample_now, self(), tag})

    receive do
      {:pressure_sampled, ^pid, ^tag} -> :ok
      {:pressure_sampler_failed, kind, reason, stack} -> :erlang.raise(kind, reason, stack)
    after
      budget() -> flunk("pressure sampler did not observe checkpoint")
    end
  end

  defp stop_sampler do
    {pid, monitor} = Process.get(:pressure_sampler)
    send(pid, {:stop_sampler, self()})

    result =
      receive do
        {:pressure_samples, ^pid, totals} ->
          assert totals.turns > 0
          totals

        {:pressure_sampler_failed, kind, reason, stack} ->
          :erlang.raise(kind, reason, stack)
      after
        budget() -> flunk("pressure sampler failed to stop")
      end

    join(pid, monitor, :normal)
    Process.put(:pressure_sampler, nil)
    result
  end

  defp start_client(f, target, mode) do
    caller = self()
    deadline = phase_deadline()
    observers = Process.get(:pressure_observers)

    {pid, monitor} =
      spawn_monitor(fn ->
        Process.put(:pressure_controller, caller)
        Process.put(:pressure_observers, observers)
        client(caller, f.port, target, mode, deadline)
      end)

    Process.put(:pressure_actors, [{pid, monitor} | Process.get(:pressure_actors)])

    value =
      receive do
        {:pressure_client, ^pid, :ready, ready} -> ready
        {:pressure_client_failed, ^pid, kind, reason, stack} -> :erlang.raise(kind, reason, stack)
      after
        budget() -> flunk("raw client did not connect")
      end

    assert value.recbuf in 1..16_384 and value.buffer in 1..16_384
    client = Map.merge(value, %{pid: pid, monitor: monitor, mode: mode})
    Process.put(:pressure_clients, [client | Process.get(:pressure_clients)])

    case Process.get(:pressure_sampler) do
      {sampler, _} -> send(sampler, {:sample_client, pid})
      nil -> :ok
    end

    client
  end

  defp client(caller, port, target, mode, opening_deadline) do
    try do
      {:ok, socket} =
        :gen_tcp.connect(
          {127, 0, 0, 1},
          port,
          [:binary, active: false, recbuf: 1024, buffer: 1024],
          timeout_at(opening_deadline)
        )

      Process.put(:pressure_client_socket, socket)

      {:ok, options} =
        observe_at(fn -> :inet.getopts(socket, [:recbuf, :buffer]) end, opening_deadline)

      :ok = :gen_tcp.send(socket, "GET #{target} HTTP/1.1\r\nHost: client.test\r\n\r\n")

      send(
        caller,
        {:pressure_client, self(), :ready,
         %{
           socket: socket,
           recbuf: Keyword.fetch!(options, :recbuf),
           buffer: Keyword.fetch!(options, :buffer)
         }}
      )

      deadline =
        receive do
          {:read_head, deadline} -> deadline
        after
          timeout_at(opening_deadline) -> raise "client head command deadline"
        end

      {head, wire} = read_line_until(socket, "\r\n\r\n", 8192, deadline, 0, "")
      [status | fields] = String.split(String.trim_trailing(head, "\r\n\r\n"), "\r\n")
      "HTTP/1.1 200 OK" = status

      fields =
        Map.new(fields, fn line ->
          [key, value] = String.split(line, ":", parts: 2)
          {String.downcase(key), String.trim(value)}
        end)

      framing =
        case fields do
          %{"transfer-encoding" => "chunked"} -> :chunked
          %{"content-length" => count} -> {:length, String.to_integer(count)}
        end

      send(
        caller,
        {:pressure_client, self(), :head,
         %{status: 200, framing: framing, head_bytes: byte_size(head)}}
      )

      {body, wire, trailers} =
        if mode === :slow do
          :chunked = framing

          receive do
            {:release, tag} ->
              release_us = System.monotonic_time(:microsecond)
              read_entered_us = System.monotonic_time(:microsecond)

              send(
                caller,
                {:pressure_client, self(), {:entered, tag},
                 %{release_us: release_us, read_entered_us: read_entered_us}}
              )
          after
            timeout_at(deadline) -> raise "raw reader release deadline"
          end

          read_chunks(socket, caller, deadline, wire, "", false)
        else
          {:length, 1} = framing
          {bytes, wire} = read_exact(socket, 1, deadline, wire)
          {bytes, wire, []}
        end

      send(
        caller,
        {:pressure_client, self(), :complete,
         %{
           body: body,
           bytes: byte_size(body),
           sha256: digest(body),
           wire_bytes: wire,
           trailers: trailers,
           at_us: System.monotonic_time(:microsecond)
         }}
      )

      receive do
        :close -> :ok
      after
        timeout_at(deadline) -> raise "raw client close deadline"
      end

      :ok = :gen_tcp.close(socket)
      send(caller, {:pressure_client, self(), :closed, %{normal: true}})
    catch
      kind, reason ->
        send(caller, {:pressure_failure_at, self(), System.monotonic_time(:microsecond)})
        send(caller, {:pressure_client_failed, self(), kind, reason, __STACKTRACE__})
    after
      if socket = Process.get(:pressure_client_socket), do: :gen_tcp.close(socket)
    end
  end

  defp read_chunks(socket, caller, deadline, wire, body, prefix_sent) do
    {line, wire} = read_line_until(socket, "\r\n", 1024, deadline, wire, "")
    size = line |> String.trim() |> String.to_integer(16)
    assert size in 0..65_536

    if size === 0 do
      {ending, wire} = read_exact(socket, 2, deadline, wire)
      assert ending === "\r\n" and byte_size(body) === 262_145
      {body, wire, []}
    else
      assert byte_size(body) + size <= 262_145
      {chunk, wire} = read_exact(socket, size, deadline, wire)
      {ending, wire} = read_exact(socket, 2, deadline, wire)
      assert ending === "\r\n"
      next = body <> chunk

      sent =
        if byte_size(next) === @prefix_bytes and not prefix_sent do
          send(
            caller,
            {:pressure_client, self(), :prefix,
             %{
               bytes: byte_size(next),
               sha256: digest(next),
               at_us: System.monotonic_time(:microsecond)
             }}
          )

          true
        else
          prefix_sent
        end

      read_chunks(socket, caller, deadline, wire, next, sent)
    end
  end

  defp read_exact(socket, bytes, deadline, wire) do
    assert bytes > 0 and wire + bytes <= @wire_limit
    {:ok, data} = :gen_tcp.recv(socket, bytes, timeout_at(deadline))
    assert byte_size(data) === bytes
    {data, wire + bytes}
  end

  defp read_line_until(socket, ending, maximum, deadline, wire, acc) do
    if String.ends_with?(acc, ending) do
      {acc, wire}
    else
      assert byte_size(acc) < maximum
      {byte, wire} = read_exact(socket, 1, deadline, wire)
      read_line_until(socket, ending, maximum, deadline, wire, acc <> byte)
    end
  end

  defp client_message(client, event) do
    receive do
      {:pressure_client, pid, ^event, value} when pid === client.pid -> value
      {:pressure_client_failed, _pid, kind, reason, stack} -> :erlang.raise(kind, reason, stack)
      {:pressure_sampler_failed, kind, reason, stack} -> :erlang.raise(kind, reason, stack)
    after
      budget() -> flunk("missing finite raw-client event #{inspect(event)}")
    end
  end

  defp close_client(client) do
    send(client.pid, :close)
    assert %{normal: true} = client_message(client, :closed)
    join(client.pid, client.monitor, :normal)
  end

  defp join_native(exchange) do
    join(exchange.owner, exchange.owner_monitor, {:shutdown, :peer_closed})
  end

  defp join(actor, monitor, expected) do
    receive do
      {:DOWN, ^monitor, :process, ^actor, reason} -> assert reason === expected
    after
      budget() -> flunk("owned actor did not join within original deadline")
    end
  end

  defp system(actor) do
    expires = phase_deadline()
    observe_at(fn -> :sys.get_state(actor, timeout_at(expires)) end, expires)
  end

  defp group_status(f), do: observe(fn -> UpstreamGroups.status(f.group) end)
  defp service(f), do: observe(fn -> Gaoxy.status(f.instance, :http) end)
  defp transport_status(f), do: observe(fn -> UpstreamTransports.status(f.owner) end)
  defp observe(function), do: observe_at(function, phase_deadline())

  # Result receipt alone is insufficient: the actual normal DOWN must also fit
  # this phase's original deadline. Late/forced cleanup always remains FAIL.
  defp observe_at(function, expires) do
    assert now() < expires, "observation cannot start after its original phase deadline"
    caller = self()
    table = Process.get(:pressure_observers)
    tag = make_ref()

    {actor, monitor} =
      spawn_monitor(fn ->
        receive do
          :observe ->
            try do
              result =
                try do
                  {:returned, function.()}
                catch
                  kind, reason -> {:raised, kind, reason, __STACKTRACE__}
                end

              send(caller, {tag, result})
            after
              :ets.delete(table, self())
            end
        after
          @barrier -> :ok
        end
      end)

    true = :ets.insert(table, {actor})
    send(actor, :observe)
    result = await_observer(actor, monitor, tag, expires, nil)

    case result do
      {:returned, value} -> value
      {:raised, kind, reason, stack} -> :erlang.raise(kind, reason, stack)
    end
  end

  defp await_observer(actor, monitor, tag, expires, result) do
    receive do
      {^tag, value} ->
        await_observer(actor, monitor, tag, expires, value)

      {:DOWN, ^monitor, :process, ^actor, :normal} when result != nil ->
        assert now() < expires, "observer joined after original phase deadline"
        result

      {:DOWN, ^monitor, :process, ^actor, reason} ->
        flunk("observer failed: #{inspect(reason)}")
    after
      max(0, expires - now()) ->
        Process.exit(actor, :kill)

        joined =
          receive do
            {:DOWN, ^monitor, :process, ^actor, reason} -> {:joined, reason}
          after
            @barrier -> :unjoined
          end

        receive do
          {^tag, _late} -> :ok
        after
          0 -> :ok
        end

        flunk("observation deadline exceeded; cleanup=#{inspect(joined)}")
    end
  end

  defp await(predicate) do
    if predicate.() do
      :ok
    else
      receive do
        {:pressure_sampler_failed, kind, reason, stack} -> :erlang.raise(kind, reason, stack)
        {:pressure_client_failed, _pid, kind, reason, stack} -> :erlang.raise(kind, reason, stack)
      after
        min(5, budget()) -> :ok
      end

      await(predicate)
    end
  end

  defp phase_deadline do
    min(
      now() + @barrier,
      min(
        Process.get(:pressure_deadline),
        Process.get(:pressure_send_deadline, Process.get(:pressure_deadline))
      )
    )
  end

  defp budget, do: timeout_at(phase_deadline())

  defp timeout_at(deadline) do
    remaining = deadline - now()
    assert remaining > 0, "original request/send deadline expired"
    min(@barrier, remaining)
  end

  defp phase(name) do
    Process.put(:pressure_phases, [
      %{phase: Atom.to_string(name), at_us: System.monotonic_time(:microsecond)}
      | Process.get(:pressure_phases)
    ])
  end

  # Failure-only diagnostics must never replace the original exception or cleanup.
  defp failure_chronology(kind, reason, stack) do
    try do
      native = Enum.map(Process.get(:pressure_originals), & &1.exchange.owner)
      clients = Enum.map(Process.get(:pressure_actors), &elem(&1, 0))

      sampler =
        case Process.get(:pressure_sampler) do
          nil -> []
          {pid, _} -> [pid]
        end

      owned = Map.new(Enum.uniq(native ++ clients ++ sampler), &{&1, true})
      {packets, packet_limit_reached} = failure_packets(owned, 32, [])

      stored =
        Enum.map(event_rows(Process.get(:pressure_events)), fn {_, event} ->
          diagnostic_send(event)
        end)

      telemetry_count = event_count()

      events =
        Enum.sort_by(stored ++ Enum.reverse(packets), &Map.get(&1, :at_us, &1[:observed_at_us]))

      phases = Process.get(:pressure_phases)
      snapshot = Process.get(:pressure_last_snapshot)

      record = %{
        at_us: System.monotonic_time(:microsecond),
        kind: Atom.to_string(kind),
        reason: diagnostic_reason(reason),
        stack: diagnostic_stack(stack),
        phases: Enum.reverse(Enum.take(phases, 16)),
        phases_clipped: length(phases) > 16,
        last_pressure_snapshot: if(snapshot, do: pressure_receipt(snapshot)),
        events: events |> Enum.reverse() |> Enum.take(64) |> Enum.reverse(),
        events_clipped: length(events) > 64,
        queued_packet_limit_reached: packet_limit_reached,
        telemetry_count: telemetry_count,
        telemetry_overflow: telemetry_count > 128,
        owned_actor_ids: Enum.map(Enum.take(Enum.uniq(native ++ clients), 4), &identity/1),
        actors_clipped: length(Enum.uniq(native ++ clients)) > 4
      }

      IO.puts("GAOXY_NATIVE_H1_PRESSURE_FAILURE_DIAGNOSTIC " <> JSON.encode!(record))
    catch
      diagnostic_kind, _diagnostic_reason ->
        # Even a diagnostic/IO failure cannot swallow the probe's caught failure.
        try do
          IO.puts(
            "GAOXY_NATIVE_H1_PRESSURE_FAILURE_DIAGNOSTIC " <>
              JSON.encode!(%{diagnostic_failed: Atom.to_string(diagnostic_kind)})
          )
        catch
          _, _ -> :ok
        end
    end
  end

  defp failure_packets(_owned, 0, acc), do: {acc, true}

  defp failure_packets(owned, remaining, acc) do
    receive do
      {:pressure_socket_failure, value} ->
        failure_packets(owned, remaining - 1, [Map.put(value, :event, "socket_failure") | acc])

      {:pressure_failure_at, pid, at_us} when is_map_key(owned, pid) ->
        failure_packets(owned, remaining - 1, [
          %{event: "failure_generated", actor: identity(pid), at_us: at_us} | acc
        ])

      {:pressure_client_failed, pid, kind, reason, stack} when is_map_key(owned, pid) ->
        failure_packets(owned, remaining - 1, [
          %{
            event: "client_failure",
            actor: identity(pid),
            kind: Atom.to_string(kind),
            observed_at_us: System.monotonic_time(:microsecond),
            reason: diagnostic_reason(reason),
            stack: diagnostic_stack(stack)
          }
          | acc
        ])

      {:DOWN, _ref, :process, pid, reason} when is_map_key(owned, pid) ->
        failure_packets(owned, remaining - 1, [
          %{
            event: "down",
            actor: identity(pid),
            reason: diagnostic_reason(reason),
            observed_at_us: System.monotonic_time(:microsecond)
          }
          | acc
        ])
    after
      0 -> {acc, false}
    end
  end

  defp diagnostic_send(event) do
    %{
      event: Atom.to_string(event.event),
      at_us: event.at_us,
      operation: identity(event.operation),
      bytes: event.bytes,
      outcome: diagnostic_reason(event.outcome)
    }
  end

  defp diagnostic_stack(stack) do
    frames = Enum.take(stack, 17)

    %{
      clipped: length(frames) > 16,
      frames:
        Enum.map(Enum.take(frames, 16), fn
          {module, function, arity, _} ->
            [
              Atom.to_string(module),
              Atom.to_string(function),
              if(is_integer(arity), do: arity, else: "arguments_redacted")
            ]
        end)
    }
  end

  defp diagnostic_reason(value, depth \\ 0)
  defp diagnostic_reason(nil, _), do: nil
  defp diagnostic_reason(value, _) when is_atom(value), do: Atom.to_string(value)
  defp diagnostic_reason(value, _) when is_number(value), do: value
  defp diagnostic_reason(value, _) when is_binary(value), do: %{binary_bytes: byte_size(value)}

  defp diagnostic_reason(value, depth) when is_tuple(value) and depth < 3 do
    %{
      tuple:
        value |> Tuple.to_list() |> Enum.take(8) |> Enum.map(&diagnostic_reason(&1, depth + 1)),
      clipped: tuple_size(value) > 8
    }
  end

  defp diagnostic_reason(%{__struct__: module}, _),
    do: %{exception_module: Atom.to_string(module)}

  defp diagnostic_reason(_, _), do: "redacted"

  defp failure_cleanup(f) do
    # This separate finite budget bounds failure cleanup; it cannot qualify an
    # expired request, send, observer, client or sampler as successful.
    expires = now() + @barrier

    for client <- Process.get(:pressure_clients, []) do
      send(client.pid, :close)
      :gen_tcp.close(client.socket)
    end

    case Process.get(:pressure_sampler) do
      {sampler, _} -> send(sampler, {:stop_sampler, self()})
      nil -> :ok
    end

    observers = Enum.map(:ets.tab2list(Process.get(:pressure_observers)), &elem(&1, 0))

    actors =
      Enum.uniq(
        Enum.map(Process.get(:pressure_actors, []), &elem(&1, 0)) ++
          observers ++
          case Process.get(:pressure_sampler) do
            nil -> []
            {pid, _} -> [pid]
          end
      )

    graceful = min(expires, now() + 1000)

    failures =
      for actor <- actors, Process.alive?(actor), reduce: [] do
        acc ->
          monitor = Process.monitor(actor)

          receive do
            {:DOWN, ^monitor, :process, ^actor, :normal} ->
              acc

            {:DOWN, ^monitor, :process, ^actor, reason} ->
              [{:abnormal_cleanup, inspect(reason)} | acc]
          after
            max(0, graceful - now()) ->
              Process.exit(actor, :kill)

              receive do
                {:DOWN, ^monitor, :process, ^actor, _} -> :ok
              after
                max(0, expires - now()) -> :ok
              end

              [:forced_owned_actor_cleanup | acc]
          end
      end

    failures =
      if not is_nil(f.group) and not Process.get(:pressure_group_joined) do
        group = f.groups
        monitor = Process.monitor(group)

        try do
          :ok =
            observe_at(
              fn ->
                GenServer.stop(group, :normal, max(1, expires - now()))
              end,
              expires
            )

          receive do
            {:DOWN, ^monitor, :process, ^group, :normal} ->
              :ok

            {:DOWN, ^monitor, :process, ^group, reason} ->
              throw({:abnormal_group_cleanup, reason})
          after
            max(0, expires - now()) -> raise "group owner cleanup did not join"
          end

          assert now() < expires, "group owner cleanup joined after failure cleanup deadline"
          Process.put(:pressure_group_joined, true)
          failures
        catch
          kind, reason ->
            [{:group_cleanup, kind, inspect(reason, limit: 8, printable_limit: 160)} | failures]
        after
          Process.demonitor(monitor, [:flush])
        end
      else
        failures
      end

    if Process.get(:pressure_stopped) do
      failures
    else
      try do
        Fixture.stop(f, max(1, expires - now()))
        failures
      catch
        kind, reason -> [{:fixture_cleanup, kind, inspect(reason)} | failures]
      end
    end
  end

  defp now, do: System.monotonic_time(:millisecond)
  defp body, do: :binary.copy(:erlang.list_to_binary(Enum.to_list(0..255)), 1024) <> <<0>>
  defp digest(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)
  defp identity(value), do: digest(:erlang.term_to_binary(value))
end
