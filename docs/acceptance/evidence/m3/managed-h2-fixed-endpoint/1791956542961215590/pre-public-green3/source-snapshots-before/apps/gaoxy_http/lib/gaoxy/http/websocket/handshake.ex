defmodule Gaoxy.HTTP.WebSocket.Handshake do
  @moduledoc false
  @guid "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
  @token ~r/\A[!#$%&'*+.^_`|~0-9A-Za-z-]+\z/
  @reserved ~w(upgrade connection sec-websocket-accept content-length transfer-encoding sec-websocket-extensions)

  def headers(request, response_headers) do
    with {:ok, key} <- validate(request),
         :ok <- validate_response(request, response_headers) do
      accept = :crypto.hash(:sha, key <> @guid) |> Base.encode64()

      {:ok,
       [
         {"upgrade", "websocket"},
         {"connection", "Upgrade"},
         {"sec-websocket-accept", accept} | response_headers
       ]}
    end
  end

  defp validate(%{method: "GET", version: :"HTTP/1.1", body: body, headers: headers})
       when body in [:none, {:length, 0}] do
    with [key] <- values(headers, "sec-websocket-key"),
         {:ok, decoded} when byte_size(decoded) == 16 <- Base.decode64(key),
         ["13"] <- values(headers, "sec-websocket-version"),
         true <- "upgrade" in tokens(headers, "connection", true),
         true <- "websocket" in tokens(headers, "upgrade", true) do
      {:ok, key}
    else
      _ -> {:error, :invalid_websocket_handshake}
    end
  end

  defp validate(_), do: {:error, :invalid_websocket_handshake}

  defp validate_response(request, headers) when is_list(headers) do
    protocols = values(headers, "sec-websocket-protocol")
    offered = tokens(request.headers, "sec-websocket-protocol", false)

    valid_protocol =
      protocols == [] or
        (length(protocols) == 1 and hd(protocols) in offered and
           Regex.match?(@token, hd(protocols)))

    valid_headers =
      Enum.all?(headers, fn
        {name, value} when is_binary(name) and is_binary(value) ->
          name not in @reserved and name == String.downcase(name) and Regex.match?(@token, name) and
            Enum.all?(:binary.bin_to_list(value), &(&1 == 9 or (&1 >= 32 and &1 != 127)))

        _ ->
          false
      end)

    if valid_protocol and valid_headers, do: :ok, else: {:error, :invalid_websocket_response}
  end

  defp validate_response(_, _), do: {:error, :invalid_websocket_response}

  defp values(headers, name), do: for({^name, value} <- headers, do: value)

  defp tokens(headers, name, downcase) do
    headers
    |> values(name)
    |> Enum.flat_map(&String.split(&1, ","))
    |> Enum.map(fn value ->
      value = String.trim(value)
      if downcase, do: String.downcase(value), else: value
    end)
  end
end
