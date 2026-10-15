defmodule Gaoxy.Proxy.ManagedH2GroupSessionBoundaryTest do
  use ExUnit.Case, async: true

  alias Gaoxy.Proxy.HTTP.Session
  alias Gaoxy.Proxy.ManagedH2Client
  alias Gaoxy.Proxy.ManagedH2Preparation
  alias Gaoxy.Proxy.UpstreamGroups
  alias Gaoxy.Proxy.UpstreamTransports

  @signed_min -9_223_372_036_854_775_808
  @signed_max 9_223_372_036_854_775_807
  @option_keys ~w(request managed_transport timeout opening_timeout write_timeout deadline opening_deadline)a
  @limit_keys ~w(max_chunk_bytes opening_timeout idle_timeout write_timeout max_lifetime)a
  @cleared ~w(request_options managed_transport selector awaiting_transport transport_handoff submitted_url)a
  @finite_atoms ~w(invalid_request invalid_policy invalid_response upstream_failure upstream_task upstream_delivery_limit upstream_delivery_overlap upstream_trailer_limit timeout request_timeout unavailable cancelled cleanup_pending cleanup_unconfirmed invalid_resource invalid_resource_pin invalid_transport_endpoint unauthorized retiring resource_unavailable)a

  test "preparation stages exact options and effective limits while releasing source aliases" do
    for protocol <- [:http2, :h2c] do
      {state, selected} = fixture(protocol)
      assert {:ok, staged, :group_open} = prepare(state, selected)
      assert staged.config === %{limits: effective_limits()}
      assert staged.client == ManagedH2Client and staged.managed_path == true
      assert {:group_prepared, options} = staged.request_options
      assert Enum.sort(Map.keys(options)) == Enum.sort(@option_keys)
      assert Enum.sort(Map.keys(staged.config.limits)) == Enum.sort(@limit_keys)
      assert options.managed_transport === state.managed_transport
      assert options.timeout == 9_000 and options.opening_timeout == 3_500
      assert options.write_timeout == 700
      assert options.deadline == staged.deadline and staged.deadline == 11_000
      assert options.opening_deadline == staged.opening_deadline
      assert staged.opening_deadline == 5_500
      assert options.request.protocol == protocol
      assert options.request.url == raw_origin(selected.config) <> state.request_options.target
      assert options.request.target == state.request_options.target
      assert options.request.fields === state.request_options.fields
      assert options.request.request_limits === state.request_options.request_limits
      assert options.request.body_mode === state.request_options.body_mode
      assert options.request.max_upload_bytes == 1_024
      assert Enum.sort(Map.keys(staged)) == Enum.sort(Map.keys(state))
      for key <- @cleared -- [:request_options], do: assert(Map.fetch!(staged, key) == nil)
      assert_controls_preserved(state, staged)
    end
  end

  test "direct and awaiting Selected aliases produce identical sanitized stages" do
    {state, selected} = fixture()
    waiting = %{state | awaiting_transport: %{handle: selected.config.transport, member: selected}}
    assert prepare(state, selected) === prepare(waiting, selected)
    assert {:ok, staged, :group_open} = prepare(waiting, selected)
    assert staged.awaiting_transport == nil
  end

  test "original raw origin escaped target leading slashes and empty query survive staging" do
    for protocol <- [:http2, :h2c], target <- ["/a%2fb%2F?", "//other.test/a%2Fb?", "/a??x"] do
      {state, selected} = fixture(protocol, true)
      state = %{state | request_options: %{state.request_options | target: target}}
      assert {:ok, staged, :group_open} = prepare(state, selected)
      assert {:group_prepared, options} = staged.request_options
      assert options.request.url == raw_origin(selected.config) <> target
      assert options.request.target == target
    end
  end

  test "preparation validates exact Selected instead of reconstructing it from config" do
    {state, selected} = fixture()
    for bad <- [nil, selected.config, Map.delete(selected, :id),
                Map.delete(selected, :max_inflight), Map.put(selected, :health, :healthy),
                %{selected | id: ""}, %{selected | id: :binary.copy("m", 129)},
                %{selected | max_inflight: 0}, %{selected | max_inflight: 1_025},
                %{selected | config: %{selected.config | transport: nil}},
                %{selected | config: %{selected.config | upstream_protocol: :http1}},
                %{selected | config: Map.put(selected.config, :member, :forbidden)}] do
      assert_prepare_error(state, bad, :invalid_request)
    end
  end

  test "group aliases must match exactly before their payloads are dropped" do
    {state, selected} = fixture()
    {group, token} = state.selection
    alien = %{group | generation: make_ref()}
    for bad <- [
          %{state | config: %{state.config | group: alien}},
          %{state | selector: {:group, alien, []}},
          %{state | selection: {alien, token}},
          %{state | selector: nil},
          %{state | config: %{limits: state.config.limits}}
        ] do
      assert_prepare_error(bad, selected, :invalid_request)
    end
  end

  test "transport aliases exact awaiting member and delegated pin coverage must agree" do
    {state, selected} = fixture()
    transport = selected.config.transport
    alien = %{transport | resource: make_ref()}
    waiting = %{handle: transport, member: selected}
    for bad <- [
          %{state | awaiting_transport: %{waiting | handle: alien}},
          %{state | awaiting_transport: %{waiting | member: %{selected | id: "other"}}},
          %{state | awaiting_transport: Map.put(waiting, :config, selected.config)},
          %{state | awaiting_transport: %{handle: transport, config: selected.config}},
          %{state | transport_selection: {alien, make_ref()}},
          %{state | transport_selection: nil},
          %{state | transport_pins: []},
          %{state | transport_pins: [%{hd(state.transport_pins) | handles: [alien]}]}
        ] do
      assert_prepare_error(bad, selected, :invalid_request)
    end
  end

  test "advertised root cap membership and checked policy mismatches fail closed" do
    {state, selected} = fixture()
    {group, token} = state.selection
    too_small = %{group | max_url_bytes: byte_size(raw_origin(selected.config)) - 1}
    absent = %{group | transports: [%{selected.config.transport | resource: make_ref()}]}
    for group <- [too_small, absent] do
      bad = %{state | config: %{state.config | group: group},
                     selector: {:group, group, []}, selection: {group, token}}
      assert_prepare_error(bad, selected, :invalid_request)
    end
    for checked <- [nil, Map.put(state.managed_transport, :member, selected),
                    checked_client(:h2c, "http://upstream.test"),
                    checked_client(:http2, "https://other.test")] do
      assert_prepare_error(%{state | managed_transport: checked}, selected, :invalid_request)
    end
  end

  test "original Neutral is validated before a reduced upload cap can hide invalid input" do
    {state, selected} = fixture()
    for source <- [
          %{state.request_options | max_upload_bytes: 65_537},
          Map.put(state.request_options, :url, "https://other.test/"),
          %{state.request_options | fields: [{"host", "other.test"}]},
          %{state.request_options | request_limits: %{state.request_options.request_limits | max_headers: 4}}
        ] do
      assert_prepare_error(%{state | request_options: source}, selected, :invalid_request)
    end
  end

  test "limits use the per-key minimum and preserve smaller original upload bounds" do
    {state, selected} = fixture()
    limits = %{endpoint_limits() | max_chunk_bytes: 512, opening_timeout: 2_000,
                                   idle_timeout: 2_000, write_timeout: 300, max_lifetime: 8_000}
    state = %{state | config: %{state.config | limits: limits},
                     request_options: %{state.request_options | max_upload_bytes: 100}}
    assert {:ok, staged, :group_open} = prepare(state, selected)
    assert staged.config == %{limits: limits}
    assert {:group_prepared, options} = staged.request_options
    assert options.request.max_upload_bytes == 100
    assert options.write_timeout == 300
    assert staged.deadline == 9_000 and staged.opening_deadline == 3_500
  end

  test "aged anchors and already reduced handoff deadlines never renew from now" do
    {state, selected} = fixture()
    assert {:ok, aged, :group_open} = prepare(state, selected, 5_000)
    assert aged.deadline == 11_000 and aged.opening_deadline == 5_500
    assert {:group_prepared, %{timeout: 6_000, opening_timeout: 500}} = aged.request_options
    reduced = %{state | deadline: 7_000, opening_deadline: 4_000}
    assert {:ok, staged, :group_open} = prepare(reduced, selected, 3_000)
    assert staged.deadline == 7_000 and staged.opening_deadline == 4_000
    assert staged.total_timer === state.total_timer
    assert staged.opening_timer === state.opening_timer
  end

  test "invalid signed anchors arithmetic overflow and cleanup headroom are rejected" do
    {state, selected} = fixture()
    for bad <- [
          %{state | started_at: nil}, %{state | activated_at: 1.0},
          %{state | started_at: @signed_max - 1},
          %{state | activated_at: @signed_max - 1},
          %{state | deadline: @signed_max + 1},
          %{state | opening_deadline: @signed_min - 1},
          %{state | started_at: @signed_max - 10_000, activated_at: @signed_max - 4_000,
                     deadline: @signed_max, opening_deadline: @signed_max}
        ] do
      assert_prepare_error(bad, selected, :invalid_request)
    end
    for now <- [nil, 2_000.0, @signed_max + 1, @signed_min - 1, @signed_min] do
      assert_prepare_error(state, selected, :invalid_request, now)
    end
  end

  test "signed64 deadline with exactly one thousand cleanup headroom is accepted" do
    {state, selected} = fixture()
    state = %{state | started_at: @signed_max - 11_000, activated_at: @signed_max - 6_000,
                     deadline: @signed_max - 1_000, opening_deadline: @signed_max - 2_000}
    assert {:ok, staged, :group_open} = prepare(state, selected, @signed_max - 3_000)
    assert staged.deadline == @signed_max - 1_000
    assert staged.opening_deadline == @signed_max - 2_000
    assert {:group_prepared, %{timeout: 2_000, opening_timeout: 1_000}} = staged.request_options
  end

  test "preparation cancellation consumed and expired deadlines have finite local reasons" do
    {state, selected} = fixture()
    assert_prepare_error(%{state | cancelled: true}, selected, :cancelled)
    assert_prepare_error(%{state | consumed: true}, selected, :cancelled)
    assert_prepare_error(state, selected, :request_timeout, 11_000)
    assert_prepare_error(state, selected, :timeout, 5_500)
  end

  test "drop clears all group opening payloads and preserves cleanup ledgers and handles" do
    {state, _selected} = fixture()
    original = public_handle()
    state = %{state | request: original, original_request: original, submitted_url: "old-url"}
    dropped = drop(state)
    assert dropped === expected_drop(state)
    assert dropped.request === original and dropped.original_request === original
    assert drop(dropped) === dropped
  end

  test "malformed group limits drop to failure-only nil without retaining arbitrary payloads" do
    {state, selected} = fixture()
    for limits <- [nil, [], %{endpoint_limits() | write_timeout: 0},
                   Map.put(endpoint_limits(), :extra, fn -> :forbidden end)] do
      bad = %{state | config: %{state.config | limits: limits}}
      assert drop(bad) === expected_drop(bad, nil)
      assert {:error, :invalid_request, dropped} = prepare(bad, selected)
      assert dropped === expected_drop(bad, nil)
      assert drop(dropped) === dropped
    end
  end

  test "drop recognizes H2 intent in each retained group alias before client classification" do
    {state, selected} = fixture()
    for bad <- [
          %{state | selector: nil, selection: nil},
          %{state | config: %{limits: endpoint_limits()}, selection: nil},
          %{state | config: %{limits: endpoint_limits()}, selector: nil},
          %{state | config: %{limits: endpoint_limits()}, selector: nil, selection: nil,
                     awaiting_transport: %{handle: selected.config.transport, member: selected}}
        ] do
      assert drop(bad) === expected_drop(bad)
    end
  end

  test "nongroup fixed H2 H1 and H3 states retain exact identity on drop and helper rejection" do
    {state, selected} = fixture()
    for {client, protocol, managed?} <- [
          {ManagedH2Client, :http2, true},
          {Gaoxy.Proxy.HTTPFetchClient, :http1, false},
          {Gaoxy.Proxy.HTTP3SessionClient, :http3, false}
        ] do
      config = %{selected.config | client: client, upstream_protocol: protocol}
      fixed = %{state | config: config, selector: {:fixed, config}, selection: nil,
                       awaiting_transport: nil, client: client, managed_path: managed?}
      assert drop(fixed) === fixed
      assert {:error, :invalid_request, ^fixed} = prepare(fixed, selected)
      assert {:error, :invalid_request, ^fixed} = result(fixed, {:error, :timeout})
    end
  end

  test "result transfers original public handle URL and independent nil or PID upload carrier" do
    for upload <- [nil, self()] do
      {state, selected} = fixture()
      assert {:ok, staged, :group_open} = prepare(state, selected)
      original = public_handle()
      assert original.stream == nil
      assert {:ok, bound, {:group_bind, ^upload}} = result(staged, {:ok, original, upload})
      assert bound.request === original and bound.original_request === original
      assert bound.request.completion === original.completion
      assert bound.submitted_url == raw_origin(selected.config) <> state.request_options.target
      assert bound.config === staged.config
      assert bound.request_options == nil and bound.managed_transport == nil
      assert Enum.sort(Map.keys(bound)) == Enum.sort(Map.keys(state))
      assert Enum.sort(Map.keys(bound.request)) == [:completion, :promise, :resolved, :stream]
      assert_controls_preserved(staged, bound)
      assert drop(bound) === %{bound | submitted_url: nil}
    end
  end

  test "late successful result captures original completion before total opening or cancellation checks" do
    {state, selected} = fixture()
    assert {:ok, staged, :group_open} = prepare(state, selected)
    original = public_handle()
    for {input, now, reason} <- [
          {staged, 11_000, :request_timeout}, {staged, 5_500, :timeout},
          {%{staged | cancelled: true}, 2_000, :cancelled},
          {%{staged | consumed: true}, 2_000, :cancelled},
          {staged, @signed_max + 1, :invalid_request}
        ] do
      assert {:error, ^reason, dropped} = result(input, {:ok, original, self()}, now)
      assert dropped.request === original and dropped.original_request === original
      assert dropped === expected_drop(%{input | request: original, original_request: original})
    end
  end

  test "malformed successful handle upload or completion identity is cleanup-unconfirmed" do
    {state, selected} = fixture()
    assert {:ok, staged, :group_open} = prepare(state, selected)
    original = public_handle()
    alien_completion = %HTTP.RequestCompletion{tracker: self(), latch: make_ref()}
    for bad <- [
          {:ok, nil, nil}, {:ok, original, make_ref()}, {:ok, original, :upload},
          {:ok, Map.put(original, :upload, self()), self()},
          {:ok, %{original | completion: nil}, nil},
          {:ok, %{original | completion: alien_completion}, nil},
          {:ok, %{original | promise: %{original.promise | task: nil}}, nil},
          {:ok, %{original | completion: Map.put(original.completion, :extra, [])}, nil},
          {:ok, original}, {:ok, original, nil, :extra}
        ] do
      assert {:error, {:cleanup_unconfirmed, :invalid_response}, dropped} = result(staged, bad)
      assert dropped === expected_drop(staged)
      assert dropped.request == nil and dropped.original_request == nil
    end
  end

  test "result requires exact staged tag seven options and validated envelope" do
    {state, selected} = fixture()
    assert {:ok, staged, :group_open} = prepare(state, selected)
    {:group_prepared, options} = staged.request_options
    for request_options <- [
          options, {:prepared, options}, {:group_prepared, Map.put(options, :selected, selected)},
          {:group_prepared, Map.delete(options, :request)},
          {:group_prepared, %{options | request: Map.put(options.request, :extra, [])}}
        ] do
      bad = %{staged | request_options: request_options}
      assert {:error, :invalid_request, dropped} = result(bad, {:error, :timeout})
      assert dropped === expected_drop(bad)
    end
  end

  test "all ordinary result errors drop payloads and retain only finite diagnostics" do
    {state, selected} = fixture()
    assert {:ok, staged, :group_open} = prepare(state, selected)
    for atom <- @finite_atoms -- [:cleanup_unconfirmed] do
      assert {:error, ^atom, dropped} = result(staged, {:error, atom})
      assert dropped === expected_drop(staged)
    end
    for wrapper <- ~w(cleanup_failed transport_cleanup_failed pin_release_failed service_cleanup_failed selection_cleanup_failed)a do
      finite = {wrapper, :cleanup_pending}
      assert {:error, ^finite, dropped} = result(staged, {:error, finite})
      assert dropped === expected_drop(staged)
    end
    for {raw, finite} <- [
          {:invalid_request, :invalid_request}, {:timeout, :timeout},
          {:request_timeout, :request_timeout}, {:not_running, :unavailable},
          {{:capacity, :pins}, :unavailable},
          {{:cleanup_failed, {:transport_cleanup_failed, :cleanup_pending}},
           {:cleanup_failed, {:transport_cleanup_failed, :cleanup_pending}}},
          {%{stack: [fn -> :arbitrary end]}, :upstream_failure},
          {{:unknown, :timeout}, :upstream_failure}
        ] do
      assert {:error, ^finite, dropped} = result(staged, {:error, raw})
      assert dropped === expected_drop(staged)
    end
  end

  test "raw cleanup-unconfirmed atom and tuple are discriminated before generic normalization" do
    {state, selected} = fixture()
    assert {:ok, staged, :group_open} = prepare(state, selected)
    for atom <- @finite_atoms do
      assert {:error, {:cleanup_unconfirmed, ^atom}, dropped} =
               result(staged, {:error, {:cleanup_unconfirmed, atom}})
      assert dropped === expected_drop(staged)
    end
    for {raw, cause} <- [
          {:cleanup_unconfirmed, :cleanup_unconfirmed},
          {{:cleanup_unconfirmed, :timeout}, :timeout},
          {{:cleanup_unconfirmed, :invalid_response}, :invalid_response},
          {{:cleanup_unconfirmed, :not_running}, :cleanup_unconfirmed},
          {{:cleanup_unconfirmed, {:cleanup_failed, :timeout}}, :cleanup_unconfirmed},
          {{:cleanup_unconfirmed, %{stack: [fn -> :not_retained end]}}, :cleanup_unconfirmed}
        ] do
      assert {:error, {:cleanup_unconfirmed, ^cause}, dropped} = result(staged, {:error, raw})
      assert dropped === expected_drop(staged)
    end
  end

  defp prepare(state, selected, now \\ 2_000),
    do: apply(Session, :prepare_group_open, [state, selected, now])

  defp drop(state), do: apply(Session, :drop_group_opening, [state])

  defp result(state, response, now \\ 2_000),
    do: apply(Session, :group_open_result, [state, response, now])

  defp assert_prepare_error(state, selected, reason, now \\ 2_000) do
    assert {:error, ^reason, dropped} = prepare(state, selected, now)
    assert dropped === expected_drop(state, valid_limits_or_nil(state.config.limits))
    assert drop(dropped) === dropped
  end

  defp expected_drop(state, limits \\ :original) do
    limits = if limits == :original, do: state.config.limits, else: limits
    state
    |> Map.merge(%{config: %{limits: limits}, client: ManagedH2Client, managed_path: true})
    |> Map.merge(Map.new(@cleared, &{&1, nil}))
  end

  defp valid_limits_or_nil(limits) do
    if is_map(limits) and Enum.sort(Map.keys(limits)) == Enum.sort(@limit_keys) and
         Enum.all?(limits, fn {key, n} ->
           is_integer(n) and n >= 1 and n <= if(key == :max_chunk_bytes, do: 65_536, else: 86_400_000)
         end), do: limits, else: nil
  end

  defp assert_controls_preserved(before, after_state) do
    for key <- ~w(selection transport_selection transport_pins service token monitors started_at activated_at opening_timer total_timer cancelled consumed outcome cleanup_deadline cleanup_requested_deadline cleanup_started)a do
      assert Map.fetch!(after_state, key) === Map.fetch!(before, key)
    end
  end

  defp fixture(protocol \\ :http2, raw_port? \\ false) do
    scheme = if protocol == :http2, do: "https", else: "http"
    port = if protocol == :http2, do: "00443", else: "00080"
    origin = scheme <> "://upstream.test" <> if(raw_port?, do: ":" <> port, else: "")
    transport = %{provider: UpstreamTransports, owner: self(), owner_epoch: make_ref(), resource: make_ref()}
    group = %{provider: UpstreamGroups, owner: self(), owner_epoch: make_ref(), group: "group",
              generation: make_ref(), max_url_bytes: 8_192, transports: [transport], execution_profile: :managed_h2}
    config = %Gaoxy.Proxy.HTTP{uri: URI.parse(origin), upstream_protocol: protocol,
                              client: ManagedH2Client, transport: transport,
                              cacertfile: nil, connect_address: nil, limits: effective_limits()}
    selected = %{id: "member", config: config, max_inflight: 32}
    pin = %{provider: UpstreamTransports, owner: transport.owner, owner_epoch: transport.owner_epoch,
            operation: make_ref(), ref: make_ref(), handles: [transport], kind: :request, holder: self()}
    state = %{
      owner: self(), service: self(), instance: self(), gate: self(), token: make_ref(),
      config: %{group: group, limits: endpoint_limits()}, selector: {:group, group, []},
      selection: {group, make_ref()}, transport_selection: {transport, make_ref()},
      transport_pins: [pin], managed_transport: checked_client(protocol, scheme <> "://upstream.test"),
      transport_handoff: make_ref(), awaiting_transport: nil,
      client: Gaoxy.Proxy.HTTPFetchClient, managed_path: false,
      request_options: neutral(), request: nil, original_request: nil, submitted_url: nil,
      started_at: 1_000, activated_at: 1_500, deadline: 40_000, opening_deadline: 10_000,
      opening_timer: make_ref(), total_timer: make_ref(), poll_timer: nil,
      monitors: %{make_ref() => self()}, cleanup_deadline: nil, cleanup_requested_deadline: nil,
      cleanup_started: false, outcome: :cancelled, cancelled: false, consumed: false,
      headers: false, delivery: nil, trailers: []
    }
    {state, selected}
  end

  defp neutral do
    %{target: "/a%2Fb?", method: :post, fields: [{"Content-Length", "3"}, {"X-Trace", "one"}, {"x-trace", "two"}],
      body_mode: {:length, 3}, max_upload_bytes: 65_536,
      request_limits: %{max_headers: 256, max_header_bytes: 65_536, max_trailers: 128, max_trailer_bytes: 65_536}}
  end

  defp endpoint_limits,
    do: %{max_chunk_bytes: 65_536, opening_timeout: 5_000, idle_timeout: 60_000, write_timeout: 5_000, max_lifetime: 30_000}

  defp effective_limits,
    do: %{max_chunk_bytes: 1_024, opening_timeout: 4_000, idle_timeout: 3_000, write_timeout: 700, max_lifetime: 10_000}

  defp checked_client(protocol, origin) do
    {:ok, policy, _} = ManagedH2Preparation.prepare_policy(%{
      protocol: protocol, origin: origin, connect_address: {127, 0, 0, 1},
      trust: if(protocol == :http2, do: [<<48, 3, 2, 1, 1>>], else: nil)
    })
    %{policy: policy, transport_scope: struct(HTTP.ManagedTransport),
      fetch_options: [http_version: protocol, tls_backend: :ssl, http2_profile: :native_v1,
                      http2_reuse: true, redirect: :manual, request_mode: :proxy,
                      decode_body: false, stream_response: true, telemetry: false]}
  end

  defp public_handle do
    completion = %HTTP.RequestCompletion{tracker: self(), latch: make_ref(), unsupported: nil}
    task = %Task{owner: self(), pid: self(), ref: make_ref(), mfa: {:erlang, :apply, 2}}
    %{promise: %HTTP.Promise{task: task, completion: completion}, completion: completion,
      stream: nil, resolved: false}
  end

  defp raw_origin(config), do: config.uri.scheme <> "://" <> config.uri.authority
end
