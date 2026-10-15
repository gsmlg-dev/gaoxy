defmodule Gaoxy.Proxy.ManagedH2FixedPeerStartupTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH2FixedFixture, as: F

  test "ready wait reports an already dead collector instead of a generic ready timeout" do
    {peer, monitor} = spawn_monitor(fn -> :ok end)
    assert_receive {:DOWN, ^monitor, :process, ^peer, :normal}, 5_000

    assert_raise ExUnit.AssertionError, "peer collector exited :noproc before ready", fn ->
      F.event(peer, "ready")
    end
  end

  test "ready wait retains the peer's primary startup failure" do
    peer = self()
    failure = %{"event" => "failure", "reason" => "certificate preparation failed"}
    send(self(), {:fixed_h2_peer, peer, failure})

    assert_raise ExUnit.AssertionError, inspect(failure), fn ->
      F.event(peer, "ready")
    end
  end

  test "ready wait retains a real port exit status" do
    peer = self()
    send(self(), {:fixed_h2_peer_exit, peer, 23})

    assert_raise ExUnit.AssertionError, "peer exited 23 before ready", fn ->
      F.event(peer, "ready")
    end
  end
end
