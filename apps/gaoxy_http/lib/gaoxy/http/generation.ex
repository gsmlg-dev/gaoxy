defmodule Gaoxy.HTTP.Generation do
  @moduledoc """
  Stable-listener route generations. Prepare outside the store, then activate
  against an expected generation. Each request retains its immutable snapshot;
  the store keeps only the current router. Listener changes require restart.
  """
  @behaviour Gaoxy.HTTP.Endpoint
  alias Gaoxy.HTTP.{Exchange, Resources, Router}
  alias Gaoxy.{Admission, Lifecycle}

  def child_spec(options),
    do: %{id: __MODULE__, start: {__MODULE__, :start_link, [options]}}

  def start_link(options) do
    with {:ok, limits, initial, registration} <- options(options),
         {:ok, store} <- GenServer.start_link(Gaoxy.HTTP.Generation.Store, limits, registration) do
      result =
        with {:ok, router} <- initial_router(store, initial),
             {:ok, generation, _} <- snapshot(store),
             {:ok, _} <- activate(store, generation, router),
             do: {:ok, store}

      if match?({:error, _}, result), do: GenServer.stop(store)
      result
    end
  end

  defp initial_router(_store, {:router, %Router{} = router}), do: {:ok, router}
  defp initial_router(store, {:routes, routes}), do: prepare(store, routes)

  def snapshot_for_request(store, holder, deadline),
    do: request(store, {:snapshot_for_request, holder, deadline}, Lifecycle.remaining(deadline))

  def snapshot(store, timeout \\ 5_000), do: request(store, :snapshot, timeout)

  @doc false
  def declared_snapshot(store, timeout \\ 5_000),
    do: request(store, :declared_snapshot, timeout)

  def prepare(store, routes, timeout \\ 5_000)

  def prepare(store, routes, timeout)
      when is_integer(timeout) and timeout > 0 do
    deadline = Lifecycle.deadline(timeout)

    with {:ok, limits} <- request(store, :limits, Lifecycle.remaining(deadline)),
         :ok <- Gaoxy.HTTP.Generation.Store.input_bound(routes, limits),
         {:ok, token, worker} <-
           request(store, {:begin_prepare, deadline}, Lifecycle.remaining(deadline)) do
      send(worker, {:compile, token, routes})
      # Bounded receipt headroom confirms worker termination after its deadline.
      request(store, {:await_preparation, token}, Lifecycle.remaining(deadline) + 50)
    end
  end

  def prepare(_, _, _), do: {:error, :invalid_prepare_timeout}

  @doc "Prepare routes loaded by a bounded trusted local function in the existing preparation worker."
  def prepare_with(store, loader, timeout \\ 5_000)

  def prepare_with(store, loader, timeout)
      when is_function(loader, 0) and is_integer(timeout) and timeout > 0 do
    deadline = Lifecycle.deadline(timeout)

    with {:ok, limits} <- request(store, :limits, Lifecycle.remaining(deadline)),
         :ok <- Gaoxy.HTTP.Generation.Store.loader_bound(loader, limits),
         {:ok, token, worker} <-
           request(store, {:begin_prepare, deadline}, Lifecycle.remaining(deadline)) do
      send(worker, {:compile, token, {:loader, loader}})
      request(store, {:await_preparation, token}, Lifecycle.remaining(deadline) + 50)
    end
  end

  def prepare_with(_, loader, _) when not is_function(loader, 0),
    do: {:error, :invalid_generation_loader}

  def prepare_with(_, _, _), do: {:error, :invalid_prepare_timeout}

  def activate(store, expected, prepared, timeout \\ 5_000)

  def activate(store, expected, %Router{} = prepared, timeout)
      when is_integer(timeout) and timeout > 0 do
    activate_declared(store, expected, prepared, prepared, timeout)
  end

  def activate(_, _, %Router{}, _), do: {:error, :invalid_activation_timeout}
  def activate(_, _, _, _), do: {:error, :invalid_prepared_router}

  @doc false
  def activate_declared(store, expected, %Router{} = prepared, %Router{} = declaration, timeout)
      when is_integer(timeout) and timeout > 0 do
    deadline = Lifecycle.deadline(timeout)

    with {:ok, limits} <- request(store, :limits, Lifecycle.remaining(deadline)),
         :ok <- Gaoxy.HTTP.Generation.Store.compiled_bound(prepared, limits),
         :ok <- Gaoxy.HTTP.Generation.Store.compiled_bound(declaration, limits),
         do:
           request(
             store,
             {:activate, expected, prepared, declaration, deadline},
             Lifecycle.remaining(deadline)
           )
  end

  def activate_declared(_, _, %Router{}, %Router{}, _),
    do: {:error, :invalid_activation_timeout}

  def reload(store, routes, timeout \\ 5_000)

  def reload(store, routes, timeout) when is_integer(timeout) and timeout > 0 do
    deadline = Lifecycle.deadline(timeout)

    with {:ok, expected, _} <- snapshot(store, Lifecycle.remaining(deadline)),
         {:ok, prepared} <- prepare(store, routes, Lifecycle.remaining(deadline)),
         do: activate(store, expected, prepared, Lifecycle.remaining(deadline))
  end

  def reload(_, _, _), do: {:error, :invalid_reload_timeout}

  @impl Gaoxy.HTTP.Endpoint
  def init({store, [accounting: accounting]}) do
    with true <- checked_accounting?(accounting),
         true <- is_pid(store) or valid_name?(store),
         pid when is_pid(pid) <- GenServer.whereis(store),
         {:ok, limits} <- request(pid, :limits) do
      {:ok, %{store: pid, max_config_bytes: limits.max_config_bytes, accounting: accounting}}
    else
      _ -> {:error, :invalid_generation_store}
    end
  rescue
    ArgumentError -> {:error, :invalid_generation_store}
  end

  def init(store) do
    with true <- is_pid(store) or valid_name?(store),
         pid when is_pid(pid) <- GenServer.whereis(store),
         {:ok, limits} <- request(pid, :limits) do
      {:ok, %{store: pid, snapshot_bytes: 2 * limits.max_config_bytes}}
    else
      _ -> {:error, :invalid_generation_store}
    end
  rescue
    ArgumentError -> {:error, :invalid_generation_store}
  end

  @impl Gaoxy.HTTP.Endpoint
  def call(exchange, %{store: store, max_config_bytes: m, accounting: accounting}) do
    context =
      {store, self(), exchange.gate, exchange.lease, :request, exchange.deadline,
       Exchange.retained_bytes(exchange)}

    with {:ok, {:native_generation_capture_v1, ^m, 65_536, 65_536, b}} <-
           checked_reservation(accounting, m, context) do
      charged = %{exchange | route_bytes: exchange.route_bytes + b}

      with :ok <- checked_admission(charged, accounting),
           {:ok, _generation, router, pins} <-
             snapshot_for_request(store, self(), charged.deadline, accounting) do
        case checked_append(accounting, pins, charged.resource_pins) do
          :ok ->
            checked_router(charged, router, pins, store, accounting)

          {:error, reason} ->
            checked_cleanup(pins, charged, store, accounting, :acquisition)
            {:error, reason, charged}
        end
      else
        {:error, reason} ->
          {:error, reason, charged}

        {:error, reason, status} ->
          if status == :cleanup_unconfirmed,
            do: checked_observe(charged, store, :acquisition)

          {:error, reason, charged}
      end
    else
      {:error, reason} -> {:error, reason, exchange}
    end
  end

  def call(exchange, %{store: store, snapshot_bytes: bytes}) do
    exchange = Map.update!(exchange, :route_bytes, &(&1 + bytes))

    with :ok <-
           Admission.update(exchange.gate, exchange.lease, Exchange.retained_bytes(exchange)),
         {:ok, _generation, router, pins} <-
           snapshot_for_request(store, self(), exchange.deadline) do
      try do
        Router.call(%{exchange | resource_pins: pins ++ exchange.resource_pins}, router)
      after
        Resources.release(pins)
      end
    else
      {:error, reason} -> {:error, reason, exchange}
    end
  end

  @checked_min -9_223_372_036_854_775_808
  @checked_max 9_223_372_036_854_775_807
  @checked_reasons ~w(invalid_generation_capture generation_capture_capacity generation_unavailable
    generation_pin_release_failed cleanup_unconfirmed invalid_resource_holder byte_limit
    stale_generation deadline_exceeded cleanup_pending)a
  @accounting_callbacks [
    reservation: 2,
    validate_manifest: 1,
    correlate: 3,
    preflight_cons: 2,
    preflight_append: 2,
    finite_checked_reason: 1,
    release: 2
  ]

  def snapshot_for_request(store, holder, deadline, accounting) do
    remaining = if checked_deadline?(deadline), do: checked_remaining(deadline), else: 0

    cond do
      not checked_deadline?(deadline) ->
        {:error, :invalid_generation_capture, :clean}

      remaining == 0 ->
        {:error, :deadline_exceeded, :clean}

      true ->
        case GenServer.call(
               store,
               {:snapshot_for_request, holder, deadline, accounting},
               remaining
             ) do
          {:ok, _, %Router{}, pins} = result when is_list(pins) ->
            result

          {:error, reason, status} when status in [:clean, :cleanup_unconfirmed] ->
            {:error, checked_reason(accounting, reason), status}

          _ ->
            {:error, :generation_unavailable, :cleanup_unconfirmed}
        end
    end
  catch
    :exit, {:timeout, _} -> {:error, :deadline_exceeded, :cleanup_unconfirmed}
    _, _ -> {:error, :generation_unavailable, :cleanup_unconfirmed}
  end

  defp checked_accounting?(module) do
    is_atom(module) and Code.ensure_loaded?(module) and
      Enum.all?(@accounting_callbacks, fn {name, arity} ->
        function_exported?(module, name, arity)
      end)
  end

  defp checked_deadline?(deadline),
    do: is_integer(deadline) and deadline >= @checked_min and deadline <= @checked_max - 1_000

  defp checked_remaining(deadline) do
    now = Lifecycle.now()
    remaining = deadline - now

    if now >= @checked_min and now <= @checked_max and remaining in 1..@checked_max,
      do: remaining,
      else: 0
  end

  defp checked_reservation(accounting, m, context) do
    case accounting.reservation(m, context) do
      {:ok, {:native_generation_capture_v1, ^m, 65_536, 65_536, b}} = result
      when is_integer(b) and b >= 0 ->
        result

      {:error, reason} ->
        {:error, checked_reason(accounting, reason)}

      {:ok, _} ->
        {:error, :invalid_generation_capture}

      _ ->
        {:error, :generation_unavailable}
    end
  catch
    _, _ -> {:error, :generation_unavailable}
  end

  defp checked_admission(exchange, accounting) do
    remaining =
      if checked_deadline?(exchange.deadline), do: checked_remaining(exchange.deadline), else: 0

    if remaining > 0 do
      case Admission.update(
             exchange.gate,
             exchange.lease,
             Exchange.retained_bytes(exchange),
             min(5_000, remaining)
           ) do
        :ok -> :ok
        {:error, reason} -> {:error, checked_reason(accounting, reason)}
        _ -> {:error, :generation_unavailable}
      end
    else
      {:error, :deadline_exceeded}
    end
  catch
    :exit, {:timeout, _} -> {:error, :deadline_exceeded}
    _, _ -> {:error, :generation_unavailable}
  end

  defp checked_append(accounting, pins, existing) do
    case accounting.preflight_append(pins, existing) do
      {:ok, %{count: count, bytes: bytes} = summary}
      when map_size(summary) == 2 and count in 0..64 and bytes in 2..65_536 ->
        :ok

      {:error, reason} ->
        {:error, checked_reason(accounting, reason)}

      _ ->
        {:error, :generation_unavailable}
    end
  catch
    _, _ -> {:error, :generation_unavailable}
  end

  defp checked_router(exchange, router, pins, store, accounting) do
    captured = %{exchange | resource_pins: pins ++ exchange.resource_pins}

    result =
      try do
        Router.call(captured, router)
      catch
        kind, value ->
          stack = __STACKTRACE__
          checked_cleanup(pins, exchange, store, accounting, :release)
          :erlang.raise(kind, value, stack)
      end

    case checked_cleanup(pins, exchange, store, accounting, :release) do
      :ok ->
        result

      {:error, :generation_pin_release_failed} ->
        case result do
          {:ok, latest} -> {:error, :generation_pin_release_failed, latest}
          _ -> result
        end
    end
  end

  defp checked_cleanup(pins, exchange, store, accounting, stage) do
    case Resources.release_checked(pins, exchange.deadline + 1_000, accounting) do
      :ok ->
        :ok

      _ ->
        checked_observe(exchange, store, stage)
        {:error, :generation_pin_release_failed}
    end
  catch
    _, _ ->
      checked_observe(exchange, store, stage)
      {:error, :generation_pin_release_failed}
  end

  defp checked_observe(exchange, store, stage) do
    Gaoxy.Telemetry.emit(:generation_capture_cleanup, %{count: 1}, %{}, %{
      store: store,
      holder: self(),
      lease: exchange.lease,
      stage: stage,
      cleanup: :cleanup_unconfirmed
    })

    :ok
  catch
    _, _ -> :ok
  end

  defp checked_reason(accounting, raw) do
    case accounting.finite_checked_reason(raw) do
      reason when reason in @checked_reasons -> reason
      _ -> :generation_unavailable
    end
  catch
    _, _ -> :generation_unavailable
  end

  defp options(options) do
    if is_list(options) and Keyword.keyword?(options) and
         length(options) == map_size(Map.new(options)) and
         Keyword.keys(options) -- [:router, :routes, :name, :max_routes, :max_config_bytes] == [] and
         not (Keyword.has_key?(options, :router) and Keyword.has_key?(options, :routes)) and
         (not Keyword.has_key?(options, :name) or valid_name?(options[:name])) and
         (not Keyword.has_key?(options, :router) or match?(%Router{}, options[:router])) do
      limits = %{
        max_routes: Keyword.get(options, :max_routes, 1024),
        max_config_bytes: Keyword.get(options, :max_config_bytes, 1_048_576)
      }

      initial =
        if Keyword.has_key?(options, :router),
          do: {:router, options[:router]},
          else: {:routes, Keyword.get(options, :routes, [])}

      if Enum.all?(limits, fn {_, value} -> is_integer(value) and value > 0 end),
        do: {:ok, limits, initial, Keyword.take(options, [:name])},
        else: {:error, :invalid_generation_limits}
    else
      {:error, :invalid_generation_options}
    end
  end

  defp valid_name?(name) when is_atom(name), do: name != nil
  defp valid_name?({:global, _}), do: true

  defp valid_name?({:via, module, _}) when is_atom(module),
    do:
      Code.ensure_loaded?(module) and function_exported?(module, :whereis_name, 1) and
        function_exported?(module, :register_name, 2)

  defp valid_name?(_), do: false

  defp request(store, operation, timeout \\ 5_000)

  defp request(store, operation, timeout) when is_integer(timeout) and timeout > 0 do
    GenServer.call(store, operation, timeout)
  catch
    :exit, _ -> {:error, :generation_unavailable}
  end

  defp request(_, _, _), do: {:error, :generation_unavailable}
end

defmodule Gaoxy.HTTP.Generation.Store do
  @moduledoc false
  use GenServer
  alias Gaoxy.HTTP.{Resources, Router}
  alias Gaoxy.Lifecycle

  @impl true
  def init(limits) do
    Process.flag(:trap_exit, true)
    {:ok, router} = Router.compile([])

    {:ok,
     %{
       router: router,
       declaration: router,
       limits: limits,
       preparation: nil,
       baseline: [],
       retired: []
     }}
  end

  @impl true
  def handle_call(:snapshot, _, state),
    do: {:reply, {:ok, state.router.generation, state.router}, state}

  def handle_call(:declared_snapshot, _, state),
    do: {:reply, {:ok, state.router.generation, state.declaration}, state}

  def handle_call({:snapshot_for_request, holder, deadline}, {caller, _}, state) do
    with true <- holder == caller || {:error, :invalid_resource_holder},
         {:ok, pins} <- Resources.pin_many(state.router.resources, holder, :request, deadline) do
      {:reply, {:ok, state.router.generation, state.router, pins}, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:snapshot_for_request, holder, deadline, accounting}, {caller, _}, state) do
    if holder === caller do
      case Resources.pin_many_checked(state.router.resources, holder, deadline, accounting) do
        {:ok, pins} -> {:reply, {:ok, state.router.generation, state.router, pins}, state}
        {:error, _, _} = error -> {:reply, error, state}
      end
    else
      {:reply, {:error, :invalid_resource_holder, :clean}, state}
    end
  end

  def handle_call(:limits, _, state), do: {:reply, {:ok, state.limits}, state}

  def handle_call({:begin_prepare, _}, _, %{preparation: preparation} = state)
      when preparation != nil,
      do: {:reply, {:error, :preparation_busy}, state}

  def handle_call({:begin_prepare, deadline}, {caller, _}, state) do
    with true <- Lifecycle.remaining(deadline) > 0 || {:error, :prepare_timeout} do
      owner = self()
      token = make_ref()
      limits = state.limits

      {worker, monitor} =
        :erlang.spawn_opt(
          fn ->
            receive do
              {:compile, ^token, {:loader, loader}} ->
                send(owner, {:prepared, token, self(), load_and_compile(loader, limits)})

              {:compile, ^token, routes} ->
                result = with :ok <- input_bound(routes, limits), do: compile(routes, limits)
                send(owner, {:prepared, token, self(), result})
            after
              Lifecycle.remaining(deadline) ->
                send(owner, {:prepared, token, self(), {:error, :prepare_timeout}})
            end
          end,
          [:link, :monitor]
        )

      preparation = %{
        worker: worker,
        monitor: monitor,
        token: token,
        from: nil,
        result: nil,
        terminated: false,
        discard: false,
        caller_pid: caller,
        caller: Process.monitor(caller),
        deadline: deadline,
        timer:
          Process.send_after(self(), {:prepare_timeout, token}, Lifecycle.remaining(deadline))
      }

      {:reply, {:ok, token, worker}, %{state | preparation: preparation}}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call(
        {:await_preparation, token},
        {caller, _} = from,
        %{preparation: %{token: token, caller_pid: caller, from: nil} = preparation} = state
      ) do
    state = %{state | preparation: %{preparation | from: from}}
    {:noreply, if(preparation.terminated, do: deliver(state), else: state)}
  end

  def handle_call({:await_preparation, _}, _, state),
    do: {:reply, {:error, :prepare_timeout}, state}

  def handle_call({:activate, expected, router, deadline}, from, state),
    do: handle_call({:activate, expected, router, router, deadline}, from, state)

  def handle_call({:activate, expected, router, declaration, deadline}, _, state) do
    with true <- Lifecycle.remaining(deadline) > 0 || {:error, :activation_timeout},
         true <- expected == state.router.generation || {:error, :stale_generation},
         true <- state.retired == [] || {:error, :resource_release_pending},
         :ok <- compiled_bound(router, state.limits),
         :ok <- compiled_bound(declaration, state.limits),
         {:ok, baseline} <- Resources.pin_many(router.resources, self(), :baseline, deadline) do
      if Lifecycle.remaining(deadline) > 0 do
        old = state.baseline
        state = %{state | router: router, declaration: declaration, baseline: baseline}
        {:reply, {:ok, router.generation}, retire_pins(state, old)}
      else
        {:reply, {:error, :activation_timeout}, retire_pins(state, baseline)}
      end
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(
        {:prepared, token, worker, result},
        %{preparation: %{token: token, worker: worker} = preparation} = state
      ) do
    result =
      if Lifecycle.remaining(preparation.deadline) > 0,
        do: result,
        else: {:error, :prepare_timeout}

    {:noreply, finish(state, result)}
  end

  def handle_info(
        {:prepare_timeout, token},
        %{preparation: %{token: token, terminated: true}} = state
      ),
      do: {:noreply, release(state)}

  def handle_info({:prepare_timeout, token}, %{preparation: %{token: token}} = state),
    do: {:noreply, finish(state, {:error, :prepare_timeout})}

  def handle_info(
        {:DOWN, monitor, :process, _, _},
        %{preparation: %{caller: monitor}} = state
      ),
      do: {:noreply, finish(put_in(state.preparation.discard, true), {:error, :caller_down})}

  def handle_info(
        {:DOWN, monitor, :process, _, _},
        %{preparation: %{monitor: monitor} = preparation} = state
      ) do
    result = preparation.result || {:error, :endpoint_preparation_failed}
    state = %{state | preparation: %{preparation | result: result, terminated: true}}
    {:noreply, deliver(state)}
  end

  def handle_info(:reconcile_resources, %{retired: [pin | rest]} = state) do
    {retired, delay} =
      case Resources.release(pin) do
        :ok -> {rest, 0}
        _ -> {rest ++ [pin], 100}
      end

    if retired != [], do: Process.send_after(self(), :reconcile_resources, delay)
    {:noreply, %{state | retired: retired}}
  end

  def handle_info(_, state), do: {:noreply, state}

  @impl true
  def terminate(_, %{preparation: nil} = state) do
    Resources.release(state.baseline ++ state.retired)
    :ok
  end

  def terminate(_, %{preparation: preparation} = state) do
    Process.exit(preparation.worker, :kill)

    unless preparation.terminated do
      receive do
        {:DOWN, monitor, :process, _, _} when monitor == preparation.monitor -> :ok
      after
        1_000 -> :ok
      end
    end

    if preparation.from, do: GenServer.reply(preparation.from, {:error, :generation_unavailable})
    release(state)
    Resources.release(state.baseline ++ state.retired)
    :ok
  end

  defp retire_pins(state, pins) do
    if pins != [] and state.retired == [],
      do: Process.send_after(self(), :reconcile_resources, 0)

    %{state | retired: pins ++ state.retired}
  end

  defp finish(%{preparation: preparation} = state, result) do
    Process.exit(preparation.worker, :kill)
    state = %{state | preparation: %{preparation | result: result}}
    if preparation.terminated, do: deliver(state), else: state
  end

  defp deliver(%{preparation: %{discard: true}} = state), do: release(state)

  defp deliver(%{preparation: %{from: nil}} = state), do: state

  defp deliver(%{preparation: preparation} = state) do
    GenServer.reply(preparation.from, preparation.result)
    release(state)
  end

  defp release(%{preparation: preparation} = state) do
    Process.cancel_timer(preparation.timer)
    Process.demonitor(preparation.caller, [:flush])
    Process.unlink(preparation.worker)
    Process.demonitor(preparation.monitor, [:flush])
    %{state | preparation: nil}
  end

  defp compile(routes, limits) do
    with {:ok, router} <- Router.compile(routes),
         :ok <- compiled_bound(router, limits),
         do: {:ok, router}
  rescue
    _ -> {:error, :endpoint_preparation_failed}
  catch
    _, _ -> {:error, :endpoint_preparation_failed}
  end

  def loader_bound(loader, limits) when is_function(loader, 0) do
    if :erlang.external_size(loader) <= limits.max_config_bytes,
      do: :ok,
      else: {:error, :configuration_too_large}
  end

  def loader_bound(_, _), do: {:error, :invalid_generation_loader}

  defp load_and_compile(loader, limits) do
    with :ok <- loader_bound(loader, limits) do
      case loader.() do
        {:ok, routes} -> with :ok <- input_bound(routes, limits), do: compile(routes, limits)
        {:error, _} = error -> error
        _ -> {:error, :invalid_loader_result}
      end
    end
  rescue
    _ -> {:error, :endpoint_preparation_failed}
  catch
    _, _ -> {:error, :endpoint_preparation_failed}
  end

  def input_bound(routes, limits) when is_list(routes) do
    cond do
      length(routes) > limits.max_routes ->
        {:error, :route_limit}

      :erlang.external_size(routes) > limits.max_config_bytes ->
        {:error, :configuration_too_large}

      true ->
        :ok
    end
  end

  def input_bound(_, _), do: {:error, :invalid_routes}

  def compiled_bound(%Router{generation: generation, routes: routes} = router, limits)
      when is_reference(generation) and is_list(routes) do
    with :ok <- input_bound(routes, limits),
         {:ok, _} <- Resources.validate(router.resources),
         :ok <- generation_bound(routes),
         :ok <- Router.validate_resource_sidecar(router),
         true <-
           :erlang.external_size(router) <= limits.max_config_bytes ||
             {:error, :configuration_too_large},
         do: :ok
  end

  def compiled_bound(_, _), do: {:error, :invalid_prepared_router}

  defp generation_bound(routes) do
    Enum.reduce_while(routes, :ok, fn route, :ok ->
      case generation_endpoint(route) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp generation_endpoint(%{target: {module, config}}) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :generation_validate, 1) do
      case module.generation_validate(config) do
        :ok -> :ok
        {:error, reason} when is_atom(reason) -> {:error, reason}
        _ -> {:error, :invalid_generation_endpoint}
      end
    else
      :ok
    end
  rescue
    _ -> {:error, :invalid_generation_endpoint}
  catch
    _, _ -> {:error, :invalid_generation_endpoint}
  end

  defp generation_endpoint(_), do: {:error, :invalid_generation_endpoint}
end
