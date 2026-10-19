defmodule Gaoxy.Proxy.ManagedH2FixedWriteLifecycleTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH2FixedFixture, as: F
  alias Gaoxy.Proxy.HTTP.Session
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports
  alias Gaoxy.HTTP.HTTP2.Frame
  alias Hell.Socket
  @moduletag :capture_log
  @timeout 5_000

  defmodule ObservedEndpoint do
    @behaviour Gaoxy.HTTP.Endpoint
    def init(options) do
      {observer, options} = Map.pop(options, :observer)
      {socket_options, options} = Map.pop(options, :socket_options, [])

      with {:ok, config} <- Gaoxy.Proxy.HTTP.init(options),
           do: {:ok, {observer, socket_options, config}}
    end

    def resources({_, _, config}), do: Gaoxy.Proxy.HTTP.resources(config)

    def call(exchange, {observer, socket_options, config}) do
      :ok = Hell.Socket.setopts(exchange.socket, socket_options)
      send(observer, {:write_lifecycle_exchange, self(), exchange.socket, exchange.gate})
      Gaoxy.Proxy.HTTP.call(exchange, config)
    end
  end

  # These two supplements use a real native H2 request/head/completion and the
  # real H1 downstream socket. A public Stream supplies one larger adapter event;
  # this is distinct from the four native-wire matrix cells and their frame cap.
  test "public Stream supplement writes every piece before one ACK and actual next DATA" do
    first = :binary.copy("a", 32_769)
    second = "actual-next-data"
    context = open_response(%{}, byte_size(first) + byte_size(second))
    barrier = send_barrier(context, [1, 3])
    supplement = supplement(context, [first, second])
    guardian = context.guardian
    stream = supplement.stream
    gate = context.gate

    assert_receive {:trace, ^guardian, :receive, {:stream_chunk, ^stream, ^first, first_ref}},
                   @timeout

    assert_receive {:write_lifecycle_piece, ^gate, 1, :ok}, @timeout
    assert {:ok, first_piece} = :gen_tcp.recv(context.socket, 16_384, @timeout)
    assert first_piece == binary_part(first, 0, 16_384)
    assert :sys.get_state(guardian).delivery == first_ref
    assert_original_pending(context)
    refute_ack(guardian, stream, first_ref)
    refute_receive {:write_lifecycle_writer_started, _, 2}, 0
    send(gate, {:write_lifecycle_continue, barrier, 1})

    assert_receive {:write_lifecycle_piece, ^gate, 3, :ok}, @timeout
    assert {:ok, tail} = :gen_tcp.recv(context.socket, byte_size(first) - 16_384, @timeout)
    assert first_piece <> tail == first
    assert :sys.get_state(guardian).delivery == first_ref
    assert_original_pending(context)
    refute_ack(guardian, stream, first_ref)
    refute_receive {:write_lifecycle_writer_started, _, 2}, 0
    send(gate, {:write_lifecycle_continue, barrier, 3})

    # Same-actor trace ordering rejects DATA2 observed before its preceding ACK.
    assert_ack_before_next(guardian, stream, first_ref, second)

    assert_receive {:trace, ^guardian, :receive, {:stream_chunk, ^stream, ^second, second_ref}},
                   @timeout

    assert {:ok, ^second} = :gen_tcp.recv(context.socket, byte_size(second), @timeout)
    assert_receive {:trace, ^guardian, :send, {:stream_chunk_ack, ^second_ref}, ^stream}, @timeout
    refute_ack(guardian, stream, first_ref)
    refute_ack(guardian, stream, second_ref)
    assert_writer_joined(supplement, [:ok, :ok])
    assert_original_pending(context)

    # The supplement never manufactures a native completion. Restore the actual
    # current native handle, then cancel/join its original held network request.
    :sys.replace_state(guardian, &%{&1 | request: context.native_handle})
    Session.cancel(guardian)
    assert_cancelled(context, supplement)
    assert {:error, :closed} = :gen_tcp.recv(context.socket, 0, @timeout)
    :ok = :gen_tcp.close(context.socket)
    F.close(context.f)
  end

  test "public Stream supplement fails after first16KiB of the same valid event without ACK or retry" do
    first = :binary.copy("b", 32_769)
    context = open_response(%{}, byte_size(first) + 4)
    barrier = send_barrier(context, [1])
    supplement = supplement(context, [first, "next"])
    guardian = context.guardian
    stream = supplement.stream
    gate = context.gate

    assert_receive {:trace, ^guardian, :receive, {:stream_chunk, ^stream, ^first, ref}}, @timeout
    assert_receive {:write_lifecycle_piece, ^gate, 1, :ok}, @timeout
    assert {:ok, piece} = :gen_tcp.recv(context.socket, 16_384, @timeout)
    assert piece == binary_part(first, 0, 16_384)
    assert_original_pending(context)
    refute_ack(guardian, stream, ref)

    # Close only the captured, public Gaoxy downstream socket, after the actual
    # first piece. The next real send operation fails without a network race.
    :ok = Socket.close(context.server_socket)
    send(gate, {:write_lifecycle_continue, barrier, 1})
    assert_receive {:write_lifecycle_piece, ^gate, 2, {:error, _}}, @timeout
    assert_cancelled(context, supplement)
    assert_writer_joined(supplement, [:error])
    refute_ack(guardian, stream, ref)
    refute_receive {:write_lifecycle_writer_started, _, 2}, 0
    refute_receive {:write_lifecycle_piece, ^gate, 3, _}, 0
    assert {:error, :closed} = :gen_tcp.recv(context.socket, 0, @timeout)
    :ok = :gen_tcp.close(context.socket)
    F.close(context.f)
  end

  test "managed H2 committed response closes at its real idle deadline without a second response" do
    context = open_response(%{idle_timeout: 200, max_lifetime: 5_000}, 1)
    started = System.monotonic_time(:millisecond)
    assert {:error, :closed} = :gen_tcp.recv(context.socket, 0, @timeout)
    assert System.monotonic_time(:millisecond) - started < 2_000
    assert_native_cancelled(context)
    :ok = :gen_tcp.close(context.socket)
    F.close(context.f)
  end

  test "managed H2 total deadline cancels a committed response that has delivered real DATA" do
    context = open_response(%{idle_timeout: 5_000, max_lifetime: 1_000}, 2)
    started = System.monotonic_time(:millisecond)

    F.command(context.f.peer, context.seen, "data", %{
      "body64" => Base.encode64("x"),
      "ended" => false
    })

    assert {:ok, "x"} = :gen_tcp.recv(context.socket, 1, @timeout)
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(context.completion, 0)
    assert {:error, :closed} = :gen_tcp.recv(context.socket, 0, @timeout)
    assert System.monotonic_time(:millisecond) - started < 3_000
    assert_native_cancelled(context)
    :ok = :gen_tcp.close(context.socket)
    F.close(context.f)
  end

  test "actual blocked H1 socket write reaches its endpoint write timeout before total expiry" do
    bytes = :binary.copy("w", 1_048_576)

    context =
      open_response(
        %{write_timeout: 80, idle_timeout: 5_000, max_lifetime: 5_000},
        byte_size(bytes),
        sndbuf: 1_024
      )

    :ok = :inet.setopts(context.socket, recbuf: 1_024, buffer: 1_024)
    send_barrier(context, [])
    started = System.monotonic_time(:millisecond)
    supplement = supplement(context, [bytes])
    guardian = context.guardian
    stream = supplement.stream

    assert_receive {:trace, ^guardian, :receive, {:stream_chunk, ^stream, ^bytes, ref}}, @timeout
    assert_write_timeout(context.gate, System.monotonic_time(:millisecond) + 2_000)
    assert System.monotonic_time(:millisecond) - started < 2_000
    assert_cancelled(context, supplement)
    assert_writer_joined(supplement, [:error])
    refute_ack(guardian, stream, ref)
    body = read_closed(context.socket, "", System.monotonic_time(:millisecond) + @timeout)
    assert byte_size(body) < byte_size(bytes)
    assert body == binary_part(bytes, 0, byte_size(body))
    :ok = :gen_tcp.close(context.socket)
    F.close(context.f)
  end

  test "native H2 zero flow credit reaches endpoint write timeout and resets without success termination" do
    f =
      F.fixture(:h2c, :http2, ["--manual"], %{
        endpoint: %{write_timeout: 80, idle_timeout: 5_000, max_lifetime: 5_000}
      })

    socket = F.connect(f)
    # SETTINGS precedes HEADERS on the same ordered TCP connection. No stream
    # credit is ever granted, so the subsequent DATA operation must time out.
    :ok = :gen_tcp.send(socket, Frame.encode(4, 0, 0, <<4::16, 0::32>>))
    :ok = F.send_request(f, socket, "GET", "/hold")
    seen = F.event(f.peer, "request")

    F.eventually(fn ->
      case :sys.get_state(f.owner).tokens |> Map.values() do
        [hold] -> match?(%HTTP.RequestCompletion{}, hold.completion)
        _ -> false
      end
    end)

    [hold] = :sys.get_state(f.owner).tokens |> Map.values()
    guardian = hold.guardian
    completion = hold.completion
    monitor = Process.monitor(guardian)

    F.command(f.peer, seen, "respond", %{
      "fields" => [["content-length", "1"]],
      "ended" => false
    })

    fields = h2_committed_head(socket, "", false, System.monotonic_time(:millisecond) + @timeout)
    assert {":status", "200"} in fields
    F.eventually(fn -> :sys.get_state(guardian).headers end)
    original = :sys.get_state(guardian).original_request
    assert original.completion == completion
    assert :erlang.trace(guardian, true, [:send]) == 1
    started = System.monotonic_time(:millisecond)
    F.command(f.peer, seen, "data", %{"body64" => Base.encode64("x"), "ended" => false})

    assert_receive {:trace, ^guardian, :send, {:gaoxy_proxy_http, ^guardian, {:chunk, "x", _}},
                    _},
                   @timeout

    assert 8 = h2_reset_without_success(socket, started + 2_000)
    assert System.monotonic_time(:millisecond) - started < 2_000
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout
    # The H2 connection and its Writer remain admitted while this downstream
    # socket is open. Request cleanup must finish before those physical holds.
    F.eventually(fn ->
      match?(
        %{active: 2, cleanup_pending: 0, cleanup_failed: nil},
        Gaoxy.status(f.instance, :http)
      ) and
        match?(
          {:ok, %{request_tokens: 0, helpers: 0, pins: 1}},
          Transports.status(f.owner)
        )
    end)

    assert_no_h2_success(socket, System.monotonic_time(:millisecond) + 100)
    :ok = :gen_tcp.close(socket)
    F.clean(f)
    F.close(f)
  end

  defp open_response(limits, body_length, socket_options \\ []) do
    endpoint = Map.merge(limits, %{observer: self(), socket_options: socket_options})

    f =
      F.fixture(:h2c, :http1, ["--manual"], %{
        endpoint_module: ObservedEndpoint,
        endpoint: endpoint
      })

    {socket, seen, guardian, completion} = F.hold(f)
    assert_receive {:write_lifecycle_exchange, pump, server_socket, gate}, @timeout
    assert :sys.get_state(guardian).owner == pump
    monitor = Process.monitor(guardian)

    F.command(f.peer, seen, "respond", %{
      "fields" => [["content-length", Integer.to_string(body_length)]],
      "ended" => false
    })

    assert F.h1_head(socket) =~ "200 OK"
    F.eventually(fn -> :sys.get_state(guardian).headers end)
    state = :sys.get_state(guardian)
    assert is_pid(state.request.stream)
    assert state.client.completion(state.original_request) == completion

    %{
      f: f,
      socket: socket,
      seen: seen,
      guardian: guardian,
      completion: completion,
      guardian_monitor: monitor,
      pump: pump,
      server_socket: server_socket,
      gate: gate,
      original: state.original_request,
      native_handle: state.request
    }
  end

  defp supplement(context, chunks) do
    {:ok, stream} = HTTP.Stream.start_link(0)
    Process.unlink(stream)
    stream_monitor = Process.monitor(stream)

    on_exit(fn ->
      if Process.alive?(stream) do
        monitor = Process.monitor(stream)
        HTTP.Stream.stop(stream, :cancelled)
        assert_receive {:DOWN, ^monitor, :process, ^stream, :normal}, @timeout
      end
    end)

    assert :erlang.trace(context.guardian, true, [:send, :receive]) == 1

    :sys.replace_state(context.guardian, fn state ->
      assert state.original_request == context.original
      request = %{state.request | stream: stream}
      :ok = state.client.subscribe(request)
      %{state | request: request}
    end)

    caller = self()

    writer =
      spawn(fn ->
        chunks
        |> Enum.with_index(1)
        |> Enum.reduce_while(:ok, fn {bytes, index}, :ok ->
          send(caller, {:write_lifecycle_writer_started, self(), index})
          result = HTTP.Stream.chunk(stream, bytes, @timeout)
          send(caller, {:write_lifecycle_writer_result, self(), index, result})
          if result == :ok, do: {:cont, :ok}, else: {:halt, result}
        end)
      end)

    writer_monitor = Process.monitor(writer)

    %{
      stream: stream,
      stream_monitor: stream_monitor,
      writer: writer,
      writer_monitor: writer_monitor
    }
  end

  defp send_barrier(context, held_pieces) do
    caller = self()
    barrier = make_ref()
    pump = context.pump
    gate = context.gate

    debug = fn count, event, _ ->
      case event do
        {:in, {:"$gen_call", {^pump, _}, {:finish_send, _, _, result}}} ->
          count = count + 1
          send(caller, {:write_lifecycle_piece, self(), count, result})

          if count in held_pieces do
            receive do
              {:write_lifecycle_continue, ^barrier, ^count} -> :ok
            after
              @timeout -> raise "downstream send barrier exceeded finite deadline"
            end
          end

          count

        _ ->
          count
      end
    end

    :ok = :sys.install(gate, {debug, 0})

    on_exit(fn ->
      for index <- held_pieces, do: send(gate, {:write_lifecycle_continue, barrier, index})
    end)

    barrier
  end

  defp assert_original_pending(context) do
    assert :sys.get_state(context.guardian).original_request == context.original
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(context.completion, 0)
    assert {:ok, %{request_tokens: 1, pins: 3}} = Transports.status(context.f.owner)
  end

  defp refute_ack(guardian, stream, ref) do
    refute_receive {:trace, ^guardian, :send, {:stream_chunk_ack, ^ref}, ^stream}, 0
  end

  defp assert_ack_before_next(guardian, stream, ref, next) do
    receive do
      {:trace, ^guardian, :send, {:stream_chunk_ack, ^ref}, ^stream} ->
        :ok

      {:trace, ^guardian, :receive, {:stream_chunk, ^stream, ^next, _}} ->
        flunk("actual next DATA preceded the previous whole-write ACK")
    after
      @timeout -> flunk("whole-write ACK did not arrive")
    end
  end

  defp assert_writer_joined(supplement, results) do
    writer = supplement.writer
    monitor = supplement.writer_monitor

    for {expected, index} <- Enum.with_index(results, 1) do
      if expected == :ok do
        assert_receive {:write_lifecycle_writer_result, ^writer, ^index, :ok}, @timeout
      else
        assert_receive {:write_lifecycle_writer_result, ^writer, ^index, {:error, _}}, @timeout
      end
    end

    assert_receive {:DOWN, ^monitor, :process, ^writer, :normal}, @timeout
  end

  defp assert_native_cancelled(context) do
    guardian = context.guardian
    monitor = context.guardian_monitor
    assert :ok = HTTP.RequestCompletion.await(context.completion, @timeout)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout
    F.clean(context.f)
  end

  defp assert_cancelled(context, supplement) do
    assert_native_cancelled(context)
    stream = supplement.stream
    monitor = supplement.stream_monitor
    assert_receive {:DOWN, ^monitor, :process, ^stream, :normal}, @timeout
  end

  defp assert_write_timeout(gate, deadline) do
    receive do
      {:write_lifecycle_piece, ^gate, _, :ok} ->
        assert_write_timeout(gate, deadline)

      {:write_lifecycle_piece, ^gate, _, {:error, :timeout}} ->
        :ok

      {:write_lifecycle_piece, ^gate, _, {:error, {:timeout, _}}} ->
        :ok

      {:write_lifecycle_piece, ^gate, _, other} ->
        flunk("unexpected actual write result #{inspect(other)}")
    after
      max(0, deadline - System.monotonic_time(:millisecond)) ->
        flunk("actual socket write did not time out")
    end
  end

  defp read_closed(socket, accumulated, deadline) do
    assert byte_size(accumulated) <= 1_048_576

    case :gen_tcp.recv(socket, 0, max(0, deadline - System.monotonic_time(:millisecond))) do
      {:ok, bytes} -> read_closed(socket, accumulated <> bytes, deadline)
      {:error, reason} when reason in [:closed, :econnreset] -> accumulated
      other -> flunk("downstream did not terminate within finite deadline: #{inspect(other)}")
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
          assert {:ok, fields, _} = HPAX.decode(block, HPAX.new(4_096))
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
        if length > 0 do
          assert {:ok, _} = :gen_tcp.recv(socket, length, @timeout)
        end

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
end
