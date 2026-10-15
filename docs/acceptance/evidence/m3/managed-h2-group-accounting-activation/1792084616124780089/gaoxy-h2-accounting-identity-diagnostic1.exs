alias Gaoxy.Proxy.{ManagedH2GroupAccounting, UpstreamTransports}

source_expression = """
uri.scheme == if(protocol == :http2, do: "https", else: "http") and
  is_binary(uri.host) and byte_size(uri.host) in 1..253 and uri.userinfo == nil and
  uri.path in [nil, "", "/"] and uri.query == nil and uri.fragment == nil and
  is_integer(uri.port) and uri.port >= 1 and uri.port <= 65_535
"""
IO.inspect(Code.string_to_quoted!(source_expression), label: "identity_origin_source_ast", limit: :infinity)

for {protocol, base, port} <- [{:http2, "https://upstream.test", "443"}, {:h2c, "http://upstream.test", "80"}],
    bytes <- [:normal, 8_192] do
  root = if bytes == :normal, do: base,
    else: :binary.copy(base <> ":" <> :binary.copy("0", bytes - byte_size(base) - 1 - byte_size(port)) <> port)
  original_uri = URI.parse(root) |> Map.to_list() |> Map.new(fn
    {key, value} when is_binary(value) -> {key, :binary.copy(value)}
    pair -> pair
  end)
  origin = original_uri.scheme <> "://" <> original_uri.authority
  uri = URI.parse(origin)
  identity = %{origin: origin, upstream_protocol: protocol, instance: self()}
  transport = %{provider: UpstreamTransports, owner: self(), owner_epoch: make_ref(), resource: make_ref()}
  envelope = {:gaoxy_proxy_http, self(), {:transport_handoff, make_ref(), transport, identity, 20_000}}
  predicates = %{
    exact_identity_keys: Enum.sort(Map.keys(identity)) == Enum.sort([:origin, :upstream_protocol, :instance]),
    origin_bytes_valid: byte_size(origin) in 1..8_192,
    origin_backing_compact: :binary.referenced_byte_size(origin) == byte_size(origin),
    instance_etf_valid: :erlang.external_size(identity.instance) <= 2_048,
    protocol_valid: protocol in [:http2, :h2c],
    scheme_valid: uri.scheme == (if protocol == :http2, do: "https", else: "http"),
    host_valid: is_binary(uri.host) and byte_size(uri.host) in 1..253,
    userinfo_nil: uri.userinfo == nil,
    path_valid: uri.path in [nil, "", "/"],
    query_nil: uri.query == nil,
    fragment_nil: uri.fragment == nil,
    port_valid: is_integer(uri.port) and uri.port in 1..65_535
  }
  original_expression =
    uri.scheme == if(protocol == :http2, do: "https", else: "http") and
      is_binary(uri.host) and byte_size(uri.host) in 1..253 and uri.userinfo == nil and
      uri.path in [nil, "", "/"] and uri.query == nil and uri.fragment == nil and
      is_integer(uri.port) and uri.port >= 1 and uri.port <= 65_535
  IO.inspect(%{protocol: protocol, requested_bytes: bytes, actual_bytes: byte_size(origin),
    referenced_bytes: :binary.referenced_byte_size(origin), scheme: uri.scheme,
    host: uri.host, port: uri.port, path: uri.path, predicates: predicates,
    original_expression: original_expression,
    handoff_request_result: ManagedH2GroupAccounting.project({:control, :handoff_request}, envelope),
    identity_result: ManagedH2GroupAccounting.project({:control, :identity}, envelope)},
    label: "identity_diagnostic", limit: :infinity)
end
