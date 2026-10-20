defmodule Gaoxy.Proxy.HTTP.Headers do
  @moduledoc false

  @token ~r/\A[!#$%&'*+.^_`|~0-9A-Za-z-]+\z/
  @hop ~w(connection proxy-connection keep-alive proxy-authenticate proxy-authorization
          te trailer transfer-encoding upgrade)
  @forbidden_trailers ~w(content-length transfer-encoding host connection trailer te upgrade
                        keep-alive proxy-connection authorization proxy-authorization
                        proxy-authenticate www-authenticate content-encoding content-type
                        content-range expect cache-control cookie set-cookie)

  def request(exchange) do
    with :ok <- preflight(exchange.request.headers, 256),
         {:ok, fields} <- normalize(exchange.request.headers),
         {:ok, policy} <- trailer_policy(fields, exchange.limits),
         policy = distrust_forwarding_trailers(policy),
         {:ok, forwarded} <- forwarding(exchange),
         true <-
           (policy.allowed == [] or exchange.request.body == :chunked or
              exchange.request.version in [:"HTTP/2", :"HTTP/3"]) ||
             {:error, :invalid_proxy_trailers} do
      fields =
        Enum.reject(fields, fn {name, _} ->
          name in policy.dropped or name in ["host", "expect"] or forwarding_field?(name) or
            (name == "content-length" and policy.allowed != [] and
               exchange.request.version in [:"HTTP/2", :"HTTP/3"])
        end)
        |> request_cookies(exchange.request.version)
        |> declare_trailers(policy.allowed)

      fields = fields ++ forwarded

      with :ok <- valid_policy(policy),
           :ok <- header_limit(fields, exchange.limits),
           do: {:ok, fields, policy}
    end
  end

  # RFC 9113 / RFC 9114 allow splitting Cookie on multiplexed hops. Rejoin
  # before handing the fields to an upstream serializer, preserving H1 input.
  defp request_cookies(fields, version) when version in [:"HTTP/2", :"HTTP/3"] do
    case for({"cookie", value} <- fields, do: value) do
      [] -> fields
      [_] -> fields
      values -> join_cookies(fields, Enum.join(values, "; "))
    end
  end

  defp request_cookies(fields, _version), do: fields

  defp join_cookies([{"cookie", _} | rest], joined),
    do: [{"cookie", joined} | Enum.reject(rest, &match?({"cookie", _}, &1))]

  defp join_cookies([field | rest], joined), do: [field | join_cookies(rest, joined)]

  defp distrust_forwarding_trailers(policy) do
    {dropped, allowed} = Enum.split_with(policy.allowed, &forwarding_field?/1)
    %{policy | allowed: allowed, dropped: policy.dropped ++ dropped}
  end

  defp forwarding_field?(name),
    do: name in ["forwarded", "x-real-ip"] or String.starts_with?(name, "x-forwarded-")

  def response(exchange, status, raw_fields) do
    with :ok <- preflight(raw_fields, 256),
         {:ok, fields} <- normalize(raw_fields),
         {:ok, policy} <- trailer_policy(fields, exchange.limits),
         fields = Enum.reject(fields, fn {name, _} -> name in policy.dropped end),
         true <-
           (policy.allowed == [] or trailers_supported?(exchange, status, fields)) ||
             {:error, :invalid_proxy_trailers},
         fields = declare_trailers(fields, policy.allowed),
         :ok <- valid_policy(policy),
         :ok <- header_limit(fields, exchange.limits) do
      {:ok, fields, policy}
    end
  end

  def trailers(raw_fields, policy) do
    with :ok <- valid_policy(policy),
         :ok <- preflight(raw_fields, 128),
         {:ok, fields} <- normalize(raw_fields),
         fields = Enum.reject(fields, fn {name, _} -> name in policy.dropped end),
         true <-
           Enum.all?(fields, fn {name, _} ->
             name in policy.allowed and name not in @forbidden_trailers
           end) || {:error, :invalid_proxy_trailers},
         true <-
           (length(fields) <= policy.max_count and field_bytes(fields) + 2 <= policy.max_bytes) ||
             {:error, :proxy_trailer_limit} do
      {:ok, fields}
    end
  end

  defp trailer_policy(fields, limits) do
    with {:ok, declared} <- tokens(fields, "trailer"),
         {:ok, connection} <- tokens(fields, "connection"),
         true <- valid_limits?(limits) || {:error, :invalid_proxy_trailers} do
      dropped = Enum.uniq(@hop ++ connection)

      cond do
        not Enum.all?(declared, &(Regex.match?(@token, &1) and &1 not in @forbidden_trailers)) ->
          {:error, :invalid_proxy_trailers}

        length(declared) > min(limits.max_trailers, 128) ->
          {:error, :proxy_trailer_limit}

        true ->
          {:ok,
           %{
             allowed: declared |> Enum.reject(&(&1 in dropped)) |> Enum.uniq(),
             dropped: dropped,
             max_count: min(limits.max_trailers, 128),
             max_bytes: min(limits.max_trailer_bytes, 65_536)
           }}
      end
    end
  end

  defp trailers_supported?(exchange, status, fields) do
    exchange.request.version in [:"HTTP/1.1", :"HTTP/2", :"HTTP/3"] and
      exchange.request.method != "HEAD" and
      status not in [204, 205, 304] and
      not Enum.any?(fields, fn {name, _} -> name == "content-length" end)
  end

  defp declare_trailers(fields, []), do: fields
  defp declare_trailers(fields, names), do: fields ++ [{"trailer", Enum.join(names, ", ")}]

  defp forwarding(exchange) do
    host =
      Enum.find_value(exchange.request.headers, exchange.request.host, fn
        {"host", value} -> value
        _ -> nil
      end)

    host_fields = if host, do: [{"x-forwarded-host", host}], else: []
    scheme = if Gaoxy.HTTP.Exchange.secure?(exchange), do: "https", else: "http"
    {address, _port} = exchange.peer

    fields =
      [{"x-forwarded-for", address |> :inet.ntoa() |> to_string()}] ++
        host_fields ++ [{"x-forwarded-proto", scheme}]

    with :ok <- preflight(fields, 256), do: normalize(fields)
  end

  defp tokens(fields, name) do
    values = for {^name, value} <- fields, do: value

    with :ok <- token_count(values, 0) do
      tokens =
        for value <- values,
            token <- String.split(value, ","),
            do: token |> String.trim() |> String.downcase() |> :binary.copy()

      if Enum.all?(tokens, &Regex.match?(@token, &1)),
        do: {:ok, tokens},
        else: {:error, :invalid_proxy_trailers}
    end
  end

  defp token_count([], _count), do: :ok

  defp token_count([value | rest], count) do
    case commas(value, count + 1) do
      {:ok, next} -> token_count(rest, next)
      error -> error
    end
  end

  defp commas(_, count) when count > 128, do: {:error, :proxy_trailer_limit}
  defp commas(<<>>, count), do: {:ok, count}
  defp commas(<<?,, rest::binary>>, count), do: commas(rest, count + 1)
  defp commas(<<_, rest::binary>>, count), do: commas(rest, count)

  defp valid_limits?(limits) do
    is_integer(limits.max_trailers) and limits.max_trailers > 0 and
      is_integer(limits.max_trailer_bytes) and limits.max_trailer_bytes > 0
  end

  defp valid_policy(policy) do
    case Gaoxy.Proxy.ManagedH2Envelope.validate_trailer_policy(policy) do
      :ok -> :ok
      _ -> {:error, :invalid_proxy_trailers}
    end
  end

  # Traverse the original proper pair list and its backing before grammar,
  # lowercase, splitting, filtering or external-size work can copy it.
  defp preflight(fields, count), do: preflight(fields, count, 0, 0)
  defp preflight([], _count, _logical, _backing), do: :ok

  defp preflight([{name, value} | rest], count, logical, backing)
       when count > 0 and is_binary(name) and is_binary(value) do
    logical = logical + byte_size(name) + byte_size(value)
    backing = backing + :binary.referenced_byte_size(name) + :binary.referenced_byte_size(value)

    if logical <= 65_536 and backing <= 65_536,
      do: preflight(rest, count - 1, logical, backing),
      else: {:error, :proxy_header_limit}
  end

  defp preflight(_, _, _, _), do: {:error, :invalid_proxy_headers}

  defp normalize(fields) when is_list(fields) do
    if Enum.all?(fields, fn
         {name, value} when is_binary(name) and is_binary(value) ->
           Regex.match?(@token, name) and
             Enum.all?(:binary.bin_to_list(value), &(&1 == 9 or (&1 >= 32 and &1 != 127)))

         _ ->
           false
       end) do
      {:ok,
       Enum.map(fields, fn {name, value} ->
         {:binary.copy(String.downcase(name)), :binary.copy(value)}
       end)}
    else
      {:error, :invalid_proxy_headers}
    end
  end

  defp normalize(_), do: {:error, :invalid_proxy_headers}

  defp header_limit(fields, limits) do
    if length(fields) <= min(Map.get(limits, :max_headers, 256), 256) and
         field_bytes(fields) + 2 <= min(limits.max_header_bytes, 65_536),
       do: :ok,
       else: {:error, :proxy_header_limit}
  end

  defp field_bytes(fields),
    do:
      Enum.reduce(fields, 0, fn {name, value}, size ->
        size + byte_size(name) + byte_size(value) + 4
      end)
end
