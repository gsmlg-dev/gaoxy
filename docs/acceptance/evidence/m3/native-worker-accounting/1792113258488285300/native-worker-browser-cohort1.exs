defmodule NativeWorkerBrowserCohort do
  @moduledoc "Test-only bounded metadata observer; root owns accounting validation."
  use GenServer
  @timeout 2_000
  @lifetime 90_000
  @events 2_048
  @actors 128
  @cuts 128
  @lease_keys ~w(pid monitor bytes token timer send drain_notify request_active cleanup deadline)a
  @spawn_keys ~w(owner parent_lease worker lease activation from deadline phase exit_seen down_seen)a
  @cleanup_keys ~w(monitor bytes lease receipt)a

  def install(gate, %{service: service, mode: mode} = scope)
      when is_pid(gate) and is_pid(service) and mode in [:h1, :h2] do
    owner = self()
    {:ok, observer} = GenServer.start(__MODULE__, {gate, owner, scope})
    {session, hook} = GenServer.call(observer, :attachment, @timeout)

    acc = %{
      observer: observer,
      owner: owner,
      session: session,
      sequence: 0,
      pending: %{},
      monitors: %{},
      faulted: false
    }

    case :sys.install(gate, {hook, &__MODULE__.debug/3, acc}, @timeout) do
      :ok ->
        {:ok, observer}

      error ->
        GenServer.stop(observer, :normal, @timeout)
        {:error, {:cohort_debug_install, reason(error)}}
    end
  end

  # Root must first verify listener -> acceptor -> connection span ancestry.
  # This runs synchronously in the connection's TI :start callback, before handshake.
  def native_start(observer, pid, ancestry) when pid == self() do
    GenServer.call(observer, {:native_start, pid, ancestry}, @timeout)
  end

  # The CALLER sends the real public Gate :status request. Exact alias, not a
  # later independent state read, binds its response to the debug out-State.
  def snapshot(observer, gate) do
    deadline = now() + @timeout
    :ok = GenServer.call(observer, {:expect_snapshot, gate}, remaining(deadline))
    request = :gen_server.send_request(gate, :status)

    case :gen_server.receive_response(request, remaining(deadline)) do
      {:reply, status} when is_map(status) ->
        GenServer.call(
          observer,
          {:snapshot, {self(), request}, status, deadline},
          remaining(deadline) + 100
        )

      _ ->
        raise "cohort public status response failed"
    end
  end

  # Failure-path finite prefix only; not a trace-delivery/completeness proof.
  def facts(observer), do: GenServer.call(observer, :facts, @timeout)

  # Call only after final snapshot/native joins; root also monitors observer.
  def stop(observer, gate) do
    :ok = :sys.remove(gate, {__MODULE__, observer}, @timeout)
    GenServer.stop(observer, :normal, @timeout)
  end

  @impl true
  def init({gate, owner, scope}) do
    session = :trace.session_create(__MODULE__, self(), [])
    # VM-side filters: NO other sends/receives, socket/state replies or spawn
    # args enter the observer. No :procs/:call tracing is enabled.
    sender = [{:is_pid, :"$1"}, {:is_pid, :"$2"}, {:"=:=", :"$2", {:self}}]

    1 =
      :trace.send(
        session,
        [
          {[:"$1", {:h2_writer_ready, :"$2"}], sender, []},
          {[:"$1", {:h2_written, :"$2", :"$3", :"$4"}],
           sender ++
             [{:is_reference, :"$3"}, {:orelse, {:"=:=", :"$4", :ok}, {:"=:=", :"$4", :expired}}],
           []},
          {[:"$1", {:h2_written, :"$2", :"$3", {:error, :"$4"}}],
           sender ++ [{:is_reference, :"$3"}, {:is_atom, :"$4"}], []},
          {[:"$1", :stop], [{:is_pid, :"$1"}], []}
        ],
        []
      )

    1 =
      :trace.recv(
        session,
        [
          {[:_, :_, :stop], [], []},
          {[:_, :_, {:DOWN, :"$1", :process, :"$2", :"$3"}],
           [{:is_reference, :"$1"}, {:is_pid, :"$2"}, {:is_atom, :"$3"}], []},
          {[:_, :_, {:DOWN, :"$1", :process, :"$2", {:shutdown, :peer_closed}}],
           [{:is_reference, :"$1"}, {:is_pid, :"$2"}], []}
        ],
        []
      )

    Process.send_after(self(), :lifetime_expired, @lifetime)

    {:ok,
     %{
       gate: gate,
       owner: owner,
       scope: scope,
       session: session,
       hook: {__MODULE__, self()},
       owner_monitor: Process.monitor(owner),
       gate_monitor: Process.monitor(gate),
       monitors: %{},
       native: %{},
       ready: %{},
       acquisitions: [],
       terminal: [],
       causal: [],
       expecting: MapSet.new(),
       cuts: %{},
       waiters: %{},
       barriers: %{},
       count: 0
     }}
  end

  @impl true
  def handle_call(:attachment, _from, s), do: {:reply, {s.session, s.hook}, s}

  def handle_call(:facts, _from, s), do: {:reply, ledger(s), s}

  def handle_call({:expect_snapshot, gate}, {caller, _}, s) do
    true = gate == s.gate and not MapSet.member?(s.expecting, caller)
    true = MapSet.size(s.expecting) < @cuts
    {:reply, :ok, %{s | expecting: MapSet.put(s.expecting, caller)}}
  end

  def handle_call({:native_start, pid, ancestry}, {pid, _}, s) do
    %{service: service, listener: listener, acceptor: acceptor, span: span} = ancestry
    true = service == s.scope.service
    true = is_reference(listener) and is_reference(acceptor) and is_reference(span)
    true = not Map.has_key?(s.native, pid) and map_size(s.monitors) < @actors
    monitor = Process.monitor(pid)

    fact = %{
      pid: pid,
      service: service,
      listener: listener,
      acceptor: acceptor,
      span: span,
      monitor: monitor
    }

    s = bump(s)

    {:reply, :ok,
     %{s | native: Map.put(s.native, pid, fact), monitors: Map.put(s.monitors, monitor, pid)}}
  end

  def handle_call({:snapshot, key, status, deadline}, from, s) do
    true = elem(key, 0) == elem(from, 0)
    true = map_size(s.waiters) < @cuts and not Map.has_key?(s.waiters, key)
    Process.send_after(self(), {:snapshot_timeout, key}, remaining(deadline))
    waiter = %{from: from, status: status, deadline: deadline, barrier: false}
    s = %{s | waiters: Map.put(s.waiters, key, waiter)}
    {:noreply, progress(s)}
  end

  @impl true
  # Only explicitly registered snapshot callers create cuts. Service/status
  # polling is not a checkpoint and cannot fill the retained-cut budget.
  def handle_info({:cohort_gate, _sequence, {:status, {caller, _}, _}} = message, s) do
    if MapSet.member?(s.expecting, caller),
      do: gate_event(message, s),
      else: {:noreply, s}
  end

  def handle_info({:cohort_gate, _, _} = message, s), do: gate_event(message, s)

  def handle_info({:cohort_fault, fault}, s), do: fail(s, fault)

  def handle_info({:trace_ts, writer, tag, {:h2_writer_ready, writer}, owner, timestamp}, s)
      when tag in [:send, :send_to_non_existing_process] and is_pid(writer) and
             is_pid(owner) and is_integer(timestamp) do
    true = not Map.has_key?(s.ready, writer)
    s = bump(s)
    fact = %{writer: writer, owner: owner, timestamp: timestamp, delivery: tag}
    {:noreply, progress(%{s | ready: Map.put(s.ready, writer, fact)})}
  end

  def handle_info(
        {:trace_ts, writer, tag, {:h2_written, writer, token, result}, owner, timestamp},
        s
      )
      when tag in [:send, :send_to_non_existing_process] and is_pid(writer) and
             is_pid(owner) and is_reference(token) and is_integer(timestamp) do
    causal(s, %{
      event: :h2_written,
      pid: writer,
      destination: owner,
      token: token,
      result: write_result(result),
      direction: :send,
      timestamp: timestamp
    })
  end

  def handle_info({:trace_ts, pid, tag, :stop, destination, timestamp}, s)
      when tag in [:send, :send_to_non_existing_process] and is_pid(pid) and
             is_pid(destination) and is_integer(timestamp) do
    causal(s, %{
      event: :stop,
      pid: pid,
      destination: destination,
      direction: :send,
      timestamp: timestamp
    })
  end

  def handle_info({:trace_ts, pid, :receive, :stop, timestamp}, s)
      when is_pid(pid) and is_integer(timestamp) do
    causal(s, %{event: :stop, pid: pid, direction: :receive, timestamp: timestamp})
  end

  def handle_info(
        {:trace_ts, pid, :receive, {:DOWN, monitor, :process, owner, why}, timestamp},
        s
      )
      when is_pid(pid) and is_pid(owner) and is_reference(monitor) and is_integer(timestamp) do
    causal(s, %{
      event: :owner_down,
      pid: pid,
      owner: owner,
      monitor: monitor,
      reason: reason(why),
      direction: :receive,
      timestamp: timestamp
    })
  end

  def handle_info({:trace_delivered, :all, marker}, s) do
    case Map.pop(s.barriers, marker) do
      {nil, _} ->
        fail(s, :unknown_trace_barrier)

      {key, barriers} ->
        waiter = Map.fetch!(s.waiters, key)
        s = %{s | barriers: barriers, waiters: Map.put(s.waiters, key, %{waiter | barrier: true})}
        {:noreply, progress(s)}
    end
  end

  def handle_info({:DOWN, monitor, :process, pid, why}, s) do
    cond do
      monitor == s.owner_monitor and pid == s.owner ->
        {:stop, :normal, s}

      monitor == s.gate_monitor and pid == s.gate ->
        fail(s, :gate_exited)

      Map.get(s.monitors, monitor) == pid ->
        s = bump(s)

        fact = %{
          pid: pid,
          monitor: monitor,
          reason: reason(why),
          source: :observer_monitor,
          sequence: nil
        }

        {:noreply, %{s | terminal: [fact | s.terminal]}}

      true ->
        fail(s, :unknown_observer_monitor)
    end
  end

  def handle_info({:snapshot_timeout, key}, s) do
    if Map.has_key?(s.waiters, key),
      do: fail(s, :snapshot_receipt_timeout),
      else: {:noreply, s}
  end

  def handle_info(:lifetime_expired, s), do: fail(s, :observer_lifetime_expired)
  def handle_info(_, s), do: fail(s, :unexpected_observer_message)

  defp gate_event({:cohort_gate, sequence, event}, s) do
    s = bump(s)

    s =
      case event do
        {:acquired, fact} ->
          true = length(s.acquisitions) < @actors
          true = not Enum.any?(s.acquisitions, &(&1.lease == fact.lease))
          s = watch(s, fact.pid)
          %{s | acquisitions: [Map.put(fact, :sequence, sequence) | s.acquisitions]}

        {:status, from, cut} ->
          true = map_size(s.cuts) < @cuts
          key = alias_key(from)
          true = not Map.has_key?(s.cuts, key)
          %{s | cuts: Map.put(s.cuts, key, Map.merge(cut, %{sequence: sequence, from: from}))}

        {:terminal, fact} ->
          %{
            s
            | terminal: [
                Map.merge(fact, %{source: :authenticated_gate_monitor, sequence: sequence})
                | s.terminal
              ]
          }
      end

    {:noreply, progress(s)}
  end

  @impl true
  def terminate(_why, s), do: :trace.session_destroy(s.session)

  # Runs in Gate. No file I/O, receive, nested call or state query.
  # Faults are explicit and never include the offending raw term.
  def debug(%{faulted: true} = acc, _event, _extra), do: acc

  def debug(acc, event, _extra) do
    acc = %{acc | sequence: acc.sequence + 1}

    try do
      debug_event(acc, event)
    catch
      _, _ ->
        send(acc.owner, {:cohort_observer_fault, acc.observer, :unsafe_gate_event})
        send(acc.observer, {:cohort_fault, :unsafe_gate_event})
        %{acc | faulted: true}
    end
  end

  defp debug_event(acc, {:in, {:"$gen_call", from, {:acquire, bytes, options}}}) do
    _ = alias_key(from)
    {pid, _} = from
    true = is_integer(bytes) and bytes >= 0
    true = options in [[], [drain_notify: true], [drain_notify: false]]
    true = map_size(acc.pending) < @actors and not Map.has_key?(acc.pending, from)
    # Before acquire reply, so even a short-lived writer's ready cannot be lost.
    1 = :trace.process(acc.session, pid, true, [:send, :receive, :monotonic_timestamp])
    pending = Map.put(acc.pending, from, %{pid: pid, bytes: bytes, options: options})
    %{acc | pending: pending}
  end

  defp debug_event(acc, {:out, reply, from, state}) do
    case Map.pop(acc.pending, from) do
      {nil, _} ->
        if is_map(reply) and Map.has_key?(reply, :retained_bytes) do
          status =
            fields(
              reply,
              ~w(active cleanup_pending retained_bytes retained_high_water rejected queued_items queued_bytes)a
            )

          cut = %{
            status: status,
            bytes: scalar(state.bytes),
            leases: records(state.leases, @lease_keys),
            spawns: records(state.spawns, @spawn_keys),
            cleanups: records(state.cleanups, @cleanup_keys)
          }

          emit(acc, {:status, from, cut})
        end

        acc

      {request, pending} ->
        acc = %{acc | pending: pending}

        case reply do
          {:ok, lease} when is_reference(lease) ->
            record = Map.fetch!(state.leases, lease)
            safe = fields(record, @lease_keys)
            true = safe.pid == request.pid and safe.bytes == request.bytes
            true = is_reference(safe.monitor)
            fact = Map.merge(request, %{lease: lease, monitor: safe.monitor, from: from})
            emit(acc, {:acquired, fact})
            true = map_size(acc.monitors) < @actors
            %{acc | monitors: Map.put(acc.monitors, safe.monitor, fact)}

          {:error, why} when is_atom(why) ->
            # A rejected acquire has no lease. Record its explicit failure.
            send(acc.owner, {:cohort_observer_fault, acc.observer, :acquire_rejected})
            send(acc.observer, {:cohort_fault, :acquire_rejected})
            %{acc | faulted: true}
        end
    end
  end

  defp debug_event(acc, {:in, {:DOWN, monitor, :process, pid, why}}) do
    case Map.fetch(acc.monitors, monitor) do
      {:ok, %{pid: ^pid} = acquired} ->
        emit(
          acc,
          {:terminal, %{pid: pid, monitor: monitor, lease: acquired.lease, reason: reason(why)}}
        )

        acc

      # Gate also monitors cleanup guardians/its spawned target child.
      _ ->
        acc
    end
  end

  defp debug_event(acc, _), do: acc

  defp emit(acc, event), do: send(acc.observer, {:cohort_gate, acc.sequence, event})

  defp progress(s) do
    Enum.reduce(Map.keys(s.waiters), s, fn key, s ->
      waiter = Map.fetch!(s.waiters, key)

      case Map.fetch(s.cuts, key) do
        :error ->
          s

        {:ok, cut} ->
          true = cut.status == waiter.status

          acquired =
            Enum.filter(s.acquisitions, fn a ->
              a.sequence < cut.sequence and Map.has_key?(cut.leases, a.lease)
            end)

          ready =
            Enum.all?(acquired, fn a ->
              Map.has_key?(s.native, a.pid) or Map.has_key?(s.ready, a.pid)
            end)

          cond do
            not ready ->
              s

            waiter.barrier ->
              true = remaining(waiter.deadline) > 0
              GenServer.reply(waiter.from, Map.put(cut, :ledger, ledger(s)))
              {caller, _} = key

              %{
                s
                | cuts: Map.delete(s.cuts, key),
                  waiters: Map.delete(s.waiters, key),
                  expecting: MapSet.delete(s.expecting, caller)
              }

            Enum.any?(s.barriers, fn {_, candidate} -> candidate == key end) ->
              s

            true ->
              marker = :trace.delivered(s.session, :all)
              %{s | barriers: Map.put(s.barriers, marker, key)}
          end
      end
    end)
  end

  defp ledger(s) do
    %{
      acquisitions: Enum.reverse(s.acquisitions),
      ready: Map.values(s.ready),
      native_starts: Map.values(s.native),
      terminal: Enum.reverse(s.terminal),
      causal: Enum.reverse(s.causal)
    }
  end

  defp causal(s, fact) do
    s = bump(s)
    send(s.owner, {:cohort_trace, self(), fact})
    {:noreply, %{s | causal: [fact | s.causal]}}
  end

  defp write_result(result) when result in [:ok, :expired], do: result
  defp write_result({:error, value}) when is_atom(value), do: {:error, reason(value)}

  defp watch(s, pid) do
    if Enum.any?(s.monitors, fn {_, known} -> known == pid end) do
      s
    else
      true = map_size(s.monitors) < @actors
      %{s | monitors: Map.put(s.monitors, Process.monitor(pid), pid)}
    end
  end

  defp records(map, keys) when map_size(map) <= @actors do
    Map.new(map, fn {ref, record} ->
      true = is_reference(ref)
      {ref, fields(record, keys)}
    end)
  end

  defp fields(map, keys) do
    true = map_size(map) == length(keys)

    Map.new(keys, fn key ->
      value = Map.fetch!(map, key)

      safe =
        case {key, value} do
          {:send, nil} ->
            nil

          {:send, %{operation: op, bytes: bytes} = send} ->
            true = map_size(send) == 2 and is_reference(op) and is_integer(bytes)
            %{operation: op, bytes: bytes}

          {:from, nil} ->
            nil

          {:from, wire} ->
            _ = alias_key(wire)
            wire

          _ ->
            scalar(value)
        end

      {key, safe}
    end)
  end

  defp scalar(value) when is_pid(value) or is_reference(value) or is_integer(value), do: value

  defp scalar(value) when value in [nil, true, false, :pending_activation, :running, :cancelled],
    do: value

  defp alias_key({pid, [:alias | ref]}) when is_pid(pid) and is_reference(ref), do: {pid, ref}

  defp reason(value), do: reason(value, 0)

  defp reason(value, _)
       when value in [
              nil,
              :normal,
              :noproc,
              :shutdown,
              :peer_closed,
              :closed,
              :killed,
              :kill,
              :timeout,
              :read_timeout,
              :error,
              :throw,
              :exit,
              :handshake_timeout,
              :enotconn,
              :econnreset,
              :econnaborted,
              :stale_or_pending_send,
              :stale_operation,
              :einval,
              :etimedout
            ],
       do: value

  defp reason({tag, value}, depth) when tag in [:shutdown, :handshake, :tls_alert] and depth < 3,
    do: {tag, reason(value, depth + 1)}

  defp reason(_, _), do: :omitted_terminal_reason

  defp bump(s) do
    true = s.count < @events
    %{s | count: s.count + 1}
  end

  defp fail(s, why) do
    send(s.owner, {:cohort_observer_fault, self(), why})
    {:stop, {:cohort_observer_fault, why}, s}
  end

  defp now, do: System.monotonic_time(:millisecond)
  defp remaining(deadline), do: max(0, deadline - now())
end
