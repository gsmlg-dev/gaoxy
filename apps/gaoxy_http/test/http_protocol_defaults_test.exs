defmodule Gaoxy.HTTP.ProtocolDefaultsTest do
  use ExUnit.Case, async: true
  @moduletag :unit

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(exchange, _options), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "default")
  end

  defmodule FixturePlug do
    def init(options), do: options
    def call(conn, _options), do: Plug.Conn.send_resp(conn, 200, "default")
  end

  @tls %{certfile: "cert.pem", keyfile: "key.pem"}

  test "HTTPS prefers H2 and supplies its omitted byte budget" do
    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(endpoint: {Endpoint, []}, transport: :tls, tls: @tls)

    assert spec.handler_options.protocols == [:http2, :http1]
    assert spec.tls.alpn == ["h2", "http/1.1"]
    assert spec.limits.max_bytes == 268_435_456
    assert spec.handler_options.h2c == :disabled
  end

  test "plain HTTP keeps H1 and the core byte budget" do
    assert {:ok, spec} = Gaoxy.HTTP.service_spec(endpoint: {Endpoint, []})
    assert spec.handler_options.protocols == [:http1]
    assert spec.limits.max_bytes == 1_048_576
  end

  test "explicit H1 HTTPS retains its protocol and budget" do
    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               transport: :tls,
               tls: @tls,
               protocols: [:http1]
             )

    assert spec.handler_options.protocols == [:http1]
    assert spec.tls.alpn == ["http/1.1"]
    assert spec.limits.max_bytes == 1_048_576
  end

  test "explicit prior knowledge h2c gets an omitted H2 budget" do
    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               protocols: [:http2],
               h2c: :prior_knowledge
             )

    assert spec.handler_options.protocols == [:http2]
    assert spec.handler_options.h2c == :prior_knowledge
    assert spec.limits.max_bytes == 268_435_456
  end

  test "mixed TCP accepts endpoints and Plugs with the native handler and H2 budget" do
    for endpoint <- [[endpoint: {Endpoint, []}], [plug: {FixturePlug, []}]] do
      assert {:ok, spec} =
               Gaoxy.HTTP.service_spec(
                 endpoint ++ [transport: :tcp, protocols: [:http2, :http1], h2c: :prior_knowledge]
               )

      assert spec.transport == :tcp
      assert spec.handler == Gaoxy.HTTP.Connection
      assert spec.handler_options.protocols == [:http2, :http1]
      assert spec.handler_options.h2c == :prior_knowledge
      assert spec.limits.max_bytes == 268_435_456
    end
  end

  test "invalid cleartext combinations and unknown values stay rejected" do
    for options <- [
          [protocols: [:http2]],
          [protocols: [:http2, :http1]],
          [protocols: [:http1], h2c: :prior_knowledge],
          [protocols: [:http1, :http2], h2c: :prior_knowledge],
          [protocols: [:unknown], h2c: :prior_knowledge],
          [protocols: [:http2, :http1], h2c: :auto],
          [transport: :tls, tls: @tls, protocols: [:http2, :http1], h2c: :prior_knowledge]
        ] do
      assert {:error, :invalid_http_protocols} =
               Gaoxy.HTTP.service_spec([endpoint: {Endpoint, []}] ++ options)
    end

    assert {:error, :http2_byte_budget} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               protocols: [:http2, :http1],
               h2c: :prior_knowledge,
               limits: %{max_bytes: 1_048_576}
             )

    assert {:error, :http2_ingress_budget} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               protocols: [:http2, :http1],
               h2c: :prior_knowledge,
               http_limits: %{max_buffer_bytes: 16_384}
             )
  end

  test "Phoenix mixed HTTP options create one native listener" do
    assert [%{start: {Gaoxy.HTTP.ListenerSet, :start_link, [options]}}] =
             Gaoxy.PhoenixAdapter.child_specs(FixturePlug,
               http: [port: 0, protocols: [:http2, :http1], h2c: :prior_knowledge],
               https: false
             )

    assert options[:plan].service_ids == %{http: Module.concat(FixturePlug, "HTTP")}
    assert {:ok, [http]} = Gaoxy.HTTP.ListenerSet.planned_services(options[:plan])

    assert http.transport == :tcp
    assert http.handler == Gaoxy.HTTP.Connection
    assert http.handler_options.protocols == [:http2, :http1]
    assert http.handler_options.h2c == :prior_knowledge
    assert {Gaoxy.HTTP.ListenerSet.Target, :planned} = http.handler_options.endpoint

    assert {:endpoint, Gaoxy.HTTP.PlugEndpoint,
            {Gaoxy.PhoenixWebSocket, {FixturePlug, []}, :endpoint_managed}} =
             options[:plan].target
  end

  test "H2 defaults preserve supplied limit fields and insufficient-budget rejection" do
    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               transport: :tls,
               tls: @tls,
               limits: %{max_active: 7, max_bytes: 536_870_912}
             )

    assert spec.limits.max_active == 7
    assert spec.limits.max_bytes == 536_870_912

    assert {:error, :http2_byte_budget} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               transport: :tls,
               tls: @tls,
               limits: %{max_bytes: 1_048_576}
             )

    assert {:error, :http2_byte_budget} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               transport: :tls,
               tls: @tls,
               limits: %{max_active: 2}
             )
  end

  test "Phoenix delegates omitted HTTPS protocols while plain HTTP keeps H1" do
    assert [%{start: {Gaoxy.HTTP.ListenerSet, :start_link, [options]}}] =
             Gaoxy.PhoenixAdapter.child_specs(FixturePlug,
               http: [port: 0],
               https: [port: 0, certfile: "cert.pem", keyfile: "key.pem"]
             )

    assert options[:plan].service_ids == %{
             http: Module.concat(FixturePlug, "HTTP"),
             https: Module.concat(FixturePlug, "HTTPS")
           }

    assert {:ok, [http, https]} = Gaoxy.HTTP.ListenerSet.planned_services(options[:plan])

    assert http.handler_options.protocols == [:http1]
    assert https.handler_options.protocols == [:http2, :http1]
    assert https.tls.alpn == ["h2", "http/1.1"]
    assert https.limits.max_bytes == 268_435_456
  end
end
