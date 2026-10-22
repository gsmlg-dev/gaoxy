defmodule Gaoxy.HeadContentLengthTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.{Exchange, FramedResponse, Request}

  defmodule Transport do
    def operation(_, operation) do
      send(self(), {:response_operation, operation})
      :ok
    end
  end

  defp exchange do
    %Exchange{
      request: %Request{method: "HEAD"},
      transport: Transport,
      limits: %{max_headers: 100, max_header_bytes: 32_768}
    }
  end

  test "HEAD keeps supplied representation lengths and never sends DATA" do
    for length <- ["0", "12345"], body <- ["", "body"] do
      headers = [{"content-length", length}]
      assert {:ok, %{response: :sent}} = FramedResponse.send_resp(exchange(), 200, headers, body)
      assert_received {:response_operation, {:head, 200, ^headers, true}}
      refute_received {:response_operation, {:data, _, _}}
    end
  end

  test "HEAD infers representation length when none was supplied" do
    assert {:ok, %{response: :sent}} = FramedResponse.send_resp(exchange(), 200, [], "body")
    assert_received {:response_operation, {:head, 200, [{"content-length", "4"}], true}}
    refute_received {:response_operation, {:data, _, _}}
  end

  test "HEAD status rules retain precedence over supplied representation length" do
    for {status, expected} <- [
          {204, []},
          {205, [{"content-length", "0"}]},
          {304, [{"content-length", "12345"}]}
        ] do
      assert {:ok, %{response: :sent}} =
               FramedResponse.send_resp(exchange(), status, [{"content-length", "12345"}], "")

      assert_received {:response_operation, {:head, ^status, ^expected, true}}
      refute_received {:response_operation, {:data, _, _}}
    end
  end

  test "HEAD still rejects invalid and duplicate lengths before emitting headers" do
    for response <- [Gaoxy.HTTP.HTTP1.Response, FramedResponse],
        headers <- [
          [{"content-length", "-1"}],
          [{"content-length", "abc"}],
          [{"content-length", "1"}, {"content-length", "1"}]
        ] do
      assert {:error, :invalid_response_framing} =
               response.send_resp(exchange(), 200, headers, "")

      refute_received {:response_operation, _}
    end
  end
end
