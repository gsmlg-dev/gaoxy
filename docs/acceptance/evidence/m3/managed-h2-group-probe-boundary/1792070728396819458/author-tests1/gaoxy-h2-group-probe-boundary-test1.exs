defmodule Gaoxy.Proxy.ManagedH2GroupProbeBoundaryTest do
  use ExUnit.Case, async: true

  alias Gaoxy.Proxy.{ManagedH2Client, ManagedH2Preparation, UpstreamGroups, UpstreamTransports}
  alias Gaoxy.Proxy.UpstreamGroups.Probe

  @signed_min -9_223_372_036_854_775_808
  @signed_max 9_223_372_036_854_775_807
  @state_keys ~w(owner token member deadline health url group cleanup_deadline owner_monitor timer request original_request managed_transport transport_selection transport_pins terminal cancelled headers outcome client limits request_options submitted_url)a
  @option_keys ~w(request managed_transport timeout opening_timeout write_timeout deadline opening_deadline)a
  @cleared ~w(member group health url request_options managed_transport submitted_url)a
  @finite_atoms ~w(invalid_request invalid_policy invalid_response upstream_failure upstream_task upstream_delivery_limit upstream_delivery_overlap upstream_trailer_limit timeout request_timeout unavailable cancelled cleanup_pending cleanup_unconfirmed invalid_resource invalid_resource_pin invalid_transport_endpoint unauthorized retiring resource_unavailable)a

  test "both H2 protocols stage exact HEAD none options and the23-key state" do
    for protocol <- [:http2, :h2c] do
      state = fixture(protocol)
      assert Enum.sort(Map.keys(state)) == Enum.sort(@state_keys)
      assert {:ok, staged, :group_open} = prepare(state)
      assert Enum.sort(Map.keys(staged)) == Enum.sort(@state_keys)
      assert {:group_prepared, options} = staged.request_options
      assert Enum.sort(Map.keys(options)) == Enum.sort(@option_keys)
      assert options.request == %{
               protocol: protocol,
               url: state.url,
               target: state.health.path,
               method: :head,
               fields: [],
               body_mode: :none,
               max_upload_bytes: 1,
               request_limits: request_limits()
             }
      assert options.managed_transport === state.managed_transport
      assert options.deadline == state.deadline
      assert options.opening_deadline == state.deadline
      assert options.timeout == 2_000
      assert options.opening_timeout == 2_000
      assert options.write_timeout == 700
      assert staged.limits == effective_limits()
      assert staged === staged_expected(state, options)
    end
  end

  test "health timeout clamps only opening write and lifetime without timer renewal" do
    state = fixture()
    limits = %{state.member.config.limits | write_timeout: 5_000}
    state = %{state | member: %{state.member | config: %{state.member.config | limits: limits}}, limits: limits}
    assert {:ok, staged, :group_open} = prepare(state)
    assert staged.limits == %{limits | opening_timeout: 3_000, write_timeout: 3_000, max_lifetime: 3_000}
    assert staged.timer === state.timer
    assert staged.owner_monitor === state.owner_monitor
    assert staged.deadline === state.deadline
    assert staged.cleanup_deadline === state.cleanup_deadline
  end

  test "raw authority and original escaped health path survive without URL rewriting" do
    for protocol <- [:http2, :h2c] do
      state = fixture(protocol, true)
      assert {:ok, staged, :group_open} = prepare(state)
      {:group_prepared, options} = staged.request_options
      assert options.request.url === state.url
      assert options.request.target === "/health%2fready"
      assert String.contains?(options.request.url, if(protocol == :http2, do: ":00443/", else: ":00080/"))
    end
  end

  test "preparation uses the original absolute deadline down to its last millisecond" do
    state = fixture()
    assert {:ok, staged, :group_open} = prepare(state, self(), state.deadline - 1)
    {:group_prepared, options} = staged.request_options
    assert options.timeout == 1 and options.opening_timeout == 1
    assert options.deadline == state.deadline and options.opening_deadline == state.deadline
    for now <- [state.deadline, state.deadline + 1] do
      assert {:error, :request_timeout, dropped} = prepare(state, self(), now)
      assert dropped === expected_drop(state)
    end
  end

  test "signed clocks and cleanup headroom are checked rather than overflowing" do
    state = fixture()
    for now <- [nil, 2_000.0, @signed_min - 1, @signed_max + 1] do
      assert_prepare_error(state, self(), now, :invalid_request)
    end
    for deadline <- [nil, 4_000.0, @signed_min - 1, @signed_max - 999, @signed_max + 1] do
      assert_prepare_error(%{state | deadline: deadline}, self(), 2_000, :invalid_request)
    end
    input = %{state | deadline: @signed_min + 4_000, cleanup_deadline: @signed_min + 5_000}
    assert {:ok, staged, :group_open} = prepare(input, self(), @signed_min + 2_000)
    {:group_prepared, options} = staged.request_options
    assert options.timeout == 2_000 and options.opening_deadline == input.deadline
  end

  test "cancelled and terminal preparation preserves holds and drops opening payloads" do
    state = fixture()
    for input <- [%{state | cancelled: true}, %{state | terminal: true}] do
      assert_prepare_error(input, self(), 2_000, :cancelled)
    end
  end

  test "member group and owner coherence is validated on originals" do
    state = fixture()
    for input <- [
          %{state | owner: nil},
          %{state | member: nil},
          %{state | member: Map.put(state.member, :health, state.health)},
          %{state | member: %{state.member | max_inflight: 0}},
          %{state | group: nil},
          %{state | group: Map.put(state.group, :extra, [])},
          %{state | group: %{state.group | transports: []}},
          %{state | group: %{state.group | transports: [state.member.config.transport, state.member.config.transport]}},
          %{state | group: %{state.group | owner: nil}},
          %{state | group: %{state.group | max_url_bytes: 1}}
        ] do
      assert_prepare_error(input, self(), 2_000, :invalid_request)
    end
    for instance <- [nil, make_ref(), :instance, 1] do
      assert_prepare_error(state, instance, 2_000, :invalid_request)
    end
  end

  test "selected transport selection token and request pin aliases must match" do
    state = fixture()
    transport = state.member.config.transport
    alien = %{transport | resource: make_ref()}
    pin = hd(state.transport_pins)
    for input <- [
          %{state | transport_selection: nil},
          %{state | transport_selection: {alien, make_ref()}},
          %{state | transport_selection: {transport, nil}},
          %{state | transport_pins: []},
          %{state | transport_pins: [%{pin | handles: [alien]}]},
          %{state | transport_pins: [%{pin | owner_epoch: make_ref()}]},
          %{state | transport_pins: [%{pin | kind: :service}]},
          %{state | transport_pins: [Map.put(pin, :extra, [])]}
        ] do
      assert_prepare_error(input, self(), 2_000, :invalid_request)
    end
  end

  test "checked client exact protocol policy authority and public shell are required" do
    state = fixture()
    for checked <- [nil, %{}, Map.put(state.managed_transport, :extra, []),
                    checked_client(:h2c, "http://upstream.test"),
                    checked_client(:http2, "https://other.test")] do
      assert_prepare_error(%{state | managed_transport: checked}, self(), 2_000, :invalid_request)
    end
    for change <- [%{client: Gaoxy.Proxy.HTTPFetchClient}, %{upstream_protocol: :http1}, %{transport: nil}] do
      member = %{state.member | config: Map.merge(state.member.config, change)}
      assert_prepare_error(%{state | member: member}, self(), 2_000, :invalid_request)
    end
  end

  test "startup URL is exactly raw root plus the original compact valid health path" do
    state = fixture()
    path = "/" <> :binary.copy("p", 100)
    state = %{state | health: %{state.health | path: path}, url: raw_root(state) <> path}
    for url <- [nil, "https://other.test/health%2fready", state.url <> "?override=1",
                "https://upstream.test:443/health%2fready", slice(state.url)] do
      assert_prepare_error(%{state | url: url}, self(), 2_000, :invalid_request)
    end
    for path <- ["", "relative", "/q?x", "/x#y", "/x\\y", "/bad%", "/bad%2g", "/space here", slice(state.health.path)] do
      health = %{state.health | path: path}
      assert_prepare_error(%{state | health: health, url: raw_root(state) <> path}, self(), 2_000, :invalid_request)
    end
  end

  test "malformed health and limit scalars fail closed without retaining arbitrary payloads" do
    state = fixture()
    for health <- [nil, %{timeout: 3_000}, Map.put(state.health, :extra, fn -> :arbitrary end),
                   %{state.health | timeout: 0}, %{state.health | timeout: 5_001},
                   %{state.health | stale_after: 1}, %{state.health | jitter: :infinity}] do
      assert_prepare_error(%{state | health: health}, self(), 2_000, :invalid_request)
    end
    for limits <- [nil, Map.put(state.limits, :extra, []), %{state.limits | max_chunk_bytes: 0},
                   %{state.limits | max_lifetime: :infinity}] do
      input = %{state | member: %{state.member | config: %{state.member.config | limits: limits}}, limits: limits}
      assert {:error, :invalid_request, dropped} = prepare(input)
      assert dropped === expected_drop(input, nil)
    end
  end

  test "drop is H2-only idempotent and clears every opening payload alias" do
    state = fixture()
    assert drop(state) === expected_drop(state)
    assert drop(drop(state)) === drop(state)
    assert {:ok, staged, :group_open} = prepare(state)
    assert drop(staged) === expected_drop(staged)
    assert drop(drop(staged)) === drop(staged)
    original = public_handle()
    bound = %{staged | request: original, original_request: original, submitted_url: state.url}
    assert drop(bound) === expected_drop(bound)
    assert drop(bound).request === original
    assert drop(bound).original_request.completion === original.completion
  end

  test "drop recognizes malformed H2 intent before legacy fallback" do
    state = fixture()
    for input <- [Map.delete(state, :client), %{state | client: Gaoxy.Proxy.HTTPFetchClient},
                  %{state | group: nil}, %{state | member: nil}] do
      dropped = drop(input)
      for key <- @cleared, do: assert(Map.get(dropped, key) == nil)
      assert dropped.client == ManagedH2Client
      assert dropped.token === state.token
      assert dropped.transport_selection === state.transport_selection
      assert dropped.transport_pins === state.transport_pins
    end
  end

  test "drop preserves valid finite limits and removes every malformed limit shape" do
    state = fixture()
    assert drop(state).limits === state.limits
    for limits <- [nil, %{}, Map.put(state.limits, :extra, []),
                   %{state.limits | idle_timeout: 0}, %{state.limits | max_chunk_bytes: 65_537},
                   %{state.limits | write_timeout: 1.0}, %{state.limits | max_lifetime: fn -> :arbitrary end}] do
      assert drop(%{state | limits: limits}).limits == nil
    end
  end

  test "legacy H1 normal18 and recovery5 values are exact drop identities" do
    state = fixture()
    legacy = state |> Map.drop([:group, :client, :limits, :request_options, :submitted_url])
    legacy = %{legacy | member: %{legacy.member | config: %{legacy.member.config | client: Gaoxy.Proxy.HTTPFetchClient, upstream_protocol: :http1, transport: nil}}}
    assert map_size(legacy) == 18
    recovery = %{owner: self(), recovery: {:probe, make_ref()}, completion: public_handle().completion,
                 deadline: -1, owner_monitor: make_ref()}
    assert map_size(recovery) == 5
    assert drop(legacy) === legacy
    assert drop(recovery) === recovery
    minimal_legacy = %{member: %{config: legacy.member.config}, health: %{timeout: 1}, owner: self()}
    assert drop(minimal_legacy) === minimal_legacy
  end

  test "valid HEAD success retains the original opaque handle and exact URL for binding" do
    state = fixture()
    assert {:ok, staged, :group_open} = prepare(state)
    original = public_handle()
    assert {:ok, bind_state, :group_bind} = result(staged, {:ok, original, nil})
    assert bind_state === %{expected_drop(staged) | request: original, original_request: original, submitted_url: state.url}
    assert bind_state.request === original
    assert bind_state.original_request === original
    assert bind_state.original_request.completion === original.completion
    assert Enum.sort(Map.keys(bind_state)) == Enum.sort(@state_keys)
  end

  test "opaque completion interiors are preserved without traversal or reconstruction" do
    state = fixture()
    assert {:ok, staged, :group_open} = prepare(state)
    original = public_handle(%HTTP.RequestCompletion{tracker: fn -> :opaque end, latch: %{deep: [make_ref()]}, unsupported: {:opaque, self()}})
    assert {:ok, bound, :group_bind} = result(staged, {:ok, original, nil})
    assert bound.request === original and bound.original_request === original
    assert bound.original_request.completion === original.completion
  end

  test "late valid success installs original handle before cancellation or deadline failure" do
    state = fixture()
    assert {:ok, staged, :group_open} = prepare(state)
    original = public_handle()
    for {input, now, reason} <- [{staged, state.deadline, :request_timeout},
                                {%{staged | cancelled: true}, 2_000, :cancelled},
                                {%{staged | terminal: true}, 2_000, :cancelled},
                                {staged, @signed_max + 1, :invalid_request}] do
      assert {:error, ^reason, dropped} = result(input, {:ok, original, nil}, now)
      assert dropped === %{expected_drop(input) | request: original, original_request: original}
    end
  end

  test "every malformed or unsupported successful result returns the mandatory discriminator" do
    state = fixture()
    assert {:ok, staged, :group_open} = prepare(state)
    original = public_handle()
    alien = %HTTP.RequestCompletion{tracker: self(), latch: make_ref()}
    invalid_handles = [nil, :handle, %{}, Map.put(original, :extra, []),
                       %{original | completion: nil}, %{original | completion: alien},
                       %{original | promise: %{original.promise | task: nil}},
                       %{original | completion: Map.put(original.completion, :extra, [])}]
    for bad <- [:ok, {:ok}, {:ok, :bad}, {:ok, nil, nil, :extra}] ++ Enum.map(invalid_handles, &{:ok, &1, nil}) do
      assert_unconfirmed(staged, bad, nil)
    end
  end

  test "supported originals survive wrong success arity and impossible nonnil uploads" do
    state = fixture()
    assert {:ok, staged, :group_open} = prepare(state)
    original = public_handle()
    for response <- [{:ok, original}, {:ok, original, nil, :extra},
                     {:ok, original, self()}, {:ok, original, make_ref()},
                     {:ok, original, %{diagnostic: fn -> :never_retain end}}] do
      assert_unconfirmed(staged, response, original)
    end
  end

  test "unsupported successes remain unconfirmed even after cancellation or expiry" do
    state = fixture()
    assert {:ok, staged, :group_open} = prepare(state)
    original = public_handle()
    for input <- [%{staged | cancelled: true}, %{staged | terminal: true}],
        response <- [:ok, {:ok, original, self()}] do
      expected = if is_tuple(response), do: original, else: nil
      assert_unconfirmed(input, response, expected, state.deadline + 1)
    end
  end

  test "missing request or selection never collapses unsupported success into ordinary failure" do
    state = fixture()
    assert {:ok, staged, :group_open} = prepare(state)
    original = public_handle()
    for input <- [%{staged | request: nil}, %{staged | original_request: nil},
                  %{staged | transport_selection: nil},
                  %{staged | request: nil, original_request: nil, transport_selection: nil}] do
      for {response, expected} <- [{:ok, nil}, {{:ok}, nil}, {{:ok, :bad}, nil},
                                   {{:ok, :bad, nil}, nil}, {{:ok, original, nil, :extra}, original},
                                   {{:ok, original, self()}, original},
                                   {{:ok, original, %{payload: fn -> :arbitrary end}}, original}] do
        assert_unconfirmed(input, response, expected)
      end
    end
  end

  test "raw cleanup-unconfirmed atom and tuple retain holds even without request or selection" do
    state = fixture()
    assert {:ok, staged, :group_open} = prepare(state)
    for input <- [staged, %{staged | transport_selection: nil},
                  %{staged | request: nil, original_request: nil, transport_selection: nil}],
        {raw, cause} <- [{:cleanup_unconfirmed, :cleanup_unconfirmed},
                         {{:cleanup_unconfirmed, :timeout}, :timeout},
                         {{:cleanup_unconfirmed, :invalid_response}, :invalid_response},
                         {{:cleanup_unconfirmed, %{stack: [fn -> :arbitrary end]}}, :cleanup_unconfirmed},
                         {{:cleanup_unconfirmed, {:cleanup_failed, :timeout}}, :cleanup_unconfirmed}] do
      assert {:error, {:cleanup_unconfirmed, ^cause}, dropped} = result(input, {:error, raw})
      assert dropped === expected_drop(input)
    end
  end

  test "cleanup-unconfirmed recognized finite causes remain flat and bounded" do
    state = fixture()
    assert {:ok, staged, :group_open} = prepare(state)
    for atom <- @finite_atoms do
      assert {:error, {:cleanup_unconfirmed, ^atom}, dropped} = result(staged, {:error, {:cleanup_unconfirmed, atom}})
      assert dropped === expected_drop(staged)
    end
  end

  test "ordinary finite client errors drop payloads while preserving every ledger and control" do
    state = fixture()
    assert {:ok, staged, :group_open} = prepare(state)
    for atom <- @finite_atoms -- [:cleanup_unconfirmed] do
      assert {:error, ^atom, dropped} = result(staged, {:error, atom})
      assert dropped === expected_drop(staged)
    end
    for raw <- [%{stack: [fn -> :arbitrary end]}, {:unknown, :timeout}, [make_ref()]] do
      assert {:error, :upstream_failure, dropped} = result(staged, {:error, raw})
      assert dropped === expected_drop(staged)
    end
  end

  test "result requires the exact staged tag validated options and submitted URL provenance" do
    state = fixture()
    assert {:ok, staged, :group_open} = prepare(state)
    {:group_prepared, options} = staged.request_options
    for request_options <- [nil, options, {:prepared, options},
                            {:group_prepared, Map.put(options, :extra, [])},
                            {:group_prepared, Map.delete(options, :request)},
                            {:group_prepared, %{options | request: Map.put(options.request, :extra, [])}}] do
      input = %{staged | request_options: request_options}
      assert {:error, :invalid_request, dropped} = result(input, {:error, :timeout})
      assert dropped === expected_drop(input)
    end
  end

  defp prepare(state, instance \\ self(), now \\ 2_000), do: apply(Probe, :prepare_group_open, [state, instance, now])
  defp drop(state), do: apply(Probe, :drop_group_opening, [state])
  defp result(state, response, now \\ 2_000), do: apply(Probe, :group_open_result, [state, response, now])

  defp assert_prepare_error(state, instance, now, reason) do
    assert {:error, ^reason, dropped} = prepare(state, instance, now)
    assert dropped === expected_drop(state)
  end

  defp assert_unconfirmed(state, response, original, now \\ 2_000) do
    assert {:error, {:cleanup_unconfirmed, :invalid_response}, dropped} = result(state, response, now)
    assert dropped === %{expected_drop(state) | request: original, original_request: original}
    assert dropped.owner === state.owner
    assert dropped.token === state.token
    assert dropped.transport_selection === state.transport_selection
    assert dropped.transport_pins === state.transport_pins
  end

  defp expected_drop(state), do: Map.merge(state, Map.new(@cleared, &{&1, nil}))
  defp expected_drop(state, limits), do: %{expected_drop(state) | limits: limits}
  defp staged_expected(state, options), do: %{expected_drop(state) | request_options: {:group_prepared, options}, limits: effective_limits()}

  defp fixture(protocol \\ :http2, raw_port? \\ false) do
    scheme = if protocol == :http2, do: "https", else: "http"
    port = if protocol == :http2, do: "00443", else: "00080"
    root = scheme <> "://upstream.test" <> if(raw_port?, do: ":" <> port, else: "")
    transport = %{provider: UpstreamTransports, owner: self(), owner_epoch: make_ref(), resource: make_ref()}
    group = %{provider: UpstreamGroups, owner: self(), owner_epoch: make_ref(), group: "health", generation: make_ref(), max_url_bytes: 8_192, transports: [transport], execution_profile: :managed_h2}
    limits = %{max_chunk_bytes: 1_024, opening_timeout: 4_000, idle_timeout: 3_000, write_timeout: 700, max_lifetime: 10_000}
    config = %Gaoxy.Proxy.HTTP{uri: URI.parse(root), upstream_protocol: protocol, client: ManagedH2Client, transport: transport, cacertfile: nil, connect_address: nil, limits: limits}
    health = %{path: "/health%2fready", interval: 1_000, timeout: 3_000, stale_after: 2_000, failure_threshold: 3, recovery_threshold: 2, jitter: 0}
    pin = %{provider: UpstreamTransports, owner: transport.owner, owner_epoch: transport.owner_epoch, operation: make_ref(), ref: make_ref(), handles: [transport], kind: :request, holder: self()}
    %{owner: self(), token: make_ref(), member: %{id: "member", config: config, max_inflight: 32}, deadline: 4_000,
      health: health, url: root <> health.path, group: group, cleanup_deadline: 5_000,
      owner_monitor: make_ref(), timer: make_ref(), request: nil, original_request: nil,
      managed_transport: checked_client(protocol, scheme <> "://upstream.test"),
      transport_selection: {transport, make_ref()}, transport_pins: [pin], terminal: false,
      cancelled: false, headers: false, outcome: :failure, client: ManagedH2Client,
      limits: limits, request_options: nil, submitted_url: nil}
  end

  defp effective_limits, do: %{max_chunk_bytes: 1_024, opening_timeout: 3_000, idle_timeout: 3_000, write_timeout: 700, max_lifetime: 3_000}
  defp request_limits, do: %{max_headers: 256, max_header_bytes: 65_536, max_trailers: 128, max_trailer_bytes: 65_536}
  defp raw_root(state), do: state.member.config.uri.scheme <> "://" <> state.member.config.uri.authority
  defp slice(value), do: binary_part(value <> :binary.copy("x", 8_192), 0, byte_size(value))

  defp checked_client(protocol, origin) do
    {:ok, policy, _} = ManagedH2Preparation.prepare_policy(%{protocol: protocol, origin: origin, connect_address: {127, 0, 0, 1}, trust: if(protocol == :http2, do: [<<48, 3, 2, 1, 1>>], else: nil)})
    %{policy: policy, transport_scope: struct(HTTP.ManagedTransport), fetch_options: [http_version: protocol, tls_backend: :ssl, http2_profile: :native_v1, http2_reuse: true, redirect: :manual, request_mode: :proxy, decode_body: false, stream_response: true, telemetry: false]}
  end

  defp public_handle(completion \\ %HTTP.RequestCompletion{tracker: self(), latch: make_ref(), unsupported: nil}) do
    task = %Task{owner: self(), pid: self(), ref: make_ref(), mfa: {:erlang, :apply, 2}}
    %{promise: %HTTP.Promise{task: task, completion: completion}, completion: completion, stream: nil, resolved: false}
  end
end
