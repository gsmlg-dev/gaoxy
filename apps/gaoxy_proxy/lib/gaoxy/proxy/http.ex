defmodule Gaoxy.Proxy.HTTP do
  @moduledoc """
  Native reverse proxy to one fixed HTTP or verified HTTPS authority.
  HTTP/1 is the default; explicit HTTP/3 requires HTTPS and an explicit trust file.

  Paths and queries retain their wire escaping, including a present empty query.
  Uploads and raw responses stream
  with acknowledged local writes; redirects are returned and requests are never
  replayed. An external guardian retains the admission reservation until public
  request cleanup completes. Configure a service byte budget for the conservative
  pinned-client reservation (roughly 8 MiB per active request); the core default
  1 MiB budget rejects these sessions. This is a payload/copy allowance, not a
  measurement of total BEAM, process or OTP/kernel socket memory.

  The qualified host uses the default :inet backend and OTP SSL internal_active_n
  from 1 through 100. Keep these startup settings stable; incompatible hosts are
  rejected without changing global configuration or transport providers.
  """
  @behaviour Gaoxy.HTTP.Endpoint
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.{HTTPFetchClient, HTTP3SessionClient, ManagedH2Client, ManagedH2Envelope}
  alias Gaoxy.HTTP.{Exchange, Resources, Response}
  alias Gaoxy.Proxy.{UpstreamTransports, ManagedH2GroupAccounting}
  alias Gaoxy.Proxy.HTTP.{Headers, Session}

  @defaults %{
    max_chunk_bytes: 65_536,
    opening_timeout: 5_000,
    idle_timeout: 60_000,
    write_timeout: 5_000,
    max_lifetime: 30_000
  }
  @methods %{
    "GET" => :get,
    "HEAD" => :head,
    "POST" => :post,
    "PUT" => :put,
    "PATCH" => :patch,
    "DELETE" => :delete,
    "OPTIONS" => :options
  }
  @poll_ms 5
  @signed_min -9_223_372_036_854_775_808
  @signed_max 9_223_372_036_854_775_807
  defstruct [
    :uri,
    :cacertfile,
    :connect_address,
    :transport,
    :limits,
    upstream_protocol: :http1,
    client: HTTPFetchClient
  ]

  @impl true
  def init(%__MODULE__{} = config) do
    with true <- Map.keys(config) -- Map.keys(%__MODULE__{}) == [],
         true <- is_struct(config.uri, URI) and is_map(config.limits),
         true <-
           config.upstream_protocol not in [:http2, :h2c] or
             (is_binary(config.uri.scheme) and is_binary(config.uri.authority)),
         options =
           Map.merge(config.limits, %{
             upstream:
               if(config.upstream_protocol in [:http2, :h2c],
                 do: config.uri.scheme <> "://" <> config.uri.authority,
                 else: URI.to_string(config.uri)
               ),
             upstream_protocol: config.upstream_protocol,
             cacertfile: config.cacertfile,
             connect_address: config.connect_address,
             transport: config.transport
           }),
         {:ok, validated} <- init(options),
         true <- validated == config do
      {:ok, validated}
    else
      _ -> {:error, :invalid_http_proxy_options}
    end
  rescue
    _ -> {:error, :invalid_http_proxy_options}
  end

  def init(%{upstream: upstream} = options) when is_binary(upstream) do
    protocol = Map.get(options, :upstream_protocol, :http1)
    transport = Map.get(options, :transport)
    chunk_limit = if protocol == :http3, do: 16_384, else: 65_536

    limits =
      Map.merge(
        %{@defaults | max_chunk_bytes: chunk_limit},
        Map.take(options, Map.keys(@defaults))
      )

    with true <- managed_source?(transport, upstream),
         uri = URI.parse(upstream),
         true <-
           Map.keys(options) --
             [
               :upstream,
               :upstream_protocol,
               :cacertfile,
               :connect_address,
               :transport | Map.keys(@defaults)
             ] ==
             [],
         true <- managed_options?(transport, uri, protocol, options),
         true <- protocol in [:http1, :http2, :h2c, :http3],
         true <- uri.scheme in ["http", "https"] and is_binary(uri.host) and uri.host != "",
         true <- is_integer(uri.port) and uri.port in 1..65_535,
         true <-
           uri.userinfo == nil and uri.path in [nil, "", "/"] and uri.query == nil and
             uri.fragment == nil,
         true <- Enum.all?(limits, fn {_, value} -> is_integer(value) and value > 0 end),
         true <- limits.max_chunk_bytes <= chunk_limit,
         true <-
           is_nil(options[:cacertfile]) or
             (is_binary(options[:cacertfile]) and File.regular?(options[:cacertfile])),
         true <-
           protocol != :http3 or
             (uri.scheme == "https" and is_binary(options[:cacertfile]) and
                is_nil(options[:connect_address])),
         {:ok, address} <- connect_address(options[:connect_address]),
         client = protocol_client(protocol),
         true <- client.host_supported?() do
      uri =
        if protocol in [:http2, :h2c],
          do: %{uri | path: nil},
          else: URI.parse(URI.to_string(%{uri | path: nil}))

      config = %__MODULE__{
        uri: if(protocol in [:http2, :h2c], do: compact_uri(uri), else: uri),
        cacertfile: options[:cacertfile],
        connect_address: address,
        transport: transport,
        limits: limits,
        upstream_protocol: protocol,
        client: client
      }

      if protocol in [:http2, :h2c] do
        case ManagedH2Envelope.validate_config(config) do
          :ok -> {:ok, config}
          _ -> {:error, :invalid_http_proxy_options}
        end
      else
        {:ok, config}
      end
    else
      _ -> {:error, :invalid_http_proxy_options}
    end
  rescue
    ArgumentError -> {:error, :invalid_http_proxy_options}
  end

  def init(_), do: {:error, :invalid_http_proxy_options}

  @impl true
  def resources(%__MODULE__{transport: nil}), do: []
  def resources(%__MODULE__{transport: transport}), do: [transport]

  defp managed_source?(nil, _), do: true

  defp managed_source?(_, origin),
    do:
      byte_size(origin) in 1..65_536 and :binary.referenced_byte_size(origin) <= 65_536 and
        root_text?(origin)

  defp managed_options?(nil, _, protocol, _) when protocol in [:http2, :h2c], do: false
  defp managed_options?(nil, _, _, _), do: true

  defp managed_options?(
         %{provider: UpstreamTransports, owner: owner, owner_epoch: epoch, resource: resource} =
           handle,
         uri,
         protocol,
         options
       )
       when protocol in [:http1, :http2, :h2c] and map_size(handle) == 4 and is_pid(owner) and
              is_reference(epoch) and
              is_reference(resource) do
    (protocol == :http1 or
       (protocol == :http2 and uri.scheme == "https") or
       (protocol == :h2c and uri.scheme == "http")) and
      is_binary(uri.host) and byte_size(uri.host) in 1..253 and
      is_integer(uri.port) and
      root_authority?(uri.authority, uri.host, uri.port) and
      is_nil(options[:cacertfile]) and is_nil(options[:connect_address])
  end

  defp managed_options?(_, _, _, _), do: false

  defp root_authority?(authority, host, port) when is_binary(authority) do
    host = if String.contains?(host, ":"), do: "[" <> host <> "]", else: host
    prefix = host <> ":"

    cond do
      authority == host ->
        true

      String.starts_with?(authority, prefix) ->
        suffix =
          binary_part(authority, byte_size(prefix), byte_size(authority) - byte_size(prefix))

        String.trim_leading(suffix, "0") == Integer.to_string(port)

      true ->
        false
    end
  end

  defp root_authority?(_, _, _), do: false
  defp root_text?(<<>>), do: true

  defp root_text?(<<?%, a, b, rest::binary>>),
    do: root_hex?(a) and root_hex?(b) and root_text?(rest)

  defp root_text?(<<?%, _::binary>>), do: false

  defp root_text?(<<char, rest::binary>>) when char in 33..126 and char not in [?#, ?\\],
    do: root_text?(rest)

  defp root_text?(_), do: false
  defp root_hex?(char), do: char in ?0..?9 or char in ?a..?f or char in ?A..?F

  @doc false
  def selected_client(%{group: %{execution_profile: :managed_h2}}), do: ManagedH2Client

  def selected_client(%{group: _}), do: HTTPFetchClient

  def selected_client(%__MODULE__{upstream_protocol: :http1, client: HTTPFetchClient}),
    do: HTTPFetchClient

  def selected_client(%__MODULE__{upstream_protocol: :http3, client: HTTP3SessionClient}),
    do: HTTP3SessionClient

  def selected_client(%__MODULE__{upstream_protocol: protocol, client: ManagedH2Client})
      when protocol in [:http2, :h2c],
      do: ManagedH2Client

  @impl true
  def generation_validate(%__MODULE__{upstream_protocol: protocol})
      when protocol in [:http2, :h2c],
      do: {:error, :unsupported_generation_endpoint}

  def generation_validate(_), do: :ok

  defp protocol_client(:http1), do: HTTPFetchClient
  defp protocol_client(:http3), do: HTTP3SessionClient
  defp protocol_client(protocol) when protocol in [:http2, :h2c], do: ManagedH2Client

  defp compact_uri(uri) do
    Map.new(Map.to_list(uri), fn {key, value} ->
      {key, if(is_binary(value), do: :binary.copy(value), else: value)}
    end)
  end

  @doc false
  def group_limits(options) when is_map(options) do
    limits = Map.merge(@defaults, options)

    if Map.keys(options) -- Map.keys(@defaults) == [] and
         Enum.all?(limits, fn {_, value} -> is_integer(value) and value > 0 end) and
         limits.max_chunk_bytes <= 65_536,
       do: {:ok, limits},
       else: {:error, :invalid_group_endpoint_options}
  end

  def group_limits(_), do: {:error, :invalid_group_endpoint_options}

  @doc false
  def unavailable(exchange), do: error_response(exchange, 503)

  defp connect_address(nil), do: {:ok, nil}
  defp connect_address(address), do: Gaoxy.Proxy.DestinationPolicy.normalize_address(address)

  @impl true
  def call(exchange, %__MODULE__{transport: transport} = config) when not is_nil(transport) do
    case exchange.resource_pins do
      [] ->
        call_fixed(exchange, config, transport)

      pins ->
        if captured_resources?(pins, [transport]),
          do: dispatch_request(exchange, config),
          else: error_response(exchange, 503)
    end
  end

  def call(exchange, config), do: dispatch_request(exchange, config)

  @doc false
  def captured_resources?(pins, handles) when is_list(pins) and length(pins) <= 64 do
    :erlang.external_size(pins) <= 65_536 and
      Enum.all?(handles, fn handle -> Enum.any?(pins, &captured_pin?(&1, handle)) end)
  end

  def captured_resources?(_, _), do: false

  defp captured_pin?(
         %{
           provider: provider,
           owner: owner,
           owner_epoch: epoch,
           operation: operation,
           ref: ref,
           handles: handles,
           kind: :request
         } = pin,
         %{provider: provider, owner: owner, owner_epoch: epoch} = handle
       )
       when is_reference(operation) and is_reference(ref) and is_list(handles) do
    length(handles) <= 64 and handle in handles and
      case provider do
        UpstreamTransports -> map_size(pin) == 8 and Map.get(pin, :holder) == self()
        Gaoxy.Proxy.UpstreamGroups -> map_size(pin) == 7
        _ -> false
      end
  end

  defp captured_pin?(_, _), do: false

  defp call_fixed(exchange, config, transport) do
    case Resources.pin_many([transport], self(), :request, exchange.deadline) do
      {:ok, pins} ->
        try do
          dispatch_request(exchange, config)
        after
          case Resources.release(pins) do
            :ok -> :ok
            {:error, reason} -> exit({:transport_pin_release_failed, reason})
          end
        end

      {:error, _} ->
        error_response(exchange, 503)
    end
  end

  defp dispatch_request(exchange, config) do
    client = selected_client(config)

    with true <- client.host_supported?() || {:error, :unsupported_http_proxy_host},
         true <-
           exchange.request.target_form in [:origin, :absolute] || {:error, :unsupported_target},
         {:ok, method} <- method(exchange.request.method),
         {:ok, headers, policy} <- Headers.request(exchange),
         {:ok, session, monitor, deadline, handoff} <-
           start_session(exchange, config, method, headers, policy) do
      pump(pump_state(exchange, config, client, policy, session, monitor, deadline, handoff))
    else
      {:error, :unsupported_target} ->
        error_response(exchange, 501)

      {:error, :unsupported_method} ->
        error_response(exchange, 501)

      {:error, reason}
      when reason in [
             :invalid_proxy_headers,
             :invalid_proxy_trailers,
             :proxy_trailer_limit,
             :proxy_header_limit,
             :invalid_request
           ] ->
        invalid_request_response(exchange, config)

      _ ->
        error_response(exchange, 503)
    end
  end

  defp method(method) do
    case Map.fetch(@methods, method) do
      {:ok, atom} -> {:ok, atom}
      :error -> {:error, :unsupported_method}
    end
  end

  defp start_session(
         exchange,
         %{group: %{execution_profile: :managed_h2}} = config,
         method,
         headers,
         policy
       ) do
    startup = ManagedH2GroupAccounting.startup_bytes()

    with :ok <-
           ManagedH2GroupAccounting.validate(
             {:control, :admission},
             {:adjust_bytes, exchange.lease, startup}
           ),
         :ok <- Gaoxy.Admission.adjust_bytes(exchange.gate, exchange.lease, startup) do
      # This caller owns the lease. The args-owning frame must have returned
      # before its temporary startup allowance can be refunded.
      result = start_group_session(exchange, config, method, headers, policy)

      case result do
        {:startup_cleanup_unconfirmed, reason} ->
          {:error, reason}

        result ->
          case Gaoxy.Admission.adjust_bytes(exchange.gate, exchange.lease, -startup) do
            :ok -> result
            {:error, reason} -> {:error, reason}
          end
      end
    end
  end

  defp start_session(exchange, config, method, headers, policy) do
    with {:ok, request_options} <- request_options(exchange, config, method, headers, policy) do
      start_prepared_session(exchange, config, headers, request_options)
    end
  end

  defp start_group_session(exchange, config, method, headers, policy) do
    with {:ok, neutral} <- group_request_options(exchange, config, method, headers, policy),
         :ok <- ManagedH2GroupAccounting.validate(:neutral, neutral) do
      start_prepared_session(exchange, config, headers, neutral, policy)
    end
  end

  defp group_request_options(exchange, config, method, fields, policy) do
    request = exchange.request

    query =
      if is_binary(request.target) and String.contains?(request.target, "?"),
        do: request.query_string,
        else: nil

    with true <- bounded_source?(request.target) and bounded_source?(request.path),
         true <- query == nil or bounded_source?(query),
         true <- signed_time?(exchange.deadline) and exchange.deadline <= @signed_max - 1_000,
         true <- signed_time?(Lifecycle.now() + config.limits.max_lifetime),
         target_bytes =
           byte_size(request.path) + if(query == nil, do: 0, else: byte_size(query) + 1),
         true <- config.group.max_url_bytes + target_bytes <= 65_536,
         target =
           if(request.target_form == :absolute,
             do: request.path <> if(query == nil, do: "", else: "?" <> query),
             else: request.target
           ),
         source = %{
           target: target,
           method: method,
           fields: fields,
           body_mode:
             if(policy.allowed != [] and request.version in [:"HTTP/2", :"HTTP/3"],
               do: :chunked,
               else: request.body
             ),
           request_limits: %{
             max_headers: min(Map.get(exchange.limits, :max_headers, 256), 256),
             max_header_bytes: min(exchange.limits.max_header_bytes, 65_536),
             max_trailers: min(exchange.limits.max_trailers, 128),
             max_trailer_bytes: min(exchange.limits.max_trailer_bytes, 65_536)
           },
           max_upload_bytes: config.limits.max_chunk_bytes
         },
         :ok <- ManagedH2Envelope.validate_group_source(source) do
      {:ok,
       %{
         source
         | target: :binary.copy(target),
           fields:
             Enum.map(fields, fn {key, value} -> {:binary.copy(key), :binary.copy(value)} end)
       }}
    else
      _ -> {:error, :invalid_request}
    end
  end

  defp request_options(
         exchange,
         %__MODULE__{upstream_protocol: protocol} = config,
         method,
         fields,
         policy
       )
       when protocol in [:http2, :h2c] do
    request = exchange.request

    query =
      if is_binary(request.target) and String.contains?(request.target, "?"),
        do: request.query_string,
        else: nil

    with true <- bounded_source?(request.target) and bounded_source?(request.path),
         true <- query == nil or bounded_source?(query),
         true <- signed_time?(exchange.deadline) and exchange.deadline <= @signed_max - 1_000,
         true <- signed_time?(Lifecycle.now() + config.limits.max_lifetime),
         target_bytes =
           byte_size(request.path) + if(query == nil, do: 0, else: byte_size(query) + 1),
         true <-
           target_bytes <= 65_536 and
             byte_size(URI.to_string(config.uri)) + target_bytes <= 65_536,
         target =
           if(request.target_form == :absolute,
             do: request.path <> if(query == nil, do: "", else: "?" <> query),
             else: request.target
           ),
         # These URL/absolute-target values are our bounded assembly workspace,
         # not caller subbinaries; compact them only after the source preflight.
         target = if(request.target_form == :absolute, do: :binary.copy(target), else: target),
         url = :binary.copy(URI.to_string(%{config.uri | path: request.path, query: query})),
         source = %{
           url: url,
           target: target,
           method: method,
           fields: fields,
           body_mode:
             if(policy.allowed != [] and request.version in [:"HTTP/2", :"HTTP/3"],
               do: :chunked,
               else: request.body
             ),
           request_limits: %{
             max_headers: min(Map.get(exchange.limits, :max_headers, 256), 256),
             max_header_bytes: min(exchange.limits.max_header_bytes, 65_536),
             max_trailers: min(exchange.limits.max_trailers, 128),
             max_trailer_bytes: min(exchange.limits.max_trailer_bytes, 65_536)
           },
           max_upload_bytes: config.limits.max_chunk_bytes
         },
         {:ok, envelope} <- ManagedH2Envelope.prepare(config, source) do
      {:ok, envelope}
    else
      _ -> {:error, :invalid_request}
    end
  end

  defp request_options(exchange, config, method, headers, policy) do
    query =
      if String.contains?(exchange.request.target, "?"),
        do: exchange.request.query_string,
        else: nil

    {:ok,
     %{
       method: method,
       headers: headers,
       body:
         if(policy.allowed != [] and exchange.request.version in [:"HTTP/2", :"HTTP/3"],
           do: :chunked,
           else: exchange.request.body
         ),
       path: exchange.request.path,
       query: query,
       limits: exchange.limits,
       max_upload_bytes: config.limits.max_chunk_bytes
     }}
  end

  defp bounded_source?(value) when is_binary(value),
    do: byte_size(value) <= 65_536 and :binary.referenced_byte_size(value) <= 65_536

  defp bounded_source?(_), do: false

  defp signed_time?(value),
    do: is_integer(value) and value >= @signed_min and value <= @signed_max

  defp start_prepared_session(exchange, config, headers, request_options, policy \\ nil) do
    query =
      if String.contains?(exchange.request.target, "?"),
        do: exchange.request.query_string,
        else: nil

    started_at = Lifecycle.now()
    deadline = min(exchange.deadline, started_at + config.limits.max_lifetime)

    handles =
      case config do
        %{group: group} ->
          Gaoxy.Proxy.UpstreamGroups.resources(group)
          |> Enum.filter(&(&1.provider == UpstreamTransports))

        %__MODULE__{transport: nil} ->
          []

        %__MODULE__{transport: transport} ->
          [transport]
      end

    handoff =
      if handles != [] and exchange.resource_pins != [] do
        %{
          ref: make_ref(),
          handles: handles,
          source_pins:
            Enum.filter(exchange.resource_pins, &match?(%{provider: UpstreamTransports}, &1)),
          used: false
        }
      end

    selector =
      case config do
        %{group: handle} ->
          {:group, handle,
           Enum.filter(
             exchange.resource_pins,
             &match?(%{provider: Gaoxy.Proxy.UpstreamGroups}, &1)
           )}

        _ ->
          {:fixed, config}
      end

    args = %{
      owner: self(),
      service: exchange.service,
      instance: exchange.instance,
      gate: exchange.gate,
      started_at: started_at,
      deadline: deadline,
      config: config,
      selector: selector,
      transport_handoff: if(handoff, do: handoff.ref),
      request_options: request_options
    }

    url_bytes =
      case selector do
        {:fixed, %{upstream_protocol: protocol}} when protocol in [:http2, :h2c] ->
          byte_size(request_options.url)

        {:group, handle, _} ->
          handle.max_url_bytes + byte_size(exchange.request.path) +
            if(query == nil, do: 0, else: byte_size(query) + 1)

        {:fixed, fixed} ->
          byte_size(URI.to_string(%{fixed.uri | path: exchange.request.path, query: query}))
      end

    client = selected_client(config)
    group? = match?(%{group: %{execution_profile: :managed_h2}}, config)

    reserve =
      if group?,
        do: ManagedH2GroupAccounting.reservation_bytes(),
        else: client.reservation_bytes(headers, url_bytes, config.limits.max_chunk_bytes)

    with :ok <-
           validate_group_startup(
             group?,
             args,
             pump_state(exchange, config, client, policy, nil, nil, deadline, handoff)
           ),
         {:ok, session} <-
           DynamicSupervisor.start_child(Gaoxy.Proxy.SessionSupervisor, {Session, args}) do
      with :ok <- preflight_started_session(group?, session) do
        monitor = Process.monitor(session)

        attachment =
          with :ok <-
                 account_control(
                   config,
                   :admission,
                   {:attach_cleanup, exchange.gate, exchange.lease, session, reserve,
                    exchange.deadline}
                 ) do
            Gaoxy.Service.attach_cleanup(
              exchange.service,
              exchange.gate,
              exchange.lease,
              session,
              reserve,
              exchange.deadline
            )
          end

        case attachment do
          {:ok, _token} ->
            {:ok, session, monitor, deadline, handoff}

          error ->
            Session.cancel(session)

            if group? do
              # A denied attachment leaves an inactive child. An ambiguous late
              # attachment remains covered by Service's genuine cleanup record.
              receive do
                {:DOWN, ^monitor, :process, ^session, _} -> error
              after
                Lifecycle.remaining(
                  min(
                    exchange.deadline + Lifecycle.cleanup_headroom(),
                    Lifecycle.deadline(Lifecycle.cleanup_headroom())
                  )
                ) ->
                  # Killing a child after cancellation cannot erase the Service
                  # ledger; an unconfirmed cleanup remains held by its owners.
                  joined = Lifecycle.terminate_resources([session], Lifecycle.deadline(1_000))
                  Process.demonitor(monitor, [:flush])

                  case joined do
                    :ok ->
                      error

                    {:error, reason} ->
                      # An unjoined child is not a cleanup receipt. Prevent new
                      # admissions before this request owner can leave its lease.
                      # Do not report lease bytes as retained after owner DOWN.
                      drain =
                        Lifecycle.protect(fn ->
                          Gaoxy.Admission.drain(exchange.gate, Lifecycle.now())
                        end)

                      case drain do
                        :ok ->
                          :ok

                        _ ->
                          # If admission cannot acknowledge draining, join the
                          # real gate termination before this caller can leave.
                          # Service observes gate loss and closes its transport.
                          :ok =
                            Lifecycle.terminate_resources(
                              [exchange.gate],
                              Lifecycle.deadline(1_000)
                            )
                      end

                      {:startup_cleanup_unconfirmed, reason}
                  end
              end
            else
              Process.demonitor(monitor, [:flush])
              error
            end
        end
      else
        error ->
          :ok = Lifecycle.terminate_resources([session], Lifecycle.deadline(1_000))
          error
      end
    end
  end

  defp preflight_started_session(false, _session), do: :ok

  defp preflight_started_session(true, session),
    do: ManagedH2GroupAccounting.preflight_control(:monitor, session)

  defp validate_group_startup(false, _, _), do: :ok

  defp validate_group_startup(true, args, pump) do
    with :ok <- ManagedH2GroupAccounting.validate(:captured_pins, pump.exchange.resource_pins),
         :ok <- ManagedH2GroupAccounting.validate(:pump, pump),
         {:ok, _} <- ManagedH2GroupAccounting.startup(Session, args),
         :ok <- ManagedH2GroupAccounting.preflight_control(:local_monitor, node()) do
      :ok
    end
  end

  defp pump_state(exchange, config, client, policy, session, monitor, deadline, handoff) do
    %{
      exchange: %{
        exchange
        | deadline: deadline,
          limits: %{
            exchange.limits
            | write_timeout: min(exchange.limits.write_timeout, config.limits.write_timeout)
          }
      },
      config: config,
      client: client,
      policy: policy,
      response_policy: nil,
      session: session,
      monitor: monitor,
      deadline: deadline,
      transport_handoff: handoff,
      upload: nil,
      ready: false,
      upload_stopped: false,
      last_activity: Lifecycle.now()
    }
  end

  defp pump(state, wait \\ 0) do
    if match?(%{group: %{execution_profile: :managed_h2}}, state.config) do
      case ManagedH2GroupAccounting.validate(:pump, state) do
        :ok -> pump_wait(state, wait)
        {:error, _} -> fail(state, :invalid_request)
      end
    else
      pump_wait(state, wait)
    end
  end

  defp pump_wait(state, wait) do
    receive do
      {:gaoxy_proxy_http, session, event} when session == state.session ->
        family =
          case event do
            {:ready, _, _, _} -> :ready
            {:transport_handoff, _, _, _, _} -> :handoff_request
            _ -> :delivery
          end

        case account_control(state.config, family, {:gaoxy_proxy_http, session, event}) do
          :ok ->
            if total_expired?(state) and not match?({:error, _}, event),
              do: timeout(state),
              else: dispatch(event, state)

          {:error, _} ->
            fail(state, :invalid_request)
        end

      {:DOWN, monitor, :process, _, reason} when monitor == state.monitor ->
        fail(state, {:guardian_down, reason})

      {:gaoxy_drain, gate, lease, deadline}
      when gate == state.exchange.gate and lease == state.exchange.lease ->
        deadline = min(state.deadline, deadline)
        pump(%{state | deadline: deadline, exchange: %{state.exchange | deadline: deadline}})
    after
      wait -> progress(state, wait > 0)
    end
  end

  defp progress(state, idle_wait_expired) do
    remaining = remaining(state)

    cond do
      remaining <= 0 ->
        timeout(state)

      state.ready and not state.upload_stopped and Exchange.body_complete?(state.exchange) ->
        finish_upload(state)

      state.ready and not state.upload_stopped ->
        read_upload(state, min(@poll_ms, remaining))

      true ->
        # Passive TLS needs a waiting receive to settle an abrupt transport close.
        # Give it a finite turn only after idle, keeping data deliveries on poll0.
        poll_wait =
          if idle_wait_expired and state.exchange.transport == nil and
               Exchange.secure?(state.exchange),
             do: min(1, remaining),
             else: 0

        case Exchange.poll_connection(state.exchange, poll_wait) do
          {kind, exchange} when kind in [:pending, :more] ->
            pump(%{state | exchange: exchange}, min(@poll_ms, remaining(state)))

          {:error, reason, exchange} ->
            local_fail(%{state | exchange: exchange}, reason)
        end
    end
  end

  defp remaining(state) do
    min(
      Lifecycle.remaining(state.deadline),
      max(0, state.config.limits.idle_timeout - (Lifecycle.now() - state.last_activity))
    )
  end

  defp read_upload(state, wait) do
    case Exchange.read_body_step(state.exchange, state.config.limits.max_chunk_bytes, wait) do
      {:pending, exchange} ->
        pump(%{state | exchange: exchange})

      {:error, reason, exchange} ->
        local_fail(%{state | exchange: exchange}, reason)

      {kind, bytes, exchange} when kind in [:ok, :more] ->
        state = %{state | exchange: exchange, last_activity: Lifecycle.now()}
        timeout = min(state.config.limits.write_timeout, Lifecycle.remaining(state.deadline))

        result =
          cond do
            timeout <= 0 -> {:error, :timeout}
            bytes == "" -> :ok
            true -> state.client.write_body(state.upload, bytes, timeout)
          end

        case result do
          :ok when kind == :ok ->
            finish_upload(state)

          :ok ->
            pump(state)

          {:error, :timeout} ->
            timeout(state)

          {:error, _} ->
            # An early final response stops the source before its Promise resolves.
            # Wait for that head rather than rewriting a valid response to 502.
            pump(%{state | upload_stopped: true, exchange: %{exchange | close: true}})
        end
    end
  end

  defp finish_upload(state) do
    with {:ok, trailers} <-
           Headers.trailers(Exchange.request_trailers(state.exchange), state.policy),
         :ok <-
           if(is_nil(state.upload),
             do: :ok,
             else: state.client.finish_body(state.upload, trailers)
           ) do
      pump(%{state | upload_stopped: true, policy: nil})
    else
      {:error, reason} -> local_fail(state, reason)
    end
  end

  defp dispatch({:ready, upload, limits, deadline}, state) do
    deadline = min(state.deadline, deadline)

    exchange = %{
      state.exchange
      | deadline: deadline,
        limits: %{
          state.exchange.limits
          | write_timeout: min(state.exchange.limits.write_timeout, limits.write_timeout)
        }
    }

    pump(%{
      state
      | ready: true,
        upload: upload,
        config: %{state.config | limits: limits},
        deadline: deadline,
        exchange: exchange
    })
  end

  defp dispatch(
         {:transport_handoff, ref, handle, identity, deadline},
         %{ready: false, transport_handoff: %{ref: ref, used: false} = handoff} = state
       )
       when is_integer(deadline) do
    if handle in handoff.handles do
      operation = make_ref()
      deadline = min(state.deadline, deadline)
      pin = Enum.find(handoff.source_pins, &captured_pin?(&1, handle))
      state = %{state | transport_handoff: %{handoff | used: true}}

      result =
        with :ok <- account_delegate(state, handle, pin, identity, operation, deadline) do
          UpstreamTransports.delegate_request_pin(
            handle,
            pin,
            state.session,
            identity,
            operation,
            deadline
          )
        end

      result =
        case account_pin_reply(state.config, result) do
          :ok ->
            result

          {:error, _} ->
            UpstreamTransports.cancel(handle.owner, operation)
            {:error, :invalid_resource_pin}
        end

      state = refresh_handoff_deadline(state)

      {result, state} =
        case Exchange.poll_connection(state.exchange, 0) do
          {kind, exchange} when kind in [:pending, :more] ->
            {result, %{state | exchange: exchange}}

          {:error, reason, exchange} ->
            revoke_handoff(handle, operation, result)
            {{:error, reason}, %{state | exchange: exchange}}
        end

      result =
        if Lifecycle.remaining(min(state.deadline, deadline)) > 0 and
             Process.alive?(state.session) do
          result
        else
          revoke_handoff(handle, operation, result)
          {:error, :timeout}
        end

      if match?({:error, _}, result), do: UpstreamTransports.cancel(handle.owner, operation)
      send(state.session, {:gaoxy_transport_handoff, ref, result, state.deadline})
      pump(state)
    else
      pump(state)
    end
  end

  defp dispatch({:transport_handoff, _, _, _, _}, state), do: pump(state)

  defp dispatch({:headers, status, fields}, state) do
    exchange = %{
      state.exchange
      | close: state.exchange.close or not Exchange.body_complete?(state.exchange)
    }

    case Headers.response(exchange, status, fields) do
      {:ok, fields, policy} ->
        case Response.send_chunked(exchange, status, fields) do
          {:ok, exchange} ->
            pump(%{
              state
              | exchange: exchange,
                response_policy: policy,
                upload_stopped: true,
                policy: nil,
                last_activity: Lifecycle.now()
            })

          {:error, :response_header_limit} when exchange.response == :unset ->
            local_fail(%{state | exchange: exchange}, :response_header_limit)

          {:error, reason} ->
            if reason == :timeout and total_expired?(state) do
              timeout(%{state | exchange: exchange})
            else
              Session.cancel(state.session)
              {:error, reason, %{exchange | close: true}}
            end
        end

      {:error, reason} ->
        local_fail(state, reason)
    end
  end

  defp dispatch({:chunk, bytes, ref}, state) do
    case Response.chunk(state.exchange, bytes) do
      :ok ->
        Session.acknowledge(state.session, ref)
        pump(%{state | last_activity: Lifecycle.now()})

      {:ok, exchange} ->
        Session.acknowledge(state.session, ref)
        pump(%{state | exchange: exchange, last_activity: Lifecycle.now()})

      {:error, reason} ->
        local_fail(state, reason)
    end
  end

  defp dispatch({:end, raw_trailers}, state) do
    with {:ok, trailers} <- Headers.trailers(raw_trailers, state.response_policy),
         {:ok, exchange} <- Response.finish(state.exchange, trailers) do
      Session.consumed(state.session)
      await_cleanup(%{state | exchange: exchange})
    else
      {:error, reason} -> local_fail(state, reason)
    end
  end

  defp dispatch({:error, reason}, state), do: fail(state, reason)

  defp refresh_handoff_deadline(state) do
    receive do
      {:gaoxy_drain, gate, lease, deadline}
      when gate == state.exchange.gate and lease == state.exchange.lease ->
        deadline = min(state.deadline, deadline)

        refresh_handoff_deadline(%{
          state
          | deadline: deadline,
            exchange: %{state.exchange | deadline: deadline}
        })
    after
      0 -> state
    end
  end

  defp account_control(%{group: %{execution_profile: :managed_h2}}, family, original),
    do: ManagedH2GroupAccounting.validate({:control, family}, original)

  defp account_control(_, _, _), do: :ok

  defp account_pin_reply(%{group: %{execution_profile: :managed_h2}}, result),
    do: ManagedH2GroupAccounting.validate({:owner_reply, :transport, :pin}, result)

  defp account_pin_reply(_, _), do: :ok

  defp account_delegate(
         %{config: %{group: %{execution_profile: :managed_h2}}} = state,
         handle,
         pin,
         identity,
         operation,
         deadline
       ) do
    uri = URI.parse(identity.origin)

    authority =
      {identity.upstream_protocol, if(uri.scheme == "https", do: :https, else: :http),
       :binary.copy(String.downcase(uri.host)), uri.port}

    ManagedH2GroupAccounting.validate(
      {:owner_call, :transport, :delegate},
      {:delegate_request_pin, handle, pin, state.session, authority, state.exchange.instance,
       operation, deadline}
    )
  end

  defp account_delegate(_, _, _, _, _, _), do: :ok

  defp revoke_handoff(handle, operation, _result) do
    # Cancellation removes even an already granted child by acquirer/operation
    # without waiting on the owner beyond the current handoff deadline.
    UpstreamTransports.cancel(handle.owner, operation)
  end

  defp await_cleanup(state) do
    receive do
      {:DOWN, monitor, :process, _, :normal} when monitor == state.monitor ->
        {:ok, state.exchange}

      {:DOWN, monitor, :process, _, reason} when monitor == state.monitor ->
        {:error, {:guardian_down, reason}, %{state.exchange | close: true}}

      {:gaoxy_proxy_http, session, {:error, reason}} when session == state.session ->
        fail(state, reason)
    after
      Lifecycle.remaining(state.deadline) -> timeout(state)
    end
  end

  defp total_expired?(state),
    do: state.client == HTTP3SessionClient and Lifecycle.remaining(state.deadline) == 0

  defp local_fail(state, :timeout), do: timeout(state)

  defp local_fail(%{client: ManagedH2Client} = state, {:request_error, status, _})
       when status in [400, 413, 431],
       do: fail(state, :invalid_request, status)

  defp local_fail(state, reason), do: fail(state, reason)

  defp timeout(state) do
    if total_expired?(state) do
      Session.expire(state.session)

      deadline =
        min(
          state.deadline + Lifecycle.cleanup_headroom(),
          Lifecycle.now() + Lifecycle.cleanup_headroom()
        )

      receive do
        {:gaoxy_proxy_http, session, {:error, reason}} when session == state.session ->
          fail(state, reason)

        {:DOWN, monitor, :process, session, reason}
        when monitor == state.monitor and session == state.session ->
          fail(state, {:guardian_down, reason})
      after
        Lifecycle.remaining(deadline) -> fail(state, :guardian_expiry_unconfirmed)
      end
    else
      fail(state, :timeout)
    end
  end

  defp fail(state, reason) do
    reason = if state.client == ManagedH2Client, do: Session.finite_reason(reason), else: reason

    status =
      case reason do
        {:request_error, status, _} -> status
        :timeout -> 504
        :request_timeout -> 504
        :unavailable -> 503
        _ -> 502
      end

    fail(state, reason, status)
  end

  defp fail(state, reason, status) do
    Session.cancel(state.session)
    Process.demonitor(state.monitor, [:flush])

    if state.exchange.response == :unset and not total_expired?(state) do
      error_response(state.exchange, status)
    else
      {:error, reason, %{state.exchange | close: true}}
    end
  end

  defp error_response(exchange, code) do
    case Response.send_resp(%{exchange | close: true}, code, [], "") do
      {:ok, exchange} -> {:ok, exchange}
      {:error, reason} -> {:error, reason, %{exchange | close: true}}
    end
  end

  defp invalid_request_response(exchange, %{upstream_protocol: protocol})
       when protocol in [:http2, :h2c] do
    # A malformed request limit cannot also disable its bounded empty rejection.
    limits =
      if is_integer(exchange.limits.max_headers) and exchange.limits.max_headers > 0 and
           is_integer(exchange.limits.max_header_bytes) and exchange.limits.max_header_bytes > 0 do
        exchange.limits
      else
        exchange.limits |> Map.put(:max_headers, 256) |> Map.put(:max_header_bytes, 65_536)
      end

    error_response(%{exchange | limits: limits}, 400)
  end

  defp invalid_request_response(exchange, _config), do: error_response(exchange, 400)
end
