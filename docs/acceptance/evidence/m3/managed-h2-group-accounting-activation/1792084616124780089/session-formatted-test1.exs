defmodule Gaoxy.Proxy.ManagedH2GroupAccountingSessionTest do
  use ExUnit.Case, async: false

  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Lifecycle

  alias Gaoxy.Proxy.{
    GroupEndpoint,
    HTTP,
    HTTPFetchClient,
    ManagedH2Client,
    UpstreamGroups,
    UpstreamTransports
  }

  alias Gaoxy.Proxy.HTTP.Session

  @args ~w(owner service instance gate started_at deadline config selector transport_handoff request_options)a
  @state ~w(owner service instance gate started_at deadline config selector transport_handoff request_options
    monitors client cleanup_deadline cleanup_requested_deadline cleanup_started opening_timer activated_at
    opening_deadline total_timer selection awaiting_transport transport_pins transport_selection
    managed_transport managed_path submitted_url poll_timer original_request outcome token request headers
    delivery trailers cancelled consumed)a

  setup do
    Process.flag(:trap_exit, true)
    :ok
  end

  test "the original H8 profile selects the managed H2 client in the public pump route" do
    f = fixture()
    assert HTTP.selected_client(f.config) === ManagedH2Client
    assert HTTP.selected_client(%{group: f.group}) === ManagedH2Client
    assert {:ok, endpoint} = GroupEndpoint.init(%{group: f.group})
    assert HTTP.selected_client(endpoint) === ManagedH2Client
    assert Resources.validate(GroupEndpoint.resources(endpoint)) === {:ok, [f.group, f.transport]}
  end

  test "legacy H1 group and fixed-client routing retain their public behavior" do
    f = fixture()
    legacy = Map.delete(f.group, :execution_profile)
    assert HTTP.selected_client(%{group: legacy}) === HTTPFetchClient

    assert HTTP.selected_client(%HTTP{upstream_protocol: :http1, client: HTTPFetchClient}) ===
             HTTPFetchClient

    assert HTTP.selected_client(%HTTP{upstream_protocol: :h2c, client: ManagedH2Client}) ===
             ManagedH2Client

    assert HTTP.selected_client(%HTTP{upstream_protocol: :http2, client: ManagedH2Client}) ===
             ManagedH2Client
  end

  test "real inactive Session preserves original exact startup roots with the managed client" do
    f = fixture()
    args = arguments(f)
    assert Enum.sort(Map.keys(args)) === Enum.sort(@args)
    assert {:ok, pid} = inactive(args)
    state = :sys.get_state(pid)
    assert Enum.sort(Map.keys(state)) === Enum.sort(@state)
    for key <- @args, do: assert(Map.fetch!(state, key) === Map.fetch!(args, key))
    assert state.client === ManagedH2Client
    assert state.managed_path === true
    assert state.token === nil
    assert state.selection === nil
    assert state.transport_selection === nil
    assert state.transport_pins === []
    assert state.managed_transport === nil
    assert state.request === nil
    assert state.original_request === nil
    assert map_size(state.monitors) === 1
    assert Map.values(state.monitors) === [self()]
    assert state.opening_timer === nil and state.total_timer === nil
    refute_receive {:"$gen_call", _, _}, 0
    refute_receive {:"$gen_cast", _}, 0
  end

  test "complete matching captured G batches survive Session initialization" do
    f = fixture()
    other = %{f.group | group: "other", generation: make_ref()}
    first = pin(f.group)
    second = pin(other)
    args = %{arguments(f) | selector: {:group, f.group, [first, second]}}
    assert {:ok, pid} = inactive(args)
    assert :sys.get_state(pid).selector === args.selector
  end

  for mutation <- [
        :expanded,
        :missing,
        :wrong_alias,
        :bad_deadline,
        :expanded_neutral,
        :wrong_client_config,
        :improper_pins,
        :expanded_pin,
        :bad_handoff
      ] do
    test "#{mutation} H2 startup refuses the original root before a child can remain alive" do
      f = fixture()
      args = bad_arguments(unquote(mutation), arguments(f))
      assert {:error, :invalid_group_accounting} = inactive(args)
      refute_receive {:"$gen_call", _, _}, 0
      refute_receive {:"$gen_cast", _}, 0
    end
  end

  defp bad_arguments(:expanded, args), do: Map.put(args, :future_monitor, make_ref())
  defp bad_arguments(:missing, args), do: Map.delete(args, :transport_handoff)

  defp bad_arguments(:wrong_alias, args) do
    {:group, group, pins} = args.selector
    %{args | selector: {:group, %{group | generation: make_ref()}, pins}}
  end

  defp bad_arguments(:bad_deadline, args), do: %{args | deadline: 9_223_372_036_854_775_808}

  defp bad_arguments(:expanded_neutral, args),
    do: %{args | request_options: Map.put(args.request_options, :url, "http://other.test/")}

  defp bad_arguments(:wrong_client_config, args),
    do: %{args | config: Map.put(args.config, :client, HTTPFetchClient)}

  defp bad_arguments(:improper_pins, args) do
    {:group, group, [pin]} = args.selector
    %{args | selector: {:group, group, [pin | :tail]}}
  end

  defp bad_arguments(:expanded_pin, args) do
    {:group, group, [pin]} = args.selector
    %{args | selector: {:group, group, [Map.put(pin, :holder, self())]}}
  end

  defp bad_arguments(:bad_handoff, args), do: %{args | transport_handoff: self()}

  defp inactive(args) do
    result = Session.start_link(args)

    case result do
      {:ok, pid} ->
        Process.unlink(pid)

        on_exit(fn ->
          if Process.alive?(pid) do
            monitor = Process.monitor(pid)
            Session.cancel(pid)
            assert_receive {:DOWN, ^monitor, :process, ^pid, _}, 5_000
          end
        end)

      _ ->
        :ok
    end

    result
  end

  # Structural preactivation source constructors grant no owner authority and
  # perform no checkout/open. Live success uses independently observed peers.
  defp fixture do
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
      max_chunk_bytes: 65_536,
      opening_timeout: 5_000,
      idle_timeout: 60_000,
      write_timeout: 3_000,
      max_lifetime: 30_000
    }

    %{transport: transport, group: group, config: %GroupEndpoint{group: group, limits: limits}}
  end

  defp arguments(f) do
    now = Lifecycle.now()

    %{
      owner: self(),
      service: self(),
      instance: self(),
      gate: self(),
      started_at: now,
      deadline: now + 8_000,
      config: f.config,
      selector: {:group, f.group, [pin(f.group)]},
      transport_handoff: make_ref(),
      request_options: %{
        target: "/a?",
        method: :get,
        fields: [],
        body_mode: :none,
        max_upload_bytes: 65_536,
        request_limits: %{
          max_headers: 256,
          max_header_bytes: 65_536,
          max_trailers: 128,
          max_trailer_bytes: 65_536
        }
      }
    }
  end

  defp pin(group),
    do: %{
      provider: UpstreamGroups,
      owner: group.owner,
      owner_epoch: group.owner_epoch,
      ref: make_ref(),
      operation: make_ref(),
      handles: [group],
      kind: :request
    }
end
