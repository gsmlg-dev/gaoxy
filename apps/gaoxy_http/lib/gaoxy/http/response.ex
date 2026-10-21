defmodule Gaoxy.HTTP.Response do
  @moduledoc "Protocol-neutral response operations for native HTTP endpoints."

  def send_resp(exchange, status, headers, body),
    do: backend(exchange).send_resp(exchange, status, headers, body)

  def send_file(exchange, status, headers, path, offset, length),
    do: backend(exchange).send_file(exchange, status, headers, path, offset, length)

  def send_chunked(exchange, status, headers) do
    with {:ok, exchange} <- Gaoxy.HTTP.Exchange.begin_stream(exchange),
         do: backend(exchange).send_chunked(exchange, status, headers)
  end

  def chunk(exchange, data), do: backend(exchange).chunk(exchange, data)
  def inform(exchange, status, headers), do: backend(exchange).inform(exchange, status, headers)
  def finish(exchange, trailers \\ []), do: backend(exchange).finish(exchange, trailers)

  defp backend(%{transport: nil}), do: Gaoxy.HTTP.HTTP1.Response
  defp backend(%{transport: module}), do: module
end
