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

  test "same-owner metadata batches count handles and release idempotently" do
    {_instance, owner} = owner()
    {:ok, first, _} = Transports.prepare(owner, policy_source(), self(), deadline())
    {:ok, second, _} = Transports.prepare(owner, policy_source(), self(), deadline())

    assert {:ok, [pin]} =
             Gaoxy.HTTP.Resources.pin_many([first, second, first], self(), :baseline, deadline())

    assert pin.kind == :baseline
    assert {:ok, %{pins: 4} = held} = Transports.status(owner)
    assert :ok = Gaoxy.HTTP.Resources.release([pin])
    assert :ok = Gaoxy.HTTP.Resources.release([pin])
    assert {:ok, %{pins: 2} = released} = Transports.status(owner)
    assert released.owned_serialized_payload_bytes < held.owned_serialized_payload_bytes
  end

  test "stale batches are atomic and facade failure rolls back other owners" do
    {_first_instance, first_owner} = owner()
    {_second_instance, second_owner} = owner(%{limits() | max_pins: 1})
    {:ok, first, _} = Transports.prepare(first_owner, policy_source(), self(), deadline())
    {:ok, second, _} = Transports.prepare(second_owner, policy_source(), self(), deadline())
    {:ok, before} = Transports.status(first_owner)
    stale = %{first | owner_epoch: make_ref()}

    assert {:error, :invalid_resource} =
             Transports.pin_many([first, stale], self(), :baseline, make_ref(), deadline())

    assert {:ok, ^before} = Transports.status(first_owner)

    assert {:error, {:capacity, :pins}} =
             Gaoxy.HTTP.Resources.pin_many([first, second], self(), :baseline, deadline())

    assert {:ok, ^before} = Transports.status(first_owner)
    assert {:ok, %{pins: 1}} = Transports.status(second_owner)
  end

  test "operation cancellation and live replay stay bounded without tombstones" do
    {_instance, owner} = owner()
    {:ok, handle, _} = Transports.prepare(owner, policy_source(), self(), deadline())
    operation = make_ref()
    assert {:ok, pin} = Transports.pin_many([handle], self(), :request, operation, deadline())
    assert {:ok, ^pin} = Transports.pin_many([handle], self(), :request, operation, deadline())
    assert {:ok, %{pins: 2}} = Transports.status(owner)
    assert :ok = Transports.cancel(owner, operation)
    assert :ok = Transports.cancel(owner, operation)
    assert {:ok, %{pins: 1}} = Transports.status(owner)

    for _ <- 1..100 do
      assert :ok = Transports.cancel(owner, make_ref())
    end

    assert map_size(:sys.get_state(owner).pins) == 1
    assert :ok = Gaoxy.HTTP.Resources.release(pin)
  end

  test "an admitted pin cannot escape when its suspended caller resumes past D" do
    {_instance, owner} = owner()
    {:ok, handle, _} = Transports.prepare(owner, policy_source(), self(), deadline())
    operation = make_ref()
    parent = self()

    :ok =
      :sys.install(
        owner,
        {fn state, event, _ ->
           case event do
             {:in, {:"$gen_call", {caller, _}, {:pin_many, _, _, _, ^operation, _}}} ->
               :erlang.suspend_process(caller)
               send(parent, {:pin_caller_suspended, caller})

             _ ->
               :ok
           end

           state
         end, operation}
      )

    d = System.monotonic_time(:millisecond) + 200

    {caller, caller_monitor} =
      spawn_monitor(fn ->
        send(
          parent,
          {:late_pin_result, Transports.pin_many([handle], parent, :request, operation, d)}
        )
      end)

    on_exit(fn ->
      monitor = Process.monitor(caller)

      if Process.alive?(owner) do
        :sys.replace_state(owner, fn state ->
          if Process.info(caller, :status) == {:status, :suspended},
            do: :erlang.resume_process(caller)

          state
        end)
      end

      receive do
        {:DOWN, ^monitor, :process, ^caller, _} -> :ok
      after
        1500 -> flunk("late pin caller did not join")
      end
    end)

    assert_receive {:pin_caller_suspended, ^caller}, 1000
    assert {:ok, %{pins: 2}} = Transports.status(owner)

    receive do
    after
      max(d - System.monotonic_time(:millisecond), 0) -> :ok
    end

    :sys.replace_state(owner, fn state ->
      :erlang.resume_process(caller)
      state
    end)

    assert_receive {:late_pin_result, {:error, {:deadline_exceeded, :cleanup_pending}}}, 1000
    assert_receive {:DOWN, ^caller_monitor, :process, ^caller, :normal}, 1000
    eventually(fn -> match?({:ok, %{pins: 1}}, Transports.status(owner)) end)
  end

  test "holder DOWN releases metadata and closed configuration refuses new pins" do
    {_instance, owner} = owner()
    {:ok, handle, preparation} = Transports.prepare(owner, policy_source(), self(), deadline())

    holder =
      spawn(fn ->
        receive do
          :join -> :ok
        after
          2000 -> :ok
        end
      end)

    assert {:ok, [request_pin]} =
             Gaoxy.HTTP.Resources.pin_many([handle], holder, :request, deadline())

    assert :ok = Gaoxy.HTTP.Resources.release(preparation)

    assert {:error, :resource_admission_closed} =
             Gaoxy.HTTP.Resources.pin_many([handle], self(), :baseline, deadline())

    assert {:ok, %{pins: 1, resources: 1}} = Transports.status(owner)
    send(holder, :join)
    eventually(fn -> match?({:ok, %{pins: 0, resources: 0}}, Transports.status(owner)) end)
    assert :ok = Gaoxy.HTTP.Resources.release(request_pin)
  end

  test "metadata and token payload refusal leave exact counters unchanged" do
    {_instance, owner} = owner()
    {:ok, handle, _} = Transports.prepare(owner, policy_source(), self(), deadline())
    {:ok, [request_pin]} = Gaoxy.HTTP.Resources.pin_many([handle], self(), :request, deadline())
    {:ok, before} = Transports.status(owner)

    :sys.replace_state(owner, fn state ->
      %{
        state
        | limits: %{state.limits | max_owned_payload_bytes: before.owned_serialized_payload_bytes}
      }
    end)

    assert {:error, {:capacity, :owned_payload}} =
             Gaoxy.HTTP.Resources.pin_many([handle], self(), :baseline, deadline())

    assert {:error, {:capacity, :owned_payload}} =
             Transports.checkout(handle, [request_pin], self(), deadline())

    assert {:ok, after_refusal} = Transports.status(owner)
    assert after_refusal.pins == before.pins
    assert after_refusal.request_tokens == 0
    assert after_refusal.owned_serialized_payload_bytes == before.owned_serialized_payload_bytes
  end

  test "checkout authenticates guardian and admitted request pin and returns frozen client policy" do
    {_instance, owner} = owner()
    {:ok, handle, preparation} = Transports.prepare(owner, policy_source(), self(), deadline())

    assert {:error, :invalid_resource_pin} =
             Transports.checkout(handle, preparation, self(), deadline())

    assert {:ok, [pin]} = Gaoxy.HTTP.Resources.pin_many([handle], self(), :request, deadline())

    guardian =
      spawn(fn ->
        receive do
          :join -> :ok
        after
          2000 -> :ok
        end
      end)

    on_exit(fn -> send(guardian, :join) end)
    assert {:error, :unauthorized} = Transports.checkout(handle, [pin], guardian, deadline())

    assert {:error, :invalid_resource_pin} =
             Transports.checkout(handle, [%{pin | ref: make_ref()}], self(), deadline())

    assert {:ok, client, token} = Transports.checkout(handle, [pin], self(), deadline())
    assert is_reference(token)
    refute token == pin.ref
    assert client.policy.origin == policy_source().origin

    assert client.fetch_options == [
             http_version: :http1,
             tls_backend: :ssl,
             http1_reuse: true,
             redirect: :manual,
             request_mode: :proxy,
             decode_body: false,
             stream_response: true,
             telemetry: false
           ]

    assert Map.has_key?(client, :transport_scope)
    assert {:ok, %{request_tokens: 1, reserved_connections: 2}} = Transports.status(owner)
    assert :ok = Gaoxy.HTTP.Resources.release(preparation)
    assert {:ok, _, _} = Transports.checkout(handle, [pin], self(), deadline())
  end

  test "owner token budget and resource R32 reject immediately without queueing" do
    for {owner_limits, count} <- [{%{limits() | max_request_tokens: 1}, 1}, {limits(), 32}] do
      {_instance, owner} = owner(owner_limits)
      {:ok, handle, _} = Transports.prepare(owner, policy_source(), self(), deadline())
      {:ok, request_pins} = Gaoxy.HTTP.Resources.pin_many([handle], self(), :request, deadline())

      for _ <- 1..count do
        assert {:ok, _, _} = Transports.checkout(handle, request_pins, self(), deadline())
      end

      {:ok, before} = Transports.status(owner)

      assert {:error, {:capacity, :request_tokens}} =
               Transports.checkout(handle, request_pins, self(), deadline())

      assert {:ok, ^before} = Transports.status(owner)
      assert before.request_tokens == count
    end
  end

  test "unbound guardian death retains request credit after public transport retirement" do
    {_instance, owner} = owner()
    {:ok, handle, _} = Transports.prepare(owner, policy_source(), self(), deadline())
    parent = self()

    guardian =
      spawn(fn ->
        {:ok, pins} = Gaoxy.HTTP.Resources.pin_many([handle], self(), :request, deadline())
        result = Transports.checkout(handle, pins, self(), deadline())
        send(parent, {:unbound_checkout, result})

        receive do
          :join -> :ok
        after
          2000 -> :ok
        end
      end)

    assert_receive {:unbound_checkout, {:ok, _, token}}, 1000
    send(guardian, :join)
    eventually(fn -> match?({:ok, %{reserved_connections: 0}}, Transports.status(owner)) end)
    assert {:ok, %{resources: 1, request_tokens: 1}} = Transports.status(owner)
    assert :sys.get_state(owner).tokens[token].completion == nil
  end

  test "unbound finish is cleanup unconfirmed and never refunds the request token" do
    {_instance, owner} = owner()
    {:ok, handle, _} = Transports.prepare(owner, policy_source(), self(), deadline())
    {:ok, pins} = Gaoxy.HTTP.Resources.pin_many([handle], self(), :request, deadline())
    {:ok, _, token} = Transports.checkout(handle, pins, self(), deadline())
    assert {:error, :cleanup_unconfirmed} = Transports.finish(handle, token)
    eventually(fn -> match?({:ok, %{reserved_connections: 0}}, Transports.status(owner)) end)
    assert {:ok, %{request_tokens: 1, resources: 1}} = Transports.status(owner)
    assert {:error, :cleanup_unconfirmed} = Transports.finish(handle, token)
  end

  test "settling one retired member retains the grouped baseline and its live member" do
    {first_source, first_peer} = completion_peer()
    {second_source, second_peer} = completion_peer()
    {_instance, owner} = owner()

    {:ok, first, first_preparation} =
      Transports.prepare(owner, first_source, self(), deadline())

    {:ok, second, second_preparation} =
      Transports.prepare(owner, second_source, self(), deadline())

    {:ok, [baseline]} =
      Gaoxy.HTTP.Resources.pin_many([first, second], self(), :baseline, deadline())

    assert :ok = Gaoxy.HTTP.Resources.release(first_preparation)
    assert :ok = Gaoxy.HTTP.Resources.release(second_preparation)
    {:ok, first_pins} = Gaoxy.HTTP.Resources.pin_many([first], self(), :request, deadline())

    assert {:ok, %{resources: 2, reserved_connections: 4, pins: 3} = before_request} =
             Transports.status(owner)

    {:ok, client, token} = Transports.checkout(first, first_pins, self(), deadline())
    promise = fetch_public(client, first_source.origin <> "/")
    completion = HTTP.Promise.completion(promise)
    assert_receive {:completion_request, ^first_peer}, 1000
    custodian = :sys.get_state(owner).records[first.resource].custodian
    monitor = Process.monitor(custodian)
    assert {:error, :cleanup_unconfirmed} = Transports.finish(first, token)
    assert :ok = Transports.bind_completion(first, token, completion)
    assert :ok = HTTP.RequestCompletion.await(completion, 1000)
    assert_receive {:DOWN, ^monitor, :process, ^custodian, :normal}, 1000
    assert :ok = Transports.finish(first, token)

    assert {:ok, %{resources: 2, reserved_connections: 2, pins: 3, request_tokens: 0} = settled} =
             Transports.status(owner)

    assert settled.owned_serialized_payload_bytes == before_request.owned_serialized_payload_bytes

    assert {:ok, second_pins} =
             Gaoxy.HTTP.Resources.pin_many([second], self(), :request, deadline())

    assert {:ok, second_client, second_token} =
             Transports.checkout(second, second_pins, self(), deadline())

    second_promise = fetch_public(second_client, second_source.origin <> "/")
    second_completion = HTTP.Promise.completion(second_promise)
    assert :ok = Transports.bind_completion(second, second_token, second_completion)
    assert_receive {:completion_request, ^second_peer}, 1000
    send(second_peer, :respond)
    assert %HTTP.Response{status: 200, stream: stream} = HTTP.Promise.await(second_promise, 1000)
    assert read_public_stream(stream) == "ok"
    assert :ok = HTTP.RequestCompletion.await(second_completion, 1000)
    assert :ok = Transports.finish(second, second_token)
    assert :ok = Gaoxy.HTTP.Resources.release(second_pins)
    assert :ok = Gaoxy.HTTP.Resources.release(first_pins)

    assert {:ok, %{resources: 2, reserved_connections: 2, pins: 2, request_tokens: 0}} =
             Transports.status(owner)

    assert :ok = Gaoxy.HTTP.Resources.release(baseline)
    assert :ok = Gaoxy.HTTP.Resources.release(baseline)

    eventually(fn ->
      match?(
        {:ok,
         %{resources: 0, reserved_connections: 0, pins: 0, owned_serialized_payload_bytes: 0}},
        Transports.status(owner)
      )
    end)
  end

  test "only original public completion settles exactly the request hold while idle scope stays" do
    {source, peer} = completion_peer()
    {_instance, owner} = owner()
    {:ok, handle, _} = Transports.prepare(owner, source, self(), deadline())
    {:ok, pins} = Gaoxy.HTTP.Resources.pin_many([handle], self(), :request, deadline())
    {:ok, client, token} = Transports.checkout(handle, pins, self(), deadline())
    assert {:error, :invalid_completion} = Transports.bind_completion(handle, token, nil)
    promise = fetch_public(client, source.origin <> "/")
    completion = HTTP.Promise.completion(promise)
    assert :ok = Transports.bind_completion(handle, token, completion)
    parent = self()

    spawn(fn ->
      send(
        parent,
        {:intruder_request_ops, Transports.bind_completion(handle, token, completion),
         Transports.finish(handle, token)}
      )
    end)

    assert_receive {:intruder_request_ops, {:error, :unauthorized}, {:error, :unauthorized}}, 1000

    assert {:error, :completion_already_bound} =
             Transports.bind_completion(handle, token, completion)

    assert_receive {:completion_request, ^peer}, 1000
    assert {:error, :cleanup_pending} = Transports.finish(handle, token)
    assert {:ok, %{request_tokens: 1} = pending} = Transports.status(owner)
    send(peer, :respond)
    assert %HTTP.Response{status: 200, stream: stream} = HTTP.Promise.await(promise, 1000)
    assert read_public_stream(stream) == "ok"
    assert :ok = HTTP.RequestCompletion.await(completion, 1000)
    assert :ok = Transports.finish(handle, token)
    assert :ok = Transports.finish(handle, token)

    assert {:ok, %{resources: 1, reserved_connections: 2, request_tokens: 0} = settled} =
             Transports.status(owner)

    assert settled.owned_serialized_payload_bytes < pending.owned_serialized_payload_bytes
    assert :ok = HTTP.RequestCompletion.await(completion, 0)
  end

  test "bound guardian death initiates public abort and keeps hold through helper join" do
    {source, peer} = completion_peer()
    {_instance, owner} = owner()
    {:ok, handle, _} = Transports.prepare(owner, source, self(), deadline())
    parent = self()

    guardian =
      spawn(fn ->
        {:ok, pins} = Gaoxy.HTTP.Resources.pin_many([handle], self(), :request, deadline())
        {:ok, client, token} = Transports.checkout(handle, pins, self(), deadline())
        promise = fetch_public(client, source.origin <> "/")
        completion = HTTP.Promise.completion(promise)
        :ok = Transports.bind_completion(handle, token, completion)
        send(parent, {:bound_checkout, token, completion})

        receive do
          :join -> :ok
        after
          2000 -> :ok
        end
      end)

    assert_receive {:bound_checkout, token, completion}, 1000
    assert_receive {:completion_request, ^peer}, 1000
    send(guardian, :join)
    assert :ok = HTTP.RequestCompletion.await(completion, 1000)

    eventually(fn ->
      match?({:ok, %{request_tokens: 0, helpers: 0}}, Transports.status(owner))
    end)

    refute Map.has_key?(:sys.get_state(owner).tokens, token)
    assert {:ok, %{resources: 1, reserved_connections: 2}} = Transports.status(owner)
  end

  test "public request completion alone cannot release a live abort helper hold" do
    {source, peer} = completion_peer()
    {_instance, owner} = owner()
    {:ok, handle, _} = Transports.prepare(owner, source, self(), deadline())
    {:ok, pins} = Gaoxy.HTTP.Resources.pin_many([handle], self(), :request, deadline())
    {:ok, client, token} = Transports.checkout(handle, pins, self(), deadline())
    promise = fetch_public(client, source.origin <> "/")
    completion = HTTP.Promise.completion(promise)
    assert :ok = Transports.bind_completion(handle, token, completion)
    assert_receive {:completion_request, ^peer}, 1000
    parent = self()

    helper =
      spawn(fn ->
        receive do
          :abort ->
            result = HTTP.RequestCompletion.abort_and_await(completion, 1000)
            send(owner, {:request_abort_result, token, self(), result})
            send(parent, {:request_helper_result, self(), result})

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

    :sys.replace_state(owner, fn state ->
      hold = %{state.tokens[token] | abort_helper: {helper, Process.monitor(helper)}}
      put_in(state.tokens[token], hold)
    end)

    send(helper, :abort)
    assert_receive {:request_helper_result, ^helper, :ok}, 1500
    assert :ok = HTTP.RequestCompletion.await(completion, 0)
    assert {:error, :aborted} = HTTP.Promise.await(promise, 1000)
    assert {:error, :cleanup_pending} = Transports.finish(handle, token)
    assert {:ok, %{request_tokens: 1, helpers: 1}} = Transports.status(owner)
    send(helper, :join)

    eventually(fn ->
      match?({:ok, %{request_tokens: 0, helpers: 0}}, Transports.status(owner))
    end)
  end

  defp fetch_public(client, url) do
    HTTP.fetch(
      url,
      Keyword.merge(client.fetch_options,
        transport_scope: client.transport_scope,
        timeout: 1000,
        connect_timeout: 500
      )
    )
  end

  defp completion_peer do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])

    {:ok, {_, port}} = :inet.sockname(listener)
    parent = self()

    peer =
      spawn(fn ->
        case :gen_tcp.accept(listener, 1000) do
          {:ok, socket} ->
            try do
              head = recv_public_head(socket, System.monotonic_time(:millisecond) + 1000)
              true = String.contains?(head, "\r\n\r\n")
              send(parent, {:completion_request, self()})

              receive do
                :respond ->
                  :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")

                :stop ->
                  :ok
              after
                1500 -> :ok
              end

              receive do
                :stop -> :ok
              after
                1500 -> :ok
              end
            after
              :gen_tcp.close(socket)
            end

          {:error, _} ->
            :ok
        end
      end)

    on_exit(fn ->
      monitor = Process.monitor(peer)
      send(peer, :stop)
      :gen_tcp.close(listener)

      receive do
        {:DOWN, ^monitor, :process, ^peer, _} -> :ok
      after
        3500 -> flunk("completion peer did not join")
      end
    end)

    {%{origin: "http://127.0.0.1:#{port}", connect_address: {127, 0, 0, 1}, trust: nil}, peer}
  end

  defp read_public_stream(stream, chunks \\ []) do
    send(stream, {:read_chunk, self(), :ack})

    receive do
      {:stream_chunk, ^stream, bytes, ack} ->
        send(stream, {:stream_chunk_ack, ack})
        read_public_stream(stream, [bytes | chunks])

      {:stream_end, ^stream} ->
        IO.iodata_to_binary(Enum.reverse(chunks))

      {:stream_error, ^stream, reason} ->
        flunk("public response failed: #{inspect(reason)}")
    after
      1000 -> flunk("public stream did not finish")
    end
  end

  defp recv_public_head(socket, deadline, acc \\ "") do
    cond do
      byte_size(acc) >= 65_536 ->
        raise "test request head exceeded its finite cap"

      String.contains?(acc, "\r\n\r\n") ->
        acc

      true ->
        remaining = max(deadline - System.monotonic_time(:millisecond), 0)
        if remaining == 0, do: raise("test request head deadline expired")
        {:ok, bytes} = :gen_tcp.recv(socket, 0, remaining)
        recv_public_head(socket, deadline, acc <> bytes)
    end
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
      actors =
        if Process.alive?(owner) do
          state = :sys.get_state(owner)
          creators = Enum.map(state.records, fn {_, record} -> record.custodian end)
          helpers = for {_, hold} <- state.tokens, {pid, _} <- [hold.abort_helper], do: pid
          Enum.uniq(creators ++ helpers)
        else
          []
        end

      monitors = Enum.map(actors, &{&1, Process.monitor(&1)})
      if Process.alive?(owner), do: GenServer.stop(owner, :normal, 1000)

      for {pid, monitor} <- monitors do
        receive do
          {:DOWN, ^monitor, :process, ^pid, _} -> :ok
        after
          6000 -> flunk("owned creator or request helper did not join after owner shutdown")
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
