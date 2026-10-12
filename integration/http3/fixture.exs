defmodule Gaoxy.HTTP3Fixture.Endpoint do
  def init(options), do: {:ok, options}
  def call(_, _), do: raise("G1 fixture actions must run in the minimal connection owner")
end

defmodule Gaoxy.HTTP3Fixture.Pins do
  use GenServer
  @behaviour Gaoxy.HTTP.Resources

  def start_link, do: GenServer.start_link(__MODULE__, [])
  def init(_), do: {:ok, %{}}

  def pin_many([handle], holder, kind, operation, deadline),
    do: Gaoxy.Lifecycle.call(handle.owner, {:pin, holder, kind, operation}, deadline)

  def release(pin), do: GenServer.call(pin.owner, {:release, pin.ref})
  def cancel(owner, operation), do: GenServer.cast(owner, {:cancel, operation})

  def handle_call({:pin, holder, kind, operation}, _, state) do
    ref = make_ref()
    monitor = Process.monitor(holder)
    pin = %{provider: __MODULE__, owner: self(), ref: ref, operation: operation, kind: kind}
    {:reply, {:ok, pin}, Map.put(state, ref, {monitor, operation})}
  end

  def handle_call({:release, ref}, _, state), do: {:reply, :ok, remove(state, ref)}
  def handle_call(:count, _, state), do: {:reply, map_size(state), state}

  def handle_cast({:cancel, operation}, state) do
    refs = for {ref, {_, op}} <- state, op == operation, do: ref
    {:noreply, Enum.reduce(refs, state, &remove(&2, &1))}
  end

  def handle_info({:DOWN, monitor, :process, _, _}, state) do
    refs = for {ref, {mon, _}} <- state, mon == monitor, do: ref
    {:noreply, Enum.reduce(refs, state, &remove(&2, &1))}
  end

  defp remove(state, ref) do
    case Map.pop(state, ref) do
      {nil, _} ->
        state

      {{monitor, _}, next} ->
        Process.demonitor(monitor, [:flush])
        next
    end
  end
end

defmodule Gaoxy.HTTP3Fixture.SharedPlug do
  alias Gaoxy.HTTP.{Exchange, Response, Resources}

  def init(options), do: options

  def call(conn, options) do
    {_, exchange} = conn.adapter
    send(options.observer, {:http3_fixture_connection, options.id, exchange.gate})
    send(options.observer, {:http3_fixture_slot, exchange.transport_state})

    case conn.request_path do
      "/ok" ->
        Plug.Conn.send_resp(conn, 200, "ok")

      "/metadata" ->
        Plug.Conn.send_resp(
          conn,
          200,
          "#{conn.scheme}:#{Plug.Conn.get_http_protocol(conn)}:#{conn.host}:#{conn.port}"
        )

      "/echo" ->
        conn = Plug.Conn.put_resp_header(conn, "trailer", "x-first, x-second, x-checksum")
        conn = Plug.Conn.send_chunked(conn, 200)
        echo(conn)

      "/zero-trailers" ->
        complete = Exchange.body_complete?(exchange)
        {bytes, conn} = if complete, do: {<<>>, conn}, else: read_all(conn, [])
        <<>> = bytes
        {_, exchange} = conn.adapter

        conn =
          conn
          |> Plug.Conn.put_resp_header("x-initial-body-complete", to_string(complete))
          |> Plug.Conn.put_resp_header("trailer", "x-first, x-second")
          |> Plug.Conn.send_chunked(200)

        finish(conn, Exchange.request_trailers(exchange))

      "/fixed" ->
        conn =
          conn |> Plug.Conn.put_resp_header("content-length", "12") |> Plug.Conn.send_chunked(200)

        {:ok, conn} = Plug.Conn.chunk(conn, "fixed-")
        {:ok, conn} = Plug.Conn.chunk(conn, "stream")
        finish(conn, [])

      "/inform" ->
        conn = Plug.Conn.inform(conn, 103, [{"link", "</fixture>; rel=preload"}])
        Plug.Conn.send_resp(conn, 200, "informed")

      "/continue" ->
        {bytes, conn} = read_all(conn, [])
        Plug.Conn.send_resp(conn, 200, bytes)

      "/file" ->
        Plug.Conn.send_file(conn, 206, options.file, 11, 8_193)

      "/large" ->
        Plug.Conn.send_file(conn, 200, options.file)

      "/empty-204" ->
        Plug.Conn.send_resp(conn, 204, "must-not-appear")

      "/empty-205" ->
        Plug.Conn.send_resp(conn, 205, "must-not-appear")

      "/empty-304" ->
        conn
        |> Plug.Conn.put_resp_header("content-length", "17")
        |> Plug.Conn.send_resp(304, "must-not-appear")

      "/early" ->
        Plug.Conn.send_resp(conn, 200, "early")

      "/crash" ->
        Process.exit(self(), :kill)

      "/busy" ->
        {owner, table, _, _} = exchange.transport_state

        handle = %{
          provider: Gaoxy.HTTP3Fixture.Pins,
          owner: options.pins,
          owner_epoch: make_ref()
        }

        {:ok, pins} = Resources.pin_many([handle], self(), :request, exchange.deadline)
        ref = make_ref()

        send(
          options.observer,
          {:http3_fixture_busy, owner, table, self(), ref, exchange.deadline, exchange.gate}
        )

        # Only Admission's original deadline can stop a Plug that does not read DOWN.
        # The runner never sends this release token and never kills this worker.
        receive do
          {:release_plug, ^ref} -> Resources.release(pins)
        end

        conn
    end
  end

  defp echo(conn) do
    case Plug.Conn.read_body(conn, length: 16_384, read_timeout: 4_000) do
      {kind, bytes, conn} when kind in [:ok, :more] ->
        {:ok, conn} = Plug.Conn.chunk(conn, bytes)

        if kind == :more do
          echo(conn)
        else
          {_, exchange} = conn.adapter
          finish(conn, Exchange.request_trailers(exchange))
        end
    end
  end

  defp read_all(conn, pieces) do
    case Plug.Conn.read_body(conn, length: 16_384, read_timeout: 4_000) do
      {:more, bytes, conn} -> read_all(conn, [bytes | pieces])
      {:ok, bytes, conn} -> {IO.iodata_to_binary(Enum.reverse([bytes | pieces])), conn}
    end
  end

  defp finish(conn, trailers) do
    {adapter, exchange} = conn.adapter
    {:ok, exchange} = Response.finish(exchange, trailers)
    %{conn | adapter: {adapter, exchange}, state: :sent}
  end
end

defmodule Gaoxy.HTTP3Fixture do
  alias Gaoxy.HTTP.HTTP3

  def run do
    directory = System.fetch_env!("GAOXY_HTTP3_CERT_DIR")
    profile = System.get_env("GAOXY_HTTP3_PROFILE", "minimal")
    file = Path.join(directory, "body.bin")
    :ok = File.write(file, :binary.copy("0123456789abcdef", 65_536))
    {:ok, pins} = Gaoxy.HTTP3Fixture.Pins.start_link()

    specs =
      for id <- if(profile == "shared", do: [:main, :sibling, :busy], else: [:main, :sibling]) do
        endpoint =
          if profile == "shared" do
            [
              plug:
                {Gaoxy.HTTP3Fixture.SharedPlug,
                 %{observer: self(), id: id, file: file, pins: pins}}
            ]
          else
            [
              endpoint:
                {Gaoxy.HTTP3Fixture.Endpoint, %{profile: :minimal, observer: self(), id: id}}
            ]
          end

        {:ok, spec} =
          HTTP3.service_spec(
            endpoint ++
              [
                id: id,
                ip: {127, 0, 0, 1},
                port: 0,
                tls: %{
                  certfile: Path.join(directory, "cert.pem"),
                  keyfile: Path.join(directory, "key.pem")
                },
                http_limits: %{
                  request_timeout: if(id == :busy, do: 1_500, else: 5_000),
                  write_timeout: 5_000
                }
              ]
          )

        spec
      end

    {:ok, runtime} = Gaoxy.start_link(services: specs)
    {:ok, {_, port}} = Gaoxy.info(runtime, :main).local
    {:ok, {_, sibling_port}} = Gaoxy.info(runtime, :sibling).local

    busy_port =
      if profile == "shared" do
        {:ok, {_, busy_port}} = Gaoxy.info(runtime, :busy).local
        busy_port
      end

    observer = self()
    reference = make_ref()
    generation = Gaoxy.handle(runtime, :main).generation

    :ok =
      :telemetry.attach_many(
        reference,
        [[:gaoxy, :send], [:gaoxy, :http3, :queue]],
        fn event, measurements, metadata, _ ->
          if metadata.generation == generation do
            case event do
              [:gaoxy, :send] ->
                send(observer, {:send_outcome, metadata.outcome})

              [:gaoxy, :http3, :queue] ->
                send(observer, {:http3_fixture_queue, metadata.connection, measurements})
            end
          end
        end,
        nil
      )

    emit("GAOXY_HTTP3_READY", %{
      event: "ready",
      profile: profile,
      port: port,
      sibling_port: sibling_port,
      busy_port: busy_port,
      busy_request_timeout: 1_500,
      application_limits: %{
        max_slots: hd(specs).handler_options.h3_limits.max_streams,
        max_ingress_bytes:
          hd(specs).handler_options.h3_limits.max_streams *
            hd(specs).handler_options.http_limits.max_buffer_bytes,
        max_output_bytes:
          hd(specs).handler_options.h3_limits.max_streams *
            hd(specs).handler_options.h3_limits.max_pending_output,
        admission_max_bytes: hd(specs).limits.max_bytes
      },
      elixir: System.version(),
      otp: to_string(:erlang.system_info(:otp_release)),
      erts: to_string(:erlang.system_info(:version))
    })

    loop(%{
      runtime: runtime,
      port: port,
      sibling_port: sibling_port,
      busy_port: busy_port,
      pins: pins,
      busy: nil,
      telemetry: reference,
      blocked: 0,
      admitted: 0,
      gates: %{},
      tables: MapSet.new(),
      queue_observations: 0,
      queue_high_water: %{slot_count: 0, ingress_bytes: 0, output_bytes: 0, parser_bytes: 0}
    })
  end

  defp collect(state) do
    receive do
      {:send_outcome, {:blocked, _}} ->
        collect(%{state | blocked: state.blocked + 1})

      {:send_outcome, {:admitted, _}} ->
        collect(%{state | admitted: state.admitted + 1})

      {:send_outcome, _} ->
        collect(state)

      {:http3_fixture_connection, id, gate} ->
        collect(%{state | gates: Map.put(state.gates, id, gate)})

      {:http3_fixture_slot, %{table: table}} ->
        collect(%{state | tables: MapSet.put(state.tables, table)})

      {:http3_fixture_slot, {_owner, table, _key, _token}} ->
        collect(%{state | tables: MapSet.put(state.tables, table)})

      {:http3_fixture_busy, owner, table, worker, ref, deadline, gate} ->
        collect(%{
          state
          | busy: %{
              owner: owner,
              table: table,
              worker: worker,
              ref: ref,
              deadline: deadline,
              gate: gate
            }
        })

      {:http3_fixture_queue, _connection, measurements} ->
        high_water =
          Map.new(state.queue_high_water, fn {key, value} ->
            {key, max(value, Map.get(measurements, key, 0))}
          end)

        collect(%{
          state
          | queue_high_water: high_water,
            queue_observations: state.queue_observations + 1
        })
    after
      0 -> state
    end
  end

  defp loop(state) do
    case IO.gets("") do
      :eof ->
        stop(collect(state))

      line ->
        state = collect(state)

        case JSON.decode!(line) do
          %{"command" => "sample"} ->
            emit("GAOXY_HTTP3_CONTROL", %{
              event: "sample",
              blocked: state.blocked,
              admitted: state.admitted,
              application_queue_high_water: state.queue_high_water,
              application_queue_observations: state.queue_observations,
              application_slots:
                Enum.reduce(state.tables, 0, fn table, sum ->
                  case :ets.info(table, :size) do
                    :undefined -> sum
                    size -> sum + size
                  end
                end),
              admission: sample(state.runtime, :main)
            })

            loop(state)

          %{"command" => "kill-busy"} ->
            state = await_busy(state, Gaoxy.Lifecycle.deadline(1_000))
            busy = state.busy
            true = Process.alive?(busy.gate)
            true = GenServer.call(state.pins, :count) == 1
            true = :ets.info(busy.table, :size) == 1
            before = Gaoxy.Admission.status(busy.gate)
            true = before.active >= 2 and before.retained_bytes > 0
            owner_monitor = Process.monitor(busy.owner)
            worker_monitor = Process.monitor(busy.worker)
            Process.exit(busy.owner, :kill)
            cleanup_deadline = busy.deadline + Gaoxy.Lifecycle.cleanup_headroom()

            receive do
              {:DOWN, ^owner_monitor, :process, _, :killed} -> :ok
            after
              1_000 -> raise "termination_unconfirmed: busy callback owner DOWN"
            end

            true = :ets.info(busy.table) == :undefined
            true = Process.alive?(busy.worker)

            receive do
              {:DOWN, ^worker_monitor, :process, _, :killed} -> :ok
            after
              Gaoxy.Lifecycle.remaining(cleanup_deadline) ->
                raise "termination_unconfirmed: busy worker DOWN"
            end

            confirmed = busy_cleanup(state.pins, busy.gate, cleanup_deadline)
            nil = Gaoxy.status(state.runtime, :busy).cleanup_failed

            emit("GAOXY_HTTP3_CONTROL", %{
              event: "busy-cleaned",
              owner_down: true,
              worker_down: true,
              ets_deleted: true,
              admission_alive: Process.alive?(busy.gate),
              pins: GenServer.call(state.pins, :count),
              admission_before: before,
              admission_after: confirmed,
              service_cleanup_failed: nil,
              cleanup_remaining_ms: Gaoxy.Lifecycle.remaining(cleanup_deadline),
              plug_release_sent: false,
              worker_kill_requested: false
            })

            loop(state)

          %{"command" => "remove-main"} ->
            gate = Map.fetch!(state.gates, :main)
            monitor = Process.monitor(gate)
            started = System.monotonic_time(:millisecond)
            :ok = Gaoxy.remove(state.runtime, :main, 2_000)

            receive do
              {:DOWN, ^monitor, :process, ^gate, _} -> :ok
            after
              2_000 -> raise "removed HTTP3 Admission gate DOWN deadline"
            end

            elapsed = System.monotonic_time(:millisecond) - started
            true = elapsed < 2_000
            :ok = rebound(state.port)

            emit("GAOXY_HTTP3_CONTROL", %{
              event: "removed",
              elapsed_ms: elapsed,
              port_rebound: true,
              admission_gate_down: true,
              sibling_admission: sample(state.runtime, :sibling)
            })

            loop(state)

          %{"command" => "stop"} ->
            stop(state)
        end
    end
  end

  defp sample(runtime, id),
    do:
      Map.take(
        Gaoxy.status(runtime, id),
        [:active, :retained_bytes, :retained_high_water, :cleanup_pending, :cleanup_failed]
      )

  defp await_busy(%{busy: busy} = state, _) when not is_nil(busy), do: state

  defp await_busy(state, deadline) do
    if Gaoxy.Lifecycle.remaining(deadline) == 0, do: raise("busy dispatch barrier deadline")

    receive do
      {:http3_fixture_busy, owner, table, worker, ref, original, gate} ->
        %{
          state
          | busy: %{
              owner: owner,
              table: table,
              worker: worker,
              ref: ref,
              deadline: original,
              gate: gate
            }
        }
    after
      Gaoxy.Lifecycle.remaining(deadline) -> raise "busy dispatch barrier deadline"
    end
  end

  defp busy_cleanup(pins, gate, deadline) do
    status = Gaoxy.Admission.status(gate)

    if status.active == 0 and status.retained_bytes == 0 and status.cleanup_pending == 0 and
         GenServer.call(pins, :count) == 0 do
      status
    else
      if Gaoxy.Lifecycle.remaining(deadline) == 0,
        do: raise("termination_unconfirmed: busy lease/bytes/pins")

      receive do
      after
        1 -> busy_cleanup(pins, gate, deadline)
      end
    end
  end

  defp rebound(port) do
    {:ok, socket} = :gen_udp.open(port, [:binary, ip: {127, 0, 0, 1}])
    :gen_udp.close(socket)
  end

  defp stop(state) do
    monitor = Process.monitor(state.runtime)
    gates = for {_, gate} <- state.gates, do: {gate, Process.monitor(gate)}
    started = System.monotonic_time(:millisecond)
    :ok = Gaoxy.stop(state.runtime, 5_000)

    receive do
      {:DOWN, ^monitor, :process, _, _} -> :ok
    after
      5_000 -> raise "HTTP3 fixture runtime DOWN deadline"
    end

    for {gate, reference} <- gates do
      receive do
        {:DOWN, ^reference, :process, ^gate, _} -> :ok
      after
        1_000 -> raise "stopped HTTP3 Admission gate DOWN deadline"
      end
    end

    :ok = rebound(state.port)
    :ok = rebound(state.sibling_port)
    if state.busy_port, do: rebound(state.busy_port)
    :ok = GenServer.stop(state.pins)
    :ok = :telemetry.detach(state.telemetry)

    emit("GAOXY_HTTP3_CONTROL", %{
      event: "stopped",
      runtime_down: true,
      ports_rebound: true,
      admission_gates_down: true,
      elapsed_ms: System.monotonic_time(:millisecond) - started
    })
  end

  defp emit(prefix, value), do: IO.puts(prefix <> " " <> JSON.encode!(value))
end

Gaoxy.HTTP3Fixture.run()
