defmodule Gaoxy.Proxy.ManagedH2FixedGenerationTest do
  use ExUnit.Case, async: false

  alias Gaoxy.HTTP.{Generation, Resources, Router}
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.HTTP, as: ProxyHTTP
  alias Gaoxy.Proxy.ManagedGenerationAccounting
  alias Gaoxy.Proxy.ManagedH2FixedFixture, as: F
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports

  @moduletag :capture_log
  @timeout 5_000

  for protocol <- [:h2c, :http2], boundary <- [:prepare, :public, :direct] do
    @protocol protocol
    @boundary boundary
    @tag :fixed_generation_red
    test "#{protocol} genuine prepared fixed route passes #{boundary} Generation boundary" do
      {peer, ready} = F.peer(@protocol, ["--manual"])
      f = environment(@protocol, :http1)
      add_listener(f)
      source = source(@protocol, ready)

      assert {:ok, transport, preparation} =
               Transports.prepare(f.owner, source, self(), Lifecycle.deadline(@timeout))

      creator = creator(f, transport)
      assert {:ok, current, _} = Generation.snapshot(f.store)
      routes = direct_routes(source, transport)

      case @boundary do
        :prepare ->
          assert {:ok, %Router{}} = Generation.prepare(f.store, routes)

        :public ->
          assert {:ok, router} = Router.compile(routes)
          assert {:ok, generation} = Generation.activate(f.store, current, router)
          assert generation == router.generation

        :direct ->
          assert {:ok, router} = Router.compile(routes)

          assert {:ok, generation} =
                   GenServer.call(
                     f.store,
                     {:activate, current, router, Lifecycle.deadline(@timeout)},
                     @timeout
                   )

          assert generation == router.generation
      end

      assert :ok = Resources.release(preparation)
      finish(f, [creator], [{peer, 0, 0}])
    end
  end

  defmodule CapturedFixed do
    @behaviour Gaoxy.HTTP.Endpoint
    def init({options, parent, label}) do
      with {:ok, config} <- Gaoxy.Proxy.HTTP.init(options), do: {:ok, {config, parent, label}}
    end

    def resources({config, _, _}), do: Gaoxy.Proxy.HTTP.resources(config)
    def generation_validate({config, _, _}), do: Gaoxy.Proxy.HTTP.generation_validate(config)

    def call(exchange, {config, parent, label}) do
      ref = make_ref()
      send(parent, {:fixed_generation_capture, self(), ref, label, exchange})

      receive do
        {:dispatch, ^ref} -> :ok
      after
        min(5_000, Gaoxy.Lifecycle.remaining(exchange.deadline)) ->
          raise "fixed Generation dispatch barrier expired"
      end

      result = Gaoxy.Proxy.HTTP.call(exchange, config)
      send(parent, {:fixed_generation_return, self(), ref, label, result})

      receive do
        {:return, ^ref} -> result
      after
        min(5_000, Gaoxy.Lifecycle.remaining(exchange.deadline)) ->
          raise "fixed Generation return barrier expired"
      end
    end
  end

  for protocol <- [:h2c, :http2], downstream <- [:http1, :http2] do
    @protocol protocol
    @downstream downstream
    test "#{downstream} to #{@protocol} checked old snapshot survives CAS and independent completion then source-pin release" do
      {old_peer, old_ready} = F.peer(@protocol, ["--manual"])
      {new_peer, new_ready} = F.peer(@protocol, ["--manual"])
      f = environment(@protocol, @downstream)
      old = candidate(f, source(@protocol, old_ready), :old)
      assert {:ok, initial, _} = Generation.snapshot(f.store)
      old = activate(f, old, initial)
      add_listener(f)
      observe_owner(f)
      {old_socket, old_baseline} = connect(f)
      :ok = F.send_request(f, old_socket, "GET", "/old%2Fpath?raw=%2F")
      captured = capture(f, old, :old, old_baseline)
      assert_no_open(f, old)

      replacement = candidate(f, source(@protocol, new_ready), :new)
      replacement = activate(f, replacement, old.generation)
      await_closed(f, old, captured)
      assert_no_open(f, old)
      dispatch(captured)
      old_request = request_at(f, old_peer, old, "/old%2Fpath?raw=%2F")
      old_bound = bound(f, old, captured)

      {new_socket, new_baseline} = connect(f)
      :ok = F.send_request(f, new_socket, "GET", "/new%2Fpath?")
      fresh = capture(f, replacement, :new, new_baseline)
      dispatch(fresh)
      new_request = request_at(f, new_peer, replacement, "/new%2Fpath?")
      new_bound = bound(f, replacement, fresh)

      refute {old_peer, old_ready["port"], old_request["connection"], old_request["stream"]} ==
               {new_peer, new_ready["port"], new_request["connection"], new_request["stream"]}

      complete_return(f, fresh, new_bound, new_peer, new_request, new_socket, <<255, "new", 0>>)
      return_endpoint(fresh)
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(old_bound.completion, 0)
      assert Process.alive?(old.creator)

      complete_return(
        f,
        captured,
        old_bound,
        old_peer,
        old_request,
        old_socket,
        <<0, "old", 255>>
      )

      old_state = :sys.get_state(f.owner)
      assert old_state.pins[captured.pin.ref].public === captured.pin
      assert old_state.records[old.transport.resource].admission == :closed
      assert Process.alive?(old.creator)
      old_creator = old.creator
      refute_receive {:DOWN, _, :process, ^old_creator, _}, 0
      assert_no_child_or_token(f, old)
      return_endpoint(captured)
      join_resource(f, old)
      assert %{"connection" => connection} = F.physical_termination(old_peer)
      assert connection == old_request["connection"]
      close_native(f, old_socket, captured)
      close_native(f, new_socket, fresh)
      assert_effect_counts(f, captured, old_bound)
      assert_effect_counts(f, fresh, new_bound)

      finish(f, [{replacement.creator, replacement.creator_monitor}], [
        {old_peer, 1, 1},
        {new_peer, 1, 1}
      ])

      assert %{"connection" => connection} = F.physical_termination(new_peer)
      assert connection == new_request["connection"]
    end
  end

  # SOURCE-ONLY PROPOSAL. Insert inside ManagedH2FixedGenerationTest after the
  # primary draft's CapturedFixed and tests. Depends on that draft's helpers.
  # This file has not been parsed, formatted, compiled, or executed.
  # Both protocols deliberately use native H1 here; the primary owns H1/H2 x2.

  defmodule FailureFixed do
    @behaviour Gaoxy.HTTP.Endpoint

    def init({options, parent, label, mutation}) do
      with {:ok, config} <- Gaoxy.Proxy.HTTP.init(options),
           do: {:ok, {config, parent, label, mutation}}
    end

    def resources({config, _, _, _}), do: Gaoxy.Proxy.HTTP.resources(config)

    def generation_validate({config, _, _, _}),
      do: Gaoxy.Proxy.HTTP.generation_validate(config)

    def call(exchange, {config, parent, label, mutation}) do
      ref = make_ref()
      # This is the actual Exchange immediately after checked Store capture.
      send(parent, {:fixed_generation_capture, self(), ref, label, exchange})

      receive do
        {:dispatch, ^ref} -> :ok
      after
        min(5_000, Gaoxy.Lifecycle.remaining(exchange.deadline)) ->
          raise "fixed Generation failure dispatch barrier expired"
      end

      changed =
        case mutation do
          :none ->
            exchange

          :forged_ref ->
            [pin] = exchange.resource_pins
            %{exchange | resource_pins: [%{pin | ref: make_ref()}]}

          :wrong_holder ->
            [pin] = exchange.resource_pins
            %{exchange | resource_pins: [%{pin | holder: parent}]}

          {:missing_selected, other_transport} ->
            [pin] = exchange.resource_pins
            %{exchange | resource_pins: [%{pin | handles: [other_transport]}]}

          {:instance, other_instance} ->
            %{exchange | instance: other_instance}
        end

      result = Gaoxy.Proxy.HTTP.call(changed, config)
      send(parent, {:fixed_generation_return, self(), ref, label, result})

      receive do
        {:return, ^ref} -> result
      after
        min(5_000, Gaoxy.Lifecycle.remaining(exchange.deadline)) ->
          raise "fixed Generation failure return barrier expired"
      end
    end
  end

  for protocol <- [:h2c, :http2] do
    @failure_protocol protocol

    test "#{protocol} stale CAS joins rejected real preparation and preserves active routing" do
      {peer, ready} = F.peer(@failure_protocol, ["--manual"])
      {rejected_peer, rejected_ready} = F.peer(@failure_protocol, ["--manual"])
      f = environment(@failure_protocol, :http1)
      assert {:ok, stale, _} = Generation.snapshot(f.store)
      active = activate(f, failure_candidate(f, source(@failure_protocol, ready), :active), stale)
      add_listener(f)
      observe_owner(f)
      rejected = failure_candidate(f, source(@failure_protocol, rejected_ready), :rejected)
      coordinator = rejected.coordinator
      monitor = rejected.monitor
      send(coordinator, {:activate, stale})

      assert_receive {:fixed_candidate_activation, ^coordinator, {:error, :stale_generation}},
                     @timeout

      assert_receive {:DOWN, ^monitor, :process, ^coordinator, :normal}, @timeout
      assert_active(f, active)
      join_resource(f, rejected)
      successful_failure_request(f, active, peer, "/after-stale?", "active")
      finish(f, [{active.creator, active.creator_monitor}], [{peer, 1, 1}, {rejected_peer, 0, 0}])
      F.physical_termination(peer)
    end

    for fate <- [:invalid_route, :abandon, :coordinator_death] do
      @failure_fate fate
      test "#{protocol} #{@failure_fate} releases only the genuinely prepared candidate" do
        {peer, ready} = F.peer(@failure_protocol, ["--manual"])
        {rejected_peer, rejected_ready} = F.peer(@failure_protocol, ["--manual"])
        f = environment(@failure_protocol, :http1)
        assert {:ok, expected, _} = Generation.snapshot(f.store)

        active =
          activate(f, failure_candidate(f, source(@failure_protocol, ready), :active), expected)

        add_listener(f)
        observe_owner(f)
        rejected = failure_candidate(f, source(@failure_protocol, rejected_ready), :rejected)
        assert configured_pins(f, rejected.transport) == [:preparation]
        coordinator = rejected.coordinator
        monitor = rejected.monitor

        case @failure_fate do
          :invalid_route ->
            send(coordinator, :invalid_route)

            assert_receive {:fixed_candidate_invalid, ^coordinator,
                            {:error, :invalid_route_path}},
                           @timeout

            assert_receive {:DOWN, ^monitor, :process, ^coordinator, :normal}, @timeout

          :abandon ->
            send(coordinator, :abort)
            assert_receive {:DOWN, ^monitor, :process, ^coordinator, :normal}, @timeout

          :coordinator_death ->
            Process.exit(coordinator, :kill)
            assert_receive {:DOWN, ^monitor, :process, ^coordinator, :killed}, @timeout
        end

        join_resource(f, rejected)
        assert_active(f, active)
        successful_failure_request(f, active, peer, "/after-candidate-failure", "active")

        finish(f, [{active.creator, active.creator_monitor}], [
          {peer, 1, 1},
          {rejected_peer, 0, 0}
        ])

        F.physical_termination(peer)
      end
    end

    test "#{protocol} Store death preserves captured right and refuses a fresh native request before effects" do
      {peer, ready} = F.peer(@failure_protocol, ["--manual"])
      f = environment(@failure_protocol, :http1)
      assert {:ok, expected, _} = Generation.snapshot(f.store)

      active =
        activate(
          f,
          failure_candidate(f, source(@failure_protocol, ready), :store_death),
          expected
        )

      add_listener(f)
      observe_owner(f)
      {socket, baseline} = connect(f)
      :ok = F.send_request(f, socket, "GET", "/before-store-death")
      captured = capture(f, active, :store_death, baseline)
      store_monitor = Process.monitor(f.store)
      assert :ok = GenServer.stop(f.store, :normal, @timeout)
      store = f.store
      assert_receive {:DOWN, ^store_monitor, :process, ^store, :normal}, @timeout
      assert {:error, :generation_unavailable} = Generation.snapshot(store)
      await_closed(f, active, captured)
      assert_no_open(f, active)
      before = :sys.get_state(f.owner)
      prior = collect_effects(f.owner, [])
      assert is_list(prior)

      {fresh, _} = connect(f)
      gate = captured.exchange.gate

      [fresh_native] =
        for {_, lease} <- :sys.get_state(gate).leases, lease.pid != captured.native, do: lease.pid

      fresh_monitor = Process.monitor(fresh_native)
      :ok = F.send_request(f, fresh, "GET", "/after-store-death")
      assert %{status: 500, body: ""} = F.response(f, fresh)

      assert_receive {:DOWN, ^fresh_monitor, :process, ^fresh_native, {:shutdown, :local_closed}},
                     @timeout

      assert :ok = :gen_tcp.close(fresh)
      after_fresh = :sys.get_state(f.owner)
      assert after_fresh.pins === before.pins and after_fresh.tokens === before.tokens
      effects = collect_effects(f.owner, [])

      refute Enum.any?(effects, fn {_, tag, _} ->
               tag in [:delegate_request_pin, :pin_many, :checkout, :bind_completion]
             end)

      assert_no_open(f, active)

      dispatch(captured)
      request = request_at(f, peer, active, "/before-store-death")
      held = bound(f, active, captured)
      complete_return(f, captured, held, peer, request, socket, "survives")
      return_endpoint(captured)
      join_resource(f, active)
      termination = F.physical_termination(peer)
      assert termination["connection"] == request["connection"]
      close_native(f, socket, captured)
      finish(f, [], [{peer, 1, 1}])
    end

    test "#{protocol} cancellation at the original Store-derived delegation revokes that operation before checkout" do
      {peer, ready} = F.peer(@failure_protocol, ["--manual"])
      f = environment(@failure_protocol, :http1)
      assert {:ok, expected, _} = Generation.snapshot(f.store)

      active =
        activate(f, failure_candidate(f, source(@failure_protocol, ready), :cancel), expected)

      add_listener(f)
      observe_owner(f)
      failure_observe_results(f.owner)
      {socket, baseline} = connect(f)
      :ok = F.send_request(f, socket, "GET", "/cancel-before-delegation")
      captured = capture(f, active, :cancel, baseline)
      assert_no_open(f, active)
      barrier = failure_delegation_barrier(f.owner)
      dispatch(captured)
      owner = f.owner
      native = captured.native
      source_pin = captured.pin

      assert_receive {:fixed_failure_delegation_held, ^owner, ^native, handle, ^source_pin,
                      session, operation, deadline},
                     @timeout

      assert handle === active.transport and is_reference(operation)
      assert deadline <= captured.exchange.deadline
      state = :sys.get_state(session)
      assert state.owner == native and state.awaiting_transport.handle === handle
      assert state.transport_pins == [] and state.transport_selection == nil
      assert state.original_request == nil and state.request == nil
      session_monitor = Process.monitor(session)
      Gaoxy.Proxy.HTTP.Session.cancel(session)
      assert_receive {:DOWN, ^session_monitor, :process, ^session, :normal}, @timeout
      send(owner, {:fixed_failure_continue, barrier})

      assert_receive {:fixed_failure_delegation_result, ^owner, ^native,
                      {:error, {:deadline_exceeded, :cleanup_pending}}},
                     @timeout

      failure_response_return(f, socket, captured, 502)
      # Synchronize with the original pump's cancellation, then inspect owner.
      assert_receive {:fixed_owner_cancel, ^owner, ^native, ^operation}, @timeout
      ledger = :sys.get_state(owner)
      assert ledger.pins[source_pin.ref].public === source_pin
      assert ledger.pins[source_pin.ref].delegations == %{}
      assert_no_open(f, active)
      effects = collect_effects(owner, [])

      assert Enum.count(effects, fn {caller, tag, message} ->
               caller == native and tag == :delegate_request_pin and elem(message, 6) == operation
             end) == 1

      refute Enum.any?(effects, fn {_, tag, _} -> tag in [:checkout, :bind_completion] end)
      refute Enum.any?(effects, fn {caller, tag, _} -> caller == native and tag == :pin_many end)
      failure_close_returned(f, socket, captured)
      finish(f, [{active.creator, active.creator_monitor}], [{peer, 0, 0}])
    end

    for mismatch <- [:protocol, :authority, :instance] do
      @failure_mismatch mismatch
      test "#{protocol} genuine prepared T4 #{@failure_mismatch} mismatch fails original binding before checkout" do
        {peer, ready} = F.peer(@failure_protocol, ["--manual"])
        f = environment(@failure_protocol, :http1)
        actual = source(@failure_protocol, ready)

        {overrides, mutation, foreign} =
          case @failure_mismatch do
            :authority ->
              {%{upstream: String.replace(actual.origin, "localhost", "other.invalid")}, :none,
               nil}

            :protocol ->
              other = if @failure_protocol == :h2c, do: :http2, else: :h2c
              scheme = if other == :http2, do: "https", else: "http"

              {%{upstream: scheme <> "://localhost:#{ready["port"]}", upstream_protocol: other},
               :none, nil}

            :instance ->
              assert {:ok, other} = Gaoxy.start_link()
              Process.unlink(other)
              monitor = Process.monitor(other)
              on_exit(fn -> if Process.alive?(other), do: Gaoxy.stop(other, @timeout) end)
              {%{}, {:instance, other}, {other, monitor}}
          end

        assert {:ok, expected, _} = Generation.snapshot(f.store)

        active =
          activate(f, failure_candidate(f, actual, :mismatch, overrides, mutation), expected)

        add_listener(f)
        observe_owner(f)
        failure_observe_results(f.owner)
        {socket, baseline} = connect(f)
        :ok = F.send_request(f, socket, "GET", "/mismatch")
        captured = capture(f, active, :mismatch, baseline)
        dispatch(captured)
        failure_response_return(f, socket, captured, 503)
        owner = f.owner
        native = captured.native

        assert_receive {:fixed_failure_delegation_result, ^owner, ^native,
                        {:error, :transport_endpoint_mismatch}},
                       @timeout

        assert_no_open(f, active)
        ledger = :sys.get_state(owner)
        assert ledger.pins[captured.pin.ref].public === captured.pin
        assert ledger.pins[captured.pin.ref].delegations == %{}
        effects = collect_effects(owner, [])

        assert Enum.count(effects, fn {caller, tag, _} ->
                 caller == native and tag == :delegate_request_pin
               end) == 1

        refute Enum.any?(effects, fn {_, tag, _} -> tag in [:checkout, :bind_completion] end)

        refute Enum.any?(effects, fn {caller, tag, _} -> caller == native and tag == :pin_many end)

        failure_close_returned(f, socket, captured)
        finish(f, [{active.creator, active.creator_monitor}], [{peer, 0, 0}])

        if foreign do
          {other, monitor} = foreign
          assert :ok = Gaoxy.stop(other, @timeout)
          assert_receive {:DOWN, ^monitor, :process, ^other, :normal}, @timeout
        end
      end
    end

    for corruption <- [:missing_selected, :forged_ref, :wrong_holder] do
      @failure_corruption corruption
      test "#{protocol} #{@failure_corruption} mutation of genuine Store T8 refuses without fallback acquisition" do
        {peer, ready} = F.peer(@failure_protocol, ["--manual"])
        f = environment(@failure_protocol, :http1)
        actual = source(@failure_protocol, ready)
        # The alternate handle itself is genuine and holder-correct prepared.
        # It is never activated and never injected as an authentic source pin.
        spare =
          if @failure_corruption == :missing_selected,
            do: failure_candidate(f, actual, :spare),
            else: nil

        mutation = if spare, do: {:missing_selected, spare.transport}, else: @failure_corruption
        assert {:ok, expected, _} = Generation.snapshot(f.store)
        active = activate(f, failure_candidate(f, actual, :corrupt, %{}, mutation), expected)
        add_listener(f)
        observe_owner(f)
        failure_observe_results(f.owner)
        {socket, baseline} = connect(f)
        :ok = F.send_request(f, socket, "GET", "/source-refusal")
        captured = capture(f, active, :corrupt, baseline)
        assert :sys.get_state(f.owner).pins[captured.pin.ref].public === captured.pin
        dispatch(captured)
        status = if @failure_corruption == :forged_ref, do: 502, else: 503
        failure_response_return(f, socket, captured, status)
        owner = f.owner
        native = captured.native

        if @failure_corruption == :forged_ref do
          assert_receive {:fixed_failure_delegation_result, ^owner, ^native,
                          {:error, :invalid_resource_pin}},
                         @timeout
        end

        ledger = :sys.get_state(owner)
        assert ledger.pins[captured.pin.ref].public === captured.pin
        assert ledger.pins[captured.pin.ref].delegations == %{}
        assert_no_open(f, active)
        effects = collect_effects(owner, [])
        expected_delegations = if @failure_corruption == :forged_ref, do: 1, else: 0

        assert Enum.count(effects, fn {_, tag, _} -> tag == :delegate_request_pin end) ==
                 expected_delegations

        refute Enum.any?(effects, fn {_, tag, _} -> tag in [:checkout, :bind_completion] end)

        refute Enum.any?(effects, fn {caller, tag, _} -> caller == native and tag == :pin_many end)

        failure_close_returned(f, socket, captured)

        if spare do
          send(spare.coordinator, :abort)
          coordinator = spare.coordinator
          monitor = spare.monitor
          assert_receive {:DOWN, ^monitor, :process, ^coordinator, :normal}, @timeout
          join_resource(f, spare)
        end

        finish(f, [{active.creator, active.creator_monitor}], [{peer, 0, 0}])
      end
    end
  end

  defp failure_candidate(f, actual, label, overrides \\ %{}, mutation \\ :none) do
    parent = self()

    {coordinator, monitor} =
      spawn_monitor(fn ->
        {:ok, transport, preparation} =
          Transports.prepare(f.owner, actual, self(), Lifecycle.deadline(15_000))

        try do
          options =
            Map.merge(
              %{
                upstream: actual.origin,
                upstream_protocol: actual.protocol,
                transport: transport
              },
              overrides
            )

          routes = [%{target: {FailureFixed, {options, parent, label, mutation}}}]
          {:ok, router} = Generation.prepare(f.store, routes)
          creator = :sys.get_state(f.owner).records[transport.resource].custodian
          send(parent, {:fixed_candidate, self(), transport, router, creator})

          receive do
            {:activate, expected} ->
              result = Generation.activate(f.store, expected, router)
              :ok = Resources.release(preparation)
              send(parent, {:fixed_candidate_activation, self(), result})

            :invalid_route ->
              [route] = routes
              result = Generation.prepare(f.store, [Map.put(route, :path, :invalid)])
              :ok = Resources.release(preparation)
              send(parent, {:fixed_candidate_invalid, self(), result})

            :abort ->
              :ok
          after
            5_000 -> raise "fixed failure candidate barrier expired"
          end
        after
          :ok = Resources.release(preparation)
        end
      end)

    on_exit(fn ->
      if Process.alive?(coordinator) do
        ref = Process.monitor(coordinator)
        send(coordinator, :abort)
        assert_receive {:DOWN, ^ref, :process, ^coordinator, :normal}, @timeout
      end
    end)

    assert_receive {:fixed_candidate, ^coordinator, transport, router, creator}, @timeout

    %{
      coordinator: coordinator,
      monitor: monitor,
      transport: transport,
      router: router,
      creator: creator,
      creator_monitor: Process.monitor(creator),
      source: actual,
      label: label
    }
  end

  defp assert_active(f, active) do
    generation = active.generation
    assert {:ok, ^generation, router} = Generation.snapshot(f.store)
    assert router === active.router
    assert configured_pins(f, active.transport) == [:baseline]
  end

  defp successful_failure_request(f, active, peer, path, body) do
    {socket, baseline} = connect(f)
    :ok = F.send_request(f, socket, "GET", path)
    captured = capture(f, active, active.label, baseline)
    dispatch(captured)
    seen = request_at(f, peer, active, path)
    held = bound(f, active, captured)
    complete_return(f, captured, held, peer, seen, socket, body)
    return_endpoint(captured)
    close_native(f, socket, captured)
  end

  defp failure_response_return(f, socket, captured, status) do
    assert %{status: ^status, body: ""} = F.response(f, socket)
    native = captured.native
    ref = captured.ref
    label = captured.label

    assert_receive {:fixed_generation_return, ^native, ^ref, ^label,
                    {:ok, %Gaoxy.HTTP.Exchange{close: true}}},
                   @timeout

    assert :sys.get_state(f.owner).pins[captured.pin.ref].public === captured.pin
  end

  defp failure_close_returned(_f, socket, captured) do
    return_endpoint(captured)
    native = captured.native
    monitor = captured.native_monitor
    assert_receive {:DOWN, ^monitor, :process, ^native, {:shutdown, :local_closed}}, @timeout
    assert :ok = :gen_tcp.close(socket)
  end

  defp failure_delegation_barrier(owner) do
    parent = self()
    barrier = make_ref()
    id = make_ref()

    debug = fn held, event, _ ->
      case event do
        {:in,
         {:"$gen_call", {native, _},
          {:delegate_request_pin, handle, source, session, _, _, operation, deadline}}}
        when not held ->
          send(
            parent,
            {:fixed_failure_delegation_held, self(), native, handle, source, session, operation,
             deadline}
          )

          receive do
            {:fixed_failure_continue, ^barrier} -> :ok
          after
            5_000 -> raise "fixed failure delegation barrier expired"
          end

          true

        _ ->
          held
      end
    end

    :ok = :sys.install(owner, {id, debug, false})
    on_exit(fn -> send(owner, {:fixed_failure_continue, barrier}) end)
    barrier
  end

  defp failure_observe_results(owner) do
    parent = self()

    debug = fn phase, event, _ ->
      case event do
        {:in, {:"$gen_call", {native, _}, {:delegate_request_pin, _, _, _, _, _, _, _}}} ->
          {:delegating, native}

        {:out, result, _, _} ->
          case phase do
            {:delegating, native} ->
              send(parent, {:fixed_failure_delegation_result, self(), native, result})

            _ ->
              :ok
          end

          nil

        _ ->
          phase
      end
    end

    :ok = :sys.install(owner, {make_ref(), debug, nil})
  end

  for protocol <- [:h2c, :http2] do
    @late_protocol protocol
    test "#{protocol} short stop failure survives genuine original completion and late physical cleanup" do
      {peer, ready} = F.peer(@late_protocol, ["--manual"])
      f = environment(@late_protocol, :http1)
      assert {:ok, expected, _} = Generation.snapshot(f.store)
      active = activate(f, failure_candidate(f, source(@late_protocol, ready), :late), expected)
      add_listener(f)
      observe_owner(f)
      {socket, baseline} = connect(f)
      :ok = F.send_request(f, socket, "GET", "/late-original-completion")
      captured = capture(f, active, :late, baseline)
      dispatch(captured)
      seen = request_at(f, peer, active, "/late-original-completion")
      held = bound(f, active, captured)
      owner = f.owner
      native = captured.native
      session = held.session
      native_monitor = captured.native_monitor
      completion = held.completion
      assert {:ok, address} = Gaoxy.info(f.instance, :http).local
      {:ok, service, _} = GenServer.call(f.instance, {:lookup, :http})
      service_monitor = Process.monitor(service)

      F.command(peer, seen, "respond", %{"fields" => [["content-length", "4"]], "ended" => false})
      assert F.h1_head(socket) =~ "200 OK"
      assert :erlang.suspend_process(native)
      on_exit(fn -> failure_safe_resume(native) end)

      try do
        F.command(peer, seen, "data", %{"body64" => Base.encode64("late"), "ended" => false})
        F.eventually(fn -> :sys.get_state(session).delivery != nil end)
        assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
        ledger = :sys.get_state(owner)
        assert ledger.tokens[held.token].completion === completion
        assert ledger.pins[held.child.ref].public === held.child
        assert ledger.pins[captured.pin.ref].public === captured.pin
        assert {:ok, %{request_tokens: 1, pins: 3, helpers: 0}} = Transports.status(owner)

        assert %{cleanup_pending: 1, retained_bytes: bytes, cleanup_failed: nil} =
                 Gaoxy.status(f.instance, :http)

        assert bytes > 0

        cancellation = failure_late_barrier(session, :session_cancel)
        retirement = failure_late_barrier(owner, :owner_retire)
        instance_done = failure_late_barrier(f.instance, :instance_done)
        failure = Gaoxy.stop(f.instance, 0)
        assert failure == {:error, {:deadline_exceeded, :cleanup_pending}}
        assert_receive {:fixed_failure_late_held, ^owner, :owner_retire, issued}, @timeout
        assert Lifecycle.remaining(issued) == 0
        assert_receive {:fixed_failure_late_held, ^session, :session_cancel, _}, @timeout
        assert_receive {:DOWN, ^native_monitor, :process, ^native, :killed}, @timeout
        instance = f.instance
        assert_receive {:fixed_failure_late_held, ^instance, :instance_done, ^failure}, @timeout
        assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)

        # The real original public barrier joins independently AFTER failed stop.
        # Session still holds the expired Service cancellation, so no zero-time
        # abort can convert an in-flight original cleanup into uncertainty.
        assert :ok = HTTP.RequestCompletion.abort_and_await(completion, @timeout)
        assert :ok = HTTP.RequestCompletion.await(completion, 0)
        assert Process.alive?(session)

        send(owner, {:fixed_failure_continue, retirement})
        assert {:ok, receipt} = Transports.retire(owner, Lifecycle.deadline(@timeout))
        assert Transports.await_retirement(receipt, Lifecycle.deadline(@timeout)) == failure
        # Only now release actual original-request cancellation and join it.
        send(session, {:fixed_failure_continue, cancellation})
        assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
        session_monitor = held.monitor
        assert_receive {:DOWN, ^session_monitor, :process, ^session, :normal}, @timeout
        termination = F.physical_termination(peer)
        assert termination["connection"] == seen["connection"]
        F.eventually(fn -> failure_owner_zero?(owner) end)
        assert :sys.get_state(owner).retirement.result == failure
        assert Transports.await_retirement(receipt, Lifecycle.deadline(@timeout)) == failure
        # Store still exists; terminal owner settlement must not rewrite receipt.
        assert :ok = GenServer.stop(f.store, :normal, @timeout)
        assert :sys.get_state(owner).retirement.result == failure
        assert :ok = HTTP.RequestCompletion.await(completion, 0)
        send(instance, {:fixed_failure_continue, instance_done})
        failure_finish_stopped(f, active, peer, address, service, service_monitor)
        assert failure == {:error, {:deadline_exceeded, :cleanup_pending}}
      after
        failure_safe_resume(native)
        :gen_tcp.close(socket)
      end
    end
  end

  defp failure_late_barrier(pid, family) do
    parent = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      value =
        case {family, event} do
          {:session_cancel, {:in, {:gaoxy_cleanup_cancel, _, _, _} = message}} -> {:hold, message}
          {:owner_retire, {:in, {:gaoxy_lifecycle_drain, _, _, _, deadline}}} -> {:hold, deadline}
          {:instance_done, {:in, {:operation_done, _, result}}} -> {:hold, result}
          _ -> :continue
        end

      case {held, value} do
        {false, {:hold, operand}} ->
          send(parent, {:fixed_failure_late_held, self(), family, operand})

          receive do
            {:fixed_failure_continue, ^barrier} -> :ok
          after
            5_000 -> raise "fixed failure late cleanup barrier expired"
          end

          true

        _ ->
          held
      end
    end

    :ok = :sys.install(pid, {make_ref(), debug, false})
    on_exit(fn -> send(pid, {:fixed_failure_continue, barrier}) end)
    barrier
  end

  defp failure_owner_zero?(owner) do
    match?(
      {:ok,
       %{
         resources: 0,
         pins: 0,
         request_tokens: 0,
         helpers: 0,
         reserved_connections: 0,
         owned_serialized_payload_bytes: 0
       }},
      Transports.status(owner)
    )
  end

  defp failure_safe_resume(pid) do
    if Process.alive?(pid), do: :erlang.resume_process(pid)
  catch
    :error, :badarg -> :ok
  end

  defp failure_finish_stopped(f, active, peer, {ip, port}, service, service_monitor) do
    for {pid, monitor} <- f.joins do
      assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, @timeout
    end

    creator = active.creator
    creator_monitor = active.creator_monitor
    assert_receive {:DOWN, ^creator_monitor, :process, ^creator, :normal}, @timeout
    assert_receive {:DOWN, ^service_monitor, :process, ^service, :normal}, @timeout
    send(f.embedding, {:stop, self()})
    embedding = f.embedding

    assert_receive {:fixed_generation_environment_stopped, ^embedding, {:error, :not_running}},
                   2 * @timeout

    embedding_monitor = f.embedding_monitor
    assert_receive {:DOWN, ^embedding_monitor, :process, ^embedding, :normal}, @timeout

    assert {:ok, rebound} =
             :gen_tcp.listen(port, [:binary, active: false, ip: ip, reuseaddr: true])

    assert :ok = :gen_tcp.close(rebound)
    peer_monitor = Process.monitor(peer)
    send(peer, {:command, %{"op" => "stop"}})

    assert %{"forced" => 0, "live" => 0, "failed" => false, "accepts" => 1, "requests" => 1} =
             F.event(peer, "joined")

    assert_receive {:fixed_h2_peer_exit, ^peer, 0}, @timeout
    assert_receive {:DOWN, ^peer_monitor, :process, ^peer, :normal}, @timeout
  end

  defp candidate(f, source, label) do
    parent = self()

    {coordinator, monitor} =
      spawn_monitor(fn ->
        {:ok, transport, preparation} =
          Transports.prepare(f.owner, source, self(), Lifecycle.deadline(15_000))

        try do
          options = %{
            upstream: source.origin,
            upstream_protocol: source.protocol,
            transport: transport
          }

          routes = [%{target: {CapturedFixed, {options, parent, label}}}]
          {:ok, router} = Generation.prepare(f.store, routes)
          creator = :sys.get_state(f.owner).records[transport.resource].custodian
          send(parent, {:fixed_candidate, self(), transport, router, creator})

          receive do
            {:activate, expected} ->
              result = Generation.activate(f.store, expected, router)
              :ok = Resources.release(preparation)
              send(parent, {:fixed_candidate_activation, self(), result})

            :abort ->
              :ok
          after
            5_000 -> raise "fixed candidate activation barrier expired"
          end
        after
          :ok = Resources.release(preparation)
        end
      end)

    on_exit(fn ->
      if Process.alive?(coordinator) do
        ref = Process.monitor(coordinator)
        send(coordinator, :abort)
        assert_receive {:DOWN, ^ref, :process, ^coordinator, :normal}, @timeout
      end
    end)

    assert_receive {:fixed_candidate, ^coordinator, transport, router, creator}, @timeout

    %{
      coordinator: coordinator,
      monitor: monitor,
      transport: transport,
      router: router,
      creator: creator,
      creator_monitor: Process.monitor(creator),
      source: source,
      label: label
    }
  end

  defp activate(f, candidate, expected) do
    coordinator = candidate.coordinator
    monitor = candidate.monitor
    send(coordinator, {:activate, expected})
    assert_receive {:fixed_candidate_activation, ^coordinator, {:ok, generation}}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^coordinator, :normal}, @timeout
    assert generation == candidate.router.generation
    assert {:ok, ^generation, router} = Generation.snapshot(f.store)
    assert router == candidate.router
    assert configured_pins(f, candidate.transport) == [:baseline]
    Map.put(candidate, :generation, generation)
  end

  defp configured_pins(f, handle) do
    for {_, hold} <- :sys.get_state(f.owner).pins,
        handle in hold.public.handles and hold.public.kind in [:baseline, :preparation],
        do: hold.public.kind
  end

  defp observe_owner(f) do
    parent = self()
    store = f.store
    id = make_ref()

    :ok =
      :sys.install(
        f.owner,
        {id,
         fn state, event, _ ->
           case event do
             {:in,
              {:"$gen_call", {^store, _}, {:pin_many, handles, holder, :request, operation, d}}} ->
               status = Gaoxy.status(f.instance, :http)

               send(
                 parent,
                 {:fixed_owner_capture_input, self(), handles, holder, operation, d, status}
               )

               receive do
                 {:fixed_owner_continue, ^operation} -> :ok
                 :fixed_owner_unblock -> :ok
               after
                 5_000 -> raise "fixed owner input barrier expired"
               end

             {:in, {:"$gen_call", {caller, _}, message}} when is_tuple(message) ->
               send(parent, {:fixed_owner_effect, self(), caller, elem(message, 0), message})

             {:in, {:cancel_pins, caller, operation}} ->
               send(parent, {:fixed_owner_cancel, self(), caller, operation})

             _ ->
               :ok
           end

           state
         end, nil}
      )

    on_exit(fn ->
      if Process.alive?(f.owner) do
        send(f.owner, :fixed_owner_unblock)
        :sys.remove(f.owner, id)
      end
    end)
  end

  defp connect(f) do
    before = Gaoxy.status(f.instance, :http)
    socket = F.connect(f)
    increment = if f.downstream == :http2, do: 2, else: 1
    F.eventually(fn -> Gaoxy.status(f.instance, :http).active == before.active + increment end)
    {socket, Gaoxy.status(f.instance, :http)}
  end

  defp capture(f, candidate, label, baseline) do
    owner = f.owner

    assert_receive {:fixed_owner_capture_input, ^owner, handles, native, operation, d, status},
                   @timeout

    assert handles === [candidate.transport]
    send(owner, {:fixed_owner_continue, operation})
    assert_receive {:fixed_generation_capture, ^native, ref, ^label, exchange}, @timeout

    on_exit(fn ->
      send(native, {:dispatch, ref})
      send(native, {:return, ref})
    end)

    assert [pin] = exchange.resource_pins
    assert map_size(pin) == 8
    assert pin.provider == Transports and pin.owner == owner
    assert pin.owner_epoch == candidate.transport.owner_epoch
    assert pin.operation == operation and pin.holder == native and pin.kind == :request
    assert pin.handles === handles
    assert is_reference(pin.ref) and pin.ref != operation
    hold = :sys.get_state(owner).pins[pin.ref]
    assert hold.public === pin and hold.acquirer == f.store
    assert Map.get(hold, :derived, false) == false
    assert d == exchange.deadline and Lifecycle.remaining(d) > 0
    retained = Gaoxy.HTTP.Exchange.retained_bytes(exchange) - exchange.route_bytes
    b = expected_b(retained)
    assert exchange.route_bytes == b

    assert {:ok, {:native_generation_capture_v1, 1_048_576, 65_536, 65_536, ^b}} =
             ManagedGenerationAccounting.reservation(
               1_048_576,
               {f.store, native, exchange.gate, exchange.lease, :request, d, retained}
             )

    assert status.retained_bytes == baseline.retained_bytes + retained + b
    assert Gaoxy.Admission.status(exchange.gate).retained_bytes == status.retained_bytes
    lease = :sys.get_state(exchange.gate).leases[exchange.lease]
    assert lease.pid == native and lease.bytes == retained + b

    assert :ok =
             ManagedGenerationAccounting.correlate(
               pin,
               {Transports, owner, operation, handles},
               native
             )

    actors =
      if f.downstream == :http2 do
        assert exchange.transport == Gaoxy.HTTP.HTTP2.Transport
        {connection, stream, token} = exchange.transport_state
        {_, state} = :sys.get_state(connection)
        assert state.streams[stream].worker == native
        assert state.streams[stream].token == token
        assert state.streams[stream].lease == exchange.lease
        assert state.streams[stream].startup == nil
        assert state.streams[stream].request == exchange.request
        assert exchange.protocol_bytes > 0

        [
          {connection, Process.monitor(connection), {:shutdown, :peer_closed}},
          {state.writer, Process.monitor(state.writer), :normal}
        ]
      else
        assert exchange.transport == nil and exchange.protocol_bytes == 0
        []
      end

    %{
      native: native,
      native_monitor: Process.monitor(native),
      ref: ref,
      label: label,
      exchange: exchange,
      pin: pin,
      actors: actors
    }
  end

  defp expected_b(retained), do: expected_b(retained, 0, 0)

  defp expected_b(retained, b, iteration) when iteration < 64 do
    next =
      6 * 1_048_576 + 4_957_373 +
        3 * (:erlang.external_size(retained) - 3) +
        5 * (:erlang.external_size(b) - 6) +
        4 * (:erlang.external_size(retained + b) - 6)

    if b == next, do: b, else: expected_b(retained, next, iteration + 1)
  end

  defp expected_b(_, _, _), do: flunk("fixed independent B did not converge")

  defp identity(f, c),
    do: %{origin: c.source.origin, upstream_protocol: c.source.protocol, instance: f.instance}

  defp await_closed(f, c, captured) do
    F.eventually(fn ->
      configured_pins(f, c.transport) == [] and
        Transports.validate_endpoint(c.transport, identity(f, c), Lifecycle.deadline(@timeout)) ==
          {:error, :resource_admission_closed}
    end)

    state = :sys.get_state(f.owner)
    assert state.records[c.transport.resource].admission == :closed
    assert state.pins[captured.pin.ref].public === captured.pin
    assert Process.alive?(c.creator)
  end

  defp dispatch(captured), do: send(captured.native, {:dispatch, captured.ref})
  defp return_endpoint(captured), do: send(captured.native, {:return, captured.ref})

  defp request_at(f, peer, candidate, target) do
    accepted = F.event(peer, "accept")

    if f.protocol == :http2 do
      assert %{"alpn" => "h2", "sni" => "localhost"} = tls = F.event(peer, "tls")
      assert tls["connection"] == accepted["connection"]
    end

    seen = F.event(peer, "request")
    assert seen["connection"] == accepted["connection"]
    assert seen["target"] == target

    assert Enum.find(seen["headers"], fn [name, _] -> name == ":authority" end) ==
             [":authority", URI.parse(candidate.source.origin).authority]

    seen
  end

  defp bound(f, candidate, captured) do
    F.eventually(fn ->
      Enum.any?(:sys.get_state(f.owner).tokens, fn {_, token} ->
        token.resource == candidate.transport.resource and
          match?(%HTTP.RequestCompletion{}, token.completion)
      end)
    end)

    [{token_ref, token}] =
      Enum.filter(
        :sys.get_state(f.owner).tokens,
        fn {_, token} -> token.resource == candidate.transport.resource end
      )

    session = token.guardian
    state = :sys.get_state(session)
    assert state.client == Gaoxy.Proxy.ManagedH2Client
    assert state.client.completion(state.original_request) === token.completion
    assert state.owner == captured.native
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(token.completion, 0)
    ledger = :sys.get_state(f.owner)
    assert ledger.pins[captured.pin.ref].public === captured.pin

    [child] =
      for {_, pin} <- ledger.pins,
          pin.public.holder == session and candidate.transport in pin.public.handles,
          do: pin

    assert child.derived == true and child.source_ref == captured.pin.ref
    assert child.acquirer == captured.native
    assert child.public.kind == :request and child.public.handles == [candidate.transport]
    refute child.public.ref == captured.pin.ref

    assert ledger.pins[captured.pin.ref].delegations[candidate.transport.resource] ==
             %{guardian: session, operation: child.public.operation, ref: child.public.ref}

    %{
      session: session,
      monitor: Process.monitor(session),
      completion: token.completion,
      token: token_ref,
      child: child.public
    }
  end

  defp assert_no_open(f, candidate) do
    state = :sys.get_state(f.owner)

    refute Enum.any?(state.tokens, fn {_, token} ->
             token.resource == candidate.transport.resource
           end)

    refute Enum.any?(state.pins, fn {_, hold} ->
             candidate.transport in hold.public.handles and Map.get(hold, :derived, false)
           end)
  end

  defp assert_no_child_or_token(f, candidate) do
    assert_no_open(f, candidate)
    assert {:ok, %{helpers: 0}} = Transports.status(f.owner)
  end

  defp complete_return(f, captured, bound, peer, request, socket, body) do
    F.command(peer, request, "respond", %{
      "body64" => Base.encode64(body),
      "fields" => [
        ["content-length", Integer.to_string(byte_size(body))],
        ["x-order", "first"],
        ["x-order", "second"]
      ]
    })

    assert %{status: 200, body: ^body, headers: headers} = F.response(f, socket)

    assert Enum.filter(headers, fn {name, _} -> name == "x-order" end) ==
             [{"x-order", "first"}, {"x-order", "second"}]

    assert :ok = HTTP.RequestCompletion.await(bound.completion, @timeout)
    session = bound.session
    monitor = bound.monitor
    assert_receive {:DOWN, ^monitor, :process, ^session, :normal}, @timeout
    native = captured.native
    ref = captured.ref
    label = captured.label
    assert_receive {:fixed_generation_return, ^native, ^ref, ^label, result}, @timeout
    assert {:ok, %Gaoxy.HTTP.Exchange{}} = result
    state = :sys.get_state(f.owner)
    refute Map.has_key?(state.tokens, bound.token)
    refute Map.has_key?(state.pins, bound.child.ref)
    assert state.pins[captured.pin.ref].public === captured.pin
    assert Process.alive?(native)
  end

  defp join_resource(f, c) do
    F.eventually(fn ->
      not Map.has_key?(:sys.get_state(f.owner).records, c.transport.resource)
    end)

    pid = c.creator
    monitor = c.creator_monitor
    assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, @timeout
  end

  defp close_native(f, socket, captured) do
    assert :ok = :gen_tcp.close(socket)
    native = captured.native
    ref = captured.native_monitor
    reason = if f.downstream == :http2, do: :normal, else: {:shutdown, :peer_closed}
    assert_receive {:DOWN, ^ref, :process, ^native, ^reason}, @timeout

    for {pid, monitor, expected} <- captured.actors do
      assert_receive {:DOWN, ^monitor, :process, ^pid, ^expected}, @timeout
    end
  end

  defp assert_effect_counts(f, captured, bound) do
    :sys.get_state(f.owner)
    native = captured.native
    session = bound.session
    effects = collect_effects(f.owner, Process.get({__MODULE__, :effects}, []))
    Process.put({__MODULE__, :effects}, effects)

    assert Enum.count(effects, fn {caller, tag, _} ->
             caller == native and tag == :delegate_request_pin
           end) == 1

    for tag <- [:checkout, :bind_completion, :finish] do
      assert Enum.count(effects, fn {caller, operation, _} ->
               caller == session and operation == tag
             end) == 1
    end

    refute Enum.any?(effects, fn {caller, tag, _} -> caller == native and tag == :pin_many end)
  end

  defp collect_effects(owner, acc) do
    receive do
      {:fixed_owner_effect, ^owner, caller, tag, message} ->
        collect_effects(owner, [{caller, tag, message} | acc])
    after
      0 -> acc
    end
  end

  for protocol <- [:h2c, :http2], initial <- [:routes, :router] do
    @protocol protocol
    @initial initial
    test "#{protocol} genuine prepared transport starts Generation with initial #{initial}" do
      {peer, ready} = F.peer(@protocol, ["--manual"])
      f = environment(@protocol, :http1)
      add_listener(f)
      source = source(@protocol, ready)

      assert {:ok, transport, preparation} =
               Transports.prepare(f.owner, source, self(), Lifecycle.deadline(@timeout))

      creator = creator(f, transport)
      routes = direct_routes(source, transport)

      options =
        if @initial == :routes do
          [routes: routes]
        else
          assert {:ok, router} = Router.compile(routes)
          [router: router]
        end

      assert {:ok, initial_store} = Generation.start_link(options)
      Process.unlink(initial_store)
      monitor = Process.monitor(initial_store)
      assert {:ok, generation, router} = Generation.snapshot(initial_store)
      assert generation == router.generation
      assert router.resources == [transport]
      assert [baseline] = :sys.get_state(initial_store).baseline
      assert baseline.kind == :baseline and baseline.handles == [transport]
      assert baseline.holder == initial_store
      assert :ok = Resources.release(preparation)
      assert :ok = GenServer.stop(initial_store, :normal, @timeout)
      assert_receive {:DOWN, ^monitor, :process, ^initial_store, :normal}, @timeout
      finish(f, [creator], [{peer, 0, 0}])
    end
  end

  for protocol <- [:h2c, :http2] do
    @protocol protocol
    test "#{protocol} shaped stale or nonexistent T4 fails genuine baseline acquisition without changing snapshot" do
      {peer, ready} = F.peer(@protocol, ["--manual"])
      f = environment(@protocol, :http1)
      add_listener(f)
      source = source(@protocol, ready)

      assert {:ok, transport, preparation} =
               Transports.prepare(f.owner, source, self(), Lifecycle.deadline(@timeout))

      creator = creator(f, transport)
      assert {:ok, current, original} = Generation.snapshot(f.store)
      before = Transports.status(f.owner)

      for invalid <- [%{transport | owner_epoch: make_ref()}, %{transport | resource: make_ref()}] do
        routes = direct_routes(source, invalid)
        assert {:ok, router} = Generation.prepare(f.store, routes)
        assert {:error, :invalid_resource} = Generation.activate(f.store, current, router)

        assert {:error, :invalid_resource} =
                 GenServer.call(
                   f.store,
                   {:activate, current, router, Lifecycle.deadline(@timeout)},
                   @timeout
                 )

        assert {:error, :invalid_resource} = Generation.start_link(routes: routes)
        assert {:error, :invalid_resource} = Generation.start_link(router: router)
        assert {:ok, ^current, ^original} = Generation.snapshot(f.store)
        assert Transports.status(f.owner) == before
      end

      assert :ok = Resources.release(preparation)
      finish(f, [creator], [{peer, 0, 0}])
    end
  end

  defp source(protocol, ready) do
    scheme = if protocol == :http2, do: "https", else: "http"

    %{
      protocol: protocol,
      origin: scheme <> "://localhost:#{ready["port"]}",
      connect_address: {127, 0, 0, 1},
      trust: if(protocol == :http2, do: F.certificates(ready["ca"]), else: nil)
    }
  end

  defp direct_routes(source, transport) do
    [
      %{
        target:
          {ProxyHTTP,
           %{upstream: source.origin, upstream_protocol: source.protocol, transport: transport}}
      }
    ]
  end

  defp environment(protocol, downstream) do
    parent = self()

    {embedding, embedding_monitor} =
      spawn_monitor(fn ->
        {:ok, instance} = Gaoxy.start_link()
        Process.unlink(instance)

        {:ok, owner} =
          Transports.start_link(
            instance: instance,
            limits: %{
              max_resources: 4,
              max_pins: 256,
              max_request_tokens: 64,
              max_owned_payload_bytes: 8_388_608
            }
          )

        Process.unlink(owner)
        {:ok, store} = Generation.start_link(routes: [])
        Process.unlink(store)
        send(parent, {:fixed_generation_environment, self(), instance, owner, store})

        receive do
          {:stop, reply} ->
            if Process.alive?(store), do: :ok = GenServer.stop(store, :normal, @timeout)
            result = Gaoxy.stop(instance, @timeout)
            send(reply, {:fixed_generation_environment_stopped, self(), result})
        after
          120_000 -> exit(:fixed_generation_environment_deadline)
        end
      end)

    assert_receive {:fixed_generation_environment, ^embedding, instance, owner, store}, @timeout
    joins = Enum.map([instance, owner, store], &{&1, Process.monitor(&1)})

    on_exit(fn ->
      if Process.alive?(embedding) do
        monitor = Process.monitor(embedding)
        send(embedding, {:stop, self()})
        assert_receive {:fixed_generation_environment_stopped, ^embedding, :ok}, 2 * @timeout
        assert_receive {:DOWN, ^monitor, :process, ^embedding, :normal}, @timeout
      end
    end)

    %{
      instance: instance,
      owner: owner,
      store: store,
      protocol: protocol,
      downstream: downstream,
      embedding: embedding,
      embedding_monitor: embedding_monitor,
      joins: joins
    }
  end

  defp add_listener(f) do
    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               id: :http,
               endpoint: {Generation, {f.store, accounting: ManagedGenerationAccounting}},
               protocols: [f.downstream],
               h2c: if(f.downstream == :http2, do: :prior_knowledge, else: :disabled),
               limits: %{max_bytes: 536_870_912},
               http_limits: %{request_timeout: 15_000}
             )

    assert {:ok, _} = Gaoxy.add(f.instance, spec)
  end

  defp creator(f, transport) do
    pid = :sys.get_state(f.owner).records[transport.resource].custodian
    {pid, Process.monitor(pid)}
  end

  defp finish(f, creators, peers) do
    F.eventually(fn ->
      match?(
        %{active: 0, retained_bytes: 0, cleanup_pending: 0, cleanup_failed: nil},
        Gaoxy.status(f.instance, :http)
      )
    end)

    assert {:ok, address} = Gaoxy.info(f.instance, :http).local
    store_monitor = Enum.find_value(f.joins, fn {pid, ref} -> if pid == f.store, do: ref end)
    if Process.alive?(f.store), do: assert(:ok == GenServer.stop(f.store, :normal, @timeout))
    assert_receive {:DOWN, ^store_monitor, :process, _, :normal}, @timeout

    F.eventually(fn ->
      match?(
        {:ok,
         %{
           resources: 0,
           pins: 0,
           request_tokens: 0,
           helpers: 0,
           reserved_connections: 0,
           owned_serialized_payload_bytes: 0
         }},
        Transports.status(f.owner)
      )
    end)

    for {pid, ref} <- creators do
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, @timeout
    end

    send(f.embedding, {:stop, self()})
    embedding = f.embedding
    assert_receive {:fixed_generation_environment_stopped, ^embedding, :ok}, 2 * @timeout

    for {pid, ref} <- f.joins, pid != f.store do
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, @timeout
    end

    monitor = f.embedding_monitor
    assert_receive {:DOWN, ^monitor, :process, ^embedding, :normal}, @timeout
    {ip, port} = address

    assert {:ok, rebound} =
             :gen_tcp.listen(port, [:binary, active: false, ip: ip, reuseaddr: true])

    assert :ok = :gen_tcp.close(rebound)

    for {peer, accepts, requests} <- peers do
      peer_monitor = Process.monitor(peer)
      send(peer, {:command, %{"op" => "stop"}})

      assert %{
               "forced" => 0,
               "live" => 0,
               "failed" => false,
               "accepts" => ^accepts,
               "requests" => ^requests
             } = F.event(peer, "joined")

      assert_receive {:fixed_h2_peer_exit, ^peer, 0}, @timeout
      assert_receive {:DOWN, ^peer_monitor, :process, ^peer, :normal}, @timeout
    end
  end
end
