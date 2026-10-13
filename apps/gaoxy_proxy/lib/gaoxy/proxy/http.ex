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
  alias Gaoxy.Proxy.{HTTPFetchClient, HTTP3SessionClient}
  alias Gaoxy.HTTP.{Exchange, Response}
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
  defstruct [
    :uri,
    :cacertfile,
    :connect_address,
    :limits,
    upstream_protocol: :http1,
    client: HTTPFetchClient
  ]

  @impl true
  def init(%__MODULE__{} = config) do
    with true <- Map.keys(config) -- Map.keys(%__MODULE__{}) == [],
         true <- is_struct(config.uri, URI) and is_map(config.limits),
         options =
           Map.merge(config.limits, %{
             upstream: URI.to_string(config.uri),
             upstream_protocol: config.upstream_protocol,
             cacertfile: config.cacertfile,
             connect_address: config.connect_address
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
    uri = URI.parse(upstream)
    protocol = Map.get(options, :upstream_protocol, :http1)
    chunk_limit = if protocol == :http3, do: 16_384, else: 65_536

    limits =
      Map.merge(
        %{@defaults | max_chunk_bytes: chunk_limit},
        Map.take(options, Map.keys(@defaults))
      )

    with true <-
           Map.keys(options) --
             [:upstream, :upstream_protocol, :cacertfile, :connect_address | Map.keys(@defaults)] ==
             [],
         true <- protocol in [:http1, :http3],
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
         client = if(protocol == :http3, do: HTTP3SessionClient, else: HTTPFetchClient),
         true <- client.host_supported?() do
      uri = URI.parse(URI.to_string(%{uri | path: nil}))

      {:ok,
       %__MODULE__{
         uri: uri,
         cacertfile: options[:cacertfile],
         connect_address: address,
         limits: limits,
         upstream_protocol: protocol,
         client: client
       }}
    else
      _ -> {:error, :invalid_http_proxy_options}
    end
  rescue
    ArgumentError -> {:error, :invalid_http_proxy_options}
  end

  def init(_), do: {:error, :invalid_http_proxy_options}

  @doc false
  def selected_client(%{group: _}), do: HTTPFetchClient

  def selected_client(%__MODULE__{upstream_protocol: :http1, client: HTTPFetchClient}),
    do: HTTPFetchClient

  def selected_client(%__MODULE__{upstream_protocol: :http3, client: HTTP3SessionClient}),
    do: HTTP3SessionClient

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
  def call(exchange, config) do
    client = selected_client(config)

    with true <- client.host_supported?() || {:error, :unsupported_http_proxy_host},
         true <-
           exchange.request.target_form in [:origin, :absolute] || {:error, :unsupported_target},
         {:ok, method} <- method(exchange.request.method),
         {:ok, headers, policy} <- Headers.request(exchange),
         {:ok, session, monitor, deadline} <-
           start_session(exchange, config, method, headers, policy) do
      pump(%{
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
        upload: nil,
        ready: false,
        upload_stopped: false,
        last_activity: Lifecycle.now()
      })
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
             :proxy_header_limit
           ] ->
        error_response(exchange, 400)

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

  defp start_session(exchange, config, method, headers, policy) do
    query =
      if String.contains?(exchange.request.target, "?"),
        do: exchange.request.query_string,
        else: nil

    started_at = Lifecycle.now()
    deadline = min(exchange.deadline, started_at + config.limits.max_lifetime)

    selector =
      case config do
        %{group: handle} -> {:group, handle, exchange.resource_pins}
        _ -> {:fixed, config}
      end

    request_options = %{
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
    }

    args = %{
      owner: self(),
      service: exchange.service,
      instance: exchange.instance,
      gate: exchange.gate,
      started_at: started_at,
      deadline: deadline,
      config: config,
      selector: selector,
      request_options: request_options
    }

    url_bytes =
      case selector do
        {:group, handle, _} ->
          handle.max_url_bytes + byte_size(exchange.request.path) +
            if(query == nil, do: 0, else: byte_size(query) + 1)

        {:fixed, fixed} ->
          byte_size(URI.to_string(%{fixed.uri | path: exchange.request.path, query: query}))
      end

    client = selected_client(config)
    reserve = client.reservation_bytes(headers, url_bytes, config.limits.max_chunk_bytes)

    with {:ok, session} <-
           DynamicSupervisor.start_child(Gaoxy.Proxy.SessionSupervisor, {Session, args}) do
      monitor = Process.monitor(session)

      case Gaoxy.Service.attach_cleanup(
             exchange.service,
             exchange.gate,
             exchange.lease,
             session,
             reserve,
             exchange.deadline
           ) do
        {:ok, _token} ->
          {:ok, session, monitor, deadline}

        error ->
          Session.cancel(session)
          Process.demonitor(monitor, [:flush])
          error
      end
    end
  end

  defp pump(state, wait \\ 0) do
    receive do
      {:gaoxy_proxy_http, session, event} when session == state.session ->
        if total_expired?(state) and not match?({:error, _}, event),
          do: timeout(state),
          else: dispatch(event, state)

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
      pump(%{state | upload_stopped: true})
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
                last_activity: Lifecycle.now()
            })

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
    Session.cancel(state.session)
    Process.demonitor(state.monitor, [:flush])

    if state.exchange.response == :unset and not total_expired?(state) do
      status =
        case reason do
          {:request_error, status, _} -> status
          :timeout -> 504
          :request_timeout -> 504
          :unavailable -> 503
          _ -> 502
        end

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
end
