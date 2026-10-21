defmodule Gaoxy.HTTP.HTTP1.Response do
  @moduledoc false
  alias Gaoxy.HTTP.{Exchange, RendererBounds}

  @token ~r/\A[!#$%&'*+.^_`|~0-9A-Za-z-]+\z/
  @forbidden_trailers ~w(content-length transfer-encoding host connection trailer te upgrade
                        keep-alive proxy-connection authorization proxy-authorization
                        proxy-authenticate www-authenticate content-encoding content-type
                        content-range expect cache-control cookie set-cookie)

  def send_resp(exchange, status, headers, body) do
    omit = bodyless?(exchange, status)
    length = IO.iodata_length(body)

    with {:ok, headers} <- prepare_headers(exchange, status, headers, {:length, length}),
         :ok <- send_head(exchange, status, headers),
         :ok <- maybe_send_body(exchange, body, omit) do
      {:ok, %{exchange | response: :sent, close: close?(exchange, headers)}}
    end
  end

  def send_file(exchange, status, headers, filename, offset, length) do
    with {:ok, stat} <- File.stat(filename),
         true <- (offset >= 0 and offset <= stat.size) || {:error, :invalid_file_range},
         actual = if(length == :all, do: stat.size - offset, else: length),
         true <-
           (is_integer(actual) and actual >= 0 and offset + actual <= stat.size) ||
             {:error, :invalid_file_range},
         {:ok, headers} <- prepare_headers(exchange, status, headers, {:length, actual}),
         :ok <- send_head(exchange, status, headers),
         :ok <- file_chunks(exchange, filename, offset, actual, bodyless?(exchange, status)) do
      {:ok, %{exchange | response: :sent, close: close?(exchange, headers)}}
    end
  end

  def send_chunked(exchange, status, original_headers) do
    with {:ok, headers, mode} <- stream_headers(exchange, status, original_headers),
         {:ok, trailers} <- declared_trailers(exchange, original_headers, mode),
         :ok <- send_head(exchange, status, headers) do
      exchange = %{
        exchange
        | response: mode,
          response_trailers: trailers,
          close: close?(exchange, headers)
      }

      with :ok <-
             Gaoxy.Admission.update(
               exchange.gate,
               exchange.lease,
               Exchange.retained_bytes(exchange)
             ),
           do: {:ok, exchange}
    end
  end

  @doc "Completes a stream once, preserving ordered duplicate declared trailers."
  def finish(exchange, trailers \\ [])

  def finish(%{response: :chunked} = exchange, trailers) do
    with :ok <- validate_trailers(exchange, trailers),
         rendered = ["0\r\n", fields(trailers), "\r\n"],
         {:ok, _} <- rendered(rendered, :response_trailer_limit),
         :ok <- Exchange.send_bytes(exchange, rendered) do
      exchange = %{exchange | response: :sent, response_trailers: []}

      with :ok <-
             Gaoxy.Admission.update(
               exchange.gate,
               exchange.lease,
               Exchange.retained_bytes(exchange)
             ),
           do: {:ok, exchange}
    end
  end

  def finish(%{response: {:fixed_stream, remaining}}, []) when remaining != 0,
    do: {:error, :content_length_mismatch}

  def finish(%{response: :close_stream} = exchange, []),
    do: {:ok, %{exchange | response: :sent, close: true}}

  def finish(%{response: mode} = exchange, [])
      when mode in [:sent, :bodyless_stream] or mode == {:fixed_stream, 0},
      do: {:ok, %{exchange | response: :sent}}

  def finish(_, trailers) when trailers != [], do: {:error, :invalid_response_trailers}
  def finish(_, []), do: {:error, :invalid_response_state}

  defp declared_trailers(exchange, headers, mode) do
    with :ok <- token_budget(headers, "trailer"),
         :ok <- token_budget(headers, "connection") do
      declared_names(exchange, headers, mode)
    end
  end

  defp declared_names(exchange, headers, mode) do
    declarations = for {"trailer", value} <- headers, do: value

    names =
      Enum.flat_map(declarations, &String.split(&1, ","))
      |> Enum.map(&String.downcase(String.trim(&1)))

    connection =
      for {"connection", value} <- headers,
          name <- String.split(value, ","),
          do: String.downcase(String.trim(name))

    if (names == [] or mode == :chunked) and
         length(names) <= exchange.limits.max_trailers and
         Enum.all?(
           names,
           &(Regex.match?(@token, &1) and &1 not in @forbidden_trailers and &1 not in connection)
         ) do
      {:ok, names}
    else
      {:error, :invalid_response_trailers}
    end
  end

  defp validate_trailers(exchange, trailers) do
    with :ok <-
           validate_headers(
             trailers,
             exchange.limits.max_trailers,
             exchange.limits.max_trailer_bytes,
             :response_trailer_limit
           ),
         true <-
           Enum.all?(trailers, fn {name, _} ->
             name in exchange.response_trailers and name not in @forbidden_trailers
           end) || {:error, :invalid_response_trailers},
         true <-
           (length(trailers) <= exchange.limits.max_trailers and
              IO.iodata_length(fields(trailers)) + 2 <= exchange.limits.max_trailer_bytes) ||
             {:error, :response_trailer_limit} do
      :ok
    end
  end

  defp fields(headers), do: Enum.map(headers, fn {key, value} -> [key, ": ", value, "\r\n"] end)

  def chunk(%{response: mode} = exchange, data) when mode in [:chunked, :close_stream] do
    size = IO.iodata_length(data)

    if size == 0 do
      :ok
    else
      encoded =
        if mode == :chunked,
          do: [Integer.to_string(size, 16), "\r\n", data, "\r\n"],
          else: data

      Exchange.send_bytes(exchange, encoded)
    end
  end

  def chunk(%{response: :bodyless_stream} = exchange, _data), do: {:ok, exchange}

  def chunk(%{response: {:fixed_stream, remaining}} = exchange, data) do
    size = IO.iodata_length(data)

    if size <= remaining do
      with :ok <- Exchange.send_bytes(exchange, data) do
        {:ok, %{exchange | response: {:fixed_stream, remaining - size}}}
      end
    else
      {:error, :content_length_exceeded}
    end
  end

  def chunk(_, _), do: {:error, :invalid_response_state}

  def inform(exchange, status, headers) when status in 100..199 and status != 101 do
    with :ok <-
           validate_headers(
             headers,
             exchange.limits.max_headers,
             exchange.limits.max_header_bytes
           ),
         true <-
           Enum.all?(headers, fn {key, _} ->
             key not in ["content-length", "transfer-encoding"]
           end) ||
             {:error, :invalid_response_framing},
         :ok <- send_head(exchange, status, headers, false) do
      :ok
    end
  end

  def inform(_, _, _), do: {:error, :not_supported}

  defp prepare_headers(exchange, status, headers, {:length, length}) do
    headers = Gaoxy.HTTP.ListenerSet.Discovery.headers(exchange, status, headers)

    with :ok <- validate_status(status),
         :ok <-
           validate_headers(
             headers,
             exchange.limits.max_headers,
             exchange.limits.max_header_bytes
           ),
         :ok <- valid_framing(headers) do
      headers =
        Enum.reject(headers, fn {key, _} ->
          key == "transfer-encoding" or (key == "content-length" and status != 304)
        end)

      headers =
        cond do
          status in [204, 304] -> headers
          status == 205 -> [{"content-length", "0"} | headers]
          true -> [{"content-length", Integer.to_string(length)} | headers]
        end

      {:ok, add_connection(exchange, headers)}
    end
  end

  defp stream_headers(exchange, status, headers) do
    headers = Gaoxy.HTTP.ListenerSet.Discovery.headers(exchange, status, headers)

    with :ok <- validate_status(status),
         :ok <-
           validate_headers(
             headers,
             exchange.limits.max_headers,
             exchange.limits.max_header_bytes
           ),
         :ok <- valid_framing(headers) do
      length =
        Enum.find_value(headers, fn {key, value} -> if key == "content-length", do: value end)

      cond do
        bodyless?(exchange, status) ->
          headers =
            cond do
              status == 204 ->
                Enum.reject(headers, fn {key, _} -> key == "content-length" end)

              status == 205 ->
                [
                  {"content-length", "0"}
                  | Enum.reject(headers, fn {key, _} -> key == "content-length" end)
                ]

              true ->
                headers
            end

          {:ok, add_connection(exchange, headers), :bodyless_stream}

        length != nil ->
          {number, ""} = Integer.parse(length)
          {:ok, add_connection(exchange, headers), {:fixed_stream, number}}

        exchange.request.version == :"HTTP/1.0" ->
          {:ok, [{"connection", "close"} | headers], :close_stream}

        true ->
          headers = [{"transfer-encoding", "chunked"} | headers]
          {:ok, add_connection(exchange, headers), :chunked}
      end
    end
  end

  defp valid_framing(headers) do
    lengths = for {"content-length", value} <- headers, do: value
    transfers = for {"transfer-encoding", value} <- headers, do: value

    cond do
      length(lengths) > 1 or transfers != [] ->
        {:error, :invalid_response_framing}

      lengths != [] and not Regex.match?(~r/\A(?:0|[1-9][0-9]*)\z/, hd(lengths)) ->
        {:error, :invalid_response_framing}

      true ->
        :ok
    end
  end

  defp validate_status(status) when is_integer(status) and status in 200..599, do: :ok
  defp validate_status(_), do: {:error, :invalid_status}

  defp validate_headers(headers, max_count, max_bytes, limit_error \\ :response_header_limit) do
    case RendererBounds.fields(headers, max_count, max_bytes) do
      :ok -> validate_field_grammar(headers)
      {:error, :renderer_limit} -> {:error, limit_error}
      {:error, _} -> {:error, :invalid_response_headers}
    end
  end

  defp validate_field_grammar(headers) do
    if Enum.all?(headers, fn
         {key, value} when is_binary(key) and is_binary(value) ->
           RendererBounds.lower_token?(key) and RendererBounds.field_value?(value)

         _ ->
           false
       end),
       do: :ok,
       else: {:error, :invalid_response_headers}
  end

  # Count before String.split/normalization can amplify a declaration.
  defp token_budget(headers, selected) do
    Enum.reduce_while(headers, 0, fn
      {^selected, value}, count ->
        case commas(value, count + 1) do
          {:ok, next} -> {:cont, next}
          :over -> {:halt, :over}
        end

      _, count ->
        {:cont, count}
    end)
    |> case do
      :over -> {:error, :invalid_response_trailers}
      _ -> :ok
    end
  end

  defp commas(_, count) when count > 128, do: :over
  defp commas(<<>>, count), do: {:ok, count}
  defp commas(<<?,, rest::binary>>, count), do: commas(rest, count + 1)
  defp commas(<<_, rest::binary>>, count), do: commas(rest, count)

  defp add_connection(exchange, headers) do
    cond do
      close?(exchange, headers) ->
        [{"connection", "close"} | Enum.reject(headers, fn {key, _} -> key == "connection" end)]

      exchange.request.version == :"HTTP/1.0" ->
        [
          {"connection", "keep-alive"}
          | Enum.reject(headers, fn {key, _} -> key == "connection" end)
        ]

      true ->
        headers
    end
  end

  defp close?(exchange, headers),
    do:
      exchange.close or exchange.body.phase != :done or
        Enum.any?(headers, fn {key, value} ->
          key == "connection" and
            Enum.any?(String.split(String.downcase(value), ","), &(String.trim(&1) == "close"))
        end)

  defp head(exchange, status, headers) do
    version = if exchange.request.version == :"HTTP/1.0", do: "HTTP/1.0", else: "HTTP/1.1"
    reason = Plug.Conn.Status.reason_phrase(status)

    [
      version,
      " ",
      Integer.to_string(status),
      " ",
      reason,
      "\r\n",
      fields(headers),
      "\r\n"
    ]
  end

  defp send_head(exchange, status, headers, final? \\ true) do
    head = head(exchange, status, headers)

    with {:ok, length} <- rendered(head, :response_header_limit),
         true <- length <= exchange.limits.max_header_bytes || {:error, :response_header_limit} do
      # A failed final response write must never become a second response.
      # Informational responses still allow the application to send its final head.
      if final?, do: send(self(), Plug.Conn.Adapter.already_sent())
      Exchange.send_bytes(exchange, head)
    end
  end

  defp rendered(data, error) do
    case RendererBounds.iodata(data, 81_920) do
      {:ok, length} -> {:ok, length}
      {:error, _} -> {:error, error}
    end
  end

  defp bodyless?(exchange, status),
    do:
      exchange.request.method == "HEAD" or
        status in [204, 205, 304]

  defp maybe_send_body(_, _, true), do: :ok
  defp maybe_send_body(exchange, body, false), do: Exchange.send_bytes(exchange, body)

  defp file_chunks(_, _, _, 0, _), do: :ok
  defp file_chunks(_, _, _, _, true), do: :ok

  defp file_chunks(exchange, filename, offset, length, false) do
    {:ok, file} = :file.open(filename, [:read, :binary, :raw])

    try do
      file_loop(exchange, file, offset, length)
    after
      :file.close(file)
    end
  end

  defp file_loop(_, _, _, 0), do: :ok

  defp file_loop(exchange, file, offset, length) do
    size = min(length, min(exchange.limits.max_read_chunk, exchange.limits.max_write_chunk))

    with :ok <-
           Gaoxy.Admission.update(
             exchange.gate,
             exchange.lease,
             Exchange.retained_bytes(exchange) + size
           ),
         {:ok, data} <- :file.pread(file, offset, size),
         true <- byte_size(data) == size || {:error, :file_short_read},
         :ok <- Exchange.send_bytes(exchange, data) do
      file_loop(exchange, file, offset + size, length - size)
    end
  end
end
