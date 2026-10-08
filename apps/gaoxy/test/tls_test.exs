defmodule Gaoxy.TLSTest do
  use ExUnit.Case, async: true

  defmodule Echo do
    @behaviour Gaoxy.StreamHandler
    def init(_, _), do: {:ok, nil}
    def handle_data(bytes, state), do: {:send, bytes, state}
  end

  @tag :loopback
  @tag :tmp_dir
  test "independent OpenSSL peer validates TLS and rejects invalid trust", %{tmp_dir: dir} do
    root = Path.expand("../../..", __DIR__)
    assert {_, 0} = System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), dir])

    pid =
      start_supervised!(
        {Gaoxy,
         services: [
           %{
             id: "tls",
             transport: :tls,
             handler: Echo,
             tls: %{
               provider: :otp,
               certfile: Path.join(dir, "cert.pem"),
               keyfile: Path.join(dir, "key.pem"),
               alpn: ["gaoxy-echo-v1"]
             }
           }
         ]}
      )

    assert %{local: {:ok, {_, port}}} = Gaoxy.info(pid, "tls")

    assert {output, 0} =
             System.cmd(
               "python3",
               [
                 Path.join(root, "integration/tls_peer.py"),
                 Integer.to_string(port),
                 Path.join(dir, "ca.pem")
               ],
               stderr_to_stdout: true
             )

    assert output =~ "PASS TLS exchange"
    assert :ok = Gaoxy.stop(pid, 1_000)
  end
end
