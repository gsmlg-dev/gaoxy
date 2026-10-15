unless Code.ensure_loaded?(Gaoxy.Proxy.ManagedH2FixedFixture) do
  Code.require_file("managed_h2_fixed_endpoint_test.exs", __DIR__)
end
Code.require_file("support/managed_h2_group_fixture.exs", __DIR__)

defmodule Gaoxy.Proxy.ManagedH2GroupStartupReservationTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH2GroupFixture, as: G
  alias Gaoxy.Proxy.{HTTP, UpstreamGroups, UpstreamTransports}
  alias Gaoxy.Proxy.HTTP.Session
  @startup 5_963_776

  for protocol <- [:http2, :h2c], downstream <- [:http1, :http2] do
    test "#{downstream} to #{protocol} startup denial precedes child creation and neutral copies" do
      f = G.fixture(unquote(protocol), unquote(downstream), ["--manual"], %{
        await_health: false, group_limits: %{probe_bytes: 16_478_861},
        service_limits: %{max_bytes: @startup - 1}
      })
      children = children()
      {response, events} = observed_request(f)
      assert response.status === 503
      assert adjustments(events, f.gate) |> Enum.map(&elem(&1, 1)) === [@startup]
      assert starts(events) === []
      refute Enum.any?(events, &match?({:return_from, _, {HTTP, :start_group_session, 5}, _}, &1))
      assert children() === children
      assert %{cleanup_pending: 0, cleanup_failed: nil, retained_bytes: 0,
        retained_high_water: high, rejected: rejected} = Gaoxy.status(f.instance, :http)
      assert high < @startup
      assert rejected >= 1
      assert_no_effect(f)
      G.close(f)
    end

    test "#{downstream} to #{protocol} attach denial joins the real inactive child before startup refund" do
      f = G.fixture(unquote(protocol), unquote(downstream), ["--manual"], %{
        await_health: false, group_limits: %{probe_bytes: 16_478_861},
        service_limits: %{max_bytes: 8_388_608}
      })
      children = children()
      {response, events} = observed_request(f)
      assert response.status === 503
      [{lease, @startup}, {same_lease, refund}] = adjustments(events, f.gate)
      assert same_lease === lease
      assert refund === -@startup
      assert [pid] = starts(events)
      refute Process.alive?(pid)
      assert children() === children
      helper_return = Enum.find_index(events, &match?({:return_from, _, {HTTP, :start_group_session, 5}, _}, &1))
      refund_call = Enum.find_index(events, fn
        {:call, _, {Gaoxy.Admission, :adjust_bytes, [gate, _, delta]}} -> gate === f.gate and delta === -@startup
        _ -> false
      end)
      assert is_integer(helper_return) and is_integer(refund_call)
      assert helper_return < refund_call
      assert %{cleanup_pending: 0, cleanup_failed: nil, retained_bytes: 0,
        retained_high_water: high} = Gaoxy.status(f.instance, :http)
      assert high >= @startup
      assert high <= f.service_bytes
      assert_no_effect(f)
      G.close(f)
    end
  end

  defp observed_request(f) do
    patterns = [{Gaoxy.Admission, :adjust_bytes, 3}, {Session, :start_link, 1}, {HTTP, :start_group_session, 5}]
    for pattern <- patterns, do: :erlang.trace_pattern(pattern, [{:_, [], [{:return_trace}]}], [:local])
    :erlang.trace(:all, true, [:call, :set_on_spawn, {:tracer, self()}])
    try do
      socket = G.connect(f)
      :ok = G.send_request(f, socket, "GET", "/startup?")
      response = G.response(f, socket)
      :ok = :gen_tcp.close(socket)
      G.clean(f)
      :erlang.trace(:all, false, [:call, :set_on_spawn])
      delivered = :erlang.trace_delivered(:all)
      assert_receive {:trace_delivered, :all, ^delivered}, 5_000
      {response, events([])}
    after
      :erlang.trace(:all, false, [:call, :set_on_spawn])
      for pattern <- patterns, do: :erlang.trace_pattern(pattern, false, [:local])
    end
  end

  defp events(acc) do
    receive do
      {:trace, pid, :call, call} -> events([{:call, pid, call} | acc])
      {:trace, pid, :return_from, call, result} -> events([{:return_from, pid, call, result} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
  defp adjustments(events, gate) do
    for {:call, _, {Gaoxy.Admission, :adjust_bytes, [^gate, lease, delta]}} <- events, do: {lease, delta}
  end
  defp starts(events), do: for {:return_from, _, {Session, :start_link, 1}, {:ok, pid}} <- events, do: pid
  defp children, do: DynamicSupervisor.which_children(Gaoxy.Proxy.SessionSupervisor) |> Enum.sort()
  defp assert_no_effect(f) do
    assert %{inflight: 0, probes: 0, probe_bytes: 0} = UpstreamGroups.status(f.group)
    assert {:ok, %{request_tokens: 0, helpers: 0}} = UpstreamTransports.status(f.owner)
    G.no_event(f.peer, "request")
  end
end
