# Integration destination: apps/gaoxy_proxy/test/managed_h2_group_live_gap_test.exs.
# Source-only draft: runtime NOT RUN. See accompanying .md/.json receipt.
# Resolve both the /tmp draft and its intended repository integration location.
fixture_dir =
  if File.exists?(Path.join(__DIR__, "support/managed_h2_group_fixture.exs")),
    do: __DIR__,
    else: Path.expand("apps/gaoxy_proxy/test", File.cwd!())

unless Code.ensure_loaded?(Gaoxy.Proxy.ManagedH2FixedFixture) do
  Code.require_file("managed_h2_fixed_endpoint_test.exs", fixture_dir)
end

Code.require_file("support/managed_h2_group_fixture.exs", fixture_dir)

defmodule Gaoxy.Proxy.ManagedH2GroupLiveGapTest do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.HTTP2.Frame
  alias Gaoxy.Proxy.ManagedH2GroupFixture, as: G
  alias Gaoxy.Proxy.{ManagedH2GroupBoundary, UpstreamGroups, UpstreamTransports}
  alias HTTP.HTTP2.HPACK
  @moduletag :capture_log
  @timeout 5_000
  @reserve 16_478_862

  setup do
    assert :ok === apply(ManagedH2GroupBoundary, :activation, [])
    :ok
  end

  for protocol <- [:http2, :h2c] do
    @protocol protocol
    test "group #{protocol} genuine capacity-denied selected transport handoff refunds only its original selection and Service hold" do
      f = G.fixture(@protocol, :http1, ["--manual"], %{transport_limits: %{max_pins: 4}})
      {sibling_socket, sibling_seen, sibling, sibling_completion} = G.hold(f, "/hold/sibling")
      [{sibling_g, sibling_g_hold}] = Map.to_list(:sys.get_state(f.groups).tokens)
      [{sibling_t, sibling_t_hold}] = Map.to_list(:sys.get_state(f.owner).tokens)
      assert sibling_g_hold.guardian === sibling
      assert sibling_g_hold.completion === sibling_completion
      assert sibling_t_hold.guardian === sibling
      assert sibling_t_hold.completion === sibling_completion
      assert {:ok, %{request_tokens: 1, pins: 3}} = UpstreamTransports.status(f.owner)

      observe_delegate_refusal(f.owner)

      owner_barrier =
        barrier(f.owner, fn
          {:in,
           {:"$gen_call", {_pump, _} = from,
            {:delegate_request_pin, handle, source, guardian, authority, instance, operation,
             deadline}}} ->
            {from, handle, source, guardian, authority, instance, operation, deadline}

          _ ->
            nil
        end)

      socket = G.connect(f)
      :ok = G.send_request(f, socket, "GET", "/handoff-denied")
      owner = f.owner

      assert_receive {:group_gap_held, ^owner, ^owner_barrier,
                      {{pump, call_tag}, handle, source, guardian, _, instance, operation,
                       deadline}},
                     @timeout

      assert handle === f.handle
      assert instance === f.instance
      assert source.holder === pump
      assert source.handles === [f.handle]
      assert is_reference(operation) and is_integer(deadline)
      refute guardian === sibling

      # This is the genuine selected Session before the pump's owner call can
      # reply. There has been no open, so no original completion or T exists.
      state = :sys.get_state(guardian)
      {group, selected_g} = state.selection
      assert group === f.group
      assert state.awaiting_transport.handle === f.handle
      assert state.original_request === nil
      assert state.request === nil
      assert state.transport_selection === nil
      assert state.transport_pins === []
      assert is_reference(state.token)
      handoff = state.transport_handoff
      assert is_reference(handoff)

      session_barrier =
        barrier(guardian, fn
          {:in,
           {:gaoxy_transport_handoff, ^handoff, {:error, :invalid_resource_pin}, _} = message} ->
            message

          _ ->
            nil
        end)

      guardian_monitor = Process.monitor(guardian)
      release(f.owner, owner_barrier)

      assert_receive {:group_gap_owner_refusal, ^owner, {^pump, ^call_tag}, ^operation,
                      {:error, {:capacity, :pins}}},
                     @timeout

      assert_receive {:group_gap_held, ^guardian, ^session_barrier,
                      {:gaoxy_transport_handoff, ^handoff, {:error, :invalid_resource_pin}, _}},
                     @timeout

      # The real owner refuses the fifth pin. HTTP's finite pin-reply validator
      # converts that raw refusal to invalid_resource_pin before the genuine
      # Session handoff. Freeze that receipt with all three ledgers readable.
      assert %{inflight: 2} = UpstreamGroups.status(f.group)
      groups = :sys.get_state(f.groups)
      assert groups.tokens[sibling_g] === sibling_g_hold
      assert groups.tokens[selected_g].guardian === guardian
      assert groups.tokens[selected_g].completion === nil
      assert map_size(groups.tokens) === 2
      G.assert_exact_controls(groups)
      assert {:ok, %{request_tokens: 1, pins: 4}} = UpstreamTransports.status(f.owner)
      assert :sys.get_state(f.owner).tokens === %{sibling_t => sibling_t_hold}
      assert G.assert_cleanup(f, 2) === 2 * @reserve
      assert :sys.get_state(f.gate).cleanups[state.token].bytes === @reserve
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(sibling_completion, 0)
      G.no_event(f.peer, "request")

      release(guardian, session_barrier)
      assert %{status: 502, body: ""} = G.response(f, socket)
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
      :ok = :gen_tcp.close(socket)

      G.eventually(fn ->
        :sys.get_state(f.groups).tokens === %{sibling_g => sibling_g_hold} and
          match?({:ok, %{request_tokens: 1, pins: 3}}, UpstreamTransports.status(f.owner))
      end)

      assert :sys.get_state(f.owner).tokens === %{sibling_t => sibling_t_hold}
      assert G.assert_cleanup(f, 1) === @reserve
      refute Map.has_key?(:sys.get_state(f.gate).cleanups, state.token)
      G.assert_exact_controls(:sys.get_state(f.groups))
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(sibling_completion, 0)
      G.no_event(f.peer, "request")

      G.command(f.peer, sibling_seen, "respond", %{
        "body64" => Base.encode64("healthy"),
        "fields" => [["content-length", "7"]]
      })

      assert %{status: 200, body: "healthy"} = G.response(f, sibling_socket)
      :ok = :gen_tcp.close(sibling_socket)
      assert :ok = HTTP.RequestCompletion.await(sibling_completion, @timeout)
      G.clean(f)
      G.no_event(f.peer, "request")
      G.close(f)
    end

    test "group #{protocol} native H2 writes part of one DATA event then real stream reset fails its remainder without ACK or replay" do
      # Credit is a wire barrier: one real byte can be written, and the rest of
      # the same two-byte event cannot complete before our explicit RST_STREAM.
      f =
        G.fixture(@protocol, :http2, ["--manual"], %{
          endpoint: %{write_timeout: 5_000, idle_timeout: 15_000, max_lifetime: 30_000},
          member: %{write_timeout: 5_000, idle_timeout: 15_000, max_lifetime: 30_000}
        })

      socket = G.connect(f)
      :ok = :gen_tcp.send(socket, Frame.encode(4, 0, 0, <<4::16, 1::32>>))
      :ok = G.send_request(f, socket, "GET", "/hold/partial-failure")
      seen = G.event(f.peer, "request")
      assert seen["target"] === "/hold/partial-failure"
      G.eventually(fn -> G.held_selection(f, "/hold/partial-failure") != nil end)
      {original_g, held} = G.held_selection(f, "/hold/partial-failure")
      guardian = held.guardian
      completion = held.completion
      original = :sys.get_state(guardian).original_request
      assert %HTTP.RequestCompletion{} = completion
      assert original.completion === completion
      [{original_t, original_t_hold}] = Map.to_list(:sys.get_state(f.owner).tokens)
      assert original_t_hold.guardian === guardian
      assert original_t_hold.completion === completion
      guardian_monitor = Process.monitor(guardian)
      assert :erlang.trace(guardian, true, [:send]) === 1

      {sibling_socket, sibling_seen, sibling, sibling_completion} = G.hold(f, "/hold/sibling")
      assert sibling_seen["connection"] === seen["connection"]
      refute sibling_seen["stream"] === seen["stream"]
      assert :erlang.trace(sibling, true, [:send]) === 1
      sibling_state = :sys.get_state(sibling)
      {_, sibling_g} = sibling_state.selection
      {_, sibling_t} = sibling_state.transport_selection
      sibling_g_hold = :sys.get_state(f.groups).tokens[sibling_g]
      sibling_t_hold = :sys.get_state(f.owner).tokens[sibling_t]

      G.command(f.peer, seen, "respond", %{
        "ended" => false,
        "fields" => [["content-length", "2"]]
      })

      assert {":status", "200"} in committed_head(socket, "", expires())
      G.command(f.peer, seen, "data", %{"body64" => Base.encode64("pq"), "ended" => false})

      assert_receive {:trace, ^guardian, :send,
                      {:gaoxy_proxy_http, ^guardian, {:chunk, "pq", delivery}}, _},
                     @timeout

      assert is_reference(delivery)
      assert {0, flags, 1, "p"} = next_data(socket, expires())
      assert Bitwise.band(flags, 1) === 0

      state = :sys.get_state(guardian)
      assert state.delivery === delivery
      assert state.original_request === original
      stream = state.request.stream
      refute_receive {:trace, ^guardian, :send, {:stream_chunk_ack, ^delivery}, ^stream}, 0
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(sibling_completion, 0)
      assert %{inflight: 2} = UpstreamGroups.status(f.group)
      assert :sys.get_state(f.groups).tokens[original_g] === held
      assert :sys.get_state(f.owner).tokens[original_t] === original_t_hold
      assert {:ok, %{request_tokens: 2, pins: 5}} = UpstreamTransports.status(f.owner)
      assert G.assert_cleanup(f, 2) === 2 * @reserve
      assert :sys.get_state(f.gate).cleanups[state.token].bytes === @reserve
      assert :sys.get_state(f.gate).cleanups[sibling_state.token].bytes === @reserve
      G.assert_exact_controls(:sys.get_state(f.groups))

      # Genuine downstream cancellation makes the native pending write fail;
      # neither a fabricated client event nor a substitute completion is used.
      :ok = :gen_tcp.send(socket, Frame.encode(3, 0, 1, <<8::32>>))
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
      refute_receive {:trace, ^guardian, :send, {:stream_chunk_ack, ^delivery}, ^stream}, 0

      G.eventually(fn ->
        :sys.get_state(f.groups).tokens === %{sibling_g => sibling_g_hold} and
          :sys.get_state(f.owner).tokens === %{sibling_t => sibling_t_hold} and
          match?({:ok, %{request_tokens: 1, pins: 3}}, UpstreamTransports.status(f.owner))
      end)

      assert G.assert_cleanup(f, 1) === @reserve
      refute Map.has_key?(:sys.get_state(f.gate).cleanups, state.token)
      assert :sys.get_state(f.gate).cleanups[sibling_state.token].bytes === @reserve
      G.assert_exact_controls(:sys.get_state(f.groups))
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(sibling_completion, 0)
      assert_no_success(socket, System.monotonic_time(:millisecond) + 100)
      G.no_event(f.peer, "request")

      G.command(f.peer, sibling_seen, "respond", %{
        "body64" => Base.encode64("healthy"),
        "fields" => [["content-length", "7"]]
      })

      assert %{status: 200, body: "healthy"} = G.response(f, sibling_socket)

      assert_receive {:trace, ^sibling, :send,
                      {:gaoxy_proxy_http, ^sibling, {:chunk, "healthy", sibling_delivery}}, _},
                     @timeout

      assert_receive {:trace, ^sibling, :send, {:read_chunk, ^sibling, :ack}, sibling_stream},
                     @timeout

      assert is_pid(sibling_stream)

      assert_receive {:trace, ^sibling, :send, {:stream_chunk_ack, ^sibling_delivery},
                      ^sibling_stream},
                     @timeout

      :ok = :gen_tcp.close(sibling_socket)
      :ok = :gen_tcp.close(socket)
      assert :ok = HTTP.RequestCompletion.await(sibling_completion, @timeout)
      G.clean(f)

      refute_receive {:trace, ^sibling, :send, {:stream_chunk_ack, ^sibling_delivery},
                      ^sibling_stream},
                     0

      refute_receive {:trace, ^guardian, :send, {:stream_chunk_ack, ^delivery}, ^stream}, 0
      G.no_event(f.peer, "request")
      G.close(f)
    end
  end

  # OTP gen_server emits {:out, reply, original_from, app_state} only after
  # replying to this actual call. Correlate that From and captured operation;
  # retain neither the owner state nor any substitute reply capability.
  defp observe_delegate_refusal(owner) do
    caller = self()

    debug = fn pending, event, _ ->
      case {pending, event} do
        {:unseen,
         {:in,
          {:"$gen_call", {pump, _} = from, {:delegate_request_pin, _, _, _, _, _, operation, _}}}}
        when is_pid(pump) and is_reference(operation) ->
          {:delegation, from, operation}

        {{:delegation, from, operation},
         {:out, {:error, {:capacity, :pins}} = reply, actual_from, _owner_state}}
        when actual_from === from ->
          send(caller, {:group_gap_owner_refusal, owner, from, operation, reply})
          :done

        _ ->
          pending
      end
    end

    :ok = :sys.install(owner, {debug, :unseen})

    on_exit(fn ->
      if Process.alive?(owner), do: :sys.remove(owner, debug)
    end)
  end

  # Actual owner/Session :sys input barriers follow the established live-suite
  # pattern. They never modify state, fabricate replies, or bypass callers.
  defp barrier(actor, match_event) do
    caller = self()
    ref = make_ref()

    debug = fn held, event, _ ->
      payload = if held, do: nil, else: match_event.(event)

      if payload != nil do
        send(caller, {:group_gap_held, self(), ref, payload})
        monitor = Process.monitor(caller)

        try do
          receive do
            {:group_gap_continue, ^ref} -> :ok
            {:DOWN, ^monitor, :process, ^caller, _} -> :ok
          after
            @timeout -> raise "real group live-gap barrier expired"
          end
        after
          Process.demonitor(monitor, [:flush])
        end

        true
      else
        held
      end
    end

    :ok = :sys.install(actor, {debug, false})
    on_exit(fn -> release(actor, ref) end)
    ref
  end

  defp release(actor, ref), do: send(actor, {:group_gap_continue, ref})
  defp expires, do: System.monotonic_time(:millisecond) + @timeout

  defp committed_head(socket, block, deadline) do
    case frame(socket, deadline) do
      {4, 0, 0, _} ->
        :ok = :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
        committed_head(socket, block, deadline)

      {type, flags, 1, payload} when type in [1, 9] ->
        assert Bitwise.band(flags, 1) === 0
        block = block <> payload
        assert byte_size(block) <= 65_536

        if Bitwise.band(flags, 4) === 0 do
          committed_head(socket, block, deadline)
        else
          assert {:ok, _, fields} =
                   HPACK.decode(HPACK.new_decoder(max_dynamic_size: 4_096), block)

          fields
        end

      {type, _, _, _} when type in [4, 8] ->
        committed_head(socket, block, deadline)

      other ->
        flunk("unexpected native H2 frame before head: #{inspect(other)}")
    end
  end

  defp next_data(socket, deadline) do
    case frame(socket, deadline) do
      {4, 0, 0, _} ->
        :ok = :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
        next_data(socket, deadline)

      {type, _, _, _} when type in [4, 8] ->
        next_data(socket, deadline)

      {0, _, 1, _} = data ->
        data

      other ->
        flunk("unexpected native H2 frame before partial DATA: #{inspect(other)}")
    end
  end

  defp assert_no_success(socket, deadline) do
    case :gen_tcp.recv(socket, 9, max(0, deadline - System.monotonic_time(:millisecond))) do
      {:error, :timeout} ->
        :ok

      {:ok, <<size::24, type, _flags, 0::1, id::31>>} ->
        assert size <= 16_384
        if size > 0, do: assert({:ok, _} = :gen_tcp.recv(socket, size, @timeout))

        refute id === 1 and type in [0, 1, 9],
               "partially failed stream emitted DATA or a success termination after reset"

        assert_no_success(socket, deadline)

      other ->
        flunk("unexpected native downstream result after partial failure: #{inspect(other)}")
    end
  end

  defp frame(socket, deadline) do
    remaining = max(0, deadline - System.monotonic_time(:millisecond))
    assert remaining > 0, "native H2 frame exceeded finite deadline"
    assert {:ok, <<size::24, type, flags, 0::1, id::31>>} = :gen_tcp.recv(socket, 9, remaining)
    assert size <= 16_384

    payload =
      if size == 0 do
        ""
      else
        assert {:ok, bytes} =
                 :gen_tcp.recv(
                   socket,
                   size,
                   max(0, deadline - System.monotonic_time(:millisecond))
                 )

        bytes
      end

    {type, flags, id, payload}
  end
end
