defmodule Gaoxy.Server.MixedHTTPRoutingTest do
  use ExUnit.Case, async: false

  test "standalone JSON routing serves explicit H1 and independent H2 on its sole listener" do
    json = %{
      "version" => 1,
      "services" => [
        %{
          "id" => "mixed-web",
          "transport" => "tcp",
          "handler" => "http",
          "port" => 0,
          "protocols" => ["http2", "http1"],
          "h2c" => "prior_knowledge",
          "routes" => %{
            "version" => 1,
            "routes" => [%{"target" => %{"type" => "static", "body" => "standalone-mixed"}}]
          }
        }
      ]
    }

    assert {:ok, options} = Gaoxy.Server.Config.decode(json |> JSON.encode!() |> JSON.decode!())
    start_supervised!({Gaoxy.Server.Supervisor, options})
    assert ["mixed-web"] = Gaoxy.services(Gaoxy.Server.Runtime)
    assert {:ok, {{127, 0, 0, 1}, port}} = Gaoxy.info(Gaoxy.Server.Runtime, "mixed-web").local

    python =
      System.get_env("GAOXY_QUIC_PYTHON") ||
        Path.expand("../../../.audit/h2peer/bin/python", __DIR__)

    script = Path.expand("../../gaoxy_http/test/support/mixed_http_peer.py", __DIR__)

    {output, code} =
      System.cmd(python, [script, to_string(port), "standalone-mixed"], stderr_to_stdout: true)

    assert code == 0, output

    assert %{
             "status" => "PASS",
             "port" => ^port,
             "simultaneous" => true,
             "protocols" => ["HTTP/1.1", "HTTP/2"]
           } = JSON.decode!(output)

    assert Gaoxy.info(Gaoxy.Server.Runtime, "mixed-web").local == {:ok, {{127, 0, 0, 1}, port}}
  end
end
