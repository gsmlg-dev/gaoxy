Code.require_file("support/managed_h2_group_fixture.exs", __DIR__)

defmodule Gaoxy.Proxy.ManagedH2GroupLifecycleTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH2GroupFixture, as: G
  alias Gaoxy.Proxy.ManagedH2FixedFixture, as: F
  alias Gaoxy.Proxy.{ManagedH2GroupBoundary, UpstreamGroups, UpstreamTransports}
  alias Gaoxy.HTTP.HTTP2.Frame
  alias HTTP.HTTP2.HPACK
  @moduletag :capture_log
  @timeout 5_000
  @reserve 16_478_862

  setup do
    assert :ok === boundary(:activation)
    :ok
  end

  for protocol <- [:http2, :h2c] do
    @protocol protocol
    test "group #{protocol} GOAWAY never replays the failed original and later work uses a new real connection" do
      f = G.fixture(@protocol, :http1, ["--manual"])
      {socket, seen, guardian, completion} = G.hold(f)
      monitor = Process.monitor(guardian)
      assert G.assert_cleanup(f, 1) === @reserve
      G.command(f.peer, seen, "goaway", %{"last_stream" => 0, "code" => 0})
      assert %{status: 502} = G.response(f, socket)
      :ok = :gen_tcp.close(socket)
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout
      G.clean(f)
      G.no_event(f.peer, "request")
      {next_socket, next, _, next_completion} = G.hold(f, "/hold/later")
      refute next["connection"] === seen["connection"]
      G.command(f.peer, next, "respond", %{"fields" => [["content-length", "0"]]})
      assert %{status: 200, body: ""} = G.response(f, next_socket)
      :ok = :gen_tcp.close(next_socket)
      assert :ok = HTTP.RequestCompletion.await(next_completion, @timeout)
      G.clean(f)
      G.no_event(f.peer, "request")
      G.close(f)
    end

    test "group #{protocol} public producer death joins the identical original G and T completion without replay" do
      f = G.fixture(@protocol, :http1, ["--manual"])
      {barrier, debug} = bind_barrier(f.groups)
      socket = G.connect(f)
      :ok = G.send_request(f, socket, "POST", "/echo", [{"content-length", "3"}], false)
      groups = f.groups
      group = f.group

      assert_receive {:group_lifecycle_bind_held, ^groups, guardian,
                      {:bind, ^group, _, completion}},
                     @timeout

      assert %HTTP.RequestCompletion{} = completion
      [{_, transport}] = Map.to_list(:sys.get_state(f.owner).tokens)
      assert transport.guardian === guardian
      assert transport.completion === completion
      assert :erlang.trace(guardian, true, [:send]) === 1
      refute_receive {:trace, ^guardian, :send, {:gaoxy_proxy_http, _, {:ready, _, _, _}}, _}, 0
      send(groups, {:group_lifecycle_continue, barrier})

      assert_receive {:trace, ^guardian, :send,
                      {:gaoxy_proxy_http, ^guardian, {:ready, upload, _, _}}, _},
                     @timeout

      assert is_pid(upload)
      :ok = :sys.remove(groups, debug)
      assert %{"target" => "/echo"} = G.event(f.peer, "request")
      [{_, held}] = Map.to_list(:sys.get_state(groups).tokens)
      assert held.guardian === guardian
      assert held.completion === completion
      assert G.assert_cleanup(f, 1) === @reserve
      G.no_event(f.peer, "upload")
      upload_monitor = Process.monitor(upload)
      guardian_monitor = Process.monitor(guardian)
      Process.exit(upload, :kill)
      assert_receive {:DOWN, ^upload_monitor, :process, ^upload, :killed}, @timeout
      assert %{status: 502} = G.response(f, socket)
      :ok = :gen_tcp.close(socket)
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
      G.clean(f)
      G.no_event(f.peer, "upload")
      G.no_event(f.peer, "request")
      G.close(f)
    end

    for action <- [:disconnect, :pump_owner_death] do
      @action action
      test "group #{protocol} #{action} joins its original before both owner ledgers refund and a healthy sibling proceeds" do
        f = G.fixture(@protocol, :http1, ["--manual"])
        {socket, seen, guardian, completion} = G.hold(f)
        monitor = Process.monitor(guardian)
        assert G.assert_cleanup(f, 1) === @reserve
        assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)

        case @action do
          :disconnect -> :ok = :gen_tcp.close(socket)
          :pump_owner_death -> Process.exit(:sys.get_state(guardian).owner, :kill)
        end

        assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
        assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout
        :ok = :gen_tcp.close(socket)
        G.clean(f)
        {later_socket, later, _, later_completion} = G.hold(f, "/hold/sibling")
        assert later["connection"] === seen["connection"]
        G.command(f.peer, later, "respond", %{"fields" => [["content-length", "0"]]})
        assert %{status: 200, body: ""} = G.response(f, later_socket)
        :ok = :gen_tcp.close(later_socket)
        assert :ok = HTTP.RequestCompletion.await(later_completion, @timeout)
        G.clean(f)
        G.no_event(f.peer, "request")
        G.close(f)
      end
    end

    for failed <- [false, true] do
      @failed failed
      test "group #{protocol} actual whole native DATA write failed=#{failed} controls the sole ACK and original holds" do
        f = G.fixture(@protocol, :http1, ["--manual"])
        {socket, seen, guardian, completion} = G.hold(f)
        pump = :sys.get_state(guardian).owner
        assert :erlang.trace(guardian, true, [:send]) === 1
        assert :erlang.suspend_process(pump)
        on_exit(fn -> safe_resume(pump) end)

        try do
          G.command(f.peer, seen, "respond", %{
            "ended" => false,
            "fields" => [["content-length", "65536"]]
          })

          G.command(f.peer, seen, "data", %{
            "body64" => Base.encode64(String.duplicate("d", 65_536)),
            "ended" => true
          })

          G.eventually(fn -> :sys.get_state(guardian).delivery != nil end)
          state = :sys.get_state(guardian)
          stream = state.request.stream
          ref = state.delivery
          refute_receive {:trace, ^guardian, :send, {:stream_chunk_ack, ^ref}, ^stream}, 0
          assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
          assert %{inflight: 1} = UpstreamGroups.status(f.group)
          assert {:ok, %{request_tokens: 1, pins: 3}} = UpstreamTransports.status(f.owner)
          assert G.assert_cleanup(f, 1) === @reserve
          if @failed, do: :ok = :gen_tcp.close(socket)
          assert :erlang.resume_process(pump)

          if @failed do
            assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
            G.clean(f)
            refute_receive {:trace, ^guardian, :send, {:stream_chunk_ack, ^ref}, ^stream}, 0
          else
            assert %{status: 200, body: bytes} = G.response(f, socket)
            assert bytes === String.duplicate("d", 65_536)

            assert_receive {:trace, ^guardian, :send, {:stream_chunk_ack, ^ref}, ^stream},
                           @timeout

            refute_receive {:trace, ^guardian, :send, {:stream_chunk_ack, ^ref}, ^stream}, 0
            :ok = :gen_tcp.close(socket)
            assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
            G.clean(f)
          end
        after
          safe_resume(pump)
        end

        G.no_event(f.peer, "request")
        G.close(f)
      end
    end

    for deadline_kind <- [:idle, :total] do
      @deadline_kind deadline_kind
      test "group #{protocol} actual #{@deadline_kind} deadline terminates an already committed native response and joins original holds" do
        limits =
          case @deadline_kind do
            :idle -> %{idle_timeout: 200, max_lifetime: 5_000}
            :total -> %{idle_timeout: 5_000, max_lifetime: 1_000}
          end

        f = G.fixture(@protocol, :http1, ["--manual"], %{endpoint: limits})
        {socket, seen, guardian, completion} = G.hold(f)
        monitor = Process.monitor(guardian)

        G.command(f.peer, seen, "respond", %{
          "ended" => false,
          "fields" => [["content-length", "2"]]
        })

        assert F.h1_head(socket) =~ "200 OK"
        G.eventually(fn -> :sys.get_state(guardian).headers end)
        assert :sys.get_state(guardian).original_request.completion === completion
        assert G.assert_cleanup(f, 1) === @reserve
        started = System.monotonic_time(:millisecond)

        if @deadline_kind == :total do
          G.command(f.peer, seen, "data", %{"body64" => Base.encode64("x"), "ended" => false})
          assert {:ok, "x"} = :gen_tcp.recv(socket, 1, @timeout)
        end

        assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
        assert System.monotonic_time(:millisecond) - started < 3_000
        assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
        assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout
        :ok = :gen_tcp.close(socket)
        G.clean(f)
        G.no_event(f.peer, "request")
        G.close(f)
      end
    end

    test "group #{protocol} native H2 zero flow credit times out the actual write without success termination or early refund" do
      f =
        G.fixture(@protocol, :http2, ["--manual"], %{
          endpoint: %{write_timeout: 80, idle_timeout: 5_000, max_lifetime: 5_000}
        })

      socket = G.connect(f)
      :ok = :gen_tcp.send(socket, Frame.encode(4, 0, 0, <<4::16, 0::32>>))
      :ok = G.send_request(f, socket, "GET", "/hold/zero-credit")
      seen = G.event(f.peer, "request")
      assert seen["target"] === "/hold/zero-credit"
      G.eventually(fn -> G.held_selection(f, "/hold/zero-credit") != nil end)
      {_, held} = G.held_selection(f, "/hold/zero-credit")
      guardian = held.guardian
      completion = held.completion
      monitor = Process.monitor(guardian)
      assert G.assert_cleanup(f, 1) === @reserve

      G.command(f.peer, seen, "respond", %{
        "ended" => false,
        "fields" => [["content-length", "1"]]
      })

      fields =
        h2_committed_head(socket, "", false, System.monotonic_time(:millisecond) + @timeout)

      assert {":status", "200"} in fields
      G.eventually(fn -> :sys.get_state(guardian).headers end)
      assert :sys.get_state(guardian).original_request.completion === completion
      assert :erlang.trace(guardian, true, [:send]) === 1
      started = System.monotonic_time(:millisecond)
      G.command(f.peer, seen, "data", %{"body64" => Base.encode64("x"), "ended" => false})

      assert_receive {:trace, ^guardian, :send, {:gaoxy_proxy_http, ^guardian, {:chunk, "x", _}},
                      _},
                     @timeout

      assert 8 === h2_reset_without_success(socket, started + 2_000)
      assert System.monotonic_time(:millisecond) - started < 2_000
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout

      G.eventually(fn ->
        match?(
          %{active: 2, cleanup_pending: 0, cleanup_failed: nil},
          Gaoxy.status(f.instance, :http)
        ) and
          match?(%{inflight: 0}, UpstreamGroups.status(f.group)) and
          match?(
            {:ok, %{request_tokens: 0, helpers: 0, pins: 1}},
            UpstreamTransports.status(f.owner)
          )
      end)

      assert_no_h2_success(socket, System.monotonic_time(:millisecond) + 100)
      :ok = :gen_tcp.close(socket)
      G.clean(f)
      G.no_event(f.peer, "request")
      G.close(f)
    end
  end

  defp bind_barrier(owner) do
    parent = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      case event do
        {:in, {:"$gen_call", {guardian, _}, {:bind, _, _, _} = request}} when not held ->
          send(parent, {:group_lifecycle_bind_held, self(), guardian, request})
          monitor = Process.monitor(parent)

          try do
            receive do
              {:group_lifecycle_continue, ^barrier} -> :ok
              {:DOWN, ^monitor, :process, ^parent, _} -> :ok
            after
              @timeout -> raise "real group lifecycle bind barrier expired"
            end
          after
            Process.demonitor(monitor, [:flush])
          end

          true

        _ ->
          held
      end
    end

    :ok = :sys.install(owner, {debug, false})

    on_exit(fn ->
      send(owner, {:group_lifecycle_continue, barrier})
      if Process.alive?(owner), do: :sys.remove(owner, debug)
    end)

    {barrier, debug}
  end

  defp safe_resume(pid) do
    try do
      :erlang.resume_process(pid)
    catch
      :error, :badarg -> :ok
    end
  end

  defp h2_committed_head(socket, block, ended, deadline) do
    {type, flags, id, payload} = h2_frame(socket, deadline)

    cond do
      type == 4 and flags == 0 ->
        :ok = :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
        h2_committed_head(socket, block, ended, deadline)

      type in [1, 9] and id == 1 ->
        ended = ended or (type == 1 and Bitwise.band(flags, 1) == 1)
        block = block <> payload
        assert byte_size(block) <= 65_536

        if Bitwise.band(flags, 4) == 0 do
          h2_committed_head(socket, block, ended, deadline)
        else
          refute ended, "head unexpectedly terminated the still-open upstream response"

          assert {:ok, _, fields} =
                   HPACK.decode(HPACK.new_decoder(max_dynamic_size: 4_096), block)

          fields
        end

      type in [4, 8] ->
        h2_committed_head(socket, block, ended, deadline)

      true ->
        flunk("unexpected frame before committed head #{inspect({type, flags, id})}")
    end
  end

  defp h2_reset_without_success(socket, deadline) do
    case h2_frame(socket, deadline) do
      {3, _, 1, <<code::32>>} ->
        code

      {type, _, 1, _} when type in [0, 1, 9] ->
        flunk("zero-credit stream emitted DATA or a second response before reset")

      {type, _, _, _} when type in [4, 8] ->
        h2_reset_without_success(socket, deadline)

      other ->
        flunk("unexpected frame while awaiting bounded write reset #{inspect(other)}")
    end
  end

  defp assert_no_h2_success(socket, deadline) do
    case :gen_tcp.recv(socket, 9, max(0, deadline - System.monotonic_time(:millisecond))) do
      {:error, :timeout} ->
        :ok

      {:ok, <<length::24, type, _flags, 0::1, id::31>>} ->
        if length > 0, do: assert({:ok, _} = :gen_tcp.recv(socket, length, @timeout))

        refute id == 1 and type in [0, 1, 9],
               "reset stream emitted a success termination or second response"

        assert_no_h2_success(socket, deadline)

      other ->
        flunk("unexpected downstream result after stream reset #{inspect(other)}")
    end
  end

  defp h2_frame(socket, deadline) do
    remaining = max(0, deadline - System.monotonic_time(:millisecond))
    assert remaining > 0, "HTTP/2 frame exceeded finite deadline"
    assert {:ok, <<length::24, type, flags, 0::1, id::31>>} = :gen_tcp.recv(socket, 9, remaining)
    assert length <= 16_384

    payload =
      if length == 0 do
        ""
      else
        assert {:ok, payload} =
                 :gen_tcp.recv(
                   socket,
                   length,
                   max(0, deadline - System.monotonic_time(:millisecond))
                 )

        payload
      end

    {type, flags, id, payload}
  end

  defp boundary(function), do: apply(ManagedH2GroupBoundary, function, [])
end
