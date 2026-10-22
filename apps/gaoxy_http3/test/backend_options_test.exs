defmodule Gaoxy.HTTP.HTTP3.BackendOptionsTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.{HTTP3}

  defmodule Endpoint do
    def init(options) do
      if options[:observer], do: send(options[:observer], :h3_backend_initialized)
      {:ok, options}
    end

    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "backend-options")
  end

  test "HTTP3 normalizes host polling before target initialization and keeps defaults" do
    options = [endpoint: {Endpoint, [observer: self()]}, tls: %{certfile: "cert", keyfile: "key"}]
    assert {:ok, default} = HTTP3.service_spec(options)
    assert default.abyss_options == []
    assert default.quic == %{alpn: ["h3"], poll_interval: 10}
    assert_receive :h3_backend_initialized
    assert {:ok, ^default} = HTTP3.service_spec(options ++ [abyss_options: []])
    assert_receive :h3_backend_initialized

    assert {:ok, tuned} =
             HTTP3.service_spec(options ++ [abyss_options: [event_batch: 1, poll_interval: 1]])

    assert tuned.abyss_options == [event_batch: 1]
    assert tuned.quic == %{alpn: ["h3"], poll_interval: 1}
    assert_receive :h3_backend_initialized
    assert {:ok, ^tuned} = Gaoxy.Config.service(tuned)
    refute_received :h3_backend_initialized

    for invalid <- [
          [handler: Endpoint],
          [tls: %{certfile: "other"}],
          [quic_options: []],
          [udp_buffer_size: 4096],
          [transport_options: [recbuf: 4096]],
          [event_batch: 0],
          [event_batch: 129],
          [event_batch: 1, event_batch: 2],
          [poll_interval: 0],
          [poll_interval: 1_001]
        ] do
      assert {:error, _} = HTTP3.service_spec(options ++ [abyss_options: invalid])
      refute_received :h3_backend_initialized
    end

    assert {:error, :invalid_http3_options} = HTTP3.service_spec(options ++ [hell_options: []])
    refute_received :h3_backend_initialized
  end
end
