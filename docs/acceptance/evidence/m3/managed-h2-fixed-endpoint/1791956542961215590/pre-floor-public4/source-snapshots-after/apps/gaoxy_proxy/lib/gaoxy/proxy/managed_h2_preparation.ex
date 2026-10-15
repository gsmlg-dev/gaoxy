defmodule Gaoxy.Proxy.ManagedH2Preparation do
  @moduledoc false

  defmodule Policy do
    @moduledoc false
    defstruct [:protocol, :origin, :scheme, :host, :port, :connect_address, :open_options]
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
  @limits %{
    url_bytes: @binary_cap,
    fields: 256,
    trailers: 128,
    field_bytes: @binary_cap,
    trailer_bytes: @binary_cap,
    effective_field_count: 256,
    effective_field_bytes: @binary_cap,
    projection_logical_bytes: 196_608,
    projection_external_bytes: 201_241,
    certificates: 128,
    certificate_bytes: @binary_cap,
    trust_bytes: @trust_cap,
    ssl_socket_policy_external_bytes: @trust_cap,
    policy_source_backing_bytes: @binary_cap + @trust_cap,
    request_source_backing_bytes: 196_608
  }

  def prepare_policy(
        %{protocol: protocol, origin: origin, connect_address: address, trust: trust} = source
      )
      when map_size(source) == 4 and protocol in [:http2, :h2c] do
    with :ok <- url_source(origin),
         :ok <- address_shape(address),
         :ok <- trust_source(trust),
         {:ok, uri} <- parse_url(origin),
         true <- uri.path in [nil, "", "/"] and is_nil(uri.query),
         :ok <- protocol_trust(protocol, uri.scheme, trust) do
      origin = :binary.copy(origin)
      host = :binary.copy(String.downcase(uri.host))
      ssl = ssl_options(protocol, host, trust)

      if :erlang.external_size({ssl, @sockets}) <= @trust_cap do
        policy = %Policy{
          protocol: protocol,
          origin: origin,
          scheme: scheme(uri.scheme),
          host: host,
          port: uri.port,
          connect_address: address,
          open_options: open_options(protocol, origin, address, ssl)
        }

        {:ok, policy, policy_manifest(source, policy)}
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
         {:ok, field_logical} <- pairs_source(fields, :fields, 0, 0, 0, 0),
         {:ok, trailer_logical} <- pairs_source(trailers, :trailers, 0, 2, 0, 0),
         {:ok, uri} <- parse_url(url),
         :ok <- matching_origin(policy, uri),
         {:ok, target} <- target(uri),
         true <- byte_size(url) + byte_size(target) + field_logical + trailer_logical <= 196_608,
         :ok <- fields_semantics(fields, :invalid_fields),
         :ok <- fields_semantics(trailers, :invalid_trailers),
         {:ok, canonical_fields} <- canonical_fields(fields, body),
         :ok <- upload_trailers(body, fields, trailers),
         {:ok, effective_count, effective_bytes} <-
           effective_fields(policy, method, target, canonical_fields),
         true <-
           byte_size(url) + byte_size(target) + pairs_logical(canonical_fields) + trailer_logical <=
             196_608 do
      prepared = %Request{
        url: :binary.copy(url),
        method: method,
        fields: copy_pairs(canonical_fields),
        body: body,
        trailers: copy_pairs(trailers),
        timeout: timeout,
        connect_timeout: connect_timeout,
        target: :binary.copy(target)
      }

      source_projection = {url, target, fields, trailers}
      canonical_projection = {prepared.url, prepared.target, prepared.fields, prepared.trailers}

      if :erlang.external_size(source_projection) <= 201_241 and
           :erlang.external_size(canonical_projection) <= 201_241 do
        {:ok, prepared,
         request_manifest(
           source,
           prepared,
           source_projection,
           canonical_projection,
           effective_count,
           effective_bytes
         )}
      else
        {:error, :request_limit}
      end
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
           protocol: protocol,
           origin: origin,
           scheme: selected_scheme,
           host: host,
           port: port,
           connect_address: address,
           open_options: options
         } = policy
       )
       when map_size(policy) == 8 and protocol in [:http2, :h2c] do
    with :ok <- compact_url(origin),
         true <- is_binary(host) and byte_size(host) in 1..253 and compact?(host),
         true <- is_integer(port) and port in 1..65_535,
         :ok <- address_shape(address),
         {:ok, uri} <- parse_url(origin),
         true <-
           uri.path in [nil, "", "/"] and is_nil(uri.query) and
             scheme(uri.scheme) == selected_scheme and String.downcase(uri.host) == host and
             uri.port == port,
         true <-
           (protocol == :h2c and uri.scheme == "http") or
             (protocol == :http2 and uri.scheme == "https"),
         :ok <- canonical_options(options, protocol, origin, address, host) do
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
           http_version: protocol,
           tls_backend: :ssl,
           http2_profile: :native_v1,
           max_requests: 32,
           max_connections: 2,
           max_pending: 0,
           idle_timeout: 30_000,
           ssl: ssl,
           socket_opts: @sockets
         ],
         protocol,
         origin,
         address,
         host
       ) do
    with :ok <- compact_url(options_origin),
         true <- options_origin == origin,
         :ok <- canonical_ssl(ssl, protocol, host),
         true <- :erlang.external_size({ssl, @sockets}) <= @trust_cap do
      :ok
    else
      _ -> {:error, :invalid_policy}
    end
  end

  defp canonical_options(_, _, _, _, _), do: {:error, :invalid_policy}
  defp canonical_ssl([], :h2c, _host), do: :ok

  defp canonical_ssl(
         [
           verify: :verify_peer,
           depth: 4,
           versions: [:"tlsv1.3", :"tlsv1.2"],
           cacerts: certificates,
           server_name_indication: sni
         ],
         :http2,
         host
       ) do
    with :ok <- trust_source(certificates),
         true <- certificates != nil and compact_certificates?(certificates),
         true <- bounded_sni?(sni, 0) and sni == String.to_charlist(host) do
      :ok
    else
      _ -> {:error, :invalid_policy}
    end
  end

  defp canonical_ssl(_, _, _), do: {:error, :invalid_policy}
  defp bounded_sni?([], _count), do: true

  defp bounded_sni?([char | rest], count)
       when count < 253 and is_integer(char) and char in 33..126,
       do: bounded_sni?(rest, count + 1)

  defp bounded_sni?(_, _count), do: false

  defp compact_certificates?([]), do: true
  defp compact_certificates?([cert | rest]), do: compact?(cert) and compact_certificates?(rest)
  defp compact?(value), do: :binary.referenced_byte_size(value) == byte_size(value)

  defp compact_url(value) do
    with :ok <- url_source(value), true <- compact?(value), do: :ok
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

  defp pairs_source([], _kind, _count, _bytes, _backing, logical), do: {:ok, logical}

  defp pairs_source([_ | _], :fields, 256, _bytes, _backing, _logical),
    do: {:error, :request_limit}

  defp pairs_source([_ | _], :trailers, 128, _bytes, _backing, _logical),
    do: {:error, :trailer_limit}

  defp pairs_source([{name, value} | rest], kind, count, bytes, backing, logical)
       when is_binary(name) and is_binary(value) do
    payload = byte_size(name) + byte_size(value)
    bytes = bytes + payload + if(kind == :fields, do: 32, else: 4)
    backing = backing + :binary.referenced_byte_size(name) + :binary.referenced_byte_size(value)

    cond do
      bytes > @binary_cap ->
        {:error, if(kind == :fields, do: :request_limit, else: :trailer_limit)}

      backing > @binary_cap ->
        {:error, :source_backing_limit}

      true ->
        pairs_source(rest, kind, count + 1, bytes, backing, logical + payload)
    end
  end

  defp pairs_source(_, :fields, _count, _bytes, _backing, _logical), do: {:error, :invalid_fields}

  defp pairs_source(_, :trailers, _count, _bytes, _backing, _logical),
    do: {:error, :invalid_trailers}

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
    (char in ?0..?9 or char in ?A..?Z or char in ?a..?z or char in ~c"!#$%&'*+-.^_`|~") and
      token_bytes?(rest)
  end

  defp field_value?(<<>>), do: true

  defp field_value?(<<char, rest::binary>>) when char == 9 or (char >= 32 and char != 127),
    do: field_value?(rest)

  defp field_value?(_), do: false

  defp upload_trailers(body, fields, trailers) do
    with true <- is_pid(body) or trailers == [],
         :ok <- declaration_counts(fields, 0),
         {:ok, _} <- HTTP.Trailers.upload(trailers, %HTTP.Headers{headers: fields}) do
      :ok
    else
      _ -> {:error, :invalid_trailers}
    end
  end

  defp declaration_counts([], _count), do: :ok

  defp declaration_counts([{name, value} | rest], count) do
    if String.downcase(name) == "trailer" do
      with {:ok, count} <- declaration_tokens(value, count), do: declaration_counts(rest, count)
    else
      declaration_counts(rest, count)
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

  defp canonical_fields(fields, body) do
    with {:ok, reversed, length} <- normalize_fields(fields, [], nil) do
      fields = Enum.reverse(reversed)

      fields =
        if List.keymember?(fields, "user-agent", 0),
          do: fields,
          else: fields ++ [{"user-agent", "gaoxy"}]

      fields =
        if is_pid(body) and not List.keymember?(fields, "content-type", 0),
          do: fields ++ [{"content-type", "application/octet-stream"}],
          else: fields

      fields =
        if is_pid(body) and length != nil,
          do: fields ++ [{"content-length", length}],
          else: fields

      {:ok, fields}
    end
  end

  defp normalize_fields([], reversed, length), do: {:ok, reversed, length}

  defp normalize_fields([{name, value} | rest], reversed, length) do
    name = String.downcase(name)

    case name do
      name
      when name in [
             "host",
             "connection",
             "keep-alive",
             "proxy-connection",
             "transfer-encoding",
             "upgrade"
           ] ->
        {:error, :invalid_fields}

      "te" ->
        if trailers_value?(trim_ows(value)),
          do: normalize_fields(rest, [{"te", "trailers"} | reversed], length),
          else: {:error, :invalid_fields}

      "trailer" ->
        normalize_fields(rest, reversed, length)

      "content-length" ->
        if valid_content_length?(value) and (length == nil or length == value),
          do: normalize_fields(rest, reversed, value),
          else: {:error, :invalid_fields}

      _ ->
        normalize_fields(rest, [{name, value} | reversed], length)
    end
  end

  defp valid_content_length?(value),
    do:
      byte_size(value) in 1..20 and digits?(value) and
        (byte_size(value) < 20 or value <= "18446744073709551615")

  defp trailers_value?(<<t, r, a, i, l, e, r2, s>>),
    do:
      t in [?t, ?T] and r in [?r, ?R] and a in [?a, ?A] and i in [?i, ?I] and
        l in [?l, ?L] and e in [?e, ?E] and r2 in [?r, ?R] and s in [?s, ?S]

  defp trailers_value?(_), do: false

  defp effective_fields(policy, method, target, fields) do
    host = if String.contains?(policy.host, ":"), do: "[" <> policy.host <> "]", else: policy.host
    default_port = if policy.scheme == :https, do: 443, else: 80

    authority =
      if policy.port == default_port,
        do: host,
        else: host <> ":" <> Integer.to_string(policy.port)

    pseudo = [
      {":method", method |> Atom.to_string() |> String.upcase()},
      {":scheme", Atom.to_string(policy.scheme)},
      {":authority", authority},
      {":path", target}
    ]

    count = 4 + length(fields)

    bytes =
      Enum.reduce(pseudo ++ fields, 0, fn {name, value}, total ->
        total + byte_size(name) + byte_size(value) + 32
      end)

    if count <= 256 and bytes <= @binary_cap,
      do: {:ok, count, bytes},
      else: {:error, :request_limit}
  end

  defp pairs_logical(fields),
    do:
      Enum.reduce(fields, 0, fn {name, value}, total ->
        total + byte_size(name) + byte_size(value)
      end)

  defp copy_pairs(fields),
    do: Enum.map(fields, fn {name, value} -> {:binary.copy(name), :binary.copy(value)} end)

  defp request_manifest(
         source,
         prepared,
         source_projection,
         canonical_projection,
         effective_count,
         effective_bytes
       ) do
    source_facts = constructors(source)
    owned = constructors(prepared)

    %{
      kind: :request,
      source: source_facts,
      owned: owned,
      transient: %{
        source_plus_owned_backing_upper: source_facts.backing_bytes + owned.backing_bytes
      },
      source_external_bytes: :erlang.external_size(source),
      prepared_external_bytes: :erlang.external_size(prepared),
      source_projection_external_bytes: :erlang.external_size(source_projection),
      canonical_projection_external_bytes: :erlang.external_size(canonical_projection),
      effective_field_count: effective_count,
      effective_field_bytes: effective_bytes,
      limits: @limits
    }
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

  defp protocol_trust(:h2c, "http", nil), do: :ok
  defp protocol_trust(:http2, "https", [_ | _]), do: :ok
  defp protocol_trust(_, _, _), do: {:error, :invalid_trust}

  defp parse_url(value) do
    with true <- url_text?(value),
         %URI{scheme: scheme, host: host, port: port, userinfo: nil, fragment: nil} = uri <-
           URI.parse(value),
         true <-
           scheme in ["http", "https"] and is_binary(host) and
             byte_size(host) in 1..253 and is_integer(port) and port in 1..65_535,
         true <- valid_authority?(uri.authority, host) do
      {:ok, uri}
    else
      _ -> {:error, :invalid_url}
    end
  rescue
    ArgumentError -> {:error, :invalid_url}
  end

  defp valid_authority?(authority, host) do
    prefix = if String.contains?(host, ":"), do: "[" <> host <> "]", else: host
    prefix_bytes = byte_size(prefix)

    case authority do
      ^prefix -> true
      <<^prefix::binary-size(prefix_bytes), ?:, port::binary>> -> port != "" and digits?(port)
      _ -> false
    end
  end

  defp digits?(<<>>), do: true
  defp digits?(<<char, rest::binary>>) when char in ?0..?9, do: digits?(rest)
  defp digits?(_), do: false

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

  defp ssl_options(:h2c, _host, nil), do: []

  defp ssl_options(:http2, host, trust) do
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

  defp open_options(protocol, origin, address, ssl) do
    [
      origin: origin,
      connect_address: address,
      http_version: protocol,
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

  # Only bounded validated sources and newly constructed values reach this walk.
  # These facts count constructor and backing occurrences, not VM memory.
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

  defp policy_manifest(source, policy) do
    source_facts = constructors(source)
    owned = constructors(policy)
    policy_bytes = :erlang.external_size(policy)

    %{
      kind: :policy,
      source: source_facts,
      owned: owned,
      transient: %{
        source_plus_owned_backing_upper: source_facts.backing_bytes + owned.backing_bytes
      },
      source_external_bytes: :erlang.external_size(source),
      prepared_external_bytes: policy_bytes,
      policy_external_bytes: policy_bytes,
      limits: @limits
    }
  end
end
