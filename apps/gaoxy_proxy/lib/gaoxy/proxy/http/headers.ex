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
    with {:ok, fields} <- normalize(exchange.request.headers),
         {:ok, policy} <- trailer_policy(fields, exchange.limits),
         policy = distrust_forwarding_trailers(policy),
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
        |> declare_trailers(policy.allowed)

      fields = fields ++ forwarding(exchange)

      with :ok <- header_limit(fields, exchange.limits), do: {:ok, fields, policy}
    end
  end

  defp distrust_forwarding_trailers(policy) do
    {dropped, allowed} = Enum.split_with(policy.allowed, &forwarding_field?/1)
    %{policy | allowed: allowed, dropped: policy.dropped ++ dropped}
  end

  defp forwarding_field?(name),
    do: name in ["forwarded", "x-real-ip"] or String.starts_with?(name, "x-forwarded-")

  def response(exchange, status, raw_fields) do
    with {:ok, fields} <- normalize(raw_fields),
         {:ok, policy} <- trailer_policy(fields, exchange.limits),
         fields = Enum.reject(fields, fn {name, _} -> name in policy.dropped end),
         true <-
           (policy.allowed == [] or trailers_supported?(exchange, status, fields)) ||
             {:error, :invalid_proxy_trailers},
         fields = declare_trailers(fields, policy.allowed),
         :ok <- header_limit(fields, exchange.limits) do
      {:ok, fields, policy}
    end
  end

  def trailers(raw_fields, policy) do
    with {:ok, fields} <- normalize(raw_fields),
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
    declared = tokens(fields, "trailer")
    dropped = Enum.uniq(@hop ++ tokens(fields, "connection"))

    cond do
      not Enum.all?(declared, &(Regex.match?(@token, &1) and &1 not in @forbidden_trailers)) ->
        {:error, :invalid_proxy_trailers}

      length(declared) > limits.max_trailers ->
        {:error, :proxy_trailer_limit}

      true ->
        {:ok,
         %{
           allowed: declared |> Enum.reject(&(&1 in dropped)) |> Enum.uniq(),
           dropped: dropped,
           max_count: limits.max_trailers,
           max_bytes: limits.max_trailer_bytes
         }}
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

    [{"x-forwarded-for", address |> :inet.ntoa() |> to_string()}] ++
      host_fields ++ [{"x-forwarded-proto", scheme}]
  end

  defp tokens(fields, name) do
    for {^name, value} <- fields,
        token <- String.split(value, ","),
        do: token |> String.trim() |> String.downcase()
  end

  defp normalize(fields) when is_list(fields) do
    if Enum.all?(fields, fn
         {name, value} when is_binary(name) and is_binary(value) ->
           Regex.match?(@token, name) and
             Enum.all?(:binary.bin_to_list(value), &(&1 == 9 or (&1 >= 32 and &1 != 127)))

         _ ->
           false
       end) do
      {:ok, Enum.map(fields, fn {name, value} -> {String.downcase(name), value} end)}
    else
      {:error, :invalid_proxy_headers}
    end
  end

  defp normalize(_), do: {:error, :invalid_proxy_headers}

  defp header_limit(fields, limits) do
    if field_bytes(fields) + 2 <= limits.max_header_bytes,
      do: :ok,
      else: {:error, :proxy_header_limit}
  end

  defp field_bytes(fields),
    do:
      Enum.reduce(fields, 0, fn {name, value}, size ->
        size + byte_size(name) + byte_size(value) + 4
      end)
end
