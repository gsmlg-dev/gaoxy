defmodule Gaoxy.HTTP3MatrixFixture do
  def emit(data), do: IO.puts("GAOXY_HTTP3_MATRIX_CONTROL " <> JSON.encode!(data))

  def run do
    directory = System.fetch_env!("GAOXY_HTTP3_CERT_DIR")
    origin = System.fetch_env!("GAOXY_HTTP3_H1_ORIGIN")

    specs =
      for id <- [:proxy, :sibling] do
        {:ok, spec} =
          Gaoxy.HTTP.HTTP3.service_spec(
            id: id,
            ip: {127, 0, 0, 1},
            port: 0,
            endpoint: {Gaoxy.Proxy.HTTP, %{upstream: origin}},
            tls: %{
              certfile: Path.join(directory, "cert.pem"),
              keyfile: Path.join(directory, "key.pem")
            },
            limits: %{max_bytes: 134_217_728},
            http_limits: %{request_timeout: 10_000, write_timeout: 5_000}
          )

        spec
      end

    {:ok, runtime} = Gaoxy.start_link(services: specs)

    ports =
      Map.new([:proxy, :sibling], fn id ->
        {:ok, {_, port}} = Gaoxy.info(runtime, id).local
        {id, port}
      end)

    IO.puts(
      "GAOXY_HTTP3_MATRIX_READY " <>
        JSON.encode!(%{
          event: "ready",
          port: ports.proxy,
          sibling_port: ports.sibling,
          upstream: origin,
          elixir: System.version(),
          otp: System.otp_release(),
          erts: to_string(:erlang.system_info(:version))
        })
    )

    loop(runtime, ports)
  end

  defp loop(runtime, ports) do
    case IO.gets("") do
      :eof ->
        stop(runtime, ports)

      line ->
        case JSON.decode!(line) do
          %{"command" => "sample"} ->
            emit(%{
              event: "sample",
              admission:
                Map.new(ports, fn {id, _} ->
                  {id,
                   Map.take(Gaoxy.status(runtime, id), [
                     :active,
                     :retained_bytes,
                     :cleanup_pending,
                     :cleanup_failed,
                     :retained_high_water,
                     :queued_items,
                     :queued_bytes
                   ])}
                end)
            })

            loop(runtime, ports)

          %{"command" => "stop"} ->
            stop(runtime, ports)
        end
    end
  end

  defp stop(runtime, ports) do
    started = Gaoxy.Lifecycle.now()
    monitor = Process.monitor(runtime)
    :ok = Gaoxy.stop(runtime, 5_000)

    receive do
      {:DOWN, ^monitor, :process, ^runtime, _} -> :ok
    after
      1_000 -> raise "matrix runtime termination unconfirmed"
    end

    for {_, port} <- ports do
      {:ok, socket} = :gen_udp.open(port, [:binary, ip: {127, 0, 0, 1}])
      :ok = :gen_udp.close(socket)
    end

    emit(%{
      event: "stopped",
      runtime_down: true,
      ports_rebound: true,
      elapsed_ms: Gaoxy.Lifecycle.now() - started
    })
  end
end

Gaoxy.HTTP3MatrixFixture.run()
