defmodule Gaoxy.Server.StaticEndpoint do
  @moduledoc "Data-only static responses for standalone route configuration."
  @behaviour Gaoxy.HTTP.Endpoint

  def init(%{status: status, body: body, headers: headers} = options)
      when is_integer(status) and status in 200..599 and is_binary(body) and is_list(headers) do
    if Map.keys(options) -- [:status, :body, :headers] == [] and
         valid_headers?(headers, status, body),
       do: {:ok, options},
       else: {:error, :invalid_static_response}
  end

  def init(_), do: {:error, :invalid_static_response}

  def call(exchange, %{status: status, body: body, headers: headers}) do
    case Gaoxy.HTTP.Response.send_resp(exchange, status, headers, body) do
      {:ok, exchange} -> {:ok, exchange}
      {:error, reason} -> {:error, reason, exchange}
    end
  end

  @doc false
  def validate_limits(%{status: status} = options, %{http_limits: limits, protocols: protocols}) do
    fields = framed_headers(options)

    valid =
      Enum.all?(protocols, fn
        version when version in [:http2, :http3] ->
          encoded = [{":status", Integer.to_string(status)} | fields]

          length(encoded) <= limits.max_headers and
            Gaoxy.HTTP.HTTP2.Headers.bytes(encoded) <= limits.max_header_bytes

        :http1 ->
          # Reserve the connection field used by HTTP/1.0 and close responses.
          encoded = [{"connection", "keep-alive"} | fields]

          head = [
            "HTTP/1.1 ",
            Integer.to_string(status),
            " ",
            Plug.Conn.Status.reason_phrase(status),
            "\r\n",
            Enum.map(encoded, fn {name, value} -> [name, ": ", value, "\r\n"] end),
            "\r\n"
          ]

          length(encoded) <= limits.max_headers and
            IO.iodata_length(head) <= limits.max_header_bytes
      end)

    if valid, do: :ok, else: {:error, :static_response_limit}
  end

  defp framed_headers(%{status: status, headers: headers, body: body}) do
    if status in [204, 304] or List.keymember?(headers, "content-length", 0),
      do: headers,
      else: [
        {"content-length", Integer.to_string(if(status == 205, do: 0, else: byte_size(body)))}
        | headers
      ]
  end

  defp valid_headers?(headers, status, body) do
    forbidden = ~w(connection keep-alive proxy-connection transfer-encoding upgrade trailer te)
    lengths = for {"content-length", value} <- headers, do: value
    expected = Integer.to_string(if(status == 205, do: 0, else: byte_size(body)))

    valid_length =
      case lengths do
        [] ->
          true

        [value] when status == 304 ->
          is_binary(value) and byte_size(value) <= 20 and
            Regex.match?(~r/\A(?:0|[1-9][0-9]*)\z/, value)

        [^expected] when status != 204 ->
          true

        _ ->
          false
      end

    framed = framed_headers(%{status: status, headers: headers, body: body})

    length(framed) + 1 <= 100 and :erlang.external_size(headers) <= 32_000 and
      valid_length and
      Enum.all?(headers, fn
        {name, value} when is_binary(name) and is_binary(value) ->
          Regex.match?(~r/\A[!#$%&'*+.^_`|~0-9a-z-]+\z/, name) and name not in forbidden and
            (value == "" or
               (:binary.first(value) not in [9, 32] and :binary.last(value) not in [9, 32])) and
            Enum.all?(:binary.bin_to_list(value), &(&1 == 9 or (&1 >= 32 and &1 != 127)))

        _ ->
          false
      end) and
      Gaoxy.HTTP.HTTP2.Headers.bytes(framed) + 42 <= 32_768
  end
end
