defmodule Gaoxy.AdmissionTimeoutTest do
  use ExUnit.Case, async: true
  alias Gaoxy.Admission

  @tag :checked_capture_constructor
  test "update/4 changes exact retained bytes on a real caller-owned lease" do
    assert_update_timeout_api!()
    gate = gate()
    assert {:ok, lease} = Admission.acquire(gate, 10)
    assert %{active: 1, retained_bytes: 10} = Admission.status(gate)
    assert :ok = apply(Admission, :update, [gate, lease, 37, 1000])
    assert %{active: 1, retained_bytes: 37, retained_high_water: 37} = Admission.status(gate)
    assert :ok = Admission.retain(gate, lease, 0)
    assert %{retained_bytes: 0} = Admission.status(gate)
  end

  @tag :checked_capture_constructor
  test "update/4 reports its explicit timeout while a real gate is suspended" do
    assert_update_timeout_api!()
    gate = gate()
    assert {:ok, lease} = Admission.acquire(gate, 10)
    assert %{retained_bytes: 10} = Admission.status(gate)
    assert :ok = :sys.suspend(gate, 1000)

    try do
      assert {:timeout, {GenServer, :call, [^gate, {:update, ^lease, 37}, 25]}} =
               catch_exit(apply(Admission, :update, [gate, lease, 37, 25]))
    after
      assert :ok = :sys.resume(gate, 1000)
    end

    # A timeout is not :ok or permission for a caller to advance. The request
    # remains queued and can still execute; this API does not cancel it.
    assert %{active: 1, retained_bytes: 37} = Admission.status(gate)
    assert :ok = Admission.retain(gate, lease, 0)
    assert %{retained_bytes: 0} = Admission.status(gate)
  end

  @tag timeout: 10_000
  @tag :checked_capture_constructor
  test "legacy update/3 retains its success behavior and actual default 5000ms timeout" do
    gate = gate()
    assert {:ok, lease} = Admission.acquire(gate, 10)
    assert :ok = Admission.update(gate, lease, 19)
    assert %{retained_bytes: 19} = Admission.status(gate)
    assert :ok = :sys.suspend(gate, 1000)

    try do
      assert {:timeout, {GenServer, :call, [^gate, {:update, ^lease, 23}, 5000]}} =
               catch_exit(Admission.update(gate, lease, 23))
    after
      assert :ok = :sys.resume(gate, 1000)
    end

    assert %{retained_bytes: 23} = Admission.status(gate)
    assert :ok = Admission.retain(gate, lease, 0)
    assert %{retained_bytes: 0} = Admission.status(gate)
  end

  defp assert_update_timeout_api! do
    assert Code.ensure_loaded?(Admission)

    assert function_exported?(Admission, :update, 4),
           "missing additive Admission.update/4 explicit-timeout API"
  end

  defp gate do
    # Same real Admission limits shape as QUICContextTest; no handler/listener
    # mock is needed to acquire a real lease owned by this calling test process.
    limits = %{max_active: 1, max_bytes: 100, max_state: 65_536, callback_timeout: 5000}
    scope = %{service: "native", instance: self(), generation: make_ref(), service_pid: self()}
    start_supervised!({Admission, {limits, scope}})
  end
end
