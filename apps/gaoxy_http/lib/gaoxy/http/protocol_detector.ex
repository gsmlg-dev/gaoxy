defmodule Gaoxy.HTTP.ProtocolDetector do
  @moduledoc false
  @preface "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

  # The carry is a previously matching prefix. Inspect only enough new input to
  # decide; replay remains iodata until the selected engine checks its bound.
  def classify(carry, bytes) when is_binary(carry) and is_binary(bytes) do
    offset = byte_size(carry)
    size = min(byte_size(bytes), byte_size(@preface) - offset)

    cond do
      binary_part(bytes, 0, size) != binary_part(@preface, offset, size) ->
        {:http1, [carry, bytes]}

      offset + size == byte_size(@preface) ->
        {:http2, [carry, bytes]}

      true ->
        {:more, :binary.copy(carry <> bytes)}
    end
  end
end
