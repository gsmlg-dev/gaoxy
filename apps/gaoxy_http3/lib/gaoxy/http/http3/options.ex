defmodule Gaoxy.HTTP.HTTP3.Options do
  @moduledoc false
  @keys [
    :id,
    :ip,
    :port,
    :transport,
    :tls,
    :quic,
    :limits,
    :http_limits,
    :h3_limits,
    :extended_connect,
    :endpoint,
    :plug
  ]
  @h3_defaults %{
    max_streams: 8,
    max_header_block: 32_768,
    max_pending_output: 65_536,
    control_turn: 32,
    control_quantum: 16_384,
    dynamic_table_capacity: 0,
    blocked_streams: 0
  }
  @service_defaults %{
    max_active: 64,
    max_bytes: 16_777_216,
    max_packet: 16_384,
    max_output: 16_384,
    max_state: 3_145_728,
    callback_timeout: 5_000,
    idle_timeout: 30_000,
    drain_timeout: 5_000,
    max_memberships: 64
  }

  def normalize(options) when is_list(options) do
    with true <-
           (Keyword.keyword?(options) and
              length(options) == map_size(Map.new(options)) and
              Keyword.keys(options) -- @keys == []) || {:error, :invalid_http3_options},
         extended_connect = Keyword.get(options, :extended_connect, false),
         true <- is_boolean(extended_connect) || {:error, :invalid_http3_options},
         :ok <- validate_binding(options),
         {:ok, tls} <- credentials(Keyword.get(options, :tls)),
         true <-
           Keyword.get(options, :quic, %{alpn: ["h3"]}) == %{alpn: ["h3"]} ||
             {:error, :unsupported_http3_alpn},
         {:ok, h3} <- h3_limits(Keyword.get(options, :h3_limits, %{})),
         {:ok, service_limits} <- service_limits(Keyword.get(options, :limits, %{})),
         {:ok, endpoint} <- endpoint(options),
         {:ok, normalized} <-
           Gaoxy.HTTP.Options.normalize(%{
             endpoint: endpoint,
             http_limits: Keyword.get(options, :http_limits, %{}),
             initialized: true
           }),
         true <-
           normalized.http_limits.stream_timeout == :request ||
             {:error, :unsupported_stream_timeout},
         handler =
           Map.take(normalized, [:endpoint, :http_limits, :initialized])
           |> Map.put(:h3_limits, h3)
           |> Map.put(:extended_connect, extended_connect),
         :ok <- budget(handler, service_limits),
         {:ok, initialized} <-
           Gaoxy.HTTP.Options.normalize(Map.put(normalized, :initialized, false)) do
      {:ok,
       %{
         id: Keyword.get(options, :id, :http3),
         ip: Keyword.get(options, :ip, {127, 0, 0, 1}),
         port: Keyword.get(options, :port, 0),
         transport: :quic,
         tls: tls,
         quic: %{alpn: ["h3"]},
         limits: service_limits,
         handler_options: %{handler | endpoint: initialized.endpoint}
       }}
    end
  end

  def normalize(_), do: {:error, :invalid_http3_options}

  def reservation(%{http_limits: http, h3_limits: h3}) do
    # Explicit reservations for retained application work, not total native/VM memory.
    stream =
      http.max_buffer_bytes + h3.max_pending_output + h3.max_header_block +
        http.max_header_bytes + 16_384

    worker = 4 * http.max_read_chunk + 2 * http.max_header_bytes + 65_536

    unidirectional =
      3 * http.max_buffer_bytes + 5 * h3.max_header_block + (h3.max_streams + 3) * 1_024

    %{
      connection: h3.control_quantum + h3.max_streams * stream + unidirectional,
      unidirectional: unidirectional,
      request: worker,
      writer: 16_384
    }
  end

  defp validate_binding(options) do
    ip = Keyword.get(options, :ip, {127, 0, 0, 1})
    id = Keyword.get(options, :id, :http3)
    port = Keyword.get(options, :port, 0)

    cond do
      Keyword.get(options, :transport, :quic) != :quic ->
        {:error, :invalid_http3_transport}

      is_tuple(ip) and tuple_size(ip) == 8 ->
        {:error, {:unsupported_capability, :quic_ipv6}}

      ip == {0, 0, 0, 0} ->
        {:error, :wildcard_bind_unsupported}

      not (is_tuple(ip) and tuple_size(ip) == 4 and
               Enum.all?(Tuple.to_list(ip), &(is_integer(&1) and &1 in 0..255))) ->
        {:error, :invalid_identity_or_binding}

      not (((is_atom(id) and not is_nil(id)) or (is_binary(id) and byte_size(id) in 1..128)) and
             is_integer(port) and port in 0..65_535) ->
        {:error, :invalid_identity_or_binding}

      true ->
        :ok
    end
  end

  defp credentials(tls) when is_map(tls) do
    cond do
      Map.keys(tls) -- [:certfile, :keyfile] != [] ->
        {:error, :invalid_http3_tls}

      not (is_binary(tls[:certfile]) and byte_size(tls[:certfile]) > 0 and
             is_binary(tls[:keyfile]) and byte_size(tls[:keyfile]) > 0) ->
        {:error, :missing_credentials}

      true ->
        {:ok, tls}
    end
  end

  defp credentials(_), do: {:error, :missing_credentials}

  defp endpoint(options) do
    case {Keyword.get(options, :endpoint), Keyword.get(options, :plug)} do
      {{module, opts}, nil} when is_atom(module) ->
        {:ok, {module, opts}}

      {nil, {module, opts}} when is_atom(module) ->
        {:ok, {Gaoxy.HTTP.PlugEndpoint, {module, opts}}}

      _ ->
        {:error, :invalid_endpoint}
    end
  end

  defp h3_limits(input) when is_map(input) do
    limits = Map.merge(@h3_defaults, input)

    if Map.keys(input) -- Map.keys(@h3_defaults) == [] and
         limits.dynamic_table_capacity == 0 and limits.blocked_streams == 0 and
         Enum.all?(Map.drop(limits, [:dynamic_table_capacity, :blocked_streams]), fn {_, value} ->
           is_integer(value) and value > 0
         end) and limits.max_streams <= 8 and limits.max_header_block <= 32_768 and
         limits.max_pending_output <= 65_536 and limits.control_turn <= 32 and
         limits.control_quantum <= 16_384,
       do: {:ok, limits},
       else: {:error, :invalid_http3_limits}
  end

  defp h3_limits(_), do: {:error, :invalid_http3_limits}

  defp service_limits(input) when is_map(input) do
    limits = Map.merge(@service_defaults, input)

    if Map.keys(input) -- Map.keys(@service_defaults) == [] and
         Enum.all?(limits, fn {_, value} -> is_integer(value) and value > 0 end) and
         limits.max_packet <= 65_507 and limits.max_memberships <= 64,
       do: {:ok, limits},
       else: {:error, :invalid_limits}
  end

  defp service_limits(_), do: {:error, :invalid_limits}

  defp budget(handler, service) do
    reserves = reservation(handler)
    http = handler.http_limits
    h3 = handler.h3_limits

    if service.max_state >= reserves.connection and
         service.max_bytes >=
           reserves.connection + h3.max_streams * reserves.request + reserves.writer and
         h3.max_pending_output >= http.max_read_chunk + 32 and
         service.max_active >= h3.max_streams + 1 and
         service.max_packet >= min(http.max_read_chunk, 16_384) and
         service.max_output >= min(http.max_read_chunk, 16_384),
       do: :ok,
       else: {:error, :http3_byte_budget}
  end
end
