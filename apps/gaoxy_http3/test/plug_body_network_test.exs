Code.require_file("../../gaoxy_http/test/support/plug_body_fixture.exs", __DIR__)

defmodule Gaoxy.HTTP.HTTP3.PlugBodyNetworkTest do
  use ExUnit.Case, async: true

  @tag :tmp_dir
  test "independent H3 peer runs real JSON/form Plug parsers and parser limit", %{
    tmp_dir: directory
  } do
    root = Path.expand("../../..", __DIR__)

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), directory],
               stderr_to_stdout: true
             )

    {:ok, server} =
      Gaoxy.HTTP.HTTP3.start_link(
        plug: {Gaoxy.PlugBodyFixture, []},
        tls: %{
          certfile: Path.join(directory, "cert.pem"),
          keyfile: Path.join(directory, "key.pem")
        },
        http_limits: %{request_timeout: 5_000}
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {_, port}} = Gaoxy.info(server, :http3).local
    python = System.get_env("GAOXY_QUIC_PYTHON") || Path.join(root, ".audit/h2peer/bin/python")
    peer = Path.join(root, "apps/gaoxy_http/test/support/plug_body_peer.py")

    {output, exit} =
      System.cmd(python, [peer, "h3", to_string(port), Path.join(directory, "ca.pem")],
        cd: root,
        stderr_to_stdout: true
      )

    assert exit == 0, output
    IO.write(output)
    assert length(Regex.scan(~r/PASS H3 Plug parser/, output)) == 3, output
    assert :ok = Gaoxy.stop(server)
  end
end
