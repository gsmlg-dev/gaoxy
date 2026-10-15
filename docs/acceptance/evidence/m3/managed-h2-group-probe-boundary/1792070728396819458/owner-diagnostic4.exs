defmodule GaoxyProbeDiagnosticFixture do
  alias Gaoxy.Proxy.{HTTPFetchClient, ManagedH2Client, UpstreamGroups}
  def fixture(protocol) do
    transport = if protocol == :http1, do: nil, else: transport()
    scheme = if protocol == :http2, do: "https", else: "http"

    config = %Gaoxy.Proxy.HTTP{
      uri: compact_uri(scheme <> "://upstream.test"),
      upstream_protocol: protocol,
      client: if(protocol == :http1, do: HTTPFetchClient, else: ManagedH2Client),
      transport: transport,
      limits: limits(),
      cacertfile: nil,
      connect_address: nil
    }

    args = %{
      owner: self(),
      token: make_ref(),
      member: %{id: "member", config: config, max_inflight: 1},
      deadline: 12_000,
      health: health(),
      url: scheme <> "://upstream.test/health"
    }

    if protocol == :http1, do: args, else: Map.put(args, :group, group(transport))
  end

  def health,
    do: %{
      path: "/health",
      interval: 5_000,
      timeout: 2_000,
      stale_after: 15_000,
      failure_threshold: 3,
      recovery_threshold: 2,
      jitter: 500
    }

  def limits,
    do: %{
      max_chunk_bytes: 65_536,
      opening_timeout: 5_000,
      idle_timeout: 60_000,
      write_timeout: 3_000,
      max_lifetime: 30_000
    }

  def transport,
    do: %{
      provider: Gaoxy.Proxy.UpstreamTransports,
      owner: self(),
      owner_epoch: make_ref(),
      resource: make_ref()
    }

  def group(transport),
    do: %{
      provider: UpstreamGroups,
      owner: self(),
      owner_epoch: make_ref(),
      group: "group",
      generation: make_ref(),
      max_url_bytes: 8_192,
      transports: [transport],
      execution_profile: :managed_h2
    }

  def recovery(kind),
    do: %{
      owner: self(),
      recovery: {kind, make_ref()},
      completion: %HTTP.RequestCompletion{tracker: self(), latch: make_ref(), unsupported: nil},
      deadline: -1
    }

  def root(args), do: args.member.config.uri.scheme <> "://" <> args.member.config.uri.authority

  def with_path(args, path) when is_binary(path),
    do: %{args | health: %{args.health | path: path}, url: root(args) <> path}

  def with_path(args, path), do: %{args | health: %{args.health | path: path}}

  def compact_uri(value),
    do:
      Map.new(Map.to_list(URI.parse(value)), fn
        {key, value} when is_binary(value) -> {key, :binary.copy(value)}
        pair -> pair
      end)

  def raw_port_origin(bytes) do
    prefix = "https://upstream.test:"
    :binary.copy(prefix <> :binary.copy("0", bytes - byte_size(prefix) - 3) <> "443")
  end

  def slice(value, backing_bytes) do
    backing = :binary.copy(value <> :binary.copy("p", backing_bytes - byte_size(value)))
    binary_part(backing, 0, byte_size(value))
  end
end

alias Gaoxy.Proxy.UpstreamGroups
args = GaoxyProbeDiagnosticFixture.fixture(:http2)
config = args.member.config
health = args.health
group = args.group
transport = config.transport
backing_before = Enum.map([args.member.id, health.path, args.url, group.group], fn v -> [byte_size(v), :binary.referenced_byte_size(v)] end)
raw_result = UpstreamGroups.probe_start_arguments(args)
backing_after = Enum.map([args.member.id, health.path, args.url, group.group], fn v -> [byte_size(v), :binary.referenced_byte_size(v)] end)
copied_args = %{args | url: :binary.copy(args.url)}
copied_result = UpstreamGroups.probe_start_arguments(copied_args)
IO.puts(Jason.encode!(%{kind: "PURE_UNTRACED_OWNER_DIAGNOSIS", backing_before: backing_before, backing_after: backing_after, raw_result: inspect(elem(raw_result,0)), copied_result: inspect(elem(copied_result,0)), tests_executed: 0, no_trace_or_messages_before_constructor: true}))
