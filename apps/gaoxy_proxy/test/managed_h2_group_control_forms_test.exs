defmodule Gaoxy.Proxy.ManagedH2GroupControlFormsTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.{ManagedH2GroupAccounting, UpstreamTransports}
  alias Gaoxy.Proxy.ManagedH2GroupAccounting, as: A

  @invalid {:error, :invalid_group_accounting}
  @timeout 5_000

  test "handoff keeps complete bounded original pin in I and only its named marker in E2048" do
    pin = pin(64)
    assert :erlang.external_size(pin) > 2_048

    assert {:ok, %{role: :i, projection: {:ok, ^pin}, cap: 393_216}} =
             A.project({:owner_reply, :transport, :pin}, {:ok, pin})

    ref = make_ref()
    original = {:gaoxy_transport_handoff, ref, {:ok, pin}, 9_000}

    assert {:ok, %{role: :e, projection: projected, bytes: bytes, cap: 2_048}} =
             A.project({:control, :handoff}, original)

    assert projected === {:gaoxy_transport_handoff, ref, {:ok, {:slot, :i}}, 9_000}
    assert bytes === :erlang.external_size(projected)
    assert bytes <= 2_048
  end

  test "handoff refuses malformed original pin or expanded whole envelope before projection" do
    p = pin()

    for bad <- [
          Map.put(p, :extra, nil),
          %{p | provider: :unknown},
          %{p | handles: [hd(p.handles) | :bad]}
        ] do
      assert @invalid ==
               A.project(
                 {:control, :handoff},
                 {:gaoxy_transport_handoff, make_ref(), {:ok, bad}, 9_000}
               )
    end

    assert @invalid ==
             A.project(
               {:control, :handoff},
               {:gaoxy_transport_handoff, make_ref(), {:ok, p}, 9_000, :expanded}
             )
  end

  test "complete_cleanup retains original Service token in existing scalar admission E24576" do
    original = {:complete_cleanup, make_ref()}

    assert {:ok, %{role: :e, projection: ^original, bytes: bytes, cap: 24_576}} =
             A.project({:control, :admission}, original)

    assert bytes === :erlang.external_size(original)
    assert :ok == A.validate({:control, :admission}, :ok)
    assert @invalid == A.project({:control, :admission}, {:complete_cleanup, self()})

    assert @invalid ==
             A.project(
               {:control, :admission},
               Tuple.insert_at(original, tuple_size(original), :expanded)
             )
  end

  test "known admission error field is normalized before finite projection without retaining raw diagnostics" do
    for {original, expected} <- [
          {{:error, :timeout}, {:error, :timeout}},
          {{:error, %{stack: [fn -> :arbitrary end]}}, {:error, :upstream_failure}}
        ] do
      assert {:ok, %{role: :e, projection: ^expected, cap: 24_576}} =
               A.project({:control, :admission}, original)
    end

    assert @invalid == A.project({:control, :admission}, {:error, :timeout, :expanded})
  end

  test "actual finite GenServer owner call and reply retain original alias tag in I and E" do
    request = {:release, pin()}
    {original, reply, tag} = actual_envelopes(request, :ok)
    assert [:alias | ref] = tag
    assert is_reference(ref)

    assert {:ok, %{role: :i, projection: ^original, cap: 393_216}} =
             A.project({:owner_call, :transport, :release}, original)

    assert {:ok, %{role: :i, projection: ^reply, cap: 393_216}} =
             A.project({:owner_reply, :transport, :release}, reply)

    assert {:ok, %{role: :e, projection: projected, cap: 24_576}} =
             A.project({:control, :owner}, original)

    assert projected === {:"$gen_call", {self(), tag}, {:slot, :i}}

    assert {:ok, %{role: :e, projection: ^reply, cap: 24_576}} =
             A.project({:control, :owner}, reply)
  end

  test "owner wrappers reject expanded or arbitrary tag lists without traversing them" do
    request = {:release, pin()}

    for tag <- [
          [:alias, make_ref()],
          [:alias | self()],
          [[:alias | make_ref()]],
          [:other | make_ref()],
          [fn -> :unbounded end]
        ] do
      assert @invalid ==
               A.project(
                 {:owner_call, :transport, :release},
                 {:"$gen_call", {self(), tag}, request}
               )

      assert @invalid == A.project({:owner_reply, :transport, :release}, {tag, :ok})
      assert @invalid == A.project({:control, :owner}, {:"$gen_call", {self(), tag}, request})
      assert @invalid == A.project({:control, :owner}, {tag, :ok})
    end
  end

  test "actual finite Service complete call and reply retain original alias tag in admission E" do
    request = {:complete_cleanup, make_ref()}
    {original, reply, _tag} = actual_envelopes(request, :ok)

    assert {:ok, %{role: :e, projection: ^original, cap: 24_576}} =
             A.project({:control, :admission}, original)

    assert {:ok, %{role: :e, projection: ^reply, cap: 24_576}} =
             A.project({:control, :admission}, reply)
  end

  test "owner preflight validates original bare I before future local public wrapper effect" do
    original = {:release, pin()}
    assert :ok == A.validate({:owner_call, :transport, :release}, original)
    assert :ok = preflight({:owner, :transport, :release}, original)
  end

  test "owner preflight refuses wrong provider operation and expanded original request" do
    original = {:release, pin()}

    for {selector, request} <- [
          {{:owner, :group, :release}, original},
          {{:owner, :transport, :unknown}, original},
          {{:owner, :unknown, :release}, original},
          {{:owner, :transport, :release},
           Tuple.insert_at(original, tuple_size(original), :expanded)},
          {{:owner, :transport, :release}, {:release, Map.put(elem(original, 1), :extra, nil)}}
        ],
        do: assert(@invalid == preflight(selector, request))
  end

  test "admission preflight bounds future public Service wrapper around original token" do
    original = {:complete_cleanup, make_ref()}
    assert :ok = preflight(:admission, original)
  end

  test "admission preflight rejects malformed and unknown original controls" do
    for original <- [
          {:complete_cleanup, self()},
          {:complete_cleanup, make_ref(), :expanded},
          {:unknown, make_ref()}
        ],
        do: assert(@invalid == preflight(:admission, original))
  end

  test "task receive preflight uses genuine original Task identities without creating identities" do
    task = %Task{owner: self(), pid: self(), ref: make_ref(), mfa: {:erlang, :apply, 2}}
    assert :ok = preflight(:task, {task.ref, task.pid})

    assert {:ok, %{role: :e, cap: 2_048}} =
             A.project({:control, :task}, {task.ref, {:error, :timeout}})

    assert {:ok, %{role: :e, cap: 2_048}} =
             A.project({:control, :down}, {:DOWN, task.ref, :process, task.pid, :timeout})
  end

  test "task preflight refuses malformed identity shell and expansions" do
    for original <- [
          {self(), make_ref()},
          {make_ref(), make_ref()},
          {make_ref(), self(), :expanded},
          %{ref: make_ref(), pid: self()}
        ],
        do: assert(@invalid == preflight(:task, original))
  end

  test "owed transport cancellation keeps original operation in existing owner scalar E" do
    operation = make_ref()
    original = {:"$gen_cast", {:cancel, operation}}

    assert {:ok, %{role: :e, projection: ^original, bytes: bytes, cap: 24_576}} =
             A.project({:control, :owner}, original)

    assert bytes === :erlang.external_size(original)

    for bad <- [
          {:"$gen_cast", {:cancel, self()}},
          {:"$gen_cast", {:cancel, operation, :expanded}},
          {:"$gen_cast", {:unknown, operation}}
        ],
        do: assert(@invalid == A.project({:control, :owner}, bad))
  end

  test "public subscription and stream ACK keep actual identities in existing acknowledge E2048 slot" do
    original_ref = make_ref()

    for original <- [{:read_chunk, self(), :ack}, {:stream_chunk_ack, original_ref}] do
      assert {:ok, %{role: :e, projection: ^original, bytes: bytes, cap: 2_048}} =
               A.project({:control, :acknowledge}, original)

      assert bytes === :erlang.external_size(original)
      assert bytes <= 2_048
    end

    for bad <- [
          {:read_chunk, original_ref, :ack},
          {:read_chunk, self(), :unknown},
          {:read_chunk, self(), :ack, :expanded},
          {:stream_chunk_ack, self()},
          {:stream_chunk_ack, original_ref, :expanded}
        ],
        do: assert(@invalid == A.project({:control, :acknowledge}, bad))
  end

  test "existing complete role caps phase math and reserve remain frozen" do
    c = ManagedH2GroupAccounting.contract()
    assert c.role_caps.i === 393_216
    assert c.role_caps.e === 131_072
    assert c.group_bytes === 7_033_906
    assert c.fixed_bytes === 9_444_956
    assert c.reservation_bytes === 16_478_862
    assert 16 * 2_048 + 4 * 24_576 === c.role_caps.e
  end

  defp pin(count \\ 1) do
    epoch = make_ref()

    handles =
      for _ <- 1..count,
          do: %{
            provider: UpstreamTransports,
            owner: self(),
            owner_epoch: epoch,
            resource: make_ref()
          }

    %{
      provider: UpstreamTransports,
      owner: self(),
      owner_epoch: epoch,
      operation: make_ref(),
      ref: make_ref(),
      handles: handles,
      kind: :request,
      holder: self()
    }
  end

  defp preflight(selector, original), do: apply(A, :preflight_control, [selector, original])

  defp actual_envelopes(request, response) do
    parent = self()

    server =
      spawn(fn ->
        receive do
          {:"$gen_call", from, _request} = original ->
            send(parent, {:original_call, self(), original, from})
            GenServer.reply(from, response)

            receive do
              :finish -> :ok
            after
              @timeout -> exit(:server_join_timeout)
            end
        after
          @timeout -> exit(:server_start_timeout)
        end
      end)

    monitor = Process.monitor(server)
    on_exit(fn -> if Process.alive?(server), do: Process.exit(server, :kill) end)
    :erlang.trace(server, true, [:send, {:tracer, parent}])
    assert response === GenServer.call(server, request, @timeout)
    assert_receive {:original_call, ^server, original, {_caller, tag}}, @timeout
    barrier = :erlang.trace_delivered(server)
    assert_receive {:trace_delivered, ^server, ^barrier}, @timeout
    assert_receive {:trace, ^server, :send, {^tag, ^response} = reply, _}, @timeout
    :erlang.trace(server, false, [:all])
    send(server, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^server, :normal}, @timeout
    {original, reply, tag}
  end
end
