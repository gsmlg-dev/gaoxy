defmodule Gaoxy.HTTP3Fixture.Endpoint do
  def init(options), do: {:ok, options}
  def call(_, _), do: raise("G1 fixture actions must run in the minimal connection owner")
end

defmodule Gaoxy.HTTP3Fixture do
  alias Gaoxy.HTTP.HTTP3

  def run do
    directory = System.fetch_env!("GAOXY_HTTP3_CERT_DIR")

    specs =
      for id <- [:main, :sibling] do
        {:ok, spec} =
          HTTP3.service_spec(
            id: id,
            ip: {127, 0, 0, 1},
            port: 0,
            endpoint:
              {Gaoxy.HTTP3Fixture.Endpoint, %{profile: :minimal, observer: self(), id: id}},
            tls: %{
              certfile: Path.join(directory, "cert.pem"),
              keyfile: Path.join(directory, "key.pem")
            },
            http_limits: %{request_timeout: 5_000, write_timeout: 5_000}
          )

        spec
      end

    {:ok, runtime} = Gaoxy.start_link(services: specs)
    {:ok, {_, port}} = Gaoxy.info(runtime, :main).local
    {:ok, {_, sibling_port}} = Gaoxy.info(runtime, :sibling).local
    observer = self()
    reference = make_ref()
    generation = Gaoxy.handle(runtime, :main).generation

    :ok =
      :telemetry.attach(
        reference,
        [:gaoxy, :send],
        fn _, _, metadata, _ ->
          if metadata.generation == generation,
            do: send(observer, {:send_outcome, metadata.outcome})
        end,
        nil
      )

    emit("GAOXY_HTTP3_READY", %{
      event: "ready",
      port: port,
      sibling_port: sibling_port,
      elixir: System.version(),
      otp: to_string(:erlang.system_info(:otp_release)),
      erts: to_string(:erlang.system_info(:version))
    })

    loop(%{
      runtime: runtime,
      port: port,
      sibling_port: sibling_port,
      telemetry: reference,
      blocked: 0,
      admitted: 0,
      gates: %{}
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
              admission: sample(state.runtime, :main)
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
