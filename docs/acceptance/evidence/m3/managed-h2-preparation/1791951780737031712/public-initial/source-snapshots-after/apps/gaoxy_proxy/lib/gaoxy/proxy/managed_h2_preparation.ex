defmodule Gaoxy.Proxy.ManagedH2Preparation do
  @moduledoc false

  defmodule Policy do
    @moduledoc false
    defstruct [:protocol, :origin, :scheme, :host, :port, :connect_address, :open_options]
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
