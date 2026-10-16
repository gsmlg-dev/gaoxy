defmodule Gaoxy.HTTP.HTTP2.WorkerAccountingTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.HTTP2.WorkerAccounting
  alias Gaoxy.HTTP.{Exchange, Request}
  alias Gaoxy.HTTP.HTTP2.{Stream, Transport}
  alias Gaoxy.Admission.WorkerBootstrap
  @moduletag :native_worker_constructor

  test "whole post-fixed point pays every complete constructor and its numeric summaries" do
    {state,stream} = fixture()
    verify(state,stream)
  end

  test "large initialized endpoint is retained in full with no invented configuration ceiling" do
    {state,stream} = fixture()
    {:ok,{:native_http2_worker_v1,n0,w0}} = WorkerAccounting.reservation(state,stream)
    endpoint = {__MODULE__,%{initialized: :binary.copy(<<42>>,131_073), nested: {make_ref(),self()}}}
    state = put_in(state.spec.handler_options.endpoint,endpoint)
    {n,w} = verify(state,stream)
    assert n > n0 + 3 * 131_073
    assert w > w0 + 3 * 131_073
  end

  test "original signed deadlines, complete request and integer widths are measured" do
    {state,stream} = fixture()
    for value <- [0,255,256,2_147_483_647,2_147_483_648,18_446_744_073_709_551_616] do
      # Arithmetic-only constructors: no Gate accepts these synthetic inputs.
      state = put_in(state.reserves.stream,value)
      state = put_in(state.limits.request_timeout,value+30_000)
      stream = %{stream|request: %{stream.request|head_bytes: value}, deadline: -value-1}
      {n,w} = verify(state,stream)
      assert w == n + 2*value
    end
  end

  test "every Exchange field and original initialized endpoint changes the charged envelope" do
    {state,stream} = fixture()
    {_n0,w0} = verify(state,stream)
    state = %{state|peer_cert: :binary.copy(<<7>>,80_000),
      service: {:service,:binary.copy(<<8>>,2_000)},instance: %{name: :binary.copy(<<9>>,2_000)}}
    stream = %{stream|request: %{stream.request|headers: [{"x-large",:binary.copy(<<10>>,12_000)}]}}
    {_n,w} = verify(state,stream)
    assert w > w0 + 4*96_000
  end

  test "finite rejection and a stale diagnostic plan cannot return rows" do
    {state,stream} = fixture()
    assert {:error,:worker_capacity} = WorkerAccounting.reservation(state,%{stream|deadline: nil})
    assert {:error,:worker_capacity} = WorkerAccounting.reservation(%{state|gate: :invalid},stream)
    assert {:error,:worker_capacity} = WorkerAccounting.describe(state,stream,{:native_http2_worker_v1,0,0})
  end

  test "limits insertion accounts for the absent original max_write_chunk key" do
    {state,stream} = fixture()
    verify(%{state|limits: Map.delete(state.limits,:max_write_chunk)},stream)
  end

  defp fixture do
    state = %{gate: self(),lease: make_ref(),reserves: %{stream: 196_608},
      limits: %{max_header_bytes: 32_768,max_read_chunk: 16_384,max_write_chunk: 4096,
        request_timeout: 30_000},
      spec: %{limits: %{max_bytes: 500_000_000,max_active: 128},
        handler_options: %{endpoint: {__MODULE__,%{initialized: true}}}},
      peer: {{127,0,0,1},42},local: {{127,0,0,1},443},secure: true,
      service: :test_service,instance: :test_instance,peer_cert: <<1,2,3>>}
    stream = %{id: 1,token: make_ref(),deadline: -1,initial_eof: true,
      request: %Request{method: "GET",target: "/",target_form: :origin,version: :http2,
        path: "/",query_string: "",headers: [{"host","localhost"}],head_bytes: 64}}
    {state,stream}
  end

  defp verify(state,stream) do
    {:ok,{:native_http2_worker_v1,n,w}=plan} = WorkerAccounting.reservation(state,stream)
    {:ok,report} = WorkerAccounting.describe(state,stream,plan)
    expected = constructors(state,stream,report)
    assert MapSet.new(Map.keys(expected)) == MapSet.new(Enum.map(report.roles,& &1.name))

    {a,j} = Enum.reduce(report.roles,{0,0},fn row,{a,j} ->
      {cap,count} = Map.fetch!(expected,row.name)
      assert row.cap == cap, "complete ETF cap differs for #{row.name}: #{row.cap} != #{cap}"
      assert row.multiplicity == count
      assert row.subtotal == cap*count
      assert row.owner != nil and row.lifetime != nil
      if row.family == :startup,do: {a+cap*count,j},else: {a,j+cap*count}
    end)

    # Expected totals come from independently instantiated complete source terms,
    # never a second production sum or an expected hard-coded budget constant.
    assert a <= report.startup_bytes
    assert j <= report.dispatch_bytes
    assert n == state.reserves.stream + report.startup_bytes + report.dispatch_bytes
    assert w == n + 2*stream.request.head_bytes
    assert report.iterations in 1..63
    {n,w}
  end

  defp constructors(s,r,report) do
    a = report.startup_bytes
    j = report.dispatch_bytes
    n = report.protocol_bytes
    w = report.bytes
    i = report.iterations
    owner = self()
    worker = self()
    gate = s.gate
    child_lease = make_ref()
    monitor = make_ref()
    activation = make_ref()
    expiry = make_ref()
    timer = make_ref()
    reqid = make_ref()
    # Original parent lease/token retain measured widths. Only newly generated
    # refs use the source-qualified future-reference upper bound.
    future = MapSet.new([child_lease,monitor,activation,expiry,timer,reqid])
    c = fn term -> cap(term,future) end
    args = [owner,r.id,r.token,gate,n,r.deadline]
    mfa = {Stream,:run,args}
    spawn_args = [gate,owner,activation,r.deadline,mfa]
    from = {owner,[:alias|reqid]}
    payload = {:spawn_request,s.lease,r.token,w,r.deadline,mfa}
    success = {:ok,worker,child_lease}
    # This is the longest ordinary source-controlled finite reason, checked
    # against all native/core finite constructors by the source checkpoint.
    failure = {:error,:invalid_spawn_request}
    reply = max_size(success,failure,c)
    public_result = [c.({:reply,success}),c.({:reply,failure}),
      c.({:error,{:invalid_spawn_request,gate}}),c.(:no_reply),c.(:timeout)] |> Enum.max()
    cancel_result = [c.({:reply,:ok}),c.({:reply,failure}),
      c.({:error,{:invalid_spawn_request,gate}}),c.(:no_reply),c.(:timeout)] |> Enum.max()
    lease = %{pid: worker,monitor: monitor,bytes: w,token: expiry,timer: timer,
      send: nil,drain_notify: true,request_active: true,cleanup: nil,deadline: r.deadline}
    correlation = %{owner: owner,parent_lease: s.lease,worker: worker,lease: child_lease,
      activation: activation,from: from,deadline: r.deadline,phase: :pending_activation,
      exit_seen: false,down_seen: false}
    watchdog = {:expired,child_lease,expiry}
    activated = {:gaoxy_admitted_worker_activate,activation,child_lease}
    cancel = {:cancel_spawn,s.lease,r.token}
    down_owner = {:DOWN,monitor,:process,owner,:invalid_spawn_request}
    down_gate = {:DOWN,monitor,:process,gate,:invalid_spawn_request}
    down_child = {:DOWN,monitor,:process,worker,:invalid_spawn_request}
    limits = Map.put(s.limits,:max_write_chunk,16_384)
    body = %{phase: :done,total: 0,trailers: [],trailer_bytes: 0}
    transport = {owner,r.id,r.token}
    exchange = %Exchange{request: r.request,socket: nil,gate: gate,lease: child_lease,
      deadline: r.deadline,limits: limits,body: body,buffer: "",peer: s.peer,local: s.local,
      service: s.service,instance: s.instance,response: :unset,response_trailers: [],
      close: false,route_bytes: 0,resource_pins: [],protocol_bytes: n,poll_buffer_bytes: 0,
      transport: Transport,transport_state: transport,secure: s.secure,ssl: nil,
      peer_cert: s.peer_cert,expect_sent: false}
    dispatch = {:h2_dispatch,owner,exchange,s.spec.handler_options.endpoint}
    done = {:h2_stream_done,worker,r.id,r.token,{:error,:response_failed}}
    startup = %{request: reqid,timer: timer,token: r.token,parent_lease: s.lease,
      protocol_bytes: n,bytes: w,deadline: r.deadline}
    input = {e(owner),e(gate),e(s.lease),e(r.id),e(r.token),e(r.deadline),s.reserves.stream,
      r.request.head_bytes,e(r.request),e(s.spec.handler_options.endpoint),e(limits),e(s.peer),
      e(s.local),e(s.service),e(s.instance),e(s.secure),e(s.peer_cert),
      e(s.spec.limits.max_bytes),e(s.spec.limits.max_active),e(node())+13,e(node())+27,
      e(s.limits.request_timeout)}
    plan = {:native_http2_worker_v1,n,w}

    raw = [
      {:planning_context,c.({owner,gate,s.lease,r.id,r.token,r.deadline,s.reserves.stream,r.request.head_bytes}),1},
      {:numeric_a,e(a),2},{:numeric_j,e(j),2},{:numeric_n,e(n),2},{:numeric_w,e(w),2},
      {:numeric_next,e(n),2},{:numeric_iteration,e(i),2},{:input_size_summary,e(input),1},
      {:input_summary_return,e({:ok,input}),1},
      {:input_scalar_size_roots,Enum.reduce(Tuple.to_list(input),0,fn value,sum -> sum+e(value) end),1},
      {:reservation_plan,e(plan),1},{:reservation_return,e({:ok,plan}),1},
      {:settle_return,e({:ok,{a,j,n,w,i}}),1},
      {:totals_return,e({a,j}),1},
      {:spawn_payload,c.(payload),2},{:spawn_wire,c.({:"$gen_call",from,payload}),1},
      {:spawn_from,c.(from),1},{:spawn_reply_payload,reply,2},
      {:spawn_reply_wire,max(c.({[:alias|reqid],success}),c.({[:alias|reqid],failure})),1},
      {:spawn_request_id,c.(reqid),1},{:spawn_public_result,public_result,1},
      {:spawn_alias_retirement_result,public_result,1},
      {:known_failure_control,c.(failure),1},
      {:reserved_transition,e(%{bytes: s.spec.limits.max_bytes,active: s.spec.limits.max_active}),1},
      {:mfa,c.(mfa),1},{:original_args,c.(args),1},{:gate_spawn_args,c.(spawn_args),1},
      {:spawn_mfa,c.({WorkerBootstrap,:run,spawn_args}),1},
      {:spawn_result,max(c.({worker,monitor}),c.(:error)),1},
      {:spawn_options,c.([:link,:monitor]),1},
      {:spawn_opt_frame,c.([WorkerBootstrap,:run,spawn_args,[:link,:monitor]]),1},
      {:spawn_timer_result,max(c.({:ok,timer}),c.(:error)),1},
      {:ordinary_lease,c.(lease),1},{:lease_entry,c.({child_lease,lease}),1},
      {:lease_timer_replacement_overlap,c.(lease),1},{:lease_terminal_replacement_overlap,c.(lease),1},
      {:correlation,c.(correlation),1},{:correlation_entry,c.({r.token,correlation}),1},
      {:phase_replacement_overlap,c.(correlation),1},{:terminal_replacement_overlap,c.(correlation),1},
      {:watchdog_payload,c.(watchdog),1},{:activation_continuation,c.({:activate_spawn,r.token}),1},
      {:gate_link_root,c.(gate),1},{:worker_gate_link_root,c.(worker),1},
      {:owner_link_root,c.(owner),1},{:worker_owner_link_root,c.(worker),1},
      {:gate_child_monitor_root,c.(monitor),1},{:child_owner_monitor_root,c.(monitor),1},
      {:child_gate_monitor_root,c.(monitor),1},
      {:worker_exit_envelope,c.({:EXIT,worker,:invalid_spawn_request}),2},
      {:owner_down_envelope,c.(down_owner),2},{:gate_down_envelope,c.(down_gate),2},
      {:watchdog_timer_ref,c.(timer),1},{:watchdog_timer_payload,c.(watchdog),1},
      {:trap_exit_prior_result,e(false),1},{:child_spawn_args,c.(spawn_args),1},
      {:bootstrap_run_frame,c.(spawn_args),1},{:activation_payload,c.(activated),2},
      {:activation_ref,c.(activation),1},{:bootstrap_owner_monitor_ref,c.(monitor),2},
      {:bootstrap_gate_monitor_ref,c.(monitor),2},{:bootstrap_owner_down,c.(down_owner),2},
      {:bootstrap_gate_down,c.(down_gate),2},
      {:apply_frame,c.({Stream,:run,[child_lease|args]}),1},{:apply_args,c.([child_lease|args]),1},
      {:child_lease_scalar,c.(child_lease),1},{:cancel_payload,c.(cancel),2},
      {:cancel_wire,c.({:"$gen_call",from,cancel}),1},{:cancel_from,c.(from),1},
      {:cancel_reply_wire,max(c.({[:alias|reqid],:ok}),c.({[:alias|reqid],failure})),1},
      {:cancel_reply_payload,max(c.(:ok),c.(failure)),2},
      {:native_pending_timer_payload,c.({:h2_worker_start_timeout,r.id,r.token}),1},
      {:cancel_request_id,c.(reqid),1},{:native_startup_correlation,c.(startup),1},
      {:native_timer_ref,c.(timer),1},{:native_worker_pid,c.(worker),1},
      {:native_child_lease,c.(child_lease),1},{:native_worker_monitor,c.(monitor),1},
      {:native_protocol_n,e(n),1},{:native_bytes_w,e(w),1},
      {:native_deadline,e(r.deadline),1},{:cancel_public_result,cancel_result,1},
      {:replacement_limits,c.(limits),1},{:body_map,c.(body),1},{:parent_exchange,c.(exchange),1},
      {:dispatch_envelope,c.(dispatch),2},{:child_exchange,c.(exchange),1},
      {:matched_endpoint,c.(s.spec.handler_options.endpoint),1},{:transport_state,c.(transport),1},
      {:done_payload,c.(done),2},{:finite_error_reply,c.(failure),2},
      {:child_monitor_down,c.(down_child),2},{:terminal_deadline,e(r.deadline),3},
      {:terminal_timeout,e(s.limits.request_timeout),3}
    ]

    caps = raw |> Enum.map(fn {_,size,_} -> size end) |> List.to_tuple()
    # Explicit independent complete tuple construction includes its own appended
    # size root; equality is against a real ETF measurement, not production math.
    cap_summary = summary_size(caps,e(caps))
    Map.new(raw ++ [{:numeric_cap_summary,cap_summary,2}],fn {name,size,count} -> {name,{size,count}} end)
  end

  defp summary_size(caps,assumed) do
    actual = e(Tuple.append(caps,assumed))
    if actual <= assumed,do: assumed,else: summary_size(caps,actual)
  end

  defp max_size(a,b,c), do: max(c.(a),c.(b))
  defp e(term), do: :erlang.external_size(term)
  defp cap(term,future), do: e(term)+ref_delta(term,future)
  defp ref_delta(term,future) when is_reference(term),
    do: if(MapSet.member?(future,term),do: e(node())+27-e(term),else: 0)
  defp ref_delta(term,future) when is_tuple(term),
    do: term |> Tuple.to_list() |> Enum.reduce(0,fn value,sum -> sum+ref_delta(value,future) end)
  defp ref_delta(term,future) when is_map(term),
    do: Enum.reduce(term,0,fn {key,value},sum -> sum+ref_delta(key,future)+ref_delta(value,future) end)
  defp ref_delta([head|tail],future), do: ref_delta(head,future)+ref_delta(tail,future)
  defp ref_delta(_, _), do: 0
end
