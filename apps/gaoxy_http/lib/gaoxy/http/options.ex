defmodule Gaoxy.HTTP.Options do
  @moduledoc false
  @defaults %{
    max_request_line: 8_192,
    max_header_bytes: 32_768,
    max_headers: 100,
    max_body_bytes: 8_388_608,
    max_chunk_line: 1_024,
    max_trailer_bytes: 8_192,
    max_trailers: 32,
    max_read_chunk: 16_384,
    max_buffer_bytes: 65_536,
    request_timeout: 30_000,
    header_timeout: 5_000,
    read_timeout: 5_000,
    write_timeout: 5_000
  }

  def normalize(%{endpoint: {module, options}, http_limits: input} = original)
      when is_atom(module) and is_map(input) do
    with true <-
           Enum.all?(Map.keys(input), &Map.has_key?(@defaults, &1)) ||
             {:error, :unknown_http_limit},
         limits = Map.merge(@defaults, input),
         true <-
           Enum.all?(limits, fn {_key, value} -> is_integer(value) and value > 0 end) ||
             {:error, :invalid_http_limit},
         true <-
           limits.max_read_chunk <= limits.max_buffer_bytes ||
             {:error, :invalid_http_limit},
         true <-
           (Code.ensure_loaded?(module) and function_exported?(module, :init, 1) and
              function_exported?(module, :call, 2)) || {:error, :invalid_endpoint},
         {:ok, initialized} <- initialize(module, options, Map.get(original, :initialized, false)) do
      with {:ok, h2} <- Gaoxy.HTTP.HTTP2.Limits.normalize(Map.get(original, :h2_limits, %{})),
           protocols = Map.get(original, :protocols, [:http1]),
           h2c = Map.get(original, :h2c, :disabled),
           extended_connect = Map.get(original, :extended_connect, false),
           true <- is_boolean(extended_connect) || {:error, :invalid_extended_connect},
           true <-
             protocols in [[:http1], [:http2], [:http2, :http1]] ||
               {:error, :invalid_http_protocols},
           true <- h2c in [:disabled, :prior_knowledge] || {:error, :invalid_http_protocols},
           true <-
             (h2c != :prior_knowledge or protocols == [:http2]) ||
               {:error, :invalid_http_protocols},
           true <-
             (:http2 not in protocols or h2.max_frame + 9 <= limits.max_buffer_bytes) ||
               {:error, :http2_ingress_budget} do
        {:ok,
         %{
           endpoint: {module, initialized},
           http_limits: limits,
           initialized: true,
           protocols: protocols,
           h2c: h2c,
           extended_connect: extended_connect,
           h2_limits: h2
         }}
      end
    end
  end

  def normalize(_), do: {:error, :invalid_http_options}

  defp initialize(_, options, true), do: {:ok, options}
  defp initialize(module, options, false), do: module.init(options)
  defp initialize(_, _, _), do: {:error, :invalid_http_options}
end
