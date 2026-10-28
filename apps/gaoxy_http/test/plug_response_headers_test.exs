defmodule Gaoxy.PlugResponseHeadersTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.{Exchange, FramedResponse, Request, Response}

  defmodule Capture do
    def send_resp(exchange, status, headers, body) do
      send(self(), {:response, :buffered, status, headers, body})
      {:ok, %{exchange | response: :sent}}
    end

    def send_file(exchange, status, headers, path, offset, length) do
      send(self(), {:response, :file, status, headers, {path, offset, length}})
      {:ok, %{exchange | response: :sent}}
    end

    def send_chunked(exchange, status, headers) do
      send(self(), {:response, :streamed, status, headers, nil})
      {:ok, %{exchange | response: :chunked}}
    end

    def inform(_, status, headers) do
      send(self(), {:response, :inform, status, headers, nil})
      :ok
    end
  end

  defmodule Framed do
    defdelegate send_resp(exchange, status, headers, body), to: FramedResponse
    defdelegate send_file(exchange, status, headers, path, offset, length), to: FramedResponse
    defdelegate send_chunked(exchange, status, headers), to: FramedResponse
    defdelegate inform(exchange, status, headers), to: FramedResponse
    defdelegate chunk(exchange, data), to: FramedResponse
    defdelegate finish(exchange, trailers), to: FramedResponse

    def operation(_, operation) do
      send(self(), {:wire, operation})
      :ok
    end
  end

  defp exchange(version, transport \\ Capture) do
    %Exchange{
      request: %Request{method: "GET", version: version},
      transport: transport,
      limits: %{
        max_headers: 100,
        max_header_bytes: 32_768,
        max_trailers: 100,
        max_trailer_bytes: 32_768
      }
    }
  end

  defp headers do
    [
      {"connection", "keep-alive, X-One"},
      {"ConNeCtIoN", "\t X-Two, X-One \t"},
      {"keep-alive", "timeout=5"},
      {"proxy-connection", "keep-alive"},
      {"transfer-encoding", "chunked"},
      {"upgrade", "websocket"},
      {"te", "trailers"},
      {"x-one", "secret-one"},
      {"X-Two", "secret-two"},
      {"set-cookie", "a=1"},
      {"set-cookie", "b=2"},
      {"x-end-to-end", "preserved"}
    ]
  end

  defp ordinary do
    [{"set-cookie", "a=1"}, {"set-cookie", "b=2"}, {"x-end-to-end", "preserved"}]
  end

  test "H2 buffered Plug responses remove every connection field and nomination" do
    body = ["a", ["b"]]
    expected = ordinary()

    assert {:ok, nil, %{response: :sent}} =
             Gaoxy.PlugAdapter.send_resp(exchange(:"HTTP/2"), 200, headers(), body)

    assert_received {:response, :buffered, 200, ^expected, ^body}
  end

  test "H3 applies the same Plug boundary policy before its shared framer" do
    expected = ordinary()
    assert {:ok, nil, _} = Gaoxy.PlugAdapter.send_resp(exchange(:"HTTP/3"), 200, headers(), "ok")
    assert_received {:response, :buffered, 200, ^expected, "ok"}
  end

  test "H1 preserves the exact application header list for every operation" do
    original = headers()

    for version <- [:"HTTP/1.0", :"HTTP/1.1"] do
      assert {:ok, nil, _} = Gaoxy.PlugAdapter.send_resp(exchange(version), 200, original, "ok")
      assert_received {:response, :buffered, 200, ^original, "ok"}

      assert {:ok, nil, _} =
               Gaoxy.PlugAdapter.send_file(exchange(version), 200, original, "file", 2, 4)

      assert_received {:response, :file, 200, ^original, {"file", 2, 4}}
      assert {:ok, nil, _} = Gaoxy.PlugAdapter.send_chunked(exchange(version), 200, original)
      assert_received {:response, :streamed, 200, ^original, nil}
      assert :ok = Gaoxy.PlugAdapter.inform(exchange(version), 103, original)
      assert_received {:response, :inform, 103, ^original, nil}
    end
  end

  test "streamed responses normalize before the response head starts" do
    expected = ordinary()

    for version <- [:"HTTP/2", :"HTTP/3"] do
      assert {:ok, nil, %{response: :chunked}} =
               Gaoxy.PlugAdapter.send_chunked(exchange(version), 200, headers())

      assert_received {:response, :streamed, 200, ^expected, nil}
    end
  end

  test "file responses preserve the selected range and ordinary headers" do
    expected = ordinary()

    for version <- [:"HTTP/2", :"HTTP/3"] do
      assert {:ok, nil, _} =
               Gaoxy.PlugAdapter.send_file(exchange(version), 200, headers(), "file", 2, 4)

      assert_received {:response, :file, 200, ^expected, {"file", 2, 4}}
    end
  end

  test "informational responses normalize without changing their status" do
    expected = [{"link", "</asset>; rel=preload"} | ordinary()]

    for version <- [:"HTTP/2", :"HTTP/3"] do
      assert :ok =
               Gaoxy.PlugAdapter.inform(
                 exchange(version),
                 103,
                 [{"link", "</asset>; rel=preload"} | headers()]
               )

      assert_received {:response, :inform, 103, ^expected, nil}
    end
  end

  @tag :tmp_dir
  test "malformed ordinary headers still fail all four operations", %{tmp_dir: dir} do
    path = Path.join(dir, "empty")
    File.write!(path, "")

    for version <- [:"HTTP/2", :"HTTP/3"],
        bad <- [[{"x-bad", "a\r\nb"}], [{"Upper", "bad"}], [{":status", "200"}], [:bad]],
        operation <- [:buffered, :file, :streamed] do
      fields = [{"connection", "keep-alive"} | bad]

      assert_raise Plug.Conn.NotSentError, ":invalid_response_headers", fn ->
        invoke(operation, exchange(version, Framed), fields, path)
      end

      assert {:error, :invalid_response_headers} =
               Gaoxy.PlugAdapter.inform(exchange(version, Framed), 103, fields)

      refute_received {:wire, _}
    end
  end

  @tag :tmp_dir
  test "invalid content lengths remain rejected after compatibility filtering", %{tmp_dir: dir} do
    path = Path.join(dir, "empty")
    File.write!(path, "")

    for version <- [:"HTTP/2", :"HTTP/3"],
        lengths <- [
          [{"content-length", "bad"}],
          [{"content-length", "1"}, {"content-length", "1"}]
        ],
        operation <- [:buffered, :file, :streamed] do
      fields = [{"connection", "keep-alive"} | lengths]

      assert_raise Plug.Conn.NotSentError, ":invalid_response_framing", fn ->
        invoke(operation, exchange(version, Framed), fields, path)
      end

      assert {:error, :invalid_response_framing} =
               Gaoxy.PlugAdapter.inform(exchange(version, Framed), 103, fields)

      refute_received {:wire, _}
    end
  end

  test "fixed stream overflow and incomplete finish remain strict" do
    for version <- [:"HTTP/2", :"HTTP/3"] do
      assert {:ok, nil, streaming} =
               Gaoxy.PlugAdapter.send_chunked(
                 exchange(version, Framed),
                 200,
                 [{"connection", "keep-alive"}, {"content-length", "1"}]
               )

      assert_received {:wire, {:head, 200, [{"content-length", "1"}], false}}
      assert {:error, :content_length_exceeded} = Gaoxy.PlugAdapter.chunk(streaming, "two")
      assert {:error, :content_length_mismatch} = Response.finish(streaming)
      refute_received {:wire, {:data, _, _}}
    end
  end

  test "native framed responses still reject connection-specific headers" do
    for version <- [:"HTTP/2", :"HTTP/3"] do
      exchange = exchange(version, Framed)
      fields = [{"connection", "keep-alive"}]
      assert {:error, :invalid_response_headers} = Response.send_resp(exchange, 200, fields, "")
      assert {:error, :invalid_response_headers} = Response.send_chunked(exchange, 200, fields)
      assert {:error, :invalid_response_headers} = Response.inform(exchange, 103, fields)
      refute_received {:wire, _}
    end
  end

  @tag :tmp_dir
  test "connection filtering cannot bypass raw header count or byte budgets", %{tmp_dir: dir} do
    path = Path.join(dir, "empty")
    File.write!(path, "")
    fields = [{"connection", "x-one"}, {"x-one", "nominated"}]

    for version <- [:"HTTP/2", :"HTTP/3"],
        limits <- [
          %{max_headers: 1, max_header_bytes: 32_768},
          %{max_headers: 100, max_header_bytes: 16}
        ],
        operation <- [:buffered, :file, :streamed] do
      exchange = %{exchange(version, Framed) | limits: limits}

      assert_raise Plug.Conn.NotSentError, ":invalid_response_headers", fn ->
        invoke(operation, exchange, fields, path)
      end

      assert {:error, :invalid_response_headers} = Gaoxy.PlugAdapter.inform(exchange, 103, fields)
      refute_received {:wire, _}
    end
  end

  defp invoke(:buffered, exchange, fields, _),
    do: Gaoxy.PlugAdapter.send_resp(exchange, 200, fields, "")

  defp invoke(:file, exchange, fields, path),
    do: Gaoxy.PlugAdapter.send_file(exchange, 200, fields, path, 0, :all)

  defp invoke(:streamed, exchange, fields, _),
    do: Gaoxy.PlugAdapter.send_chunked(exchange, 200, fields)
end
