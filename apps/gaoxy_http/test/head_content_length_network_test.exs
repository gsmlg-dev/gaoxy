Code.require_file("support/head_content_length_fixture.exs", __DIR__)

defmodule Gaoxy.HeadContentLengthNetworkTest do
  use ExUnit.Case, async: true

  for protocol <- [:http1, :http2] do
    @protocol protocol
    test "#{protocol} preserves explicit HEAD metadata and ordinary GET/status semantics" do
      options = [plug: {Gaoxy.HeadContentLengthFixture, []}, protocols: [@protocol]]
      options = if @protocol == :http2, do: options ++ [h2c: :prior_knowledge], else: options
      {:ok, server} = Gaoxy.HTTP.start_link(options)
      on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
      {:ok, {_, port}} = Gaoxy.info(server, :http).local
      root = Path.expand("../../..", __DIR__)
      python = System.get_env("GAOXY_H2_PYTHON") || Path.join(root, ".audit/h2peer/bin/python")
      protocol = if @protocol == :http1, do: "h1", else: "h2"

      {output, exit} =
        System.cmd(
          python,
          [Path.join(__DIR__, "support/head_content_length_peer.py"), protocol, to_string(port)],
          cd: root,
          stderr_to_stdout: true
        )

      assert exit == 0, output
      assert length(Regex.scan(~r/PASS H[12] /, output)) == 16, output
      IO.write(output)
      assert :ok = Gaoxy.stop(server)
    end
  end
end
