defmodule Gaoxy.HTTP2AuthorityTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.HTTP2.Headers

  @limits %{
    max_headers: 100,
    max_header_bytes: 32_768,
    max_request_line: 8192,
    max_body_bytes: 8_388_608
  }
  @origin [{":method", "GET"}, {":scheme", "http"}, {":path", "/authority"}]

  test "missing authority and Host returns a structured stream error" do
    assert {:error, :protocol_error, :request_target} = Headers.request(@origin, false, @limits)
  end

  test "authority-only and Host fallback preserve host normalization and default ports" do
    for fields <- [
          List.insert_at(@origin, 2, {":authority", "EXAMPLE.test"}),
          @origin ++ [{"host", "EXAMPLE.test"}]
        ] do
      assert {:ok, %{host: "example.test", port: 80, path: "/authority"}} =
               Headers.request(fields, false, @limits)
    end

    secure = List.keyreplace(@origin, ":scheme", 0, {":scheme", "https"})

    assert {:ok, %{host: "example.test", port: 443}} =
             Headers.request(secure ++ [{"host", "example.test"}], true, @limits)
  end

  test "authority and Host agree semantically including default ports" do
    for {secure, scheme, authority, host, port} <- [
          {false, "http", "example.test", "EXAMPLE.test:80", 80},
          {false, "http", "example.test:80", "EXAMPLE.test", 80},
          {true, "https", "example.test", "EXAMPLE.test:443", 443},
          {true, "https", "example.test:8443", "EXAMPLE.test:8443", 8443},
          {false, "http", "[::1]", "[::1]:80", 80}
        ] do
      fields = [
        {":method", "GET"},
        {":scheme", scheme},
        {":authority", authority},
        {":path", "/authority"},
        {"host", host}
      ]

      assert {:ok, %{port: ^port}} = Headers.request(fields, secure, @limits)
    end
  end

  test "empty malformed mismatched and duplicate authorities are structured errors" do
    for authority <- ["", "bad host", "example.test:", "example.test:0", "[::1", "[invalid]"] do
      fields = List.insert_at(@origin, 2, {":authority", authority})
      assert {:error, :protocol_error, :request_target} = Headers.request(fields, false, @limits)
    end

    fields = List.insert_at(@origin, 2, {":authority", "example.test"})

    for hosts <- [
          [{"host", "other.test"}],
          [{"host", "example.test:81"}],
          [{"host", "example.test"}, {"host", "example.test"}]
        ] do
      assert {:error, :protocol_error, :request_target} =
               Headers.request(fields ++ hosts, false, @limits)
    end
  end

  test "invalid byte sequences in bracketed authorities are structured errors" do
    invalid = <<"[", 255, "]">>

    for fields <- [
          List.insert_at(@origin, 2, {":authority", invalid}),
          @origin ++ [{"host", invalid}],
          List.insert_at(@origin, 2, {":authority", "example.test"}) ++ [{"host", invalid}]
        ] do
      assert {:error, :protocol_error, :request_target} = Headers.request(fields, false, @limits)
    end

    assert {:error, :protocol_error, :connect_headers} =
             Headers.request([{":method", "CONNECT"}, {":authority", invalid}], false, @limits)
  end

  test "nonbinary authority and Host are rejected by field validation" do
    for field <- [{":authority", nil}, {":authority", 80}, {"host", nil}] do
      assert {:error, :protocol_error, :header_fields} =
               Headers.request(@origin ++ [field], false, @limits)
    end
  end

  test "CONNECT still requires explicit authority and port" do
    assert {:ok, %{method: "CONNECT", target_form: :authority, host: "example.test", port: 443}} =
             Headers.request(
               [{":method", "CONNECT"}, {":authority", "example.test:443"}],
               false,
               @limits
             )

    for fields <- [
          [{":method", "CONNECT"}],
          [{":method", "CONNECT"}, {"host", "example.test:443"}],
          [{":method", "CONNECT"}, {":authority", "example.test"}]
        ] do
      assert {:error, :protocol_error, :connect_headers} = Headers.request(fields, false, @limits)
    end
  end

  test "extended CONNECT retains opt-in and origin authority validation" do
    fields = [
      {":method", "CONNECT"},
      {":scheme", "http"},
      {":authority", "example.test"},
      {":path", "/socket"},
      {":protocol", "websocket"}
    ]

    assert {:ok, %{protocol: "websocket", body: :tunnel, host: "example.test", port: 80}} =
             Headers.request(fields, false, @limits, true)

    assert {:error, :protocol_error, :request_headers} =
             Headers.request(fields, false, @limits, false)

    missing = List.keydelete(fields, ":authority", 0)

    assert {:error, :protocol_error, :request_headers} =
             Headers.request(missing, false, @limits, true)
  end
end
