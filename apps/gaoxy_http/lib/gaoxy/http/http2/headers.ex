defmodule Gaoxy.HTTP.HTTP2.Headers do
  @moduledoc false
  alias Gaoxy.HTTP.HTTP1.Parser
  alias Gaoxy.HTTP.Request
  @token ~r/\A[!#$%&'*+.^_`|~0-9A-Za-z-]+\z/
  @hop ~w(connection proxy-connection keep-alive transfer-encoding upgrade)
  @forbidden_trailers ~w(content-length transfer-encoding host connection trailer te upgrade keep-alive proxy-connection authorization proxy-authorization proxy-authenticate www-authenticate content-encoding content-type content-range expect cache-control cookie set-cookie)

  def request(fields, secure, limits, extended_connect \\ false) do
    with :ok <- validate(fields, limits.max_headers, limits.max_header_bytes),
         {:ok, pseudo, regular} <- split(fields),
         method when is_binary(method) <- pseudo[":method"],
         true <- Regex.match?(@token, method),
         true <-
           Map.keys(pseudo) -- [":method", ":scheme", ":authority", ":path", ":protocol"] == [],
         :ok <- protocol(method, pseudo, extended_connect),
         {:ok, request} <- target(method, pseudo, regular, secure, limits) do
      {:ok, request}
    else
      {:error, _, _} = error -> error
      _ -> {:error, :protocol_error, :request_headers}
    end
  end

  defp protocol("CONNECT", %{":protocol" => value, ":authority" => authority}, true)
       when is_binary(value) and is_binary(authority) do
    if Regex.match?(@token, value), do: :ok, else: :error
  end

  defp protocol(_, pseudo, _) do
    if Map.has_key?(pseudo, ":protocol"), do: :error, else: :ok
  end

  defp target("CONNECT", %{":protocol" => protocol} = pseudo, regular, secure, limits) do
    with false <- Enum.any?(regular, fn {name, _} -> name == "content-length" end),
         {:ok, request} <- origin("CONNECT", pseudo, regular, secure, limits) do
      {:ok, %{request | protocol: protocol, body: :tunnel, expect_continue: false}}
    else
      _ -> {:error, :protocol_error, :connect_headers}
    end
  end

  defp target("CONNECT", pseudo, regular, _secure, limits) do
    with true <- Map.keys(pseudo) -- [":method", ":authority"] == [],
         authority when is_binary(authority) <- pseudo[":authority"],
         {:ok, host, port} when is_integer(port) <- Parser.parse_authority(authority),
         true <- not Enum.any?(regular, fn {name, _} -> name == "content-length" end) do
      {:ok,
       %Request{
         method: "CONNECT",
         target: authority,
         target_form: :authority,
         version: :"HTTP/2",
         path: authority,
         query_string: "",
         host: host,
         port: port,
         headers: regular,
         head_bytes: min(bytes(regular), limits.max_header_bytes),
         keep_alive: true
       }}
    else
      _ -> {:error, :protocol_error, :connect_headers}
    end
  end

  defp target(method, pseudo, regular, secure, limits),
    do: origin(method, pseudo, regular, secure, limits)

  defp origin(method, pseudo, regular, secure, limits) do
    scheme = if secure, do: "https", else: "http"
    host_fields = for {"host", value} <- regular, do: value
    authority = pseudo[":authority"] || List.first(host_fields)
    path = pseudo[":path"]

    with true <- pseudo[":scheme"] == scheme,
         true <- is_binary(path) and byte_size(path) <= limits.max_request_line,
         true <- String.starts_with?(path, "/") or (path == "*" and method == "OPTIONS"),
         true <- Enum.all?(:binary.bin_to_list(path), &(&1 in 33..126 and &1 not in [?#, ?\\])),
         true <- not Regex.match?(~r/%(?![0-9a-fA-F]{2})/, path),
         true <- length(host_fields) <= 1,
         true <- is_binary(authority),
         {:ok, host, port} <- Parser.parse_authority(authority),
         true <- authority_matches?(host_fields, host, port, scheme),
         {:ok, body} <- body(regular, limits.max_body_bytes) do
      [raw_path | query] = String.split(path, "?", parts: 2)

      {:ok,
       %Request{
         method: method,
         target: path,
         target_form: :origin,
         version: :"HTTP/2",
         path: raw_path,
         query_string: List.first(query) || "",
         host: host,
         port: port || if(secure, do: 443, else: 80),
         scheme: if(secure, do: :https, else: :http),
         headers: regular,
         body: body,
         head_bytes: bytes(regular) + bytes(Map.to_list(pseudo)),
         keep_alive: true,
         expect_continue: {"expect", "100-continue"} in regular
       }}
    else
      _ -> {:error, :protocol_error, :request_target}
    end
  end

  defp authority_matches?([], _, _, _), do: true

  defp authority_matches?([value], host, port, scheme) do
    default = if scheme == "https", do: 443, else: 80

    case Parser.parse_authority(value) do
      {:ok, ^host, other_port} -> (other_port || default) == (port || default)
      _ -> false
    end
  end

  defp body(fields, maximum) do
    case for {"content-length", value} <- fields, do: value do
      [] ->
        {:ok, :chunked}

      [value] ->
        if byte_size(value) <= 20 and Regex.match?(~r/\A(?:0|[1-9][0-9]*)\z/, value) and
             String.to_integer(value) <= maximum,
           do: {:ok, {:length, String.to_integer(value)}},
           else: {:error, :content_length}

      _ ->
        {:error, :content_length}
    end
  end

  def trailers(fields, limits) do
    with :ok <- validate(fields, limits.max_trailers, limits.max_trailer_bytes),
         true <-
           Enum.all?(fields, fn {name, _} ->
             not String.starts_with?(name, ":") and name not in @forbidden_trailers
           end) do
      :ok
    else
      _ -> {:error, :protocol_error, :request_trailers}
    end
  end

  def validate(fields, max_count, max_bytes) when is_list(fields) do
    if Enum.all?(fields, fn
         {name, value} when is_binary(name) and is_binary(value) -> true
         _ -> false
       end) and length(fields) <= max_count and bytes(fields) <= max_bytes and
         Enum.all?(fields, fn
           {name, value} when is_binary(name) and is_binary(value) ->
             ordinary = String.trim_leading(name, ":")

             Regex.match?(@token, ordinary) and name == String.downcase(name) and name not in @hop and
               (name != "te" or value == "trailers") and
               Enum.all?(:binary.bin_to_list(value), &(&1 == 9 or &1 in 32..126 or &1 >= 128)) and
               (value == "" or
                  (not String.starts_with?(value, [" ", "\t"]) and
                     not String.ends_with?(value, [" ", "\t"])))

           _ ->
             false
         end),
       do: :ok,
       else: {:error, :protocol_error, :header_fields}
  end

  def validate(_, _, _), do: {:error, :protocol_error, :header_fields}

  def response(fields, max_count, max_bytes) do
    if validate(fields, max_count, max_bytes) == :ok and
         Enum.all?(fields, fn {name, _} -> not String.starts_with?(name, ":") end),
       do: :ok,
       else: {:error, :invalid_response_headers}
  end

  def bytes(fields),
    do:
      Enum.reduce(fields, 0, fn {name, value}, size ->
        size + byte_size(name) + byte_size(value) + 32
      end)

  defp split(fields) do
    Enum.reduce_while(fields, {:ok, %{}, [], false}, fn {name, value},
                                                        {:ok, pseudo, regular, seen_regular} ->
      if String.starts_with?(name, ":") do
        if seen_regular or Map.has_key?(pseudo, name),
          do: {:halt, :error},
          else: {:cont, {:ok, Map.put(pseudo, name, value), regular, false}}
      else
        {:cont, {:ok, pseudo, [{name, value} | regular], true}}
      end
    end)
    |> case do
      {:ok, pseudo, regular, _} -> {:ok, pseudo, Enum.reverse(regular)}
      _ -> {:error, :protocol_error, :pseudoheaders}
    end
  end
end
