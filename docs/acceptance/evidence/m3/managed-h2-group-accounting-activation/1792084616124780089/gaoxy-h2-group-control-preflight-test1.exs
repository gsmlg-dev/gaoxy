defmodule Gaoxy.Proxy.ManagedH2GroupControlPreflightTest do
  use ExUnit.Case, async: true

  @accounting Gaoxy.Proxy.ManagedH2GroupAccounting
  @invalid {:error, :invalid_group_accounting}
  @min -9_223_372_036_854_775_808
  @max 9_223_372_036_854_775_807

  test "a real monitor target is pre-admitted without creating monitor or authority" do
    {:monitors, before} = Process.info(self(), :monitors)
    assert :ok === preflight(:monitor, self())
    assert Process.info(self(), :monitors) === {:monitors, before}
  end

  test "invalid monitor inputs are refused before any monitor effect" do
    assert @invalid === preflight(:monitor, nil)
    for value <- [make_ref(), {self()}, "pid", fn -> self() end] do
      assert @invalid === preflight(:monitor, value)
    end
  end

  test "source-local future monitor refs are distinct from arbitrary combined remote input" do
    assert :ok === preflight(:monitor, self())
    {pid, remote_ref} = large_untrusted_scalars()
    assert is_pid(pid) and is_reference(remote_ref)
    assert :ok === preflight(:monitor, pid)
    assert :erlang.external_size({:DOWN, remote_ref, :process, pid, :timeout}) > 2_048
    assert {:error, :group_accounting_capacity} ===
             apply(@accounting, :project, [{:control, :down}, {:DOWN, remote_ref, :process, pid, :timeout}])
    assert {:ok, %{cap: 2_048, bytes: bytes}} =
             apply(@accounting, :project, [{:control, :down}, {:DOWN, make_ref(), :process, pid, :timeout}])
    assert bytes <= 2_048
  end

  test "future local Service token cancellation supports the full signed deadline domain" do
    assert :ok === preflight(:cleanup_cancel, @min)
    for deadline <- [0, @max], do: assert(:ok === preflight(:cleanup_cancel, deadline))
  end

  test "an existing original token is checked with its complete cancellation wrapper" do
    token = make_ref()
    assert :ok === preflight(:cleanup_cancel, {:token, token, @max})
    assert {:ok, %{cap: 2_048, bytes: bytes}} =
             apply(@accounting, :project, [{:control, :cleanup_cancel}, {:gaoxy_cleanup_cancel, token, :timeout, @max}])
    assert bytes <= 2_048
  end

  test "invalid cancellation times and token shells are refused" do
    assert @invalid === preflight(:cleanup_cancel, @max + 1)
    for value <- [@min - 1, :infinity, nil, {:token, self(), @max}, {:token, make_ref(), @max + 1},
                  {:token, make_ref(), @max, :expanded}] do
      assert @invalid === preflight(:cleanup_cancel, value)
    end
  end

  test "preflight has a closed family and never accepts an arbitrary future envelope" do
    assert @invalid === preflight(:unknown, self())
    for family <- [:down, :cast, :new_monitor], do: assert(@invalid === preflight(family, self()))
  end

  test "preflight preserves already owed original cleanup and DOWN values" do
    assert :ok === preflight(:monitor, self())
    token = make_ref()
    assert :ok === preflight(:cleanup_cancel, {:token, token, @min})
    ref = make_ref()
    event = {:DOWN, ref, :process, self(), :timeout}
    assert {:ok, %{projection: ^event}} = apply(@accounting, :project, [{:control, :down}, event])
    assert ref === elem(event, 1)
  end

  defp preflight(kind, original), do: apply(@accounting, :preflight_control, [kind, original])

  # Public ETF types used only for local refusal tests, never as owner authority.
  defp large_untrusted_scalars do
    node_name = :binary.copy("😀", 255)
    atom = <<118, byte_size(node_name)::16, node_name::binary>>
    pid = :erlang.binary_to_term(<<131, 88, atom::binary, 1::32, 0::32, 0::32>>)
    ref = :erlang.binary_to_term(<<131, 90, 3::16, atom::binary, 0::32, 1::32, 2::32, 3::32>>)
    {pid, ref}
  end
end
