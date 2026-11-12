defmodule Gaoxy.DatagramDrainReplyTest do
  use ExUnit.Case, async: true

  defmodule Waiting do
    @behaviour Gaoxy.DatagramHandler
    def handle_datagram(%{data: "wait"}, owner) do
      send(owner, {:waiting, self()})

      receive do
        {:reply, output} -> {:reply, output}
      end
    end
  end

  defp eventually(fun, deadline \\ nil) do
    deadline = deadline || System.monotonic_time(:millisecond) + 2_000

    if fun.() do
      :ok
    else
      assert System.monotonic_time(:millisecond) < deadline, "condition deadline"

      receive do
      after
        5 -> eventually(fun, deadline)
      end
    end
  end

  defp rejections(runtime, id) do
    owner = self()
    reference = make_ref()
    %{generation: generation} = Gaoxy.handle(runtime, id)

    :ok =
      :telemetry.attach(
        reference,
        [:gaoxy, :admission_rejected],
        fn _, _, metadata, _ ->
          if metadata[:generation] == generation, do: send(owner, {reference, metadata.reason})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(reference) end)
    reference
  end

  @tag :loopback
  test "an admitted datagram replies from its funded headroom after drain fences growth" do
    ip = {127, 0, 0, 1}
    {:ok, client} = :gen_udp.open(0, [:binary, active: false, ip: ip])
    on_exit(fn -> :gen_udp.close(client) end)

    runtime =
      start_supervised!(
        {Gaoxy,
         services: [
           %{
             id: "drain",
             transport: :udp,
             handler: Waiting,
             handler_options: self(),
             limits: %{max_output: 16}
           }
         ]}
      )

    eventually(fn ->
      match?(%{state: :ready, backend: %{receive_credit: 1}}, Gaoxy.status(runtime, "drain"))
    end)

    events = rejections(runtime, "drain")
    %{local: {^ip, port}} = Gaoxy.info(runtime, "drain")
    :ok = :gen_udp.send(client, ip, port, "wait")
    assert_receive {:waiting, worker}, 2_000

    # The input stays retained; the whole reply allowance is temporary credit.
    assert %{active: 1, retained_bytes: 4, temporary_bytes: 16, transport_bytes: 20} =
             Gaoxy.status(runtime, "drain")

    owner = self()
    spawn(fn -> send(owner, {:removed, Gaoxy.remove(runtime, "drain", 2_000)}) end)
    eventually(fn -> Gaoxy.status(runtime, "drain").state == :draining end)

    send(worker, {:reply, "finished"})
    assert {:ok, {^ip, ^port, "finished"}} = :gen_udp.recv(client, 0, 2_000)
    assert_receive {:removed, :ok}, 2_500
    refute_received {^events, _}
  end
end
