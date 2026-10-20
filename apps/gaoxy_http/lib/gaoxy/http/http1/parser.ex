defmodule Gaoxy.HTTP.HTTP1.Parser do
  @moduledoc "Bounded HTTP/1 request-head parsing with a strict, unambiguous framing policy."
  alias Gaoxy.HTTP.Request

  @defaults %{
    max_request_line: 8_192,
    max_header_bytes: 32_768,
    max_headers: 100,
    max_body_bytes: 8_388_608
  }
  @token ~r/\A[!#$%&'*+.^_`|~0-9A-Za-z-]+\z/

  def parse_head(bytes, options \\ %{}) when is_binary(bytes) do
    limits = Map.merge(@defaults, options)

    case :binary.match(bytes, "\r\n\r\n") do
      {size, 4} ->
        <<head::binary-size(^size), _::binary-size(4), rest::binary>> = bytes

        if size + 4 > limits.max_header_bytes do
          {:error, 431, :header_bytes_limit}
        else
          with {:ok, request} <- parse_lines(:binary.copy(head), limits) do
            {:ok, %{request | head_bytes: size + 4}, :binary.copy(rest)}
          end
        end

      :nomatch ->
        incomplete(bytes, limits)
    end
  end

  defp incomplete(bytes, limits) do
    first_line_size =
      case :binary.match(bytes, "\r\n") do
        {size, 2} -> size
        :nomatch -> byte_size(bytes)
      end

    cond do
      invalid_newlines?(bytes) -> {:error, 400, :line_ending}
      first_line_size > limits.max_request_line -> {:error, 414, :request_line_limit}
      byte_size(bytes) > limits.max_header_bytes -> {:error, 431, :header_bytes_limit}
      true -> :more
    end
  end

  defp parse_lines(head, limits) do
    [line | fields] = :binary.split(head, "\r\n", [:global])

    with :ok <- bound(byte_size(line), limits.max_request_line, 414, :request_line_limit),
         :ok <- bound(length(fields), limits.max_headers, 431, :header_count_limit),
         {:ok, method, target, version} <- request_line(line),
         {:ok, headers} <- headers(fields, []),
         {:ok, target_info} <- target(method, target),
         {:ok, host, port} <- authority(headers, target_info, version),
         {:ok, body} <- framing(headers, version, limits),
         {:ok, expect} <- expectation(headers, version) do
      {:ok,
       struct!(
         Request,
         Map.merge(target_info, %{
           method: method,
           target: target,
           version: version,
           host: host,
           port: port,
           headers: headers,
           body: body,
           keep_alive: keep_alive?(headers, version),
           expect_continue: expect
         })
       )}
    end
  end

  defp request_line(line) do
    case :binary.split(line, " ", [:global]) do
      [method, target, version] when method != "" and target != "" ->
        with true <- Regex.match?(@token, method) || {:error, 400, :method},
             {:ok, version} <- version(version) do
          {:ok, method, target, version}
        end

      _ ->
        {:error, 400, :request_line}
    end
  end

  defp version("HTTP/1.1"), do: {:ok, :"HTTP/1.1"}
  defp version("HTTP/1.0"), do: {:ok, :"HTTP/1.0"}
  defp version("HTTP/" <> _), do: {:error, 505, :http_version}
  defp version(_), do: {:error, 400, :request_line}

  @doc false
  def parse_fields(lines), do: headers(lines, [])

  defp headers([], acc), do: {:ok, Enum.reverse(acc)}

  defp headers([line | rest], acc) do
    case :binary.split(line, ":") do
      [name, value] ->
        if Regex.match?(@token, name) and valid_field_value?(value) do
          headers(rest, [{String.downcase(name), trim_ows(value)} | acc])
        else
          {:error, 400, :header}
        end

      _ ->
        {:error, 400, :header}
    end
  end

  defp valid_field_value?(bytes) do
    for(<<byte <- bytes>>, do: byte == 9 or byte in 32..126 or byte >= 128)
    |> Enum.all?()
  end

  defp trim_ows(<<byte, rest::binary>>) when byte in [32, 9], do: trim_ows(rest)
  defp trim_ows(bytes), do: trim_trailing_ows(bytes)
  defp trim_trailing_ows(<<>>), do: ""

  defp trim_trailing_ows(bytes) do
    if :binary.last(bytes) in [32, 9],
      do: trim_trailing_ows(binary_part(bytes, 0, byte_size(bytes) - 1)),
      else: bytes
  end

  defp target(method, value) do
    cond do
      not valid_target?(value) -> {:error, 400, :request_target}
      value == "*" and method == "OPTIONS" -> {:ok, path_info(:asterisk, "*")}
      method == "CONNECT" -> connect_target(value)
      String.starts_with?(value, "/") -> {:ok, path_info(:origin, value)}
      true -> absolute_target(value)
    end
  end

  defp valid_target?(bytes) do
    Enum.all?(:binary.bin_to_list(bytes), &(&1 in 33..126 and &1 not in [?#, ?\\])) and
      not Regex.match?(~r/%(?![0-9a-fA-F]{2})/, bytes)
  end

  defp path_info(form, value) do
    [path | query] = :binary.split(value, "?")
    %{target_form: form, path: path, query_string: List.first(query) || "", scheme: nil}
  end

  defp connect_target(value) do
    with {:ok, host, port} <- parse_authority(value),
         true <- not is_nil(port) || {:error, 400, :authority} do
      {:ok, Map.merge(path_info(:authority, value), %{host: host, port: port})}
    end
  end

  defp absolute_target(value) do
    uri = URI.parse(value)

    if uri.scheme in ["http", "https"] and is_binary(uri.authority) and
         is_nil(uri.userinfo) and is_nil(uri.fragment) do
      with {:ok, host, port} <- parse_authority(uri.authority) do
        scheme = if uri.scheme == "https", do: :https, else: :http

        {:ok,
         %{
           target_form: :absolute,
           path: uri.path || "/",
           query_string: uri.query || "",
           scheme: scheme,
           host: host,
           port: port || default_port(scheme)
         }}
      end
    else
      {:error, 400, :request_target}
    end
  end

  defp authority(headers, target, version) do
    case values(headers, "host") do
      [] when version == :"HTTP/1.0" ->
        {:ok, target[:host], target[:port]}

      [value] ->
        with {:ok, host, port} <- parse_authority(value) do
          if target[:host] &&
               (host != target.host or (port || default_port(target.scheme)) != target.port) do
            {:error, 400, :authority_mismatch}
          else
            {:ok, host, port || target[:port]}
          end
        end

      _ ->
        {:error, 400, :host}
    end
  end

  def parse_authority("[" <> rest) do
    case :binary.split(rest, "]") do
      [host, suffix] ->
        with {:ok, _} <- :inet.parse_ipv6strict_address(:binary.bin_to_list(host)),
             {:ok, port} <- port_suffix(suffix) do
          {:ok, String.downcase(host), port}
        else
          _ -> {:error, 400, :authority}
        end

      _ ->
        {:error, 400, :authority}
    end
  end

  def parse_authority(value) do
    [host | port] = :binary.split(value, ":")
    suffix = if port == [], do: "", else: ":" <> hd(port)

    with true <- Regex.match?(~r/\A[A-Za-z0-9._~-]+\z/, host),
         {:ok, port} <- port_suffix(suffix) do
      {:ok, String.downcase(host), port}
    else
      _ -> {:error, 400, :authority}
    end
  end

  defp port_suffix(""), do: {:ok, nil}

  defp port_suffix(":" <> port) do
    case decimal(port) do
      {:ok, number} when number in 1..65_535 -> {:ok, number}
      _ -> {:error, 400, :authority}
    end
  end

  defp port_suffix(_), do: {:error, 400, :authority}

  defp default_port(:https), do: 443
  defp default_port(_), do: 80

  defp framing(headers, version, limits) do
    case {values(headers, "content-length"), values(headers, "transfer-encoding")} do
      {[], []} ->
        {:ok, :none}

      {[length], []} ->
        with {:ok, size} <- decimal(length),
             :ok <- bound(size, limits.max_body_bytes, 413, :body_limit) do
          {:ok, {:length, size}}
        else
          :error -> {:error, 400, :content_length}
          error -> error
        end

      {[], [encoding]} when version == :"HTTP/1.1" ->
        if String.downcase(encoding) == "chunked",
          do: {:ok, :chunked},
          else: {:error, 400, :transfer_encoding}

      _ ->
        {:error, 400, :ambiguous_framing}
    end
  end

  defp decimal(value) do
    if(byte_size(value) <= 20 and Regex.match?(~r/\A[0-9]+\z/, value),
      do: Integer.parse(value),
      else: :error
    )
    |> case do
      {number, ""} -> {:ok, number}
      _ -> :error
    end
  end

  defp expectation(headers, version) do
    case values(headers, "expect") do
      [] ->
        {:ok, false}

      [value] when version == :"HTTP/1.1" ->
        if String.downcase(value) == "100-continue",
          do: {:ok, true},
          else: {:error, 417, :expectation}

      _ ->
        {:error, 417, :expectation}
    end
  end

  defp keep_alive?(headers, version) do
    tokens =
      headers
      |> values("connection")
      |> Enum.flat_map(&String.split(String.downcase(&1), ","))
      |> Enum.map(&String.trim/1)

    "close" not in tokens and (version == :"HTTP/1.1" or "keep-alive" in tokens)
  end

  defp values(headers, name), do: for({^name, value} <- headers, do: value)
  defp bound(size, max, _status, _reason) when size <= max, do: :ok
  defp bound(_size, _max, status, reason), do: {:error, status, reason}
  defp invalid_newlines?(bytes), do: Regex.match?(~r/(?<!\r)\n|\r[^\n]/, bytes)
end
