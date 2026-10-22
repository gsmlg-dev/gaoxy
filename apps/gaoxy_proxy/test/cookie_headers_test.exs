defmodule Gaoxy.Proxy.CookieHeadersTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.{Exchange, Request}
  alias Gaoxy.Proxy.HTTP.Headers

  for version <- [:"HTTP/2", :"HTTP/3"] do
    test "#{version} combines only request Cookies in encounter order" do
      input = [
        {"cookie", "a=1"},
        {"x-trace", "first"},
        {"Cookie", "b=2; c=3"},
        {"x-trace", "second"},
        {"cookie", "d=4"}
      ]

      assert {:ok, fields, _} = Headers.request(exchange(unquote(version), input))
      assert [{"cookie", "a=1; b=2; c=3; d=4"}] = Enum.filter(fields, &match?({"cookie", _}, &1))

      assert [{"x-trace", "first"}, {"x-trace", "second"}] =
               Enum.filter(fields, &match?({"x-trace", _}, &1))
    end
  end

  test "zero and one Cookie preserve their values, and H1 preserves separate fields" do
    for version <- [:"HTTP/1.0", :"HTTP/1.1", :"HTTP/2", :"HTTP/3"],
        fields <- [[], [{"cookie", " a=1; b=2 "}]] do
      assert {:ok, output, _} = Headers.request(exchange(version, fields))
      assert Enum.filter(output, &match?({"cookie", _}, &1)) == fields
    end

    fields = [{"cookie", "a=1"}, {"cookie", "b=2"}]
    assert {:ok, output, _} = Headers.request(exchange(:"HTTP/1.1", fields))
    assert Enum.filter(output, &match?({"cookie", _}, &1)) == fields
  end

  test "transformed output limits include separators and preserve input preflight" do
    request = exchange(:"HTTP/2", [{"cookie", "a"}, {"cookie", "b"}])
    assert {:ok, fields, _} = Headers.request(request)
    assert [{"cookie", "a; b"}] = Enum.filter(fields, &match?({"cookie", _}, &1))
    bytes = Enum.reduce(fields, 2, fn {k, v}, n -> n + byte_size(k) + byte_size(v) + 4 end)

    assert {:ok, _, _} =
             Headers.request(%{request | limits: %{request.limits | max_header_bytes: bytes}})

    assert {:error, :proxy_header_limit} =
             Headers.request(%{request | limits: %{request.limits | max_header_bytes: bytes - 1}})

    # Input count is checked before joining; normalization cannot erase overflow.
    assert {:error, _} =
             Headers.request(exchange(:"HTTP/2", List.duplicate({"cookie", "a"}, 257)))

    assert {:error, :proxy_header_limit} =
             Headers.request(exchange(:"HTTP/3", [{"cookie", String.duplicate("a", 65_537)}]))
  end

  test "hop nominations remove Cookies before normalization and response Set-Cookie stays separate" do
    request = exchange(:"HTTP/2", [{"connection", "cookie"}, {"cookie", "a"}, {"cookie", "b"}])
    assert {:ok, fields, _} = Headers.request(request)
    refute List.keymember?(fields, "cookie", 0)

    cookies = [{"set-cookie", "a=1; Path=/"}, {"set-cookie", "b=2; Path=/"}]

    for version <- [:"HTTP/1.1", :"HTTP/2", :"HTTP/3"] do
      assert {:ok, ^cookies, _} = Headers.response(exchange(version, []), 200, cookies)
    end
  end

  defp exchange(version, headers) do
    %Exchange{
      request: %Request{
        method: "GET",
        version: version,
        host: "localhost",
        headers: headers,
        body: :none
      },
      socket: struct(Hell.Socket, transport_module: Hell.Transports.TCP),
      peer: {{127, 0, 0, 1}, 12345},
      limits: %{
        max_headers: 256,
        max_header_bytes: 65_536,
        max_trailers: 32,
        max_trailer_bytes: 8192
      }
    }
  end
end
