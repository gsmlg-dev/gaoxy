defmodule Gaoxy.HTTP2AuthorityNetworkTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Exchange, Response}

  @moduletag :h2_authority_peer
  @tag timeout: 15_000
  test "independent H2 peer isolates missing authority from an active sibling and connection" do
    root = Path.expand("../../..", __DIR__)
    python = Path.join(root, ".audit/h2peer/bin/python")

    assert File.exists?(python),
           "install the pinned independent peer from test/support/h2-requirements.txt"

    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint: {__MODULE__.Endpoint, []},
        protocols: [:http2],
        h2c: :prior_knowledge,
        limits: %{max_bytes: 536_870_912, max_active: 128},
        http_limits: %{request_timeout: 10_000}
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {_, port}} = Gaoxy.info(server, :http).local

    {output, status} =
      System.cmd(
        python,
        [Path.join(__DIR__, "support/h2_authority_peer.py"), Integer.to_string(port)],
        stderr_to_stdout: true
      )

    assert status == 0, output
    assert output =~ "PASS independent H2 authority"
  end

  defmodule Endpoint do
    def init(options), do: {:ok, options}

    def call(%{request: %{path: "/sibling"}} = exchange, _) do
      case Exchange.read_body(exchange, 16, 5_000) do
        {:ok, "sibling", next} -> Response.send_resp(next, 200, [], "sibling")
        {:error, reason} -> {:error, reason, exchange}
        result -> {:error, {:unexpected_body, result}, exchange}
      end
    end

    def call(exchange, _), do: Response.send_resp(exchange, 200, [], exchange.request.path)
  end
end
