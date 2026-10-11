# Public TLS95 qualification only; the parent owns cohort/tool/runtime identities.
old_flag = System.get_env("HTTP_FETCH_PROBE_LIBRARY")
System.put_env("HTTP_FETCH_PROBE_LIBRARY", "1")

try do
  Code.require_file("pooled_completion_probe.exs", __DIR__)
after
  if old_flag,
    do: System.put_env("HTTP_FETCH_PROBE_LIBRARY", old_flag),
    else: System.delete_env("HTTP_FETCH_PROBE_LIBRARY")
end

defmodule HTTPFetchTLSTrackingProbe do
  alias HTTP.{ManagedTransport, Promise, RequestCompletion, Response}
  alias HTTPFetchPublicProbe, as: Peer

  @snapshot_fields [
    :lifecycle,
    :active_requests,
    :preparing_requests,
    :pending,
    :connections,
    :resources
  ]
  @unconfirmed {:error, :cleanup_unconfirmed}

  def run do
    profile =
      case System.argv() do
        [] -> :candidate
        ["--cases", "inventory"] -> :inventory
        args -> raise "TLS95 unsupported arguments: #{inspect(args)}"
      end

    {:ok, _} = Application.ensure_all_started(:http_fetch)

    Process.put({__MODULE__, :global}, %{
      snapshots: 0,
      cap: if(profile == :candidate, do: 682, else: 240)
    })

    inventory = [
      {"tls_h1_inventory_idle_close", "tls_h1", :inventory},
      {"tls_h2_inventory_idle_close", "tls_h2", :inventory}
    ]

    cases =
      if profile == :candidate do
        inventory ++
          [
            {"tls_h1_retire_isolation", "tls_h1", :retirement},
            {"tls_h2_retire_isolation", "tls_h2", :retirement},
            {"tls_failed_handshake_unconfirmed", "tls_h2", :handshake}
          ]
      else
        inventory
      end

    outcomes = Enum.map(cases, &run_case/1)
    global = Process.get({__MODULE__, :global})
    passed = Enum.count(outcomes, &(&1.result == :pass))
    cleanups = Enum.count(outcomes, &(&1.cleanup == :pass))

    report("TLS95_SUMMARY", %{
      profile: profile,
      executed_cases: length(outcomes),
      passed_cases: passed,
      failed_cases: length(outcomes) - passed,
      successful_cleanups: cleanups,
      public_snapshot_calls: global.snapshots,
      public_snapshot_cap: global.cap,
      cases: outcomes,
      result: if(passed == length(cases), do: :pass, else: :fail)
    })

    expected = if profile == :candidate, do: 5, else: 2
    ^expected = length(outcomes)

    if passed != expected or cleanups != expected do
      raise "TLS95 qualification failed after #{expected} case and cleanup reports"
    end

    :ok
  end

  defp run_case({name, protocol, kind}) do
    Process.put({__MODULE__, :case}, %{
      token: make_ref(),
      name: name,
      protocol: protocol,
      kind: kind,
      port: nil,
      port_monitor: nil,
      port_exit: nil,
      port_down: nil,
      primary_end: nil,
      cleanup_end: nil,
      shutdown_end: nil,
      helpers: 0,
      jobs: %{},
      custodians: %{},
      monitors: %{},
      scopes: [],
      completions: [],
      receipts: [],
      inventories: [],
      mismatches: [],
      snapshots: 0,
      snapshot_cap: case_cap(kind)
    })

    primary =
      capture(fn ->
        peer = start_peer(protocol)

        case kind do
          :inventory -> inventory_case(peer)
          :retirement -> retirement_case(peer)
          :handshake -> handshake_case(peer)
        end
      end)

    # Cleanup runs independently of primary success, and attempts every owned item.
    cleanup = cleanup()
    state = state()
    primary_ok = match?({:ok, _}, primary) and state.mismatches == []
    result = if primary_ok and cleanup.result == :pass, do: :pass, else: :fail

    report("TLS95_CASE", %{
      case: name,
      result: result,
      primary: printable(primary),
      inventory_observations: Enum.reverse(state.inventories),
      inventory_mismatches: Enum.reverse(state.mismatches),
      helper_starts: state.helpers,
      helper_cap: 10,
      public_snapshot_calls: state.snapshots,
      public_snapshot_cap: state.snapshot_cap
    })

    report("TLS95_CLEANUP", Map.put(cleanup, :case, name))
    Process.delete({Peer, state.port})

    %{
      case: name,
      result: result,
      cleanup: cleanup.result,
      inventory_mismatches: Enum.reverse(state.mismatches),
      primary: printable(primary)
    }
  end

  defp inventory_case(peer) do
    scope = open_scope(peer, :a, :ok)
    one = request(peer, scope, "/one", "ok")
    finish_request(one)
    first = idle_inventory(scope, "after_one", peer.resources)
    repeat_completion(one)
    two = request(peer, scope, "/two", "ok")
    finish_request(two)
    second = idle_inventory(scope, "after_two", peer.resources)
    repeat_completion(two)
    true = first.resources == second.resources

    command(peer, %{"command" => "close", "connection" => 1}, state().primary_end)
    event(peer, &(&1["event"] == "closed" and &1["connection"] == 1), state().primary_end)
    zero = stable_snapshot(scope, idle_fields(0, 0), state().primary_end)
    repeat_completion(one)
    repeat_completion(two)
    events = peer_events(peer)
    verify_wire(peer, events, [{"/one", 1}, {"/two", 1}], [1])
    [%{"event" => "closed", "connection" => 1}] = only(events, "closed")

    %{
      bodies: ["ok", "ok"],
      original_completions: [:ok, :ok],
      accepts: 1,
      requests: 2,
      same_connection: true,
      no_replay: true,
      zero: zero,
      request_deadlines_preserved: true
    }
  end

  defp retirement_case(peer) do
    a = open_scope(peer, :a, :ok)
    one = request(peer, a, "/one", "ok")
    finish_request(one)
    idle_inventory(a, "a_idle", peer.resources)
    repeat_completion(one)
    b = open_scope(peer, :b, :ok)
    live = request(peer, b, "/hold-live", "abcdefgh")
    wait_until(fn -> job(live.id).headers end, live.deadline)

    active = %{
      lifecycle: :open,
      active_requests: 1,
      preparing_requests: 0,
      pending: 0,
      connections: 1
    }

    stable_snapshot(b, active, live.deadline)
    receipt = retire(a, :graceful, :ok, min(state().primary_end, live.deadline))
    :ok = ManagedTransport.await_retired(receipt, 0)
    # Exactly one bounded terminal A call per isolation case, already budgeted.
    {:error, :transport_scope_retired} = budgeted_snapshot(a, state().primary_end)
    event(peer, &(&1["event"] == "closed" and &1["connection"] == 1), live.deadline)
    stable_snapshot(b, active, live.deadline)

    command(
      peer,
      %{"command" => "finish_hold", "connection" => 2, "path" => "/hold-live"},
      live.deadline
    )

    finish_request(live)
    idle_inventory(b, "b_after_hold", peer.resources)
    repeat_completion(live)
    survivor = request(peer, b, "/survivor", "ok")
    finish_request(survivor)
    idle_inventory(b, "b_after_survivor", peer.resources)
    repeat_completion(survivor)
    events = peer_events(peer)
    verify_wire(peer, events, [{"/one", 1}, {"/hold-live", 2}, {"/survivor", 2}], [1, 2])
    [%{"event" => "closed", "connection" => 1}] = only(events, "closed")

    %{
      bodies: ["ok", "abcdefgh", "ok"],
      original_completions: [:ok, :ok, :ok],
      accepts: 2,
      requests: 3,
      isolated_retirement: :ok,
      live_scope_survived: true,
      survivor_reused_connection: 2,
      no_replay: true,
      request_deadlines_preserved: true
    }
  end

  defp handshake_case(peer) do
    scope = open_scope(peer, :a, @unconfirmed)
    rejected = request(peer, scope, "/untrusted", :unknown_ca, @unconfirmed)
    finish_request(rejected)
    repeat_completion(rejected)
    event(peer, &(&1["event"] == "disconnect" and &1["connection"] == 1), state().primary_end)
    event(peer, &(&1["event"] == "closed" and &1["connection"] == 1), state().primary_end)
    receipt = retire(scope, :graceful, @unconfirmed, state().primary_end)
    stable_retired(scope, state().primary_end)
    @unconfirmed = ManagedTransport.await_retired(receipt, 0)
    {:ok, ^receipt} = ManagedTransport.retire(scope)
    events = peer_events(peer)
    [%{"event" => "accept", "connection" => 1}] = only(events, "accept")
    [] = only(events, "request")
    [] = only(events, "tls")
    [] = only(events, "failure")
    [] = only(events, "reset")

    %{
      public_failure: :unknown_ca,
      original_completion: @unconfirmed,
      retirement: @unconfirmed,
      accepts: 1,
      requests: 0,
      conservative_uncertainty: true,
      tls_reclamation_claimed: false,
      request_deadlines_preserved: true
    }
  end

  defp start_peer(protocol) do
    python = System.fetch_env!("HTTP_FETCH_PEER_PYTHON")

    port =
      Port.open({:spawn_executable, python}, [
        :binary,
        :exit_status,
        {:line, 2_000_000},
        args: [Path.join(__DIR__, "managed_tls_tracking_peer.py"), "--protocol", protocol]
      ])

    monitor = :erlang.monitor(:port, port)
    update(&%{&1 | port: port, port_monitor: monitor})
    Process.put({Peer, port}, [])
    ready = Peer.event(port, &(&1["event"] == "ready"), 45_000)
    ^protocol = ready["protocol"]
    true = is_integer(ready["port"]) and ready["port"] > 0
    true = is_binary(ready["ca"])
    now = now()

    update(
      &%{&1 | primary_end: now + 18_000, cleanup_end: now + 30_000, shutdown_end: now + 32_000}
    )

    %{
      port: port,
      origin: "https://localhost:#{ready["port"]}",
      ca: ready["ca"],
      version: if(protocol == "tls_h1", do: :http1, else: :http2),
      resources: if(protocol == "tls_h1", do: 3, else: 4),
      alpn: if(protocol == "tls_h1", do: nil, else: "h2")
    }
  end

  defp open_scope(peer, label, expected) do
    current = state()
    true = map_size(current.custodians) < 2
    parent = self()
    token = current.token
    deadline = current.cleanup_end

    ssl =
      if expected == @unconfirmed,
        do: [verify: :verify_peer, cacerts: []],
        else: [verify: :verify_peer, cacertfile: peer.ca]

    opts = [
      origin: peer.origin,
      connect_address: {127, 0, 0, 1},
      http_version: peer.version,
      tls_backend: :ssl,
      ssl: ssl,
      socket_opts: [send_timeout: 2_000, send_timeout_close: true],
      max_requests: 1,
      max_connections: 1,
      max_pending: 0,
      idle_timeout: 30_000,
      http2_profile: :native_v1
    ]

    custodian = %{pid: nil, monitor: nil, expected: expected, opened: nil, down: nil}
    update(&%{&1 | custodians: Map.put(&1.custodians, label, custodian)})

    {pid, monitor} =
      spawn_monitor(fn ->
        result = capture(fn -> ManagedTransport.open(opts) end)
        send(parent, {__MODULE__, token, :custodian_opened, label, result})
        parent_monitor = Process.monitor(parent)

        receive do
          {__MODULE__, ^token, :stop_custodian} -> :ok
          {:DOWN, ^parent_monitor, :process, ^parent, _} -> :ok
        after
          remaining(deadline) -> exit(:tls95_custodian_deadline)
        end

        Process.demonitor(parent_monitor, [:flush])
      end)

    update(fn s ->
      %{
        s
        | custodians: Map.update!(s.custodians, label, &%{&1 | pid: pid, monitor: monitor}),
          monitors: Map.put(s.monitors, monitor, {:custodian, label})
      }
    end)

    wait_until(fn -> state().custodians[label].opened != nil end, current.primary_end)
    {:ok, {:ok, scope}} = state().custodians[label].opened
    scope
  end

  defp request(peer, scope, path, body, expected \\ :ok) do
    deadline = min(now() + 6_000, state().primary_end)
    parent = self()
    token = state().token

    id =
      start_job(:producer, deadline, fn id ->
        promise =
          HTTP.fetch(peer.origin <> path,
            transport_scope: scope,
            request_mode: :proxy,
            redirect: :manual,
            stream_response: true,
            decode_body: false,
            timeout: remaining!(deadline),
            connect_timeout: 2_000,
            telemetry: false
          )

        completion = Promise.completion(promise)
        send(parent, {__MODULE__, token, :completion, id, path, completion, expected})

        receive do
          {__MODULE__, ^token, :completion_recorded, ^id} -> :ok
        after
          remaining(deadline) -> raise "TLS95 completion registration deadline"
        end

        outcome = Promise.await(promise, remaining!(deadline))

        case body do
          :unknown_ca ->
            {:error, {:tls_alert, {:unknown_ca, message}}} = outcome
            true = is_binary(message) or is_list(message)

          bytes when is_binary(bytes) ->
            %Response{status: 200, body: stream} = outcome
            send(parent, {__MODULE__, token, :headers, id})
            send(stream, {:read_chunk, self(), :ack})
            consume(stream, bytes, deadline, false)
        end

        ^expected = RequestCompletion.await(completion, remaining!(deadline))
        true = now() <= deadline

        public_failure =
          case outcome do
            {:error, {:tls_alert, {:unknown_ca, message}}} ->
              %{kind: :tls_alert, reason: :unknown_ca, message: to_string(message)}

            %Response{} ->
              nil
          end

        %{
          path: path,
          body: body,
          completion: expected,
          public_failure: public_failure,
          deadline_preserved: true
        }
      end)

    wait_until(fn -> job(id).registered or job(id).result != nil end, deadline)

    unless job(id).registered do
      {:error, error} = finish_job(id, deadline)
      raise "TLS95 producer failed before completion capture: #{inspect(error)}"
    end

    %{id: id, deadline: deadline, expected: expected}
  end

  defp consume(stream, remaining_body, deadline, trailers_seen) do
    receive do
      {:stream_chunk, ^stream, bytes, ack} when is_binary(bytes) ->
        rest = body_rest(remaining_body, bytes)
        send(stream, {:stream_chunk_ack, ack})
        consume(stream, rest, deadline, trailers_seen)

      {:stream_chunk, ^stream, bytes} when is_binary(bytes) ->
        consume(stream, body_rest(remaining_body, bytes), deadline, trailers_seen)

      {:stream_trailers, ^stream, %HTTP.Headers{headers: []}} ->
        false = trailers_seen
        "" = remaining_body
        consume(stream, remaining_body, deadline, true)

      {:stream_trailers, ^stream, trailers} ->
        raise "TLS95 unexpected trailers: #{inspect(trailers)}"

      {:stream_end, ^stream} ->
        "" = remaining_body
        :ok

      {:stream_error, ^stream, reason} ->
        raise "TLS95 response error: #{inspect(reason)}"
    after
      remaining!(deadline) -> raise "TLS95 original body deadline exceeded"
    end
  end

  defp body_rest(body, bytes) do
    true = byte_size(bytes) > 0
    size = byte_size(bytes)
    <<^bytes::binary-size(size), rest::binary>> = body
    rest
  end

  defp finish_request(request) do
    {:ok, result} = finish_job(request.id, request.deadline)
    true = result.deadline_preserved
    result
  end

  defp repeat_completion(request) do
    record = Enum.find(state().completions, &(&1.id == request.id))
    expected = request.expected
    ^expected = RequestCompletion.await(record.completion, 0)
  end

  defp retire(scope, mode, expected, deadline, sweep \\ false) do
    parent = self()
    token = state().token
    originals = if sweep, do: Enum.filter(state().receipts, &(&1.scope == scope)), else: []

    id =
      start_job(:retirement, deadline, fn id ->
        acquired =
          capture(fn ->
            {:ok, receipt} = ManagedTransport.retire(scope, mode: mode)
            send(parent, {__MODULE__, token, :receipt, id, scope, receipt, expected})

            receive do
              {__MODULE__, ^token, :receipt_recorded, ^id} -> receipt
            after
              remaining(deadline) -> raise "TLS95 receipt registration deadline"
            end
          end)

        checks =
          case acquired do
            {:ok, receipt} -> originals ++ [%{id: id, receipt: receipt, expected: expected}]
            {:error, _} -> originals
          end

        # Reuse this owned caller for every original receipt, even if acquisition
        # or an earlier receipt check failed; never renew the cleanup deadline.
        results =
          Enum.map(checks, fn entry ->
            result =
              capture(fn ->
                terminal = entry.expected
                ^terminal = ManagedTransport.await_retired(entry.receipt, remaining!(deadline))
                ^terminal = ManagedTransport.await_retired(entry.receipt, 0)
                terminal
              end)

            send(parent, {__MODULE__, token, :receipt_checked, entry.id, sweep, result})
            result
          end)

        {:ok, receipt} = acquired
        true = Enum.all?(results, &match?({:ok, _}, &1))
        %{receipt: receipt, result: expected}
      end)

    {:ok, result} = finish_job(id, deadline)
    result.receipt
  end

  defp idle_inventory(scope, phase, expected_resources) do
    # Stable full map first: retain a baseline count mismatch without aborting reuse.
    snapshot =
      stable_snapshot(
        scope,
        Map.delete(idle_fields(1, expected_resources), :resources),
        state().primary_end
      )

    observation = %{
      phase: phase,
      expected_resources: expected_resources,
      observed_resources: snapshot.resources,
      snapshot: snapshot
    }

    update(fn s ->
      mismatches =
        if snapshot.resources == expected_resources,
          do: s.mismatches,
          else: [observation | s.mismatches]

      %{s | inventories: [observation | s.inventories], mismatches: mismatches}
    end)

    snapshot
  end

  defp idle_fields(connections, resources),
    do: %{
      lifecycle: :open,
      active_requests: 0,
      preparing_requests: 0,
      pending: 0,
      connections: connections,
      resources: resources
    }

  defp stable_snapshot(scope, expected, deadline),
    do: snapshot_window(scope, expected, deadline, 0, nil)

  defp snapshot_window(_scope, _expected, _deadline, 40, _previous),
    do: raise("TLS95 public snapshot window cap exceeded")

  defp snapshot_window(scope, expected, deadline, calls, previous) do
    case budgeted_snapshot(scope, deadline) do
      {:ok, snapshot} ->
        selected = Map.take(snapshot, @snapshot_fields)
        matches = Enum.all?(expected, fn {key, value} -> Map.fetch!(selected, key) == value end)

        if matches and selected == previous do
          selected
        else
          pause(deadline)

          snapshot_window(
            scope,
            expected,
            deadline,
            calls + 1,
            if(matches, do: selected, else: nil)
          )
        end

      {:error, :cleanup_pending} ->
        pause(deadline)
        snapshot_window(scope, expected, deadline, calls + 1, nil)

      error ->
        raise "TLS95 unexpected public snapshot: #{inspect(error)}"
    end
  end

  defp stable_retired(scope, deadline), do: retired_window(scope, deadline, 0, false)

  defp retired_window(_scope, _deadline, 40, _seen),
    do: raise("TLS95 retired window cap exceeded")

  defp retired_window(scope, deadline, calls, seen) do
    case budgeted_snapshot(scope, deadline) do
      {:error, :transport_scope_retired} when seen ->
        :ok

      {:error, :transport_scope_retired} ->
        pause(deadline)
        retired_window(scope, deadline, calls + 1, true)

      {:ok, _} ->
        pause(deadline)
        retired_window(scope, deadline, calls + 1, false)

      {:error, :cleanup_pending} ->
        pause(deadline)
        retired_window(scope, deadline, calls + 1, false)

      error ->
        raise "TLS95 unexpected retirement snapshot: #{inspect(error)}"
    end
  end

  defp budgeted_snapshot(scope, deadline) do
    global = Process.get({__MODULE__, :global})
    current = state()
    true = global.snapshots < global.cap
    true = current.snapshots < current.snapshot_cap
    timeout = min(50, remaining!(deadline))
    Process.put({__MODULE__, :global}, %{global | snapshots: global.snapshots + 1})
    update(&%{&1 | snapshots: &1.snapshots + 1})
    ManagedTransport.snapshot(scope, timeout)
  end

  defp peer_events(peer) do
    deadline = state().primary_end
    Peer.command(peer.port, %{"command" => "wire_snapshot"})
    counters = event(peer, &(&1["event"] == "wire_snapshot"), deadline)["counters"]
    true = counters["h1_partial_header_bytes"] == 0
    true = counters["h2_partial_frame_bytes"] == 0
    Peer.command(peer.port, %{"command" => "snapshot"})
    event(peer, &(&1["event"] == "snapshot"), deadline)["events"]
  end

  defp verify_wire(peer, events, paths, connections) do
    requests = only(events, "request")
    ^paths = Enum.map(requests, &{&1["path"], &1["connection"]})
    ^connections = Enum.map(only(events, "accept"), & &1["connection"])
    ^connections = Enum.map(only(events, "tls"), & &1["connection"])
    true = Enum.all?(only(events, "tls"), &(&1["alpn"] == peer.alpn))
    [] = only(events, "failure")
    [] = only(events, "reset")

    true =
      Enum.all?(requests, fn request ->
        if peer.version == :http1 do
          request["method"] == "GET" and request["body"] == ""
        else
          Enum.filter(request["headers"], fn [name, _] -> name == ":method" end) == [
            [":method", "GET"]
          ]
        end
      end)

    if peer.version == :http2 do
      for cid <- connections do
        streams = requests |> Enum.filter(&(&1["connection"] == cid)) |> Enum.map(& &1["stream"])
        true = Enum.all?(streams, &(is_integer(&1) and &1 > 0))
        true = length(streams) == length(Enum.uniq(streams))
      end
    end

    :ok
  end

  defp command(peer, item, deadline) do
    remaining!(deadline)
    Peer.command(peer.port, item)
    event(peer, &(&1["event"] == "command_done" and &1["command"] == item["command"]), deadline)
  end

  defp event(peer, predicate, deadline),
    do: Peer.event(peer.port, predicate, remaining!(deadline))

  defp only(events, name), do: Enum.filter(events, &(&1["event"] == name))

  defp start_job(role, deadline, fun) do
    remaining!(deadline)
    current = state()
    true = current.helpers < 10
    id = current.helpers + 1
    parent = self()
    token = current.token

    {pid, monitor} =
      spawn_monitor(fn ->
        result = capture(fn -> fun.(id) end)
        send(parent, {__MODULE__, token, :job_result, id, result})
      end)

    owned = %{
      id: id,
      role: role,
      pid: pid,
      monitor: monitor,
      result: nil,
      down: nil,
      registered: false,
      receipt_registered: false,
      headers: false,
      joined: false,
      forced: false
    }

    update(fn s ->
      %{
        s
        | helpers: id,
          jobs: Map.put(s.jobs, id, owned),
          monitors: Map.put(s.monitors, monitor, {:job, id})
      }
    end)

    id
  end

  defp finish_job(id, deadline) do
    wait_until(fn -> job(id).result != nil and job(id).down != nil end, deadline)
    :normal = job(id).down
    update_job(id, &%{&1 | joined: true})
    job(id).result
  end

  defp wait_until(predicate, deadline) do
    if predicate.() do
      :ok
    else
      :message = receive_owned(remaining!(deadline))
      wait_until(predicate, deadline)
    end
  end

  defp receive_owned(timeout) do
    current = state()
    token = current.token
    monitors = current.monitors

    receive do
      {__MODULE__, ^token, :job_result, id, result} ->
        update_job(id, &%{&1 | result: result})

      {__MODULE__, ^token, :headers, id} ->
        update_job(id, &%{&1 | headers: true})

      {__MODULE__, ^token, :completion, id, path, completion, expected} ->
        update(
          &%{
            &1
            | completions:
                &1.completions ++
                  [%{id: id, path: path, completion: completion, expected: expected}]
          }
        )

        update_job(id, &%{&1 | registered: true})
        send(job(id).pid, {__MODULE__, token, :completion_recorded, id})

      {__MODULE__, ^token, :custodian_opened, label, opened} ->
        update_custodian(label, &%{&1 | opened: opened})

        case opened do
          {:ok, {:ok, scope}} ->
            expected = state().custodians[label].expected

            update(
              &%{&1 | scopes: &1.scopes ++ [%{label: label, scope: scope, expected: expected}]}
            )

          _ ->
            :ok
        end

      {__MODULE__, ^token, :receipt, id, scope, receipt, expected} ->
        entry = %{
          id: id,
          scope: scope,
          receipt: receipt,
          expected: expected,
          primary_check: nil,
          cleanup_check: nil
        }

        update(&%{&1 | receipts: &1.receipts ++ [entry]})
        update_job(id, &%{&1 | receipt_registered: true})
        send(job(id).pid, {__MODULE__, token, :receipt_recorded, id})

      {__MODULE__, ^token, :receipt_checked, id, sweep, result} ->
        key = if sweep, do: :cleanup_check, else: :primary_check

        update(fn s ->
          receipts =
            Enum.map(s.receipts, fn entry ->
              if entry.id == id, do: Map.put(entry, key, result), else: entry
            end)

          %{s | receipts: receipts}
        end)

      {:DOWN, monitor, :process, _pid, reason} when is_map_key(monitors, monitor) ->
        case monitors[monitor] do
          {:job, id} -> update_job(id, &%{&1 | down: reason})
          {:custodian, label} -> update_custodian(label, &%{&1 | down: reason})
        end
    after
      timeout -> :empty
    end
    |> case do
      :empty -> :empty
      _ -> :message
    end
  end

  defp drain_owned do
    case receive_owned(0) do
      :message -> drain_owned()
      :empty -> :ok
    end
  end

  defp cleanup do
    # A peer failing before ready still gets a finite owned cleanup deadline.
    if is_nil(state().cleanup_end) do
      update(&%{&1 | cleanup_end: now() + 12_000, shutdown_end: now() + 14_000})
    end

    deadline = state().cleanup_end
    drain_owned()

    open_registration =
      capture(fn ->
        wait_until(
          fn ->
            Enum.all?(state().custodians, fn {_, owned} ->
              owned.opened != nil or owned.down != nil
            end)
          end,
          deadline
        )
      end)

    receipt_registration =
      capture(fn ->
        wait_until(
          fn ->
            state().jobs
            |> Map.values()
            |> Enum.filter(&(&1.role == :retirement))
            |> Enum.all?(&(&1.receipt_registered or &1.result != nil or &1.down != nil))
          end,
          deadline
        )
      end)

    drain_owned()

    scopes =
      Enum.map(state().scopes, fn entry ->
        result =
          capture(fn ->
            retire(entry.scope, :abort, entry.expected, deadline, true)
            :ok
          end)

        %{
          scope: entry.label,
          expected: printable(entry.expected),
          result: printable(result),
          joined: match?({:ok, _}, result)
        }
      end)

    producer_registration =
      capture(fn ->
        wait_until(
          fn ->
            state().jobs
            |> Map.values()
            |> Enum.filter(&(&1.role == :producer))
            |> Enum.all?(&(&1.registered or &1.result != nil))
          end,
          deadline
        )
      end)

    drain_owned()

    completions =
      Enum.map(state().completions, fn entry ->
        result =
          capture(fn ->
            id =
              start_job(:completion_cleanup, deadline, fn _ ->
                expected = entry.expected

                ^expected =
                  RequestCompletion.abort_and_await(
                    entry.completion,
                    min(2_000, remaining!(deadline))
                  )

                expected
              end)

            {:ok, terminal} = finish_job(id, deadline)
            terminal
          end)

        %{
          request: entry.path,
          expected: printable(entry.expected),
          result: printable(result),
          joined: match?({:ok, _}, result)
        }
      end)

    peer = stop_peer(deadline)
    drain_owned()
    jobs = join_jobs(deadline)
    custodians = join_custodians(deadline)

    receipts =
      Enum.map(state().receipts, fn entry ->
        %{
          id: entry.id,
          expected: printable(entry.expected),
          result: printable(entry.cleanup_check),
          checked: match?({:ok, _}, entry.cleanup_check)
        }
      end)

    passed =
      now() <= deadline and match?({:ok, _}, open_registration) and
        match?({:ok, _}, receipt_registration) and match?({:ok, _}, producer_registration) and
        Enum.all?(receipts, & &1.checked) and
        Enum.all?(scopes ++ completions, & &1.joined) and peer.result == :pass and
        Enum.all?(
          jobs ++ custodians,
          &(&1.joined and &1.normal_down and &1.result_ok and &1.join_ok and not &1.forced)
        )

    %{
      result: if(passed, do: :pass, else: :fail),
      scopes: scopes,
      original_completions: completions,
      original_receipts: receipts,
      open_registration: printable(open_registration),
      receipt_registration: printable(receipt_registration),
      producer_registration: printable(producer_registration),
      peer: peer,
      helpers: jobs,
      custodians: custodians,
      original_cleanup_deadline_met: now() <= deadline
    }
  end

  defp join_jobs(deadline) do
    for {id, _} <- Enum.sort(state().jobs) do
      result =
        capture(fn ->
          wait_until(fn -> job(id).result != nil and job(id).down != nil end, deadline)
          :normal = job(id).down
          {:ok, _} = job(id).result
          update_job(id, &%{&1 | joined: true})
          :ok
        end)

      if not match?({:ok, _}, result) and job(id).down == nil do
        Process.exit(job(id).pid, :kill)
        update_job(id, &%{&1 | forced: true})
        capture(fn -> wait_until(fn -> job(id).down != nil end, state().shutdown_end) end)
      end

      %{
        id: id,
        role: job(id).role,
        joined: job(id).down != nil,
        normal_down: job(id).down == :normal,
        result_ok: match?({:ok, _}, job(id).result),
        join_ok: match?({:ok, _}, result),
        join_check: printable(result),
        down: printable(job(id).down),
        forced: job(id).forced,
        result: printable(job(id).result)
      }
    end
  end

  defp join_custodians(deadline) do
    for {label, owned} <- Enum.sort(state().custodians) do
      send(owned.pid, {__MODULE__, state().token, :stop_custodian})

      result =
        capture(fn ->
          wait_until(fn -> state().custodians[label].down != nil end, deadline)
          :normal = state().custodians[label].down
          {:ok, {:ok, _}} = state().custodians[label].opened
          :ok
        end)

      forced = not match?({:ok, _}, result)

      if forced and state().custodians[label].down == nil do
        Process.exit(owned.pid, :kill)

        capture(fn ->
          wait_until(fn -> state().custodians[label].down != nil end, state().shutdown_end)
        end)
      end

      %{
        scope: label,
        joined: state().custodians[label].down != nil,
        normal_down: state().custodians[label].down == :normal,
        result_ok: match?({:ok, {:ok, _}}, state().custodians[label].opened),
        join_ok: match?({:ok, _}, result),
        join_check: printable(result),
        down: printable(state().custodians[label].down),
        forced: forced
      }
    end
  end

  defp stop_peer(deadline) do
    port = state().port

    stopped =
      capture(fn ->
        true = port != nil
        Peer.command(port, %{"command" => "stop"})

        %{"live_threads" => 0} =
          Peer.event(port, &(&1["event"] == "stopped"), remaining!(deadline))
      end)

    exited = capture(fn -> join_port(deadline) end)

    if not match?({:ok, _}, exited) and port != nil and state().port_down == nil do
      capture(fn -> Port.close(port) end)
      capture(fn -> join_port(state().shutdown_end) end)
    end

    %{
      result: if(match?({:ok, _}, stopped) and match?({:ok, _}, exited), do: :pass, else: :fail),
      stopped: printable(stopped),
      exit_status: state().port_exit,
      port_joined: state().port_down != nil,
      joined_exit: printable(exited)
    }
  end

  defp join_port(deadline) do
    current = state()

    cond do
      current.port == nil ->
        raise "TLS95 peer was not started"

      current.port_exit != nil and current.port_down != nil ->
        0 = current.port_exit
        :normal = current.port_down
        :ok

      true ->
        port = current.port
        monitor = current.port_monitor

        receive do
          {^port, {:exit_status, status}} -> update(&%{&1 | port_exit: status})
          {:DOWN, ^monitor, :port, ^port, reason} -> update(&%{&1 | port_down: reason})
        after
          remaining!(deadline) -> raise "TLS95 owned peer exit/join deadline"
        end

        join_port(deadline)
    end
  end

  defp case_cap(:inventory), do: 120
  defp case_cap(:retirement), do: 201
  defp case_cap(:handshake), do: 40
  defp now, do: System.monotonic_time(:millisecond)
  defp remaining(deadline), do: max(deadline - now(), 0)

  defp remaining!(deadline) do
    value = remaining(deadline)
    if value == 0, do: raise("TLS95 original absolute deadline exceeded"), else: value
  end

  defp pause(deadline) do
    receive do
    after
      min(25, remaining!(deadline)) -> :ok
    end
  end

  defp state, do: Process.get({__MODULE__, :case})
  defp update(fun), do: Process.put({__MODULE__, :case}, fun.(state()))
  defp job(id), do: Map.fetch!(state().jobs, id)
  defp update_job(id, fun), do: update(&%{&1 | jobs: Map.update!(&1.jobs, id, fun)})

  defp update_custodian(label, fun),
    do: update(&%{&1 | custodians: Map.update!(&1.custodians, label, fun)})

  defp capture(fun) do
    try do
      {:ok, fun.()}
    catch
      kind, reason ->
        {:error, %{kind: kind, failure: Exception.format(kind, reason, __STACKTRACE__)}}
    end
  end

  defp printable(nil), do: nil

  defp printable({:ok, value}) when is_map(value) do
    # Never serialize opaque public completion/scope/receipt handles.
    false = is_struct(value)
    %{status: :ok, value: Map.drop(value, [:receipt])}
  end

  defp printable({:ok, _}), do: %{status: :ok}
  defp printable({:error, error}) when is_map(error), do: %{status: :error, error: error}
  defp printable(term), do: inspect(term)
  defp report(tag, value), do: IO.puts(tag <> " " <> JSON.encode!(json_value(value)))
  defp json_value(value) when value in [nil, true, false], do: value
  defp json_value(value) when is_atom(value), do: Atom.to_string(value)

  defp json_value(value) when is_map(value),
    do: Map.new(value, fn {key, item} -> {to_string(key), json_value(item)} end)

  defp json_value(value) when is_list(value), do: Enum.map(value, &json_value/1)
  defp json_value(value) when is_tuple(value), do: inspect(value)
  defp json_value(value), do: value
end

HTTPFetchTLSTrackingProbe.run()
