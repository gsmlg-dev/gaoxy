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
         streams: %{},
         pending: %{},
         observer: observer
       }}
    end

    def handle_event({:ready, _metadata}, state), do: progress(%{state | ready: true})

    def handle_event({:stream_open, stream, :bidi}, state),
      do: {:ok, %{state | streams: Map.put(state.streams, stream, :echo)}}

    def handle_event(event, state) when event in [:tick, :writable], do: progress(state)
    def handle_event({:readable, _}, state), do: progress(state)
    def handle_event(_, state), do: {:ok, state}

    # Host polling may emit :tick before the engine authenticates peer parameters.
    defp progress(%{ready: false} = state), do: {:ok, state}

    defp progress(state) do
      with {:ok, state} <- open_local(state) do
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
               pending: Map.put(state.pending, stream, {"server-fin", true})
           }}

        {:blocked, _} ->
          {:ok, state}

        failure ->
          {:stop, {:open_failed, failure}, state}
      end
    end

    defp read(state, stream, kind) do
      if Map.has_key?(state.pending, stream) do
        {:ok, state}
      else
        case QUIC.read(stream, 1024) do
          {:ok, items} ->
            {:ok,
             Enum.reduce(items, state, fn
               {:data, _, bytes}, s when kind == :echo ->
                 pending(s, stream, bytes, false)

               {:fin, _}, s when kind == :echo ->
                 pending(s, stream, <<>>, true)

               {:data, _, bytes}, s ->
                 send(s.observer, {:after_fin, bytes})
                 s

               {:fin, _}, s ->
                 %{s | streams: Map.delete(s.streams, stream)}

               {:reset, _, _, _}, s ->
                 %{s | streams: Map.delete(s.streams, stream)}
             end)}

          error ->
            {:stop, {:read_failed, error}, state}
        end
      end
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
          case QUIC.send_stream(stream, bytes, fin) do
            {:ok, operation} ->
              send(
                state.observer,
                {:write, operation, QUIC.operation_status(stream.connection, operation)}
              )

              streams =
                if fin and state.streams[stream] == :echo,
                  do: Map.delete(state.streams, stream),
                  else: state.streams

              {:ok, %{state | streams: streams, pending: Map.delete(state.pending, stream)}}

            {:blocked, reason} ->
              send(state.observer, {:blocked, reason})
              {:ok, state}

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

  test "public optional host: verified streams, directional controls, bounds and isolation", %{
    tmp_dir: directory
  } do
    {_, 0} = System.cmd("bash", ["../../scripts/generate-fixtures.sh", directory])

    services =
      for {id, handler} <- [{"echo", Echo}, {"controls", Controls}] do
        %{
          id: id,
          transport: :quic,
          handler: handler,
          handler_options: self(),
          tls: %{
            certfile: Path.join(directory, "cert.pem"),
            keyfile: Path.join(directory, "key.pem")
          },
          quic: %{alpn: ["gaoxy-stream-v1"]},
          limits: %{max_active: 4, max_packet: 4096, max_output: 4096, max_bytes: 262_144}
        }
      end

    runtime =
      start_supervised!(
        {Gaoxy, services: services ++ [%{id: "tcp", transport: :tcp, handler: TCP}]}
      )

    {:ok, {_, echo}} = Gaoxy.info(runtime, "echo").local
    {:ok, {_, controls}} = Gaoxy.info(runtime, "controls").local
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
    assert_receive {:reset_result, {:ok, reset}}, 2000
    assert_receive {:stop_result, {:ok, stop}}, 2000
    assert is_reference(reset) and is_reference(stop)
    peer(echo, directory, "negative", "gaoxy-unsupported-v1")
    wrong = Path.join(directory, "wrong-ca")
    {_, 0} = System.cmd("bash", ["../../scripts/generate-fixtures.sh", wrong])
    peer(echo, wrong, "negative")

    {:ok, {ip, port}} = Gaoxy.info(runtime, "tcp").local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 2000)
    :ok = :gen_tcp.send(socket, "quic-independent-sibling")
    assert {:ok, "quic-independent-sibling"} = :gen_tcp.recv(socket, 0, 2000)
    :gen_tcp.close(socket)
    assert %{retained_high_water: high} = Gaoxy.status(runtime, "echo")
    assert high <= 262_144
    :ok = Gaoxy.remove(runtime, "echo", 1000)
    assert "echo" not in Gaoxy.services(runtime)
    IO.puts("PASS QUIC_FACADE_WIRE_BOUNDS_LIFECYCLE")
  end

  defp peer(port, directory, mode, alpn \\ "gaoxy-stream-v1") do
    {output, exit} =
      System.cmd(
        "uv",
        [
          "run",
          "--python",
          "3.12",
          "--with",
          "aioquic==1.2.0",
          "python",
          "peer.py",
          "--port",
          Integer.to_string(port),
          "--ca",
          Path.join(directory, "ca.pem"),
          "--mode",
          mode,
          "--alpn",
          alpn
        ],
        stderr_to_stdout: true
      )

    IO.write(output)
    assert exit == 0, "independent #{mode} peer exit #{exit}"
    assert output =~ "\"result\": \"PASS\""
  end
end
