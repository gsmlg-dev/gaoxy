defmodule Gaoxy.Proxy.ManagedH2PublicEndpointHostTest do
  use ExUnit.Case, async: true
  alias Gaoxy.Proxy.{ManagedH2GroupAccounting, UpstreamTransports}
  @timeout 5_000

  for {protocol, scheme, port} <- [{:http2, "https", 443}, {:h2c, "http", 80}] do
    test "#{protocol} public endpoint identity emits compact253-byte actual normalized host" do
      protocol = unquote(protocol)
      scheme = unquote(scheme)
      port = unquote(port)
      parent = self()
      host = Enum.join([String.duplicate("a", 63), String.duplicate("b", 63),
                        String.duplicate("c", 63), String.duplicate("d", 61)], ".")
      assert byte_size(host) === 253
      prefix = scheme <> "://" <> host <> ":"
      suffix = Integer.to_string(port)
      origin = :binary.copy(prefix <> String.duplicate("0", 8_192 - byte_size(prefix) - byte_size(suffix)) <> suffix)
      assert byte_size(origin) === 8_192
      assert :binary.referenced_byte_size(origin) === byte_size(origin)
      handle = %{provider: UpstreamTransports, owner: parent, owner_epoch: make_ref(), resource: make_ref()}
      deadline = Gaoxy.Lifecycle.deadline(@timeout)
      identity = %{origin: origin, upstream_protocol: protocol, instance: parent}
      {worker, monitor} = spawn_monitor(fn ->
        result = UpstreamTransports.validate_endpoint(handle, identity, deadline)
        send(parent, {:public_endpoint_result, self(), result})
      end)
      on_exit(fn -> if Process.alive?(worker), do: Process.exit(worker, :kill) end)
      assert_receive {:"$gen_call", from,
        {:validate_endpoint, ^handle, {^protocol, actual_scheme, actual_host, ^port} = authority,
         ^parent, ^deadline} = original}, @timeout
      # This is the actual request emitted by the supported public API. Reply
      # with a deliberate denial: this test grants no transport authority.
      GenServer.reply(from, {:error, :invalid_resource})
      assert_receive {:public_endpoint_result, ^worker, {:error, :invalid_resource}}, @timeout
      assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, @timeout
      assert actual_scheme === if(scheme == "https", do: :https, else: :http)
      assert actual_host === host
      assert byte_size(actual_host) === 253
      assert :binary.referenced_byte_size(actual_host) === byte_size(actual_host)
      assert authority === {protocol, actual_scheme, host, port}
      assert :ok === ManagedH2GroupAccounting.validate({:control, :identity}, original)
    end
  end
end
