defmodule Gaoxy.Proxy.ManagedH2GroupBoundary do
  @moduledoc false

  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Proxy.ManagedH2Envelope

  @signed_min -9_223_372_036_854_775_808
  @signed_max 9_223_372_036_854_775_807
  @day 86_400_000

  def prepare(
        %{id: id, config: config, max_inflight: max} = selected,
        neutral,
        checked,
        %{
          group: group,
          instance: instance,
          limits: limits,
          deadline: deadline,
          opening_deadline: opening,
          now: now
        } = context
      )
      when map_size(selected) == 3 and map_size(context) == 6 and is_integer(max) and
             max in 1..1_024 and is_pid(instance) and is_integer(deadline) and
             deadline >= @signed_min and deadline <= @signed_max - 1_000 and
             is_integer(opening) and opening >= @signed_min and opening <= @signed_max and
             is_integer(now) and now >= @signed_min and now <= @signed_max do
    with true <- compact_identifier?(id),
         :ok <- ManagedH2Envelope.validate_config(config),
         :ok <- ManagedH2Envelope.validate_group_source(neutral),
         true <- valid_limits?(limits),
         true <- valid_group?(group),
         true <- config.transport in group.transports,
         true <- now < opening and opening <= deadline,
         timeout = deadline - now,
         opening_timeout = opening - now,
         true <- timeout in 1..@day and opening_timeout in 1..@day,
         :ok <- ManagedH2Envelope.validate_checked_client(checked, config.upstream_protocol),
         true <- matching_authority?(config, checked.policy),
         true <- group.max_url_bytes + byte_size(neutral.target) <= 65_536,
         root_bytes = byte_size(config.uri.scheme) + 3 + byte_size(config.uri.authority),
         true <- root_bytes <= group.max_url_bytes and root_bytes <= 8_192,
         true <- root_bytes + byte_size(neutral.target) <= 65_536,
         effective = effective_limits(limits, config.limits),
         adjusted = %{
           neutral
           | max_upload_bytes: min(neutral.max_upload_bytes, effective.max_chunk_bytes)
         },
         {:ok, request} <- ManagedH2Envelope.prepare_group_request(config, adjusted) do
      {:ok,
       %{
         request: request,
         managed_transport: checked,
         timeout: timeout,
         opening_timeout: opening_timeout,
         write_timeout: effective.write_timeout,
         deadline: deadline,
         opening_deadline: opening
       }, effective}
    else
      _ -> {:error, :invalid_group_opening}
    end
  end

  def prepare(_, _, _, _), do: {:error, :invalid_group_opening}

  def activation, do: {:error, :accounting_not_ready}

  defp compact_identifier?(value) when is_binary(value) and byte_size(value) in 1..128,
    do: :binary.referenced_byte_size(value) == byte_size(value)

  defp compact_identifier?(_), do: false

  defp valid_group?(
         %{
           provider: Gaoxy.Proxy.UpstreamGroups,
           owner: owner,
           owner_epoch: epoch,
           group: id,
           generation: generation,
           max_url_bytes: bytes,
           transports: transports,
           execution_profile: :managed_h2
         } = group
       )
       when map_size(group) == 8 and is_pid(owner) and is_reference(epoch) and
              is_reference(generation) and is_integer(bytes) and bytes in 1..8_192 do
    compact_identifier?(id) and valid_transports?(transports, [], 0) and
      match?({:ok, _}, Resources.validate([group | transports]))
  end

  defp valid_group?(_), do: false

  defp valid_transports?([], _, count), do: count > 0

  defp valid_transports?(
         [
           %{
             provider: Gaoxy.Proxy.UpstreamTransports,
             owner: owner,
             owner_epoch: epoch,
             resource: resource
           } = transport
           | rest
         ],
         seen,
         count
       )
       when count < 32 and map_size(transport) == 4 and is_pid(owner) and
              is_reference(epoch) and is_reference(resource) do
    transport not in seen and valid_transports?(rest, [transport | seen], count + 1)
  end

  defp valid_transports?(_, _, _), do: false

  defp valid_limits?(
         %{
           max_chunk_bytes: chunk,
           opening_timeout: opening,
           idle_timeout: idle,
           write_timeout: write,
           max_lifetime: lifetime
         } = limits
       )
       when map_size(limits) == 5 and is_integer(chunk) and chunk in 1..65_536 and
              is_integer(opening) and opening in 1..@day and is_integer(idle) and
              idle in 1..@day and is_integer(write) and write in 1..@day and
              is_integer(lifetime) and lifetime in 1..@day,
       do: true

  defp valid_limits?(_), do: false

  defp effective_limits(endpoint, member),
    do: %{
      max_chunk_bytes: min(endpoint.max_chunk_bytes, member.max_chunk_bytes),
      opening_timeout: min(endpoint.opening_timeout, member.opening_timeout),
      idle_timeout: min(endpoint.idle_timeout, member.idle_timeout),
      write_timeout: min(endpoint.write_timeout, member.write_timeout),
      max_lifetime: min(endpoint.max_lifetime, member.max_lifetime)
    }

  # Shape and membership establish coherence only. Runtime checkout supplies
  # owner/instance authority; neither a profile nor this comparison grants it.
  defp matching_authority?(config, policy) do
    scheme = if config.uri.scheme == "https", do: :https, else: :http

    {config.upstream_protocol, scheme, String.downcase(config.uri.host), config.uri.port} ==
      {policy.protocol, policy.scheme, policy.host, policy.port}
  end
end
