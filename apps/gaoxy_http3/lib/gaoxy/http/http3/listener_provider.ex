defmodule Gaoxy.HTTP.HTTP3.ListenerProvider do
  @moduledoc "HTTP/3 implementation of the optional common listener provider contract."
  @behaviour Gaoxy.HTTP.ListenerProvider
  def version, do: 1
  def normalize(:http3, options), do: Gaoxy.HTTP.ListenerSet.normalize_listener(:http3, options)
  def capabilities(_), do: %{pause: :unsupported, drain: :local_host_cleanup}

  def materialize(:http3, options, target) do
    tls = options |> Keyword.take([:certfile, :keyfile]) |> Map.new()

    options =
      options
      |> Keyword.drop([:certfile, :keyfile])
      |> Keyword.merge(tls: tls, endpoint: {Gaoxy.HTTP.ListenerSet.Target, target})

    with {:ok, spec} <- Gaoxy.HTTP.HTTP3.service_spec(options),
         :ok <- generation_budget(spec, Gaoxy.HTTP.ListenerSet.Target.snapshot_bytes(target)),
         do: {:ok, spec}
  end

  defp generation_budget(_, 0), do: :ok

  defp generation_budget(spec, snapshot) do
    reserve = Gaoxy.HTTP.HTTP3.Options.reservation(spec.handler_options)
    streams = spec.handler_options.h3_limits.max_streams
    required = reserve.connection + streams * (reserve.request + snapshot) + reserve.writer

    if spec.limits.max_bytes >= required,
      do: :ok,
      else: {:error, :generation_byte_budget}
  end
end
