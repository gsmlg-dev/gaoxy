defmodule Gaoxy.Proxy.GatewayPlanTest do
  use ExUnit.Case, async: false
  @moduletag :unit
  alias Gaoxy.Proxy.Gateway
  alias Gaoxy.Proxy.Gateway.Upstream
  alias Gaoxy.HTTP.Router
  @moduletag :capture_log

  defmodule Endpoint do
    def init(body), do: {:ok, body}
    def call(exchange, body), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], body)
  end

  defmodule Blocked do
    def init(body) do
      send(Process.whereis(Gaoxy.Proxy.GatewayPlanTest.Gate), {:preparing, self()})

      receive do
        :continue -> {:ok, body}
      after
        3000 -> {:error, :gate_timeout}
      end
    end

    def call(exchange, body), do: Endpoint.call(exchange, body)
  end

  defp options(id, routes),
    do: [
      id: id,
      listener_sets: [[id: id, endpoint: {Router, routes}, listeners: [http: [port: 0]]]]
    ]

  test "pure plans retain file references and never initialize route endpoints" do
    assert {:ok, target} =
             Upstream.fixed(%{
               upstream: "https://example.test",
               connect_address: {127, 0, 0, 1},
               cacertfile: "/does/not/exist"
             })

    options = options("web", [%{target: target}, %{target: {Blocked, "never initialized"}}])
    assert {:ok, first} = Gateway.compile(options)
    assert {:ok, ^first} = Gateway.compile(options)
    assert {:ok, ^first} = Gateway.compile(first)
    assert Gaoxy.Proxy.Gateway.Declaration.owner_independent?(first)
    refute_receive {:preparing, _}
    assert {:error, _} = Gateway.compile(options("web", [%{target: {Endpoint, self()}}]))

    for invalid <- [
          [id: nil],
          [id: :ok, name: "invalid"],
          [services: [%{}]],
          %Gaoxy.Proxy.Gateway.Plan{sets: :invalid}
        ] do
      assert {:error, _} = Gateway.compile(invalid)
    end
  end

  @tag :tmp_dir
  test "invalid trust files produce a structured preparation error", %{tmp_dir: dir} do
    path = Path.join(dir, "empty.pem")

    for bytes <- ["", "not a certificate"] do
      File.write!(path, bytes)

      assert {:ok, {_, declaration}} =
               Upstream.fixed(%{
                 upstream: "https://localhost:443",
                 connect_address: {127, 0, 0, 1},
                 cacertfile: path
               })

      assert {:error, :invalid_trust} = Upstream.materialize(declaration)
    end
  end
end
