defmodule Gaoxy.HTTP.HTTP1.ParserTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.HTTP1.Parser

  test "retained header values do not pin a coalesced large request body" do
    body = String.duplicate("b", 100_000)

    head =
      "POST / HTTP/1.1\r\nHost: localhost\r\nX-Pad: " <>
        String.duplicate("x", 128) <>
        "\r\nContent-Length: 100000\r\n\r\n"

    assert {:ok, request, ^body} = Parser.parse_head(head <> body)
    {_, value} = List.keyfind(request.headers, "x-pad", 0)
    assert :binary.referenced_byte_size(value) <= byte_size(head)
    assert request.head_bytes == byte_size(head)
  end

  test "parses a fragmented head without consuming the next pipelined request" do
    head = "GET /a%20b?q=one HTTP/1.1\r\nHost: Example.test:8080\r\nX-Tag: a\r\nX-Tag: b\r\n\r\n"

    for size <- 0..(byte_size(head) - 1) do
      assert :more = Parser.parse_head(binary_part(head, 0, size))
    end

    assert {:ok, request, "GET /next"} = Parser.parse_head(head <> "GET /next")

    assert %{
             method: "GET",
             path: "/a%20b",
             query_string: "q=one",
             host: "example.test",
             port: 8080,
             version: :"HTTP/1.1",
             body: :none,
             keep_alive: true,
             target_form: :origin
           } = request

    assert [{"host", "Example.test:8080"}, {"x-tag", "a"}, {"x-tag", "b"}] = request.headers
  end

  test "absolute, authority and asterisk targets have explicit forms" do
    assert {:ok,
            %{
              target_form: :absolute,
              scheme: :https,
              host: "example.test",
              port: 443,
              path: "/p",
              query_string: "x=1"
            },
            ""} =
             Parser.parse_head(
               "GET https://example.test/p?x=1 HTTP/1.1\r\nHost: example.test\r\n\r\n"
             )

    assert {:ok, %{target_form: :authority, host: "::1", port: 443}, ""} =
             Parser.parse_head("CONNECT [::1]:443 HTTP/1.1\r\nHost: [::1]:443\r\n\r\n")

    assert {:ok, %{target_form: :asterisk, path: "*"}, ""} =
             Parser.parse_head("OPTIONS * HTTP/1.1\r\nHost: example.test\r\n\r\n")
  end

  test "framing declares a bounded body without collecting body bytes" do
    assert {:ok, %{body: {:length, 4}, expect_continue: true}, "data"} =
             Parser.parse_head(
               "POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 4\r\nExpect: 100-continue\r\n\r\ndata"
             )

    assert {:ok, %{body: :chunked}, "4\r\ndata\r\n"} =
             Parser.parse_head(
               "POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n4\r\ndata\r\n"
             )
  end

  test "connection lifetime follows the protocol and explicit close" do
    assert {:ok, %{version: :"HTTP/1.0", keep_alive: false}, ""} =
             Parser.parse_head("GET / HTTP/1.0\r\n\r\n")

    assert {:ok, %{keep_alive: true}, ""} =
             Parser.parse_head("GET / HTTP/1.0\r\nConnection: keep-alive\r\n\r\n")

    assert {:ok, %{keep_alive: false}, ""} =
             Parser.parse_head(
               "GET / HTTP/1.1\r\nHost: x\r\nConnection: Keep-Alive, CLOSE\r\n\r\n"
             )
  end

  test "rejects ambiguous message framing before dispatch" do
    for headers <- [
          "Content-Length: 1\r\nContent-Length: 1\r\n",
          "Content-Length: 1, 1\r\n",
          "Content-Length: +1\r\n",
          "Content-Length: -1\r\n",
          "Content-Length: 1\r\nTransfer-Encoding: chunked\r\n",
          "Transfer-Encoding: chunked, identity\r\n",
          "Transfer-Encoding: chunked\r\nTransfer-Encoding: chunked\r\n",
          "Content-Length : 1\r\n",
          " folded: value\r\n",
          "X: evil\0value\r\n"
        ] do
      assert {:error, 400, _} =
               Parser.parse_head("POST / HTTP/1.1\r\nHost: x\r\n" <> headers <> "\r\n")
    end
  end

  test "rejects invalid and conflicting authorities and request targets" do
    for request <- [
          "GET / HTTP/1.1\r\n\r\n",
          "GET / HTTP/1.1\r\nHost: a\r\nHost: a\r\n\r\n",
          "GET http://a/p HTTP/1.1\r\nHost: b\r\n\r\n",
          "GET http://user@a/p HTTP/1.1\r\nHost: a\r\n\r\n",
          "GET /p#fragment HTTP/1.1\r\nHost: a\r\n\r\n",
          "GET /bad%XX HTTP/1.1\r\nHost: a\r\n\r\n",
          "GET * HTTP/1.1\r\nHost: a\r\n\r\n",
          "GET / HTTP/1.1\r\nHost: a:99999\r\n\r\n",
          "GET / HTTP/1.1\r\nHost: a b\r\n\r\n",
          "GET / HTTP/1.1\nHost: a\n\n"
        ] do
      assert {:error, 400, _} = Parser.parse_head(request)
    end
  end

  test "enforces line, head, count and body bounds before allocation" do
    assert {:error, 414, :request_line_limit} =
             Parser.parse_head("GET /long-path", %{max_request_line: 8})

    assert {:error, 431, :header_bytes_limit} =
             Parser.parse_head("GET / HTTP/1.1\r\nX: " <> String.duplicate("x", 80), %{
               max_header_bytes: 64
             })

    assert {:error, 431, :header_count_limit} =
             Parser.parse_head("GET / HTTP/1.1\r\nHost: x\r\nX: y\r\n\r\n", %{max_headers: 1})

    assert {:error, 413, :body_limit} =
             Parser.parse_head("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 11\r\n\r\n", %{
               max_body_bytes: 10
             })
  end

  test "rejects unsupported versions and expectations explicitly" do
    assert {:error, 505, :http_version} = Parser.parse_head("GET / HTTP/2.0\r\nHost: x\r\n\r\n")

    assert {:error, 417, :expectation} =
             Parser.parse_head("POST / HTTP/1.1\r\nHost: x\r\nExpect: other\r\n\r\n")

    assert {:error, 400, _} =
             Parser.parse_head("POST / HTTP/1.0\r\nTransfer-Encoding: chunked\r\n\r\n")
  end
end
