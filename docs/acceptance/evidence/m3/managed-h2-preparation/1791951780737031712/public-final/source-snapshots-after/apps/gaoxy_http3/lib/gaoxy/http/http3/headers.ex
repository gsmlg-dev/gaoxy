defmodule Gaoxy.HTTP.HTTP3.Headers do
  @moduledoc false
  alias Gaoxy.HTTP.HTTP1.Parser
  alias Gaoxy.HTTP.HTTP2.Headers, as: Fields
  alias Gaoxy.HTTP.Request
  alias QuicHttp3.Qpack
  @token ~r/\A[!#$%&'*+.^_`|~0-9A-Za-z-]+\z/

  def decode(block, max_fields) do
    case Qpack.decode_header_block(block, max_fields: max_fields) do
      {:ok, fields} -> {:ok, fields}
      {:error, :invalid_fields} -> message(:invalid_fields)
      {:error, :field_limit} -> excessive(:field_limit)
      {:error, reason} -> {:error, :connection, 0x200, reason}
      :more -> {:error, :connection, 0x200, :truncated_header_block}
    end
  end

  def request(fields, limits) do
    with :ok <- validate(fields, limits.max_headers, limits.max_header_bytes),
         {:ok, pseudo, regular} <- split(fields),
         method when is_binary(method) <- pseudo[":method"],
         true <- Regex.match?(@token, method),
         true <- Map.keys(pseudo) -- [":method", ":scheme", ":authority", ":path"] == [],
         {:ok, request} <- target(method, pseudo, regular, limits) do
      {:ok, %{request | head_bytes: bytes(fields)}}
    else
      {:error, _, _, _} = error -> error
      _ -> message(:request_headers)
    end
  end

  def trailers(fields, limits) do
    with :ok <- validate(fields, limits.max_trailers, limits.max_trailer_bytes),
         :ok <- Fields.trailers(fields, limits) do
      :ok
    else
      {:error, _, _, _} = error -> error
      _ -> message(:request_trailers)
    end
  end

  defdelegate response(fields, max_count, max_bytes), to: Fields
  defdelegate bytes(fields), to: Fields

  defp validate(fields, count, maximum) do
    cond do
      not is_list(fields) or
          not Enum.all?(fields, fn
            {name, value} -> is_binary(name) and is_binary(value)
            _ -> false
          end) ->
        message(:header_fields)

      length(fields) > count or bytes(fields) > maximum ->
        excessive(:header_limit)

      Fields.validate(fields, count, maximum) != :ok ->
        message(:header_fields)

      true ->
        :ok
    end
  end

  defp split(fields) do
    Enum.reduce_while(fields, {:ok, %{}, [], false}, fn {name, value},
                                                        {:ok, pseudo, regular, seen_regular} ->
      if String.starts_with?(name, ":") do
        if seen_regular or Map.has_key?(pseudo, name),
          do: {:halt, message(:pseudoheaders)},
          else: {:cont, {:ok, Map.put(pseudo, name, value), regular, false}}
      else
        {:cont, {:ok, pseudo, [{name, value} | regular], true}}
      end
    end)
    |> case do
      {:ok, pseudo, regular, _} -> {:ok, pseudo, Enum.reverse(regular)}
      error -> error
    end
  end

  defp target("CONNECT", pseudo, regular, _limits) do
    hosts = for {"host", value} <- regular, do: value

    with true <- Map.keys(pseudo) -- [":method", ":authority"] == [],
         authority when is_binary(authority) <- pseudo[":authority"],
         {:ok, host, port} when is_integer(port) <- Parser.parse_authority(authority),
         true <- not Enum.any?(regular, fn {name, _} -> name == "content-length" end),
         true <- length(hosts) <= 1,
         true <- authority_matches?(hosts, host, port) do
      {:ok,
       %Request{
         method: "CONNECT",
         target: authority,
         target_form: :authority,
         version: :"HTTP/3",
         path: authority,
         query_string: "",
         host: host,
         port: port,
         scheme: :https,
         headers: regular,
         keep_alive: true
       }}
    else
      _ -> message(:connect_headers)
    end
  end

  defp target(method, pseudo, regular, limits) do
    hosts = for {"host", value} <- regular, do: value
    authority = pseudo[":authority"] || List.first(hosts)
    path = pseudo[":path"]

    with true <- pseudo[":scheme"] == "https",
         true <- is_binary(path) and byte_size(path) <= limits.max_request_line,
         true <- String.starts_with?(path, "/") or (path == "*" and method == "OPTIONS"),
         true <- Enum.all?(:binary.bin_to_list(path), &(&1 in 33..126 and &1 not in [?#, ?\\])),
         true <- not Regex.match?(~r/%(?![0-9a-fA-F]{2})/, path),
         true <- length(hosts) <= 1,
         true <- is_binary(authority),
         {:ok, host, port} <- Parser.parse_authority(authority),
         true <- authority_matches?(hosts, host, port),
         {:ok, body} <- body(regular, limits.max_body_bytes) do
      [raw_path | query] = String.split(path, "?", parts: 2)

      {:ok,
       %Request{
         method: method,
         target: path,
         target_form: :origin,
         version: :"HTTP/3",
         path: raw_path,
         query_string: List.first(query) || "",
         host: host,
         port: port || 443,
         scheme: :https,
         headers: regular,
         body: body,
         keep_alive: true,
         expect_continue: {"expect", "100-continue"} in regular
       }}
    else
      {:error, _, _, _} = error -> error
      _ -> message(:request_target)
    end
  end

  defp authority_matches?([], _, _), do: true

  defp authority_matches?([value], host, port) do
    case Parser.parse_authority(value) do
      {:ok, ^host, other_port} -> (other_port || 443) == (port || 443)
      _ -> false
    end
  end

  defp body(fields, maximum) do
    case for {"content-length", value} <- fields, do: value do
      [] ->
        {:ok, :chunked}

      [value] ->
        if byte_size(value) <= 20 and Regex.match?(~r/\A(?:0|[1-9][0-9]*)\z/, value) do
          length = String.to_integer(value)
          if length <= maximum, do: {:ok, {:length, length}}, else: excessive(:body_limit)
        else
          message(:content_length)
        end

      _ ->
        message(:content_length)
    end
  end

  defp message(reason), do: {:error, :stream, 0x10E, reason}
  defp excessive(reason), do: {:error, :stream, 0x107, reason}
end
