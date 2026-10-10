defmodule Gaoxy.Proxy.HTTP do
  @moduledoc """
  Native HTTP/1 reverse proxy to one fixed HTTP or verified HTTPS authority.

  M2 raw-target acceptance is pending HTTP Fetch #64: the pinned 0.19.0 client
  drops a present empty query delimiter. Its wire regression remains enabled.

  Paths and queries retain their wire escaping. Uploads and raw responses stream
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
  alias Gaoxy.{Lifecycle, Proxy.HTTPFetchClient}
  alias Gaoxy.HTTP.{Exchange, HTTP1.Response}
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
  defstruct [:uri, :cacertfile, :limits]

  @impl true
  def init(%__MODULE__{} = config) do
    if HTTPFetchClient.host_supported?(),
      do: {:ok, config},
      else: {:error, :unsupported_http_proxy_host}
  end

  def init(%{upstream: upstream} = options) when is_binary(upstream) do
    uri = URI.parse(upstream)
    limits = Map.merge(@defaults, Map.take(options, Map.keys(@defaults)))

    with true <- Map.keys(options) -- [:upstream, :cacertfile | Map.keys(@defaults)] == [],
         true <- uri.scheme in ["http", "https"] and is_binary(uri.host) and uri.host != "",
         true <- is_integer(uri.port) and uri.port in 1..65_535,
         true <-
           uri.userinfo == nil and uri.path in [nil, "", "/"] and uri.query == nil and
             uri.fragment == nil,
         true <- Enum.all?(limits, fn {_, value} -> is_integer(value) and value > 0 end),
         true <- limits.max_chunk_bytes <= 65_536,
         true <-
           is_nil(options[:cacertfile]) or
             (is_binary(options[:cacertfile]) and File.regular?(options[:cacertfile])),
         true <- HTTPFetchClient.host_supported?() do
      {:ok,
       %__MODULE__{uri: %{uri | path: nil}, cacertfile: options[:cacertfile], limits: limits}}
    else
      _ -> {:error, :invalid_http_proxy_options}
    end
  rescue
    ArgumentError -> {:error, :invalid_http_proxy_options}
  end

  def init(_), do: {:error, :invalid_http_proxy_options}

  @impl true
  def call(exchange, config) do
    with true <- HTTPFetchClient.host_supported?() || {:error, :unsupported_http_proxy_host},
         true <-
           exchange.request.target_form in [:origin, :absolute] || {:error, :unsupported_target},
         {:ok, method} <- method(exchange.request.method),
         {:ok, headers, policy} <- Headers.request(exchange),
         {:ok, session, monitor, deadline} <- start_session(exchange, config, method, headers) do
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

  defp start_session(exchange, config, method, headers) do
    query =
      if String.contains?(exchange.request.target, "?"),
        do: exchange.request.query_string,
        else: nil

    # TODO(upstream): gsmlg-dev/http_fetch#64 - preserve the present empty query on the wire.
    url = URI.to_string(%{config.uri | path: exchange.request.path, query: query})
    deadline = min(exchange.deadline, Lifecycle.deadline(config.limits.max_lifetime))

    request_options = %{
      url: url,
      method: method,
      headers: headers,
      body: exchange.request.body,
      opening_timeout: config.limits.opening_timeout,
      write_timeout: config.limits.write_timeout,
      cacertfile: config.cacertfile
    }

    args = %{
      owner: self(),
      service: exchange.service,
      instance: exchange.instance,
      gate: exchange.gate,
      deadline: deadline,
      config: config,
      request_options: request_options
    }

    reserve = HTTPFetchClient.reservation(headers, url, config.limits.max_chunk_bytes)

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

  defp pump(state) do
    receive do
      {:gaoxy_proxy_http, session, event} when session == state.session ->
        dispatch(event, state)

      {:DOWN, monitor, :process, _, reason} when monitor == state.monitor ->
        fail(state, {:guardian_down, reason})

      {:gaoxy_drain, gate, lease, deadline}
      when gate == state.exchange.gate and lease == state.exchange.lease ->
        deadline = min(state.deadline, deadline)
        pump(%{state | deadline: deadline, exchange: %{state.exchange | deadline: deadline}})
    after
      0 -> progress(state)
    end
  end

  defp progress(state) do
    remaining =
      min(
        Lifecycle.remaining(state.deadline),
        max(0, state.config.limits.idle_timeout - (Lifecycle.now() - state.last_activity))
      )

    cond do
      remaining <= 0 ->
        fail(state, :timeout)

      state.ready and not state.upload_stopped and state.exchange.body.phase != :done ->
        read_upload(state, min(@poll_ms, remaining))

      true ->
        case Exchange.poll_connection(state.exchange, min(@poll_ms, remaining)) do
          {:pending, exchange} -> pump(%{state | exchange: exchange})
          {:more, exchange} -> pump(%{state | exchange: exchange})
          {:error, reason, exchange} -> fail(%{state | exchange: exchange}, reason)
        end
    end
  end

  defp read_upload(state, wait) do
    case Exchange.read_body_step(state.exchange, state.config.limits.max_chunk_bytes, wait) do
      {:pending, exchange} ->
        pump(%{state | exchange: exchange})

      {:error, reason, exchange} ->
        fail(%{state | exchange: exchange}, reason)

      {kind, bytes, exchange} when kind in [:ok, :more] ->
        state = %{state | exchange: exchange, last_activity: Lifecycle.now()}
        timeout = min(state.config.limits.write_timeout, Lifecycle.remaining(state.deadline))

        result =
          cond do
            timeout <= 0 -> {:error, :timeout}
            bytes == "" -> :ok
            true -> HTTPFetchClient.write_body(state.upload, bytes, timeout)
          end

        case result do
          :ok when kind == :ok ->
            with {:ok, trailers} <- Headers.trailers(exchange.body.trailers, state.policy),
                 :ok <- HTTPFetchClient.finish_body(state.upload, trailers) do
              pump(%{state | upload_stopped: true})
            else
              {:error, reason} -> fail(state, reason)
            end

          :ok ->
            pump(state)

          {:error, :timeout} when timeout <= 0 ->
            fail(state, :timeout)

          {:error, _} ->
            # An early final response stops the source before its Promise resolves.
            # Wait for that head rather than rewriting a valid response to 502.
            pump(%{state | upload_stopped: true, exchange: %{exchange | close: true}})
        end
    end
  end

  defp dispatch({:ready, upload}, state), do: pump(%{state | ready: true, upload: upload})

  defp dispatch({:headers, status, fields}, state) do
    exchange = %{
      state.exchange
      | close: state.exchange.close or state.exchange.body.phase != :done
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
            Session.cancel(state.session)
            {:error, reason, %{exchange | close: true}}
        end

      {:error, reason} ->
        fail(state, reason)
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
        fail(state, reason)
    end
  end

  defp dispatch({:end, raw_trailers}, state) do
    with {:ok, trailers} <- Headers.trailers(raw_trailers, state.response_policy),
         {:ok, exchange} <- Response.finish(state.exchange, trailers) do
      Session.consumed(state.session)
      await_cleanup(%{state | exchange: exchange})
    else
      {:error, reason} -> fail(state, reason)
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
      Lifecycle.remaining(state.deadline) -> fail(state, :timeout)
    end
  end

  defp fail(state, reason) do
    Session.cancel(state.session)
    Process.demonitor(state.monitor, [:flush])

    if state.exchange.response == :unset do
      status =
        case reason do
          {:request_error, status, _} -> status
          :timeout -> 504
          :request_timeout -> 504
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
