defmodule GaoxyQUICConsumerTest do
  use ExUnit.Case, async: true
  alias Gaoxy.QUIC
  @moduletag :tmp_dir
  @moduletag timeout: 120_000

  defmodule Echo do
    @behaviour Gaoxy.QUICHandler
    def init(connection, metadata, observer) do
      send(observer, {:connection, connection, metadata})

      {:ok,
       %{
         connection: connection,
         ready: false,
         local: false,
         local_uni: false,
         ids: MapSet.new(),
         uni_bytes: %{},
         streams: %{},
         pending: %{},
         observer: observer
       }}
    end

    def handle_event({:ready, metadata}, state) do
      send(state.observer, {:ready_metadata, metadata})
      progress(%{state | ready: true})
    end

    def handle_event({:stream_open, stream, :bidi}, state),
      do: {:ok, %{state | streams: Map.put_new(state.streams, stream, :echo)}}

    def handle_event({:stream_open, stream, :uni}, state),
      do: {:ok, %{state | streams: Map.put_new(state.streams, stream, :uni)}}

    def handle_event({:stopped, stream, code}, state) do
      send(state.observer, {:peer_stopped, code})

      {:ok,
       %{
         state
         | streams: Map.delete(state.streams, stream),
           pending: Map.delete(state.pending, stream)
       }}
    end

    def handle_event(event, state) when event in [:tick, :writable], do: progress(state)
    def handle_event({:readable, _}, state), do: progress(state)
    def handle_event(_, state), do: {:ok, state}

    # Host polling may emit :tick before the engine authenticates peer parameters.
    defp progress(%{ready: false} = state), do: {:ok, state}

    defp progress(state) do
      with {:ok, state} <- open_local(state), {:ok, state} <- open_local_uni(state) do
        Enum.reduce_while(state.streams, {:ok, state}, fn {stream, kind}, {:ok, acc} ->
          with {:ok, next} <- read(acc, stream, kind), {:ok, next} <- flush(next, stream) do
            {:cont, {:ok, next}}
          else
            failure -> {:halt, failure}
          end
        end)
      end
    end

    defp open_local(%{local: true} = state), do: {:ok, state}

    defp open_local(state) do
      case QUIC.open_stream(state.connection, :bidi) do
        {:ok, stream} ->
          send(
            state.observer,
            {:bounds, QUIC.send_stream(stream, :binary.copy("x", 4097)), QUIC.read(stream, 0),
             QUIC.open_stream(state.connection, :bidi, ref: make_ref())}
          )

          send(state.observer, {:flow_control, QUIC.send_stream(stream, :binary.copy("x", 4096))})

          {:ok,
           %{
             state
             | local: true,
               streams: Map.put(state.streams, stream, :local),
               pending:
                 Map.put(state.pending, stream, {:binary.copy("x", 4096) <> "server-fin", true})
           }}

        {:blocked, _} ->
          {:ok, state}

        failure ->
          {:stop, {:open_failed, failure}, state}
      end
    end

    defp open_local_uni(%{local_uni: true} = state), do: {:ok, state}

    defp open_local_uni(state) do
      case QUIC.open_stream(state.connection, :uni) do
        {:ok, stream} ->
          {:ok,
           %{
             state
             | local_uni: true,
               streams: Map.put(state.streams, stream, :local_uni),
               pending: Map.put(state.pending, stream, {"server-uni-fin", true})
           }}

        {:blocked, _} ->
          {:ok, state}

        failure ->
          {:stop, {:open_uni_failed, failure}, state}
      end
    end

    defp read(state, _stream, :local_uni), do: {:ok, state}

    defp read(state, stream, kind) do
      if Map.has_key?(state.pending, stream) do
        {:ok, state}
      else
        case QUIC.read(stream, 1024) do
          {:ok, items} ->
            {:ok,
             Enum.reduce(items, record_ids(state, items, kind), fn
               {:data, id, bytes}, s when kind == :uni ->
                 %{s | uni_bytes: Map.update(s.uni_bytes, id, bytes, &(&1 <> bytes))}

               {:fin, id}, s when kind == :uni ->
                 send(s.observer, {:uni_received, id, Map.get(s.uni_bytes, id, <<>>)})

                 %{
                   s
                   | streams: Map.delete(s.streams, stream),
                     uni_bytes: Map.delete(s.uni_bytes, id)
                 }

               {:data, _, bytes}, s when kind == :echo ->
                 if bytes == "listener-remove",
                   do: send(s.observer, {:remove_ready, s.connection})

                 pending(s, stream, bytes, false)

               {:fin, _}, s when kind == :echo ->
                 pending(s, stream, <<>>, true)

               {:data, _, bytes}, s ->
                 send(s.observer, {:after_fin, bytes})
                 s

               {:fin, _}, s ->
                 %{s | streams: Map.delete(s.streams, stream)}

               {:reset, id, code, final_size}, s ->
                 send(s.observer, {:peer_reset, id, code, final_size})

                 %{
                   s
                   | streams: Map.delete(s.streams, stream),
                     pending: Map.delete(s.pending, stream)
                 }
             end)}

          error ->
            {:stop, {:read_failed, error}, state}
        end
      end
    end

    defp record_ids(state, items, kind) do
      Enum.reduce(items, state, fn item, acc ->
        id = elem(item, 1)

        if MapSet.member?(acc.ids, id) do
          acc
        else
          send(acc.observer, {:numeric_read_id, kind, id})
          %{acc | ids: MapSet.put(acc.ids, id)}
        end
      end)
    end

    defp pending(state, stream, bytes, fin) do
      {previous, _} = Map.get(state.pending, stream, {<<>>, false})
      %{state | pending: Map.put(state.pending, stream, {previous <> bytes, fin})}
    end

    defp flush(state, stream) do
      case state.pending[stream] do
        nil ->
          {:ok, state}

        {bytes, fin} ->
          size = min(byte_size(bytes), 1024)
          <<chunk::binary-size(^size), rest::binary>> = bytes
          final = fin and rest == <<>>

          case QUIC.send_stream(stream, chunk, final) do
            {:ok, operation} ->
              send(
                state.observer,
                {:write, operation, QUIC.operation_status(stream.connection, operation)}
              )

              streams =
                if final and state.streams[stream] in [:echo, :local_uni],
                  do: Map.delete(state.streams, stream),
                  else: state.streams

              pending =
                if rest == <<>>,
                  do: Map.delete(state.pending, stream),
                  else: Map.put(state.pending, stream, {rest, fin})

              {:ok, %{state | streams: streams, pending: pending}}

            {:blocked, reason} ->
              send(state.observer, {:blocked, reason})
              {:ok, state}

            {:error, :stopped} ->
              # STOP may change the engine between this batch's poll and write.
              # Its queued event still reports the peer code on the next poll.
              {:ok,
               %{
                 state
                 | streams: Map.delete(state.streams, stream),
                   pending: Map.delete(state.pending, stream)
               }}

            failure ->
              {:stop, {:write_failed, failure}, state}
          end
      end
    end
  end

  defmodule Controls do
    @behaviour Gaoxy.QUICHandler
    def init(_, _, observer), do: {:ok, %{observer: observer}}

    def handle_event({:readable, stream}, state) do
      {:ok, items} = QUIC.read(stream, 1024)

      for {:data, _, bytes} <- items do
        case bytes do
          "reset" -> send(state.observer, {:reset_result, QUIC.reset_stream(stream, 0x12345)})
          "stop" -> send(state.observer, {:stop_result, QUIC.stop_stream(stream, 0x54321)})
        end
      end

      {:ok, state}
    end

    def handle_event(_, state), do: {:ok, state}
  end

  defmodule TCP do
    def init(_, _), do: {:ok, nil}
    def handle_data(bytes, state), do: {:send, bytes, state}
  end

  test "late stream_open preserves the locally opened stream role" do
    stream = %QUIC.Stream{handle: make_ref(), connection: nil}
    state = %{streams: %{stream => :local}}

    assert {:ok, ^state} = Echo.handle_event({:stream_open, stream, :bidi}, state)
  end

  test "peer unidirectional streams are retained for explicit pull consumption" do
    stream = %QUIC.Stream{handle: make_ref(), connection: nil}
    state = %{streams: %{}}

    assert {:ok, %{streams: %{^stream => :uni}}} =
             Echo.handle_event({:stream_open, stream, :uni}, state)
  end

  test "peer STOP removes queued bytes from only its send direction" do
    stream = %QUIC.Stream{handle: make_ref(), connection: nil}
    sibling = %QUIC.Stream{handle: make_ref(), connection: nil}

    state = %{
      streams: %{stream => :local, sibling => :echo},
      pending: %{stream => {"queued", true}},
      observer: self()
    }

    assert {:ok, next} = Echo.handle_event({:stopped, stream, 0x222}, state)
    assert next.streams == %{sibling => :echo}
    assert next.pending == %{}
    assert_receive {:peer_stopped, 0x222}
  end

  test "public optional host: verified streams, directional controls, bounds and isolation", %{
    tmp_dir: directory
  } do
    {_, 0} = System.cmd("bash", ["../../scripts/generate-fixtures.sh", directory])

    services =
      for {id, handler} <- [{"echo", Echo}, {"sibling", Echo}, {"controls", Controls}] do
        %{
          id: id,
          transport: :quic,
          handler: handler,
          handler_options: self(),
          tls: %{
            certfile: Path.join(directory, "cert.pem"),
            keyfile: Path.join(directory, "key.pem")
          },
          quic: %{alpn: ["h3"]},
          limits: %{max_active: 4, max_packet: 4096, max_output: 4096, max_bytes: 262_144}
        }
      end

    runtime =
      start_supervised!(
        {Gaoxy, services: services ++ [%{id: "tcp", transport: :tcp, handler: TCP}]}
      )

    {:ok, {_, echo}} = Gaoxy.info(runtime, "echo").local
    {:ok, {_, controls}} = Gaoxy.info(runtime, "controls").local
    {:ok, {_, sibling}} = Gaoxy.info(runtime, "sibling").local
    assert %{pause: :unsupported, drain: :local_host_cleanup} = Gaoxy.info(runtime, "echo")
    assert {:error, {:unsupported_capability, :quic_pause}} = Gaoxy.pause(runtime, "echo")
    assert {:error, {:unsupported_capability, :quic_pause}} = Gaoxy.resume(runtime, "echo")

    observer = self()
    reference = make_ref()
    generation = Gaoxy.handle(runtime, "echo").generation

    :ok =
      :telemetry.attach(
        reference,
        [:gaoxy, :send],
        fn _, _, metadata, _ ->
          if metadata.generation == generation,
            do: send(observer, {:send_outcome, metadata.operation, metadata.outcome})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(reference) end)

    assert {:error, {:unsupported_capability, :drain}} =
             Gaoxy.add(
               runtime,
               Map.merge(hd(services), %{id: "strong-drain", capabilities: [:drain]})
             )

    peer(echo, directory, "echo")

    assert_receive {:bounds, {:error, :output_limit}, {:error, :invalid_read_limit},
                    {:error, :invalid_operation_options}},
                   2000

    assert_receive {:ready_metadata, %{alpn: "h3", tls_complete: true, parameters_valid: true}},
                   2000

    assert_receive {:numeric_read_id, :echo, 0}, 2000
    assert_receive {:numeric_read_id, :local, 1}, 2000
    assert_receive {:numeric_read_id, :uni, 2}, 2000
    assert_receive {:uni_received, 2, "peer-uni-fragment"}, 2000
    assert_receive {:after_fin, "after-server-fin"}, 2000
    assert_receive {:flow_control, {:blocked, %{type: :data_blocked}}}, 2000
    assert_receive {:send_outcome, blocked, {:blocked, %{type: :data_blocked}}}, 2000
    assert is_reference(blocked)
    assert_receive {:write, operation, status}, 2000
    assert is_reference(operation)
    assert %{status: :admitted, result: {:ok, ^operation}} = status
    assert_receive {:send_outcome, ^operation, {:admitted, ^operation}}, 2000
    peer(echo, directory, "isolation")
    peer(controls, directory, "controls")
    peer(echo, directory, "peer-controls")
    assert_receive {:peer_reset, 0, 0x111, 6}, 2000
    assert_receive {:peer_stopped, 0x222}, 2000
    assert_receive {:reset_result, {:ok, reset}}, 2000
    assert_receive {:stop_result, {:ok, stop}}, 2000
    assert is_reference(reset) and is_reference(stop)
    peer(echo, directory, "negative", "gaoxy-unsupported-v1")
    wrong = Path.join(directory, "wrong-ca")
    {_, 0} = System.cmd("bash", ["../../scripts/generate-fixtures.sh", wrong])
    peer(echo, wrong, "negative")
    peer(echo, directory, "negative", "h3", nil, "invalid.example")

    {:ok, {ip, port}} = Gaoxy.info(runtime, "tcp").local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 2000)
    :ok = :gen_tcp.send(socket, "quic-independent-sibling")
    assert {:ok, "quic-independent-sibling"} = :gen_tcp.recv(socket, 0, 2000)
    :gen_tcp.close(socket)
    assert %{retained_high_water: high} = Gaoxy.status(runtime, "echo")
    assert high <= 262_144

    IO.inspect(
      %{
        retained_high_water: high,
        callback_timeout_ms: 5000,
        public_read_ids: [0, 1, 2],
        readiness_before_reads: true
      },
      label: "QUIC_HOST_OBSERVATIONS"
    )

    holding = Task.async(fn -> peer(echo, directory, "listener", "h3", sibling) end)
    assert_receive {:remove_ready, connection}, 5000
    gate_monitor = Process.monitor(connection.gate)
    started = System.monotonic_time(:millisecond)
    :ok = Gaoxy.remove(runtime, "echo", 2000)
    elapsed = System.monotonic_time(:millisecond) - started
    assert elapsed <= 2000
    IO.inspect(%{remove_elapsed_ms: elapsed, deadline_ms: 2000}, label: "QUIC_LOCAL_CLEANUP")
    assert_receive {:DOWN, ^gate_monitor, :process, _, _}, 1000
    assert "echo" not in Gaoxy.services(runtime)
    Task.await(holding, 20_000)

    assert {:ok, %{id: "echo", generation: _}} =
             Gaoxy.add(runtime, Map.put(hd(services), :port, echo))

    assert {:ok, {_, ^echo}} = Gaoxy.info(runtime, "echo").local
    assert Gaoxy.handle(runtime, "echo").generation != generation
    peer(echo, directory, "echo")
    :ok = Gaoxy.remove(runtime, "echo", 2000)
    IO.puts("PASS QUIC_LIVE_LISTENER_STOP_SIBLING_REBIND")
    IO.puts("PASS QUIC_FACADE_WIRE_BOUNDS_LIFECYCLE")
  end

  defp peer(port, directory, mode, alpn \\ "h3", sibling \\ nil, server_name \\ "localhost") do
    {output, exit} =
      System.cmd(
        System.get_env("GAOXY_QUIC_PYTHON", Path.expand(".venv/bin/python")),
        [
          "peer.py",
          "--port",
          Integer.to_string(port),
          "--ca",
          Path.join(directory, "ca.pem"),
          "--mode",
          mode,
          "--alpn",
          alpn,
          "--server-name",
          server_name
        ] ++ if(sibling, do: ["--sibling-port", Integer.to_string(sibling)], else: []),
        stderr_to_stdout: true
      )

    IO.write(output)
    assert exit == 0, "independent #{mode} peer exit #{exit}"
    assert output =~ "\"result\": \"PASS\""
  end
end
