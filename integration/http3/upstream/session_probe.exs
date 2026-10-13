defmodule Gaoxy.SessionBoundaryDouble do
  # Scripted public Transport boundary, never native/network qualification.
  def put(script), do: Process.put(__MODULE__, %{script: script, calls: []})
  def calls, do: Process.get(__MODULE__).calls |> Enum.reverse()

  defp call(name, default, args \\ []) do
    state = Process.get(__MODULE__)

    {result, script} =
      case Map.get(state.script, name, []) do
        [result | rest] -> {result, Map.put(state.script, name, rest)}
        [] -> {default, state.script}
      end

    Process.put(__MODULE__, %{state | script: script, calls: [{name, args} | state.calls]})

    case result do
      {:barrier, observer, value} ->
        send(observer, {:public_call_entered, self()})

        receive do
          :release_public_call -> value
        after
          5_000 -> exit(:double_call_timeout)
        end

      value ->
        value
    end
  end

  def connect(_, _, opts), do: call(:connect, {:ok, :connection}, [opts[:ref]])
  def ready(_, _), do: call(:ready, :ready)
  def open_stream(_, kind, _), do: call(:open_stream, {:ok, kind})

  def send_stream(stream, bytes, fin, opts),
    do: call(:send_stream, :ok, [stream, bytes, fin, opts[:ref]])

  def operation_status(_, ref, kind),
    do: call(:operation_status, %{status: :admitted, result: :ok}, [ref, kind])

  def events(_, _, _), do: call(:events, {:ok, []})
  def read(stream, _, _), do: call(:read, {:ok, []}, [stream])
  def reset_stream(_, _, _), do: :ok
  def stop_stream(_, _, _), do: :ok
  def close(_, _, _, _), do: :ok
  def cleanup(_), do: :ok
  def abort(_, _), do: call(:abort, :ok)
end

defmodule Gaoxy.EndpointBoundaryDouble do
  use GenServer

  def client(opts) do
    if opts[:fixture_client], do: opts[:fixture_client].()
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts),
    do: {:ok, %{monitor: Process.monitor(opts[:acceptor]), owner: opts[:acceptor], options: opts}}

  def handle_info({:DOWN, ref, :process, owner, _}, %{monitor: ref, owner: owner} = state),
    do: {:stop, :normal, state}

  def terminate(_, state) do
    if state.options[:fixture_stop], do: state.options[:fixture_stop].()
    :ok
  end
end

defmodule Gaoxy.SessionCaller do
  @operations ~w(connect ready open request poll send_data send_fin send_trailers resume suspend_blocked cancel close abort boundary)a

  def start(guardian, request_id, generation) do
    :erlang.spawn_opt(
      fn ->
        monitor = Process.monitor(guardian)
        send(guardian, {:caller_ready, self()})
        loop(guardian, monitor, request_id, generation, 0, 0)
      end,
      [:link, :monitor]
    )
  end

  def guardian_lost?(guardian, monitor) do
    receive do
      {:DOWN, ^monitor, :process, ^guardian, _reason} -> true
    after
      0 -> false
    end
  end

  defp loop(guardian, monitor, id, generation, sequence, high_water) do
    if guardian_lost?(guardian, monitor), do: exit(:normal)
    {:message_queue_len, queued} = Process.info(self(), :message_queue_len)
    high_water = max(high_water, queued)
    drain(guardian, monitor, id, generation, 16)

    receive do
      {:DOWN, ^monitor, :process, ^guardian, _reason} ->
        :ok

      {:stop_caller, ^guardian, ^id, ^generation} ->
        :ok

      {:command, ^guardian, ^id, ^generation, ref, next, name, session, fun, deadline}
      when next == sequence + 1 and name in @operations ->
        if guardian_lost?(guardian, monitor), do: exit(:normal)
        drain(guardian, monitor, id, generation, 16)

        result =
          if System.monotonic_time(:millisecond) >= deadline do
            {:error, session, :deadline_expired}
          else
            fun.(session)
          end

        drain(guardian, monitor, id, generation, 16)
        if guardian_lost?(guardian, monitor), do: exit(:normal)

        result =
          if System.monotonic_time(:millisecond) >= deadline,
            do: {:error, session, :deadline_expired},
            else: result

        send(guardian, {:caller_result, self(), id, generation, ref, next, result, high_water})
        # The tail call retains only identities/counters, never Session or result.
        loop(guardian, monitor, id, generation, next, high_water)

      {:quic_closed, _handle, reason} ->
        relay_closed(guardian, monitor, id, generation, reason)
        loop(guardian, monitor, id, generation, sequence, high_water)

      {:caller_barrier, observer, ref} ->
        send(
          observer,
          {ref, %{pid: self(), high_water: high_water, queued: queued, sequence: sequence}}
        )

        loop(guardian, monitor, id, generation, sequence, high_water)

      _unknown ->
        loop(guardian, monitor, id, generation, sequence, high_water)
    end
  end

  defp drain(guardian, monitor, id, generation, remaining) do
    if guardian_lost?(guardian, monitor), do: exit(:normal)

    if remaining > 0 do
      receive do
        {:quic_ready, _handle, _metadata} ->
          drain(guardian, monitor, id, generation, remaining - 1)

        {:quic_closed, _handle, reason} ->
          relay_closed(guardian, monitor, id, generation, reason)
          drain(guardian, monitor, id, generation, remaining - 1)
      after
        0 -> :ok
      end
    else
      # Yield between finite batches; control gets processed by the main loop.
      :erlang.yield()
    end
  end

  defp relay_closed(guardian, monitor, id, generation, reason) do
    if guardian_lost?(guardian, monitor), do: exit(:normal)
    if :erlang.external_size(reason) > 65_536, do: exit(:closed_reason_too_large)
    send(guardian, {:caller_closed, self(), id, generation, reason})
  end
end

defmodule Gaoxy.SessionGuardian do
  import ExUnit.Assertions
  alias QuicHttp3.Transport.Quic, as: Transport
  alias Gaoxy.SessionCaller, as: Caller

  def start(opts, owner) do
    parent = self()

    spawn_monitor(fn ->
      Process.flag(:trap_exit, true)

      now = System.monotonic_time(:millisecond)
      total = opts[:total_deadline] || now + opts[:timeout]
      opening = opts[:opening_deadline] || total
      Process.send_after(self(), :lifetime_deadline, max(min(total, opening) - now, 0))

      loop(%{
        total_deadline: total,
        opening_deadline: opening,
        opening_complete: false,
        cleanup_deadline: nil,
        bootstrap_reply: nil,
        parent: parent,
        owner: owner,
        owner_monitor: Process.monitor(owner),
        opts: opts,
        endpoint: nil,
        endpoint_monitor: nil,
        bootstrap: nil,
        caller: nil,
        operation: nil,
        request_id: make_ref(),
        generation: make_ref(),
        sequence: 0,
        session: nil,
        tasks: [],
        terminal: false,
        caller_high_water: 0,
        public_closed: nil,
        caller_down: nil,
        endpoint_down: nil,
        bootstrap_down: nil
      })
    end)
  end

  def creator(guardian, opts, tag) do
    monitor = Process.monitor(guardian)
    if Caller.guardian_lost?(guardian, monitor), do: exit(:normal)
    result = Transport.client(Keyword.put(opts, :acceptor, guardian))

    case result do
      {:ok, endpoint} ->
        if opts[:fixture_before_adopt], do: opts[:fixture_before_adopt].()

        if Caller.guardian_lost?(guardian, monitor) do
          Transport.stop_endpoint(endpoint)
        else
          send(guardian, {:adopt, self(), endpoint})

          receive do
            {:adopted, ^guardian} ->
              Process.unlink(endpoint.pid)
              if opts[:fixture_after_ack], do: opts[:fixture_after_ack].()

              if Caller.guardian_lost?(guardian, monitor) do
                Transport.stop_endpoint(endpoint)
              else
                send(guardian, {:bootstrap_result, self(), tag, result})
              end

            {:adopted_for_teardown, ^guardian} ->
              Process.unlink(endpoint.pid)

            {:DOWN, ^monitor, :process, ^guardian, _reason} ->
              Transport.stop_endpoint(endpoint)
          after
            5_000 ->
              Transport.stop_endpoint(endpoint)
              exit(:adoption_timeout)
          end
        end

      _ ->
        unless Caller.guardian_lost?(guardian, monitor),
          do: send(guardian, {:bootstrap_result, self(), tag, result})
    end
  end

  def stop_task(guardian, endpoint, observer, stop \\ &Transport.stop_endpoint/1) do
    :erlang.spawn_opt(
      fn ->
        monitor = Process.monitor(guardian)
        result = stop.(endpoint)

        if Caller.guardian_lost?(guardian, monitor) do
          if observer, do: send(observer, {:orphan_stop_attempt, self(), result})
        else
          send(guardian, {:stopped, self(), result})
        end
      end,
      [:link, :monitor]
    )
  end

  defp loop(state) do
    receive do
      :lifetime_deadline ->
        if remaining(applicable_deadline(state)) == 0 do
          fail_operation(state)
          teardown(%{state | terminal: true}, state.parent, :deadline_cleanup, true)
        else
          Process.send_after(self(), :lifetime_deadline, remaining(applicable_deadline(state)))
          loop(state)
        end

      {:bootstrap, observer, ref} when state.bootstrap == nil and not state.terminal ->
        guardian = self()
        opts = state.opts
        tag = {observer, ref}
        task = :erlang.spawn_opt(fn -> creator(guardian, opts, tag) end, [:link, :monitor])
        loop(%{state | bootstrap: task})

      {:adopt, creator, endpoint} ->
        assert elem(state.bootstrap, 0) == creator
        assert state.endpoint == nil
        monitor = Process.monitor(endpoint.pid)
        Process.link(endpoint.pid)
        state = %{state | endpoint: endpoint, endpoint_monitor: monitor}

        if remaining(applicable_deadline(state)) == 0 do
          send(creator, {:adopted_for_teardown, self()})
          teardown(%{state | terminal: true}, state.parent, :deadline_cleanup, true)
        else
          send(creator, {:adopted, self()})
          loop(state)
        end

      {:bootstrap_result, creator, tag, result} ->
        assert elem(state.bootstrap, 0) == creator
        bootstrap_ready(%{state | bootstrap_reply: {tag, result}})

      {:set_session, session} ->
        loop(%{state | session: session})

      {call_kind, observer, ref, name, fun, deadline}
      when call_kind in [:call, :call_traced] and state.operation == nil and not state.terminal ->
        deadline = min(deadline, applicable_deadline(state))

        if remaining(deadline) == 0 do
          reply_result(
            state,
            observer,
            ref,
            {:error, state.session, :deadline_expired},
            call_kind == :call_traced
          )

          teardown(%{state | terminal: true}, state.parent, :deadline_cleanup, true)
        else
          state = ensure_caller(state)
          {caller, _monitor} = state.caller
          sequence = state.sequence + 1
          command_ref = make_ref()

          if state.opts[:fixture_command_observer],
            do: send(state.opts[:fixture_command_observer], {:command_deadline, name, deadline})

          send(
            caller,
            {:command, self(), state.request_id, state.generation, command_ref, sequence,
             String.to_existing_atom(name), state.session, fun, deadline}
          )

          timer =
            Process.send_after(
              self(),
              {:operation_deadline, command_ref},
              max(deadline - System.monotonic_time(:millisecond), 0)
            )

          loop(%{
            state
            | sequence: sequence,
              operation: %{
                observer: observer,
                ref: ref,
                timer: timer,
                command_ref: command_ref,
                sequence: sequence,
                kind: name,
                traced: call_kind == :call_traced,
                deadline: deadline
              }
          })
        end

      {:caller_closed, caller, id, generation, reason}
      when id == state.request_id and generation == state.generation ->
        case state.caller do
          {^caller, _} -> loop(%{state | public_closed: state.public_closed || reason})
          _ -> loop(state)
        end

      {:caller_result, caller, id, generation, command_ref, sequence, result, high_water}
      when id == state.request_id and generation == state.generation ->
        assert elem(state.caller, 0) == caller

        case state.operation do
          %{command_ref: ^command_ref, sequence: ^sequence} ->
            if state.opts[:fixture_result_check], do: state.opts[:fixture_result_check].()
            Process.cancel_timer(state.operation.timer)

            if remaining(min(state.operation.deadline, applicable_deadline(state))) == 0 or
                 match?({:error, _, :deadline_expired}, result) do
              reply_operation(state, {:error, state.session, :deadline_expired})
              teardown(%{state | terminal: true}, state.parent, :deadline_cleanup, true)
            else
              advanced = advanced(result, state.session)

              next = %{
                state
                | session: advanced,
                  opening_complete: state.opening_complete or final_head?(result),
                  caller_high_water: max(state.caller_high_water, high_water)
              }

              reply_operation(next, result)
              loop(%{next | operation: nil})
            end

          _stale ->
            loop(state)
        end

      {:operation_deadline, command_ref} ->
        case state.operation do
          %{command_ref: ^command_ref} ->
            reply_operation(state, {:error, state.session, :deadline_expired})
            teardown(%{state | terminal: true}, state.parent, :deadline_cleanup, true)

          _stale ->
            loop(state)
        end

      {:leave_normal, observer, ref} ->
        send(
          observer,
          {ref, %{caller: state.caller, endpoint: state.endpoint, bootstrap: state.bootstrap}}
        )

        :ok

      {:identity, observer, ref} ->
        caller = if state.caller, do: elem(state.caller, 0)

        send(
          observer,
          {ref,
           %{
             guardian: inspect(self()),
             caller: inspect(caller),
             bootstrap_tasks: Enum.reverse(state.tasks),
             high_water: state.caller_high_water,
             caller_alive: is_pid(caller) and Process.alive?(caller),
             public_closed: state.public_closed,
             caller_pid: caller,
             request_id: state.request_id,
             generation: state.generation,
             sequence: state.sequence,
             endpoint: state.endpoint
           }}
        )

        loop(state)

      {:cleanup, observer, ref, cancelled, deadline} ->
        teardown(
          %{
            state
            | terminal: true,
              cleanup_deadline: min(deadline, state.total_deadline + 1_000)
          },
          observer,
          ref,
          cancelled
        )

      {:cleanup, observer, ref, cancelled} ->
        teardown(%{state | terminal: true}, observer, ref, cancelled)

      {:DOWN, monitor, :process, owner, reason}
      when monitor == state.owner_monitor and owner == state.owner ->
        send(state.parent, {:owner_loss_observed, reason})
        teardown(%{state | terminal: true}, state.parent, :owner_cleanup, true)

      {:DOWN, monitor, :process, pid, reason} ->
        cond do
          state.caller == {pid, monitor} ->
            send(state.parent, {:caller_failure, pid, reason})

            teardown(
              %{state | caller_down: reason, terminal: true},
              state.parent,
              :caller_failure_cleanup,
              true
            )

          state.bootstrap == {pid, monitor} ->
            if reason == :normal do
              bootstrap_ready(%{state | bootstrap_down: reason})
            else
              send(state.parent, {:bootstrap_failure, reason})

              teardown(
                %{state | bootstrap_down: reason, terminal: true},
                state.parent,
                :bootstrap_failure_cleanup,
                true
              )
            end

          state.endpoint != nil and state.endpoint_monitor == monitor and
              state.endpoint.pid == pid ->
            teardown(
              %{state | endpoint_down: reason, terminal: true},
              state.parent,
              :endpoint_failure_cleanup,
              true
            )

          true ->
            loop(state)
        end

      {:EXIT, _, :normal} ->
        loop(state)

      {:EXIT, _, _reason} ->
        loop(state)

      _stale ->
        loop(state)
    end
  end

  def remaining(deadline), do: max(deadline - System.monotonic_time(:millisecond), 0)

  defp applicable_deadline(state),
    do:
      if(state.opening_complete,
        do: state.total_deadline,
        else: min(state.total_deadline, state.opening_deadline)
      )

  defp final_head?({:ok, _, events}) when is_list(events),
    do:
      Enum.any?(events, fn
        {:headers, _, [{":status", status} | _]} -> status >= "200"
        _ -> false
      end)

  defp final_head?(_), do: false

  defp fail_operation(%{operation: nil}), do: :ok

  defp fail_operation(state),
    do: reply_operation(state, {:error, state.session, :deadline_expired})

  defp reply_operation(state, result) do
    reply_result(
      state,
      state.operation.observer,
      state.operation.ref,
      result,
      state.operation.traced
    )
  end

  defp reply_result(state, observer, ref, result, traced) do
    reply =
      if traced do
        caller = if state.caller, do: elem(state.caller, 0)

        {:traced_result, result,
         %{
           caller: inspect(caller),
           caller_alive: is_pid(caller) and Process.alive?(caller),
           public_closed: state.public_closed,
           high_water: state.caller_high_water
         }}
      else
        result
      end

    send(observer, {ref, reply})
  end

  defp bootstrap_ready(
         %{bootstrap_reply: {{observer, ref}, result}, bootstrap_down: :normal} = state
       ) do
    if remaining(applicable_deadline(state)) == 0 do
      teardown(%{state | terminal: true}, state.parent, :deadline_cleanup, true)
    else
      {creator, _} = state.bootstrap
      send(observer, {ref, result})

      loop(%{
        state
        | bootstrap: nil,
          bootstrap_reply: nil,
          bootstrap_down: nil,
          tasks: [%{pid: inspect(creator), kind: :bootstrap, down: ":normal"} | state.tasks]
      })
    end
  end

  defp bootstrap_ready(state), do: loop(state)

  defp ensure_caller(%{caller: nil, bootstrap: nil, endpoint: endpoint} = state)
       when not is_nil(endpoint) do
    assert Process.alive?(endpoint.pid)
    caller = Caller.start(self(), state.request_id, state.generation)
    {pid, _monitor} = caller

    receive do
      {:caller_ready, ^pid} -> :ok
    after
      min(1_000, remaining(applicable_deadline(state))) ->
        flunk("stable caller readiness missing")
    end

    %{state | caller: caller}
  end

  defp ensure_caller(state), do: state

  defp finish_session(
         %{operation: nil, caller_down: nil, caller: {caller, _}, session: session} = state,
         cancelled
       )
       when not is_nil(session) do
    command_ref = make_ref()
    sequence = state.sequence + 1
    name = if cancelled, do: :abort, else: :close
    fun = if cancelled, do: &QuicHttp3.Session.abort/1, else: &QuicHttp3.Session.close/1

    send(
      caller,
      {:command, self(), state.request_id, state.generation, command_ref, sequence, name, session,
       fun, state.cleanup_deadline}
    )

    %{
      state
      | sequence: sequence,
        cleanup_command: {command_ref, sequence},
        session_result: :cleanup_call_pending
    }
  end

  defp finish_session(state, _),
    do: %{state | cleanup_command: nil, session_result: :not_safe_while_operation_pending}

  defp teardown(state, observer, ref, cancelled) do
    # The original Service grace is capped at total + 1000; no stage restarts it.
    deadline =
      state.cleanup_deadline ||
        min(
          state.opts[:cleanup_deadline] ||
            System.monotonic_time(:millisecond) + 1_000,
          state.total_deadline + 1_000
        )

    state =
      Map.merge(state, %{
        cleanup_deadline: deadline,
        stopper: nil,
        stop_trigger: nil,
        stop_result: nil,
        stopper_down: nil,
        cleanup_command: nil,
        session_result: nil,
        caller_stop_sent: false,
        bootstrap_was_started: state.bootstrap != nil or state.tasks != [],
        observer: observer,
        cleanup_ref: ref
      })

    state = finish_session(state, cancelled)
    state = if state.cleanup_command == nil, do: begin_stop(state), else: state

    if state.stopper == nil,
      do: Process.send_after(self(), :cleanup_stop_due, min(100, remaining(deadline)))

    collect_cleanup(state)
  end

  defp begin_stop(state, trigger \\ :immediate)

  defp begin_stop(%{stopper: nil, endpoint: endpoint} = state, trigger)
       when not is_nil(endpoint) do
    stop = state.opts[:fixture_public_stop] || (&Transport.stop_endpoint/1)
    observer = if state.opts[:fixture_stop_observer], do: state.parent
    task = stop_task(self(), endpoint, observer, stop)
    if observer, do: send(observer, {:owned_stop_started, elem(task, 0)})
    %{state | stopper: task, stop_trigger: trigger}
  end

  defp begin_stop(state, _trigger), do: state

  defp collect_cleanup(state) do
    state = retire_caller(state)

    all_down =
      (state.bootstrap == nil or state.bootstrap_down != nil) and
        (state.caller == nil or state.caller_down != nil) and
        (state.stopper == nil or state.stopper_down != nil)

    proof =
      state.endpoint != nil and state.stop_result == :ok and
        state.endpoint_down == :normal and state.stopper_down == :normal

    no_allocation = not state.bootstrap_was_started and state.endpoint == nil

    if remaining(state.cleanup_deadline) == 0 or (all_down and (proof or no_allocation)) do
      cleanup_receipt(
        state,
        all_down and (proof or no_allocation) and
          remaining(state.cleanup_deadline) > 0
      )
    else
      receive do
        :cleanup_stop_due ->
          collect_cleanup(begin_stop(state, :fallback))

        {:adopt, creator, endpoint} when state.endpoint == nil ->
          assert elem(state.bootstrap, 0) == creator
          monitor = Process.monitor(endpoint.pid)
          Process.link(endpoint.pid)
          # Terminal adoption is solely for teardown and can never start a caller.
          send(creator, {:adopted_for_teardown, self()})

          collect_cleanup(
            begin_stop(%{
              state
              | endpoint: endpoint,
                endpoint_monitor: monitor
            })
          )

        {:caller_result, caller, id, generation, command_ref, sequence, result, high_water}
        when id == state.request_id and generation == state.generation ->
          if state.caller != nil and elem(state.caller, 0) == caller and
               state.cleanup_command == {command_ref, sequence} do
            result =
              if remaining(state.cleanup_deadline) > 0,
                do: result,
                else: {:error, state.session, :deadline_expired}

            state = %{
              state
              | session_result: result,
                cleanup_command: nil,
                caller_high_water: max(high_water, state.caller_high_water)
            }

            collect_cleanup(begin_stop(state, :session_result))
          else
            # Late request results never advance Session, ACK, or restart work.
            collect_cleanup(state)
          end

        {:stopped, pid, result} when state.stopper != nil ->
          assert elem(state.stopper, 0) == pid
          collect_cleanup(%{state | stop_result: result})

        {:DOWN, monitor, :process, pid, reason} ->
          state =
            cond do
              state.endpoint != nil and state.endpoint.pid == pid and
                  state.endpoint_monitor == monitor ->
                %{state | endpoint_down: reason}

              state.caller == {pid, monitor} ->
                begin_stop(%{state | caller_down: reason}, :caller_down)

              state.bootstrap == {pid, monitor} ->
                %{state | bootstrap_down: reason}

              state.stopper == {pid, monitor} ->
                %{state | stopper_down: reason}

              true ->
                state
            end

          collect_cleanup(state)

        _late_or_control ->
          collect_cleanup(state)
      after
        remaining(state.cleanup_deadline) -> cleanup_receipt(state, false)
      end
    end
  end

  defp retire_caller(
         %{caller: {pid, _}, caller_down: nil, endpoint_down: down, caller_stop_sent: false} =
           state
       )
       when not is_nil(down) do
    send(pid, {:stop_caller, self(), state.request_id, state.generation})
    # Only an owned caller blocked in an outstanding call needs forced termination.
    if state.operation != nil or state.cleanup_command != nil, do: Process.exit(pid, :kill)
    %{state | caller_stop_sent: true}
  end

  defp retire_caller(state), do: state

  defp cleanup_receipt(state, confirmed) do
    tasks =
      Enum.reverse(state.tasks) ++
        task_receipt(state.bootstrap, :bootstrap, state.bootstrap_down) ++
        task_receipt(state.caller, :stable_caller, state.caller_down)

    rebound =
      case :gen_udp.open(state.opts[:port], [:binary, ip: {127, 0, 0, 1}, active: false]) do
        {:ok, socket} ->
          :gen_udp.close(socket)
          state.opts[:port]

        {:error, _} ->
          nil
      end

    send(
      state.observer,
      {state.cleanup_ref,
       %{
         cleanup_outcome: if(confirmed, do: "confirmed", else: "cleanup_unconfirmed"),
         service_completion: "NOT CLAIMED: harness lifecycle only",
         cleanup_deadline: state.cleanup_deadline,
         observed_at: System.monotonic_time(:millisecond),
         session_result: inspect(state.session_result),
         endpoint_stop: inspect(state.stop_result),
         stop_trigger: inspect(state.stop_trigger),
         endpoint_down: inspect(state.endpoint_down),
         stop_task_down: inspect(state.stopper_down),
         tasks: tasks,
         bind_address: "127.0.0.1",
         bind_port: state.opts[:port],
         rebound_port: rebound,
         caller_high_water: state.caller_high_water
       }}
    )

    :ok
  end

  defp task_receipt(nil, _, _), do: []

  defp task_receipt({pid, _}, kind, down),
    do: [
      %{
        pid: inspect(pid),
        kind: kind,
        down: if(down == nil, do: "NOT OBSERVED", else: inspect(down))
      }
    ]

  def advanced({:ok, session}, _) when is_struct(session, QuicHttp3.Session), do: session
  def advanced({tag, session, _}, _) when tag in [:ok, :error, :blocked, :unknown], do: session
  def advanced(_, previous), do: previous

  def await_down(pid, monitor) do
    receive do
      {:DOWN, ^monitor, :process, ^pid, reason} -> reason
    after
      6_000 -> flunk("owned process DOWN missing #{inspect(pid)}")
    end
  end
end

defmodule Gaoxy.SessionAffinityDoubles do
  import ExUnit.Assertions
  alias Gaoxy.{SessionCaller, SessionGuardian}
  alias QuicHttp3.{Session, Transport.Quic}

  defp fixture do
    observer = self()
    {_uri, options} = Gaoxy.SessionPublicProbe.options("a")

    {guardian, guardian_monitor} =
      spawn_monitor(fn ->
        Process.flag(:trap_exit, true)

        assert {:ok, endpoint} =
                 Quic.client(
                   Keyword.merge(options, acceptor: self(), ops: Gaoxy.EndpointBoundaryDouble)
                 )

        id = make_ref()
        generation = make_ref()
        {caller, _} = SessionCaller.start(self(), id, generation)

        receive do
          {:caller_ready, ^caller} -> :ok
        after
          1_000 -> flunk("double caller missing")
        end

        send(observer, {:affinity_fixture, self(), caller, endpoint, id, generation})
        fixture_loop(observer, caller)
      end)

    receive do
      {:affinity_fixture, ^guardian, caller, endpoint, id, generation} ->
        %{
          guardian: guardian,
          guardian_monitor: guardian_monitor,
          caller: caller,
          caller_monitor: Process.monitor(caller),
          endpoint: endpoint,
          endpoint_monitor: Process.monitor(endpoint.pid),
          id: id,
          generation: generation,
          sequence: 0
        }
    after
      2_000 -> flunk("affinity fixture missing")
    end
  end

  defp fixture_loop(observer, caller) do
    receive do
      {:forward, command} ->
        send(caller, command)
        fixture_loop(observer, caller)

      {:caller_result, ^caller, _, _, _, _, _, _} = result ->
        send(observer, {:fixture_result, result})
        fixture_loop(observer, caller)

      :leave_normal ->
        :ok

      _other ->
        fixture_loop(observer, caller)
    end
  end

  defp dispatch(h, session, fun, name \\ :boundary, deadline \\ nil) do
    ref = make_ref()
    next = h.sequence + 1
    deadline = deadline || System.monotonic_time(:millisecond) + 2_000
    command = {:command, h.guardian, h.id, h.generation, ref, next, name, session, fun, deadline}
    send(h.guardian, {:forward, command})

    receive do
      {:fixture_result, {:caller_result, caller, id, generation, ^ref, ^next, result, high_water}}
      when caller == h.caller and id == h.id and generation == h.generation ->
        {result, %{h | sequence: next}, high_water}
    after
      3_000 -> flunk("affinity result missing")
    end
  end

  defp loss(h) do
    send(h.guardian, :leave_normal)
    assert SessionGuardian.await_down(h.guardian, h.guardian_monitor) == :normal
    assert SessionGuardian.await_down(h.endpoint.pid, h.endpoint_monitor) == :normal
    assert SessionGuardian.await_down(h.caller, h.caller_monitor) == :normal
  end

  defp record(name, fields) do
    Gaoxy.SessionPublicProbe.emit(
      "double_receipt",
      Map.merge(
        fields,
        %{name: name, service_completion: "NOT CLAIMED", kind: "boundary_double"}
      )
    )

    Gaoxy.SessionPublicProbe.check(name, "boundary_double")
  end

  def run do
    for phase <- [:before_connect, :after_connect, :paused_ack] do
      h = fixture()
      {:ok, session} = Session.new(transport: Gaoxy.SessionBoundaryDouble)

      h =
        if phase != :before_connect do
          {{:ok, _session}, h, _} =
            dispatch(
              h,
              session,
              fn s ->
                Gaoxy.SessionBoundaryDouble.put(%{})
                Session.connect(s, "localhost", 443, consumer: self())
              end,
              :connect
            )

          h
        else
          h
        end

      # An unrelated DOWN must not be mistaken for the guardian's exact monitor.
      send(h.caller, {:DOWN, make_ref(), :process, h.guardian, :normal})
      barrier_ref = make_ref()
      send(h.caller, {:caller_barrier, self(), barrier_ref})

      receive do
        {^barrier_ref, state} -> assert state.pid == h.caller
      after
        1_000 -> flunk("idle caller barrier missing")
      end

      assert Process.alive?(h.caller)
      loss(h)

      record("guardian_normal_#{phase}", %{
        caller: inspect(h.caller),
        endpoint_down: ":normal",
        caller_down: ":normal",
        unrelated_down: "ignored"
      })
    end

    h = fixture()
    observer = self()
    {:ok, session} = Session.new(transport: Gaoxy.SessionBoundaryDouble)

    {{:ok, connected}, h, _} =
      dispatch(
        h,
        session,
        fn s ->
          Gaoxy.SessionBoundaryDouble.put(%{})
          Session.connect(s, "localhost", 443, consumer: self())
        end,
        :connect
      )

    ref = make_ref()

    send(
      h.guardian,
      {:forward,
       {:command, h.guardian, h.id, h.generation, ref, h.sequence + 1, :ready, connected,
        fn s ->
          Gaoxy.SessionBoundaryDouble.put(%{ready: [{:barrier, observer, :ready}]})
          Session.ready(s)
        end, System.monotonic_time(:millisecond) + 2_000}}
    )

    receive do
      {:public_call_entered, pid} -> assert pid == h.caller
    after
      1_000 -> flunk("blocking public boundary missing")
    end

    send(h.guardian, :leave_normal)
    assert SessionGuardian.await_down(h.guardian, h.guardian_monitor) == :normal
    assert SessionGuardian.await_down(h.endpoint.pid, h.endpoint_monitor) == :normal
    assert Process.alive?(h.caller)
    send(h.caller, :release_public_call)
    assert SessionGuardian.await_down(h.caller, h.caller_monitor) == :normal

    record("guardian_loss_blocked_call", %{
      caller_down_after_barrier_release: ":normal",
      endpoint_down_before_release: ":normal",
      immediate_caller_down: "NOT CLAIMED"
    })

    h = fixture()
    ref = make_ref()

    bad =
      {:command, h.guardian, h.id, make_ref(), ref, 1, :boundary, nil,
       fn _ ->
         send(observer, :forbidden_admission)
         :ok
       end, System.monotonic_time(:millisecond) + 1_000}

    send(h.guardian, {:forward, bad})

    {:ok, h, _} =
      dispatch(h, nil, fn _ ->
        send(observer, :admitted_once)
        :ok
      end)

    assert_receive :admitted_once, 1_000
    # Duplicate accepted command sequence is stale even with a fresh command ref.
    send(h.guardian, {:forward, put_elem(put_elem(bad, 3, h.generation), 4, make_ref())})
    {:ok, h, _} = dispatch(h, nil, fn _ -> :ok end)
    refute_receive :forbidden_admission, 0
    loss(h)
    record("caller_stale_generation_sequence", %{admissions: 1, forbidden_admissions: 0})

    h = fixture()
    {:ok, session} = Session.new(transport: Gaoxy.SessionBoundaryDouble)
    operation_ref = make_ref()

    {{:unknown, advanced, ^operation_ref}, h, _} =
      dispatch(
        h,
        session,
        fn s ->
          Gaoxy.SessionBoundaryDouble.put(%{
            connect: [{:unknown, :connection, operation_ref}],
            operation_status: [
              :unknown,
              :unknown,
              :unknown,
              %{status: :admitted, result: {:ok, :connection}}
            ]
          })

          Session.connect(s, "localhost", 443, consumer: self())
        end,
        :connect
      )

    {connected, h} =
      Enum.reduce(1..4, {advanced, h}, fn index, {session, h} ->
        {result, h, high_water} =
          dispatch(
            h,
            session,
            fn s ->
              send(
                self(),
                {:quic_ready, :opaque_double_handle, %{payload: :binary.copy("x", 65_536)}}
              )

              Session.resume(s)
            end,
            :resume
          )

        assert high_water <= 16

        case {index, result} do
          {4, {:ok, session}} -> {session, h}
          {_, {:unknown, session, ^operation_ref}} -> {session, h}
        end
      end)

    {h, peaks} =
      Enum.reduce(1..128, {h, []}, fn _, {h, peaks} ->
        {{:ok, _, []}, h, peak} =
          dispatch(
            h,
            connected,
            fn s ->
              send(
                self(),
                {:quic_ready, :opaque_double_handle, %{payload: :binary.copy("y", 262_144)}}
              )

              send(self(), {:quic_closed, :opaque_double_handle, :hint_only})
              Session.poll(s, 16, paused: MapSet.new())
            end,
            :poll
          )

        {h, [peak | peaks]}
      end)

    {calls, h, _} = dispatch(h, nil, fn _ -> Gaoxy.SessionBoundaryDouble.calls() end)
    assert Enum.count(calls, &(elem(&1, 0) == :connect)) == 1
    assert Enum.count(calls, &(elem(&1, 0) == :operation_status)) == 4
    assert Enum.max(peaks) <= 16
    barrier_ref = make_ref()
    send(h.caller, {:caller_barrier, self(), barrier_ref})

    receive do
      {^barrier_ref, state} -> assert state.queued <= 1
    after
      1_000 -> flunk("mailbox barrier missing")
    end

    loss(h)

    record("caller_reconcile_read_hint_bound", %{
      connect_calls: 1,
      reconciliations: 4,
      reads: 128,
      payload_bytes_per_hint: 262_144,
      supported_mailbox_high_water: Enum.max(peaks),
      boundary: "synthetic supported hints; native bound measured separately"
    })

    h = fixture()

    {{:done, :consumption_pending}, h, _} =
      dispatch(h, nil, fn _ -> {:done, :consumption_pending} end)

    assert Process.alive?(h.caller)
    assert Process.alive?(h.endpoint.pid)
    loss(h)
    record("caller_survives_done_pending_consumption", %{caller_alive_before_cleanup: true})

    # Exercise the actual guardian's stale-result and original deadline handling.
    {_uri, options} = Gaoxy.SessionPublicProbe.options("a")
    options = Keyword.put(options, :ops, Gaoxy.EndpointBoundaryDouble)
    {guardian, monitor} = SessionGuardian.start(options, self())
    assert {:ok, _} = Gaoxy.SessionPublicProbe.rpc(guardian, {:bootstrap})

    assert :ok =
             Gaoxy.SessionPublicProbe.rpc(
               guardian,
               {:call, "boundary", fn _ -> :ok end, System.monotonic_time(:millisecond) + 1_000}
             )

    identity = Gaoxy.SessionPublicProbe.rpc(guardian, {:identity})

    send(
      guardian,
      {:caller_result, identity.caller_pid, identity.request_id, identity.generation, make_ref(),
       identity.sequence, :forged_late_success, 0}
    )

    assert :ok =
             Gaoxy.SessionPublicProbe.rpc(
               guardian,
               {:call, "boundary", fn _ -> :ok end, System.monotonic_time(:millisecond) + 1_000}
             )

    send(guardian, {:caller_closed, identity.caller_pid, identity.request_id, make_ref(), :stale})
    send(guardian, {:caller_closed, self(), identity.request_id, identity.generation, :forged})
    closed_reason = {:tls_alert, :unknown_ca, :path_validation_failed}

    assert {:traced_result, {:error, :closed}, %{public_closed: ^closed_reason}} =
             Gaoxy.SessionPublicProbe.rpc(
               guardian,
               {:call_traced, "boundary",
                fn _ ->
                  send(self(), {:quic_closed, :opaque_double_handle, closed_reason})
                  {:error, :closed}
                end, System.monotonic_time(:millisecond) + 1_000}
             )

    assert {:traced_result, :ok, %{public_closed: ^closed_reason}} =
             Gaoxy.SessionPublicProbe.rpc(
               guardian,
               {:call_traced, "boundary",
                fn _ ->
                  send(self(), {:quic_closed, :opaque_double_handle, :later_reason})
                  :ok
                end, System.monotonic_time(:millisecond) + 1_000}
             )

    receipt = Gaoxy.SessionPublicProbe.rpc(guardian, {:cleanup, true}, 15_000)
    assert SessionGuardian.await_down(guardian, monitor) == :normal
    assert receipt.endpoint_down == ":normal"

    {idle_guardian, idle_monitor} = SessionGuardian.start(options, self())
    assert {:ok, _} = Gaoxy.SessionPublicProbe.rpc(idle_guardian, {:bootstrap})

    assert :ok =
             Gaoxy.SessionPublicProbe.rpc(
               idle_guardian,
               {:call, "boundary", fn _ -> :ok end, System.monotonic_time(:millisecond) + 1_000}
             )

    idle_identity = Gaoxy.SessionPublicProbe.rpc(idle_guardian, {:identity})
    idle_ref = make_ref()
    send(idle_identity.caller_pid, {:quic_closed, :opaque_double_handle, closed_reason})
    send(idle_identity.caller_pid, {:caller_barrier, self(), idle_ref})
    assert_receive {^idle_ref, _}, 1_000

    assert {:traced_result, :ok, %{public_closed: ^closed_reason}} =
             Gaoxy.SessionPublicProbe.rpc(
               idle_guardian,
               {:call_traced, "boundary", fn _ -> :ok end,
                System.monotonic_time(:millisecond) + 1_000}
             )

    idle_receipt = Gaoxy.SessionPublicProbe.rpc(idle_guardian, {:cleanup, true}, 15_000)
    assert SessionGuardian.await_down(idle_guardian, idle_monitor) == :normal
    assert idle_receipt.endpoint_down == ":normal"

    record("guardian_duplicate_result_rejected", %{
      state_transitions: 2,
      post_call_closed_before_result: true,
      idle_closed_observed: true,
      stale_closed_rejected: true,
      first_reason_retained: true
    })

    {guardian, monitor} = SessionGuardian.start(options, self())
    assert {:ok, endpoint} = Gaoxy.SessionPublicProbe.rpc(guardian, {:bootstrap})
    endpoint_monitor = Process.monitor(endpoint.pid)
    result_ref = make_ref()
    deadline = System.monotonic_time(:millisecond) + 150

    send(
      guardian,
      {:call, self(), result_ref, "boundary",
       fn _ ->
         send(observer, {:deadline_call_entered, self()})

         receive do
           :release_public_call -> :late_success
         after
           2_000 -> :late_success
         end
       end, deadline}
    )

    caller =
      receive do
        {:deadline_call_entered, pid} -> pid
      after
        1_000 -> flunk("deadline call missing")
      end

    receive do
      {^result_ref, {:error, nil, :deadline_expired}} -> :ok
    after
      1_000 -> flunk("original deadline did not cancel guardian")
    end

    assert SessionGuardian.await_down(endpoint.pid, endpoint_monitor) == :normal
    send(caller, :release_public_call)

    receipt =
      receive do
        {:deadline_cleanup, receipt} -> receipt
      after
        3_000 -> flunk("deadline cleanup missing")
      end

    assert SessionGuardian.await_down(guardian, monitor) == :normal
    assert receipt.endpoint_stop == ":ok"
    assert Enum.any?(receipt.tasks, &(&1.kind == :stable_caller))
    refute_receive {^result_ref, :late_success}, 0

    record("guardian_original_deadline_late_result", %{
      endpoint_stop: ":ok",
      late_success: "discarded",
      deadline_ms: 150
    })

    {guardian, monitor} = SessionGuardian.start(options, self())
    assert {:ok, _} = Gaoxy.SessionPublicProbe.rpc(guardian, {:bootstrap})

    assert :ok =
             Gaoxy.SessionPublicProbe.rpc(
               guardian,
               {:call, "boundary", fn _ -> :ok end, System.monotonic_time(:millisecond) + 1_000}
             )

    identity = Gaoxy.SessionPublicProbe.rpc(guardian, {:identity})
    Process.exit(identity.caller_pid, :kill)
    assert_receive {:caller_failure, caller, :killed} when caller == identity.caller_pid, 1_000

    receipt =
      receive do
        {:caller_failure_cleanup, receipt} -> receipt
      after
        3_000 -> flunk("idle crash cleanup missing")
      end

    assert SessionGuardian.await_down(guardian, monitor) == :normal
    assert receipt.endpoint_down == ":normal"
    assert Enum.count(receipt.tasks, &(&1.kind == :stable_caller)) == 1

    record("idle_caller_failure_before_connect", %{
      replacement_callers: 0,
      connect_calls: 0,
      endpoint_down: ":normal"
    })

    stop_hook = fn ->
      send(observer, {:ordering_stop_entered, self()})

      receive do
        :release_stop -> :ok
      after
        2_000 -> exit(:ordering_timeout)
      end
    end

    {guardian, monitor} =
      SessionGuardian.start(Keyword.put(options, :fixture_stop, stop_hook), self())

    assert {:ok, endpoint} = Gaoxy.SessionPublicProbe.rpc(guardian, {:bootstrap})

    assert :ok =
             Gaoxy.SessionPublicProbe.rpc(
               guardian,
               {:call, "boundary", fn _ -> :ok end, System.monotonic_time(:millisecond) + 1_000}
             )

    identity = Gaoxy.SessionPublicProbe.rpc(guardian, {:identity})
    caller_monitor = Process.monitor(identity.caller_pid)
    cleanup_ref = make_ref()
    send(guardian, {:cleanup, self(), cleanup_ref, true})
    assert_receive {:ordering_stop_entered, pid} when pid == endpoint.pid, 1_000
    Process.exit(identity.caller_pid, :kill)
    assert SessionGuardian.await_down(identity.caller_pid, caller_monitor) == :killed
    refute_receive {^cleanup_ref, _receipt}, 0
    send(endpoint.pid, :release_stop)

    receipt =
      receive do
        {^cleanup_ref, receipt} -> receipt
      after
        3_000 -> flunk("stop-ordering cleanup missing")
      end

    assert SessionGuardian.await_down(guardian, monitor) == :normal
    assert receipt.endpoint_down == ":normal" and receipt.endpoint_stop == ":ok"
    assert Enum.any?(receipt.tasks, &(&1.kind == :stable_caller and &1.down == ":killed"))

    for abort_mode <- [:released, :blocked] do
      stop = fn endpoint ->
        send(observer, {:abort_cleanup_stop, endpoint.pid})
        Quic.stop_endpoint(endpoint)
      end

      {abort_guardian, abort_monitor} =
        SessionGuardian.start(Keyword.put(options, :fixture_public_stop, stop), self())

      assert {:ok, abort_endpoint} =
               Gaoxy.SessionPublicProbe.rpc(abort_guardian, {:bootstrap})

      {:ok, abort_session} = Session.new(transport: Gaoxy.SessionBoundaryDouble)

      assert {:ok, _} =
               Gaoxy.SessionPublicProbe.rpc(
                 abort_guardian,
                 {:call, "connect",
                  fn _ ->
                    Gaoxy.SessionBoundaryDouble.put(%{
                      abort: [{:barrier, observer, :ok}]
                    })

                    Session.connect(abort_session, "localhost", 443, consumer: self())
                  end, System.monotonic_time(:millisecond) + 1_000}
               )

      abort_identity = Gaoxy.SessionPublicProbe.rpc(abort_guardian, {:identity})
      abort_caller = abort_identity.caller_pid
      abort_ref = make_ref()
      cleanup_deadline = System.monotonic_time(:millisecond) + 500
      send(abort_guardian, {:cleanup, self(), abort_ref, true, cleanup_deadline})
      assert_receive {:public_call_entered, ^abort_caller}, 1_000
      refute_receive {:abort_cleanup_stop, _}, 0
      if abort_mode == :released, do: send(abort_caller, :release_public_call)
      assert_receive {:abort_cleanup_stop, endpoint} when endpoint == abort_endpoint.pid, 1_000

      abort_receipt =
        receive do
          {^abort_ref, receipt} -> receipt
        after
          1_000 -> flunk("bounded abort cleanup missing")
        end

      assert SessionGuardian.await_down(abort_guardian, abort_monitor) == :normal
      assert abort_receipt.cleanup_outcome == "confirmed"
      assert abort_receipt.cleanup_deadline == cleanup_deadline
      assert abort_receipt.observed_at < cleanup_deadline

      if abort_mode == :released do
        assert String.starts_with?(abort_receipt.session_result, "{:ok,")
        assert abort_receipt.stop_trigger == ":session_result"

        assert Enum.any?(
                 abort_receipt.tasks,
                 &(&1.kind == :stable_caller and &1.down == ":normal")
               )
      else
        assert abort_receipt.session_result == ":cleanup_call_pending"
        assert abort_receipt.stop_trigger == ":fallback"

        assert Enum.any?(
                 abort_receipt.tasks,
                 &(&1.kind == :stable_caller and &1.down == ":killed")
               )
      end
    end

    record("caller_down_before_stop_result", %{
      completion_before_stop: false,
      stop_result: ":ok",
      endpoint_down: ":normal",
      idle_abort_before_stop: true,
      blocked_abort_fallback: true,
      original_cleanup_deadline_retained: true
    })

    bootstrap_loss(:allocation)
    bootstrap_loss(:adoption)
    stop_loss()
    creator_crash()
  end

  defp bootstrap_loss(stage) do
    observer = self()
    {_uri, options} = Gaoxy.SessionPublicProbe.options("a")

    {guardian, monitor} =
      spawn_monitor(fn ->
        guardian = self()

        hook =
          if stage == :allocation,
            do: fn ->
              send(observer, {:creator_in_client, self()})

              receive do
                :release_client -> :ok
              after
                2_000 -> exit(:fixture_timeout)
              end
            end

        options = Keyword.merge(options, ops: Gaoxy.EndpointBoundaryDouble, fixture_client: hook)

        creator =
          :erlang.spawn_opt(
            fn -> SessionGuardian.creator(guardian, options, {observer, :unused}) end,
            [:link, :monitor]
          )

        send(observer, {:bootstrap_loss_fixture, self(), elem(creator, 0)})

        receive do
          {:adopt, creator, endpoint} ->
            send(observer, {:creator_waiting_adoption, creator, endpoint})

            receive do
              :leave_normal -> :ok
            end

          :leave_normal ->
            :ok
        after
          3_000 -> exit(:fixture_timeout)
        end
      end)

    creator =
      receive do
        {:bootstrap_loss_fixture, ^guardian, pid} -> pid
      after
        1_000 -> flunk("creator fixture missing")
      end

    creator_monitor = Process.monitor(creator)

    endpoint =
      if stage == :adoption do
        receive do
          {:creator_waiting_adoption, ^creator, endpoint} -> endpoint
        after
          1_000 -> flunk("adoption fixture missing")
        end
      else
        receive do
          {:creator_in_client, ^creator} -> :ok
        after
          1_000 -> flunk("client barrier missing")
        end

        nil
      end

    endpoint_monitor = if endpoint, do: Process.monitor(endpoint.pid)
    send(guardian, :leave_normal)
    assert SessionGuardian.await_down(guardian, monitor) == :normal

    if stage == :allocation do
      assert Process.alive?(creator)
      send(creator, :release_client)
    end

    assert SessionGuardian.await_down(creator, creator_monitor) == :normal
    if endpoint, do: assert(SessionGuardian.await_down(endpoint.pid, endpoint_monitor) == :normal)

    record("guardian_normal_bootstrap_#{stage}", %{
      creator_down: ":normal",
      connect_calls: 0,
      boundary: "allocation call may return after guardian DOWN; no immediate caller-death claim"
    })
  end

  defp stop_loss do
    observer = self()
    {_uri, options} = Gaoxy.SessionPublicProbe.options("a")

    {guardian, monitor} =
      spawn_monitor(fn ->
        Process.flag(:trap_exit, true)

        hook = fn ->
          send(observer, {:stop_entered, self()})

          receive do
            :release_stop -> :ok
          after
            2_000 -> exit(:stop_double_timeout)
          end
        end

        {:ok, endpoint} =
          Quic.client(
            Keyword.merge(options,
              acceptor: self(),
              ops: Gaoxy.EndpointBoundaryDouble,
              fixture_stop: hook
            )
          )

        {stopper, _} = SessionGuardian.stop_task(self(), endpoint, observer)
        send(observer, {:stop_loss_fixture, endpoint, stopper})

        receive do
          :leave_normal -> :ok
        after
          2_000 -> exit(:fixture_timeout)
        end
      end)

    {endpoint, stopper} =
      receive do
        {:stop_loss_fixture, endpoint, stopper} -> {endpoint, stopper}
      after
        1_000 -> flunk("stop fixture missing")
      end

    endpoint_monitor = Process.monitor(endpoint.pid)
    stopper_monitor = Process.monitor(stopper)

    receive do
      {:stop_entered, pid} -> assert pid == endpoint.pid
    after
      1_000 -> flunk("stop barrier missing")
    end

    send(guardian, :leave_normal)
    assert SessionGuardian.await_down(guardian, monitor) == :normal
    send(endpoint.pid, :release_stop)
    assert SessionGuardian.await_down(endpoint.pid, endpoint_monitor) == :normal
    assert SessionGuardian.await_down(stopper, stopper_monitor) == :normal
    assert_receive {:orphan_stop_attempt, ^stopper, :ok}, 1_000

    record("guardian_normal_endpoint_stop", %{
      stop_attempts: 1,
      stop_task_down: ":normal",
      endpoint_down: ":normal"
    })
  end

  defp creator_crash do
    observer = self()
    {_uri, options} = Gaoxy.SessionPublicProbe.options("a")

    hook = fn ->
      send(observer, {:creator_after_ack, self()})

      receive do
        :never -> :ok
      after
        2_000 -> :ok
      end
    end

    options = Keyword.merge(options, ops: Gaoxy.EndpointBoundaryDouble, fixture_after_ack: hook)
    {guardian, monitor} = SessionGuardian.start(options, self())
    ref = make_ref()
    send(guardian, {:bootstrap, self(), ref})

    creator =
      receive do
        {:creator_after_ack, creator} -> creator
      after
        1_000 -> flunk("creator ACK barrier missing")
      end

    creator_monitor = Process.monitor(creator)
    identity = Gaoxy.SessionPublicProbe.rpc(guardian, {:identity})
    assert Process.alive?(identity.endpoint.pid)
    Process.exit(creator, :kill)
    assert SessionGuardian.await_down(creator, creator_monitor) == :killed
    assert_receive {:bootstrap_failure, :killed}, 1_000
    assert_receive {:bootstrap_failure_cleanup, receipt}, 2_000
    assert SessionGuardian.await_down(guardian, monitor) == :normal
    assert receipt.cleanup_outcome == "confirmed" and receipt.endpoint_down == ":normal"

    record("creator_crash_after_adoption", %{
      request_outcome: "uncertain",
      endpoint_down: ":normal",
      connect_calls: 0
    })

    before_hook = fn ->
      send(observer, {:creator_before_descriptor, self()})

      receive do
        :never -> :ok
      after
        2_000 -> exit(:before_descriptor_timeout)
      end
    end

    before_options =
      options |> Keyword.delete(:fixture_after_ack) |> Keyword.put(:fixture_client, before_hook)

    {guardian, guardian_monitor} = SessionGuardian.start(before_options, self())
    ref = make_ref()
    send(guardian, {:bootstrap, self(), ref})

    creator =
      receive do
        {:creator_before_descriptor, pid} -> pid
      after
        1_000 -> flunk("before-descriptor barrier missing")
      end

    monitor = Process.monitor(creator)
    Process.exit(creator, :kill)
    assert SessionGuardian.await_down(creator, monitor) == :killed
    assert_receive {:bootstrap_failure, :killed}, 1_000
    assert_receive {:bootstrap_failure_cleanup, receipt}, 2_000
    assert SessionGuardian.await_down(guardian, guardian_monitor) == :normal
    assert receipt.cleanup_outcome == "cleanup_unconfirmed"
    assert receipt.endpoint_stop == "nil" and receipt.endpoint_down == "nil"

    record("creator_crash_before_descriptor", %{
      cleanup_token: "retained uncertainty",
      no_allocation: "NOT CLAIMED",
      connect_calls: 0
    })
  end
end

defmodule Gaoxy.SessionPublicProbe do
  import ExUnit.Assertions
  alias QuicHttp3.Session
  alias Gaoxy.SessionGuardian, as: Guardian
  @trailers [{"x-check", "one"}, {"x-check", "two"}]
  @timeout 5_000

  def emit(event, fields \\ %{}) do
    IO.puts("GAOXY_UPSTREAM_PROBE " <> JSON.encode!(Map.put(fields, "event", event)))
  end

  def barrier(name, fields \\ %{}) do
    emit("barrier", Map.put(fields, "name", name))
    assert IO.gets("") == "continue\n"
  end

  def check(name, kind \\ "network") do
    checks = Process.get(:checks, [])
    refute name in checks
    Process.put(:checks, [name | checks])
    emit("check", %{name: name, status: "PASS", kind: kind})
  end

  def options(identity, host \\ nil, trust \\ nil) do
    uri = URI.parse(System.fetch_env!("GAOXY_UPSTREAM_URL_" <> String.upcase(identity)))
    ca = trust || System.fetch_env!("GAOXY_UPSTREAM_CA_" <> String.upcase(identity))
    {:ok, socket} = :gen_udp.open(0, [:binary, ip: {127, 0, 0, 1}, active: false])
    {:ok, {{127, 0, 0, 1}, port}} = :inet.sockname(socket)
    :ok = :gen_udp.close(socket)

    opts = [
      host: host || uri.host,
      tls: [cacertfile: ca, verify: :verify_peer],
      ip: {127, 0, 0, 1},
      port: port,
      timeout: @timeout,
      streams: [
        max_data: 262_144,
        max_buffer: 262_144,
        max_ready_bytes: 262_144,
        max_stream_data_bidi_local: 65_536,
        max_stream_data_uni: 65_536,
        max_streams_bidi: 1,
        max_streams_uni: 3,
        max_stream_records: 16
      ]
    ]

    {uri, opts}
  end

  def rpc(pid, message, timeout \\ 7_000) do
    ref = make_ref()
    send(pid, Tuple.insert_at(message, 1, self()) |> Tuple.insert_at(2, ref))

    receive do
      {^ref, result} -> result
    after
      timeout -> flunk("guardian call missing #{inspect(message |> elem(0))}")
    end
  end

  def call(handle, name, fun, deadline \\ nil) do
    deadline =
      min(
        deadline || System.monotonic_time(:millisecond) + @timeout,
        Map.get(handle, :total_deadline, System.monotonic_time(:millisecond) + @timeout)
      )

    Process.put({:operation_deadline, handle.pid}, deadline)
    started = System.monotonic_time(:millisecond)
    {:traced_result, result, identity} = rpc(handle.pid, {:call_traced, name, fun, deadline})

    completed = System.monotonic_time(:millisecond)

    unless Map.get(handle, :boundary_double, false) do
      poll_events = poll_event_summary(name, result)

      emit("public_result", %{
        operation: name,
        path: handle.path,
        result: summary(result),
        origin: handle.origin,
        caller: identity.caller,
        caller_alive: identity.caller_alive,
        caller_high_water: identity.high_water,
        public_closed: inspect(identity.public_closed, limit: 50, printable_limit: 128),
        started_ms: started,
        completed_ms: completed,
        deadline_ms: deadline,
        remaining_ms: deadline - completed,
        poll_events: poll_events
      })
    end

    result
  end

  def summary({tag, session, value}) when tag in [:ok, :blocked, :unknown, :error] do
    %{
      status: Atom.to_string(tag),
      value: inspect(value, limit: 8, printable_limit: 64),
      pending: inspect(session.pending, limit: 8, printable_limit: 64),
      requests: map_size(session.requests)
    }
  end

  def summary(result), do: inspect(result, limit: 8, printable_limit: 64)

  def poll_event_summary("poll", {:ok, _, events}) when is_list(events) do
    data = for {:data, _, bytes} <- events, do: bytes

    %{
      events: length(events),
      data_events: length(data),
      data_bytes: Enum.reduce(data, 0, &(byte_size(&1) + &2)),
      data_sha256: :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
    }
  end

  def poll_event_summary(_, _), do: nil

  def settle(handle, result, deadline \\ nil) do
    deadline = deadline || Process.get({:operation_deadline, handle.pid})
    assert Guardian.remaining(deadline) > 0

    case result do
      {tag, session, _} when tag in [:blocked, :unknown] ->
        assert System.monotonic_time(:millisecond) < deadline
        assert session.pending != nil

        receive do
        after
          5 -> :ok
        end

        settle(handle, call(handle, "resume", &Session.resume/1, deadline), deadline)

      _ ->
        result
    end
  end

  def bootstrap(identity, path, extra \\ []) do
    {uri, opts} = options(identity, extra[:host], extra[:trust])
    total = System.monotonic_time(:millisecond) + @timeout
    opts = Keyword.merge(opts, total_deadline: total, opening_deadline: total)
    {pid, monitor} = Guardian.start(opts, Process.get(:probe_owner, self()))

    handle = %{
      pid: pid,
      monitor: monitor,
      uri: uri,
      opts: opts,
      path: path,
      origin: identity,
      total_deadline: total,
      opening_deadline: total
    }

    try do
      assert {:ok, endpoint} = rpc(pid, {:bootstrap})
      # Creator normal DOWN has been consumed by guardian before bootstrap returns.
      assert Process.alive?(endpoint.pid)
      assert {{127, 0, 0, 1}, port} = Quic.local(endpoint.pid)
      assert port == opts[:port]

      identity = rpc(pid, {:identity})

      emit("adoption", %{
        creator: hd(identity.bootstrap_tasks).pid,
        guardian: inspect(pid),
        caller_not_started: identity.caller_pid == nil,
        path: path,
        endpoint: inspect(endpoint.pid),
        creator_down: ":normal",
        alive_after_creator_down: true,
        acceptor: inspect(pid),
        bind_port: port
      })

      # TODO(upstream): gsmlg-dev/http_fetch#105
      # WORKAROUND(upstream): gsmlg-dev/http_fetch#105
      # Smaller public wire fragments retain the 16 KiB application DATA ceiling.
      {:ok, session} =
        Session.new(
          timeout: @timeout,
          max_frame: 8_192,
          max_fields: 128,
          max_encoded_headers: 65_536,
          max_header_bytes: 65_536,
          max_retained_bytes: 262_144
        )

      send(pid, {:set_session, session})

      result =
        call(handle, "connect", fn session ->
          Session.connect(
            session,
            opts[:host],
            uri.port,
            Keyword.merge(opts, endpoint: endpoint, consumer: self())
          )
        end)
        |> then(&settle(handle, &1))

      {handle, result}
    rescue
      error ->
        cleanup(handle, true)
        reraise(error, __STACKTRACE__)
    end
  end

  def ready(handle, deadline \\ nil) do
    deadline = deadline || handle.opening_deadline
    assert Guardian.remaining(deadline) > 0

    case call(handle, "ready", &Session.ready/1, deadline) do
      :ready ->
        assert {:ok, _} =
                 call(handle, "open", &Session.open/1, deadline)
                 |> then(&settle(handle, &1, deadline))

        :ok

      :pending ->
        assert System.monotonic_time(:millisecond) < deadline

        receive do
        after
          5 -> :ok
        end

        ready(handle, deadline)

      error ->
        error
    end
  end

  def request(identity, path, body \\ <<>>, fields \\ []) do
    {handle, result} = bootstrap(identity, path)

    try do
      assert {:ok, _} = result
      assert :ok = ready(handle)

      headers =
        [
          {":method", if(body == :stream, do: "POST", else: "GET")},
          {":scheme", "https"},
          {":authority", "localhost:#{handle.uri.port}"},
          {":path", path}
        ] ++ fields

      assert {:ok, _, ref} =
               call(handle, "request", &Session.request(&1, headers, body, []))
               |> then(&settle(handle, &1))

      emit("request_ref", %{path: path, ref: inspect(ref)})
      Map.put(handle, :ref, ref)
    rescue
      error ->
        cleanup(handle, true)
        reraise(error, __STACKTRACE__)
    end
  end

  def cleanup(handle, cancelled) do
    receipt = rpc(handle.pid, {:cleanup, cancelled}, 15_000)
    assert Guardian.await_down(handle.pid, handle.monitor) == :normal
    assert receipt.cleanup_outcome == "confirmed"

    emit(
      "cleanup_result",
      Map.merge(receipt, %{
        path: handle.path,
        origin: handle.origin,
        guardian_down: ":normal"
      })
    )

    receipt
  end

  def with_request(identity, path, body, fields, fun) do
    handle = request(identity, path, body, fields)

    try do
      fun.(handle)
    after
      if Process.alive?(handle.pid), do: cleanup(handle, true)
    end
  end

  def poll(handle, paused \\ false, deadline \\ nil) do
    opts = [
      max_read_batches: 1,
      timeout: @timeout,
      paused: if(paused, do: MapSet.new([handle.ref]), else: MapSet.new())
    ]

    assert {:ok, _, events} =
             call(handle, "poll", &Session.poll(&1, 16, opts), deadline)
             |> then(&settle(handle, &1, deadline))

    events
  end

  def assert_paused_controls(events) do
    # Paused refs prohibit response reads, not public connection/control events.
    # Validate the entire batch; filtering would hide response or error events.
    Enum.each(events, fn
      event when event in [:ready, :writable] ->
        :ok

      {:ready, %{alpn: "h3", peer_authenticated: true}} ->
        :ok

      {:settings, settings} when is_list(settings) ->
        assert Enum.all?(settings, fn
                 {id, value}
                 when is_integer(id) and id >= 0 and is_integer(value) and value >= 0 ->
                   true

                 _ ->
                   false
               end)

      event ->
        flunk("unexpected event while request is paused: #{inspect(event, limit: 8)}")
    end)

    :ok
  end

  def response(handle, until, acc \\ [], deadline \\ nil) do
    deadline = min(deadline || handle.total_deadline, handle.total_deadline)
    assert System.monotonic_time(:millisecond) < deadline
    events = poll(handle, false, deadline)
    assert Guardian.remaining(deadline) > 0
    acc = acc ++ events

    if until.(acc) do
      acc
    else
      progress? =
        Enum.any?(events, fn
          {kind, ref, _} when kind in [:headers, :data, :trailers] -> ref == handle.ref
          {:done, ref} -> ref == handle.ref
          _ -> false
        end)

      unless progress? do
        receive do
        after
          5 -> :ok
        end
      end

      response(handle, until, acc, deadline)
    end
  end

  def data(events, ref), do: for({:data, ^ref, bytes} <- events, into: <<>>, do: bytes)
  def ended?(events, ref), do: Enum.any?(events, &match?({:done, ^ref}, &1))

  def verify(events, handle, body, trailers) do
    assert Enum.any?(events, fn
             {:headers, ref, [{":status", "200"} | fields]} when ref == handle.ref ->
               Enum.filter(fields, &(elem(&1, 0) == "x-repeat")) == [
                 {"x-repeat", "one"},
                 {"x-repeat", "two"}
               ]

             _ ->
               false
           end)

    assert data(events, handle.ref) == body
    assert ended?(events, handle.ref)

    assert for({:trailers, ref, fields} <- events, ref == handle.ref, do: fields) ==
             if(trailers == [], do: [], else: [trailers])
  end

  def ordinary(identity) do
    with_request(identity, "/ordinary", <<>>, [], fn h ->
      first = response(h, &(data(&1, h.ref) == "ordinary-"))
      refute ended?(first, h.ref)
      barrier("ordinary_progress", %{origin: identity, path: h.path})
      events = response(h, &ended?(&1, h.ref), first)
      verify(events, h, "ordinary-response", @trailers)
      cleanup(h, false)
      check("ordinary_stream_" <> identity)
    end)
  end

  def upload(path, chunks, name) do
    with_request("a", path, :stream, [], fn h ->
      Enum.with_index(chunks, 1)
      |> Enum.each(fn {bytes, index} ->
        assert {:ok, _} =
                 call(h, "send_data", &Session.send_data(&1, h.ref, bytes, false, []))
                 |> then(&settle(h, &1))

        if index == 1,
          do: barrier("upload_progress", %{origin: "a", path: path, bytes: byte_size(bytes)})
      end)

      assert {:ok, _} =
               call(h, "send_fin", &Session.send_data(&1, h.ref, <<>>, true, []))
               |> then(&settle(h, &1))

      events = response(h, &ended?(&1, h.ref))
      verify(events, h, IO.iodata_to_binary(chunks), [])
      cleanup(h, false)
      check(name)
    end)
  end

  def trailers(zero?, declared?) do
    size = if zero?, do: "zero", else: "three"
    declaration = if declared?, do: "declared", else: "undeclared"
    path = "/echo-" <> size <> "-" <> declaration

    with_request(
      "a",
      path,
      :stream,
      if(declared?, do: [{"trailer", "x-check"}], else: []),
      fn h ->
        if not zero?,
          do:
            assert(
              {:ok, _} =
                call(h, "send_data", &Session.send_data(&1, h.ref, "abc", false, []))
                |> then(&settle(h, &1))
            )

        barrier("trailer_before_finish", %{origin: "a", path: path, zero: zero?})

        assert {:ok, _} =
                 call(h, "send_trailers", &Session.send_trailers(&1, h.ref, @trailers, []))
                 |> then(&settle(h, &1))

        events = response(h, &ended?(&1, h.ref))
        verify(events, h, "echo-finished", @trailers)
        cleanup(h, false)
        check("request_trailers_" <> size <> "_" <> declaration)
      end
    )
  end

  def negative(name) do
    barrier("negative_before", %{case: name})

    result =
      case name do
        "absent_trust" ->
          QuicHttp3.Transport.Quic.client(host: "localhost", tls: [])

        "address_policy" ->
          # Gaoxy's pre-admission policy is deliberately separate from raw Transport options.
          opts = [connect_address: {127, 0, 0, 1}]
          if Keyword.has_key?(opts, :connect_address), do: {:error, :unsupported_address_pinning}

        _ ->
          extra =
            if name == "wrong_ca",
              do: [trust: System.fetch_env!("GAOXY_UPSTREAM_CA_B")],
              else: [host: "127.0.0.1"]

          {h, connected} = bootstrap("a", "/negative-" <> name, extra)
          outcome = if match?({:ok, _}, connected), do: ready(h), else: connected
          identity = rpc(h.pid, {:identity})
          cleanup(h, true)
          assert match?({:error, _}, outcome) or match?({:error, _, _}, outcome)
          %{operation_result: outcome, public_closed: identity.public_closed}
      end

    case name do
      "absent_trust" ->
        assert result == {:error, :ca_trust_required}

      "address_policy" ->
        assert result == {:error, :unsupported_address_pinning}

      "wrong_ca" ->
        assert inspect(result) =~ "unknown_ca"
        assert inspect(result) =~ "path_validation_failed"
        assert inspect(result.public_closed) =~ "unknown_ca"
        assert inspect(result.public_closed) =~ "path_validation_failed"

      "wrong_hostname" ->
        assert inspect(result) =~ "certificate_unknown"
        assert inspect(result) =~ "hostname_mismatch"
        assert inspect(result.public_closed) =~ "certificate_unknown"
        assert inspect(result.public_closed) =~ "hostname_mismatch"
    end

    barrier("negative_after", %{case: name, result: inspect(result)})
    check(name, if(name in ["address_policy", "absent_trust"], do: "policy", else: "network"))
  end

  def cancel_case(name, path) do
    sibling = request("b", "/sibling-" <> name)

    try do
      owner =
        if name == "owner_loss",
          do:
            spawn(fn ->
              receive do
                :lose -> :ok
              end
            end)

      if owner, do: Process.put(:probe_owner, owner)

      with_request("a", path, if(name == "blocked_upload", do: :stream, else: <<>>), [], fn h ->
        Process.delete(:probe_owner)

        case name do
          "pending_headers" ->
            barrier("pending_headers", %{origin: "a", path: path})

          "blocked_upload" ->
            barrier("pause_upload", %{origin: "a", path: path})

            result =
              Enum.reduce_while(1..128, nil, fn index, _ ->
                result =
                  call(
                    h,
                    "send_data",
                    &Session.send_data(&1, h.ref, :binary.copy("x", 16_384), false,
                      timeout: 1_000
                    ),
                    System.monotonic_time(:millisecond) + 1_000
                  )

                case result do
                  {:ok, _} -> {:cont, nil}
                  {:blocked, session, reason} -> {:halt, {index, :blocked, session, reason}}
                  {:unknown, session, ref} -> {:halt, {index, :unknown, session, ref}}
                  other -> flunk("unexpected blocked upload result #{inspect(other)}")
                end
              end)

            assert {index, status, _, _} = result
            assert status in [:blocked, :unknown]

            emit("blocked_write", %{
              index: index,
              status: Atom.to_string(status),
              result: inspect(result, limit: 8)
            })

            if status == :blocked do
              assert {:ok, _, continuation} =
                       call(h, "suspend_blocked", &Session.suspend_blocked/1)

              assert is_struct(continuation, Session.Continuation)
              assert :ok = assert_paused_controls(poll(h, true))
            end

            barrier("blocked_upload", %{origin: "a", path: path})

          _ ->
            events = response(h, &(data(&1, h.ref) == "unacknowledged"))
            refute ended?(events, h.ref)
            assert :ok = assert_paused_controls(poll(h, true))

            if name == "owner_loss" do
              monitor = Process.monitor(owner)
              barrier("owner_loss", %{origin: "a", path: path})
              send(owner, :lose)
              assert Guardian.await_down(owner, monitor) == :normal
            end
        end

        if name == "pending_headers" do
          assert {:ok, _} = call(h, "cancel", &Session.cancel(&1, h.ref)) |> then(&settle(h, &1))
        end

        if name == "owner_loss" do
          receive do
            {:owner_loss_observed, :normal} -> :ok
          after
            @timeout -> flunk("guardian owner monitor missing")
          end

          receipt =
            receive do
              {:owner_cleanup, receipt} -> receipt
            after
              15_000 -> flunk("owner cleanup missing")
            end

          assert Guardian.await_down(h.pid, h.monitor) == :normal

          emit(
            "cleanup_result",
            Map.merge(receipt, %{
              path: h.path,
              origin: h.origin,
              guardian_down: ":normal",
              cancelled: true,
              owner_monitor_triggered: true
            })
          )
        else
          cleanup(h, true)
        end

        if name == "blocked_upload", do: barrier("resume_upload", %{origin: "a", path: path})
        barrier("cancel_observed", %{origin: "a", path: path})
        assert Process.alive?(sibling.pid)
        barrier("finish_sibling", %{origin: "b", path: sibling.path})
        events = response(sibling, &ended?(&1, sibling.ref))
        verify(events, sibling, "sibling-response", [])
        cleanup(sibling, false)
        check("cancel_" <> name)
      end)
    after
      Process.delete(:probe_owner)
      if Process.alive?(sibling.pid), do: cleanup(sibling, true)
    end
  end

  def ownership_double(stage) do
    observer = self()
    {_uri, opts} = options("a")

    hook = fn ->
      send(observer, {:ownership_barrier, stage, self()})

      receive do
        :release_ownership -> :ok
      after
        2_000 -> exit(:ownership_barrier_timeout)
      end
    end

    opts = Keyword.put(opts, :ops, Gaoxy.EndpointBoundaryDouble)

    opts =
      case stage do
        :before_descriptor ->
          Keyword.put(opts, :fixture_client, hook)

        :before_adoption ->
          Keyword.put(opts, :fixture_before_adopt, hook)

        :after_ack ->
          Keyword.put(opts, :fixture_after_ack, hook)

        :stop_error ->
          Keyword.put(opts, :fixture_public_stop, fn _ -> {:error, :injected_stop_error} end)

        :missing_down ->
          Keyword.put(opts, :fixture_public_stop, fn _ -> :ok end)

        :cleanup_expiry ->
          Keyword.merge(opts, fixture_stop: hook, fixture_stop_observer: true)

        _ ->
          opts
      end

    {guardian, guardian_monitor} = Guardian.start(opts, self())
    bootstrap_ref = make_ref()
    send(guardian, {:bootstrap, self(), bootstrap_ref})

    creator =
      if stage in [:before_descriptor, :before_adoption, :after_ack] do
        receive do
          {:ownership_barrier, ^stage, creator} -> creator
        after
          1_000 -> flunk("ownership barrier missing")
        end
      else
        assert_receive {^bootstrap_ref, {:ok, _}}, 1_000
        nil
      end

    creator_monitor = if creator, do: Process.monitor(creator)
    identity = rpc(guardian, {:identity})
    assert identity.caller_pid == nil
    endpoint_monitor = if identity.endpoint, do: Process.monitor(identity.endpoint.pid)
    cleanup_ref = make_ref()

    if stage == :abnormal_down do
      GenServer.stop(identity.endpoint.pid, :injected_abnormal)
    else
      message =
        if stage == :cleanup_expiry,
          do: {:cleanup, self(), cleanup_ref, true, System.monotonic_time(:millisecond) + 150},
          else: {:cleanup, self(), cleanup_ref, true}

      send(guardian, message)
    end

    if creator, do: send(creator, :release_ownership)

    stop_monitor =
      if stage == :cleanup_expiry do
        assert_receive {:owned_stop_started, stopper}, 1_000
        {stopper, Process.monitor(stopper)}
      end

    stopped_endpoint =
      if stage == :cleanup_expiry do
        receive do
          {:ownership_barrier, ^stage, endpoint} -> endpoint
        after
          1_000 -> flunk("cleanup expiry stop barrier missing")
        end
      end

    ref = if stage == :abnormal_down, do: :endpoint_failure_cleanup, else: cleanup_ref

    receipt =
      receive do
        {^ref, receipt} -> receipt
      after
        2_000 -> flunk("actual guardian ownership receipt missing")
      end

    assert Guardian.await_down(guardian, guardian_monitor) == :normal
    if stopped_endpoint, do: send(stopped_endpoint, :release_ownership)
    if creator, do: assert(Guardian.await_down(creator, creator_monitor) == :normal)

    if identity.endpoint,
      do:
        assert(
          Guardian.await_down(identity.endpoint.pid, endpoint_monitor) ==
            if(stage == :abnormal_down, do: :injected_abnormal, else: :normal)
        )

    if stage in [:stop_error, :abnormal_down, :missing_down, :cleanup_expiry] do
      assert receipt.cleanup_outcome == "cleanup_unconfirmed"

      if stage == :stop_error,
        do: assert(receipt.endpoint_stop == "{:error, :injected_stop_error}")

      if stage == :abnormal_down, do: assert(receipt.endpoint_down == ":injected_abnormal")

      if stage == :missing_down,
        do: assert(receipt.endpoint_stop == ":ok" and receipt.endpoint_down == "nil")

      if stage == :cleanup_expiry do
        assert receipt.stop_task_down == "nil" and receipt.endpoint_down == "nil"
        assert receipt.observed_at >= receipt.cleanup_deadline
        # Stop remains owned and finishes its one public call after grace, without completion.
        {stopper, stopper_monitor} = stop_monitor
        assert_receive {:orphan_stop_attempt, ^stopper, :ok}, 1_000
        assert Guardian.await_down(stopper, stopper_monitor) == :normal
      end
    else
      assert receipt.cleanup_outcome == "confirmed"
      assert receipt.endpoint_stop == ":ok" and receipt.endpoint_down == ":normal"
      assert receipt.stop_task_down == ":normal"
      assert Enum.all?(receipt.tasks, &(&1.down == ":normal"))
    end

    refute Enum.any?(receipt.tasks, &(&1.kind == :stable_caller))
    assert String.starts_with?(receipt.service_completion, "NOT CLAIMED")

    emit(
      "double_receipt",
      Map.merge(receipt, %{name: stage, driver: "actual SessionGuardian", connect_calls: 0})
    )

    check("ownership_#{stage}", "boundary_double")
  end

  def affinity_network do
    for kind <- [:idle_caller_failure, :guardian_after_connect] do
      {h, connected} = bootstrap("a", "/affinity-" <> Atom.to_string(kind))
      assert {:ok, _} = connected
      assert :ok = ready(h)
      identity = rpc(h.pid, {:identity})

      if kind == :idle_caller_failure do
        caller_monitor = Process.monitor(identity.caller_pid)
        Process.exit(identity.caller_pid, :kill)
        assert Guardian.await_down(identity.caller_pid, caller_monitor) == :killed

        assert_receive {:caller_failure, caller, :killed} when caller == identity.caller_pid,
                       @timeout

        receipt =
          receive do
            {:caller_failure_cleanup, receipt} -> receipt
          after
            15_000 -> flunk("failed caller cleanup missing")
          end

        assert Guardian.await_down(h.pid, h.monitor) == :normal

        emit(
          "cleanup_result",
          Map.merge(receipt, %{
            path: h.path,
            origin: h.origin,
            guardian_down: ":normal",
            cancelled: true,
            request_outcome: "caller_failed; no replay"
          })
        )
      else
        guardian_loss(h)
      end

      check("network_#{kind}")
    end

    sibling = request("b", "/sibling-guardian_loss")

    with_request("a", "/guardian-loss", <<>>, [], fn h ->
      events = response(h, &(data(&1, h.ref) == "unacknowledged"))
      refute ended?(events, h.ref)
      assert :ok = assert_paused_controls(poll(h, true))
      guardian_loss(h)
      assert Process.alive?(sibling.pid)
      barrier("finish_sibling", %{origin: "b", path: sibling.path})
      events = response(sibling, &ended?(&1, sibling.ref))
      verify(events, sibling, "sibling-response", [])
      cleanup(sibling, false)
      check("network_guardian_paused_ack")
    end)
  end

  def guardian_loss(h) do
    identity = rpc(h.pid, {:identity})
    caller_monitor = Process.monitor(identity.caller_pid)
    endpoint_monitor = Process.monitor(identity.endpoint.pid)
    assert %{endpoint: endpoint} = rpc(h.pid, {:leave_normal})
    assert endpoint == identity.endpoint
    assert Guardian.await_down(h.pid, h.monitor) == :normal
    assert Guardian.await_down(endpoint.pid, endpoint_monitor) == :normal
    assert Guardian.await_down(identity.caller_pid, caller_monitor) == :normal
    # Independent observer confirms an already-observed normal endpoint DOWN.
    stop_result = QuicHttp3.Transport.Quic.stop_endpoint(endpoint)
    assert stop_result == :ok
    {:ok, socket} = :gen_udp.open(h.opts[:port], [:binary, ip: {127, 0, 0, 1}, active: false])
    :ok = :gen_udp.close(socket)

    emit("guardian_loss_result", %{
      path: h.path,
      origin: h.origin,
      guardian_down: ":normal",
      endpoint_down: ":normal",
      caller_down: ":normal",
      creator_tasks: identity.bootstrap_tasks,
      endpoint_stop: inspect(stop_result),
      bind_port: h.opts[:port],
      rebound_port: h.opts[:port],
      service_completion: "NOT CLAIMED; guardian protocol lost",
      caller_high_water: identity.high_water
    })
  end

  def doubles do
    alias Gaoxy.SessionBoundaryDouble, as: D
    ref = make_ref()

    D.put(%{
      connect: [{:unknown, :connection, ref}],
      operation_status: [%{status: :admitted, result: {:ok, :connection}}]
    })

    {:ok, s} = Session.new(transport: D)
    assert {:unknown, advanced, ^ref} = Session.connect(s, "localhost", 443, [])
    assert advanced.connection == :connection
    assert {:ok, connected} = Session.resume(advanced)
    assert Enum.count(D.calls(), &(elem(&1, 0) == :connect)) == 1
    check("unknown_connect_reconciled", "boundary_double")
    assert {:ok, opened} = Session.open(connected)

    fields = [
      {":method", "POST"},
      {":scheme", "https"},
      {":authority", "localhost"},
      {":path", "/double"}
    ]

    assert {:ok, requested, request_ref} = Session.request(opened, fields, :stream, [])

    for operation <- [:data, :trailers] do
      operation_ref = make_ref()
      D.put(%{send_stream: [{:unknown, operation_ref}]})

      result =
        if operation == :data,
          do: Session.send_data(requested, request_ref, "abc", false, []),
          else: Session.send_trailers(requested, request_ref, @trailers, [])

      assert {:unknown, advanced, ^operation_ref} = result
      assert {:ok, reconciled} = Session.resume(advanced)
      assert Enum.count(D.calls(), &(elem(&1, 0) == :send_stream)) == 1

      assert Enum.any?(D.calls(), fn {name, args} ->
               name == :operation_status and args == [operation_ref, :send_stream]
             end)

      assert reconciled.pending == nil
      check("unknown_#{operation}_no_replay", "boundary_double")
    end

    D.put(%{send_stream: [{:error, :advanced_failure}]})

    assert {:error, advanced, :advanced_failure} =
             Session.send_data(requested, request_ref, "abc", false, [])

    assert Map.has_key?(advanced.requests, request_ref)
    assert advanced.work != nil
    assert advanced.pending == nil
    check("advanced_error_retained", "boundary_double")
    D.put(%{send_stream: [{:blocked, :credit}]})

    assert {:blocked, advanced, :credit} =
             Session.send_data(requested, request_ref, "abc", false, [])

    original_deadline = advanced.pending.deadline
    assert {:ok, suspended, token} = Session.suspend_blocked(advanced)
    assert {:ok, polled, []} = Session.poll(suspended, 16, paused: MapSet.new([request_ref]))
    assert token.pending.deadline == original_deadline
    assert {:ok, resumed} = Session.resume(polled, token)
    assert resumed.pending == nil
    assert {:error, _, :stale_continuation} = Session.resume(resumed, token)
    paused_poll_contract_double(requested, request_ref)
    fragmentation_double(fields)
    check("blocked_suspend_poll_resume", "boundary_double")
  end

  def fragmentation_double(fields) do
    alias Gaoxy.SessionBoundaryDouble, as: D
    body = :binary.copy("x", 16_384)
    assert {:ok, encoded} = QuicHttp3.Frame.encode(:data, body)
    assert byte_size(encoded) == 16_389
    <<first::binary-size(8_192), second::binary-size(8_192), last::binary-size(5)>> = encoded

    for outcome <- [:accepted, :blocked, :unknown] do
      D.put(%{})
      assert {:ok, session} = Session.new(transport: D, max_frame: 8_192)
      assert {:ok, session} = Session.connect(session, "localhost", 443, [])
      assert {:ok, session} = Session.open(session)
      assert {:ok, session, request_ref} = Session.request(session, fields, :stream, [])
      operation_ref = make_ref()

      script =
        case outcome do
          :accepted -> [:ok, :ok, :ok]
          :blocked -> [:ok, {:blocked, :credit}, :ok, :ok]
          :unknown -> [:ok, {:unknown, operation_ref}, :ok]
        end

      D.put(%{send_stream: script})
      result = Session.send_data(session, request_ref, body, true, [])

      case outcome do
        :accepted ->
          assert {:ok, _} = result

          assert [
                   {:send_stream, [:bidi, ^first, false, _]},
                   {:send_stream, [:bidi, ^second, false, _]},
                   {:send_stream, [:bidi, ^last, true, _]}
                 ] = D.calls()

        :blocked ->
          assert {:blocked, advanced, :credit} = result
          assert {:ok, _} = Session.resume(advanced)

          assert [
                   {:send_stream, [:bidi, ^first, false, _]},
                   {:send_stream, [:bidi, ^second, false, _]},
                   {:send_stream, [:bidi, ^second, false, _]},
                   {:send_stream, [:bidi, ^last, true, _]}
                 ] = D.calls()

        :unknown ->
          assert {:unknown, advanced, ^operation_ref} = result
          assert {:ok, _} = Session.resume(advanced)

          assert [
                   {:send_stream, [:bidi, ^first, false, _]},
                   {:send_stream, [:bidi, ^second, false, _]},
                   {:operation_status, [^operation_ref, :send_stream]},
                   {:send_stream, [:bidi, ^last, true, _]}
                 ] = D.calls()
      end

      # A rejected second fragment is retried; accepted/unknown prefixes never are.
      assert first <> second <> last == encoded
    end
  end

  def paused_poll_contract_double(requested, request_ref) do
    alias Gaoxy.SessionBoundaryDouble, as: D
    alias QuicHttp3.{Frame, Qpack}

    controls = [
      :ready,
      :writable,
      {:ready, %{alpn: "h3", peer_authenticated: true}},
      {:settings, [{1, 0}]}
    ]

    assert :ok = assert_paused_controls(controls)

    forbidden = [
      {:headers, request_ref, [{":status", "200"}]},
      {:informational, request_ref, 103, []},
      {:data, request_ref, "new delivery"},
      {:data, make_ref(), "other request"},
      {:trailers, request_ref, @trailers},
      {:done, request_ref},
      {:stream_error, request_ref, 0x100, :failure},
      {:stream_reset, request_ref, 0x100, 0},
      {:stopped, request_ref, 0x100},
      {:error, :failure},
      {:closed, :normal},
      {:goaway, 0},
      :datagram_readable,
      {:ready, %{peer_authenticated: false}},
      {:settings, [:invalid]},
      :unknown
    ]

    for event <- forbidden, batch <- [[event], [:writable, event], [event, :writable]] do
      assert_raise ExUnit.AssertionError, fn -> assert_paused_controls(batch) end
    end

    # Public codecs script the Transport boundary, not an independent peer.
    assert {:ok, encoded} = Qpack.encode_header_block([{":status", "200"}])
    assert {:ok, headers} = Frame.encode(:headers, encoded)
    assert {:ok, first_data} = Frame.encode(:data, "held-delivery")
    assert {:ok, next_data} = Frame.encode(:data, "after-ack")

    D.put(%{
      events: [{:ok, [{:readable, :bidi}]}],
      read: [{:ok, [{:data, headers <> first_data}]}]
    })

    assert {:ok, held, [{:headers, ^request_ref, _}, {:data, ^request_ref, "held-delivery"}]} =
             Session.poll(requested, 16, max_read_batches: 1)

    D.put(%{
      events: [{:ok, [:writable, {:readable, :bidi}]}],
      read: [{:ok, [{:data, next_data}, {:fin}]}]
    })

    assert {:ok, paused, [:writable] = events} =
             Session.poll(held, 16, max_read_batches: 1, paused: MapSet.new([request_ref]))

    assert :ok = assert_paused_controls(events)

    assert {:ok, still_paused, []} =
             Session.poll(paused, 16, max_read_batches: 1, paused: MapSet.new([request_ref]))

    # While the first delivery is held, only events pulls ran: no response read,
    # application send/replay or implicit ACK release. Pending DATA/FIN survives.
    assert D.calls() == [{:events, []}, {:events, []}]

    assert {:ok, _, [{:data, ^request_ref, "after-ack"}, {:done, ^request_ref}]} =
             Session.poll(still_paused, 16, max_read_batches: 1, paused: MapSet.new())

    assert D.calls() == [{:events, []}, {:events, []}, {:events, []}, {:read, [:bidi]}]
  end

  def deadline_doubles do
    alias Gaoxy.SessionBoundaryDouble, as: D
    observer = self()
    {_uri, opts} = options("a")

    opts =
      Keyword.merge(opts, ops: Gaoxy.EndpointBoundaryDouble, fixture_command_observer: self())

    {guardian, monitor} = Guardian.start(opts, self())
    assert {:ok, _} = rpc(guardian, {:bootstrap})
    {:ok, session} = Session.new(transport: D)
    send(guardian, {:set_session, session})
    deadline = System.monotonic_time(:millisecond) + 1_000
    handle = %{pid: guardian, boundary_double: true, total_deadline: deadline}

    {driver, driver_monitor} =
      spawn_monitor(fn ->
        result =
          call(
            handle,
            "connect",
            fn session ->
              D.put(%{
                connect: [{:unknown, :connection, make_ref()}],
                operation_status: [
                  :unknown,
                  :unknown,
                  {:barrier, observer, %{status: :admitted, result: {:ok, :connection}}}
                ]
              })

              Session.connect(session, "localhost", 443, [])
            end,
            deadline
          )

        assert {:ok, _} = settle(handle, result, deadline)
        send(observer, {:resumes_complete, Process.get({:operation_deadline, guardian})})
      end)

    assert_receive {:public_call_entered, caller}, 1_000
    identity = rpc(guardian, {:identity})
    assert identity.caller_pid == caller

    for name <- ["connect", "resume", "resume", "resume"],
        do: assert_receive({:command_deadline, ^name, ^deadline}, 0)

    send(caller, :release_public_call)
    assert_receive {:resumes_complete, ^deadline}, 1_000
    assert Guardian.await_down(driver, driver_monitor) == :normal
    assert %{cleanup_outcome: "confirmed"} = rpc(guardian, {:cleanup, true})
    assert Guardian.await_down(guardian, monitor) == :normal

    emit("double_receipt", %{
      name: "guardian_repeated_resume_original_deadline",
      command_deadlines: List.duplicate(deadline, 4),
      caller: inspect(caller)
    })

    check("guardian_repeated_resume_original_deadline", "boundary_double")

    # Hold the actual result handler after a success is dequeued, allowing the
    # original deadline to pass before the timer message can be processed.
    hook = fn ->
      send(observer, {:result_handler_entered, self()})

      receive do
        :release_result_handler -> :ok
      after
        1_000 -> exit(:result_handler_timeout)
      end
    end

    opts =
      opts
      |> Keyword.delete(:fixture_command_observer)
      |> Keyword.put(:fixture_result_check, hook)

    {guardian, monitor} = Guardian.start(opts, self())
    assert {:ok, _} = rpc(guardian, {:bootstrap})
    deadline = System.monotonic_time(:millisecond) + 150
    ref = make_ref()
    send(guardian, {:call, self(), ref, "boundary", fn _ -> :successful_result end, deadline})
    assert_receive {:result_handler_entered, ^guardian}, 1_000
    Process.send_after(guardian, :release_result_handler, Guardian.remaining(deadline) + 1)
    assert_receive {^ref, {:error, nil, :deadline_expired}}, 1_000
    assert_receive {:deadline_cleanup, %{cleanup_outcome: "confirmed"}}, 1_000
    assert Guardian.await_down(guardian, monitor) == :normal
    refute_receive {^ref, :successful_result}, 0

    emit("double_receipt", %{
      name: "guardian_late_success_before_timer",
      late_success: "rejected by absolute deadline before timer handling"
    })

    check("guardian_late_success_before_timer", "boundary_double")
  end

  def run do
    {:ok, _} = Application.ensure_all_started(:http_fetch)

    emit("environment", %{
      elixir: System.version(),
      otp: List.to_string(:erlang.system_info(:otp_release)),
      http_fetch: to_string(Application.spec(:http_fetch, :vsn)),
      selected: "public Session dedicated endpoint"
    })

    doubles()
    Gaoxy.SessionAffinityDoubles.run()
    deadline_doubles()

    for stage <- [
          :before_adoption,
          :after_ack,
          :after_adoption,
          :stop_error,
          :abnormal_down,
          :before_descriptor,
          :missing_down,
          :cleanup_expiry
        ],
        do: ownership_double(stage)

    affinity_network()
    ordinary("a")
    ordinary("b")
    upload("/upload", ["abc", "def"], "progressive_upload")
    upload("/tiny-upload", List.duplicate(:binary.copy("x", 16_384), 64), "tiny_window_1mib")
    for zero? <- [true, false], declared? <- [true, false], do: trailers(zero?, declared?)

    for name <- ["wrong_ca", "wrong_hostname", "absent_trust", "address_policy"],
        do: negative(name)

    cancel_case("pending_headers", "/delayed-headers")
    cancel_case("unacknowledged_response", "/stalled-response")
    cancel_case("blocked_upload", "/blocked-upload")
    cancel_case("owner_loss", "/owner-loss")
    barrier("final_snapshot")
    emit("done", %{status: "PASS", checks: length(Process.get(:checks, []))})
  end
end

if System.get_env("GAOXY_SESSION_PROBE_LOAD_ONLY") != "1", do: Gaoxy.SessionPublicProbe.run()
