defmodule Gaoxy.ResourceBudget.PolicyTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.ResourceBudget.Policy

  test "default limits use half physical capacity and twice that soft limit" do
    assert Policy.limits(%{capacity: 8_589_934_592}) == %{
             soft_limit: 4_294_967_296,
             hard_limit: 8_589_934_592
           }
  end

  test "unknown capacity uses 256 MiB soft and 512 MiB hard fallback" do
    assert Policy.limits(nil) == %{soft_limit: 268_435_456, hard_limit: 536_870_912}
    assert Policy.limits(%{capacity: nil, fallback?: true}) == Policy.limits(nil)
  end

  test "odd and maximum capacities use safe integer arithmetic" do
    assert Policy.limits(101) == %{soft_limit: 50, hard_limit: 100}

    assert Policy.limits(9_223_372_036_854_775_807) == %{
             soft_limit: 4_611_686_018_427_387_903,
             hard_limit: 9_223_372_036_854_775_806
           }

    assert Policy.limits(2) == %{soft_limit: 1, hard_limit: 2}
  end

  test "invalid capacities never produce unbounded or invalid budgets" do
    for value <- [0, 1, -1, :infinity, 9_223_372_036_854_775_808] do
      assert Policy.limits(value) == Policy.limits(nil)
    end
  end

  test "100 percent is normal and one byte above it is warning" do
    assert Policy.state(0, 100, 200) == :normal
    assert Policy.state(100, 100, 200) == :normal
    assert Policy.state(101, 100, 200) == :warning
  end

  test "200 percent remains warning and one byte above it is over limit" do
    assert Policy.state(200, 100, 200) == :warning
    assert Policy.state(201, 100, 200) == :over_limit
  end

  test "projected admission admits warning capacity and rejects crossing hard limit" do
    assert Policy.admit(100, 1, 200) == :ok
    assert Policy.admit(199, 1, 200) == :ok
    assert Policy.admit(0, 200, 200) == :ok
    assert Policy.admit(100, 101, 200) == {:error, :memory_hard_limit}
    assert Policy.admit(0, 201, 200) == {:error, :memory_hard_limit}
    assert Policy.admit(201, 0, 200) == {:error, :memory_hard_limit}
  end

  test "release remains possible above hard limit and admission recovers immediately" do
    assert Policy.admit(250, -1, 200) == :ok
    assert Policy.admit(250, -51, 200) == :ok
    assert Policy.admit(199, 1, 200) == :ok
  end

  test "invalid accounting is rejected without negative usage or arithmetic overflow" do
    for {usage, delta, hard} <- [
          {-1, 0, 200},
          {0, -1, 200},
          {0, 1, 0},
          {0, :infinity, 200},
          {nil, 1, 200}
        ] do
      assert Policy.admit(usage, delta, hard) == {:error, :invalid_usage}
    end

    assert Policy.admit(9_223_372_036_854_775_806, 2, 9_223_372_036_854_775_807) ==
             {:error, :memory_hard_limit}
  end
end
