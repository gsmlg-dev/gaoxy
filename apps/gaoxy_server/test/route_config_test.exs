defmodule Gaoxy.Server.RouteConfigTest do
  use ExUnit.Case, async: true
  alias Gaoxy.Server.{RouteConfig, StaticEndpoint}

  test "versioned route data resolves only registered endpoint types" do
    assert {:ok,
            [%{host: "example.test", path: {:prefix, "/api"}, target: {StaticEndpoint, static}}]} =
             RouteConfig.decode(%{
               "version" => 1,
               "routes" => [
                 %{
                   "host" => "example.test",
                   "prefix" => "/api",
                   "target" => %{"type" => "static", "status" => 201, "body" => "created"}
                 }
               ]
             })

    assert %{status: 201, body: "created", headers: []} = static

    for target <- [
          %{"type" => "System.cmd", "args" => ["touch", "file"]},
          %{"type" => "static", "body" => "ok", "eval" => "code"},
          %{"type" => "reverse_proxy", "upstream" => "http://user:pass@example.test"}
        ] do
      assert {:error, _} = RouteConfig.decode(data(target))
    end
  end

  test "strict route shapes reject ambiguous matches and arbitrary keys" do
    for route <- [
          %{"path" => "/", "prefix" => "/", "target" => %{"type" => "static"}},
          %{"target" => %{"type" => "static"}, "module" => "System"},
          %{"methods" => ["bad method"], "target" => %{"type" => "static"}},
          %{"target" => %{"type" => "static", "headers" => [["x", "a\r\nb"]]}}
        ] do
      assert {:error, _} = RouteConfig.decode(%{"version" => 1, "routes" => [route]})
    end

    assert {:error, :invalid_route_configuration} =
             RouteConfig.decode(%{"version" => 2, "routes" => []})

    assert {:error, :invalid_route_configuration} =
             RouteConfig.decode(%{"version" => 1, "routes" => [], "eval" => "code"})
  end

  @tag :tmp_dir
  test "bounded file reload activates a new route generation and rolls back invalid input", %{
    tmp_dir: dir
  } do
    assert {:ok, routes} = RouteConfig.decode(data(%{"type" => "static", "body" => "old"}))
    store = start_supervised!({Gaoxy.HTTP.Generation, routes: routes})
    assert {:ok, original, original_router} = Gaoxy.HTTP.Generation.snapshot(store)
    path = Path.join(dir, "routes.json")
    File.write!(path, JSON.encode!(data(%{"type" => "static", "body" => "new"})))
    assert {:ok, next} = RouteConfig.reload(store, path)
    refute next == original
    assert {:ok, ^next, router} = Gaoxy.HTTP.Generation.snapshot(store)
    refute router == original_router

    File.write!(path, JSON.encode!(data(%{"type" => "unknown"})))
    assert {:error, _} = RouteConfig.reload(store, path)
    assert {:ok, ^next, ^router} = Gaoxy.HTTP.Generation.snapshot(store)

    File.write!(path, String.duplicate("x", 1_048_577))
    assert {:error, :configuration_too_large} = RouteConfig.load(path)
  end

  test "route count is bounded before endpoint initialization" do
    routes = List.duplicate(%{"target" => %{"type" => "static"}}, 1025)
    assert {:error, :route_limit} = RouteConfig.decode(%{"version" => 1, "routes" => routes})
  end

  @tag :tmp_dir
  test "unusable static response framing cannot replace a live generation", %{tmp_dir: dir} do
    assert {:ok, routes} = RouteConfig.decode(data(%{"type" => "static", "body" => "old"}))
    store = start_supervised!({Gaoxy.HTTP.Generation, routes: routes})
    assert {:ok, original, router} = Gaoxy.HTTP.Generation.snapshot(store)
    path = Path.join(dir, "invalid.json")

    for headers <- [
          [["transfer-encoding", "chunked"]],
          [["content-length", "invalid"]],
          [["content-length", "3"], ["content-length", "3"]],
          [["content-length", "4"]],
          [["connection", "keep-alive"]],
          [["x", <<127>>]],
          [["x", <<1>>]],
          [["x", " value "]],
          [["x", "\tvalue"]]
        ] do
      target = %{"type" => "static", "body" => "new", "headers" => headers}
      File.write!(path, JSON.encode!(data(target)))
      assert {:error, _} = RouteConfig.reload(store, path)
      assert {:ok, ^original, ^router} = Gaoxy.HTTP.Generation.snapshot(store)
    end
  end

  test "304 static responses preserve representation length without requiring a body" do
    assert {:ok,
            [
              %{
                target:
                  {StaticEndpoint, %{status: 304, body: "", headers: [{"content-length", "123"}]}}
              }
            ]} =
             RouteConfig.decode(
               data(%{
                 "type" => "static",
                 "status" => 304,
                 "headers" => [["content-length", "123"]]
               })
             )
  end

  test "304 static metadata rejects a length beyond the protocol decimal limit" do
    assert {:error, _} =
             RouteConfig.decode(
               data(%{
                 "type" => "static",
                 "status" => 304,
                 "headers" => [["content-length", String.duplicate("1", 21)]]
               })
             )
  end

  test "static fields reserve the default H2 accounting and generated framing headroom" do
    for headers <- [
          List.duplicate(["x", String.duplicate("a", 306)], 100),
          List.duplicate(["x", String.duplicate("a", 313)], 98),
          List.duplicate(["x", "a"], 100)
        ] do
      assert {:error, _} =
               RouteConfig.decode(
                 data(%{"type" => "static", "body" => "ok", "headers" => headers})
               )
    end
  end

  defp data(target), do: %{"version" => 1, "routes" => [%{"target" => target}]}
end
