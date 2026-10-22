defmodule Gaoxy.Test.Instance do
  @moduledoc false
  use GenServer, restart: :temporary
  alias Gaoxy.Test.{Expectations, Handle, Server, UnavailableError}

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  def call(%Handle{pid: pid, id: id}, request, timeout \\ 6_000) do
    try do
      case GenServer.call(pid, {:fixture, id, request}, timeout) do
        {:fixture_unavailable, reason} ->
          raise UnavailableError, message: "fixture unavailable: #{inspect(reason)}"

        reply ->
          reply
      end
    catch
      :exit, reason ->
        raise UnavailableError,
          message: "fixture state unavailable or expired: #{inspect(reason)}"
    end
  end

  def admit(pid, fixture_id, metadata),
    do: GenServer.call(pid, {:fixture, fixture_id, {:admit, self(), metadata}})

  def complete(pid, request_id, outcome), do: safe_call(pid, {:complete, request_id, outcome})

  def establish(pid, request_id, session_pid),
    do: safe_call(pid, {:establish, request_id, session_pid})

  def event(pid, request_id, event), do: GenServer.cast(pid, {:event, request_id, event})

  def capture(pid, request_id, bytes, complete, truncated),
    do: GenServer.cast(pid, {:capture, request_id, bytes, complete, truncated})

  @impl true
  def init({owner, fixture_id, options}) do
    Process.flag(:trap_exit, true)
    owner_monitor = Process.monitor(owner)

    case Server.start_link(self(), Keyword.put(options, :fixture_id, fixture_id)) do
      {:ok, server} ->
        info = Server.info(server) |> Map.put(:fixture_id, fixture_id)

        {:ok,
         %{
           owner: owner,
           owner_monitor: owner_monitor,
           id: fixture_id,
           options: options,
           server: server,
           server_monitor: Process.monitor(server),
           info: info,
           phase: :open,
           ledger: Expectations.new(),
           journal: [],
           dropped: 0,
           monitors: %{},
           executors: %{},
           sessions: %{},
           session_routes: %{},
           session_outcomes: %{},
           awaiters: %{},
           verifiers: %{},
           closers: [],
           consume: false,
           cleanup: nil,
           finalizer: nil,
           final_timer: nil,
           report: nil
         }}

      {:error, reason} ->
        {:stop, {:server_startup, reason}}
    end
  end

  @impl true
  def handle_call({:fixture, id, _request}, _from, %{id: fixture_id} = state)
      when id != fixture_id,
      do: {:reply, {:fixture_unavailable, :identity_mismatch}, state}

  def handle_call({:fixture, _id, :info}, _from, state),
    do: {:reply, %{state.info | ready: state.phase == :open}, state}

  def handle_call({:fixture, _id, :requests}, _from, state) do
    journal = %{
      entries: Enum.reverse(state.journal),
      dropped: state.dropped,
      truncated: state.dropped > 0,
      cursor: state.ledger.cursor
    }

    {:reply, journal, state}
  end

  def handle_call(
        {:fixture, _id, {:register, method, path, handler, requirement}},
        _from,
        %{phase: :open} = state
      ) do
    case Expectations.register(state.ledger, method, path, handler, requirement) do
      {:ok, ledger} -> {:reply, :ok, %{state | ledger: ledger}}
      {:error, message} -> {:reply, {:error, message}, state}
    end
  end

  def handle_call({:fixture, _id, {:register, _, _, _, _}}, _from, state),
    do: {:reply, {:error, "fixture finalization has started"}, state}

  def handle_call({:fixture, _id, {:admit, executor, metadata}}, _from, %{phase: :open} = state) do
    {ledger, reservation} = Expectations.reserve(state.ledger, metadata.method, metadata.path)
    request_id = elem(reservation, 1)

    outcome =
      case reservation do
        {:ok, _, _} -> :pending
        {:error, _, reason} -> {:error, reason}
      end

    entry =
      Map.merge(metadata, %{
        id: request_id,
        outcome: outcome,
        events: [],
        events_dropped: 0,
        events_truncated: false
      })

    entry =
      if state.options[:capture_body] do
        Map.put(entry, :body, %{
          data: "",
          complete: false,
          truncated: false,
          limit: state.options[:capture_body]
        })
      else
        entry
      end

    state = %{state | ledger: ledger} |> append_entry(entry) |> notify_awaiters(entry)

    case reservation do
      {:ok, _, handler} ->
        monitor = Process.monitor(executor)

        state = %{
          state
          | monitors: Map.put(state.monitors, monitor, {:request, request_id}),
            executors: Map.put(state.executors, request_id, monitor)
        }

        {:reply, {:ok, request_id, handler, state.options[:capture_body]}, state}

      {:error, _, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:fixture, _id, {:admit, _, _}}, _from, state),
    do: {:reply, {:error, :sealed}, state}

  def handle_call({:fixture, _id, {:await, matcher, timeout}}, from, state) do
    case Enum.find(Enum.reverse(state.journal), &matches?(&1, matcher)) do
      nil ->
        token = make_ref()
        timer = Process.send_after(self(), {:await_timeout, token}, timeout)
        waiter = %{from: from, matcher: matcher, timer: timer}
        {:noreply, %{state | awaiters: Map.put(state.awaiters, token, waiter)}}

      entry ->
        {:reply, {:ok, entry}, state}
    end
  end

  def handle_call({:fixture, _id, {:verify, _timeout}}, _from, %{phase: :closed} = state),
    do: {:reply, state.report, state}

  def handle_call({:fixture, _id, {:verify, timeout}}, from, state) do
    snapshot = Expectations.snapshot(state.ledger)

    if Expectations.ordinary_pending(state.ledger, snapshot.cursor) == [] do
      {:reply, Expectations.report(state.ledger, snapshot), state}
    else
      token = make_ref()
      timer = Process.send_after(self(), {:verify_timeout, token}, timeout)
      verifier = %{from: from, snapshot: snapshot, timer: timer}
      {:noreply, %{state | verifiers: Map.put(state.verifiers, token, verifier)}}
    end
  end

  def handle_call({:fixture, _id, {:close, _timeout, consume}}, _from, %{phase: :closed} = state) do
    if consume, do: {:stop, :normal, state.report, state}, else: {:reply, state.report, state}
  end

  def handle_call({:fixture, _id, {:close, timeout, consume}}, from, state) do
    state = %{state | closers: [from | state.closers], consume: state.consume or consume}
    {:noreply, begin_finalization(state, timeout)}
  end

  def handle_call({:complete, _request_id, _outcome}, _from, %{phase: :closed} = state),
    do: {:reply, {:error, :closed}, state}

  def handle_call({:complete, request_id, outcome}, _from, state) do
    ledger = Expectations.complete(state.ledger, request_id, outcome)
    state = %{state | ledger: ledger} |> update_entry(request_id, &Map.put(&1, :outcome, outcome))

    state =
      if Map.has_key?(ledger.active, request_id),
        do: state,
        else: release_executor(state, request_id)

    state = state |> settle_verifiers() |> signal_drain()
    finish_reply(:ok, state)
  end

  def handle_call({:establish, request_id, session_pid}, _from, state) do
    cond do
      state.phase == :closed ->
        {:reply, {:error, :closed}, state}

      not is_pid(session_pid) ->
        {:reply, {:error, :invalid_session}, state}

      Map.has_key?(state.sessions, request_id) ->
        {:reply, {:error, :already_established}, state}

      true ->
        case Expectations.establish(state.ledger, request_id) do
          {:ok, ledger} ->
            monitor = Process.monitor(session_pid)
            route = state.ledger.active[request_id].route

            state = %{
              state
              | ledger: ledger,
                monitors: Map.put(state.monitors, monitor, {:session, request_id, session_pid}),
                session_routes: Map.put(state.session_routes, request_id, route),
                sessions: Map.put(state.sessions, request_id, session_pid)
            }

            if state.phase == :closing,
              do: send(session_pid, {:gaoxy_test_cancel, :fixture_close})

            state =
              if Map.has_key?(ledger.active, request_id),
                do: state,
                else: release_executor(state, request_id)

            state = state |> settle_verifiers() |> signal_drain()
            finish_reply(:ok, state)

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_cast({:event, request_id, event}, %{phase: phase} = state) when phase != :closed do
    state =
      case event do
        %{type: :websocket_established} ->
          %{state | session_outcomes: Map.put(state.session_outcomes, request_id, :pending)}

        %{type: :websocket_closed} ->
          %{state | session_outcomes: Map.put(state.session_outcomes, request_id, :completed)}

        %{type: :session_cancelled} ->
          %{state | session_outcomes: Map.put(state.session_outcomes, request_id, :cancelled)}

        %{type: :session_failure, kind: kind, reason: reason, stacktrace: stacktrace} ->
          route = Map.get(state.session_routes, request_id)

          failure = %{
            type: :callback,
            request_id: request_id,
            kind: kind,
            reason: reason,
            stacktrace: stacktrace
          }

          failure = if route, do: Map.put(failure, :route, route), else: failure
          ledger = Expectations.fail(state.ledger, failure)
          %{state | ledger: ledger}

        _ ->
          state
      end

    event = bounded_event(event)
    send(state.owner, {:gaoxy_test_event, state.id, request_id, event})

    state =
      update_entry(state, request_id, fn entry ->
        events = entry.events ++ [event]
        dropped = max(length(events) - 100, 0)

        %{
          entry
          | events: Enum.take(events, -100),
            events_dropped: entry.events_dropped + dropped,
            events_truncated:
              entry.events_truncated or dropped > 0 or Map.get(event, :truncated, false)
        }
      end)

    {:noreply, state}
  end

  def handle_cast({:capture, request_id, bytes, complete, truncated}, state) do
    state =
      update_entry(state, request_id, fn entry ->
        case Map.fetch(entry, :body) do
          {:ok, body} ->
            available = max(body.limit - byte_size(body.data), 0)
            keep = binary_part(bytes, 0, min(byte_size(bytes), available))

            body = %{
              body
              | data: body.data <> keep,
                complete: body.complete or complete,
                truncated: body.truncated or truncated or byte_size(bytes) > available
            }

            %{entry | body: body}

          :error ->
            entry
        end
      end)

    {:noreply, state}
  end

  def handle_cast(_message, state), do: {:noreply, state}

  @impl true
  def handle_info({:DOWN, monitor, :process, _pid, reason}, %{owner_monitor: monitor} = state) do
    state =
      if state.options[:mode] == :manual and state.phase == :open do
        %{
          state
          | ledger: Expectations.fail(state.ledger, %{type: :owner_abandoned, reason: reason})
        }
      else
        state
      end

    {:noreply, begin_finalization(state, state.options[:timeout])}
  end

  def handle_info({:DOWN, monitor, :process, _pid, reason}, %{server_monitor: monitor} = state) do
    if state.phase == :open do
      ledger = Expectations.fail(state.ledger, %{type: :server_lost, reason: reason})
      {:noreply, begin_finalization(%{state | ledger: ledger}, state.options[:timeout])}
    else
      {:noreply, state}
    end
  end

  def handle_info({:DOWN, monitor, :process, _pid, reason}, state) do
    case Map.pop(state.monitors, monitor) do
      {nil, _} ->
        if (state.finalizer && elem(state.finalizer, 1) == monitor) and is_nil(state.cleanup) do
          cleanup = {:error, {:finalizer_lost, reason}}
          finish_noreply(%{state | cleanup: cleanup})
        else
          {:noreply, state}
        end

      {{:request, request_id}, monitors} ->
        state = %{state | monitors: monitors, executors: Map.delete(state.executors, request_id)}
        request = Map.get(state.ledger.active, request_id)

        if request && request.upgraded && reason == :normal do
          {:noreply, state}
        else
          outcome =
            if request && request.persistent && state.phase == :closing,
              do: {:cancelled, reason},
              else: {:terminated, reason}

          state = %{state | ledger: Expectations.complete(state.ledger, request_id, outcome)}
          state = update_entry(state, request_id, &Map.put(&1, :outcome, outcome))
          finish_noreply(state |> settle_verifiers() |> signal_drain())
        end

      {{:session, request_id, _pid}, monitors} ->
        {outcome, outcomes} = Map.pop(state.session_outcomes, request_id)

        state = %{
          state
          | monitors: monitors,
            sessions: Map.delete(state.sessions, request_id),
            session_outcomes: outcomes
        }

        state =
          if (normal_session_exit?(reason) and outcome != :pending) or state.phase == :closed do
            state
          else
            %{
              state
              | ledger:
                  Expectations.fail(state.ledger, %{
                    type: :session_terminated,
                    request_id: request_id,
                    route: state.session_routes[request_id],
                    reason:
                      if(outcome == :pending,
                        do: {:session_outcome_unavailable, reason},
                        else: reason
                      )
                  })
            }
          end

        finish_noreply(state)
    end
  end

  def handle_info({:await_timeout, token}, state) do
    {waiter, awaiters} = Map.pop(state.awaiters, token)
    if waiter, do: GenServer.reply(waiter.from, {:error, :timeout})
    {:noreply, %{state | awaiters: awaiters}}
  end

  def handle_info({:verify_timeout, token}, state) do
    {verifier, verifiers} = Map.pop(state.verifiers, token)

    if verifier,
      do: GenServer.reply(verifier.from, Expectations.report(state.ledger, verifier.snapshot))

    {:noreply, %{state | verifiers: verifiers}}
  end

  def handle_info({:cleanup, token, result}, %{finalizer: {_pid, _monitor, token}} = state),
    do: finish_noreply(%{state | cleanup: result})

  def handle_info(
        {:final_deadline, token},
        %{finalizer: {pid, _monitor, token}, phase: :closing} = state
      ) do
    if is_nil(state.cleanup), do: Process.exit(pid, :kill)
    cleanup = state.cleanup || {:error, :cleanup_deadline_exceeded}
    finish_noreply(%{state | cleanup: cleanup}, true)
  end

  def handle_info(:expire, state), do: {:stop, :normal, state}
  def handle_info({:EXIT, _pid, _reason}, state), do: {:noreply, state}
  def handle_info(_message, state), do: {:noreply, state}

  defp begin_finalization(%{phase: phase} = state, _timeout) when phase != :open, do: state

  defp begin_finalization(state, timeout) do
    coordinator = self()
    deadline = now() + timeout
    token = make_ref()
    server = state.server
    cleanup_budget = min(250, max(div(timeout, 2), 1))

    {pid, monitor} =
      spawn_monitor(fn ->
        receive do
          {:drained, ^token} -> :ok
        after
          max(deadline - now() - cleanup_budget, 0) -> :ok
        end

        result =
          try do
            Server.close(server, max(deadline - now(), 0))
          catch
            kind, reason -> {:error, {kind, reason}}
          end

        send(coordinator, {:cleanup, token, result})
      end)

    for {_request_id, session_pid} <- state.sessions,
        do: send(session_pid, {:gaoxy_test_cancel, :fixture_close})

    timer = Process.send_after(self(), {:final_deadline, token}, timeout)

    %{state | phase: :closing, finalizer: {pid, monitor, token}, final_timer: timer}
    |> signal_drain()
  end

  defp signal_drain(%{phase: :closing, finalizer: {pid, _monitor, token}} = state) do
    if Expectations.ordinary_pending(state.ledger) == [], do: send(pid, {:drained, token})
    state
  end

  defp signal_drain(state), do: state

  defp finish_reply(reply, state) do
    case finish(state, false) do
      {:retain, state} -> {:reply, reply, state}
      {:stop, state} -> {:stop, :normal, reply, state}
    end
  end

  defp finish_noreply(state, deadline \\ false) do
    case finish(state, deadline) do
      {:retain, state} -> {:noreply, state}
      {:stop, state} -> {:stop, :normal, state}
    end
  end

  defp finish(%{phase: :closing, cleanup: cleanup} = state, deadline) when not is_nil(cleanup) do
    if deadline or (map_size(state.ledger.active) == 0 and map_size(state.sessions) == 0) do
      Process.cancel_timer(state.final_timer)
      report = Expectations.report(state.ledger)

      unresolved =
        for request_id <-
              Enum.sort(
                Enum.uniq(
                  Map.keys(state.sessions) ++
                    for({request_id, %{persistent: true}} <- state.ledger.active, do: request_id)
                )
              ),
            do: %{type: :session_cleanup_pending, request_id: request_id}

      report =
        if unresolved == [],
          do: report,
          else: %{report | status: :error, failures: report.failures ++ unresolved}

      report =
        if cleanup == :ok do
          report
        else
          %{
            report
            | status: :error,
              failures: report.failures ++ [%{type: :cleanup, reason: cleanup}]
          }
        end

      report = Map.merge(report, %{fixture_id: state.id, cleanup: cleanup})
      for from <- state.closers, do: GenServer.reply(from, report)

      for {_token, verifier} <- state.verifiers do
        Process.cancel_timer(verifier.timer)
        GenServer.reply(verifier.from, Expectations.report(state.ledger, verifier.snapshot))
      end

      for {_token, waiter} <- state.awaiters do
        Process.cancel_timer(waiter.timer)
        GenServer.reply(waiter.from, {:error, :timeout})
      end

      state = %{
        state
        | phase: :closed,
          report: report,
          closers: [],
          verifiers: %{},
          awaiters: %{}
      }

      if state.consume do
        {:stop, state}
      else
        Process.send_after(self(), :expire, state.options[:retention])
        {:retain, state}
      end
    else
      {:retain, state}
    end
  end

  defp finish(state, _deadline), do: {:retain, state}

  defp settle_verifiers(state) do
    verifiers =
      Enum.reduce(state.verifiers, %{}, fn {token, verifier}, remaining ->
        if Expectations.ordinary_pending(state.ledger, verifier.snapshot.cursor) == [] do
          Process.cancel_timer(verifier.timer)
          GenServer.reply(verifier.from, Expectations.report(state.ledger, verifier.snapshot))
          remaining
        else
          Map.put(remaining, token, verifier)
        end
      end)

    %{state | verifiers: verifiers}
  end

  defp release_executor(state, request_id) do
    case Map.pop(state.executors, request_id) do
      {nil, _} ->
        state

      {monitor, executors} ->
        Process.demonitor(monitor, [:flush])
        %{state | executors: executors, monitors: Map.delete(state.monitors, monitor)}
    end
  end

  defp append_entry(state, entry) do
    entries = [entry | state.journal]
    dropped = max(length(entries) - state.options[:journal_limit], 0)

    %{
      state
      | journal: Enum.take(entries, state.options[:journal_limit]),
        dropped: state.dropped + dropped
    }
  end

  defp update_entry(state, request_id, function),
    do: %{
      state
      | journal:
          Enum.map(state.journal, fn entry ->
            if entry.id == request_id, do: function.(entry), else: entry
          end)
    }

  defp notify_awaiters(state, entry) do
    awaiters =
      Enum.reduce(state.awaiters, %{}, fn {token, waiter}, remaining ->
        if matches?(entry, waiter.matcher) do
          Process.cancel_timer(waiter.timer)
          GenServer.reply(waiter.from, {:ok, entry})
          remaining
        else
          Map.put(remaining, token, waiter)
        end
      end)

    %{state | awaiters: awaiters}
  end

  defp matches?(entry, matcher),
    do: entry.id > matcher.after and entry.method == matcher.method and entry.path == matcher.path

  defp bounded_event(event) when is_map(event) do
    if :erlang.external_size(event) <= 4_096 do
      event
    else
      %{
        type: Map.get(event, :type, :observation),
        truncated: true,
        preview: inspect(event, limit: 10, printable_limit: 512)
      }
    end
  end

  defp bounded_event(event), do: bounded_event(%{type: :observation, data: event})

  defp safe_call(pid, message) do
    try do
      GenServer.call(pid, message)
    catch
      :exit, _ -> {:error, :unavailable}
    end
  end

  defp now, do: System.monotonic_time(:millisecond)

  defp normal_session_exit?(:normal), do: true
  defp normal_session_exit?(:shutdown), do: true
  defp normal_session_exit?({:shutdown, _reason}), do: true
  defp normal_session_exit?(_reason), do: false
end
