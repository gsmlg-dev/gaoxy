defmodule Gaoxy.H2RFC.Endpoint do
  alias Gaoxy.HTTP.Response

  def init(options), do: {:ok, options}

  def call(exchange, _) do
    if exchange.request.path == "/hold" do
      receive do
        :unused -> {:ok, exchange}
      end
    else
      Response.send_resp(exchange, 200, [], exchange.request.path)
    end
  end
end

defmodule Gaoxy.H2RFC.Fixture do
  def run do
    {:ok, runtime} =
      Gaoxy.HTTP.start_link(
        ip: {127, 0, 0, 1},
        port: 0,
        endpoint: {Gaoxy.H2RFC.Endpoint, []},
        protocols: [:http2],
        h2c: :prior_knowledge,
        limits: %{max_active: 128, max_bytes: 536_870_912},
        http_limits: %{request_timeout: 5_000}
      )

    {:ok, {{127, 0, 0, 1}, port}} = Gaoxy.info(runtime, :http).local

    emit(%{
      event: "ready",
      port: port,
      elixir: System.version(),
      otp: to_string(:erlang.system_info(:otp_release))
    })

    loop(runtime, port)
  end

  defp loop(runtime, port) do
    case IO.gets("") do
      "sample\n" ->
        emit(
          Map.take(Gaoxy.status(runtime, :http), [
            :active,
            :retained_bytes,
            :cleanup_pending,
            :cleanup_failed
          ])
        )

        loop(runtime, port)

      "stop\n" ->
        monitor = Process.monitor(runtime)
        :ok = Gaoxy.stop(runtime, 5_000)

        receive do
          {:DOWN, ^monitor, :process, ^runtime, _} -> :ok
        after
          5_000 -> raise "runtime DOWN deadline"
        end

        {:error, :econnrefused} =
          :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false], 1_000)

        {:ok, socket} =
          :gen_tcp.listen(port, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])

        :ok = :gen_tcp.close(socket)
        emit(%{event: "stopped", runtime_down: true, port_rebound: true})
    end
  end

  defp emit(value), do: IO.puts("GAOXY_H2_RFC " <> JSON.encode!(value))
end

Gaoxy.H2RFC.Fixture.run()
