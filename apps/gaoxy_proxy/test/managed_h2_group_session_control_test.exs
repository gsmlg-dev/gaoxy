unless Code.ensure_loaded?(Gaoxy.Proxy.ManagedH2FixedFixture) do
  Code.require_file("managed_h2_fixed_endpoint_test.exs", __DIR__)
end

Code.require_file("support/managed_h2_group_fixture.exs", __DIR__)

defmodule Gaoxy.Proxy.ManagedH2GroupSessionControlFixture do
  @moduledoc false
  import ExUnit.Assertions
  alias Gaoxy.Proxy.ManagedH2GroupFixture, as: G
  alias Gaoxy.Proxy.ManagedH2FixedFixture, as: F
  alias Gaoxy.Proxy.ManagedH2GroupAccounting, as: A
  @timeout 5_000

  def open(protocol, target, preactivation \\ false, downstream \\ :http1) do
    options =
      if preactivation,
        do: %{await_health: false, group_limits: %{probe_bytes: 16_478_861}},
        else: %{}

    f = G.fixture(protocol, downstream, ["--manual"], options)
    {barrier, debug} = attachment_barrier(f.service)
    socket = G.connect(f)
    :ok = G.send_request(f, socket, "GET", target)
    service = f.service
    gate = f.gate

    assert_receive {:group_control_attach_held, ^service,
                    {:attach_cleanup, ^gate, _, guardian, 16_478_862, _}},
                   @timeout

    trace(guardian)
    send(service, {:group_control_attach_continue, barrier})
    :ok = :sys.remove(service, debug)
    {f, socket, guardian}
  end

  def trace(guardian) do
    for {function, arity} <- [validate: 2, preflight_control: 2],
        do: :erlang.trace_pattern({A, function, arity}, true, [:local])

    ExUnit.Callbacks.on_exit(fn ->
      for {function, arity} <- [validate: 2, preflight_control: 2],
          do: :erlang.trace_pattern({A, function, arity}, false, [:local])
    end)

    assert :erlang.trace(guardian, true, [:call]) === 1
  end

  def close_removed(f) do
    assert {:error, :not_running} = Gaoxy.info(f.instance, :http)
    assert %{inflight: 0, probes: 0, probe_bytes: 0} = Gaoxy.Proxy.UpstreamGroups.status(f.group)

    assert {:ok, %{request_tokens: 0, helpers: 0, pins: 1}} =
             Gaoxy.Proxy.UpstreamTransports.status(f.owner)

    G.assert_exact_controls(:sys.get_state(f.groups))
    actors = [f.instance, f.owner, f.groups, f.service, f.gate, f.custodian, f.embedding]
    joins = for actor <- actors, do: {actor, Process.monitor(actor)}
    send(f.embedding, {:stop, self()})
    embedding = f.embedding
    assert_receive {:group_h2_embedding_stopped, ^embedding, :ok}, 3 * @timeout

    for {actor, monitor} <- joins do
      assert_receive {:DOWN, ^monitor, :process, ^actor, reason}, @timeout
      assert reason in [:normal, :noproc, :shutdown]
    end

    expected = Process.get({F, :observed_requests, f.peer}, 0)
    F.physical_termination(f.peer)
    peer = f.peer
    monitor = Process.monitor(peer)
    send(peer, {:command, %{"op" => "stop"}})
    assert %{"forced" => 0, "live" => 0, "failed" => false} = joined = G.event(peer, "joined")
    assert joined["requests"] === expected
    assert_receive {:fixed_h2_peer_exit, ^peer, 0}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^peer, :normal}, @timeout
  end

  defp attachment_barrier(service) do
    caller = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      case event do
        {:in, {:"$gen_call", _, {:attach_cleanup, _, _, _, _, _} = request}} when not held ->
          send(caller, {:group_control_attach_held, self(), request})
          monitor = Process.monitor(caller)

          try do
            receive do
              {:group_control_attach_continue, ^barrier} -> :ok
              {:DOWN, ^monitor, :process, ^caller, _} -> :ok
            after
              @timeout -> raise "actual Service attachment barrier expired"
            end
          after
            Process.demonitor(monitor, [:flush])
          end

          true

        _ ->
          held
      end
    end

    :ok = :sys.install(service, {debug, false})
    ExUnit.Callbacks.on_exit(fn -> send(service, {:group_control_attach_continue, barrier}) end)
    {barrier, debug}
  end
end

defmodule Gaoxy.Proxy.ManagedH2GroupSessionPreactivationControlTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH2GroupSessionControlFixture, as: C
  alias Gaoxy.Proxy.ManagedH2GroupFixture, as: G
  alias Gaoxy.Proxy.ManagedH2GroupAccounting, as: A
  @moduletag :capture_log
  @timeout 5_000

  for protocol <- [:http2, :h2c] do
    @protocol protocol
    test "#{protocol} genuine activation and scalar cleanup preflight precede the real owner checkout with no healthy member" do
      {f, socket, guardian} = C.open(@protocol, "/no-healthy-member", true)
      assert %{status: 503, body: ""} = G.response(f, socket)

      assert_receive {:trace, ^guardian, :call,
                      {A, :validate,
                       [{:control, :activate}, {:gaoxy_cleanup_activate, actual_token}]}},
                     @timeout

      assert is_reference(actual_token)

      assert_receive {:trace, ^guardian, :call,
                      {A, :validate,
                       [
                         {:state, :session},
                         %{token: ^actual_token, opening_timer: nil, total_timer: nil}
                       ]}},
                     @timeout

      assert_receive {:trace, ^guardian, :call,
                      {A, :preflight_control,
                       [:cleanup_cancel, {:token, ^actual_token, signed_deadline}]}},
                     @timeout

      assert is_integer(signed_deadline)

      assert_receive {:trace, ^guardian, :call,
                      {A, :preflight_control,
                       [{:owner, :group, :checkout}, {:checkout, group, pins, ^guardian, %{}, _}]}},
                     @timeout

      assert group === f.group
      assert is_list(pins) and pins != []
      :ok = :gen_tcp.close(socket)
      G.clean(f)
      G.no_event(f.peer, "request")
      G.close(f)
    end
  end
end

defmodule Gaoxy.Proxy.ManagedH2GroupSessionStreamingControlTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH2GroupSessionControlFixture, as: C
  alias Gaoxy.Proxy.ManagedH2GroupFixture, as: G
  alias Gaoxy.Proxy.{ManagedH2GroupAccounting, ManagedH2GroupBoundary}
  alias Gaoxy.Proxy.ManagedH2GroupAccounting, as: A
  @moduletag :capture_log
  @timeout 5_000

  defp boundary(function), do: apply(ManagedH2GroupBoundary, function, [])

  setup do
    assert :ok === boundary(:activation)
    :ok
  end

  for protocol <- [:http2, :h2c] do
    @protocol protocol
    test "#{protocol} actual handoff response I and streaming DATA ACK trailers and cleanup controls retain original capability" do
      {f, socket, guardian} = C.open(@protocol, "/hold/controls")
      seen = G.event(f.peer, "request")
      G.eventually(fn -> G.held_selection(f, "/hold/controls") != nil end)
      {_, held} = G.held_selection(f, "/hold/controls")
      completion = held.completion

      assert_receive {:trace, ^guardian, :call,
                      {A, :validate, [{:owner_reply, :transport, :pin}, {:ok, original_pin}]}},
                     @timeout

      assert original_pin.holder === guardian
      assert original_pin.handles === [f.handle]

      assert_receive {:trace, ^guardian, :call,
                      {A, :validate,
                       [
                         {:control, :handoff},
                         {:gaoxy_transport_handoff, _, {:ok, ^original_pin}, _}
                       ]}},
                     @timeout

      assert G.assert_cleanup(f, 1) === 16_478_862

      G.command(f.peer, seen, "respond", %{
        "fields" => [["trailer", "x-check"]],
        "body64" => Base.encode64("data"),
        "trailers" => [["x-check", "final"]]
      })

      assert %{status: 200, body: "data", trailers: [{"x-check", "final"}]} =
               G.response(f, socket)

      assert_receive {:trace, ^guardian, :call,
                      {A, :validate,
                       [{:control, :ready}, {:gaoxy_proxy_http, ^guardian, {:ready, nil, _, _}}]}},
                     @timeout

      assert_receive {:trace, ^guardian, :call,
                      {A, :validate, [{:control, :acknowledge}, {:read_chunk, ^guardian, :ack}]}},
                     @timeout

      assert_receive {:trace, ^guardian, :call,
                      {A, :validate,
                       [{:control, :data}, {:stream_chunk, stream, "data", delivery}]}},
                     @timeout

      assert is_pid(stream) and is_reference(delivery)

      assert_receive {:trace, ^guardian, :call,
                      {A, :validate,
                       [
                         {:control, :delivery},
                         {:gaoxy_proxy_http, ^guardian, {:chunk, "data", ^delivery}}
                       ]}},
                     @timeout

      assert_receive {:trace, ^guardian, :call,
                      {A, :validate, [{:control, :acknowledge}, {:stream_chunk_ack, ^delivery}]}},
                     @timeout

      assert_receive {:trace, ^guardian, :call,
                      {A, :validate,
                       [
                         {:control, :trailers},
                         {:stream_trailers, ^stream,
                          %Elixir.HTTP.Headers{headers: [{"x-check", "final"}]}}
                       ]}},
                     @timeout

      :ok = :gen_tcp.close(socket)
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)

      assert_receive {:trace, ^guardian, :call,
                      {A, :preflight_control, [:admission, {:complete_cleanup, _}]}},
                     @timeout

      assert_receive {:trace, ^guardian, :call,
                      {A, :validate,
                       [{:owner_call, :transport, :release}, {:release, ^original_pin}]}},
                     @timeout

      G.clean(f)
      G.assert_exact_controls(:sys.get_state(f.groups))
      G.close(f)
    end

    test "#{protocol} real public Service removal cancellation remains owed through finite control checks and original completion" do
      {f, socket, guardian} = C.open(@protocol, "/hold/removing")
      assert %{"target" => "/hold/removing"} = G.event(f.peer, "request")
      G.eventually(fn -> G.held_selection(f, "/hold/removing") != nil end)
      {_, held} = G.held_selection(f, "/hold/removing")
      completion = held.completion
      assert G.assert_cleanup(f, 1) === 16_478_862
      caller = self()

      {worker, monitor} =
        spawn_monitor(fn ->
          send(
            caller,
            {:group_control_removed, self(), Gaoxy.remove(f.instance, :http, @timeout)}
          )
        end)

      assert_receive {:trace, ^guardian, :call,
                      {A, :validate,
                       [
                         {:control, :cleanup_cancel},
                         {:gaoxy_cleanup_cancel, actual_token, actual_reason, deadline}
                       ]}},
                     @timeout

      assert is_reference(actual_token) and is_integer(deadline)
      assert actual_reason in [:draining, :forced_cleanup]
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:group_control_removed, ^worker, :ok}, 2 * @timeout
      assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, @timeout
      :ok = :gen_tcp.close(socket)
      G.no_event(f.peer, "request")
      C.close_removed(f)
    end

    test "#{protocol} genuine owner DOWN diagnostic is normalized for E while the already owed original cleanup still joins" do
      {f, socket, guardian} = C.open(@protocol, "/hold/owner-down", false, :http2)
      assert %{"target" => "/hold/owner-down"} = G.event(f.peer, "request")
      G.eventually(fn -> G.held_selection(f, "/hold/owner-down") != nil end)
      {_, held} = G.held_selection(f, "/hold/owner-down")
      completion = held.completion
      pump = :sys.get_state(guardian).owner
      diagnostic = {:actual_owner_failure, :binary.copy("diagnostic", 16_384)}
      guardian_monitor = Process.monitor(guardian)
      pump_monitor = Process.monitor(pump)
      assert {:trap_exit, false} = Process.info(pump, :trap_exit)
      Process.exit(pump, diagnostic)
      assert_receive {:DOWN, ^pump_monitor, :process, ^pump, ^diagnostic}, @timeout

      assert_receive {:trace, ^guardian, :call,
                      {A, :validate,
                       [{:control, :down}, {:DOWN, actual_ref, :process, ^pump, ^diagnostic}]}},
                     @timeout

      assert is_reference(actual_ref)

      assert {:ok, %{projection: {:DOWN, ^actual_ref, :process, ^pump, :upstream_failure}}} =
               ManagedH2GroupAccounting.project(
                 {:control, :down},
                 {:DOWN, actual_ref, :process, pump, diagnostic}
               )

      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
      :ok = :gen_tcp.close(socket)
      G.clean(f)
      G.no_event(f.peer, "request")
      G.close(f)
    end
  end
end
