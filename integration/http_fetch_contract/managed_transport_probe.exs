# Preparation only until the containing published cohort is installed/frozen.
# Historical helpers are loaded read-only; their original run is suppressed.
library_flag = System.get_env("HTTP_FETCH_PROBE_LIBRARY")
System.put_env("HTTP_FETCH_PROBE_LIBRARY", "1")
Code.require_file("pooled_completion_probe.exs", __DIR__)

if library_flag,
  do: System.put_env("HTTP_FETCH_PROBE_LIBRARY", library_flag),
  else: System.delete_env("HTTP_FETCH_PROBE_LIBRARY")

defmodule HTTPFetchManagedProbe do
  alias HTTP.{ManagedTransport, Promise, RequestCompletion, Response}
  alias HTTPFetchPublicProbe, as: Peer
  @timeout 6_000

  def with_peer(protocol, fun) do
    python = System.get_env("HTTP_FETCH_PEER_PYTHON") || System.find_executable("python3")
    if is_nil(python), do: raise("BLOCKED_ENV: Python h2 peer unavailable")

    port =
      Port.open({:spawn_executable, python}, [
        :binary,
        :exit_status,
        {:line, 2_000_000},
        args: [Path.join(__DIR__, "managed_peer.py"), "--protocol", protocol]
      ])

    Process.put({Peer, port}, [])
    Process.put({:managed_scopes, port}, [])
    Process.put({:managed_completions, port}, [])

    primary =
      try do
        ready = Peer.event(port, &(&1["event"] == "ready"))
        scheme = if protocol == "tls", do: "https", else: "http"

        peer = %{
          port: port,
          ready: ready,
          protocol: protocol,
          origin: "#{scheme}://localhost:#{ready["port"]}"
        }

        {:ok, fun.(peer)}
      catch
        kind, reason ->
          stacktrace = __STACKTRACE__

          IO.inspect(%{protocol: protocol, failure: Exception.format(kind, reason, stacktrace)},
            label: "MANAGED_PRIMARY_FAILURE"
          )

          IO.inspect(
            %{
              scopes:
                for scope <- Process.get({:managed_scopes, port}, []) do
                  capture(fn -> ManagedTransport.snapshot(scope, 100) end)
                end,
              completions:
                for {completion, expected} <- Process.get({:managed_completions, port}, []) do
                  %{
                    expected: expected,
                    observed: capture(fn -> RequestCompletion.await(completion, 0) end)
                  }
                end
            },
            label: "MANAGED_PRE_CLEANUP"
          )

          {:failed, kind, reason, stacktrace}
      end

    cleanup =
      try do
        :ok = cleanup(port)
      catch
        kind, reason ->
          stacktrace = __STACKTRACE__

          IO.inspect(%{protocol: protocol, failure: Exception.format(kind, reason, stacktrace)},
            label: "MANAGED_CLEANUP_FAILURE"
          )

          {:failed, kind, reason, stacktrace}
      end

    case {primary, cleanup} do
      {{:failed, kind, reason, stacktrace}, _} -> :erlang.raise(kind, reason, stacktrace)
      {{:ok, _}, {:failed, kind, reason, stacktrace}} -> :erlang.raise(kind, reason, stacktrace)
      {{:ok, result}, :ok} -> result
    end
  end

  defp capture(fun) do
    try do
      fun.()
    rescue
      error -> {:fixture_exception, Exception.message(error)}
    catch
      kind, reason -> {:fixture_exit, kind, reason}
    end
  end

  defp cleanup(port) do
    scopes =
      for scope <- Process.get({:managed_scopes, port}, []) do
        capture(fn ->
          {:ok, receipt} = ManagedTransport.retire(scope, mode: :abort)
          :ok = ManagedTransport.await_retired(receipt, 3_000)
        end)
      end

    completions =
      for {completion, expected} <- Process.get({:managed_completions, port}, []) do
        capture(fn ->
          result = RequestCompletion.abort_and_await(completion, 2_000)

          IO.inspect(%{expected: expected, observed: result},
            label: "MANAGED_COMPLETION_CLEANUP"
          )

          ^expected = result
          result
        end)
      end

    stopped =
      capture(fn ->
        Peer.command(port, %{"command" => "stop"})
        %{"live_threads" => 0} = Peer.event(port, &(&1["event"] == "stopped"))

        receive do
          {^port, {:exit_status, 0}} -> :ok
          {^port, {:exit_status, status}} -> raise "managed peer exit #{status}"
        after
          @timeout -> raise "managed peer shutdown deadline exceeded"
        end
      end)

    IO.inspect(%{scopes: scopes, completions: completions, peer: stopped},
      label: "MANAGED_CLEANUP"
    )

    Process.delete({Peer, port})
    Process.delete({:managed_scopes, port})
    Process.delete({:managed_completions, port})
    true = Enum.all?(scopes, &(&1 == :ok))
    true = Enum.all?(completions, &(&1 in [:ok, {:error, :cleanup_unconfirmed}]))
    :ok = stopped
  end

  def options(peer, extra \\ []) do
    version =
      case peer.protocol do
        "h1" -> :http1
        "h2c" -> :h2c
        "tls" -> :http2
      end

    options = [
      origin: peer.origin,
      connect_address: {127, 0, 0, 1},
      http_version: version,
      max_requests: 32,
      max_connections: 2,
      max_pending: 0,
      idle_timeout: 30_000
    ]

    options =
      if peer.protocol == "tls",
        do: options ++ [ssl: [verify: :verify_peer, cacertfile: peer.ready["ca"]]],
        else: options

    Keyword.merge(options, extra)
  end

  defp remember_scope(peer, scope) do
    Process.put(
      {:managed_scopes, peer.port},
      [scope | Process.get({:managed_scopes, peer.port})]
    )

    scope
  end

  def open(peer, extra \\ []) do
    {:ok, scope} = ManagedTransport.open(options(peer, extra))
    remember_scope(peer, scope)
  end

  def fetch(peer, scope, path, extra \\ []) do
    promise =
      HTTP.fetch(
        peer.origin <> path,
        Keyword.merge(
          [
            transport_scope: scope,
            request_mode: :proxy,
            redirect: :manual,
            stream_response: true,
            decode_body: false,
            timeout: @timeout,
            connect_timeout: 2_000,
            telemetry: false
          ],
          extra
        )
      )

    completion = Promise.completion(promise)

    Process.put(
      {:managed_completions, peer.port},
      [{completion, :ok} | Process.get({:managed_completions, peer.port})]
    )

    {promise, completion}
  end

  defp unconfirmed(peer, completion) do
    {:error, :cleanup_unconfirmed} = RequestCompletion.await(completion, 2_000)

    Process.put(
      {:managed_completions, peer.port},
      Enum.map(Process.get({:managed_completions, peer.port}), fn
        {^completion, :ok} -> {completion, {:error, :cleanup_unconfirmed}}
        other -> other
      end)
    )
  end

  defp forced_completion(peer, completion) do
    allowed =
      case peer.protocol do
        "h1" -> [:ok]
        protocol when protocol in ["tls", "h2c"] -> [:ok, {:error, :cleanup_unconfirmed}]
      end

    parent = self()

    {pid, monitor} =
      spawn_monitor(fn ->
        send(
          parent,
          {:forced_completion_result, self(), RequestCompletion.await(completion, 2_000)}
        )
      end)

    observed = RequestCompletion.await(completion, 2_000)

    IO.inspect(%{protocol: peer.protocol, allowed: allowed, observed: observed},
      label: "MANAGED_FORCE_COMPLETION"
    )

    true = observed in allowed

    receive do
      {:forced_completion_result, ^pid, ^observed} -> :ok
    after
      @timeout -> raise "cross-process forced completion deadline exceeded"
    end

    receive do
      {:DOWN, ^monitor, :process, ^pid, :normal} -> :ok
    after
      @timeout -> raise "forced completion waiter shutdown deadline exceeded"
    end

    ^observed = RequestCompletion.await(completion, 0)

    Process.put(
      {:managed_completions, peer.port},
      Enum.map(Process.get({:managed_completions, peer.port}), fn
        {^completion, :ok} -> {completion, observed}
        other -> other
      end)
    )

    observed
  end

  defp drain(peer, scope, path, extra \\ []) do
    {promise, completion} = fetch(peer, scope, path, extra)
    Peer.response(promise, "ok")
    Peer.complete(completion)
  end

  defp idle(scope), do: idle_until(scope, System.monotonic_time(:millisecond) + 3_000)

  defp idle_until(scope, deadline) do
    {:ok, snapshot} = ManagedTransport.snapshot(scope, 100)

    if snapshot.active_requests == 0 and snapshot.preparing_requests == 0 do
      snapshot
    else
      true = System.monotonic_time(:millisecond) < deadline

      receive do
      after
        5 -> idle_until(scope, deadline)
      end
    end
  end

  defp retire(scope, mode \\ :graceful) do
    {:ok, receipt} = ManagedTransport.retire(scope, mode: mode)
    :ok = ManagedTransport.await_retired(receipt, 3_000)
    receipt
  end

  defp repeated_receipt(scope, receipt) do
    parent = self()

    waiters =
      for _ <- 1..2 do
        spawn_monitor(fn ->
          send(parent, {:retired_result, self(), ManagedTransport.await_retired(receipt, 1_000)})
        end)
      end

    :ok = ManagedTransport.await_retired(receipt, 0)
    {:ok, ^receipt} = ManagedTransport.retire(scope)

    for {pid, monitor} <- waiters do
      receive do
        {:retired_result, ^pid, :ok} -> :ok
      after
        @timeout -> raise "concurrent receipt deadline exceeded"
      end

      receive do
        {:DOWN, ^monitor, :process, ^pid, :normal} -> :ok
      after
        @timeout -> raise "receipt waiter shutdown deadline exceeded"
      end
    end
  end

  defp request(peer, path), do: Peer.barrier(peer, "request", path)

  defp closed(peer, cid),
    do:
      Peer.event(
        peer.port,
        &(&1["event"] == "closed" and &1["connection"] == cid)
      )

  defp command(peer, item) do
    Peer.command(peer.port, item)

    Peer.event(
      peer.port,
      &(&1["event"] == "command_done" and &1["command"] == item["command"])
    )
  end

  defp wire(peer) do
    Peer.command(peer.port, %{"command" => "wire_snapshot"})
    Peer.event(peer.port, &(&1["event"] == "wire_snapshot"))["counters"]
  end

  defp no_request_bytes(peer, before) do
    ^before = after_rejection = wire(peer)
    IO.inspect(%{before: before, after: after_rejection}, label: "MANAGED_NO_REQUEST_BYTES")
  end

  defp finish(peer, path, cid),
    do:
      command(
        peer,
        %{"command" => "finish_hold", "path" => path, "connection" => cid}
      )

  defp report(name, details \\ %{}) do
    Process.put(:managed_case_count, Process.get(:managed_case_count, 0) + 1)
    IO.inspect(Map.merge(%{case: name, result: :pass}, details), label: "MANAGED_CASE")
  end

  def common(protocol) do
    with_peer(protocol, fn peer ->
      scope = open(peer, max_connections: 1)
      drain(peer, scope, "/first", timeout: 5_000, connect_timeout: 1_500)
      before = idle(scope)
      drain(peer, scope, "/second", timeout: 1_800, connect_timeout: 900)
      after_reuse = idle(scope)
      %{connections: 1, pending: 0} = before
      true = after_reuse.resources == before.resources
      1 = after_reuse.connections
      receipt = retire(scope)
      repeated_receipt(scope, receipt)
      closed(peer, 1)
      events = Peer.snapshot(peer)
      1 = Peer.accepts(events)

      [%{"path" => "/first", "connection" => 1}, %{"path" => "/second", "connection" => 1}] =
        Peer.requests(events)

      if protocol == "tls",
        do:
          Peer.event(
            peer.port,
            &(&1["event"] == "tls" and &1["alpn"] == "h2")
          )

      report("#{protocol}_unequal_deadlines_reuse_completion_and_receipts")
    end)

    with_peer(protocol, fn peer ->
      a = open(peer)
      b = open(peer)
      drain(peer, a, "/a")
      drain(peer, b, "/b")
      wire_before = wire(peer)
      retire(a)
      closed(peer, 1)
      {rejected, completion} = fetch(peer, a, "/retired")
      {:error, :transport_scope_retired} = Promise.await(rejected, @timeout)
      Peer.complete(completion)
      no_request_bytes(peer, wire_before)
      # A conflicting route must never fall back to a global transport.
      {conflict, cc} = fetch(peer, b, "/conflict", connect_address: {127, 0, 0, 2})
      {:error, :transport_scope_policy_mismatch} = Promise.await(conflict, @timeout)
      Peer.complete(cc)
      no_request_bytes(peer, wire_before)
      drain(peer, b, "/b-survives")
      retire(b)
      closed(peer, 2)
      events = Peer.snapshot(peer)
      2 = Peer.accepts(events)

      [
        %{"path" => "/a", "connection" => 1},
        %{"path" => "/b", "connection" => 2},
        %{"path" => "/b-survives", "connection" => 2}
      ] = Peer.requests(events)

      report("#{protocol}_private_scopes_no_fallback_retire_a_preserves_b")
    end)

    with_peer(protocol, fn peer ->
      scope = open(peer, max_requests: 1, max_connections: 1)
      {held, ch} = fetch(peer, scope, "/hold-capacity")
      %Response{status: 200, body: stream} = Promise.await(held, @timeout)
      %{"connection" => cid} = request(peer, "/hold-capacity")
      {:error, :cleanup_pending} = RequestCompletion.await(ch, 0)
      wire_before = wire(peer)
      1 = wire_before["accepts"]
      {rejected, cr} = fetch(peer, scope, "/over-capacity")
      {:error, {:transport_scope_capacity, :requests}} = Promise.await(rejected, @timeout)
      Peer.complete(cr)
      no_request_bytes(peer, wire_before)

      {:ok, %{active_requests: 1, pending: 0, connections: 1}} =
        ManagedTransport.snapshot(scope, 100)

      finish(peer, "/hold-capacity", cid)
      Peer.consume(stream, "abcdefgh")
      Peer.complete(ch)
      retire(scope)
      closed(peer, cid)
      no_request_bytes(peer, wire_before)
      1 = Peer.accepts(Peer.snapshot(peer))
      [%{"path" => "/hold-capacity"}] = Peer.requests(Peer.snapshot(peer))
      report("#{protocol}_max_requests_before_bytes_no_pending_queue")
    end)

    with_peer(protocol, fn peer ->
      scope = open(peer)
      {held, completion} = fetch(peer, scope, "/hold-graceful")
      %Response{body: stream} = Promise.await(held, @timeout)
      %{"connection" => cid} = request(peer, "/hold-graceful")
      {:ok, receipt} = ManagedTransport.retire(scope, mode: :graceful)
      {:error, :cleanup_pending} = ManagedTransport.await_retired(receipt, 0)
      {:error, :cleanup_pending} = RequestCompletion.await(completion, 0)
      wire_before = wire(peer)
      {rejected, cr} = fetch(peer, scope, "/late-admission")
      {:error, :transport_scope_retired} = Promise.await(rejected, @timeout)
      Peer.complete(cr)
      no_request_bytes(peer, wire_before)
      finish(peer, "/hold-graceful", cid)
      Peer.consume(stream, "abcdefgh")
      Peer.complete(completion)
      :ok = ManagedTransport.await_retired(receipt, 3_000)
      repeated_receipt(scope, receipt)
      closed(peer, cid)
      no_request_bytes(peer, wire_before)
      1 = Peer.accepts(Peer.snapshot(peer))
      [%{"path" => "/hold-graceful"}] = Peer.requests(Peer.snapshot(peer))
      report("#{protocol}_graceful_pending_late_checkin_closes")
    end)

    with_peer(protocol, fn peer ->
      scope = open(peer)
      {held, completion} = fetch(peer, scope, "/hold-abort")
      %Response{} = Promise.await(held, @timeout)
      %{"connection" => cid} = request(peer, "/hold-abort")
      independent = open(peer)
      {healthy, ch} = fetch(peer, independent, "/hold-abort-independent")
      %Response{body: healthy_stream} = Promise.await(healthy, @timeout)
      %{"connection" => healthy_cid} = request(peer, "/hold-abort-independent")
      true = healthy_cid != cid
      receipt = retire(scope, :abort)
      closed(peer, cid)
      {:error, :transport_scope_retired} = ManagedTransport.snapshot(scope, 100)
      {:error, :cleanup_pending} = RequestCompletion.await(ch, 0)

      {:ok,
       %{
         active_requests: 1,
         preparing_requests: 0,
         pending: 0,
         connections: 1,
         resources: resources,
         lifecycle: :open
       }} =
        ManagedTransport.snapshot(independent, 100)

      true = resources > 0
      force_outcome = forced_completion(peer, completion)
      repeated_receipt(scope, receipt)
      {:error, :cleanup_pending} = RequestCompletion.await(ch, 0)
      finish(peer, "/hold-abort-independent", healthy_cid)
      Peer.consume(healthy_stream, "abcdefgh")
      Peer.complete(ch)
      retire(independent)
      closed(peer, healthy_cid)

      [
        %{"path" => "/hold-abort", "connection" => ^cid},
        %{"path" => "/hold-abort-independent", "connection" => ^healthy_cid}
      ] =
        Peer.requests(Peer.snapshot(peer))

      report("#{protocol}_abort_generation_closes_stalled_request", %{
        request_completion: force_outcome,
        generation_retirement: :ok
      })
    end)

    with_peer(protocol, fn peer ->
      parent = self()

      {creator, monitor} =
        spawn_monitor(fn ->
          {:ok, scope} = ManagedTransport.open(options(peer))
          send(parent, {:creator_scope, self(), scope})

          receive do
            :exit -> :ok
          after
            @timeout -> raise "creator barrier deadline exceeded"
          end
        end)

      scope =
        receive do
          {:creator_scope, ^creator, scope} -> remember_scope(peer, scope)
        after
          @timeout -> raise "creator open deadline exceeded"
        end

      {held, completion} = fetch(peer, scope, "/hold-creator")
      %Response{} = Promise.await(held, @timeout)
      %{"connection" => cid} = request(peer, "/hold-creator")
      {:ok, receipt} = ManagedTransport.retire(scope, mode: :graceful)
      {:error, :cleanup_pending} = ManagedTransport.await_retired(receipt, 0)
      send(creator, :exit)

      receive do
        {:DOWN, ^monitor, :process, ^creator, :normal} -> :ok
      after
        @timeout -> raise "creator shutdown deadline exceeded"
      end

      :ok = ManagedTransport.await_retired(receipt, 3_000)
      closed(peer, cid)
      {:error, :transport_scope_retired} = ManagedTransport.snapshot(scope, 100)
      force_outcome = forced_completion(peer, completion)
      repeated_receipt(scope, receipt)

      report("#{protocol}_creator_death_escalates_graceful_to_abort", %{
        request_completion: force_outcome,
        generation_retirement: :ok
      })
    end)
  end

  def deadline(protocol) do
    with_peer(protocol, fn peer ->
      scope = open(peer, max_connections: if(protocol == "h1", do: 2, else: 1))
      {long, cl} = fetch(peer, scope, "/hold-long-deadline", timeout: 5_500)
      %Response{body: long_stream} = Promise.await(long, @timeout)
      %{"connection" => long_cid} = request(peer, "/hold-long-deadline")
      started = System.monotonic_time(:millisecond)
      {short, cs} = fetch(peer, scope, "/deadline-short", timeout: 700, connect_timeout: 400)
      %{"connection" => short_cid} = request(peer, "/deadline-short")
      if protocol == "h1", do: true = short_cid != long_cid, else: true = short_cid == long_cid
      {:error, :request_timeout} = Promise.await(short, 1_700)
      elapsed = System.monotonic_time(:millisecond) - started
      true = elapsed >= 650 and elapsed <= 1_700
      Peer.complete(cs)

      if protocol == "h1",
        do: closed(peer, short_cid),
        else: Peer.barrier(peer, "reset", "/deadline-short")

      {:error, :cleanup_pending} = RequestCompletion.await(cl, 0)

      %{active_requests: 1, preparing_requests: 0, pending: 0, connections: 1} =
        one_held_request(scope, System.monotonic_time(:millisecond) + 2_000)

      finish(peer, "/hold-long-deadline", long_cid)
      Peer.consume(long_stream, "abcdefgh")
      Peer.complete(cl)
      drain(peer, scope, "/after-short-deadline", timeout: 1_800, connect_timeout: 900)
      retire(scope)
      closed(peer, long_cid)
      events = Peer.snapshot(peer)
      expected_accepts = if protocol == "h1", do: 2, else: 1
      ^expected_accepts = Peer.accepts(events)

      [
        %{"path" => "/hold-long-deadline", "connection" => ^long_cid},
        %{"path" => "/deadline-short", "connection" => ^short_cid},
        %{"path" => "/after-short-deadline", "connection" => ^long_cid}
      ] = Peer.requests(events)

      report(
        "#{protocol}_short_absolute_deadline_preserves_live_long_request",
        %{short_timeout_ms: 700, observed_elapsed_ms: elapsed, longer_body: "abcdefgh"}
      )
    end)
  end

  defp one_held_request(scope, deadline) do
    {:ok, snapshot} = ManagedTransport.snapshot(scope, 100)

    if snapshot.active_requests == 1 and snapshot.preparing_requests == 0 and
         snapshot.connections == 1 and snapshot.pending == 0 do
      snapshot
    else
      true = System.monotonic_time(:millisecond) < deadline

      receive do
      after
        5 -> one_held_request(scope, deadline)
      end
    end
  end

  def h1_extra do
    with_peer("h1", fn peer ->
      scope = open(peer, max_requests: 2, max_connections: 1)
      {held, completion} = fetch(peer, scope, "/hold-connection")
      %Response{body: stream} = Promise.await(held, @timeout)
      request(peer, "/hold-connection")
      wire_before = wire(peer)
      {rejected, cr} = fetch(peer, scope, "/connection-overflow")
      {:error, {:transport_scope_capacity, :connections}} = Promise.await(rejected, @timeout)
      Peer.complete(cr)
      no_request_bytes(peer, wire_before)
      {:ok, %{pending: 0, connections: 1}} = ManagedTransport.snapshot(scope, 100)
      finish(peer, "/hold-connection", 1)
      Peer.consume(stream, "abcdefgh")
      Peer.complete(completion)
      retire(scope)
      closed(peer, 1)
      no_request_bytes(peer, wire_before)
      events = Peer.snapshot(peer)
      1 = Peer.accepts(events)
      [%{"path" => "/hold-connection"}] = Peer.requests(events)
      report("h1_max_connections_before_bytes_no_pending_queue")
    end)

    with_peer("h1", fn peer ->
      scope = open(peer, max_connections: 1)
      drain(peer, scope, "/warm")
      {post, completion} = fetch(peer, scope, "/post-close", method: :post, body: "once")
      {:error, _} = Promise.await(post, @timeout)
      Peer.complete(completion)
      closed(peer, 1)
      retire(scope, :abort)
      events = Peer.snapshot(peer)
      1 = Peer.accepts(events)

      [%{"path" => "/warm"}, %{"path" => "/post-close", "method" => "POST", "body" => "once"}] =
        Peer.requests(events)

      report("h1_reused_post_failure_no_replay")
    end)
  end

  def h2_capacity(protocol) do
    with_peer(protocol, fn peer ->
      scope = open(peer, max_requests: 2, max_connections: 1)
      {held, completion} = fetch(peer, scope, "/hold-draining")
      %Response{body: stream} = Promise.await(held, @timeout)
      %{"connection" => cid} = request(peer, "/hold-draining")
      independent = open(peer, max_connections: 1)
      drain(peer, independent, "/independent-before")

      command(peer, %{
        "command" => "drain_connection",
        "path" => "/hold-draining",
        "connection" => cid
      })

      Peer.event(peer.port, &(&1["event"] == "drain_ack" and &1["connection"] == cid))
      {:error, :cleanup_pending} = RequestCompletion.await(completion, 0)

      {:ok, %{active_requests: 1, pending: 0, connections: 1}} =
        ManagedTransport.snapshot(scope, 100)

      wire_before = wire(peer)
      {rejected, cr} = fetch(peer, scope, "/draining-overflow")
      # PR81 SocketClient466–482 propagates Pool505's zero-queue error.
      # This differs from the canonical capacity tuple in facade docs45–48.
      actual_error = Promise.await(rejected, @timeout)
      documented_error = {:error, {:transport_scope_capacity, :connections}}
      # TODO(upstream): gsmlg-dev/http_fetch#89 — canonical connection-capacity tuple.
      # WORKAROUND(upstream): gsmlg-dev/http_fetch#89 — retain explicit canonical MISMATCH.
      source_error = {:error, :pending_capacity}

      IO.inspect(
        %{
          documented: documented_error,
          source_expected: source_error,
          observed: actual_error,
          result: if(actual_error == documented_error, do: :match, else: :mismatch)
        },
        label: "MANAGED_CAPACITY_ERROR_CONTRACT"
      )

      ^source_error = actual_error
      Peer.complete(cr)
      no_request_bytes(peer, wire_before)
      events = Peer.snapshot(peer)
      2 = Peer.accepts(events)

      [%{"path" => "/hold-draining"}, %{"path" => "/independent-before"}] =
        Peer.requests(events)

      drain(peer, independent, "/independent-during")

      {:ok, %{active_requests: 1, pending: 0, connections: 1}} =
        ManagedTransport.snapshot(scope, 100)

      finish(peer, "/hold-draining", cid)
      Peer.consume(stream, "abcdefgh")
      Peer.complete(completion)
      closed(peer, cid)
      # Closure includes the independently retained protocol/TLS resources;
      # retry only after the public aggregate connection ledger reaches zero.
      zero_connections(scope, System.monotonic_time(:millisecond) + 3_000)
      drain(peer, scope, "/after-drain")
      retire(scope)
      retire(independent)
      events = Peer.snapshot(peer)
      3 = Peer.accepts(events)

      [
        %{"path" => "/hold-draining", "connection" => ^cid},
        %{"path" => "/independent-before", "connection" => independent_cid},
        %{"path" => "/independent-during", "connection" => independent_cid},
        %{"path" => "/after-drain", "connection" => replacement_cid}
      ] = Peer.requests(events)

      true = independent_cid != cid and replacement_cid != cid

      report(
        "#{protocol}_max_connections_draining_before_bytes_no_pending_queue",
        %{canonical_error_contract: :mismatch, observed_error: actual_error}
      )
    end)
  end

  defp zero_connections(scope, deadline) do
    {:ok, snapshot} = ManagedTransport.snapshot(scope, 100)

    if snapshot.connections == 0 and snapshot.active_requests == 0 and
         snapshot.preparing_requests == 0 and snapshot.resources == 0 do
      snapshot
    else
      true = System.monotonic_time(:millisecond) < deadline

      receive do
      after
        5 -> zero_connections(scope, deadline)
      end
    end
  end

  def fragments(protocol) do
    for body <- [false, true] do
      with_peer(protocol, fn peer ->
        scope = open(peer, max_connections: 1)
        {promise, completion} = fetch(peer, scope, "/fragment256")
        %{"connection" => cid} = request(peer, "/fragment256")

        command(peer, %{
          "command" => "fragments",
          "path" => "/fragment256",
          "connection" => cid,
          "count" => 256,
          "body" => body
        })

        if body do
          %Response{status: 200, body: stream} = Promise.await(promise, @timeout)
          true = is_pid(stream)
          Peer.consume(stream, "bounded")
        else
          %Response{status: 200, body: ""} = Promise.await(promise, @timeout)
        end

        Peer.complete(completion)
        retire(scope)
        closed(peer, cid)
        [%{"path" => "/fragment256"}] = Peer.requests(Peer.snapshot(peer))
        report("#{protocol}_frame256_success_body_#{body}")
      end)
    end

    for nonempty <- [false, true], final <- [false, true] do
      with_peer(protocol, fn peer ->
        scope = open(peer, max_connections: 1)
        {promise, completion} = fetch(peer, scope, "/fragment257")
        %{"connection" => cid} = request(peer, "/fragment257")

        command(peer, %{
          "command" => "fragments",
          "path" => "/fragment257",
          "connection" => cid,
          "count" => 257,
          "nonempty" => nonempty,
          "final" => final
        })

        {:error, {:transport_error, :header_block_too_fragmented}} =
          Promise.await(promise, @timeout)

        # A managed H2 request uses a shared owner even with no sibling.
        unconfirmed(peer, completion)
        closed(peer, cid)
        retire(scope, :abort)
        events = Peer.snapshot(peer)
        1 = Peer.accepts(events)
        [%{"path" => "/fragment257"}] = Peer.requests(events)
        report("#{protocol}_frame257_reject_nonempty_#{nonempty}_final_#{final}")
      end)
    end

    with_peer(protocol, fn peer ->
      a = open(peer, max_connections: 1)
      b = open(peer, max_connections: 1)
      {offender, co} = fetch(peer, a, "/fragment-shared")
      %{"connection" => cid} = request(peer, "/fragment-shared")
      {sibling, cs} = fetch(peer, a, "/hold-sibling")
      %Response{body: sibling_stream} = Promise.await(sibling, @timeout)
      %{"connection" => ^cid} = request(peer, "/hold-sibling")
      {healthy, ch} = fetch(peer, b, "/hold-independent")
      %Response{body: healthy_stream} = Promise.await(healthy, @timeout)
      %{"connection" => healthy_cid} = request(peer, "/hold-independent")
      true = healthy_cid != cid
      send(sibling_stream, {:read_chunk, self(), :ack})

      command(peer, %{
        "command" => "fragments",
        "path" => "/fragment-shared",
        "connection" => cid,
        "count" => 257,
        "nonempty" => false,
        "final" => false
      })

      {:error, {:transport_error, :header_block_too_fragmented}} =
        Promise.await(offender, @timeout)

      receive do
        {:stream_error, ^sibling_stream, {:transport_error, :header_block_too_fragmented}} -> :ok
      after
        @timeout -> raise "affected sibling did not settle"
      end

      unconfirmed(peer, co)
      unconfirmed(peer, cs)
      closed(peer, cid)
      {:error, :cleanup_pending} = RequestCompletion.await(ch, 0)
      finish(peer, "/hold-independent", healthy_cid)
      Peer.consume(healthy_stream, "abcdefgh")
      Peer.complete(ch)

      %{active_requests: 0, preparing_requests: 0, connections: 0, resources: 0} =
        zero_connections(a, System.monotonic_time(:millisecond) + 3_000)

      drain(peer, a, "/replacement")
      %{"connection" => replacement_cid} = request(peer, "/replacement")
      3 = replacement_cid
      true = replacement_cid != cid and replacement_cid != healthy_cid
      retire(a)
      retire(b)
      events = Peer.snapshot(peer)
      3 = Peer.accepts(events)

      %{"accepts" => 3, "h2_headers" => 4, "h2_continuations" => 0, "h2_partial_frame_bytes" => 0} =
        wire(peer)

      [
        %{"path" => "/fragment-shared", "connection" => ^cid},
        %{"path" => "/hold-sibling", "connection" => ^cid},
        %{"path" => "/hold-independent", "connection" => ^healthy_cid},
        %{"path" => "/replacement", "connection" => ^replacement_cid}
      ] = Peer.requests(events)

      report("#{protocol}_fragment_connection_failure_sibling_independent_no_replay")
    end)
  end

  def run do
    Peer.start_apps()
    Process.put(:managed_case_count, 0)

    for protocol <- ["h1", "tls", "h2c"] do
      common(protocol)
      deadline(protocol)
    end

    h1_extra()

    for protocol <- ["tls", "h2c"] do
      h2_capacity(protocol)
      fragments(protocol)
    end

    39 = Process.get(:managed_case_count)

    IO.puts(
      "MANAGED_PROBE_PASS cases=39; resource properties only; canonical H2 capacity error MISMATCH"
    )
  end
end

HTTPFetchManagedProbe.run()
