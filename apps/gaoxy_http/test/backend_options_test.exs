defmodule Gaoxy.HTTP.BackendOptionsTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.ListenerSet

  defmodule Endpoint do
    def init(options) do
      if options[:observer], do: send(options[:observer], :backend_endpoint_initialized)
      {:ok, options}
    end

    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "backend-options")
  end

  defmodule PhoenixEndpoint do
    def init(options), do: options
    def call(conn, _), do: Plug.Conn.send_resp(conn, 200, "backend-options")
  end

  test "default remains compatible and invalid backend options fail before target initialization" do
    options = [endpoint: {Endpoint, [observer: self()]}]
    assert {:ok, default} = Gaoxy.HTTP.service_spec(options)
    assert_receive :backend_endpoint_initialized
    assert {:ok, ^default} = Gaoxy.HTTP.service_spec(options ++ [hell_options: []])
    assert_receive :backend_endpoint_initialized

    for invalid <- [
          [handler_module: Endpoint],
          [num_acceptors: 65],
          [num_acceptors: 1, num_acceptors: 2],
          [transport_options: [ip: {0, 0, 0, 0}]],
          [transport_options: [active: true]],
          [transport_options: [nodelay: :yes]]
        ] do
      assert {:error, _} = Gaoxy.HTTP.service_spec(options ++ [hell_options: invalid])
      refute_received :backend_endpoint_initialized
    end

    assert {:error, :invalid_http_options} =
             Gaoxy.HTTP.service_spec(options ++ [abyss_options: []])

    assert {:error, :invalid_http_options} =
             Gaoxy.HTTP.service_spec(options ++ [hell_options: [], hell_options: tuning(2)])

    for transport <- [:tcp, :tls], key <- [:recbuf, :buffer] do
      assert {:error, {:unsupported_http_backend_option, ^key}} =
               Gaoxy.HTTP.service_spec(
                 options ++
                   [transport: transport, hell_options: [transport_options: [{key, 4096}]]]
               )

      refute_received :backend_endpoint_initialized
    end

    refute_received :backend_endpoint_initialized
  end

  test "listener roles reject the other backend and preflight rejects reserved options" do
    for {role, key} <- [http: :abyss_options, https: :abyss_options, http3: :hell_options] do
      assert {:error, {:field, [:listeners, ^role, ^key], :unknown_option}} =
               ListenerSet.plan(
                 id: :wrong_backend,
                 endpoint: {Endpoint, []},
                 listeners: [{role, [{key, []}]}]
               )

      assert_raise ArgumentError, fn ->
        Gaoxy.PhoenixAdapter.child_specs(PhoenixEndpoint, [{role, [{key, []}]}])
      end
    end

    assert {:ok, plan} =
             ListenerSet.plan(
               id: :invalid_backend,
               endpoint: {Endpoint, []},
               listeners: [http: [hell_options: [port: 9000]]]
             )

    assert {:error, {:unsupported_backend_option, :hell_options, :port}} =
             ListenerSet.preflight(plan)

    for role <- [:http, :https], key <- [:recbuf, :buffer] do
      listeners = [{role, [hell_options: [transport_options: [{key, 4096}]]]}]

      assert {:ok, plan} =
               ListenerSet.plan(
                 id: :owned_buffers,
                 endpoint: {Endpoint, []},
                 listeners: listeners
               )

      assert {:error, {:unsupported_http_backend_option, ^key}} = ListenerSet.preflight(plan)
      [child] = Gaoxy.PhoenixAdapter.child_specs(PhoenixEndpoint, listeners)
      {module, function, arguments} = child.start

      assert {:error, {:unsupported_http_backend_option, ^key}} =
               apply(module, function, arguments)
    end
  end

  defp tuning(count),
    do: [
      num_acceptors: count,
      transport_options: [backlog: 32, nodelay: false, keepalive: true, sndbuf: 32_768]
    ]
end
