defmodule Gaoxy.HTTP.HTTP2.Response do
  @moduledoc false
  defdelegate send_resp(exchange, status, headers, body), to: Gaoxy.HTTP.FramedResponse

  defdelegate send_file(exchange, status, headers, filename, offset, length),
    to: Gaoxy.HTTP.FramedResponse

  defdelegate send_chunked(exchange, status, headers), to: Gaoxy.HTTP.FramedResponse
  defdelegate chunk(exchange, bytes), to: Gaoxy.HTTP.FramedResponse
  defdelegate inform(exchange, status, headers), to: Gaoxy.HTTP.FramedResponse
  def finish(exchange, trailers \\ []), do: Gaoxy.HTTP.FramedResponse.finish(exchange, trailers)
end
