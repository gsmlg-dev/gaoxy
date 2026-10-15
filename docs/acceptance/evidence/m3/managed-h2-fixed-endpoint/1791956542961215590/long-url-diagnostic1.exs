alias Gaoxy.Proxy.{ManagedH2Envelope, ManagedH2Preparation}

sizes = fn value ->
  %{logical: byte_size(value), backing: :binary.referenced_byte_size(value)}
end

prefix = "https://upstream.test:"
suffix = "443/a%2Fb?"
url = :binary.copy(prefix <> :binary.copy("0", 65_536 - byte_size(prefix) - byte_size(suffix)) <> suffix)
uri = URI.parse(url)
generated_origin = uri.scheme <> "://" <> uri.authority
fields = [{"content-length", "3"}, {"x-trace", "first"}, {"x-trace", "second"}]
source = %{url: url, method: :post, fields: fields, body: nil, trailers: [], timeout: 5000, connect_timeout: 5000}

summarize = fn
  {:error, reason} -> %{status: :error, reason: reason}
  {:ok, prepared, manifest} ->
    %{status: :ok, prepared_external: :erlang.external_size(prepared), manifest_external: :erlang.external_size(manifest),
      url: sizes.(prepared.url), target: prepared.target, target_size: sizes.(prepared.target),
      effective_field_count: manifest.effective_field_count, effective_field_bytes: manifest.effective_field_bytes}
end

origins = Enum.map([{"generated", generated_origin}, {"standard", "https://upstream.test"}], fn {name, origin} ->
  result = ManagedH2Preparation.prepare_policy(%{protocol: :http2, origin: origin, connect_address: {127,0,0,1}, trust: [<<48,3,2,1,1>>]})
  summary = case result do
    {:error, reason} -> %{status: :error, reason: reason}
    {:ok, policy, accounting} ->
      %{status: :ok, origin_size: sizes.(policy.origin), host_size: sizes.(policy.host), port: policy.port,
        policy_external: :erlang.external_size(policy), accounting_external: :erlang.external_size(accounting),
        request: summarize.(ManagedH2Preparation.prepare_request(policy, source))}
  end
  %{name: name, origin_size: sizes.(origin), policy: summary}
end)

config = %Gaoxy.Proxy.HTTP{uri: URI.parse("https://upstream.test"), cacertfile: nil, connect_address: nil,
  transport: %{provider: Gaoxy.Proxy.UpstreamTransports, owner: self(), owner_epoch: make_ref(), resource: make_ref()},
  upstream_protocol: :http2, client: Gaoxy.Proxy.ManagedH2Client,
  limits: %{max_chunk_bytes: 65_536, opening_timeout: 5000, idle_timeout: 60_000, write_timeout: 5000, max_lifetime: 30_000}}

valid_configs = Enum.map(["https://127.0.0.1", "https://[::1]", "https://upstream.test:1", "https://upstream.test:65535", "https://" <> :binary.copy("a",253)], fn origin ->
  parsed = URI.parse(origin)
  compact = Map.new(Map.to_list(parsed), fn {key, value} -> {key, if(is_binary(value), do: :binary.copy(value), else: value)} end)
  %{origin_bytes: byte_size(origin), parsed_host: sizes.(parsed.host), parsed_authority: sizes.(parsed.authority),
    parsed: inspect(ManagedH2Envelope.validate_config(%{config | uri: parsed})),
    compact: inspect(ManagedH2Envelope.validate_config(%{config | uri: compact}))}
end)

request = %{url: url, target: "/a%2Fb?", method: :post, fields: fields, body_mode: {:length,3}, max_upload_bytes: 65_536,
  request_limits: %{max_headers: 256, max_header_bytes: 65_536, max_trailers: 128, max_trailer_bytes: 65_536}}
result = case ManagedH2Envelope.prepare(config, request) do
  {:ok, envelope} -> %{status: :ok, external: :erlang.external_size(envelope), url: sizes.(envelope.url), target: envelope.target}
  {:error, reason} -> %{status: :error, reason: reason}
end
IO.puts(JSON.encode!(%{url: sizes.(url), scheme: sizes.(uri.scheme), host: sizes.(uri.host), authority: sizes.(uri.authority),
  generated_origin: sizes.(generated_origin), origins: origins, valid_configs: valid_configs, envelope: result}))
