defmodule Gaoxy.Server.Config do
  @moduledoc "Version 1 JSON configuration. Handlers and keys use explicit allowlists; input creates no atoms."
  @handlers %{
    "stream_echo" => Gaoxy.Server.StreamEcho,
    "datagram_echo" => Gaoxy.Server.DatagramEcho,
    "http" => Gaoxy.HTTP.Connection,
    "http3" => Gaoxy.HTTP.HTTP3.Connection
  }
  @service_keys %{"id" => :id, "port" => :port, "handler_options" => :handler_options}
  @limits ~w(max_active max_bytes max_packet max_output max_state callback_timeout idle_timeout drain_timeout max_memberships)a
  @http_limits ~w(max_request_line max_header_bytes max_headers max_body_bytes max_chunk_line max_trailer_bytes max_trailers max_read_chunk max_buffer_bytes request_timeout header_timeout read_timeout write_timeout)a
  @h2_limits ~w(max_streams max_frame max_header_block table_size receive_window frame_timeout control_turn control_rate)a
  @h3_limits ~w(max_streams max_header_block max_pending_output control_turn control_quantum dynamic_table_capacity blocked_streams)a
  @max_bytes 1_048_576

  def load(path) do
    with {:ok, bytes} <- read_file(path),
         {:ok, data} <- JSON.decode(bytes),
         {:ok, options} <- decode(data),
         {:ok, _} <- Gaoxy.Config.validate(options) do
      {:ok, options}
    end
  end

  @doc false
  def read_file(path) do
    with {:ok, %File.Stat{type: :regular, size: size}} <- File.stat(path),
         true <- size <= @max_bytes || {:error, :configuration_too_large},
         {:ok, file} <- :file.open(path, [:read, :binary, :raw]) do
      try do
        case :file.read(file, @max_bytes + 1) do
          {:ok, bytes} when byte_size(bytes) <= @max_bytes -> {:ok, bytes}
          {:ok, _} -> {:error, :configuration_too_large}
          :eof -> {:ok, ""}
          error -> error
        end
      after
        :file.close(file)
      end
    else
      {:ok, %File.Stat{}} -> {:error, :invalid_configuration_file}
      {:error, _} = error -> error
    end
  end

  def decode(%{"version" => 1, "services" => services} = data) when is_list(services) do
    with :ok <- keys(data, ["version", "services"]),
         {:ok, specs} <- traverse(services, &service/1) do
      {:ok, [services: specs]}
    end
  end

  def decode(_), do: {:error, :invalid_configuration_version_or_shape}

  defp service(data) when is_map(data) do
    http_keys =
      case data["handler"] do
        "http" -> ["routes", "protocols", "h2c", "http_limits", "h2_limits"]
        "http3" -> ["routes", "protocols", "http_limits", "h3_limits"]
        _ -> []
      end

    with :ok <-
           keys(
             data,
             http_keys ++
               [
                 "id",
                 "transport",
                 "handler",
                 "handler_options",
                 "ip",
                 "port",
                 "mode",
                 "limits",
                 "tls",
                 "udp"
               ]
           ),
         {:ok, transport} <-
           enum(data["transport"], %{"tcp" => :tcp, "tls" => :tls, "udp" => :udp, "quic" => :quic}),
         {:ok, handler} <- enum(data["handler"], @handlers),
         {:ok, ip} <- address(Map.get(data, "ip", "127.0.0.1")),
         {:ok, mode} <-
           enum(Map.get(data, "mode", "unicast"), %{
             "unicast" => :unicast,
             "broadcast" => :broadcast,
             "multicast" => :multicast
           }),
         {:ok, limits} <-
           named(Map.get(data, "limits", %{}), Map.new(@limits, &{Atom.to_string(&1), &1})),
         {:ok, tls} <- tls(Map.get(data, "tls", %{})),
         {:ok, udp} <- udp(Map.get(data, "udp", %{})) do
      base =
        Map.new(Map.take(data, Map.keys(@service_keys)), fn {key, value} ->
          {@service_keys[key], value}
        end)

      spec =
        Map.merge(base, %{
          transport: transport,
          handler: handler,
          ip: ip,
          mode: mode,
          limits: limits,
          tls: tls,
          udp: udp
        })

      case handler do
        Gaoxy.HTTP.Connection -> http_service(data, spec)
        Gaoxy.HTTP.HTTP3.Connection -> http3_service(data, spec)
        _ -> {:ok, spec}
      end
    end
  end

  defp service(_), do: {:error, :invalid_service}

  defp http3_service(data, spec) do
    with true <-
           (data["protocols"] == ["http3"] and spec.mode == :unicast and
              not Map.has_key?(data, "handler_options") and not Map.has_key?(data, "udp")) ||
             {:error, :invalid_http3_options},
         true <-
           (is_binary(spec[:id]) and byte_size(spec.id) in 1..128) ||
             {:error, :invalid_identity_or_binding},
         {:ok, routes} <- Gaoxy.Server.RouteConfig.decode(data["routes"]),
         {:ok, router} <- Gaoxy.HTTP.Router.compile(routes),
         :ok <-
           Gaoxy.HTTP.Generation.Store.compiled_bound(router, %{
             max_routes: 1024,
             max_config_bytes: @max_bytes
           }),
         {:ok, http_limits} <-
           named(
             Map.get(data, "http_limits", %{}),
             Map.new(@http_limits, &{Atom.to_string(&1), &1})
           ),
         {:ok, h3_limits} <-
           named(Map.get(data, "h3_limits", %{}), Map.new(@h3_limits, &{Atom.to_string(&1), &1})),
         options = Map.take(spec, [:id, :ip, :port, :transport, :tls, :limits]) |> Map.to_list(),
         {:ok, spec} <-
           Gaoxy.HTTP.HTTP3.service_spec(
             options ++
               [
                 endpoint: {Gaoxy.HTTP.Router, router},
                 http_limits: http_limits,
                 h3_limits: h3_limits
               ]
           ),
         :ok <-
           Gaoxy.Server.RouteConfig.validate_routes(
             router,
             Map.put(spec.handler_options, :protocols, [:http3])
           ),
         :ok <- snapshot_budget(spec) do
      {:ok, spec}
    end
  end

  defp http_service(data, spec) do
    with true <-
           (not Map.has_key?(data, "handler_options") and spec.mode == :unicast and
              spec.udp == %{}) ||
             {:error, :invalid_http_options},
         true <-
           (is_binary(spec[:id]) and byte_size(spec.id) in 1..128) ||
             {:error, :invalid_identity_or_binding},
         {:ok, routes} <- Gaoxy.Server.RouteConfig.decode(data["routes"]),
         {:ok, router} <- Gaoxy.HTTP.Router.compile(routes),
         :ok <-
           Gaoxy.HTTP.Generation.Store.compiled_bound(router, %{
             max_routes: 1024,
             max_config_bytes: @max_bytes
           }),
         {:ok, protocols} <-
           traverse(
             Map.get(data, "protocols", ["http1"]),
             &enum(&1, %{"http1" => :http1, "http2" => :http2})
           ),
         {:ok, h2c} <-
           enum(Map.get(data, "h2c", "disabled"), %{
             "disabled" => :disabled,
             "prior_knowledge" => :prior_knowledge
           }),
         {:ok, http_limits} <-
           named(
             Map.get(data, "http_limits", %{}),
             Map.new(@http_limits, &{Atom.to_string(&1), &1})
           ),
         {:ok, h2_limits} <-
           named(Map.get(data, "h2_limits", %{}), Map.new(@h2_limits, &{Atom.to_string(&1), &1})),
         options = Map.take(spec, [:id, :ip, :port, :transport, :tls, :limits]) |> Map.to_list(),
         {:ok, spec} <-
           Gaoxy.HTTP.service_spec(
             options ++
               [
                 endpoint: {Gaoxy.HTTP.Router, router},
                 protocols: protocols,
                 h2c: h2c,
                 http_limits: http_limits,
                 h2_limits: h2_limits
               ]
           ),
         :ok <- Gaoxy.Server.RouteConfig.validate_routes(router, spec.handler_options),
         :ok <- snapshot_budget(spec) do
      {:ok, spec}
    end
  end

  defp snapshot_budget(%{
         handler: Gaoxy.HTTP.HTTP3.Connection,
         handler_options: options,
         limits: limits
       }) do
    reserves = Gaoxy.HTTP.HTTP3.Options.reservation(options)

    required =
      reserves.connection + options.h3_limits.max_streams * (reserves.request + 2 * @max_bytes) +
        reserves.writer

    if limits.max_bytes >= required, do: :ok, else: {:error, :route_snapshot_byte_budget}
  end

  defp snapshot_budget(%{handler_options: options, limits: limits}) do
    http = options.http_limits

    required =
      if :http2 in options.protocols do
        reserves = Gaoxy.HTTP.HTTP2.Limits.reservation(http, options.h2_limits)
        reserves.connection + reserves.stream + reserves.writer
      else
        2 * http.max_header_bytes + 4 * http.max_read_chunk + http.max_buffer_bytes
      end

    if limits.max_bytes >= 2 * @max_bytes + required,
      do: :ok,
      else: {:error, :route_snapshot_byte_budget}
  end

  defp tls(data) do
    with {:ok, options} <-
           named(data, %{
             "certfile" => :certfile,
             "keyfile" => :keyfile,
             "alpn" => :alpn,
             "provider" => :provider
           }) do
      case Map.fetch(options, :provider) do
        {:ok, provider} ->
          with {:ok, provider} <- enum(provider, %{"otp" => :otp, "ex_ssl" => :ex_ssl}),
               do: {:ok, Map.put(options, :provider, provider)}

        :error ->
          {:ok, options}
      end
    end
  end

  defp udp(data) do
    with {:ok, options} <-
           named(data, %{
             "memberships" => :memberships,
             "multicast_if" => :multicast_if,
             "multicast_ttl" => :multicast_ttl,
             "multicast_loop" => :multicast_loop,
             "strict_group_filter" => :strict_group_filter
           }),
         {:ok, memberships} <- traverse(Map.get(options, :memberships, []), &membership/1) do
      {:ok,
       if(Map.has_key?(options, :memberships),
         do: Map.put(options, :memberships, memberships),
         else: options
       )}
    end
  end

  defp membership(%{"group" => group, "interface" => interface} = data) do
    with :ok <- keys(data, ["group", "interface"]), {:ok, group} <- address(group) do
      selector =
        case address(interface) do
          {:ok, ip} -> ip
          _ -> interface
        end

      {:ok, {group, selector}}
    end
  end

  defp membership(_), do: {:error, :invalid_membership}
  defp address(value) when is_binary(value), do: :inet.parse_address(String.to_charlist(value))
  defp address(_), do: {:error, :invalid_address}

  defp enum(value, allowed) do
    case Map.fetch(allowed, value) do
      {:ok, result} -> {:ok, result}
      :error -> {:error, :unsupported_value}
    end
  end

  defp named(data, allowed) when is_map(data) do
    with :ok <- keys(data, Map.keys(allowed)),
         do: {:ok, Map.new(data, fn {key, value} -> {allowed[key], value} end)}
  end

  defp named(_, _), do: {:error, :invalid_options}

  defp keys(data, allowed) do
    case Map.keys(data) -- allowed do
      [] -> :ok
      _ -> {:error, :unknown_configuration_keys}
    end
  end

  defp traverse(values, fun) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case fun.(value) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp traverse(_, _), do: {:error, :invalid_list}
end
