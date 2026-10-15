defmodule Gaoxy.HTTP.HTTP2.Frame do
  @moduledoc false

  def decode(bytes, _limit) when byte_size(bytes) < 9, do: :more

  def decode(<<length::24, type, flags, _::1, id::31, tail::binary>>, limit) do
    cond do
      length > limit ->
        {:error, :frame_size_error}

      byte_size(tail) < length ->
        :more

      true ->
        <<payload::binary-size(length), rest::binary>> = tail
        {:ok, %{type: type, flags: flags, id: id, payload: payload}, rest}
    end
  end

  def encode(type, flags, id, payload),
    do: [<<IO.iodata_length(payload)::24, type, flags, 0::1, id::31>>, payload]

  def flag?(flags, bit), do: Bitwise.band(flags, bit) != 0

  def code(:no_error), do: 0
  def code(:protocol_error), do: 1
  def code(:internal_error), do: 2
  def code(:flow_control_error), do: 3
  def code(:settings_timeout), do: 4
  def code(:stream_closed), do: 5
  def code(:frame_size_error), do: 6
  def code(:refused_stream), do: 7
  def code(:cancel), do: 8
  def code(:compression_error), do: 9
  def code(:enhance_your_calm), do: 11
end
