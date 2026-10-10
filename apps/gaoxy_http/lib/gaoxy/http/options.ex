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
      {:ok, %{endpoint: {module, initialized}, http_limits: limits, initialized: true}}
    end
  end

  def normalize(_), do: {:error, :invalid_http_options}

  defp initialize(_, options, true), do: {:ok, options}
  defp initialize(module, options, false), do: module.init(options)
  defp initialize(_, _, _), do: {:error, :invalid_http_options}
end
