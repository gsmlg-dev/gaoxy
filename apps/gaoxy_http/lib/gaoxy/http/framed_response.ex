defmodule Gaoxy.HTTP.FramedResponse do
  @moduledoc false
  alias Gaoxy.HTTP.{Exchange, HTTP2.Headers}

  def send_resp(exchange, status, headers, body) do
    size = IO.iodata_length(body)

    with {:ok, headers} <- prepare(exchange, status, headers, size),
         :ok <- head(exchange, status, headers, bodyless?(exchange, status) or size == 0),
         :ok <-
           if(bodyless?(exchange, status) or size == 0,
             do: :ok,
             else: write(exchange, [body], true)
           ) do
      {:ok, %{exchange | response: :sent}}
    end
  end

  def send_chunked(exchange, status, headers) do
    with {:ok, headers} <- prepare(exchange, status, headers, nil),
         {:ok, names} <- declared_trailers(exchange, status, headers),
         :ok <- head(exchange, status, headers, bodyless?(exchange, status)) do
      length =
        Enum.find_value(headers, fn {name, value} ->
          if name == "content-length", do: String.to_integer(value)
        end)

      mode =
        cond do
          bodyless?(exchange, status) -> :bodyless_stream
          length != nil -> {:fixed_stream, length}
          true -> :chunked
        end

      {:ok, %{exchange | response: mode, response_trailers: names}}
    end
  end

  defp declared_trailers(exchange, status, headers) do
    names =
      for {"trailer", value} <- headers,
          name <- String.split(value, ","),
          do: name |> String.trim() |> String.downcase()

    if (names == [] or not bodyless?(exchange, status)) and
         Headers.trailers(Enum.map(names, &{&1, ""}), exchange.limits) == :ok,
       do: {:ok, names},
       else: {:error, :invalid_response_trailers}
  end

  def chunk(%{response: :bodyless_stream} = exchange, _), do: {:ok, exchange}

  def chunk(%{response: :chunked} = exchange, bytes) do
    with :ok <- write(exchange, [bytes], false), do: {:ok, exchange}
  end

  def chunk(%{response: {:fixed_stream, remaining}} = exchange, bytes) do
    size = IO.iodata_length(bytes)

    if size <= remaining do
      with :ok <- write(exchange, [bytes], false),
           do: {:ok, %{exchange | response: {:fixed_stream, remaining - size}}}
    else
      {:error, :content_length_exceeded}
    end
  end

  def chunk(_, _), do: {:error, :invalid_response_state}

  def finish(exchange, trailers \\ [])

  def finish(%{response: mode} = exchange, []) when mode in [:sent, :bodyless_stream],
    do: {:ok, %{exchange | response: :sent}}

  def finish(%{response: {:fixed_stream, remaining}}, []) when remaining != 0,
    do: {:error, :content_length_mismatch}

  def finish(%{response: mode} = exchange, trailers)
      when mode == :chunked or mode == {:fixed_stream, 0} do
    with :ok <- Headers.trailers(trailers, exchange.limits),
         true <-
           Enum.all?(trailers, fn {name, _} -> name in exchange.response_trailers end) ||
             {:error, :invalid_response_trailers},
         :ok <-
           if(trailers == [],
             do: exchange.transport.operation(exchange, {:data, "", true}),
             else: exchange.transport.operation(exchange, {:trailers, trailers})
           ) do
      {:ok, %{exchange | response: :sent, response_trailers: []}}
    end
  end

  def finish(_, _), do: {:error, :invalid_response_state}

  def inform(exchange, status, headers) when status in 100..199 and status != 101 do
    with :ok <-
           Headers.response(
             headers,
             exchange.limits.max_headers,
             exchange.limits.max_header_bytes
           ),
         true <-
           not Enum.any?(headers, fn {name, _} ->
             name in ["content-length", "transfer-encoding"]
           end) || {:error, :invalid_response_framing},
         do: exchange.transport.operation(exchange, {:head, status, headers, false})
  end

  def inform(_, _, _), do: {:error, :not_supported}

  def send_file(exchange, status, headers, filename, offset, length) do
    with {:ok, stat} <- File.stat(filename),
         actual = if(length == :all, do: stat.size - offset, else: length),
         true <-
           (is_integer(offset) and offset >= 0 and is_integer(actual) and actual >= 0 and
              offset + actual <= stat.size) || {:error, :invalid_file_range},
         {:ok, headers} <- prepare(exchange, status, headers, actual),
         :ok <- head(exchange, status, headers, bodyless?(exchange, status) or actual == 0),
         :ok <- file(exchange, filename, offset, actual, bodyless?(exchange, status)) do
      {:ok, %{exchange | response: :sent}}
    end
  end

  defp prepare(exchange, status, headers, size) do
    with true <- (is_integer(status) and status in 200..599) || {:error, :invalid_status},
         :ok <-
           Headers.response(
             headers,
             exchange.limits.max_headers,
             exchange.limits.max_header_bytes
           ),
         lengths = for({"content-length", value} <- headers, do: value),
         true <-
           (length(lengths) <= 1 and
              Enum.all?(
                lengths,
                &(byte_size(&1) <= 20 and Regex.match?(~r/\A(?:0|[1-9][0-9]*)\z/, &1))
              )) || {:error, :invalid_response_framing} do
      headers =
        cond do
          status == 204 ->
            Enum.reject(headers, &(elem(&1, 0) == "content-length"))

          status == 205 ->
            [{"content-length", "0"} | Enum.reject(headers, &(elem(&1, 0) == "content-length"))]

          status == 304 or size == nil ->
            headers

          true ->
            [
              {"content-length", Integer.to_string(size)}
              | Enum.reject(headers, &(elem(&1, 0) == "content-length"))
            ]
        end

      {:ok, headers}
    end
  end

  defp head(exchange, status, headers, ended) do
    send(self(), Plug.Conn.Adapter.already_sent())
    exchange.transport.operation(exchange, {:head, status, headers, ended})
  end

  defp bodyless?(exchange, status),
    do: exchange.request.method == "HEAD" or status in [204, 205, 304]

  defp file(_, _, _, 0, _), do: :ok
  defp file(_, _, _, _, true), do: :ok

  defp file(exchange, filename, offset, size, false) do
    with {:ok, file} <- :file.open(filename, [:read, :binary, :raw]) do
      try do
        file_loop(exchange, file, offset, size)
      after
        :file.close(file)
      end
    end
  end

  defp file_loop(_, _, _, 0), do: :ok

  defp file_loop(exchange, file, offset, remaining) do
    size = min(remaining, 16_384)

    with :ok <-
           Gaoxy.Admission.update(
             exchange.gate,
             exchange.lease,
             Exchange.retained_bytes(exchange) + 2 * size
           ),
         {:ok, bytes} <- :file.pread(file, offset, size),
         true <- byte_size(bytes) == size || {:error, :file_short_read},
         :ok <- write(exchange, [bytes], size == remaining),
         do: file_loop(exchange, file, offset + size, remaining - size)
  end

  defp write(exchange, pending, ended) do
    {piece, tail} = take(pending, 16_384, [])
    bytes = IO.iodata_to_binary(piece)

    cond do
      bytes == "" and tail == [] ->
        if ended, do: exchange.transport.operation(exchange, {:data, "", true}), else: :ok

      true ->
        with :ok <-
               Gaoxy.Admission.update(
                 exchange.gate,
                 exchange.lease,
                 Exchange.retained_bytes(exchange) + 2 * byte_size(bytes)
               ),
             :ok <- exchange.transport.operation(exchange, {:data, bytes, ended and tail == []}),
             :ok <-
               Gaoxy.Admission.update(
                 exchange.gate,
                 exchange.lease,
                 Exchange.retained_bytes(exchange)
               ) do
          if tail == [], do: :ok, else: write(exchange, tail, ended)
        end
    end
  end

  defp take(rest, 0, acc), do: {Enum.reverse(acc), rest}
  defp take([], _, acc), do: {Enum.reverse(acc), []}
  defp take([[] | rest], size, acc), do: take(rest, size, acc)
  defp take([[head | tail] | rest], size, acc), do: take([head, tail | rest], size, acc)

  defp take([byte | rest], size, acc) when is_integer(byte) and byte in 0..255,
    do: take(rest, size - 1, [byte | acc])

  defp take([bytes | rest], size, acc) when is_binary(bytes) do
    count = min(size, byte_size(bytes))
    <<piece::binary-size(^count), tail::binary>> = bytes
    take(if(tail == "", do: rest, else: [tail | rest]), size - count, [piece | acc])
  end
end
