Code.require_file(
  Path.expand("../../integration/http_fetch_contract/managed_h1_accounting_fixture.exs", __DIR__)
)

ExUnit.start(autorun: false, max_cases: 1, seed: 21_112_026, timeout: 5_000)

defmodule H1FixtureLedgerFaultTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Qualification.ManagedH1AccountingFixture.Ledger

  test "dead owned actor refusal preserves the cleanup ledger and counters" do
    with_owned_actor(fn ledger, actor, deadline ->
      send(actor, {:stop, deadline})
      assert :normal = GenServer.call(ledger, {:actor_join, 664, deadline})
      before = GenServer.call(ledger, :state)
      reply = command_result(ledger)

      assert Process.alive?(ledger)
      assert {:error, :actor_unavailable} = reply
      assert GenServer.call(ledger, :state) == before
    end)
  end

  test "second owned actor command preserves the original in-flight operation" do
    with_owned_actor(fn ledger, actor, _deadline ->
      assert {^actor, 1} = GenServer.call(ledger, {:command, 664})
      before = GenServer.call(ledger, :state)
      reply = command_result(ledger)

      assert Process.alive?(ledger)
      assert {:error, :actor_in_flight} = reply
      assert GenServer.call(ledger, :state) == before
    end)
  end

  defp command_result(ledger) do
    GenServer.call(ledger, {:command, 664})
  catch
    :exit, _ -> :ledger_call_exit
  end

  defp with_owned_actor(fun) do
    {:ok, ledger} = Ledger.start("LOCAL_LEDGER_FAULT_PROBE")
    ledger_monitor = Process.monitor(ledger)
    actor = GenServer.call(ledger, {:actor, 664, :peer, :local_fault_probe})
    actor_monitor = Process.monitor(actor)
    deadline = System.monotonic_time(:millisecond) + 2_000

    try do
      fun.(ledger, actor, deadline)
    after
      send(actor, {:stop, deadline})
      assert_receive {:DOWN, ^actor_monitor, :process, ^actor, :normal}, 2_000
      if Process.alive?(ledger), do: GenServer.stop(ledger)
      assert_receive {:DOWN, ^ledger_monitor, :process, ^ledger, _}, 2_000
    end
  end
end

totals = ExUnit.run()
IO.puts("H1_FIXTURE_LEDGER_REGRESSION_SUMMARY " <> inspect(totals))

if totals.total != 2 or totals.failures != 0 or totals.skipped != 0 or totals.excluded != 0,
  do: raise("local ledger regression failed")
