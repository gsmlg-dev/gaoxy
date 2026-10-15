defmodule Gaoxy.Proxy.ManagedH2GroupAccountingTransitionsTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.HTTP.Session

  alias Gaoxy.Proxy.{
    ManagedH2Client,
    ManagedH2Preparation,
    ManagedH2GroupAccounting,
    UpstreamGroups,
    UpstreamTransports
  }

  test "real preparation validates each original charged boundary role before transfer" do
    {state, selected} = fixture()
    assert :ok = ManagedH2GroupAccounting.validate({:state, :session}, state)
    {result, calls} = traced(fn -> Session.prepare_group_open(state, selected, 2_000) end)
    assert {:ok, staged, :group_open} = result
    assert :ok = ManagedH2GroupAccounting.validate({:state, :session}, staged)

    for role <- [:selected, :neutral, :checked, :context, :request, :options] do
      assert Enum.any?(calls, fn [selector, _original] -> selector === role end), inspect(role)
    end

    assert Enum.count(calls, fn [selector, _] -> selector === {:state, :session} end) >= 2

    assert Enum.any?(calls, fn [selector, original] ->
             selector === :selected and original === selected
           end)

    assert Enum.any?(calls, fn [selector, original] ->
             selector === :neutral and original === state.request_options
           end)

    assert Enum.any?(calls, fn [selector, original] ->
             selector === :checked and original === state.managed_transport
           end)
  end

  for mutation <- [
        :expanded,
        :monitor,
        :outcome,
        :cleanup_time,
        :delivery,
        :trailers,
        :selector_pin
      ] do
    test "#{mutation} retained source is refused before preparing or retaining options" do
      {state, selected} = fixture()
      original = mutate(unquote(mutation), state)

      assert {:error, :invalid_group_accounting} =
               ManagedH2GroupAccounting.validate({:state, :session}, original)

      assert {:error, :invalid_request, dropped} =
               Session.prepare_group_open(original, selected, 2_000)

      assert dropped.request_options === nil
      assert dropped.managed_transport === nil
      assert dropped.original_request === nil
      assert dropped.transport_selection === original.transport_selection
      assert dropped.transport_pins === original.transport_pins
      assert dropped.selection === original.selection
    end
  end

  test "invalid successful upload preserves supported original completion for genuine cleanup" do
    {state, selected} = fixture()
    assert {:ok, staged, :group_open} = Session.prepare_group_open(state, selected, 2_000)
    original = public_handle()

    for result <- [
          {:ok, original, :invalid_upload},
          {:ok, original},
          {:ok, original, nil, :extra}
        ] do
      assert {:error, {:cleanup_unconfirmed, :invalid_response}, dropped} =
               Session.group_open_result(staged, result, 2_000)

      assert dropped.request === original
      assert dropped.original_request === original
      assert ManagedH2Client.completion(dropped.original_request) === original.completion
      assert dropped.request_options === nil and dropped.submitted_url === nil
    end
  end

  test "supported success is captured before rejecting an expanded staged source" do
    {state, selected} = fixture()
    assert {:ok, staged, :group_open} = Session.prepare_group_open(state, selected, 2_000)
    original = public_handle()

    assert {:error, :invalid_request, dropped} =
             Session.group_open_result(
               Map.put(staged, :unaccounted, []),
               {:ok, original, nil},
               2_000
             )

    assert dropped.original_request === original and dropped.request === original
    assert dropped.request_options === nil
  end

  test "success transition checks the complete original result and resulting retained state" do
    {state, selected} = fixture()
    assert {:ok, staged, :group_open} = Session.prepare_group_open(state, selected, 2_000)
    original = public_handle()

    {result, calls} =
      traced(fn -> Session.group_open_result(staged, {:ok, original, nil}, 2_000) end)

    assert {:ok, bound, {:group_bind, nil}} = result
    assert :ok = ManagedH2GroupAccounting.validate({:state, :session}, bound)

    assert Enum.any?(calls, fn [selector, value] ->
             selector === :open_result and value === {:ok, original, nil}
           end)

    assert Enum.any?(calls, fn [selector, value] ->
             selector === {:state, :session} and value === bound
           end)
  end

  defp mutate(:expanded, s), do: Map.put(s, :unaccounted, [])
  defp mutate(:monitor, s), do: %{s | monitors: %{make_ref() => :wrong_target}}
  defp mutate(:outcome, s), do: %{s | outcome: %{raw_diagnostic: fn -> :never_measure end}}
  defp mutate(:cleanup_time, s), do: %{s | cleanup_deadline: 9_223_372_036_854_775_808}
  defp mutate(:delivery, s), do: %{s | delivery: self()}
  defp mutate(:trailers, s), do: %{s | trailers: [{"x", "v"} | :improper]}

  defp mutate(:selector_pin, s) do
    {:group, group, [pin]} = s.selector
    %{s | selector: {:group, group, [Map.put(pin, :holder, self())]}}
  end

  defp traced(fun) do
    parent = self()

    {pid, monitor} =
      spawn_monitor(fn ->
        receive do
          :run -> send(parent, {:transition_result, self(), fun.()})
        after
          5_000 -> exit(:test_start_deadline)
        end
      end)

    :erlang.trace_pattern({ManagedH2GroupAccounting, :validate, 2}, true, [:local])
    :erlang.trace(pid, true, [:call, {:tracer, parent}])

    try do
      send(pid, :run)

      result =
        receive do
          {:transition_result, ^pid, value} -> value
          {:DOWN, ^monitor, :process, ^pid, reason} -> flunk(inspect(reason))
        after
          5_000 -> flunk("transition did not complete")
        end

      delivered = :erlang.trace_delivered(pid)
      assert_receive {:trace_delivered, ^pid, ^delivered}, 5_000
      assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, 5_000
      {result, calls(pid, [])}
    after
      :erlang.trace_pattern({ManagedH2GroupAccounting, :validate, 2}, false, [:local])
      if Process.alive?(pid), do: Process.exit(pid, :kill)
      Process.demonitor(monitor, [:flush])
    end
  end

  defp calls(pid, acc) do
    receive do
      {:trace, ^pid, :call, {ManagedH2GroupAccounting, :validate, args}} ->
        calls(pid, [args | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp fixture(protocol \\ :http2, raw_port? \\ false) do
    scheme = if protocol == :http2, do: "https", else: "http"
    port = if protocol == :http2, do: "00443", else: "00080"
    origin = scheme <> "://upstream.test" <> if(raw_port?, do: ":" <> port, else: "")

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

    config = %Gaoxy.Proxy.HTTP{
      uri: URI.parse(origin),
      upstream_protocol: protocol,
      client: ManagedH2Client,
      transport: transport,
      cacertfile: nil,
      connect_address: nil,
      limits: effective_limits()
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
      token: make_ref(),
      config: %Gaoxy.Proxy.GroupEndpoint{group: group, limits: endpoint_limits()},
      selector:
        {:group, group,
         [
           %{
             provider: UpstreamGroups,
             owner: group.owner,
             owner_epoch: group.owner_epoch,
             ref: make_ref(),
             operation: make_ref(),
             handles: [group],
             kind: :request
           }
         ]},
      selection: {group, make_ref()},
      transport_selection: {transport, make_ref()},
      transport_pins: [pin],
      managed_transport: checked_client(protocol, scheme <> "://upstream.test"),
      transport_handoff: make_ref(),
      awaiting_transport: nil,
      client: ManagedH2Client,
      managed_path: true,
      request_options: neutral(),
      request: nil,
      original_request: nil,
      submitted_url: nil,
      started_at: 1_000,
      activated_at: 1_500,
      deadline: 40_000,
      opening_deadline: 10_000,
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

  defp endpoint_limits,
    do: %{
      max_chunk_bytes: 65_536,
      opening_timeout: 5_000,
      idle_timeout: 60_000,
      write_timeout: 5_000,
      max_lifetime: 30_000
    }

  defp effective_limits,
    do: %{
      max_chunk_bytes: 1_024,
      opening_timeout: 4_000,
      idle_timeout: 3_000,
      write_timeout: 700,
      max_lifetime: 10_000
    }

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
end
