defmodule Gaoxy.HTTP.HTTP2.WorkerAccounting do
  @moduledoc false
  alias Gaoxy.HTTP.HTTP2.{Stream, Transport}
  alias Gaoxy.Admission.WorkerBootstrap
  @tag :native_http2_worker_v1
  @error {:error, :worker_capacity}
  @reasons ~w(byte_limit active_limit deadline_exceeded stale_generation invalid_spawn_request
    worker_capacity cancelled paused draining failed stopped closed timeout noproc normal shutdown killed)a

  # Numeric-only preflight. No request/MFA/Exchange/lease/report is constructed.
  # D is the original signed absolute deadline, never a positive-duration proxy.
  def reservation(state, stream) do
    with {:ok, input} <- inputs(state, stream),
         {:ok, {_a, _j, n, w, _iterations}} <- settle(input, 0, 0, 0, 0, 0) do
      {:ok, {@tag, n, w}}
    else
      _ -> @error
    end
  end

  # Diagnostic API ONLY. Production callers must charge the ordinary child lease
  # first. A pure diagnostic cannot establish Gate custody; this API is never
  # called by the production connection's pre-admission path.
  def describe(state, stream, {@tag, n, w}) do
    with {:ok, input} <- inputs(state, stream),
         {:ok, {a, j, ^n, ^w, iterations}} <- settle(input, 0, 0, 0, 0, 0) do
      caps = caps(input, a, j, n, w, n, iterations)

      roles =
        caps
        |> Tuple.to_list()
        |> Enum.with_index()
        |> Enum.map(fn {cap, index} ->
          {name, family, count, owner, lifetime} = role(index)
          %{name: name, family: family, cap: cap, multiplicity: count,
            subtotal: cap * count, owner: owner, lifetime: lifetime}
        end)

      {:ok, %{startup_bytes: a, dispatch_bytes: j, protocol_bytes: n, bytes: w,
        iterations: iterations, roles: roles}}
    else
      _ -> @error
    end
  end

  def describe(_, _, _), do: @error

  defp inputs(state, stream) do
    owner = self()
    gate = state.gate
    parent = state.lease
    id = stream.id
    token = stream.token
    deadline = stream.deadline
    p = state.reserves.stream
    head = stream.request.head_bytes

    if is_pid(gate) and node(gate) == node() and is_reference(parent) and
         is_integer(id) and id > 0 and is_reference(token) and
         is_integer(deadline) and is_integer(p) and p >= 0 and
         is_integer(head) and head >= 0 do
      # Complete original operands; no replay of endpoint.init/1, projection,
      # configuration inventory or arbitrary scalar/configuration size ceiling.
      limits = e(state.limits)
      limits =
        if Map.has_key?(state.limits, :max_write_chunk),
          do: limits - e(Map.fetch!(state.limits, :max_write_chunk)) + e(16_384),
          else: limits + e(:max_write_chunk) + e(16_384) - 2

      {:ok, {e(owner), e(gate), e(parent), e(id), e(token), e(deadline),
        p, head, e(stream.request), e(state.spec.handler_options.endpoint), limits,
        e(state.peer), e(state.local), e(Map.get(state, :service)),
        e(Map.get(state, :instance)), e(state.secure), e(state.peer_cert),
        e(state.spec.limits.max_bytes), e(state.spec.limits.max_active),
        e(node()) + 13, e(node()) + 27, e(state.limits.request_timeout)}}
    else
      @error
    end
  rescue
    _ -> @error
  end

  # Whole monotone post-fixed point. Every prior iterate is <= the next; widths
  # therefore cannot shrink on this native nonnegative A/J/N/W path. Signed D
  # is measured as an original operand and never enters that monotonicity claim.
  defp settle(input, a, j, n, w, iteration) when iteration < 64 do
    {next_a, next_j} = totals(caps(input, a, j, n, w, n, iteration))
    next_n = elem(input, 6) + next_a + next_j
    next_w = next_n + 2 * elem(input, 7)

    if next_a <= a and next_j <= j and next_n <= n and next_w <= w,
      do: {:ok, {a, j, n, w, iteration}},
      else: settle(input, max(a, next_a), max(j, next_j), max(n, next_n),
        max(w, next_w), iteration + 1)
  end

  defp settle(_, _, _, _, _, _), do: @error

  defp totals(caps), do: total(caps, 0, 0, 0)
  defp total(caps, index, a, j) when index == tuple_size(caps), do: {a, j}
  defp total(caps, index, a, j) do
    {_, family, count, _, _} = role(index)
    subtotal = count * elem(caps, index)
    if family == :startup,
      do: total(caps, index + 1, a + subtotal, j),
      else: total(caps, index + 1, a, j + subtotal)
  end

  defp caps(input, a, j, n, w, next, iteration) do
    {o, g, parent, id, token, d, p, head, request, endpoint, limits, peer, local,
      service, instance, secure, cert, max_bytes, max_active, pid, ref, timeout} = input
    args = l([o, id, token, g, e(n), d])
    mfa = t([e(Stream), e(:run), args])
    spawn_args = l([g, o, ref, d, mfa])
    spawn_mfa = t([e(WorkerBootstrap), e(:run), spawn_args])
    payload = t([e(:spawn_request), parent, token, e(w), d, mfa])
    from = t([o, alias_tag(ref)])
    success = t([e(:ok), pid, ref])
    finite = t([e(:error), reason_cap()])
    reply = max(success, finite)
    public_result = max(t([e(:reply), reply]),
      max(t([e(:error), t([reason_cap(), g])]), max(e(:no_reply), e(:timeout))))
    cancel_result = max(t([e(:reply),max(e(:ok),finite)]),
      max(t([e(:error),t([reason_cap(),g])]),max(e(:no_reply),e(:timeout))))
    lease = m([pid: pid, monitor: ref, bytes: e(w), token: ref, timer: ref,
      send: e(nil), drain_notify: e(true), request_active: e(true),
      cleanup: e(nil), deadline: d])
    correlation = m([owner: o, parent_lease: parent, worker: pid, lease: ref,
      activation: ref, from: from, deadline: d,
      phase: Enum.max([e(:pending_activation), e(:running), e(:cancelled)]),
      exit_seen: max(e(false), e(true)), down_seen: max(e(false), e(true))])
    watchdog = t([e(:expired), ref, ref])
    activation = t([e(:gaoxy_admitted_worker_activate), ref, ref])
    cancel = t([e(:cancel_spawn), parent, token])
    down_owner = t([e(:DOWN), ref, e(:process), o, reason_cap()])
    down_gate = t([e(:DOWN), ref, e(:process), g, reason_cap()])
    down_child = t([e(:DOWN), ref, e(:process), pid, reason_cap()])
    body = m([phase: max(e(:done), e(:data)), total: e(0), trailers: e([]), trailer_bytes: e(0)])
    transport = t([o, id, token])
    exchange = m([__struct__: e(Gaoxy.HTTP.Exchange), request: request, socket: e(nil),
      gate: g, lease: ref, deadline: d, limits: limits, body: body, buffer: e(""),
      peer: peer, local: local, service: service, instance: instance, response: e(:unset),
      response_trailers: e([]), close: e(false), route_bytes: e(0), resource_pins: e([]),
      protocol_bytes: e(n), poll_buffer_bytes: e(0), transport: e(Transport),
      transport_state: transport, secure: secure, ssl: e(nil), peer_cert: cert,
      expect_sent: e(false)])
    dispatch = t([e(:h2_dispatch), o, exchange, endpoint])
    done = t([e(:h2_stream_done), pid, id, token,
      max(e(:ok), t([e(:error), max(e(:endpoint_failed), e(:response_failed))]))])
    plan = t([e(@tag), e(n), e(w)])
    startup = m([request: ref, timer: ref, token: token, parent_lease: parent,
      protocol_bytes: e(n), bytes: e(w), deadline: d])

    raw = {
      t([o,g,parent,id,token,d,e(p),e(head)]),
      e(a), e(j), e(n), e(w), e(next), e(iteration), e(input),
      t([e(:ok),e(input)]),
      input |> Tuple.to_list() |> Enum.reduce(0, fn size,sum -> sum + e(size) end),
      plan, t([e(:ok), plan]), t([e(:ok), t([e(a),e(j),e(n),e(w),e(iteration)])]),
      t([e(a),e(j)]),
      payload, call(payload, from), from, reply, t([alias_tag(ref),reply]), ref,
      public_result, public_result, finite,
      m([bytes: max_bytes, active: max_active]), mfa, args, spawn_args, spawn_mfa,
      max(t([pid,ref]),e(:error)),
      l([e(:link),e(:monitor)]),
      l([e(WorkerBootstrap),e(:run),spawn_args,l([e(:link),e(:monitor)])]),
      max(t([e(:ok),ref]),e(:error)),
      lease, t([ref,lease]), lease, lease, correlation, t([token,correlation]),
      correlation, correlation, watchdog, t([e(:activate_spawn),token]),
      g, pid, o, pid, ref, ref, ref,
      t([e(:EXIT),pid,reason_cap()]), down_owner, down_gate, ref, watchdog, max(e(false),e(true)),
      spawn_args, l([g,o,ref,d,mfa]), activation, ref, ref, ref, down_owner, down_gate,
      t([e(Stream),e(:run),l([ref,o,id,token,g,e(n),d])]),
      l([ref,o,id,token,g,e(n),d]), ref,
      cancel, call(cancel,from), from, t([alias_tag(ref),max(e(:ok),finite)]),
      max(e(:ok),finite), t([e(:h2_worker_start_timeout),id,token]), ref,
      startup, ref, pid, ref, ref, e(n), e(w), d, cancel_result,
      limits, body, exchange, dispatch, exchange, endpoint, transport,
      done, finite, down_child, d, timeout
    }

    # Both complete numeric tuples plus the raw cap summary's own integer width
    # are paid. This summary has only integer leaves, no original large terms.
    Tuple.append(raw, summary_size(e(raw), e(raw)))
  end

  defp summary_size(base, assumed) do
    next = base + e(assumed) - 1
    if next <= assumed, do: assumed, else: summary_size(base, next)
  end

  defp e(term), do: :erlang.external_size(term)
  defp t(sizes), do: 1 + if(length(sizes) < 256, do: 2, else: 5) + sum_bodies(sizes)
  defp l([]), do: 2
  defp l(sizes), do: 7 + sum_bodies(sizes)
  defp sum_bodies(sizes), do: Enum.reduce(sizes, 0, fn size, sum -> sum + size - 1 end)
  defp m(fields), do: 6 + Enum.reduce(fields, 0, fn {key,size}, sum -> sum + e(key) + size - 2 end)
  defp alias_tag(ref), do: 6 + e(:alias) - 1 + ref - 1
  defp call(payload,from), do: t([e(:"$gen_call"),from,payload])
  defp reason_cap, do: Enum.reduce(@reasons, 0, fn reason, cap -> max(cap,e(reason)) end)

  # Static source-role metadata; numeric preflight visits one tuple at a time.
  # Families retain named enclosing envelopes in addition to their members.
  @roles [
    {:planning_context,:startup,1,:connection,:calculation_return},
    {:numeric_a,:startup,2,:connection,:calculation_return},
    {:numeric_j,:startup,2,:connection,:calculation_return},
    {:numeric_n,:startup,2,:connection,:calculation_return},
    {:numeric_w,:startup,2,:connection,:calculation_return},
    {:numeric_next,:startup,2,:connection,:calculation_return},
    {:numeric_iteration,:startup,2,:connection,:calculation_return},
    {:input_size_summary,:startup,1,:connection,:calculation_return},
    {:input_summary_return,:startup,1,:connection,:calculation_return},
    {:input_scalar_size_roots,:startup,1,:connection,:calculation_return},
    {:reservation_plan,:startup,1,:connection,:worker_down_and_exit},
    {:reservation_return,:startup,1,:connection,:calculation_return},
    {:settle_return,:startup,1,:connection,:calculation_return},
    {:totals_return,:startup,1,:connection,:calculation_return},
    {:spawn_payload,:startup,2,:connection_and_gate,:activation_or_worker_down_and_exit},
    {:spawn_wire,:startup,1,:gate,:activation_or_worker_down_and_exit},
    {:spawn_from,:startup,1,:gate,:worker_down_and_exit},
    {:spawn_reply_payload,:startup,2,:connection_and_gate,:worker_down_and_exit},
    {:spawn_reply_wire,:startup,1,:connection,:worker_down_and_exit},
    {:spawn_request_id,:startup,1,:connection,:worker_down_and_exit},
    {:spawn_public_result,:startup,1,:connection,:worker_down_and_exit},
    {:spawn_alias_retirement_result,:startup,1,:connection,:worker_down_and_exit},
    {:known_failure_control,:startup,1,:connection_and_gate,:worker_down_and_exit},
    {:reserved_transition,:startup,1,:gate,:spawn_callback_return},
    {:mfa,:startup,1,:gate,:spawn_callback_return},
    {:original_args,:startup,1,:gate,:spawn_callback_return},
    {:gate_spawn_args,:startup,1,:gate,:spawn_callback_return},
    {:spawn_mfa,:startup,1,:gate,:spawn_callback_return},
    {:spawn_result,:startup,1,:gate,:spawn_callback_return},
    {:spawn_options,:startup,1,:gate,:spawn_callback_return},
    {:spawn_opt_frame,:startup,1,:gate,:spawn_callback_return},
    {:spawn_timer_result,:startup,1,:gate,:spawn_callback_return},
    {:ordinary_lease,:startup,1,:gate,:worker_down_and_exit},
    {:lease_entry,:startup,1,:gate,:worker_down_and_exit},
    {:lease_timer_replacement_overlap,:startup,1,:gate,:spawn_callback_return},
    {:lease_terminal_replacement_overlap,:startup,1,:gate,:worker_down_and_exit},
    {:correlation,:startup,1,:gate,:worker_down_and_exit},
    {:correlation_entry,:startup,1,:gate,:worker_down_and_exit},
    {:phase_replacement_overlap,:startup,1,:gate,:worker_down_and_exit},
    {:terminal_replacement_overlap,:startup,1,:gate,:worker_down_and_exit},
    {:watchdog_payload,:startup,1,:gate,:worker_down_and_exit},
    {:activation_continuation,:startup,1,:gate,:worker_down_and_exit},
    {:gate_link_root,:startup,1,:child,:worker_down_and_exit},
    {:worker_gate_link_root,:startup,1,:gate,:worker_down_and_exit},
    {:owner_link_root,:startup,1,:child,:worker_down_and_exit},
    {:worker_owner_link_root,:startup,1,:connection,:worker_down_and_exit},
    {:gate_child_monitor_root,:startup,1,:gate,:worker_down_and_exit},
    {:child_owner_monitor_root,:startup,1,:child,:worker_down_and_exit},
    {:child_gate_monitor_root,:startup,1,:child,:worker_down_and_exit},
    {:worker_exit_envelope,:startup,2,:gate_and_connection,:worker_down_and_exit},
    {:owner_down_envelope,:startup,2,:child,:worker_down_and_exit},
    {:gate_down_envelope,:startup,2,:child,:worker_down_and_exit},
    {:watchdog_timer_ref,:startup,1,:gate,:worker_down_and_exit},
    {:watchdog_timer_payload,:startup,1,:gate,:worker_down_and_exit},
    {:trap_exit_prior_result,:startup,1,:gate,:init_return},
    {:child_spawn_args,:startup,1,:child,:activation},
    {:bootstrap_run_frame,:startup,1,:child,:activation},
    {:activation_payload,:startup,2,:gate_and_child,:worker_down_and_exit},
    {:activation_ref,:startup,1,:child,:activation},
    {:bootstrap_owner_monitor_ref,:startup,2,:child,:activation},
    {:bootstrap_gate_monitor_ref,:startup,2,:child,:activation},
    {:bootstrap_owner_down,:startup,2,:child,:activation},
    {:bootstrap_gate_down,:startup,2,:child,:activation},
    {:apply_frame,:startup,1,:child,:request_end},
    {:apply_args,:startup,1,:child,:request_end},
    {:child_lease_scalar,:startup,1,:child,:request_end},
    {:cancel_payload,:startup,2,:connection_and_gate,:worker_down_and_exit},
    {:cancel_wire,:startup,1,:gate,:worker_down_and_exit},
    {:cancel_from,:startup,1,:gate,:worker_down_and_exit},
    {:cancel_reply_wire,:startup,1,:connection,:worker_down_and_exit},
    {:cancel_reply_payload,:startup,2,:connection_and_gate,:worker_down_and_exit},
    {:native_pending_timer_payload,:startup,1,:connection,:worker_down_and_exit},
    {:cancel_request_id,:startup,1,:connection,:worker_down_and_exit},
    {:native_startup_correlation,:startup,1,:connection,:worker_down_and_exit},
    {:native_timer_ref,:startup,1,:connection,:worker_down_and_exit},
    {:native_worker_pid,:startup,1,:connection,:worker_down_and_exit},
    {:native_child_lease,:startup,1,:connection,:worker_down_and_exit},
    {:native_worker_monitor,:startup,1,:connection,:worker_down_and_exit},
    {:native_protocol_n,:startup,1,:connection,:worker_down_and_exit},
    {:native_bytes_w,:startup,1,:connection,:worker_down_and_exit},
    {:native_deadline,:startup,1,:connection,:worker_down_and_exit},
    {:cancel_public_result,:startup,1,:connection,:worker_down_and_exit},
    {:replacement_limits,:dispatch,1,:connection,:dispatch_return},
    {:body_map,:dispatch,1,:connection,:dispatch_return},
    {:parent_exchange,:dispatch,1,:connection,:dispatch_return},
    {:dispatch_envelope,:dispatch,2,:connection_and_child,:request_end},
    {:child_exchange,:dispatch,1,:child,:request_end},
    {:matched_endpoint,:dispatch,1,:child,:request_end},
    {:transport_state,:dispatch,1,:connection_and_child,:request_end},
    {:done_payload,:startup,2,:connection_and_child,:worker_down_and_exit},
    {:finite_error_reply,:startup,2,:connection_and_child,:worker_down_and_exit},
    {:child_monitor_down,:startup,2,:connection_and_gate,:worker_down_and_exit},
    {:terminal_deadline,:startup,3,:connection_and_child,:worker_down_and_exit},
    {:terminal_timeout,:startup,3,:connection_and_child,:worker_down_and_exit},
    {:numeric_cap_summary,:startup,2,:connection,:calculation_return}
  ]

  for {metadata,index} <- Enum.with_index(@roles) do
    defp role(unquote(index)), do: unquote(Macro.escape(metadata))
  end
end
