defmodule Gaoxy.Proxy.HTTPFetchClientTest do
  use ExUnit.Case, async: true
  @moduletag :unit

  alias Gaoxy.Proxy.HTTPFetchClient, as: Client

  test "an ExSSL plaintext delivery preserves its bytes and acknowledgement" do
    bytes = :binary.copy(<<0, 255>>, 524_288)
    handle = %{stream: self()}
    ref = make_ref()

    assert {{:chunk, ^bytes, ^ref}, ^handle} =
             Client.event(handle, {:stream_chunk, self(), bytes, ref})

    assert :ok = Client.acknowledge(handle, ref)
    assert_receive {:stream_chunk_ack, ^ref}
  end

  test "the receive boundary includes framing carry and rejects larger or malformed deliveries" do
    bytes = :binary.copy("x", 1_048_576 + 65_536)
    handle = %{stream: self()}
    ref = make_ref()

    assert {{:chunk, ^bytes, ^ref}, ^handle} =
             Client.event(handle, {:stream_chunk, self(), bytes, ref})

    for invalid <- [bytes <> "x", nil, [bytes], {bytes}] do
      assert {{:error, :upstream_delivery_limit}, ^handle} =
               Client.event(handle, {:stream_chunk, self(), invalid, ref})
    end
  end

  test "admission reserves the full ExSSL delivery and framing windows before request inputs" do
    delivery_windows = 8 * (1_048_576 + 65_536)
    upload_windows = 8 * 65_536

    assert Client.reservation_bytes([], 0, 65_536) >= delivery_windows + upload_windows
  end
end
