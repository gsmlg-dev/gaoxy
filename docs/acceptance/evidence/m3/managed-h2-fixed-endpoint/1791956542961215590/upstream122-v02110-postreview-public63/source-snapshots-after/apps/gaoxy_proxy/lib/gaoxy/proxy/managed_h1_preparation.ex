defmodule Gaoxy.Proxy.ManagedH1Preparation do
  @moduledoc false

  defmodule Policy do
    @moduledoc false
    defstruct [:origin, :scheme, :host, :port, :connect_address, :open_options]
  end

  defmodule Request do
    @moduledoc false
    defstruct [:url, :method, :fields, :body, :trailers, :timeout, :connect_timeout, :target]
  end

  @binary_cap 65_536
  @trust_cap 1_048_576
  @sockets [
    buffer: 8192,
    recbuf: 8192,
    sndbuf: 8192,
    nodelay: true,
    send_timeout: 30_000,
    send_timeout_close: true
  ]

  def prepare_policy(%{origin: origin, connect_address: address, trust: trust} = source)
      when map_size(source) == 3 do
    with :ok <- url_source(origin),
         :ok <- address_shape(address),
         :ok <- trust_source(trust),
         {:ok, uri} <- parse_url(origin),
         true <- uri.path in [nil, "", "/"] and is_nil(uri.query),
         :ok <- trust_for_scheme(uri.scheme, trust) do
      source_counts = constructors(source)
      origin = :binary.copy(origin)
      host = :binary.copy(String.downcase(uri.host))
      ssl = ssl_options(uri.scheme, host, trust)

      if :erlang.external_size({ssl, @sockets}) <= @trust_cap do
        policy = %Policy{
          origin: origin,
          scheme: scheme(uri.scheme),
          host: host,
          port: uri.port,
          connect_address: address,
          open_options: open_options(origin, address, ssl)
        }

        {:ok, policy, manifest(:policy, source_counts, policy, 0)}
      else
        {:error, :policy_limit}
      end
    else
      false -> {:error, :invalid_url}
      {:error, _} = error -> error
    end
  end

  def prepare_policy(_), do: {:error, :invalid_policy}

  def prepare_request(policy, source) do
    with :ok <- canonical_policy(policy) do
      request(policy, source)
    else
      _ -> {:error, :invalid_policy}
    end
  end

  defp request(
         policy,
         %{
           url: url,
           method: method,
           fields: fields,
           body: body,
           trailers: trailers,
           timeout: timeout,
           connect_timeout: connect_timeout
         } = source
       )
       when map_size(source) == 7 do
    with :ok <- request_scalars(method, body, timeout, connect_timeout),
         :ok <- url_source(url),
         {:ok, field_count, field_bytes} <- pairs_source(fields, :fields, 0, 0, 0),
         {:ok, trailer_count, _} <- pairs_source(trailers, :trailers, 0, 2, 0),
         {:ok, uri} <- parse_url(url),
         :ok <- matching_origin(policy, uri),
         {:ok, target} <- target(uri),
         true <- byte_size(target) + field_bytes <= @binary_cap,
         :ok <- fields_semantics(fields, :invalid_fields),
         :ok <- fields_semantics(trailers, :invalid_trailers),
         :ok <- upload_trailers(body, fields, trailers) do
      source_counts = constructors(source)

      prepared = %Request{
        url: :binary.copy(url),
        target: :binary.copy(target),
        method: method,
        fields: copy_pairs(fields),
        body: body,
        trailers: copy_pairs(trailers),
        timeout: timeout,
        connect_timeout: connect_timeout
      }

      {:ok, prepared, manifest(:request, source_counts, prepared, field_count + trailer_count)}
    else
      false -> {:error, :request_limit}
      {:error, _} = error -> error
    end
  end

  defp request(_, _), do: {:error, :invalid_request}

  defp request_scalars(method, body, timeout, connect_timeout) do
    if method in [:get, :head, :post, :put, :delete, :patch, :options] and
         (is_nil(body) or is_pid(body)) and valid_timeout?(timeout) and
         valid_timeout?(connect_timeout),
       do: :ok,
       else: {:error, :invalid_request}
  end

  defp valid_timeout?(value), do: is_integer(value) and value in 1..86_400_000

  defp canonical_policy(
         %Policy{
           origin: origin,
           scheme: selected_scheme,
           host: host,
           port: port,
           connect_address: address,
           open_options: options
         } = policy
       )
       when map_size(policy) == 7 do
    with :ok <- compact_url(origin),
         true <- is_binary(host) and byte_size(host) in 1..253 and compact?(host),
         :ok <- address_shape(address),
         {:ok, uri} <- parse_url(origin),
         true <-
           uri.path in [nil, "", "/"] and is_nil(uri.query) and
             scheme(uri.scheme) == selected_scheme and String.downcase(uri.host) == host and
             uri.port == port,
         :ok <- canonical_options(options, origin, address, uri.scheme, host) do
      :ok
    else
      _ -> {:error, :invalid_policy}
    end
  end

  defp canonical_policy(_), do: {:error, :invalid_policy}

  defp canonical_options(
         [
           origin: options_origin,
           connect_address: address,
           http_version: :http1,
           tls_backend: :ssl,
           http2_profile: :native_v1,
           max_requests: 32,
           max_connections: 2,
           max_pending: 0,
           idle_timeout: 30_000,
           ssl: ssl,
           socket_opts: @sockets
         ],
         origin,
         address,
         selected_scheme,
         host
       ) do
    with :ok <- compact_url(options_origin),
         true <- options_origin == origin,
         :ok <- canonical_ssl(ssl, selected_scheme, host),
         true <- :erlang.external_size({ssl, @sockets}) <= @trust_cap do
      :ok
    else
      _ -> {:error, :invalid_policy}
    end
  end

  defp canonical_options(_, _, _, _, _), do: {:error, :invalid_policy}

  defp canonical_ssl([], "http", _host), do: :ok

  defp canonical_ssl(
         [
           verify: :verify_peer,
           depth: 4,
           versions: [:"tlsv1.3", :"tlsv1.2"],
           cacerts: certificates,
           server_name_indication: sni
         ],
         "https",
         host
       ) do
    with :ok <- trust_source(certificates),
         true <-
           certificates != nil and compact_certificates?(certificates) and
             sni == String.to_charlist(host) do
      :ok
    else
      _ -> {:error, :invalid_policy}
    end
  end

  defp canonical_ssl(_, _, _), do: {:error, :invalid_policy}

  defp compact_certificates?([]), do: true

  defp compact_certificates?([cert | rest]),
    do: compact?(cert) and compact_certificates?(rest)

  defp compact?(value), do: :binary.referenced_byte_size(value) == byte_size(value)

  defp compact_url(value) do
    with :ok <- url_source(value), true <- compact?(value) do
      :ok
    else
      _ -> {:error, :invalid_policy}
    end
  end

  defp matching_origin(policy, uri) do
    if scheme(uri.scheme) == policy.scheme and String.downcase(uri.host) == policy.host and
         uri.port == policy.port,
       do: :ok,
       else: {:error, :origin_mismatch}
  end

  defp target(uri) do
    path = if uri.path in [nil, ""], do: "/", else: uri.path

    case path do
      "/" <> _ -> {:ok, if(is_nil(uri.query), do: path, else: path <> "?" <> uri.query)}
      _ -> {:error, :invalid_url}
    end
  end

  defp pairs_source([], _kind, count, bytes, _backing), do: {:ok, count, bytes}
  defp pairs_source([_ | _], :fields, 256, _bytes, _backing), do: {:error, :request_limit}
  defp pairs_source([_ | _], :trailers, 128, _bytes, _backing), do: {:error, :trailer_limit}

  defp pairs_source([{name, value} | rest], kind, count, bytes, backing)
       when is_binary(name) and is_binary(value) do
    overhead = if kind == :fields, do: 32, else: 4
    bytes = bytes + byte_size(name) + byte_size(value) + overhead
    backing = backing + :binary.referenced_byte_size(name) + :binary.referenced_byte_size(value)

    cond do
      bytes > @binary_cap ->
        {:error, if(kind == :fields, do: :request_limit, else: :trailer_limit)}

      backing > @binary_cap ->
        {:error, :source_backing_limit}

      true ->
        pairs_source(rest, kind, count + 1, bytes, backing)
    end
  end

  defp pairs_source(_, :fields, _count, _bytes, _backing), do: {:error, :invalid_fields}
  defp pairs_source(_, :trailers, _count, _bytes, _backing), do: {:error, :invalid_trailers}

  defp fields_semantics([], _error), do: :ok

  defp fields_semantics([{name, value} | rest], error) do
    if token?(name) and field_value?(value),
      do: fields_semantics(rest, error),
      else: {:error, error}
  end

  defp token?(<<>>), do: false
  defp token?(value), do: token_bytes?(value)
  defp token_bytes?(<<>>), do: true

  defp token_bytes?(<<char, rest::binary>>) do
    (char in ?0..?9 or char in ?A..?Z or char in ?a..?z or
       char in ~c"!#$%&'*+-.^_`|~") and token_bytes?(rest)
  end

  defp field_value?(<<>>), do: true

  defp field_value?(<<char, rest::binary>>) when char == 9 or (char >= 32 and char != 127),
    do: field_value?(rest)

  defp field_value?(_), do: false

  defp upload_trailers(body, fields, trailers) do
    with true <- is_pid(body) or trailers == [],
         :ok <- declaration_counts(fields, %{trailer: 0, connection: 0}),
         {:ok, _} <- HTTP.Trailers.upload(trailers, %HTTP.Headers{headers: fields}) do
      :ok
    else
      _ -> {:error, :invalid_trailers}
    end
  end

  defp declaration_counts([], _counts), do: :ok

  defp declaration_counts([{name, value} | rest], counts) do
    case String.downcase(name) do
      "trailer" -> declaration_field(value, :trailer, rest, counts)
      "connection" -> declaration_field(value, :connection, rest, counts)
      _ -> declaration_counts(rest, counts)
    end
  end

  defp declaration_field(value, kind, rest, counts) do
    with {:ok, total} <- declaration_tokens(value, counts[kind]) do
      declaration_counts(rest, Map.put(counts, kind, total))
    end
  end

  defp declaration_tokens(_value, 128), do: {:error, :invalid_trailers}

  defp declaration_tokens(value, count) do
    case :binary.match(value, ",") do
      :nomatch ->
        if token?(trim_ows(value)), do: {:ok, count + 1}, else: {:error, :invalid_trailers}

      {index, 1} ->
        if token?(trim_ows(binary_part(value, 0, index))) do
          declaration_tokens(
            binary_part(value, index + 1, byte_size(value) - index - 1),
            count + 1
          )
        else
          {:error, :invalid_trailers}
        end
    end
  end

  defp trim_ows(<<char, rest::binary>>) when char in [9, 32], do: trim_ows(rest)
  defp trim_ows(value), do: trim_end_ows(value)
  defp trim_end_ows(<<>>), do: <<>>

  defp trim_end_ows(value) do
    if :binary.last(value) in [9, 32],
      do: trim_end_ows(binary_part(value, 0, byte_size(value) - 1)),
      else: value
  end

  defp copy_pairs(fields) do
    fields
    |> Enum.reduce([], fn {name, value}, acc ->
      [{:binary.copy(name), :binary.copy(value)} | acc]
    end)
    |> Enum.reverse()
  end

  defp url_source(value) when is_binary(value) and byte_size(value) in 1..@binary_cap do
    if :binary.referenced_byte_size(value) <= @binary_cap,
      do: :ok,
      else: {:error, :source_backing_limit}
  end

  defp url_source(_), do: {:error, :invalid_url}

  defp address_shape(address) when is_tuple(address) and tuple_size(address) in [4, 8] do
    maximum = if tuple_size(address) == 4, do: 255, else: 65_535

    if Enum.all?(Tuple.to_list(address), &(is_integer(&1) and &1 in 0..maximum)),
      do: :ok,
      else: {:error, :invalid_policy}
  end

  defp address_shape(_), do: {:error, :invalid_policy}

  defp trust_source(nil), do: :ok
  defp trust_source([_ | _] = certificates), do: trust_source(certificates, 0, 0, 0)
  defp trust_source(_), do: {:error, :invalid_trust}

  defp trust_source([], _count, _logical, _backing), do: :ok
  defp trust_source([_ | _], 128, _logical, _backing), do: {:error, :trust_limit}

  defp trust_source([cert | rest], count, logical, backing) when is_binary(cert) do
    bytes = byte_size(cert)
    retained = :binary.referenced_byte_size(cert)

    cond do
      bytes == 0 ->
        {:error, :invalid_trust}

      bytes > @binary_cap or logical + bytes > @trust_cap ->
        {:error, :trust_limit}

      retained > @binary_cap or backing + retained > @trust_cap ->
        {:error, :source_backing_limit}

      true ->
        trust_source(rest, count + 1, logical + bytes, backing + retained)
    end
  end

  defp trust_source(_, _count, _logical, _backing), do: {:error, :invalid_trust}

  defp trust_for_scheme("http", nil), do: :ok
  defp trust_for_scheme("https", [_ | _]), do: :ok
  defp trust_for_scheme(_, _), do: {:error, :invalid_trust}

  defp parse_url(value) do
    with true <- url_text?(value),
         %URI{scheme: scheme, host: host, port: port, userinfo: nil, fragment: nil} = uri <-
           URI.parse(value),
         true <-
           scheme in ["http", "https"] and is_binary(host) and
             byte_size(host) in 1..253 and is_integer(port) and port in 1..65_535 do
      {:ok, uri}
    else
      _ -> {:error, :invalid_url}
    end
  rescue
    ArgumentError -> {:error, :invalid_url}
  end

  defp url_text?(<<>>), do: true

  defp url_text?(<<?%, a, b, rest::binary>>),
    do: hex?(a) and hex?(b) and url_text?(rest)

  defp url_text?(<<?%, _::binary>>), do: false

  defp url_text?(<<char, rest::binary>>) when char in 33..126 and char not in [?#, ?\\],
    do: url_text?(rest)

  defp url_text?(_), do: false
  defp hex?(char), do: char in ?0..?9 or char in ?a..?f or char in ?A..?F

  defp scheme("http"), do: :http
  defp scheme("https"), do: :https

  defp ssl_options("http", _host, nil), do: []

  defp ssl_options("https", host, trust) do
    # Explicit managed H1 retains the qualified profile without ALPN advertisement.
    # Optional negotiated H1 ALPN support is separate from this profile.
    # TODO(upstream): gsmlg-dev/http_fetch#107
    [
      verify: :verify_peer,
      depth: 4,
      versions: [:"tlsv1.3", :"tlsv1.2"],
      cacerts: copy_trust(trust),
      server_name_indication: String.to_charlist(host)
    ]
  end

  defp copy_trust([]), do: []
  defp copy_trust([cert | rest]), do: [:binary.copy(cert) | copy_trust(rest)]

  defp open_options(origin, address, ssl) do
    [
      origin: origin,
      connect_address: address,
      http_version: :http1,
      tls_backend: :ssl,
      http2_profile: :native_v1,
      max_requests: 32,
      max_connections: 2,
      max_pending: 0,
      idle_timeout: 30_000,
      ssl: ssl,
      socket_opts: @sockets
    ]
  end

  # These are constructor/backing occurrence facts, not a VM byte reservation.
  # Only validated finite input and newly constructed canonical values reach this walk.
  defp constructors(value) do
    count(value, %{
      logical_bytes: 0,
      backing_bytes: 0,
      binary_occurrences: 0,
      cons_cells: 0,
      tuples: %{},
      maps: %{},
      atom_occurrences: 0,
      integer_occurrences: 0,
      pid_occurrences: 0
    })
  end

  defp count([], counts), do: counts

  defp count([value | rest], counts),
    do: count(rest, count(value, increment(counts, :cons_cells)))

  defp count(value, counts) when is_binary(value) do
    %{
      counts
      | logical_bytes: counts.logical_bytes + byte_size(value),
        backing_bytes: counts.backing_bytes + :binary.referenced_byte_size(value),
        binary_occurrences: counts.binary_occurrences + 1
    }
  end

  defp count(value, counts) when is_tuple(value) do
    counts = %{counts | tuples: Map.update(counts.tuples, tuple_size(value), 1, &(&1 + 1))}
    Enum.reduce(Tuple.to_list(value), counts, &count/2)
  end

  defp count(value, counts) when is_map(value) do
    counts = %{counts | maps: Map.update(counts.maps, map_size(value), 1, &(&1 + 1))}
    :maps.fold(fn key, value, acc -> count(value, count(key, acc)) end, counts, value)
  end

  defp count(value, counts) when is_atom(value), do: increment(counts, :atom_occurrences)
  defp count(value, counts) when is_integer(value), do: increment(counts, :integer_occurrences)
  defp count(value, counts) when is_pid(value), do: increment(counts, :pid_occurrences)

  defp increment(counts, key), do: Map.update!(counts, key, &(&1 + 1))

  defp manifest(kind, source_counts, canonical, reversals) do
    owned = constructors(canonical)

    %{
      kind: kind,
      source: source_counts,
      owned: owned,
      transient: %{
        source_plus_owned_backing_upper: source_counts.backing_bytes + owned.backing_bytes,
        pair_reversal_extra_cons: reversals
      },
      limits: %{
        url_bytes: @binary_cap,
        fields: 256,
        trailers: 128,
        field_bytes: @binary_cap,
        trailer_bytes: @binary_cap,
        certificates: 128,
        certificate_bytes: @binary_cap,
        trust_bytes: @trust_cap,
        policy_source_backing_bytes: @binary_cap + @trust_cap,
        request_source_backing_bytes: 3 * @binary_cap
      }
    }
  end
end
