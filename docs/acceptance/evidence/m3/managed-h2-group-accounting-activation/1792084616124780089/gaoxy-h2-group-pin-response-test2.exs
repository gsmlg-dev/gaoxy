defmodule Gaoxy.Proxy.ManagedH2GroupPinResponseTest do
  use ExUnit.Case, async: true
  alias Gaoxy.Proxy.{ManagedH2GroupAccounting, UpstreamGroups, UpstreamTransports}
  @invalid {:error, :invalid_group_accounting}

  for {owner, provider} <- [group: UpstreamGroups, transport: UpstreamTransports] do
    test "#{owner} Resources pin_many keeps the complete original list response in I" do
      selector = {:owner_reply, unquote(owner), :pin}
      pin = pin(unquote(provider))
      original = {:ok, [pin]}
      assert {:ok, %{role: :i, projection: ^original, bytes: bytes, cap: 393_216}} =
               ManagedH2GroupAccounting.project(selector, original)
      assert bytes === :erlang.external_size(original)
      assert bytes > :erlang.external_size(pin)
      assert :ok === ManagedH2GroupAccounting.validate(selector, original)
    end

    test "#{owner} public reply wrapper preserves its genuine ref and whole list shell" do
      selector = {:owner_reply, unquote(owner), :pin}
      ref = make_ref()
      original = {ref, {:ok, [pin(unquote(provider))]}}
      assert {:ok, %{role: :i, projection: ^original, bytes: bytes, cap: 393_216}} =
               ManagedH2GroupAccounting.project(selector, original)
      assert bytes === :erlang.external_size(original)
      assert :ok === ManagedH2GroupAccounting.validate(selector, original)
    end
  end

  test "Resources response validates every original pin and rejects unknown list shells" do
    pin = pin(UpstreamTransports)
    selector = {:owner_reply, :transport, :pin}
    for original <- [
          {:ok, [pin | :improper]},
          {:ok, List.duplicate(pin, 65)},
          {:ok, [Map.put(pin, :extra, fn -> :unbounded end)]},
          {:ok, [pin(UpstreamGroups)]},
          {:ok, [pin], :expanded}
        ] do
      assert @invalid === ManagedH2GroupAccounting.project(selector, original)
      assert @invalid === ManagedH2GroupAccounting.validate(selector, original)
    end
  end

  test "Resources containing response preserves the existing complete65536 capture gate" do
    original_pin = pin(UpstreamTransports)
    [base] = original_pin.handles
    handles = for _ <- 1..64, do: %{base | resource: make_ref()}
    pin = %{original_pin | handles: handles}
    assert {:ok, %{projection: [^pin]}} = ManagedH2GroupAccounting.project(:captured_pins, [pin])
    captures = List.duplicate(pin, 64)
    assert :erlang.external_size(captures) > 65_536
    assert {:ok, ^handles} = Gaoxy.HTTP.Resources.validate(handles)
    assert @invalid === ManagedH2GroupAccounting.project({:owner_reply, :transport, :pin}, {:ok, captures})
  end

  defp transport, do: %{provider: UpstreamTransports, owner: self(), owner_epoch: make_ref(), resource: make_ref()}
  defp pin(UpstreamTransports) do
    transport = transport()
    %{provider: UpstreamTransports, owner: self(), owner_epoch: transport.owner_epoch,
      ref: make_ref(), operation: make_ref(), handles: [transport], kind: :request, holder: self()}
  end
  defp pin(UpstreamGroups) do
    transport = transport()
    group = %{provider: UpstreamGroups, owner: self(), owner_epoch: make_ref(), group: "group",
      generation: make_ref(), max_url_bytes: 8_192, transports: [transport], execution_profile: :managed_h2}
    %{provider: UpstreamGroups, owner: self(), owner_epoch: group.owner_epoch,
      ref: make_ref(), operation: make_ref(), handles: [group], kind: :request}
  end
end
