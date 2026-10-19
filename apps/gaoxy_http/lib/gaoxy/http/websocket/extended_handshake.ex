defmodule Gaoxy.HTTP.WebSocket.ExtendedHandshake do
  @moduledoc false
  @token ~r/\A[!#$%&'*+.^_`|~0-9A-Za-z-]+\z/
  @reserved ~w(connection upgrade keep-alive proxy-connection te trailer content-length transfer-encoding sec-websocket-accept sec-websocket-key sec-websocket-extensions)

  def headers(request, response_headers) do
    with :ok <- validate(request),
         :ok <- validate_response(request, response_headers),
         do: {:ok, response_headers}
  end

  defp validate(%{
         method: "CONNECT",
         protocol: "websocket",
         version: version,
         body: :tunnel,
         scheme: scheme,
         host: host,
         port: port,
         target_form: :origin,
         target: "/" <> _,
         path: "/" <> _,
         headers: headers
       })
       when version in [:"HTTP/2", :"HTTP/3"] and scheme in [:http, :https] and
              is_binary(host) and byte_size(host) > 0 and is_integer(port) and port in 1..65535 do
    offered = tokens(headers)

    if values(headers, "sec-websocket-version") == ["13"] and
         Enum.all?(offered, &Regex.match?(@token, &1)) and
         length(offered) == length(Enum.uniq(offered)),
       do: :ok,
       else: {:error, :invalid_websocket_handshake}
  end

  defp validate(_), do: {:error, :invalid_websocket_handshake}

  defp validate_response(request, headers) when is_list(headers) do
    selected = values(headers, "sec-websocket-protocol")
    offered = tokens(request.headers)

    valid_protocol =
      case selected do
        [] -> true
        [protocol] -> protocol in offered and Regex.match?(@token, protocol)
        _ -> false
      end

    valid_fields =
      Enum.all?(headers, fn
        {name, value} when is_binary(name) and is_binary(value) ->
          name not in @reserved and Regex.match?(@token, name) and
            name == String.downcase(name) and
            Enum.all?(:binary.bin_to_list(value), &(&1 == 9 or (&1 >= 32 and &1 != 127)))

        _ ->
          false
      end)

    if valid_protocol and valid_fields, do: :ok, else: {:error, :invalid_websocket_response}
  end

  defp validate_response(_, _), do: {:error, :invalid_websocket_response}
  defp values(headers, name), do: for({^name, value} <- headers, do: value)

  defp tokens(headers) do
    headers
    |> values("sec-websocket-protocol")
    |> Enum.flat_map(&String.split(&1, ","))
    |> Enum.map(&String.trim/1)
  end
end
