defmodule Gaoxy.Proxy.ManagedH2Envelope do
  @moduledoc false

  alias Gaoxy.Proxy.ManagedH2Preparation

  @binary_cap 65_536
  @methods [:get, :head, :post, :put, :patch, :delete, :options]
  @forbidden_trailers ~w(content-length transfer-encoding host connection trailer te upgrade
                        keep-alive proxy-connection authorization proxy-authorization
                        proxy-authenticate www-authenticate content-encoding content-type
                        content-range expect cache-control cookie set-cookie)

  def prepare(config, source) when is_map(source) and map_size(source) == 7 do
    with :ok <- validate_config(config),
         %{
           url: _,
           target: _,
           method: _,
           fields: _,
           body_mode: _,
           request_limits: _,
           max_upload_bytes: _
         } <- source,
         request = Map.put(source, :protocol, config.upstream_protocol),
         {:ok, uri} <- request_shape(request),
         true <-
           origin(uri) == origin(config.uri) and
             request.max_upload_bytes <= config.limits.max_chunk_bytes do
      {:ok,
       %{
         request
         | url: :binary.copy(request.url),
           target: :binary.copy(request.target),
           fields: copy_pairs(request.fields)
       }}
    else
      _ -> {:error, :invalid_request}
    end
  end

  def prepare(_, _), do: {:error, :invalid_request}

  def prepare_group_source(source) do
    with :ok <- group_source_shape(source) do
      {:ok, %{source | target: :binary.copy(source.target), fields: copy_pairs(source.fields)}}
    end
  end

  def validate_group_source(source) do
    with :ok <- group_source_shape(source),
         true <- compact?(source.target) and compact_pairs?(source.fields) do
      :ok
    else
      _ -> {:error, :invalid_group_source}
    end
  end

  def prepare_group_request(config, source) do
    with :ok <- validate_config(config),
         :ok <- validate_group_source(source),
         root = config.uri.scheme <> "://" <> config.uri.authority,
         true <- byte_size(root) <= 8_192,
         true <- byte_size(root) + byte_size(source.target) <= @binary_cap do
      prepare(config, Map.put(source, :url, :binary.copy(root <> source.target)))
    else
      _ -> {:error, :invalid_request}
    end
  end

  def validate_request(request) do
    with {:ok, _} <- request_shape(request),
         true <- compact?(request.url) and compact?(request.target),
         true <- compact_pairs?(request.fields) do
      :ok
    else
      _ -> {:error, :invalid_request}
    end
  end

  def validate_config(
        %Gaoxy.Proxy.HTTP{
          uri: uri,
          cacertfile: nil,
          connect_address: nil,
          transport: transport,
          limits: limits,
          upstream_protocol: protocol,
          client: Gaoxy.Proxy.ManagedH2Client
        } = config
      )
      when map_size(config) == 8 and protocol in [:http2, :h2c] do
    with :ok <- transport_shape(transport),
         :ok <- limits_shape(limits),
         :ok <- uri_shape(uri, true),
         true <- uri.scheme == protocol_scheme(protocol),
         true <- uri.path == nil and uri.query == nil,
         true <- :erlang.external_size(uri) <= 132_096,
         true <- :erlang.external_size(config) <= 147_456 do
      :ok
    else
      _ -> {:error, :invalid_config}
    end
  end

  def validate_config(_), do: {:error, :invalid_config}

  def validate_checked_client(
        %{policy: policy, transport_scope: scope, fetch_options: options} = client,
        protocol
      )
      when map_size(client) == 3 and protocol in [:http2, :h2c] do
    with %{__struct__: ManagedH2Preparation.Policy, protocol: ^protocol, origin: url} <- policy,
         true <- opaque_scope?(scope),
         true <- options == fetch_options(protocol),
         {:ok, _, _} <-
           ManagedH2Preparation.prepare_request(policy, preparation_source(url, :get, [])),
         projection = %{client | transport_scope: {:opaque, HTTP.ManagedTransport}},
         true <- :erlang.external_size(projection) <= 1_183_744 do
      :ok
    else
      _ -> {:error, :invalid_checked_client}
    end
  end

  def validate_checked_client(_, _), do: {:error, :invalid_checked_client}

  def validate_trailer_policy(
        %{allowed: allowed, dropped: dropped, max_count: count, max_bytes: bytes} = policy
      )
      when map_size(policy) == 4 and is_integer(count) and count in 1..128 and
             is_integer(bytes) and bytes in 1..@binary_cap do
    with {:ok, logical, backing} <- names(allowed, 128, true, 0, 0, 0),
         {:ok, dropped_logical, dropped_backing} <- names(dropped, 265, false, 0, 0, 0),
         true <- logical + dropped_logical <= 65_642 and backing + dropped_backing <= 65_642,
         true <- :erlang.external_size(policy) <= 67_689 do
      :ok
    else
      _ -> {:error, :invalid_trailer_policy}
    end
  end

  def validate_trailer_policy(_), do: {:error, :invalid_trailer_policy}

  def validate_response(
        %HTTP.Response{
          status: status,
          status_text: text,
          ok: ok,
          headers: headers,
          body: body,
          body_used: used,
          url: url,
          redirected: redirected,
          type: type,
          stream: stream,
          http_version: :http2,
          informational: informational,
          trailers: trailers
        } = response,
        submitted_url
      )
      when map_size(response) == 14 and is_integer(status) and status in 200..599 and
             is_boolean(ok) and is_boolean(used) and is_boolean(redirected) and
             type in [:basic, :cors, :error, :opaque] do
    with :ok <- bounded_binary(text, 64, true),
         true <- stream == nil or is_pid(stream),
         true <- body in [nil, ""] or (is_pid(body) and body == stream),
         :ok <- bounded_binary(submitted_url, @binary_cap, false),
         true <- compact?(submitted_url),
         {:ok, submitted_uri} <- parse_url(submitted_url),
         :ok <- response_uri(url, submitted_uri),
         {:ok, fields, _, _, _} <- headers_shape(headers, 256),
         %HTTP.Headers{headers: []} <- trailers,
         true <- map_size(trailers) == 2,
         :ok <- informational_shape(informational, 0, 0, 0, 0),
         metadata = %{response | headers: %HTTP.Headers{}, body: nil},
         true <- :erlang.external_size(metadata) <= 213_965 do
      {:ok, %{status: status, fields: copy_pairs(fields), stream: stream}}
    else
      _ -> {:error, :invalid_response}
    end
  end

  def validate_response(_, _), do: {:error, :invalid_response}

  defp group_source_shape(
         %{
           target: target,
           method: method,
           fields: fields,
           body_mode: mode,
           request_limits: limits,
           max_upload_bytes: upload
         } = source
       )
       when map_size(source) == 6 and method in @methods and
              is_integer(upload) and upload in 1..@binary_cap do
    with :ok <- body_mode(mode),
         :ok <- request_limits(limits),
         :ok <- bounded_binary(target, @binary_cap, false),
         <<"/", _::binary>> <- target,
         true <- url_text?(target),
         {:ok, _, logical, backing} <- pairs(fields, 256, 0, 0, 0),
         true <- byte_size(target) + logical <= 131_072,
         true <- :binary.referenced_byte_size(target) + backing <= 131_072,
         true <- :erlang.external_size(source) <= 205_337 do
      :ok
    else
      _ -> {:error, :invalid_group_source}
    end
  end

  defp group_source_shape(_), do: {:error, :invalid_group_source}

  defp request_shape(
         %{
           protocol: protocol,
           url: url,
           target: target,
           method: method,
           fields: fields,
           body_mode: mode,
           request_limits: limits,
           max_upload_bytes: upload
         } = request
       )
       when map_size(request) == 8 and protocol in [:http2, :h2c] and method in @methods and
              is_integer(upload) and upload in 1..@binary_cap do
    with :ok <- body_mode(mode),
         :ok <- request_limits(limits),
         :ok <- bounded_binary(url, @binary_cap, false),
         :ok <- bounded_binary(target, @binary_cap, false),
         {:ok, _, field_logical, field_backing} <- pairs(fields, 256, 0, 0, 0),
         true <- byte_size(url) + byte_size(target) + field_logical <= 196_608,
         true <-
           :binary.referenced_byte_size(url) + :binary.referenced_byte_size(target) +
             field_backing <= 196_608,
         {:ok, uri} <- parse_url(url),
         true <- uri.scheme == protocol_scheme(protocol) and target == submitted_target(uri),
         {:ok, policy, _} <-
           ManagedH2Preparation.prepare_policy(%{
             protocol: protocol,
             origin: validation_origin(uri),
             connect_address: {127, 0, 0, 1},
             trust: if(protocol == :http2, do: [<<48, 3, 2, 1, 1>>], else: nil)
           }),
         {:ok, prepared, manifest} <-
           ManagedH2Preparation.prepare_request(policy, preparation_source(url, method, fields)),
         true <-
           manifest.effective_field_count <= limits.max_headers and
             manifest.effective_field_bytes <= limits.max_header_bytes,
         :ok <- preparation_return(prepared, manifest),
         true <- :erlang.external_size(request) <= 205_337 do
      {:ok, uri}
    else
      _ -> {:error, :invalid_request}
    end
  end

  defp request_shape(_), do: {:error, :invalid_request}

  # The accepted preparer produces these closed constructor/accounting schemas.
  # Its full return occupies one request slot; the projection is not charged again.
  defp preparation_return(request, preparation) do
    accounting = %{
      owned_serialized_payload_bytes: :erlang.external_size(request),
      preparation: preparation
    }

    if accounting.owned_serialized_payload_bytes <= 201_753 and
         :erlang.external_size(preparation) <= 3_072 and
         :erlang.external_size(accounting) <= 3_456 and
         :erlang.external_size({:ok, request, accounting}) <= 205_337,
       do: :ok,
       else: {:error, :invalid_request}
  end

  defp preparation_source(url, method, fields),
    do: %{
      url: url,
      method: method,
      fields: fields,
      body: nil,
      trailers: [],
      timeout: 1,
      connect_timeout: 1
    }

  defp body_mode(mode) when mode in [:none, :chunked], do: :ok

  defp body_mode({:length, length})
       when is_integer(length) and length in 0..18_446_744_073_709_551_615,
       do: :ok

  defp body_mode(_), do: {:error, :invalid_request}

  defp request_limits(
         %{
           max_headers: heads,
           max_header_bytes: bytes,
           max_trailers: trailers,
           max_trailer_bytes: trailer_bytes
         } = limits
       )
       when map_size(limits) == 4 and is_integer(heads) and heads in 1..256 and
              is_integer(bytes) and bytes in 1..@binary_cap and is_integer(trailers) and
              trailers in 1..128 and is_integer(trailer_bytes) and trailer_bytes in 1..@binary_cap,
       do: :ok

  defp request_limits(_), do: {:error, :invalid_request}

  defp limits_shape(
         %{
           max_chunk_bytes: chunk,
           opening_timeout: opening,
           idle_timeout: idle,
           write_timeout: write,
           max_lifetime: lifetime
         } = limits
       )
       when map_size(limits) == 5 and is_integer(chunk) and chunk in 1..@binary_cap and
              is_integer(opening) and opening in 1..86_400_000 and is_integer(idle) and
              idle in 1..86_400_000 and
              is_integer(write) and write in 1..86_400_000 and is_integer(lifetime) and
              lifetime in 1..86_400_000,
       do: :ok

  defp limits_shape(_), do: {:error, :invalid_config}

  defp transport_shape(
         %{
           provider: Gaoxy.Proxy.UpstreamTransports,
           owner: owner,
           owner_epoch: epoch,
           resource: resource
         } = handle
       )
       when map_size(handle) == 4 and is_pid(owner) and is_reference(epoch) and
              is_reference(resource),
       do: :ok

  defp transport_shape(_), do: {:error, :invalid_config}

  defp opaque_scope?(%HTTP.ManagedTransport{} = scope),
    do:
      map_size(scope) == map_size(%HTTP.ManagedTransport{}) and
        Enum.sort(Map.keys(scope)) == Enum.sort(Map.keys(%HTTP.ManagedTransport{}))

  defp opaque_scope?(_), do: false

  defp fetch_options(protocol),
    do: [
      http_version: protocol,
      tls_backend: :ssl,
      http2_profile: :native_v1,
      http2_reuse: true,
      redirect: :manual,
      request_mode: :proxy,
      decode_body: false,
      stream_response: true,
      telemetry: false
    ]

  defp headers_shape(%HTTP.Headers{headers: fields} = wrapper, maximum)
       when map_size(wrapper) == 2 do
    with {:ok, count, logical, backing} <- pairs(fields, maximum, 0, 0, 0),
         do: {:ok, fields, count, logical, backing}
  end

  defp headers_shape(_, _), do: {:error, :invalid_response}

  defp pairs([], _, count, logical, backing), do: {:ok, count, logical, backing}

  defp pairs([{name, value} | rest], maximum, count, logical, backing)
       when count < maximum and is_binary(name) and is_binary(value) do
    logical = logical + byte_size(name) + byte_size(value)
    backing = backing + :binary.referenced_byte_size(name) + :binary.referenced_byte_size(value)

    if logical <= @binary_cap and backing <= @binary_cap and token?(name) and field_value?(value),
      do: pairs(rest, maximum, count + 1, logical, backing),
      else: {:error, :invalid_fields}
  end

  defp pairs(_, _, _, _, _), do: {:error, :invalid_fields}

  defp informational_shape([], _, _, _, _), do: :ok

  defp informational_shape([{status, headers} | rest], count, fields, bytes, backing)
       when count < 128 and is_integer(status) and status in 100..199 do
    with {:ok, _, n, logical, retained} <- headers_shape(headers, 256),
         true <-
           fields + n <= 2048 and bytes + logical + 32 * n <= @binary_cap and
             backing + retained <= @binary_cap do
      informational_shape(
        rest,
        count + 1,
        fields + n,
        bytes + logical + 32 * n,
        backing + retained
      )
    else
      _ -> {:error, :invalid_response}
    end
  end

  defp informational_shape(_, _, _, _, _), do: {:error, :invalid_response}

  defp names([], _, _, _, logical, backing), do: {:ok, logical, backing}

  defp names([name | rest], maximum, allowed?, count, logical, backing)
       when count < maximum and is_binary(name) do
    logical = logical + byte_size(name)
    backing = backing + :binary.referenced_byte_size(name)

    if logical <= 65_642 and backing <= 65_642 and compact?(name) and lowercase_token?(name) and
         (not allowed? or name not in @forbidden_trailers),
       do: names(rest, maximum, allowed?, count + 1, logical, backing),
       else: {:error, :invalid_trailer_policy}
  end

  defp names(_, _, _, _, _, _), do: {:error, :invalid_trailer_policy}

  defp response_uri(nil, _), do: :ok

  defp response_uri(
         %URI{
           scheme: scheme,
           userinfo: nil,
           host: host,
           port: _port,
           path: path,
           query: query,
           fragment: nil,
           authority: nil
         } = uri,
         submitted
       )
       when map_size(uri) == 9 do
    # Public managed Fetch removes authority and supplies "/" for an empty
    # root. Accept only that exact submitted-derived representation, after
    # checking every retained binary before equality or serialization.
    with {:ok, _, _} <- uri_binaries([scheme, host, path, query], false, 0, 0),
         expected = %{
           submitted
           | authority: nil,
             path: if(submitted.path in [nil, ""], do: "/", else: submitted.path)
         },
         true <- uri == expected,
         true <- :erlang.external_size(uri) <= 132_096 do
      :ok
    else
      _ -> {:error, :invalid_url}
    end
  end

  defp response_uri(uri, submitted) do
    with :ok <- uri_shape(uri, false),
         true <- uri == submitted,
         true <- :erlang.external_size(uri) <= 132_096,
         do: :ok
  end

  defp uri_shape(
         %URI{
           scheme: scheme,
           userinfo: nil,
           host: host,
           port: port,
           path: path,
           query: query,
           fragment: nil,
           authority: authority
         } = uri,
         compact_required
       )
       when map_size(uri) == 9 and scheme in ["http", "https"] and is_binary(host) and
              byte_size(host) in 1..253 and is_integer(port) and port in 1..65_535 do
    with {:ok, _, _} <-
           uri_binaries([scheme, host, path, query, authority], compact_required, 0, 0),
         true <- authority_valid?(authority, host),
         text =
           scheme <>
             "://" <> authority <> (path || "") <> if(query == nil, do: "", else: "?" <> query),
         true <- byte_size(text) <= @binary_cap and url_text?(text),
         {:ok, reparsed} <- parse_url(text),
         true <- uri == reparsed do
      :ok
    else
      _ -> {:error, :invalid_url}
    end
  rescue
    ArgumentError -> {:error, :invalid_url}
  end

  defp uri_shape(_, _), do: {:error, :invalid_url}

  defp uri_binaries([], _, logical, backing), do: {:ok, logical, backing}

  defp uri_binaries([nil | rest], compact_required, logical, backing),
    do: uri_binaries(rest, compact_required, logical, backing)

  defp uri_binaries([value | rest], compact_required, logical, backing) when is_binary(value) do
    retained = :binary.referenced_byte_size(value)

    if byte_size(value) <= @binary_cap and retained <= @binary_cap and
         logical + byte_size(value) <= 132_096 and backing + retained <= 132_096 and
         (not compact_required or compact?(value)),
       do: uri_binaries(rest, compact_required, logical + byte_size(value), backing + retained),
       else: {:error, :invalid_url}
  end

  defp uri_binaries(_, _, _, _), do: {:error, :invalid_url}

  defp parse_url(text) do
    with true <- url_text?(text),
         %URI{scheme: scheme, userinfo: nil, host: host, port: port, fragment: nil} = uri <-
           URI.parse(text),
         true <-
           scheme in ["http", "https"] and is_binary(host) and byte_size(host) in 1..253 and
             is_integer(port) and port in 1..65_535,
         true <- authority_valid?(uri.authority, host),
         true <- uri.path in [nil, ""] or String.starts_with?(uri.path, "/") do
      {:ok, uri}
    else
      _ -> {:error, :invalid_url}
    end
  rescue
    ArgumentError -> {:error, :invalid_url}
  end

  defp authority_valid?(authority, host) when is_binary(authority) do
    prefix = if String.contains?(host, ":"), do: "[" <> host <> "]", else: host
    size = byte_size(prefix)

    case authority do
      ^prefix -> true
      <<^prefix::binary-size(^size), ?:, port::binary>> -> port != "" and digits?(port)
      _ -> false
    end
  end

  defp authority_valid?(_, _), do: false
  defp digits?(<<>>), do: true
  defp digits?(<<char, rest::binary>>) when char in ?0..?9, do: digits?(rest)
  defp digits?(_), do: false

  defp url_text?(<<>>), do: true
  defp url_text?(<<?%, a, b, rest::binary>>), do: hex?(a) and hex?(b) and url_text?(rest)
  defp url_text?(<<?%, _::binary>>), do: false

  defp url_text?(<<char, rest::binary>>) when char in 33..126 and char not in [?#, ?\\],
    do: url_text?(rest)

  defp url_text?(_), do: false
  defp hex?(char), do: char in ?0..?9 or char in ?a..?f or char in ?A..?F

  defp token?(<<>>), do: false
  defp token?(value), do: token_bytes?(value)
  defp token_bytes?(<<>>), do: true

  defp token_bytes?(<<char, rest::binary>>),
    do:
      (char in ?0..?9 or char in ?A..?Z or char in ?a..?z or
         char in ~c"!#$%&'*+-.^_`|~") and token_bytes?(rest)

  defp lowercase_token?(value), do: token?(value) and not uppercase?(value)
  defp uppercase?(<<>>), do: false
  defp uppercase?(<<char, _::binary>>) when char in ?A..?Z, do: true
  defp uppercase?(<<_, rest::binary>>), do: uppercase?(rest)
  defp field_value?(<<>>), do: true

  defp field_value?(<<char, rest::binary>>) when char == 9 or (char >= 32 and char != 127),
    do: field_value?(rest)

  defp field_value?(_), do: false

  defp bounded_binary(value, cap, empty?) when is_binary(value) do
    if byte_size(value) <= cap and (empty? or byte_size(value) > 0) and
         :binary.referenced_byte_size(value) <= cap,
       do: :ok,
       else: {:error, :invalid_binary}
  end

  defp bounded_binary(_, _, _), do: {:error, :invalid_binary}
  defp compact?(value), do: :binary.referenced_byte_size(value) == byte_size(value)
  defp compact_pairs?([]), do: true

  defp compact_pairs?([{name, value} | rest]),
    do: compact?(name) and compact?(value) and compact_pairs?(rest)

  defp copy_pairs(fields),
    do: Enum.map(fields, fn {name, value} -> {:binary.copy(name), :binary.copy(value)} end)

  defp origin(uri), do: {uri.scheme, String.downcase(uri.host), uri.port}

  # Raw authority may contain64KiB of leading port zeros. Reusing it here
  # creates an appendable origin with backing beyond the source cap. This
  # synthetic policy needs only the effective authority; the submitted URL
  # and target remain untouched in the envelope and preparation source.
  defp validation_origin(uri) do
    host = if String.contains?(uri.host, ":"), do: "[" <> uri.host <> "]", else: uri.host
    :binary.copy(uri.scheme <> "://" <> host <> ":" <> Integer.to_string(uri.port))
  end

  defp protocol_scheme(:http2), do: "https"
  defp protocol_scheme(:h2c), do: "http"

  defp submitted_target(uri) do
    path = if uri.path in [nil, ""], do: "/", else: uri.path
    if uri.query == nil, do: path, else: path <> "?" <> uri.query
  end
end
