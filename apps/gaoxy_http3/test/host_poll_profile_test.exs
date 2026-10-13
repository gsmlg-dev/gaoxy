defmodule Gaoxy.HTTP.HTTP3.HostPollProfileTest do
  use ExUnit.Case, async: false
  alias Gaoxy.{Config, Lifecycle}
  alias Gaoxy.HTTP.HTTP3
  @moduletag :tmp_dir

  defmodule Endpoint do
    def init(observer) do
      send(observer, :poll_endpoint_initialized)
      {:ok, observer}
    end

    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "poll-profile")
  end

  defp spec(tls \\ %{certfile: "fixture.pem", keyfile: "fixture-key.pem"}) do
    assert {:ok, completed} = HTTP3.service_spec(endpoint: {Endpoint, self()}, tls: tls)
    assert_receive :poll_endpoint_initialized
    completed
  end

  test "omission retains ten milliseconds and explicit finite boundaries normalize" do
    completed = spec()
    assert completed.quic == %{alpn: ["h3"], poll_interval: 10}

    for interval <- [1, 10, 1_000] do
      assert {:ok, selected} =
               Config.service(%{
                 completed
                 | quic: Map.put(completed.quic, :poll_interval, interval)
               })

      assert selected.quic == %{alpn: ["h3"], poll_interval: interval}
      assert selected.handler_options == completed.handler_options
    end

    refute_received :poll_endpoint_initialized
  end

  test "completed specification revalidation is idempotent without endpoint reinitialization" do
    completed = spec()

    assert {:ok, selected} =
             Config.service(%{completed | quic: Map.put(completed.quic, :poll_interval, 1)})

    assert {:ok, ^selected} = Config.service(selected)
    refute_received :poll_endpoint_initialized
  end

  test "invalid intervals fail before host allocation and unknown keys stay rejected" do
    completed = spec()

    for interval <- [0, -1, 1_001, 1.0, true, nil, "1", :infinity] do
      invalid = %{completed | quic: Map.put(completed.quic, :poll_interval, interval)}
      assert {:error, :invalid_quic_poll_interval} = Config.service(invalid)
      assert {:error, :invalid_quic_poll_interval} = Gaoxy.start_link(services: [invalid])
    end

    assert {:error, {:unknown_options, [:unknown]}} =
             Config.service(%{completed | quic: Map.put(completed.quic, :unknown, 1)})

    refute_received :poll_endpoint_initialized
  end

  test "the default ten-millisecond profile reaches the real public host and cleans up",
       context do
    host(context.tmp_dir, nil, 10)
  end

  test "the selected one-millisecond profile reaches the real public host and cleans up",
       context do
    host(context.tmp_dir, 1, 1)
  end

  defp host(directory, selected, expected) do
    root = Path.expand("../../..", __DIR__)
    {_, exit} = System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), directory])
    assert exit == 0
    deadline = Lifecycle.deadline(5_000)
    tls = %{certfile: Path.join(directory, "cert.pem"), keyfile: Path.join(directory, "key.pem")}
    completed = spec(tls)

    {:ok, completed} =
      if selected == nil,
        do: Config.service(completed),
        else:
          Config.service(%{completed | quic: Map.put(completed.quic, :poll_interval, selected)})

    assert completed.quic.poll_interval == expected
    refute_received :poll_endpoint_initialized

    # Trace only this supported public startup call in a synchronous test.
    # Its TLS arguments remain transient and are never printed or persisted.
    Code.ensure_loaded!(Abyss.QUIC)
    assert :erlang.trace_pattern({Abyss.QUIC, :start_link, 1}, true, [:local]) == 1
    :erlang.trace(:new, true, [:call, {:tracer, self()}])

    try do
      assert {:ok, runtime} = Gaoxy.start_link(services: [completed])
      on_exit(fn -> if Process.alive?(runtime), do: Gaoxy.stop(runtime, 1_000) end)

      forwarded =
        receive do
          {:trace, _caller, :call, {Abyss.QUIC, :start_link, [options]}} ->
            Keyword.get(options, :poll_interval)
        after
          remaining(deadline) -> flunk("public host startup trace missing")
        end

      assert forwarded == expected
      assert {:ok, {ip, port}} = Gaoxy.info(runtime, :http3).local
      assert port > 0
      status = Gaoxy.status(runtime, :http3)
      assert status.active == 0 and status.retained_bytes == 0 and status.cleanup_pending == 0
      assert status.cleanup_failed == nil
      monitor = Process.monitor(runtime)
      assert :ok = Gaoxy.stop(runtime, remaining(deadline))
      assert_receive {:DOWN, ^monitor, :process, ^runtime, :normal}, remaining(deadline)
      assert {:ok, rebound} = :gen_udp.open(port, [:binary, active: false, ip: ip])
      assert :ok = :gen_udp.close(rebound)
    after
      :erlang.trace(:new, false, [:call])
      :erlang.trace_pattern({Abyss.QUIC, :start_link, 1}, false, [:local])
    end
  end

  defp remaining(deadline) do
    value = Lifecycle.remaining(deadline)
    assert value > 0, "original host-profile lifecycle deadline expired"
    value
  end
end
