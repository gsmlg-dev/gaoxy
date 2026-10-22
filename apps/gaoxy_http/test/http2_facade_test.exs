defmodule Gaoxy.HTTP2FacadeTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.Exchange

  test "a generation snapshot reservation survives exchange accounting" do
    exchange = Map.put(%Exchange{buffer: "abc"}, :route_bytes, 128)
    assert Exchange.retained_bytes(exchange) == 131
    assert Map.fetch!(%Exchange{}, :route_bytes) == 0
  end

  test "semantic body access preserves ordered request trailers" do
    exchange = %Exchange{
      buffer: "",
      body: %{phase: :done, trailers: [{"x-check", "one"}, {"x-check", "two"}], trailer_bytes: 24}
    }

    assert apply(Exchange, :body_complete?, [exchange])

    assert apply(Exchange, :request_trailers, [exchange]) == [
             {"x-check", "one"},
             {"x-check", "two"}
           ]
  end
end
