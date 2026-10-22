defmodule Gaoxy.Test.ExpectationsTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.Test.Expectations, as: E

  test "normalization, duplicate routes and count validation" do
    handler = & &1
    {:ok, ledger} = E.register(E.new(), :get, "/same", handler, {:exact, 1})
    assert Map.has_key?(ledger.routes, {"GET", "/same"})
    assert {:error, "duplicate" <> _} = E.register(ledger, "GET", "/same", handler, :stub)
    assert {:error, _} = E.register(ledger, :get, "/bad", handler, {:exact, 0})
    assert_raise ArgumentError, fn -> E.normalize_path("/query?x=1") end
  end

  test "one exact reservation wins and excess never runs its handler" do
    {:ok, ledger} = E.register(E.new(), :post, "/once", & &1, {:exact, 1})
    {ledger, {:ok, 1, _handler}} = E.reserve(ledger, "POST", "/once")
    {ledger, {:error, 2, :excessive}} = E.reserve(ledger, :post, "/once")
    assert ledger.routes[{"POST", "/once"}].admitted == 1
    assert ledger.routes[{"POST", "/once"}].received == 2
    ledger = E.complete(ledger, 1, :ok)
    assert [%{type: :excessive, request_id: 2}] = E.report(ledger).failures
  end

  test "default at least once and zero-use stubs have distinct obligations" do
    {:ok, ledger} = E.register(E.new(), :get, "/required", & &1, :at_least_one)
    {:ok, ledger} = E.register(ledger, :get, "/optional", & &1, :stub)
    assert [%{type: :missing, route: {"GET", "/required"}}] = E.report(ledger).failures
    {ledger, {:ok, 1, _}} = E.reserve(ledger, :get, "/required")
    {ledger, {:ok, 2, _}} = E.reserve(ledger, :get, "/required")
    ledger = ledger |> E.complete(1, :ok) |> E.complete(2, :ok)
    assert E.report(ledger).status == :ok
  end

  test "snapshot excludes later admissions and retains pending callbacks" do
    {:ok, ledger} = E.register(E.new(), :get, "/snapshot", & &1, :at_least_one)
    {ledger, {:ok, 1, _}} = E.reserve(ledger, :get, "/snapshot")
    snapshot = E.snapshot(ledger)
    {ledger, {:error, 2, :unexpected}} = E.reserve(ledger, :get, "/later")
    assert [%{type: :pending, request_id: 1}] = E.report(ledger, snapshot).failures
    ledger = E.complete(ledger, 1, :ok)
    assert E.report(ledger, snapshot).status == :ok
    assert E.report(ledger).status == :error
  end

  test "failures survive completion and cancellation never refunds admission" do
    {:ok, ledger} = E.register(E.new(), :get, "/failed", & &1, {:exact, 1})
    {ledger, {:ok, 1, _}} = E.reserve(ledger, :get, "/failed")
    stacktrace = [{__MODULE__, :callback, 1, [file: ~c"fixture.exs", line: 17]}]
    ledger = E.complete(ledger, 1, {:failure, :throw, :original, stacktrace})

    assert [%{kind: :throw, reason: :original, stacktrace: ^stacktrace}] =
             E.report(ledger).failures

    {ledger, {:error, 2, :excessive}} = E.reserve(ledger, :get, "/failed")
    assert length(E.report(ledger).failures) == 2
  end

  test "upgraded callback waits for establishment in either order" do
    {:ok, ledger} = E.register(E.new(), :get, "/ws", & &1, :at_least_one)
    {ledger, {:ok, 1, _}} = E.reserve(ledger, :get, "/ws")
    upgraded = E.complete(ledger, 1, :upgraded)
    assert E.ordinary_pending(upgraded) == [1]
    {:ok, established} = E.establish(upgraded, 1)
    assert established.active == %{}
    {:ok, established} = E.establish(ledger, 1)
    assert E.ordinary_pending(established) == []
    assert E.complete(established, 1, :upgraded).active == %{}
  end
end
