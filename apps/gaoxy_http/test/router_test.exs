defmodule Gaoxy.HTTP.RouterTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Request, Router}

  defmodule Target do
    def init(:invalid), do: {:error, :invalid_target}
    def init(options), do: {:ok, options}
    def call(exchange, options), do: {:ok, Map.put(exchange, :selected, options)}
  end

  test "first declared matching route wins using normalized host, method and segment prefix" do
    assert {:ok, router} =
             Router.compile([
               %{
                 host: "EXAMPLE.test",
                 methods: ["GET"],
                 path: {:prefix, "/api"},
                 target: {Target, :api}
               },
               %{path: "/apiary", target: {Target, :exact}},
               %{target: {Target, :fallback}}
             ])

    assert {:ok, {Target, :api}} =
             Router.match(router, request("/api/item", "GET", "example.test"))

    assert {:ok, {Target, :exact}} =
             Router.match(router, request("/apiary", "GET", "example.test"))

    assert {:ok, {Target, :fallback}} =
             Router.match(router, request("/api", "POST", "example.test"))

    assert {:ok, {Target, :fallback}} = Router.match(router, request("/api", "GET", "other.test"))
    assert {:ok, ^router} = Router.init(router)
  end

  test "dispatch preserves original escaping and the original compiled generation" do
    assert {:ok, router} =
             Router.compile([
               %{path: "/a%2Fb", target: {Target, :encoded}},
               %{path: "/a/b", target: {Target, :plain}}
             ])

    request = request("/a%2Fb", "GET", "x")

    assert {:ok, %{selected: :encoded, request: ^request}} =
             Router.call(%{request: request}, router)

    assert :not_found = Router.match(router, request("/a%252Fb", "GET", "x"))
    assert {:ok, {Target, :plain}} = Router.match(router, request("/a/b", "GET", "x"))
    assert is_reference(router.generation)
  end

  test "rejects malformed configuration before endpoint activation" do
    for route <- [
          %{target: {Target, :invalid}},
          %{target: {MissingTarget, []}},
          %{target: {Target, []}, typo: true},
          %{target: {Target, []}, host: "bad host"},
          %{target: {Target, []}, methods: ["bad method"]},
          %{target: {Target, []}, path: "/bad?query"},
          %{target: {Target, []}, path: {:prefix, "/api/"}}
        ] do
      assert {:error, _} = Router.compile([route])
    end
  end

  test "routes all valid HTTP method tokens with case-sensitive matching" do
    assert {:ok, router} =
             Router.compile([
               %{methods: ["FOO$BAR", "get"], target: {Target, :extension}}
             ])

    assert {:ok, {Target, :extension}} = Router.match(router, request("/", "FOO$BAR", "x"))
    assert {:ok, {Target, :extension}} = Router.match(router, request("/", "get", "x"))
    assert :not_found = Router.match(router, request("/", "GET", "x"))
  end

  defp request(path, method, host), do: %Request{path: path, method: method, host: host}
end
