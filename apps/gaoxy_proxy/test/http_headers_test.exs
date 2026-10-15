defmodule Gaoxy.Proxy.HTTPHeadersTest do
  use ExUnit.Case, async: true

  alias Gaoxy.HTTP.{Exchange, Request}
  alias Gaoxy.Proxy.HTTP.Headers

  test "request policy preserves duplicates and fixed framing while regenerating forwarding fields" do
    exchange =
      exchange(
        [
          {"host", "downstream.example:8080"},
          {"content-length", "3"},
          {"x-trace", "first"},
          {"x-trace", "second"},
          {"connection", "keep-alive, X-Remove"},
          {"x-remove", "private"},
          {"proxy-connection", "keep-alive"},
          {"forwarded", "for=spoofed"},
          {"x-forwarded-for", "spoofed"},
          {"x-real-ip", "spoofed"},
          {"expect", "100-continue"}
        ],
        {:length, 3}
      )

    assert {:ok, fields, %{allowed: []}} = Headers.request(exchange)

    assert fields == [
             {"content-length", "3"},
             {"x-trace", "first"},
             {"x-trace", "second"},
             {"x-forwarded-for", "127.0.0.1"},
             {"x-forwarded-host", "downstream.example:8080"},
             {"x-forwarded-proto", "http"}
           ]
  end

  test "chunked upload trailers retain ordered duplicates after hop filtering" do
    exchange =
      exchange(
        [
          {"transfer-encoding", "chunked"},
          {"trailer", "X-Trace, X-Remove"},
          {"connection", "X-Remove"}
        ],
        :chunked
      )

    assert {:ok, fields, policy} = Headers.request(exchange)
    assert {"trailer", "x-trace"} in fields
    refute Enum.any?(fields, fn {name, _} -> name == "transfer-encoding" end)

    assert {:ok, [{"x-trace", "one"}, {"x-trace", "two"}]} =
             Headers.trailers(
               [{"X-Trace", "one"}, {"X-Remove", "private"}, {"X-Trace", "two"}],
               policy
             )
  end

  test "request trailers require chunk framing and safe declared names" do
    assert {:error, _} = Headers.request(exchange([{"trailer", "x-trace"}], {:length, 3}))
    assert {:error, _} = Headers.request(exchange([{"trailer", "content-length"}], :chunked))
    assert {:error, _} = Headers.request(exchange([{"trailer", "x-trace,,x-other"}], :chunked))
  end

  test "request trailers cannot restore client supplied forwarding identities" do
    fields = [
      {"Forwarded", "for=spoofed"},
      {"X-Forwarded-For", "spoofed"},
      {"X-Forwarded-Client-Cert", "spoofed"},
      {"X-Real-IP", "spoofed"},
      {"X-Trace", "allowed"}
    ]

    declaration = Enum.map_join(fields, ", ", &elem(&1, 0))
    request = exchange([{"trailer", declaration}], :chunked)
    assert {:ok, headers, policy} = Headers.request(request)
    assert {"trailer", "x-trace"} in headers
    assert {"x-forwarded-for", "127.0.0.1"} in headers
    assert {:ok, [{"x-trace", "allowed"}]} = Headers.trailers(fields, policy)
  end

  test "response policy preserves raw compression, cookies and content length" do
    fields = [
      {"Content-Encoding", "gzip"},
      {"Content-Length", "27"},
      {"Set-Cookie", "first=1"},
      {"Set-Cookie", "second=2"},
      {"Connection", "close, X-Remove"},
      {"X-Remove", "private"},
      {"Proxy-Connection", "close"}
    ]

    assert {:ok,
            [
              {"content-encoding", "gzip"},
              {"content-length", "27"},
              {"set-cookie", "first=1"},
              {"set-cookie", "second=2"}
            ], %{allowed: []}} = Headers.response(exchange(), 200, fields)
  end

  test "response nominations are applied before rebuilding its trailer declaration" do
    fields = [
      {"Connection", "X-Remove, Content-Length"},
      {"Content-Length", "99"},
      {"Transfer-Encoding", "chunked"},
      {"Trailer", "X-Trace, X-Remove"}
    ]

    assert {:ok, [{"trailer", "x-trace"}], policy} =
             Headers.response(exchange(), 200, fields)

    assert {:ok, [{"x-trace", "done"}]} =
             Headers.trailers([{"x-remove", "private"}, {"x-trace", "done"}], policy)

    assert {:error, _} = Headers.trailers([{"x-undeclared", "lost"}], policy)
  end

  test "HTTP 1.0 and bodyless responses cannot promise terminal trailers" do
    fields = [{"trailer", "x-trace"}]
    exchange = exchange()
    old = %{exchange | request: %{exchange.request | version: :"HTTP/1.0"}}
    head = %{exchange | request: %{exchange.request | method: "HEAD"}}

    assert {:error, _} = Headers.response(old, 200, fields)
    assert {:error, _} = Headers.response(head, 200, fields)
    assert {:error, _} = Headers.response(exchange, 204, fields)
    assert {:error, _} = Headers.response(exchange, 200, fields ++ [{"content-length", "3"}])
  end

  test "invalid field bytes and finite trailer limits are enforced before forwarding" do
    assert {:error, _} = Headers.response(exchange(), 200, [{"X-Bad", "one\r\nInjected: two"}])
    assert {:error, _} = Headers.response(exchange(), 200, [{"bad name", "value"}])

    assert {:ok, _, policy} = Headers.response(exchange(), 200, [{"trailer", "x-trace"}])
    assert {:error, _} = Headers.trailers([{"x-trace", String.duplicate("x", 128)}], policy)
    assert {:error, _} = Headers.trailers(List.duplicate({"x-trace", "x"}, 9), policy)
  end

  for version <- [:"HTTP/2", :"HTTP/3"], size <- [0, 3] do
    test "#{version} fixed #{size} request trailers remove forwarded length" do
      request =
        exchange(
          [{"content-length", "#{unquote(size)}"}, {"trailer", "x-trace"}],
          {:length, unquote(size)}
        )

      request = %{request | request: %{request.request | version: unquote(version)}}
      assert {:ok, fields, policy} = Headers.request(request)
      refute Enum.any?(fields, fn {name, _} -> name == "content-length" end)
      assert {"trailer", "x-trace"} in fields

      assert {:ok, [{"x-trace", "first"}, {"x-trace", "second"}]} =
               Headers.trailers([{"x-trace", "first"}, {"x-trace", "second"}], policy)
    end
  end

  test "HTTP/3 response trailers retain ordered fields from a chunked origin" do
    request = exchange()
    request = %{request | request: %{request.request | version: :"HTTP/3"}}

    assert {:ok, [{"trailer", "x-trace"}], policy} =
             Headers.response(request, 200, [
               {"transfer-encoding", "chunked"},
               {"trailer", "x-trace"}
             ])

    assert {:ok, [{"x-trace", "first"}, {"x-trace", "second"}]} =
             Headers.trailers([{"x-trace", "first"}, {"x-trace", "second"}], policy)
  end

  for version <- [:"HTTP/1.1", :"HTTP/2", :"HTTP/3"] do
    test "#{version} fixed response cannot declare trailers" do
      request = exchange()
      request = %{request | request: %{request.request | version: unquote(version)}}

      assert {:error, :invalid_proxy_trailers} =
               Headers.response(request, 200, [{"content-length", "3"}, {"trailer", "x-trace"}])

      assert {:error, :invalid_proxy_trailers} =
               Headers.request(%{
                 request
                 | request: %{request.request | headers: [{"trailer", "authorization"}]}
               })
    end
  end

  test "managed H2 trailer and Connection declarations count repeated tokens before deduplication" do
    bounded = %{
      exchange()
      | limits: %{
          max_headers: 256,
          max_header_bytes: 65_536,
          max_trailers: 128,
          max_trailer_bytes: 65_536
        }
    }

    for field <- ["trailer", "connection"] do
      exact = Enum.join(List.duplicate("x-check", 128), ",")
      over = exact <> ",x-check"

      request = %{
        bounded
        | request: %{
            bounded.request
            | headers: [{field, exact}],
              body: :chunked,
              version: :"HTTP/2"
          }
      }

      assert {:ok, _, policy} = Headers.request(request)
      assert Enum.sort(Map.keys(policy)) == [:allowed, :dropped, :max_bytes, :max_count]
      assert :erlang.external_size(policy) <= 67_689

      assert {:error, _} =
               Headers.request(%{
                 request
                 | request: %{request.request | headers: [{field, over}]}
               })

      assert {:ok, _, _} = Headers.response(bounded, 200, [{field, exact}])
      assert {:error, _} = Headers.response(bounded, 200, [{field, over}])
    end
  end

  test "managed H2 header backing and improper lists reject before normalization or token splitting" do
    bounded = %{
      exchange()
      | limits: %{
          max_headers: 256,
          max_header_bytes: 65_536,
          max_trailers: 128,
          max_trailer_bytes: 65_536
        }
    }

    backing = "x-check" <> String.duplicate("x", 65_537)
    token = binary_part(backing, 0, 100)
    assert :binary.referenced_byte_size(token) > 65_536

    for fields <- [
          [{"trailer", token}],
          [{"connection", token}],
          [{"x-check", token}],
          [{"x-check", "x"} | :improper],
          List.duplicate({"x-check", "x"}, 257)
        ] do
      assert {:error, _} =
               Headers.request(%{
                 bounded
                 | request: %{bounded.request | headers: fields, body: :chunked}
               })

      assert {:error, _} = Headers.response(bounded, 200, fields)
    end
  end

  test "managed H2 actual trailers retain exact128 ordered duplicates and reject129 before filtering" do
    bounded = %{
      exchange()
      | limits: %{
          max_headers: 256,
          max_header_bytes: 65_536,
          max_trailers: 128,
          max_trailer_bytes: 65_536
        }
    }

    assert {:ok, _, policy} = Headers.response(bounded, 200, [{"trailer", "x-check"}])
    exact = for index <- 1..128, do: {"x-check", Integer.to_string(index)}
    assert {:ok, ^exact} = Headers.trailers(exact, policy)
    assert {:error, _} = Headers.trailers(exact ++ [{"x-check", "129"}], policy)

    for forged <- [
          Map.put(policy, :extra, true),
          Map.delete(policy, :allowed),
          %{policy | max_count: 129},
          %{policy | max_bytes: 65_537},
          %{policy | allowed: ["x-check" | :improper]}
        ] do
      assert {:error, _} = Headers.trailers(exact, forged)
    end
  end

  defp exchange(headers \\ [], framing \\ :none) do
    %Exchange{
      request: %Request{
        method: "GET",
        version: :"HTTP/1.1",
        host: "downstream.example",
        headers: headers,
        body: framing
      },
      socket: struct(ThousandIsland.Socket, transport_module: ThousandIsland.Transports.TCP),
      peer: {{127, 0, 0, 1}, 12345},
      limits: %{max_header_bytes: 8192, max_trailers: 8, max_trailer_bytes: 128}
    }
  end
end
