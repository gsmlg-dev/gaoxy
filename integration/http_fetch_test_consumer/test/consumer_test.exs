defmodule GaoxyTestHTTPFetchConsumerTest do
  use ExUnit.Case, async: false

  test "published public HTTPFetch drives H1 and h2c expectations" do
    for {profile, version, actual} <- [{:http1, :http1, :http1}, {:h2c, :h2c, :http2}] do
      fixture = Gaoxy.Test.open(profile: profile)

      Gaoxy.Test.expect_once(fixture, :post, "/echo", fn conn ->
        {:ok, "consumer payload", conn} = Plug.Conn.read_body(conn)
        Plug.Conn.send_resp(conn, 200, "public HTTPFetch")
      end)

      response =
        HTTP.fetch(Gaoxy.Test.url(fixture, "/echo"),
          method: :post,
          body: "consumer payload",
          http_version: version,
          timeout: 3_000
        )
        |> HTTP.Promise.await(5_000)

      assert %HTTP.Response{status: 200, http_version: ^actual} = response
      assert HTTP.Response.text(response) == "public HTTPFetch"
      assert :ok = Gaoxy.Test.verify!(fixture)
      assert %{status: :ok} = Gaoxy.Test.close(fixture)
    end
  end

  test "HTTPFetch accepting a server error cannot hide fixture assertion failures" do
    fixture = Gaoxy.Test.open(mode: :manual)

    Gaoxy.Test.expect_once(fixture, :get, "/failure", fn _conn ->
      assert false, "consumer callback failure remains visible"
    end)

    assert %HTTP.Response{status: 500} =
             HTTP.fetch(Gaoxy.Test.url(fixture, "/failure"), timeout: 3_000)
             |> HTTP.Promise.await(5_000)

    assert_raise ExUnit.AssertionError, ~r/consumer callback failure remains visible/, fn ->
      Gaoxy.Test.verify_and_close!(fixture)
    end

    assert %{status: :error} = Gaoxy.Test.close(fixture)
  end
end
