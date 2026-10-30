defmodule BudgetTrace do
  def loop(calls) do
    receive do
      {:trace, pid, :call, {Gaoxy.Admission, :update_until, [gate, lease, bytes, _, _]}} ->
        loop(Map.put(calls, pid, {gate, lease, bytes}))
      {:trace, pid, :return_from, {Gaoxy.Admission, :update_until, 5}, result} ->
        if result != :ok, do: IO.puts("BUDGET_TRACE " <> inspect({pid, Map.get(calls, pid), result}, limit: :infinity))
        loop(Map.delete(calls, pid))
      _ -> loop(calls)
    end
  end
end
Code.ensure_loaded!(Gaoxy.Admission)
tracer = spawn(fn -> BudgetTrace.loop(%{}) end)
:erlang.trace(:all, true, [:call, {:tracer, tracer}])
:erlang.trace_pattern({Gaoxy.Admission, :update_until, 5}, [{:_, [], [{:return_trace}]}], [:local])
Mix.Task.run("test", ["apps/gaoxy_http/test/supervised_shutdown_budget_test.exs", "--seed", "0", "--max-cases", "1"])
