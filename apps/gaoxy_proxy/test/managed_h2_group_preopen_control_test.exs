defmodule Gaoxy.Proxy.ManagedH2GroupPreopenControlTest do
  use ExUnit.Case, async: true

  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.HTTP.Session
  alias Gaoxy.Proxy.{ManagedH2Client, ManagedH2Preparation, UpstreamGroups, UpstreamTransports}

  @protocols [:http2, :h2c]
  @stages [:open, :bind]
  @terminal [
    :cancel,
    :expire,
    :consumed,
    :cleanup_cancel,
    :down,
    :opening_expired,
    :total_expired
  ]
  @signed_min -9_223_372_036_854_775_808
  @signed_max 9_223_372_036_854_775_807
  @invalid_events [
    :wrong_cleanup_token,
    :nil_cleanup_deadline,
    :atom_cleanup_deadline,
    :float_cleanup_deadline,
    :underflow_cleanup_deadline,
    :overflow_cleanup_deadline,
    :expanded_cleanup_cancel,
    :wrong_down_reference,
    :wrong_down_pid,
    :nonpid_down_pid,
    :wrong_down_type,
    :expanded_down,
    :other_cast,
    :expanded_cancel_cast,
    :unrelated
  ]
  @dropped [
    :request_options,
    :managed_transport,
    :selector,
    :awaiting_transport,
    :transport_handoff,
    :submitted_url
  ]

  # Structural callback fixtures exercise the real continuations. G/T handles,
  # selections and pins below are identities only: no owner grants authority,
  # no activated cleanup token exists and no Fetch/client override is installed.
  # There is deliberately no no-message bind test with fabricated owner replies.
  for protocol <- @protocols, stage <- @stages, kind <- @terminal do
    test "#{protocol} #{stage} consumes queued #{kind} through its ordinary terminal semantics" do
      {state, continuation} = fixture(unquote(protocol), unquote(stage))
      kind = unquote(kind)
      event = terminal_event(kind, state)
      send(self(), event)

      result = Session.handle_continue(continuation, state)

      refute_receive ^event, 0
      assert_terminal(result, state, kind)
    end
  end

  for protocol <- @protocols, stage <- @stages, invalid <- @invalid_events do
    test "#{protocol} #{stage} leaves #{invalid} pending before recognized cancel" do
      {state, continuation} = fixture(unquote(protocol), unquote(stage))
      invalid = invalid_event(unquote(invalid), state)
      cancel = terminal_event(:cancel, state)
      send(self(), invalid)
      send(self(), cancel)

      result = Session.handle_continue(continuation, state)

      refute_receive ^cancel, 0
      assert_terminal(result, state, :cancel)
      assert_receive ^invalid, 100
    end
  end

  for protocol <- @protocols, invalid <- @invalid_events do
    test "#{protocol} open leaves lone #{invalid} pending and retains activation denial" do
      {state, continuation} = fixture(unquote(protocol), :open)
      event = invalid_event(unquote(invalid), state)
      send(self(), event)

      result = Session.handle_continue(continuation, state)

      assert_gate_denied(result, state)
      assert_receive ^event, 100
    end
  end

  for protocol <- @protocols,
      stage <- @stages,
      {first, second} <- [
        {:consumed, :cancel},
        {:cancel, :total_expired},
        {:cleanup_cancel, :consumed},
        {:down, :expire},
        {:opening_expired, :cancel}
      ] do
    test "#{protocol} #{stage} selects oldest #{first} and leaves later #{second} plus sentinel" do
      {state, continuation} = fixture(unquote(protocol), unquote(stage))
      first_kind = unquote(first)
      first = terminal_event(first_kind, state)
      second = terminal_event(unquote(second), state)
      sentinel = {:preopen_sentinel, make_ref()}
      send(self(), sentinel)
      send(self(), first)
      send(self(), second)

      result = Session.handle_continue(continuation, state)

      refute_receive ^first, 0
      assert_terminal(result, state, first_kind)
      assert_receive ^sentinel, 100
      assert_receive ^second, 100
    end
  end

  for protocol <- @protocols,
      stage <- @stages,
      kind <- [:cleanup_cancel, :down],
      reason_kind <- [:function, :binary] do
    test "#{protocol} #{stage} discards direct #{reason_kind} reason from queued #{kind}" do
      {state, continuation} = fixture(unquote(protocol), unquote(stage))
      kind = unquote(kind)
      ordinary_event = terminal_event(kind, state)
      raw = Map.fetch!(opaque_reason(), unquote(reason_kind))
      event = put_elem(ordinary_event, reason_index(kind), raw)
      send(self(), event)

      result = Session.handle_continue(continuation, state)

      refute_receive ^event, 0
      assert_terminal(result, state, kind)
    end
  end

  for protocol <- @protocols,
      stage <- @stages,
      {label, deadline} <- [{:signed_min, @signed_min}, {:signed_max, @signed_max}] do
    test "#{protocol} #{stage} accepts exact #{label} service cleanup deadline" do
      {state, continuation} = fixture(unquote(protocol), unquote(stage))
      deadline = unquote(deadline)
      event = {:gaoxy_cleanup_cancel, state.token, opaque_reason(), deadline}
      send(self(), event)

      result = Session.handle_continue(continuation, state)

      refute_receive ^event, 0
      assert_terminal(result, state, :cleanup_cancel, deadline)
    end
  end

  for protocol <- @protocols, stage <- @stages, kind <- [:cancel, :consumed] do
    test "#{protocol} #{stage} queued #{kind} precedes already elapsed total deadline" do
      {state, continuation} = fixture(unquote(protocol), unquote(stage))
      state = with_deadlines(state, Lifecycle.now() - 1, Lifecycle.now() - 2)
      kind = unquote(kind)
      event = terminal_event(kind, state)
      send(self(), event)

      result = Session.handle_continue(continuation, state)

      refute_receive ^event, 0
      assert_terminal(result, state, kind)
    end
  end

  for protocol <- @protocols, stage <- @stages do
    test "#{protocol} #{stage} queued expire reports original elapsed total deadline" do
      {state, continuation} = fixture(unquote(protocol), unquote(stage))
      state = with_deadlines(state, Lifecycle.now() - 1, Lifecycle.now() - 2)
      event = terminal_event(:expire, state)
      send(self(), event)

      result = Session.handle_continue(continuation, state)

      refute_receive ^event, 0
      assert_terminal(result, state, :expired_expire)
    end
  end

  for protocol <- @protocols do
    test "#{protocol} bind nil upload still consumes queued cancel before owner bind" do
      {state, continuation} = fixture(unquote(protocol), :bind, nil)
      event = terminal_event(:cancel, state)
      send(self(), event)

      result = Session.handle_continue(continuation, state)

      refute_receive ^event, 0
      assert_terminal(result, state, :cancel)
    end

    test "#{protocol} no-message open retains literal accounting denial" do
      {state, continuation} = fixture(unquote(protocol), :open)
      assert_gate_denied(Session.handle_continue(continuation, state), state)
      assert {:error, :accounting_not_ready} == Gaoxy.Proxy.ManagedH2GroupBoundary.activation()
    end
  end

  for protocol <- @protocols,
      stage <- @stages,
      {local, reason} <- [
        {:cancelled, :cancelled},
        {:consumed, :cancelled},
        {:total_elapsed, :request_timeout},
        {:opening_elapsed, :timeout}
      ] do
    test "#{protocol} #{stage} no-message #{local} retains existing local failure" do
      {state, continuation} = fixture(unquote(protocol), unquote(stage))
      state = local_state(state, unquote(local))
      reason = unquote(reason)

      expected =
        state
        |> expected_drop()
        |> Map.merge(%{cancelled: true, consumed: true, outcome: :cancelled})

      assert {:stop, :normal, ^expected} = Session.handle_continue(continuation, state)
      assert_error(reason)
      assert_no_ready_or_extra_error()
    end
  end

  for protocol <- @protocols, stage <- @stages do
    test "#{protocol} #{stage} rejects malformed stage before consuming queued cancel" do
      {state, continuation} = fixture(unquote(protocol), unquote(stage))
      state = malformed_stage(state, unquote(stage))
      event = terminal_event(:cancel, state)
      send(self(), event)

      expected =
        state
        |> expected_drop()
        |> Map.merge(%{cancelled: true, consumed: true, outcome: :cancelled})

      assert {:stop, :normal, ^expected} = Session.handle_continue(continuation, state)
      assert_error(:invalid_request)
      assert_receive ^event, 100
      assert_no_ready_or_extra_error()
    end
  end

  defp assert_terminal(result, state, kind, requested_deadline \\ nil) do
    consumed? = kind == :consumed

    outcome =
      cond do
        consumed? -> :success
        kind == :opening_expired and state.original_request != nil -> :upstream_failure
        true -> :cancelled
      end

    requested_deadline =
      if kind == :cleanup_cancel and requested_deadline == nil,
        do: state.deadline + 111,
        else: requested_deadline

    expected =
      state
      |> expected_drop()
      |> Map.merge(%{cancelled: not consumed?, consumed: true, outcome: outcome})

    expected =
      if kind == :cleanup_cancel,
        do: %{expected | cleanup_requested_deadline: requested_deadline},
        else: expected

    if consumed?,
      do: assert(result === {:noreply, expected}),
      else: assert(result === {:stop, :normal, expected})

    # Exact state equality includes deadlines, monitors, G/T handles, selection
    # tokens, pins, timers, cleanup flags and original public handle/completion.
    actual = elem(result, tuple_size(result) - 1)
    assert actual.request === state.request
    assert actual.original_request === state.original_request

    case kind do
      kind when kind in [:expire, :opening_expired] -> assert_error(:timeout)
      kind when kind in [:total_expired, :expired_expire] -> assert_error(:request_timeout)
      _ -> :ok
    end

    assert_no_ready_or_extra_error()
    refute_receive {:raw_reason_invoked, _}, 0
  end

  defp assert_gate_denied(result, state) do
    expected =
      state
      |> expected_drop()
      |> Map.merge(%{cancelled: true, consumed: true, outcome: :cancelled})

    assert result === {:stop, :normal, expected}
    assert_error(:unavailable)
    assert_no_ready_or_extra_error()
  end

  defp assert_error(reason) do
    session = self()
    assert_receive {:gaoxy_proxy_http, ^session, {:error, ^reason}}, 100
  end

  defp assert_no_ready_or_extra_error do
    session = self()
    refute_receive {:gaoxy_proxy_http, ^session, {:ready, _, _, _}}, 0
    refute_receive {:gaoxy_proxy_http, ^session, {:error, _}}, 0
  end

  defp expected_drop(state) do
    state
    |> Map.merge(%{
      config: %{limits: state.config.limits},
      client: ManagedH2Client,
      managed_path: true
    })
    |> Map.merge(Map.new(@dropped, &{&1, nil}))
  end

  defp terminal_event(:cancel, _), do: {:"$gen_cast", :cancel}
  defp terminal_event(:expire, _), do: {:"$gen_cast", :expire}
  defp terminal_event(:consumed, _), do: {:"$gen_cast", :consumed}
  defp terminal_event(:opening_expired, _), do: :opening_expired
  defp terminal_event(:total_expired, _), do: :total_expired

  defp terminal_event(:cleanup_cancel, state),
    do: {:gaoxy_cleanup_cancel, state.token, opaque_reason(), state.deadline + 111}

  defp terminal_event(:down, state) do
    [{ref, pid}] = Map.to_list(state.monitors)
    {:DOWN, ref, :process, pid, opaque_reason()}
  end

  defp invalid_event(kind, state) do
    [{ref, pid}] = Map.to_list(state.monitors)

    case kind do
      :wrong_cleanup_token ->
        {:gaoxy_cleanup_cancel, make_ref(), :cancel, state.deadline}

      :nil_cleanup_deadline ->
        {:gaoxy_cleanup_cancel, state.token, :cancel, nil}

      :atom_cleanup_deadline ->
        {:gaoxy_cleanup_cancel, state.token, :cancel, :infinity}

      :float_cleanup_deadline ->
        {:gaoxy_cleanup_cancel, state.token, :cancel, 1.0}

      :underflow_cleanup_deadline ->
        {:gaoxy_cleanup_cancel, state.token, :cancel, @signed_min - 1}

      :overflow_cleanup_deadline ->
        {:gaoxy_cleanup_cancel, state.token, :cancel, @signed_max + 1}

      :expanded_cleanup_cancel ->
        {:gaoxy_cleanup_cancel, state.token, :cancel, state.deadline, :extra}

      :wrong_down_reference ->
        {:DOWN, make_ref(), :process, pid, :normal}

      :wrong_down_pid ->
        {:DOWN, ref, :process, other_pid(), :normal}

      :nonpid_down_pid ->
        {:DOWN, ref, :process, make_ref(), :normal}

      :wrong_down_type ->
        {:DOWN, ref, :port, pid, :normal}

      :expanded_down ->
        {:DOWN, ref, :process, pid, :normal, :extra}

      :other_cast ->
        {:"$gen_cast", :other}

      :expanded_cancel_cast ->
        {:"$gen_cast", {:cancel, :extra}}

      :unrelated ->
        {:unrelated_preopen_control, make_ref()}
    end
  end

  defp reason_index(:cleanup_cancel), do: 2
  defp reason_index(:down), do: 4

  defp opaque_reason do
    large = :binary.copy("raw-terminal-reason", 8_192)
    owner = self()

    hidden = fn ->
      send(owner, {:raw_reason_invoked, byte_size(large)})
      raise "raw reason executed"
    end

    %{binary: large, function: hidden}
  end

  defp with_deadlines(state, deadline, opening) do
    state = %{state | deadline: deadline, opening_deadline: opening}

    case state.request_options do
      {:group_prepared, options} ->
        %{
          state
          | request_options:
              {:group_prepared, %{options | deadline: deadline, opening_deadline: opening}}
        }

      nil ->
        state
    end
  end

  defp local_state(state, :cancelled), do: %{state | cancelled: true}
  defp local_state(state, :consumed), do: %{state | consumed: true}

  defp local_state(state, :total_elapsed),
    do: with_deadlines(state, Lifecycle.now() - 1, Lifecycle.now() - 2)

  defp local_state(state, :opening_elapsed),
    do: with_deadlines(state, state.deadline, Lifecycle.now() - 1)

  defp malformed_stage(state, :open), do: %{state | request_options: nil}
  defp malformed_stage(state, :bind), do: %{state | submitted_url: nil}

  defp fixture(protocol, stage, upload \\ self()) do
    now = Lifecycle.now()
    {source, selected} = source_fixture(protocol, now)
    assert {:ok, staged, :group_open} = Session.prepare_group_open(source, selected, now)
    assert staged.token == nil
    assert staged.client == ManagedH2Client
    assert staged.deadline === now + 60_000
    assert staged.opening_deadline === now + 30_000

    case stage do
      :open ->
        {staged, :group_open}

      :bind ->
        original = public_handle()

        assert {:ok, bound, {:group_bind, ^upload}} =
                 Session.group_open_result(staged, {:ok, original, upload}, now)

        assert bound.request === original and bound.original_request === original
        assert bound.original_request.completion === original.promise.completion
        {bound, {:group_bind, upload}}
    end
  end

  defp source_fixture(protocol, now) do
    scheme = if protocol == :http2, do: "https", else: "http"
    origin = scheme <> "://upstream.test"

    transport = %{
      provider: UpstreamTransports,
      owner: self(),
      owner_epoch: make_ref(),
      resource: make_ref()
    }

    group = %{
      provider: UpstreamGroups,
      owner: self(),
      owner_epoch: make_ref(),
      group: "group",
      generation: make_ref(),
      max_url_bytes: 8_192,
      transports: [transport],
      execution_profile: :managed_h2
    }

    limits = %{
      max_chunk_bytes: 1_024,
      opening_timeout: 30_000,
      idle_timeout: 3_000,
      write_timeout: 700,
      max_lifetime: 60_000
    }

    config = %Gaoxy.Proxy.HTTP{
      uri: URI.parse(origin),
      upstream_protocol: protocol,
      client: ManagedH2Client,
      transport: transport,
      limits: limits,
      cacertfile: nil,
      connect_address: nil
    }

    selected = %{id: "member", config: config, max_inflight: 32}

    pin = %{
      provider: UpstreamTransports,
      owner: transport.owner,
      owner_epoch: transport.owner_epoch,
      operation: make_ref(),
      ref: make_ref(),
      handles: [transport],
      kind: :request,
      holder: self()
    }

    state = %{
      owner: self(),
      service: self(),
      instance: self(),
      gate: self(),
      token: nil,
      config: %{group: group, limits: limits},
      selector: {:group, group, []},
      selection: {group, make_ref()},
      transport_selection: {transport, make_ref()},
      transport_pins: [pin],
      managed_transport: checked_client(protocol, origin),
      transport_handoff: make_ref(),
      awaiting_transport: nil,
      client: Gaoxy.Proxy.HTTPFetchClient,
      managed_path: false,
      request_options: neutral(),
      request: nil,
      original_request: nil,
      submitted_url: nil,
      started_at: now,
      activated_at: now,
      deadline: now + 60_000,
      opening_deadline: now + 30_000,
      opening_timer: make_ref(),
      total_timer: make_ref(),
      poll_timer: nil,
      monitors: %{make_ref() => self()},
      cleanup_deadline: nil,
      cleanup_requested_deadline: nil,
      cleanup_started: false,
      outcome: :cancelled,
      cancelled: false,
      consumed: false,
      headers: false,
      delivery: nil,
      trailers: []
    }

    {state, selected}
  end

  defp neutral do
    %{
      target: "/a%2Fb?",
      method: :post,
      fields: [{"Content-Length", "3"}, {"X-Trace", "one"}, {"x-trace", "two"}],
      body_mode: {:length, 3},
      max_upload_bytes: 65_536,
      request_limits: %{
        max_headers: 256,
        max_header_bytes: 65_536,
        max_trailers: 128,
        max_trailer_bytes: 65_536
      }
    }
  end

  defp checked_client(protocol, origin) do
    {:ok, policy, _} =
      ManagedH2Preparation.prepare_policy(%{
        protocol: protocol,
        origin: origin,
        connect_address: {127, 0, 0, 1},
        trust: if(protocol == :http2, do: [<<48, 3, 2, 1, 1>>], else: nil)
      })

    %{
      policy: policy,
      transport_scope: struct(HTTP.ManagedTransport),
      fetch_options: [
        http_version: protocol,
        tls_backend: :ssl,
        http2_profile: :native_v1,
        http2_reuse: true,
        redirect: :manual,
        request_mode: :proxy,
        decode_body: false,
        stream_response: true,
        telemetry: false
      ]
    }
  end

  defp public_handle do
    completion = %HTTP.RequestCompletion{tracker: self(), latch: make_ref(), unsupported: nil}
    task = %Task{owner: self(), pid: self(), ref: make_ref(), mfa: {:erlang, :apply, 2}}

    %{
      promise: %HTTP.Promise{task: task, completion: completion},
      completion: completion,
      stream: nil,
      resolved: false
    }
  end

  # Scalar fixture only; no process is created or contacted through this PID.
  defp other_pid, do: :erlang.list_to_pid(~c"<0.32766.0>")
end
