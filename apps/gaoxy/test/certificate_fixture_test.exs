defmodule Gaoxy.CertificateFixtureTest do
  use ExUnit.Case, async: true

  @moduletag :loopback
  @moduletag :tmp_dir
  @script Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)

  test "unavailable selected executable fails with a useful diagnostic", %{tmp_dir: dir} do
    {output, status} =
      System.cmd("bash", [@script, dir],
        env: [{"OPENSSL_BIN", Path.join(dir, "missing-openssl")}],
        stderr_to_stdout: true
      )

    assert status != 0
    assert output =~ "OPENSSL_BIN"
    assert output =~ "executable"
  end

  test "explicit certificate profile ignores machine configuration and stale serial files", %{
    tmp_dir: dir
  } do
    openssl = System.get_env("OPENSSL_BIN") || System.find_executable("openssl")
    selected = Path.join(dir, "selected openssl")
    File.ln_s!(openssl, selected)
    config = Path.join(dir, "machine.cnf")
    File.write!(config, "invalid machine OpenSSL configuration\n")
    File.write!(Path.join(dir, "ca.srl"), "not a serial\n")

    assert {output, 0} =
             System.cmd("bash", [@script, dir],
               env: [{"OPENSSL_BIN", selected}, {"OPENSSL_CONF", config}],
               stderr_to_stdout: true
             )

    assert output =~ selected
    assert output =~ "OpenSSL"
    assert {:ok, %{mode: mode}} = File.stat(Path.join(dir, "key.pem"))
    assert Bitwise.band(mode, 0o777) == 0o600
    assert File.read!(Path.join(dir, "ca.srl")) == "not a serial\n"
    refute File.exists?(Path.join(dir, "ca-key.pem"))
    refute File.exists?(Path.join(dir, "request.pem"))
  end

  test "server purpose and DNS/IP identities verify while wrong CA and hostname fail", %{
    tmp_dir: dir
  } do
    first = Path.join(dir, "first")
    second = Path.join(dir, "second")
    assert {_, 0} = System.cmd("bash", [@script, first], stderr_to_stdout: true)
    assert {_, 0} = System.cmd("bash", [@script, second], stderr_to_stdout: true)
    openssl = System.get_env("OPENSSL_BIN") || System.find_executable("openssl")
    certificate = Path.join(first, "cert.pem")
    base = ["verify", "-purpose", "sslserver", "-CAfile", Path.join(first, "ca.pem")]

    for identity <- [["-verify_hostname", "localhost"], ["-verify_ip", "127.0.0.1"]] do
      assert {_, 0} = System.cmd(openssl, base ++ identity ++ [certificate])
    end

    {hostname_output, hostname_status} =
      System.cmd(openssl, base ++ ["-verify_hostname", "wrong.example", certificate],
        stderr_to_stdout: true
      )

    assert hostname_status != 0
    assert hostname_output =~ "hostname mismatch"

    {ca_output, ca_status} =
      System.cmd(
        openssl,
        ["verify", "-CAfile", Path.join(second, "ca.pem"), certificate],
        stderr_to_stdout: true
      )

    assert ca_status != 0
    assert ca_output =~ "verification failed"
  end
end
