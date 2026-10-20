defmodule Gaoxy.HTTP.HTTP2.Limits do
  @moduledoc false
  @receive_buffer 16_384
  # Hell delivers active-once. The qualified OTP 28 SSL internal transport profile
  # can aggregate 100 buffers plus one maximum TLS 1.2 record. Reserve deliveries
  # and copies separately from configurable parser carry and HPACK expansion.
  @max_delivery 100 * @receive_buffer + 18_437
  @defaults %{
    max_streams: 32,
    max_frame: 16_384,
    max_header_block: 16_384,
    table_size: 4_096,
    receive_window: 65_535,
    frame_timeout: 5_000,
    control_turn: 32,
    control_rate: 256
  }

  def normalize(input) when is_map(input) do
    limits = Map.merge(@defaults, input)

    if Map.keys(input) -- Map.keys(@defaults) == [] and
         Enum.all?(limits, fn {_, value} -> is_integer(value) and value > 0 end) and
         limits.max_frame in 16_384..65_535 and limits.receive_window <= 65_535 and
         limits.max_header_block <= 65_536 and limits.table_size <= 65_536 and
         limits.max_streams <= 128 and limits.control_rate <= 4_096 and
         limits.control_turn <= 128 do
      {:ok, limits}
    else
      {:error, :invalid_http2_limits}
    end
  end

  def normalize(_), do: {:error, :invalid_http2_limits}

  def receive_buffer, do: @receive_buffer

  def validate_host(transport) do
    active = Application.get_env(:ssl, :internal_active_n, 100)

    if Application.get_env(:kernel, :inet_backend, :inet) == :inet and
         (transport != :tls or (is_integer(active) and active in 1..100)),
       do: :ok,
       else: {:error, :unsupported_http2_host}
  end

  def reservation(http, h2) do
    %{
      connection: 16_777_216 + 65_535 + 4 * http.max_buffer_bytes + 8 * @max_delivery,
      decode: decode_reservation(h2, h2.max_header_block),
      stream: 2 * http.max_header_bytes + 4 * http.max_read_chunk + 65_536,
      writer: 4 * 16_384 + 1_024
    }
  end

  def decode_reservation(h2, block_bytes) do
    t = h2.table_size
    2 * block_bytes * (max(t, 128) + 2) + 512 * block_bytes + 2 * t
  end

  def validate_budget(http, h2, service) do
    reserves = reservation(http, h2)

    if service.max_bytes >=
         reserves.connection + reserves.decode + reserves.stream + reserves.writer and
         service.max_active >= 3,
       do: :ok,
       else: {:error, :http2_byte_budget}
  end
end
