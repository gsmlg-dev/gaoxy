defmodule Gaoxy.Proxy.GatewayConfigTest do
  use ExUnit.Case, async: false
  @moduletag :unit
  alias Gaoxy.HTTP.Router
  alias Gaoxy.Proxy.Gateway
  @moduletag :capture_log

  defmodule Endpoint do
    def init(body), do: {:ok, body}
    def call(exchange, body), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], body)
  end

  defp routes(body), do: [%{target: {Endpoint, body}}]

  defp options(drain),
    do: [
      id: :lifecycle,
      listener_sets: [
        [
          id: "web",
          endpoint: {Router, routes("old")},
          listeners: [http: [port: 0, limits: %{drain_timeout: drain}]]
        ]
      ]
    ]

  test "the supervisor budget cannot truncate a configured long drain" do
    child = Gateway.child_spec(options(45_000))
    assert child.shutdown == :infinity or child.shutdown >= 90_000
  end

  test "reload rejects malformed, duplicate and unknown options without exiting" do
    for options <- [nil, [:invalid], [timeout: 20, timeout: 30], [unknown: true]] do
      assert {:error, :invalid_reload_options} = Gateway.reload_routes(self(), "web", [], options)
    end
  end

  test "raw Router services need not provide the internal initialized flag" do
    service = %{
      id: :raw,
      transport: :tcp,
      ip: {127, 0, 0, 1},
      port: 0,
      handler: Gaoxy.HTTP.Connection,
      handler_mode: :native,
      handler_options: %{endpoint: {Router, routes("raw")}, http_limits: %{}}
    }

    assert {:ok, plan} = Gateway.compile(id: :raw, services: [service])
    assert {:ok, [_]} = Gateway.planned_services(plan)
  end
end
