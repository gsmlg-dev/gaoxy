defmodule Gaoxy.Proxy.UpstreamTransportsTest do
  use ExUnit.Case, async: true

  alias Gaoxy.Proxy.UpstreamTransports, as: Transports
  alias Gaoxy.Proxy.UpstreamTransports.Custodian

  test "the temporary owner registers with its instance before resource creation" do
    {instance, owner} = owner()
    assert Transports.child_spec(instance: instance, limits: limits()).restart == :temporary

    assert Custodian.child_spec(owner: owner, resource: make_ref(), policy: nil).restart ==
             :temporary

    assert Enum.any?(:sys.get_state(instance).participants, fn {_, entry} ->
             entry.pid == owner
           end)

    assert {:ok, status} = Transports.status(owner)

    assert %{
             lifecycle: :running,
             resources: 0,
             reserved_connections: 0,
             pins: 0,
             request_tokens: 0,
             owned_serialized_payload_bytes: 0,
             helpers: 0
           } = status

    assert status.limits == limits()
  end

  test "startup rejects duplicate unknown options and invalid limits" do
    {:ok, instance} = Gaoxy.start_link()
    Process.unlink(instance)
    on_exit(fn -> Gaoxy.stop(instance, 100) end)

    for options <- [
          [instance: instance, limits: limits(), limits: limits()],
          [instance: instance, limits: limits(), transport: HTTP.ManagedTransport],
          [instance: instance],
          [instance: instance, limits: %{limits() | max_resources: 65}]
        ] do
      assert {:error, :invalid_options} = Transports.start_link(options)
    end
  end

  test "dead instances cannot create an owner or allocate transport resources" do
    dead = spawn(fn -> :ok end)
    monitor = Process.monitor(dead)
    assert_receive {:DOWN, ^monitor, :process, ^dead, _}, 1000

    assert {:error, :instance_unavailable} =
             Transports.start_link(instance: dead, limits: limits())
  end

  test "prepare returns only immutable provider identity and a preparation pin" do
    {_instance, owner} = owner()
    assert {:ok, handle, [pin]} = Transports.prepare(owner, policy_source(), self(), deadline())
    assert Enum.sort(Map.keys(handle)) == [:owner, :owner_epoch, :provider, :resource]
    assert %{provider: Transports, owner: ^owner, owner_epoch: epoch, resource: resource} = handle
    assert is_reference(epoch)
    assert is_reference(resource)
    assert pin.kind == :preparation
    assert pin.owner == owner

    assert {:ok,
            %{
              resources: 1,
              reserved_connections: 2,
              pins: 1,
              request_tokens: 0,
              lifecycle: :running
            } = status} = Transports.status(handle)

    assert status.owned_serialized_payload_bytes > 0
    refute Map.has_key?(status, :policy)
    refute Map.has_key?(status, :scope)
    assert {:error, :invalid_resource} = Transports.status(%{handle | owner_epoch: make_ref()})
    assert {:error, :invalid_resource} = Transports.status(%{handle | resource: make_ref()})
  end

  test "invalid preparation and impersonated preparers reject before reservation" do
    {_instance, owner} = owner()

    other =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    on_exit(fn -> send(other, :stop) end)

    assert {:error, :unauthorized} = Transports.prepare(owner, policy_source(), other, deadline())

    assert {:error, :invalid_policy} =
             Transports.prepare(owner, Map.put(policy_source(), :ssl, []), self(), deadline())

    assert {:error, {:deadline_exceeded, :cleanup_pending}} =
             Transports.prepare(
               owner,
               policy_source(),
               self(),
               System.monotonic_time(:millisecond)
             )

    assert {:ok, %{resources: 0, pins: 0, helpers: 0, owned_serialized_payload_bytes: 0}} =
             Transports.status(owner)
  end

  test "resource pin and payload capacities reject immediately without extra custodians" do
    for {owner_limits, capacity} <- [
          {%{limits() | max_resources: 1}, :resources},
          {%{limits() | max_pins: 1}, :pins}
        ] do
      {_instance, owner} = owner(owner_limits)
      assert {:ok, _, _} = Transports.prepare(owner, policy_source(), self(), deadline())
      assert {:ok, before} = Transports.status(owner)

      assert {:error, {:capacity, ^capacity}} =
               Transports.prepare(owner, policy_source(), self(), deadline())

      assert {:ok, ^before} = Transports.status(owner)
      assert map_size(:sys.get_state(owner).records) == 1
    end

    {_instance, owner} = owner(%{limits() | max_owned_payload_bytes: 1})

    assert {:error, {:capacity, :owned_payload}} =
             Transports.prepare(owner, policy_source(), self(), deadline())

    assert {:ok, %{resources: 0, pins: 0, helpers: 0, owned_serialized_payload_bytes: 0}} =
             Transports.status(owner)
  end

  test "late public open success cannot publish after the preparation deadline" do
    {_instance, owner} = owner()
    barrier = open_barrier(owner)
    parent = self()
    d = System.monotonic_time(:millisecond) + 100

    caller =
      spawn(fn ->
        send(parent, {:prepared, Transports.prepare(owner, policy_source(), self(), d)})
      end)

    monitor = Process.monitor(caller)
    assert_receive {:open_result_barrier, ^owner, custodian}, 1000
    assert Process.alive?(custodian)
    assert_receive {:prepared, {:error, {:deadline_exceeded, :cleanup_pending}}}, 1000
    assert_receive {:DOWN, ^monitor, :process, ^caller, :normal}, 1000
    send(owner, {:continue_open_result, barrier})

    eventually(fn ->
      match?({:ok, %{resources: 0, reserved_connections: 0}}, Transports.status(owner))
    end)

    refute_receive {:prepared, {:ok, _, _}}, 0
  end

  test "a dying preparer cannot publish a late scope and holds retire publicly" do
    {_instance, owner} = owner()
    barrier = open_barrier(owner)
    caller = spawn(fn -> Transports.prepare(owner, policy_source(), self(), deadline()) end)
    monitor = Process.monitor(caller)
    assert_receive {:open_result_barrier, ^owner, custodian}, 1000
    Process.exit(caller, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^caller, :killed}, 1000
    send(owner, {:continue_open_result, barrier})

    eventually(fn ->
      match?({:ok, %{resources: 0, pins: 0, reserved_connections: 0}}, Transports.status(owner))
    end)

    eventually(fn -> not Process.alive?(custodian) end)
  end

  test "custodian death retains failed physical ownership and prohibits blank restart" do
    {_instance, owner} = owner()
    assert {:ok, _, _} = Transports.prepare(owner, policy_source(), self(), deadline())
    [record] = Map.values(:sys.get_state(owner).records)
    monitor = Process.monitor(record.custodian)
    Process.exit(record.custodian, :kill)
    assert_receive {:DOWN, ^monitor, :process, _, :killed}, 1000
    eventually(fn -> match?({:ok, %{failed_resources: 1}}, Transports.status(owner)) end)
    assert {:ok, %{resources: 1, reserved_connections: 2}} = Transports.status(owner)
    assert map_size(:sys.get_state(owner).records) == 1
  end

  test "a local invalid policy is reported by the persistent custodian" do
    resource = make_ref()
    capability = make_ref()
    {:ok, custodian} = Custodian.start(owner: self(), resource: resource, policy: nil)
    send(custodian, {:open, capability})
    assert_receive {:custodian_open_result, ^resource, ^custodian, ^capability, {:error, _}}, 1000
    monitor = Process.monitor(custodian)
    send(custodian, {:discard, capability})
    assert_receive {:DOWN, ^monitor, :process, ^custodian, :normal}, 1000
  end

  test "a retirement helper result keeps its slot and payload until helper DOWN" do
    {_instance, owner} = owner(%{limits() | max_resources: 1})
    assert {:ok, _, _} = Transports.prepare(owner, policy_source(), self(), deadline())
    [entry] = Map.values(:sys.get_state(owner).records)
    parent = self()
    scope = :sys.get_state(entry.custodian).scope

    helper =
      spawn(fn ->
        receive do
          :retire ->
            result = HTTP.ManagedTransport.retire(scope, mode: :abort)
            send(entry.custodian, {:retire_result, self(), result})
            send(parent, {:helper_result_sent, self()})

            receive do
              :join -> :ok
            after
              2000 -> :ok
            end
        after
          2000 -> :ok
        end
      end)

    on_exit(fn -> send(helper, :join) end)

    :sys.replace_state(entry.custodian, fn state ->
      %{
        state
        | retire_helper: {helper, Process.monitor(helper)},
          cleanup_deadline: System.monotonic_time(:millisecond) + 1000
      }
    end)

    send(
      owner,
      {:custodian_helper_started, entry.resource, entry.custodian, entry.capability, helper}
    )

    send(owner, {:custodian_failed, entry.resource, entry.custodian, entry.capability})
    assert {:ok, before} = Transports.status(owner)
    assert before.helpers == 1
    assert before.failed_resources == 1
    send(helper, :retire)
    assert_receive {:helper_result_sent, ^helper}, 1000
    assert {:ok, held} = Transports.status(owner)
    assert held.resources == 1
    assert held.helpers == 1
    assert held.owned_serialized_payload_bytes == before.owned_serialized_payload_bytes
    assert Process.alive?(entry.custodian)

    assert {:error, {:capacity, :resources}} =
             Transports.prepare(owner, policy_source(), self(), deadline())

    send(helper, :join)
    eventually(fn -> match?({:ok, %{resources: 0, helpers: 0}}, Transports.status(owner)) end)
  end

  test "creator retirement receipt keeps its record and payload until creator DOWN" do
    for order <- [:receipt_first, :down_first] do
      {_instance, owner} = owner(%{limits() | max_resources: 1})
      assert {:ok, _, _} = Transports.prepare(owner, policy_source(), self(), deadline())
      [entry] = Map.values(:sys.get_state(owner).records)
      scope = :sys.get_state(entry.custodian).scope
      {:ok, receipt} = HTTP.ManagedTransport.retire(scope, mode: :abort)
      assert :ok = HTTP.ManagedTransport.await_retired(receipt, 1000)

      actor =
        spawn(fn ->
          receive do
            :join -> :ok
          after
            2000 -> :ok
          end
        end)

      on_exit(fn -> send(actor, :join) end)

      :sys.replace_state(owner, fn state ->
        Process.demonitor(entry.custodian_monitor, [:flush])

        put_in(state.records[entry.resource], %{
          entry
          | custodian: actor,
            custodian_monitor: Process.monitor(actor)
        })
      end)

      # The original scope creator is explicitly retired and joined as well;
      # the controlled actor exercises only Gaoxy's receipt/DOWN accounting.
      monitor = Process.monitor(entry.custodian)
      send(entry.custodian, {:retire, entry.capability})
      assert_receive {:DOWN, ^monitor, :process, _, :normal}, 1000
      assert {:ok, before} = Transports.status(owner)

      if order == :receipt_first do
        send(owner, {:custodian_retired, entry.resource, actor, entry.capability})
        assert {:ok, held} = Transports.status(owner)
        assert held.resources == 1
        assert held.reserved_connections == 0
        assert held.owned_serialized_payload_bytes == before.owned_serialized_payload_bytes

        assert {:error, {:capacity, :resources}} =
                 Transports.prepare(owner, policy_source(), self(), deadline())

        send(actor, :join)
      else
        send(actor, :join)
        eventually(fn -> :sys.get_state(owner).records[entry.resource].custodian_down end)
        assert {:ok, %{resources: 1, reserved_connections: 2}} = Transports.status(owner)
        send(owner, {:custodian_retired, entry.resource, actor, entry.capability})
      end

      eventually(fn ->
        match?({:ok, %{resources: 0, reserved_connections: 0}}, Transports.status(owner))
      end)
    end
  end

  test "helper DOWN before its relayed public result remains provisional and joinable" do
    {_instance, owner} = owner()
    assert {:ok, _, _} = Transports.prepare(owner, policy_source(), self(), deadline())
    [entry] = Map.values(:sys.get_state(owner).records)
    scope = :sys.get_state(entry.custodian).scope
    parent = self()

    helper =
      spawn(fn ->
        receive do
          :retire ->
            send(
              parent,
              {:held_public_result, self(), HTTP.ManagedTransport.retire(scope, mode: :abort)}
            )
        after
          2000 -> :ok
        end
      end)

    monitor = Process.monitor(helper)

    :sys.replace_state(entry.custodian, fn state ->
      %{
        state
        | retire_helper: {helper, Process.monitor(helper)},
          cleanup_deadline: System.monotonic_time(:millisecond) + 1000
      }
    end)

    send(
      owner,
      {:custodian_helper_started, entry.resource, entry.custodian, entry.capability, helper}
    )

    assert {:ok, %{helpers: 1}} = Transports.status(owner)
    send(helper, :retire)
    assert_receive {:held_public_result, ^helper, {:ok, _} = result}, 1000
    assert_receive {:DOWN, ^monitor, :process, ^helper, :normal}, 1000
    # System-state access is limited to our custodian, never dependency actors.
    eventually(fn -> :sys.get_state(entry.custodian).helper_down end)
    assert :sys.get_state(entry.custodian).retire_helper != nil
    assert {:ok, %{resources: 1, helpers: 1}} = Transports.status(owner)
    send(entry.custodian, {:retire_result, helper, result})
    eventually(fn -> match?({:ok, %{resources: 0, helpers: 0}}, Transports.status(owner)) end)
  end

  test "an admitted real public open error retains failed resource connection and payload holds" do
    {_instance, owner} = owner(%{limits() | max_resources: 1})
    parent = self()
    barrier = make_ref()

    :ok =
      :sys.install(
        owner,
        {fn state, event, _ ->
           case event do
             {:in, {:custodian_ready, _resource, custodian, _capability}} ->
               send(parent, {:ready_barrier, self(), custodian})

               receive do
                 {:continue_ready, ^barrier} -> :ok
               after
                 2000 -> raise "ready barrier timed out"
               end

             _ ->
               :ok
           end

           state
         end, barrier}
      )

    caller =
      spawn(fn ->
        send(
          parent,
          {:failed_open, Transports.prepare(owner, policy_source(), self(), deadline())}
        )
      end)

    assert_receive {:ready_barrier, ^owner, custodian}, 1000

    :sys.replace_state(custodian, fn state ->
      %{
        state
        | policy: %{
            state.policy
            | open_options: [origin: "http://example.test", http_version: :invalid]
          }
      }
    end)

    send(owner, {:continue_ready, barrier})
    assert_receive {:failed_open, {:error, _}}, 1000
    eventually(fn -> not Process.alive?(caller) end)
    assert {:ok, status} = Transports.status(owner)
    assert %{resources: 1, failed_resources: 1, reserved_connections: 2} = status
    assert status.owned_serialized_payload_bytes > 0

    assert {:error, {:capacity, :resources}} =
             Transports.prepare(owner, policy_source(), self(), deadline())

    refute_receive {:failed_open, {:ok, _, _}}, 0
  end

  defp open_barrier(owner) do
    parent = self()
    barrier = make_ref()

    :ok =
      :sys.install(
        owner,
        {fn state, event, _extra ->
           case event do
             {:in, {:custodian_open_result, _resource, custodian, _capability, _result}} ->
               send(parent, {:open_result_barrier, self(), custodian})

               receive do
                 {:continue_open_result, ^barrier} -> :ok
               after
                 2000 -> raise "test-owned open-result barrier timed out"
               end

             _ ->
               :ok
           end

           state
         end, barrier}
      )

    barrier
  end

  defp owner(owner_limits \\ limits()) do
    {:ok, instance} = Gaoxy.start_link()
    Process.unlink(instance)
    {:ok, owner} = Transports.start_link(instance: instance, limits: owner_limits)
    Process.unlink(owner)

    on_exit(fn ->
      custodians =
        if Process.alive?(owner),
          do: Enum.map(:sys.get_state(owner).records, fn {_, record} -> record.custodian end),
          else: []

      monitors = Enum.map(custodians, &{&1, Process.monitor(&1)})
      if Process.alive?(owner), do: GenServer.stop(owner, :normal, 1000)

      for {pid, monitor} <- monitors do
        receive do
          {:DOWN, ^monitor, :process, ^pid, _} -> :ok
        after
          6000 -> flunk("owned custodian did not join after owner shutdown")
        end
      end

      Gaoxy.stop(instance, 100)
    end)

    {instance, owner}
  end

  defp limits do
    %{max_resources: 2, max_pins: 8, max_request_tokens: 64, max_owned_payload_bytes: 131_072}
  end

  defp policy_source do
    %{origin: "http://example.test", connect_address: {127, 0, 0, 1}, trust: nil}
  end

  defp deadline, do: System.monotonic_time(:millisecond) + 1000

  defp eventually(fun, budget \\ 1000) do
    d = System.monotonic_time(:millisecond) + budget
    poll(fun, d)
  end

  defp poll(fun, d) do
    if fun.() do
      :ok
    else
      assert System.monotonic_time(:millisecond) < d, "bounded ledger condition did not settle"

      receive do
      after
        5 -> poll(fun, d)
      end
    end
  end
end
