defmodule Gaoxy.Test.Server do
  @moduledoc false
  use GenServer

  @profiles [:http1, :https, :h2c, :http2, :http3]
  @service :gaoxy_test

  def start_link(coordinator, options) do
    profile = Keyword.get(options, :profile, :http1)

    with :ok <- preflight(profile),
         {:ok, tls} <- credentials(profile) do
      GenServer.start_link(__MODULE__, {coordinator, options, profile, tls})
    end
  end

  def info(server), do: GenServer.call(server, :info)

  def close(server, timeout) when is_integer(timeout) and timeout >= 0 do
    GenServer.call(server, {:close, timeout}, timeout + 100)
  catch
    :exit, {:noproc, _} -> {:error, :server_unavailable}
    :exit, {:normal, _} -> {:error, :server_unavailable}
    :exit, {:timeout, _} -> {:error, {:deadline_exceeded, :cleanup_pending}}
  end

  @impl true
  def init({coordinator, options, profile, tls}) do
    Process.flag(:trap_exit, true)
    monitor = Process.monitor(coordinator)
    timeout = Keyword.get(options, :timeout, 5_000)
    plug = {Gaoxy.Test.DispatchPlug, {coordinator, Keyword.fetch!(options, :fixture_id)}}
    common = [id: @service, ip: {127, 0, 0, 1}, port: 0, plug: plug]

    with {:ok, spec} <- specification(profile, common, tls),
         {:ok, runtime} <- Gaoxy.start_link(services: [spec]) do
      state = %{runtime: runtime, monitor: monitor, timeout: timeout, info: nil}

      case Gaoxy.info(runtime, @service) do
        %{local: {:ok, {ip, port}}} when port > 0 ->
          if Process.alive?(coordinator) do
            scheme = if tls, do: "https", else: "http"
            transport = if profile == :http3, do: :udp, else: :tcp

            info = %{
              profile: profile,
              url: "#{scheme}://#{:inet.ntoa(ip)}:#{port}",
              endpoints: [%{transport: transport, ip: ip, port: port}],
              ready: true,
              capabilities: %{
                streaming: true,
                sse: true,
                websocket: profile in [:http1, :https],
                protocol: profile
              },
              tls: if(tls, do: Map.take(tls, [:cacertfile]), else: nil)
            }

            {:ok, %{state | info: info}}
          else
            _ = Gaoxy.stop(runtime, timeout)
            {:stop, :coordinator_unavailable}
          end

        error ->
          _ = Gaoxy.stop(runtime, timeout)
          {:stop, {:endpoint_unavailable, error}}
      end
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call(:info, _, state), do: {:reply, state.info, state}

  def handle_call({:close, timeout}, _, state) do
    result = stop_runtime(state.runtime, timeout)
    {:stop, :normal, result, %{state | runtime: nil}}
  end

  @impl true
  def handle_info({:DOWN, monitor, :process, _, _}, %{monitor: monitor} = state),
    do: {:stop, :normal, state}

  def handle_info({:EXIT, runtime, reason}, %{runtime: runtime} = state),
    do: {:stop, {:runtime_exit, reason}, %{state | runtime: nil}}

  def handle_info({:EXIT, _, _}, state), do: {:stop, :normal, state}

  @impl true
  def terminate(_, %{runtime: runtime, timeout: timeout}) do
    if runtime, do: stop_runtime(runtime, timeout)
    :ok
  end

  defp stop_runtime(runtime, timeout) do
    if Process.alive?(runtime), do: Gaoxy.stop(runtime, timeout), else: :ok
  end

  defp preflight(:http3) do
    if Code.ensure_loaded?(Gaoxy.HTTP.HTTP3) and Code.ensure_loaded?(Quic) do
      case Application.ensure_all_started(:gaoxy_http3) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, {:http3_unavailable, reason}}
      end
    else
      {:error, {:http3_unavailable, :optional_dependency_required}}
    end
  end

  defp preflight(profile) when profile in @profiles, do: :ok
  defp preflight(profile), do: {:error, {:unsupported_profile, profile}}

  defp credentials(profile) when profile in [:https, :http2, :http3] do
    directory = Application.app_dir(:gaoxy_test, "priv/tls")

    tls = %{
      cacertfile: Path.join(directory, "ca.pem"),
      certfile: Path.join(directory, "cert.pem"),
      keyfile: Path.join(directory, "key.pem")
    }

    case Enum.find(tls, fn {_, path} -> not File.regular?(path) end) do
      nil -> {:ok, tls}
      {key, _} -> {:error, {:missing_tls_asset, key}}
    end
  end

  defp credentials(_), do: {:ok, nil}

  defp specification(:http3, common, tls),
    do:
      apply(Gaoxy.HTTP.HTTP3, :service_spec, [
        common ++ [tls: Map.take(tls, [:certfile, :keyfile])]
      ])

  defp specification(profile, common, tls) do
    options =
      case profile do
        :http1 -> [protocols: [:http1]]
        :https -> [protocols: [:http1], transport: :tls, tls: Map.drop(tls, [:cacertfile])]
        :h2c -> [protocols: [:http2], h2c: :prior_knowledge]
        :http2 -> [protocols: [:http2], transport: :tls, tls: Map.drop(tls, [:cacertfile])]
      end

    Gaoxy.HTTP.service_spec(common ++ options)
  end
end
