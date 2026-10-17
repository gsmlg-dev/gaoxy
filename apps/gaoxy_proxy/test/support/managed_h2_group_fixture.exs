Code.require_file("managed_h2_fixed_fixture.exs", __DIR__)

defmodule Gaoxy.Proxy.ManagedH2GroupFixture do
  @moduledoc false
  import ExUnit.Assertions
  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Proxy.{GroupEndpoint, ManagedH2GroupAccounting, UpstreamGroups}
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports
  alias Gaoxy.Proxy.ManagedH2FixedFixture, as: F
  @timeout 5_000
  @reserve 16_478_862
  @service_bytes 1_073_741_824

  def fixture(protocol, downstream \\ :http1, peer_options \\ [], overrides \\ %{}) do
    {peer, ready} = F.peer(protocol, peer_options)
    scheme = if protocol == :http2, do: "https", else: "http"
    origin = scheme <> "://" <> Map.get(overrides, :hostname, "localhost") <> ":#{ready["port"]}"

    trust =
      if protocol == :http2, do: F.certificates(Map.get(overrides, :ca, ready["ca"])), else: nil

    source = %{protocol: protocol, origin: origin, connect_address: {127, 0, 0, 1}, trust: trust}
    caller = self()
    group_limits = Map.get(overrides, :group_limits, %{})

    transport_limits =
      Map.merge(
        %{
          max_resources: 2,
          max_pins: 256,
          max_request_tokens: 64,
          max_owned_payload_bytes: 4_194_304
        },
        Map.get(overrides, :transport_limits, %{})
      )

    embedding =
      spawn(fn ->
        {:ok, instance} = Gaoxy.start_link()
        Process.unlink(instance)
        {:ok, owner} = Transports.start_link(instance: instance, limits: transport_limits)
        Process.unlink(owner)
        {:ok, groups} = UpstreamGroups.start_link(instance: instance, limits: group_limits)
        Process.unlink(groups)
        send(caller, {:group_h2_embedding, self(), instance, owner, groups})
        embedding_loop(instance, owner, groups, [])
      end)

    assert_receive {:group_h2_embedding, ^embedding, instance, owner, groups}, @timeout

    ExUnit.Callbacks.on_exit(fn ->
      if Process.alive?(embedding) do
        monitor = Process.monitor(embedding)
        send(embedding, {:stop, self()})
        assert_receive {:group_h2_embedding_stopped, ^embedding, :ok}, 3 * @timeout
        assert_receive {:DOWN, ^monitor, :process, ^embedding, :normal}, @timeout
      end
    end)

    assert {:ok, transport, transport_preparation} =
             Transports.prepare(owner, source, self(), deadline())

    member =
      Map.merge(
        %{
          id: "only",
          upstream: origin,
          upstream_protocol: protocol,
          transport: transport,
          max_inflight: 32
        },
        Map.get(overrides, :member, %{})
      )

    health =
      Map.merge(
        %{
          path: "/health",
          interval: 3_600_000,
          timeout: 5_000,
          stale_after: 3_600_000,
          jitter: 0,
          failure_threshold: 2,
          recovery_threshold: 2
        },
        Map.get(overrides, :health, %{})
      )

    assert {:ok, compiled} =
             UpstreamGroups.compile(%{
               id: "group-wire",
               members: [member],
               max_inflight: Map.get(overrides, :max_inflight, 32),
               health: health
             })

    assert {:ok, group, preparation} =
             UpstreamGroups.prepare(groups, compiled, self(), deadline())

    assert {:ok, baseline} =
             Resources.pin_many(UpstreamGroups.resources(group), embedding, :baseline, deadline())

    send(embedding, {:baseline, baseline, self()})
    assert_receive {:group_h2_baseline_owned, ^embedding}, @timeout
    assert :ok = Resources.release(preparation)
    assert :ok = Resources.release(transport_preparation)
    custodian = :sys.get_state(owner).records[transport.resource].custodian

    f = %{
      instance: instance,
      owner: owner,
      transports: owner,
      handle: transport,
      transport: transport,
      groups: groups,
      group: group,
      baseline: baseline,
      embedding: embedding,
      peer: peer,
      ready: ready,
      origin: origin,
      protocol: protocol,
      downstream: downstream,
      custodian: custodian,
      service_bytes: @service_bytes,
      await_health: Map.get(overrides, :await_health, true)
    }

    if f.await_health do
      seen = F.event(peer, "request")
      assert seen["target"] === health.path
      assert [":method", "HEAD"] in seen["headers"]
      assert seen["ended"] === true
      health_connection = seen["connection"]
      health_stream = seen["stream"]

      assert %{"connection" => ^health_connection, "stream" => ^health_stream, "total_bytes" => 0} =
               F.event(peer, "upload_end")

      if "--manual" in peer_options,
        do:
          F.command(peer, seen, "respond", %{
            "fields" => [["content-length", "0"]],
            "ended" => true
          })

      F.eventually(fn ->
        match?(
          %{probes: 0, probe_bytes: 0, members: [%{health: :healthy}]},
          UpstreamGroups.status(group)
        )
      end)

      F.eventually(fn ->
        match?({:ok, %{request_tokens: 0, helpers: 0}}, Transports.status(owner))
      end)
    end

    endpoint = Map.merge(%{group: group}, Map.get(overrides, :endpoint, %{}))

    service_limits =
      Map.merge(
        %{max_bytes: @service_bytes, max_active: 64},
        Map.get(overrides, :service_limits, %{})
      )

    service_options = [
      id: :http,
      endpoint: {Map.get(overrides, :endpoint_module, GroupEndpoint), endpoint},
      limits: service_limits,
      http_limits:
        Map.merge(
          %{
            request_timeout: 30_000,
            write_timeout: 2_000,
            max_headers: 512,
            max_header_bytes: 131_072,
            max_trailers: 256,
            max_trailer_bytes: 131_072
          },
          Map.get(overrides, :http_limits, %{})
        )
    ]

    service_options =
      if downstream == :http2,
        do: service_options ++ [protocols: [:http2], h2c: :prior_knowledge],
        else: service_options

    assert {:ok, spec} = Gaoxy.HTTP.service_spec(service_options)
    assert {:ok, _} = Gaoxy.add(instance, spec)
    [{:http, service, _generation}] = :ets.lookup(:sys.get_state(instance).live, :http)
    gate = :sys.get_state(service).gate
    Map.merge(f, %{service: service, gate: gate, service_bytes: service_limits.max_bytes})
  end

  defp embedding_loop(instance, owner, groups, baseline) do
    receive do
      {:baseline, pins, caller} ->
        send(caller, {:group_h2_baseline_owned, self()})
        embedding_loop(instance, owner, groups, pins)

      {:release_baseline, caller} ->
        result = Resources.release(baseline)
        send(caller, {:group_h2_baseline_released, self(), result})
        embedding_loop(instance, owner, groups, [])

      {:finish_external_shutdown, caller} ->
        # A negative test first records the real public stop outcome, inspects
        # retained ledgers, and then explicitly joins this actual holder. This
        # message never stops or refunds either resource owner.
        if Process.alive?(instance) do
          send(
            caller,
            {:group_h2_external_shutdown_finished, self(), {:error, :instance_running}}
          )

          embedding_loop(instance, owner, groups, baseline)
        else
          send(caller, {:group_h2_external_shutdown_finished, self(), :ok})
        end

      {:stop, caller} ->
        result = Gaoxy.stop(instance, 10_000)
        if Process.alive?(groups), do: GenServer.stop(groups, :normal, @timeout)
        send(caller, {:group_h2_embedding_stopped, self(), result})
    after
      120_000 -> raise "test-owned group embedding exceeded cleanup deadline"
    end
  end

  defdelegate connect(f), to: F
  defdelegate send_request(f, socket, method, target), to: F
  defdelegate send_request(f, socket, method, target, fields), to: F
  defdelegate send_request(f, socket, method, target, fields, ended), to: F
  defdelegate send_request(f, socket, method, target, fields, ended, id), to: F
  defdelegate send_body(f, socket, bytes, ended), to: F
  defdelegate send_body(f, socket, bytes, ended, id), to: F
  defdelegate response(f, socket), to: F
  defdelegate response(f, socket, method), to: F
  defdelegate response(f, socket, method, id), to: F
  defdelegate event(peer, name), to: F
  defdelegate command(peer, request, op), to: F
  defdelegate command(peer, request, op, extra), to: F
  defdelegate no_event(peer, name), to: F
  defdelegate upload_through(peer, request, expected), to: F
  defdelegate upload_through(peer, request, expected, previous), to: F
  defdelegate eventually(predicate), to: F
  defdelegate eventually(predicate, expires), to: F

  def request(f, method, target, fields \\ []) do
    socket = connect(f)
    :ok = send_request(f, socket, method, target, fields)
    result = response(f, socket, method)
    :ok = :gen_tcp.close(socket)
    clean(f)
    result
  end

  def hold(f, target \\ "/hold") do
    socket = connect(f)
    :ok = send_request(f, socket, "GET", target)
    seen = event(f.peer, "request")
    assert seen["target"] === target
    assert [":method", "GET"] in seen["headers"]
    F.eventually(fn -> held_selection(f, target) != nil end)
    {_token, held} = held_selection(f, target)
    {socket, seen, held.guardian, held.completion}
  end

  def held_selection(f, target) do
    Enum.find(:sys.get_state(f.groups).tokens, fn {_, held} ->
      if match?(%HTTP.RequestCompletion{}, held.completion) and Process.alive?(held.guardian) do
        try do
          :sys.get_state(held.guardian).submitted_url === f.origin <> target
        catch
          :exit, _ -> false
        end
      else
        false
      end
    end)
  end

  def assert_cleanup(f, count) do
    F.eventually(fn -> Gaoxy.status(f.instance, :http).cleanup_pending === count end)
    gate = :sys.get_state(f.gate)
    assert map_size(gate.cleanups) === count
    assert Enum.all?(gate.cleanups, fn {_, held} -> held.bytes === @reserve end)
    bytes = Enum.sum(for {_, held} <- gate.cleanups, do: held.bytes)
    assert bytes === count * @reserve
    assert gate.bytes >= bytes
    assert gate.bytes <= gate.limits.max_bytes
    assert gate.high_water <= gate.limits.max_bytes
    assert %{cleanup_pending: ^count, retained_bytes: retained} = Gaoxy.status(f.instance, :http)
    assert retained >= bytes
    assert retained <= f.service_bytes
    bytes
  end

  def clean(f) do
    F.eventually(fn ->
      match?(%{active: 0, cleanup_pending: 0, retained_bytes: 0}, Gaoxy.status(f.instance, :http)) and
        match?(%{inflight: 0, probes: 0, probe_bytes: 0}, UpstreamGroups.status(f.group)) and
        match?({:ok, %{request_tokens: 0, helpers: 0, pins: 1}}, Transports.status(f.owner)) and
        map_size(:sys.get_state(f.groups).pins) === 1
    end)

    assert %{cleanup_failed: nil, retained_high_water: high} = Gaoxy.status(f.instance, :http)
    assert high <= f.service_bytes
    assert {:ok, %{resources: 1, reserved_connections: 2}} = Transports.status(f.owner)
    state = :sys.get_state(f.groups)
    assert state.tokens === %{}
    assert state.probes === %{}
    assert state.probe_bytes === 0
    assert_exact_controls(state)
    assert UpstreamGroups.status(f.group).config_bytes === state.bytes

    assert :ok ===
             ManagedH2GroupAccounting.group_update(state.groups[group_key(f.group)], state.bytes)
  end

  def clean_retired(f) do
    F.eventually(fn ->
      match?(%{active: 0, cleanup_pending: 0, retained_bytes: 0}, Gaoxy.status(f.instance, :http)) and
        UpstreamGroups.status(f.group) === {:error, :stale_group} and
        match?(
          {:ok, %{resources: 0, request_tokens: 0, helpers: 0, pins: 0, reserved_connections: 0}},
          Transports.status(f.owner)
        )
    end)

    assert %{cleanup_failed: nil} = Gaoxy.status(f.instance, :http)
    state = :sys.get_state(f.groups)

    assert %{
             groups: %{},
             pins: %{},
             tokens: %{},
             probes: %{},
             bytes: 0,
             control_bytes: 0,
             probe_bytes: 0
           } = state
  end

  def assert_exact_controls(state) do
    charges =
      for {kind, records} <- [pin: state.pins, selection: state.tokens, probe: state.probes],
          {_, held} <- records do
        assert {:ok, bytes} = ManagedH2GroupAccounting.control_charge(kind, held)
        assert held.control_bytes === bytes
        bytes
      end

    assert state.control_bytes === Enum.sum(charges)
    assert state.control_bytes <= 16_777_216
  end

  def release_baseline(f) do
    send(f.embedding, {:release_baseline, self()})
    embedding = f.embedding
    assert_receive {:group_h2_baseline_released, ^embedding, :ok}, @timeout
  end

  def close(f, mode \\ :ready) do
    if mode == :retired, do: clean_retired(f), else: clean(f)
    expected = Process.get({F, :observed_requests, f.peer}, 0)
    actors = [f.instance, f.owner, f.groups, f.service, f.gate, f.custodian, f.embedding]
    joins = for pid <- actors, do: {pid, Process.monitor(pid)}
    send(f.embedding, {:stop, self()})
    embedding = f.embedding
    assert_receive {:group_h2_embedding_stopped, ^embedding, :ok}, 3 * @timeout

    for {pid, monitor} <- joins do
      assert_receive {:DOWN, ^monitor, :process, ^pid, reason}, @timeout

      actor =
        Enum.find(
          [:instance, :owner, :groups, :service, :gate, :custodian, :embedding],
          &(Map.fetch!(f, &1) === pid)
        )

      if actor == :gate do
        # Service.close_resources/4 deliberately kills its Admission gate.
        assert reason === :killed
      else
        assert reason in [:normal, :noproc, :shutdown],
               "group fixture #{actor} #{inspect(pid)} exited #{inspect(reason)}"
      end
    end

    if expected > 0, do: F.physical_termination(f.peer)
    peer = f.peer
    monitor = Process.monitor(peer)
    send(peer, {:command, %{"op" => "stop"}})
    assert %{"forced" => 0, "live" => 0, "failed" => false} = joined = event(peer, "joined")
    assert joined["requests"] === expected
    assert_receive {:fixed_h2_peer_exit, ^peer, 0}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^peer, :normal}, @timeout
  end

  def group_key(group), do: {group.group, group.generation}
  def deadline, do: Gaoxy.Lifecycle.deadline(@timeout)
end
