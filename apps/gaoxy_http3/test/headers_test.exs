defmodule Gaoxy.HTTP.HTTP3.HeadersTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.HTTP3.Headers

  @limits %{
    max_headers: 100,
    max_header_bytes: 32_768,
    max_request_line: 8192,
    max_body_bytes: 8_388_608,
    max_trailers: 32,
    max_trailer_bytes: 8192
  }
  @fields [
    {":method", "POST"},
    {":scheme", "https"},
    {":authority", "example.test"},
    {":path", "/a%2Fb?"}
  ]

  test "request conversion preserves escaped path and empty query delimiter" do
    assert {:ok, request} = Headers.request(@fields ++ [{"content-length", "3"}], @limits)

    assert %{
             version: :"HTTP/3",
             scheme: :https,
             method: "POST",
             target: "/a%2Fb?",
             path: "/a%2Fb",
             query_string: "",
             host: "example.test",
             port: 443,
             body: {:length, 3},
             keep_alive: true
           } = request
  end

  test "ordinary CONNECT remains parseable for the explicit 501 policy" do
    assert {:ok, %{method: "CONNECT", target_form: :authority, port: 443}} =
             Headers.request(
               [{":method", "CONNECT"}, {":authority", "example.test:443"}],
               @limits
             )
  end

  test "host can supply authority and default-port comparison is semantic" do
    fields = Enum.reject(@fields, fn {name, _} -> name == ":authority" end)

    assert {:ok, %{host: "example.test"}} =
             Headers.request(fields ++ [{"host", "example.test"}], @limits)

    assert {:ok, _} = Headers.request(@fields ++ [{"host", "example.test:443"}], @limits)

    assert {:error, :stream, 0x10E, _} =
             Headers.request(@fields ++ [{"host", "other.test"}], @limits)
  end

  test "rejects invalid pseudo fields, connection fields and target forms" do
    bad = [
      [{":method", "GET"} | @fields],
      [{"x", "a"} | @fields],
      Enum.reject(@fields, fn {name, _} -> name == ":scheme" end),
      List.keyreplace(@fields, ":scheme", 0, {":scheme", "http"}),
      List.keyreplace(@fields, ":path", 0, {":path", "/bad%q"}),
      List.keyreplace(@fields, ":path", 0, {":path", "/bad#fragment"}),
      @fields ++ [{":status", "200"}],
      @fields ++ [{"connection", "close"}],
      @fields ++ [{"te", "gzip"}],
      @fields ++ [{"X", "a"}],
      @fields ++ [{"x", "a\r\nb"}],
      @fields ++ [{"content-length", "-1"}],
      @fields ++ [{"content-length", "1"}, {"content-length", "1"}]
    ]

    for fields <- bad, do: assert({:error, :stream, 0x10E, _} = Headers.request(fields, @limits))
  end

  test "field resource ceilings have excessive-load classification" do
    assert {:error, :stream, 0x107, _} = Headers.request(@fields, %{@limits | max_headers: 3})

    assert {:error, :stream, 0x107, _} =
             Headers.request(@fields, %{@limits | max_header_bytes: 10})

    assert Headers.bytes(@fields) ==
             Enum.reduce(@fields, 0, fn {n, v}, acc -> acc + byte_size(n) + byte_size(v) + 32 end)
  end

  test "trailers forbid pseudo and framing fields" do
    assert :ok = Headers.trailers([{"x-checksum", "ok"}], @limits)

    for fields <- [[{":path", "/"}], [{"content-length", "3"}], [{"host", "x"}]],
        do: assert({:error, :stream, 0x10E, _} = Headers.trailers(fields, @limits))

    assert {:error, :stream, 0x107, _} =
             Headers.trailers([{"x", "x"}], %{@limits | max_trailer_bytes: 1})
  end

  test "response validation keeps the shared facade contract" do
    assert :ok = Headers.response([{"content-type", "text/plain"}], 100, 32_768)

    assert {:error, :invalid_response_headers} =
             Headers.response([{":status", "200"}], 100, 32_768)

    assert {:error, :invalid_response_headers} =
             Headers.response([{"connection", "close"}], 100, 32_768)
  end

  test "missing authority and Host is a stream error rather than a parser exception" do
    fields = Enum.reject(@fields, fn {name, _} -> name == ":authority" end)
    assert {:error, :stream, 0x10E, :request_target} = Headers.request(fields, @limits)
  end

  test "HEAD and OPTIONS asterisk map to ordinary HTTP metadata" do
    assert {:ok, %{method: "HEAD", version: :"HTTP/3"}} =
             Headers.request(List.keyreplace(@fields, ":method", 0, {":method", "HEAD"}), @limits)

    fields =
      @fields
      |> List.keyreplace(":method", 0, {":method", "OPTIONS"})
      |> List.keyreplace(":path", 0, {":path", "*"})

    assert {:ok, %{method: "OPTIONS", path: "*"}} = Headers.request(fields, @limits)

    assert {:error, :stream, 0x10E, _} =
             Headers.request(@fields ++ [{":protocol", "websocket"}], @limits)
  end

  test "CONNECT accepts a matching regular Host but rejects disagreement and duplicates" do
    fields = [{":method", "CONNECT"}, {":authority", "example.test:443"}]

    assert {:ok, %{method: "CONNECT", host: "example.test", port: 443}} =
             Headers.request(fields ++ [{"host", "example.test:443"}], @limits)

    for hosts <- [
          [{"host", "other.test:443"}],
          [{"host", "example.test:444"}],
          [{"host", "example.test:443"}, {"host", "example.test:443"}]
        ] do
      assert {:error, :stream, 0x10E, :connect_headers} =
               Headers.request(fields ++ hosts, @limits)
    end
  end

  test "valid Content-Length above the body ceiling is a resource error" do
    limits = %{@limits | max_body_bytes: 8}

    assert {:error, :stream, 0x107, :body_limit} =
             Headers.request(@fields ++ [{"content-length", "9"}], limits)

    assert {:error, :stream, 0x10E, :content_length} =
             Headers.request(@fields ++ [{"content-length", "-1"}], limits)
  end
end
