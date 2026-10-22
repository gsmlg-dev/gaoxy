defmodule Gaoxy.HTTP.HTTP3.StreamLifetimeBoundaryTest do
  use ExUnit.Case, async: true
  @moduletag :unit

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: {:ok, exchange}
  end

  test "HTTP3 rejects unsupported stream lifetime configuration and preserves its finite default" do
    options = [endpoint: {Endpoint, []}, tls: %{certfile: "cert", keyfile: "key"}]
    assert {:ok, _} = Gaoxy.HTTP.HTTP3.Options.normalize(options)

    for timeout <- [:infinity, 500] do
      assert {:error, :unsupported_stream_timeout} =
               Gaoxy.HTTP.HTTP3.Options.normalize(
                 options ++ [http_limits: %{stream_timeout: timeout}]
               )
    end
  end
end
