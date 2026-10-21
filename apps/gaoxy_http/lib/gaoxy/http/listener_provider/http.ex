defmodule Gaoxy.HTTP.ListenerProvider.HTTP do
  @moduledoc false
  @behaviour Gaoxy.HTTP.ListenerProvider
  def version, do: 1
  def normalize(role, options), do: Gaoxy.HTTP.ListenerSet.normalize_listener(role, options)
  def capabilities(_), do: %{pause: :unbind_rebind, drain: :admitted_work}

  def materialize(role, options, target) do
    tls = options |> Keyword.take([:certfile, :keyfile, :versions, :alpn]) |> Map.new()
    options = Keyword.drop(options, [:certfile, :keyfile, :versions, :alpn])

    options =
      Keyword.merge(options,
        transport: if(role == :http, do: :tcp, else: :tls),
        endpoint: {Gaoxy.HTTP.ListenerSet.Target, target}
      )

    options = if role == :https, do: Keyword.put(options, :tls, tls), else: options

    with {:ok, spec} <- Gaoxy.HTTP.service_spec(options),
         :ok <- generation_budget(spec, Gaoxy.HTTP.ListenerSet.Target.snapshot_bytes(target)),
         do: {:ok, spec}
  end

  defp generation_budget(_, 0), do: :ok

  defp generation_budget(spec, snapshot) do
    options = spec.handler_options
    http = options.http_limits

    base =
      if :http2 in options.protocols do
        reserve = Gaoxy.HTTP.HTTP2.Limits.reservation(http, options.h2_limits)
        reserve.connection + reserve.decode + reserve.stream + reserve.writer
      else
        2 * http.max_header_bytes + http.max_buffer_bytes + 4 * http.max_read_chunk
      end

    if spec.limits.max_bytes >= base + snapshot,
      do: :ok,
      else: {:error, :generation_byte_budget}
  end
end
