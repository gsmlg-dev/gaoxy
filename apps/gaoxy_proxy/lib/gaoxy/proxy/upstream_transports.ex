defmodule Gaoxy.Proxy.UpstreamTransports do
  @moduledoc """
  Instance-associated finite ownership of immutable managed H1/H2 resources.

  Preparation authenticates the caller as the preparer. Status counts compact
  Gaoxy policy and metadata/control-slot serialized payload; dependency opaque
  scopes and completions, process heaps, native allocations and socket memory
  are excluded. Pins count admitted per-handle holds, not grouped pin maps.
  Cancellation is ordered with acquisition by its caller and original deadline;
  only live pin groups retain operation metadata, with no cancellation history.
  Checkout returns the immutable prepared policy, opaque public scope and fixed
  raw/manual protocol-bound Fetch profile. Capture and bind the original Promise completion
  before publishing request success; a completion cannot replace transport
  retirement or an unresolved request/helper hold.
  Dedicated production endpoints are unaffected by this resource foundation.
  """
  use GenServer
  @behaviour Gaoxy.HTTP.Resources
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.{ManagedH1Preparation, ManagedH2Preparation}
  alias Gaoxy.Proxy.UpstreamTransports.{Custodian, Options}

  def child_spec(options),
    do: %{
      id: {__MODULE__, make_ref()},
      start: {__MODULE__, :start_link, [options]},
      restart: :temporary
    }

  def start_link(options) do
    with {:ok, instance, limits} <- start_options(options),
         true <- Process.alive?(instance) || {:error, :instance_unavailable} do
      GenServer.start_link(__MODULE__, {instance, limits})
    end
  end

  def prepare(owner, source, preparer, deadline) do
    Lifecycle.call(owner, {:prepare, source, preparer, deadline}, deadline)
  end

  def validate_endpoint(
        %{provider: __MODULE__, owner: owner, owner_epoch: epoch, resource: resource} = handle,
        identity,
        deadline
      )
      when map_size(handle) == 4 and is_pid(owner) and is_reference(epoch) and
             is_reference(resource) do
    with {:ok, authority, instance} <- endpoint_identity(identity),
         true <- valid_deadline?(deadline) || pending() do
      Lifecycle.call(
        owner,
        {:validate_endpoint, handle, authority, instance, deadline},
        deadline
      )
    end
  end

  def validate_endpoint(_, _, _), do: {:error, :invalid_resource}

  def delegate_request_pin(handle, source_pin, guardian, identity, operation, deadline) do
    with {:ok, owner, [_]} <- handle_batch([handle]),
         {:ok, pin_owner} <- delegation_pin_shape(source_pin),
         true <- owner == pin_owner || {:error, :invalid_resource},
         {:ok, authority, instance} <- endpoint_identity(identity),
         true <-
           (is_pid(guardian) and guardian != self() and is_reference(operation)) ||
             {:error, :invalid_resource_pin},
         true <- (valid_deadline?(deadline) and Process.alive?(guardian)) || pending() do
      result =
        Lifecycle.call(
          owner,
          {:delegate_request_pin, handle, source_pin, guardian, authority, instance, operation,
           deadline},
          deadline
        )

      case result do
        {:ok, pin} ->
          if valid_deadline?(deadline) and Process.alive?(guardian) do
            {:ok, pin}
          else
            cancel(owner, operation)
            pending()
          end

        {:error, {:deadline_exceeded, :cleanup_pending}} ->
          cancel(owner, operation)
          result

        error ->
          error
      end
    end
  end

  @fetch_options [
    http_version: :http1,
    tls_backend: :ssl,
    http1_reuse: true,
    redirect: :manual,
    request_mode: :proxy,
    decode_body: false,
    stream_response: true,
    telemetry: false
  ]

  @impl true
  def pin_many(handles, holder, kind, operation, deadline) do
    with {:ok, owner, handles} <- handle_batch(handles),
         true <-
           (is_pid(holder) and kind in [:baseline, :preparation, :request] and
              is_reference(operation)) ||
             {:error, :invalid_resource_pin},
         true <- valid_deadline?(deadline) || pending(),
         {:ok, pin} <-
           Lifecycle.call(
             owner,
             {:pin_many, handles, holder, kind, operation, deadline},
             deadline
           ) do
      if valid_deadline?(deadline) and Process.alive?(holder) do
        {:ok, pin}
      else
        cancel(owner, operation)
        pending()
      end
    end
  end

  @impl true
  def release(%{provider: __MODULE__, owner: owner} = pin) when is_pid(owner),
    do: Gaoxy.Proxy.ManagedPin.release(pin, Lifecycle.deadline(1000))

  def release(_), do: {:error, :invalid_resource_pin}

  def release(%{provider: __MODULE__, owner: owner} = pin, deadline)
      when is_pid(owner) and is_integer(deadline) do
    if Lifecycle.remaining(deadline) > 0,
      do: Gaoxy.Proxy.ManagedPin.release(pin, deadline),
      else: {:error, :deadline_exceeded}
  end

  def release(_, _), do: {:error, :invalid_resource_pin}

  @impl true
  def cancel(owner, operation) when is_pid(owner) and is_reference(operation) do
    send(owner, {:cancel_pins, self(), operation})
    :ok
  end

  def checkout(%{provider: __MODULE__, owner: owner} = handle, pins, guardian, deadline)
      when is_pid(owner) and is_integer(deadline),
      do: Lifecycle.call(owner, {:checkout, handle, pins, guardian, deadline}, deadline)

  def checkout(_, _, _, _), do: {:error, :invalid_resource}

  def bind_completion(%{provider: __MODULE__, owner: owner} = handle, token, completion)
      when is_pid(owner),
      do:
        Lifecycle.call(
          owner,
          {:bind_completion, handle, token, completion},
          Lifecycle.deadline(1000)
        )

  def bind_completion(_, _, _), do: {:error, :invalid_resource}

  def finish(%{provider: __MODULE__, owner: owner} = handle, token) when is_pid(owner),
    do: Lifecycle.call(owner, {:finish, handle, token}, Lifecycle.deadline(1000))

  def finish(_, _), do: {:error, :invalid_resource}

  def retire(owner, deadline) when is_pid(owner) and is_integer(deadline),
    do: Lifecycle.call(owner, {:retire_owner, deadline}, deadline)

  def retire(_, _), do: {:error, :invalid_retirement_receipt}

  def await_retirement(
        %{provider: __MODULE__, owner: owner, owner_epoch: epoch, operation: operation} = receipt,
        deadline
      )
      when map_size(receipt) == 4 and is_pid(owner) and is_reference(epoch) and
             is_reference(operation) and is_integer(deadline) do
    case Lifecycle.call(owner, {:retirement_status, receipt}, deadline) do
      {:error, :cleanup_pending} ->
        if Lifecycle.remaining(deadline) == 0 do
          pending()
        else
          receive do
          after
            min(5, Lifecycle.remaining(deadline)) -> await_retirement(receipt, deadline)
          end
        end

      {:error, :not_running} ->
        {:error, :cleanup_unconfirmed}

      {:error, {:operation_exit, _}} ->
        {:error, :cleanup_unconfirmed}

      result ->
        result
    end
  end

  def await_retirement(_, _), do: {:error, :invalid_retirement_receipt}

  def status(owner) when is_pid(owner),
    do: Lifecycle.call(owner, :status, Lifecycle.deadline(1000))

  def status(%{provider: __MODULE__, owner: owner} = handle) when is_pid(owner),
    do: Lifecycle.call(owner, {:status, handle}, Lifecycle.deadline(1000))

  def status(_), do: {:error, :invalid_resource}

  @impl true
  def init({instance, limits}) do
    case Gaoxy.register_lifecycle_participant(instance, 1000) do
      {:ok, registration} ->
        {:ok,
         %{
           instance: instance,
           instance_monitor: Process.monitor(instance),
           registration: registration,
           epoch: make_ref(),
           limits: limits,
           lifecycle: :running,
           records: %{},
           pins: %{},
           tokens: %{},
           request_timer: nil,
           retirement: nil,
           retirement_timer: nil,
           core_reply: nil,
           instance_down: false
         }}

      _ ->
        {:stop, :instance_unavailable}
    end
  end

  @impl true
  def handle_call(:status, _, state), do: {:reply, {:ok, aggregate(state)}, state}

  def handle_call({:retire_owner, deadline}, _, state) do
    state = begin_retirement(state, deadline) |> retirement_progress()
    {:reply, {:ok, state.retirement.receipt}, state}
  end

  def handle_call({:retirement_status, receipt}, _, state) do
    if state.retirement != nil and state.retirement.receipt == receipt do
      state = retirement_progress(state)
      {:reply, state.retirement.result || {:error, :cleanup_pending}, state}
    else
      {:reply, {:error, :invalid_retirement_receipt}, state}
    end
  end

  def handle_call({:status, handle}, _, state) do
    case record(state, handle) do
      {:ok, _} -> {:reply, {:ok, aggregate(state)}, state}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:validate_endpoint, handle, authority, instance, deadline}, _, state) do
    result =
      with true <- state.lifecycle == :running || {:error, :retiring},
           true <- valid_deadline?(deadline) || pending(),
           {:ok, entry} <- record(state, handle),
           true <-
             (entry.lifecycle == :active and not entry.transport_confirmed) ||
               {:error, :resource_unavailable},
           true <- entry.admission == :open || {:error, :resource_admission_closed},
           true <-
             (instance == state.instance and
                authority == policy_authority(entry.policy)) ||
               {:error, :transport_endpoint_mismatch} do
        :ok
      end

    {:reply, result, state}
  end

  def handle_call({:prepare, _, _, _}, _, %{lifecycle: lifecycle} = state)
      when lifecycle != :running,
      do: {:reply, {:error, :retiring}, state}

  def handle_call({:prepare, source, preparer, deadline}, {caller, _} = from, state) do
    with true <- caller == preparer || {:error, :unauthorized},
         true <- (valid_deadline?(deadline) and Process.alive?(caller)) || pending(),
         {:ok, policy, _} <- Options.prepare_policy(source),
         {:ok, entry, pin} <- reservation(state, policy, preparer, deadline),
         :ok <- capacity(state, entry, pin) do
      # Construct the reservation before creating the first actor. The ready
      # handshake cannot open until this state has entered the owner loop.
      state = %{
        state
        | records: Map.put(state.records, entry.resource, entry),
          pins: Map.put(state.pins, pin.public.ref, pin)
      }

      {:ok, custodian} =
        Custodian.start(
          owner: self(),
          resource: entry.resource,
          policy: policy,
          capability: entry.capability
        )

      entry = %{
        entry
        | custodian: custodian,
          custodian_monitor: Process.monitor(custodian),
          preparer_monitor: Process.monitor(preparer),
          from: from,
          timer:
            Process.send_after(
              self(),
              {:prepare_expired, entry.resource},
              Lifecycle.remaining(deadline)
            )
      }

      pin = %{pin | holder_monitor: entry.preparer_monitor}
      state = %{state | pins: Map.put(state.pins, pin.public.ref, pin)}

      {:noreply, put_entry(state, entry)}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call({:pin_many, handles, holder, kind, operation, deadline}, {caller, _}, state) do
    with true <- state.lifecycle == :running || {:error, :retiring},
         true <- (valid_deadline?(deadline) and Process.alive?(holder)) || pending(),
         :ok <- pinnable(state, handles),
         {:ok, pin, state} <-
           acquire_pins(state, handles, holder, kind, operation, caller, deadline) do
      {:reply, {:ok, pin}, state}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call(
        {:delegate_request_pin, handle, source_pin, guardian, authority, instance, operation,
         deadline},
        {caller, _},
        state
      ) do
    with true <-
           (state.lifecycle == :running and Process.alive?(state.instance)) || {:error, :retiring},
         :ok <- pin_identity(state, source_pin),
         {:ok, source} <- delegation_source(state, source_pin, caller),
         {:ok, entry} <- record(state, handle),
         true <- handle in source.public.handles || {:error, :invalid_resource_pin},
         true <-
           (entry.lifecycle == :active and not entry.transport_confirmed and
              not entry.retirement_requested) || {:error, :resource_unavailable},
         true <-
           (instance == state.instance and
              authority == policy_authority(entry.policy)) ||
             {:error, :transport_endpoint_mismatch},
         true <-
           (is_pid(guardian) and guardian != caller and is_reference(operation)) ||
             {:error, :invalid_resource_pin},
         true <-
           (valid_deadline?(deadline) and deadline <= source.admission_deadline and
              Process.alive?(caller) and Process.alive?(guardian)) || pending(),
         {:ok, child, state} <-
           derive_pin(state, handle, source, guardian, operation, caller, deadline) do
      {:reply, {:ok, child}, state}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call({:release, pin}, {caller, _}, state) do
    with :ok <- pin_identity(state, pin) do
      ref = pin.ref

      case state.pins do
        %{^ref => hold} ->
          if pin == hold.public and caller in [hold.public.holder, hold.acquirer] do
            {:reply, :ok, remove_pin(state, pin.ref)}
          else
            {:reply, {:error, :unauthorized}, state}
          end

        _ ->
          {:reply, :ok, state}
      end
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call({:checkout, handle, pins, guardian, deadline}, {caller, _}, state) do
    with true <- caller == guardian || {:error, :unauthorized},
         true <-
           (state.lifecycle == :running and Process.alive?(state.instance)) || {:error, :retiring},
         true <- valid_deadline?(deadline) || pending(),
         {:ok, entry} <- record(state, handle),
         true <-
           (entry.lifecycle == :active and not entry.transport_confirmed and
              not entry.retirement_requested) ||
             {:error, :resource_unavailable},
         :ok <- request_pin(state, handle, pins, guardian),
         {:ok, token, hold} <- token_hold(state, entry, guardian, deadline) do
      hold = %{hold | guardian_monitor: Process.monitor(guardian)}
      state = %{state | tokens: Map.put(state.tokens, token, hold)}

      client = %{
        policy: entry.policy,
        transport_scope: entry.scope,
        fetch_options: fetch_options(entry.policy)
      }

      {:reply, {:ok, client, token}, state}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call({:bind_completion, handle, token, completion}, {caller, _}, state) do
    with {:ok, hold} <- request_hold(state, handle, token, caller),
         true <- match?(%HTTP.RequestCompletion{}, completion) || {:error, :invalid_completion},
         true <- hold.completion == nil || {:error, :completion_already_bound} do
      hold = %{hold | completion: completion}
      state = %{state | tokens: Map.put(state.tokens, token, hold)}

      state =
        if state.retirement != nil and state.retirement.mode == :abort,
          do: abort_request(state, token, hold),
          else: state

      {:reply, :ok, state}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call({:finish, handle, token}, {caller, _}, state) do
    case request_hold(state, handle, token, caller) do
      {:ok, %{completion: nil} = hold} ->
        {:reply, {:error, :cleanup_unconfirmed}, retire_resource(state, hold.resource)}

      {:ok, %{abort_helper: helper}} when not is_nil(helper) ->
        {:reply, {:error, :cleanup_pending}, state}

      {:ok, hold} ->
        case await_request(hold.completion) do
          :ok -> {:reply, :ok, remove_token(state, token)}
          error -> {:reply, error, state}
        end

      {:error, :unknown_request_token} ->
        {:reply, :ok, state}

      {:error, :invalid_resource} when state.lifecycle != :running and is_reference(token) ->
        case handle_batch([handle]) do
          {:ok, owner, _} when owner == self() and handle.owner_epoch == state.epoch ->
            result =
              if Map.has_key?(state.tokens, token), do: {:error, :invalid_resource}, else: :ok

            {:reply, result, state}

          _ ->
            {:reply, {:error, :invalid_resource}, state}
        end

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_info(
        {:gaoxy_lifecycle_drain, registration, operation, coordinator, deadline},
        %{registration: registration} = state
      )
      when is_reference(operation) and is_pid(coordinator) and is_integer(deadline) do
    context = %{operation: operation, coordinator: coordinator, sent: false}

    if state.core_reply == nil or
         (state.core_reply.operation == operation and state.core_reply.coordinator == coordinator) or
         not Process.alive?(state.core_reply.coordinator) do
      state = %{state | core_reply: context}
      {:noreply, begin_retirement(state, deadline) |> retirement_progress()}
    else
      {:noreply, state}
    end
  end

  def handle_info(:check_owner_retirement, state) do
    state = retirement_progress(%{state | retirement_timer: nil})

    if state.instance_down and map_size(state.records) == 0 and map_size(state.tokens) == 0,
      do: {:stop, :normal, state},
      else: {:noreply, state}
  end

  def handle_info({:custodian_ready, resource, custodian, capability}, state) do
    case state.records do
      %{
        ^resource =>
          %{custodian: ^custodian, capability: ^capability, lifecycle: :opening} = entry
      } ->
        if state.lifecycle == :running and not entry.retirement_requested do
          send(custodian, {:open, entry.capability})
          {:noreply, state}
        else
          state = put_entry(state, %{entry | admission: :closed, retirement_requested: true})

          if state.retirement,
            do: send(custodian, {:retire, entry.capability, :abort, state.retirement.deadline}),
            else: send(custodian, {:retire, entry.capability})

          {:noreply, state}
        end

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:custodian_open_result, resource, custodian, capability, result}, state) do
    case state.records do
      %{
        ^resource =>
          %{custodian: ^custodian, capability: ^capability, lifecycle: :opening} = entry
      } ->
        case result do
          {:ok, scope} ->
            if valid_deadline?(entry.deadline) and Process.alive?(entry.preparer) and
                 state.lifecycle == :running and not entry.retirement_requested do
              GenServer.reply(
                entry.from,
                {:ok, handle(state, resource), [state.pins[entry.pin].public]}
              )

              cancel_timer(entry.timer)
              entry = %{entry | lifecycle: :active, scope: scope, from: nil, opening: false}
              {:noreply, put_entry(state, entry)}
            else
              state = abandon(state, entry)
              send(custodian, {:retire, capability})
              {:noreply, state}
            end

          {:error, reason} ->
            if entry.from, do: GenServer.reply(entry.from, {:error, reason})
            # A control error alone cannot establish absence of an allocation.
            entry = %{
              entry
              | lifecycle: :failed,
                from: nil,
                opening: false,
                admission: :closed,
                retirement_requested: true
            }

            {:noreply, put_entry(state, entry)}
        end

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:prepare_expired, resource}, state) do
    case state.records do
      %{^resource => %{lifecycle: :opening} = entry} -> {:noreply, abandon(state, entry)}
      _ -> {:noreply, state}
    end
  end

  def handle_info({:custodian_retiring, resource, pid, capability}, state),
    do: update_custodian(state, resource, pid, capability, :retiring)

  def handle_info({:custodian_failed, resource, pid, capability}, state),
    do: update_custodian(state, resource, pid, capability, :failed)

  def handle_info({:custodian_retired, resource, pid, capability}, state) do
    case state.records do
      %{^resource => %{custodian: ^pid, capability: ^capability} = entry} ->
        entry = %{entry | transport_confirmed: true, opening: false}
        {:noreply, settle_entry(put_entry(state, entry), entry) |> retirement_progress()}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:custodian_helper_started, resource, pid, capability, helper}, state)
      when is_pid(helper) do
    case state.records do
      %{^resource => %{custodian: ^pid, capability: ^capability} = entry} ->
        if map_size(entry.helpers) < 2 and not Map.has_key?(entry.helpers, helper) do
          hold = %{monitor: Process.monitor(helper), down: false, finished: false}
          entry = %{entry | helpers: Map.put(entry.helpers, helper, hold)}
          {:noreply, put_entry(state, entry)}
        else
          {:noreply, state}
        end

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:custodian_helper_finished, resource, pid, capability, helper}, state) do
    case state.records do
      %{^resource => %{custodian: ^pid, capability: ^capability, helpers: helpers} = entry} ->
        case helpers do
          %{^helper => hold} ->
            entry = update_helper(entry, helper, %{hold | finished: true})
            {:noreply, settle_entry(put_entry(state, entry), entry) |> retirement_progress()}

          _ ->
            {:noreply, state}
        end

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:cancel_pins, caller, operation}, state) do
    refs =
      for {ref, hold} <- state.pins,
          hold.acquirer == caller and hold.public.operation == operation,
          do: ref

    {:noreply, Enum.reduce(refs, state, &remove_pin(&2, &1))}
  end

  def handle_info({:request_abort_result, token, helper, result}, state) do
    case state.tokens do
      %{^token => %{abort_helper: {^helper, _}} = hold} ->
        {:noreply,
         join_request_helper(state, token, %{hold | abort_result: result})
         |> retirement_progress()}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(:check_requests, state) do
    state = %{state | request_timer: nil}

    state =
      Enum.reduce(state.tokens, state, fn {token, hold}, acc ->
        if hold.guardian_down and hold.completion != nil and hold.abort_helper == nil do
          if await_request(hold.completion) == :ok, do: remove_token(acc, token), else: acc
        else
          acc
        end
      end)

    {:noreply, request_poll(state)}
  end

  def handle_info({:DOWN, monitor, :process, _, _}, %{instance_monitor: monitor} = state) do
    deadline = if state.retirement, do: state.retirement.deadline, else: Lifecycle.deadline(5000)
    state = begin_retirement(%{state | instance_down: true}, deadline)

    for {_, entry} <- state.records,
        do: send(entry.custodian, {:retire, entry.capability, :abort, deadline})

    state =
      Enum.reduce(state.tokens, state, fn {token, hold}, acc ->
        abort_request(acc, token, hold)
      end)

    state = retirement_progress(state)
    {:noreply, state}
  end

  def handle_info({:DOWN, monitor, :process, _, _}, state) do
    state =
      Enum.reduce(state.records, state, fn {_, entry}, acc ->
        cond do
          entry.custodian_monitor == monitor ->
            if entry.from, do: GenServer.reply(entry.from, {:error, :cleanup_unconfirmed})
            lifecycle = if entry.transport_confirmed, do: :retired, else: :failed

            entry = %{
              entry
              | lifecycle: lifecycle,
                from: nil,
                custodian_down: true,
                admission: :closed,
                retirement_requested: true
            }

            settle_entry(put_entry(acc, entry), entry)

          entry.preparer_monitor == monitor ->
            if entry.lifecycle == :opening, do: abandon(acc, entry), else: acc

          true ->
            entry =
              Enum.reduce(entry.helpers, entry, fn {helper, hold}, record ->
                if hold.monitor == monitor,
                  do: update_helper(record, helper, %{hold | down: true}),
                  else: record
              end)

            settle_entry(put_entry(acc, entry), entry)
        end
      end)

    refs = for {ref, hold} <- state.pins, hold.holder_monitor == monitor, do: ref
    state = Enum.reduce(refs, state, &remove_pin(&2, &1))

    state =
      Enum.reduce(state.tokens, state, fn {token, hold}, acc ->
        cond do
          hold.guardian_monitor == monitor ->
            guardian_down(acc, token, hold)

          match?({_, ^monitor}, hold.abort_helper) ->
            join_request_helper(acc, token, %{hold | abort_down: true})

          true ->
            acc
        end
      end)

    {:noreply, retirement_progress(state)}
  end

  def handle_info(_, state), do: {:noreply, state}

  @impl true
  def terminate(_, state) do
    state = %{
      state
      | records:
          Map.new(state.records, fn {resource, entry} ->
            {resource, %{entry | admission: :closed, retirement_requested: true}}
          end)
    }

    for {_, entry} <- state.records, do: send(entry.custodian, {:retire, entry.capability})
    :ok
  end

  defp start_options(options) when is_list(options) do
    if Keyword.keyword?(options) and length(options) == 2 and
         Enum.sort(Keyword.keys(options)) == [:instance, :limits] do
      with instance when is_pid(instance) <- options[:instance],
           {:ok, limits} <- Options.normalize_limits(options[:limits]) do
        {:ok, instance, limits}
      else
        _ -> {:error, :invalid_options}
      end
    else
      {:error, :invalid_options}
    end
  end

  defp start_options(_), do: {:error, :invalid_options}

  defp reservation(state, policy, preparer, deadline) do
    resource = make_ref()
    capability = make_ref()
    pin_ref = make_ref()

    public_pin = %{
      provider: __MODULE__,
      owner: self(),
      owner_epoch: state.epoch,
      operation: make_ref(),
      ref: pin_ref,
      handles: [handle(state, resource)],
      kind: :preparation,
      holder: preparer
    }

    pin = %{public: public_pin, holder_monitor: make_ref(), acquirer: preparer}

    payload = %{
      policy: policy,
      owner: self(),
      owner_epoch: state.epoch,
      resource: resource,
      capability: capability,
      preparer: preparer,
      deadline: deadline,
      # The larger false encoding remains reserved when retirement flips true.
      retirement_requested: false,
      control_slots: %{
        initiation: %{
          operation: make_ref(),
          pid: self(),
          monitor: make_ref(),
          down: false,
          finished: false
        },
        abort: %{
          operation: make_ref(),
          pid: self(),
          monitor: make_ref(),
          down: false,
          finished: false
        }
      }
    }

    entry = %{
      resource: resource,
      capability: capability,
      policy: policy,
      payload: payload,
      payload_bytes: :erlang.external_size(payload),
      pin: pin_ref,
      lifecycle: :opening,
      opening: true,
      custodian: nil,
      custodian_monitor: nil,
      preparer: preparer,
      preparer_monitor: nil,
      deadline: deadline,
      from: nil,
      timer: nil,
      scope: nil,
      transport_confirmed: false,
      custodian_down: false,
      helpers: %{},
      admission: :open,
      retirement_requested: false
    }

    {:ok, entry, pin}
  end

  defp capacity(state, entry, pin) do
    status = aggregate(state)

    cond do
      status.resources >= state.limits.max_resources ->
        {:error, {:capacity, :resources}}

      status.pins >= state.limits.max_pins ->
        {:error, {:capacity, :pins}}

      status.owned_serialized_payload_bytes + entry.payload_bytes + :erlang.external_size(pin) >
          state.limits.max_owned_payload_bytes ->
        {:error, {:capacity, :owned_payload}}

      true ->
        :ok
    end
  end

  defp handle_batch(handles), do: handle_batch(handles, nil, [], 0)

  defp handle_batch([], owner, acc, count) when count > 0 do
    handles = Enum.uniq(Enum.reverse(acc))

    if :erlang.external_size(handles) <= 65_536,
      do: {:ok, owner, handles},
      else: {:error, :invalid_resource}
  end

  defp handle_batch(
         [
           %{provider: __MODULE__, owner: owner, owner_epoch: epoch, resource: resource} = handle
           | tail
         ],
         selected,
         acc,
         count
       )
       when map_size(handle) == 4 and is_pid(owner) and is_reference(epoch) and
              is_reference(resource) and count < 64 do
    if selected == nil or selected == owner,
      do: handle_batch(tail, owner, [handle | acc], count + 1),
      else: {:error, :invalid_resource}
  end

  defp handle_batch(_, _, _, _), do: {:error, :invalid_resource}

  defp pinnable(state, handles) do
    Enum.reduce_while(handles, :ok, fn handle, _ ->
      case record(state, handle) do
        {:ok,
         %{
           lifecycle: :active,
           admission: :open,
           transport_confirmed: false,
           retirement_requested: false
         }} ->
          {:cont, :ok}

        {:ok, _} ->
          {:halt, {:error, :resource_admission_closed}}

        error ->
          {:halt, error}
      end
    end)
  end

  defp acquire_pins(state, handles, holder, kind, operation, caller, deadline) do
    existing =
      Enum.find(state.pins, fn {_, hold} ->
        hold.public.operation == operation and hold.acquirer == caller
      end)

    case existing do
      {_, %{public: %{handles: ^handles, holder: ^holder, kind: ^kind} = pin}} ->
        {:ok, pin, state}

      {_, _} ->
        {:error, :invalid_resource_pin}

      nil ->
        pin = %{
          provider: __MODULE__,
          owner: self(),
          owner_epoch: state.epoch,
          operation: operation,
          ref: make_ref(),
          handles: handles,
          kind: kind,
          holder: holder
        }

        hold = %{public: pin, holder_monitor: make_ref(), acquirer: caller}

        hold =
          if kind == :request,
            do: Map.merge(hold, %{admission_deadline: deadline, delegations: %{}}),
            else: hold

        status = aggregate(state)

        cond do
          status.pins + length(handles) > state.limits.max_pins ->
            {:error, {:capacity, :pins}}

          status.owned_serialized_payload_bytes + :erlang.external_size(hold) >
              state.limits.max_owned_payload_bytes ->
            {:error, {:capacity, :owned_payload}}

          true ->
            hold = %{hold | holder_monitor: Process.monitor(holder)}
            {:ok, pin, %{state | pins: Map.put(state.pins, pin.ref, hold)}}
        end
    end
  end

  defp pin_identity(
         state,
         %{
           provider: __MODULE__,
           owner: owner,
           owner_epoch: epoch,
           operation: operation,
           ref: ref,
           handles: handles,
           kind: kind,
           holder: holder
         } = pin
       )
       when map_size(pin) == 8 and is_reference(operation) and is_reference(ref) and
              is_pid(holder) and
              kind in [:baseline, :preparation, :request] do
    with true <- owner == self() and epoch == state.epoch,
         {:ok, ^owner, _} <- handle_batch(handles) do
      :ok
    else
      _ -> {:error, :invalid_resource_pin}
    end
  end

  defp pin_identity(_, _), do: {:error, :invalid_resource_pin}

  defp delegation_pin_shape(
         %{
           provider: __MODULE__,
           owner: owner,
           owner_epoch: epoch,
           operation: operation,
           ref: ref,
           handles: handles,
           kind: kind,
           holder: holder
         } = pin
       )
       when map_size(pin) == 8 and is_pid(owner) and is_reference(epoch) and
              is_reference(operation) and is_reference(ref) and is_pid(holder) and
              kind in [:baseline, :preparation, :request] do
    with {:ok, ^owner, _} <- handle_batch(handles),
         true <- :erlang.external_size(pin) <= 65_536 do
      {:ok, owner}
    else
      _ -> {:error, :invalid_resource_pin}
    end
  end

  defp delegation_pin_shape(_), do: {:error, :invalid_resource_pin}

  defp delegation_source(state, pin, caller) do
    ref = pin.ref

    case state.pins do
      %{^ref => %{public: ^pin} = hold} ->
        cond do
          caller != hold.public.holder ->
            {:error, :unauthorized}

          pin.kind != :request or Map.get(hold, :derived, false) ->
            {:error, :invalid_resource_pin}

          true ->
            {:ok, hold}
        end

      _ ->
        {:error, :invalid_resource_pin}
    end
  end

  defp derive_pin(state, handle, source, guardian, operation, caller, deadline) do
    resource = handle.resource

    case source.delegations do
      %{^resource => %{guardian: ^guardian, operation: ^operation, ref: ref}} ->
        case state.pins do
          %{^ref => %{public: pin}} -> {:ok, pin, state}
          _ -> {:error, :invalid_resource_pin}
        end

      %{^resource => _} ->
        {:error, :invalid_resource_pin}

      _ ->
        if Enum.any?(state.pins, fn {_, hold} ->
             hold.acquirer == caller and hold.public.operation == operation
           end) do
          {:error, :invalid_resource_pin}
        else
          reserve_derived_pin(state, handle, source, guardian, operation, caller, deadline)
        end
    end
  end

  defp reserve_derived_pin(state, handle, source, guardian, operation, caller, deadline) do
    public = %{
      provider: __MODULE__,
      owner: self(),
      owner_epoch: state.epoch,
      operation: operation,
      ref: make_ref(),
      handles: [handle],
      kind: :request,
      holder: guardian
    }

    child = %{
      public: public,
      holder_monitor: make_ref(),
      acquirer: caller,
      admission_deadline: deadline,
      derived: true,
      source_ref: source.public.ref
    }

    marker = %{guardian: guardian, operation: operation, ref: public.ref}
    updated_source = put_in(source.delegations[handle.resource], marker)

    delta =
      :erlang.external_size(updated_source) - :erlang.external_size(source) +
        :erlang.external_size(child)

    status = aggregate(state)

    cond do
      status.pins + 1 > state.limits.max_pins ->
        {:error, {:capacity, :pins}}

      status.owned_serialized_payload_bytes + delta > state.limits.max_owned_payload_bytes ->
        {:error, {:capacity, :owned_payload}}

      true ->
        child = %{child | holder_monitor: Process.monitor(guardian)}

        pins =
          state.pins |> Map.put(source.public.ref, updated_source) |> Map.put(public.ref, child)

        {:ok, public, %{state | pins: pins}}
    end
  end

  defp remove_pin(state, ref) do
    case Map.pop(state.pins, ref) do
      {nil, _} ->
        state

      {hold, pins} ->
        Process.demonitor(hold.holder_monitor, [:flush])
        state = %{state | pins: pins}

        Enum.reduce(hold.public.handles, state, fn handle, acc ->
          close_unpinned(acc, handle.resource)
        end)
    end
  end

  defp close_unpinned(state, resource) do
    case state.records do
      %{^resource => %{lifecycle: :active} = entry} ->
        configured =
          Enum.any?(state.pins, fn {_, hold} ->
            hold.public.kind in [:baseline, :preparation] and
              Enum.any?(hold.public.handles, &(&1.resource == resource))
          end)

        if configured do
          state
        else
          state = put_entry(state, %{entry | admission: :closed})

          held =
            Enum.any?(state.pins, fn {_, hold} ->
              Enum.any?(hold.public.handles, &(&1.resource == resource))
            end) or
              Enum.any?(state.tokens, fn {_, hold} -> hold.resource == resource end)

          if held, do: state, else: retire_resource(state, resource)
        end

      %{^resource => entry} ->
        settle_entry(state, entry)

      _ ->
        state
    end
  end

  defp retire_resource(state, resource) do
    case state.records do
      %{^resource => %{transport_confirmed: false} = entry} ->
        state = put_entry(state, %{entry | admission: :closed, retirement_requested: true})
        send(entry.custodian, {:retire, entry.capability})
        state

      _ ->
        state
    end
  end

  defp request_pin(state, handle, pins, guardian) do
    with :ok <- request_pin(state, handle, pins, guardian, 0, false) do
      if :erlang.external_size(pins) <= 65_536, do: :ok, else: {:error, :invalid_resource_pin}
    end
  end

  defp request_pin(_, _, [], _, count, true) when count <= 64, do: :ok

  defp request_pin(state, handle, [pin | rest], guardian, count, found) when count < 64 do
    with :ok <- pin_identity(state, pin),
         %{public: ^pin} <- state.pins[pin.ref],
         true <- pin.kind == :request and pin.holder == guardian do
      request_pin(state, handle, rest, guardian, count + 1, found or handle in pin.handles)
    else
      _ -> {:error, :invalid_resource_pin}
    end
  end

  defp request_pin(_, _, _, _, _, _), do: {:error, :invalid_resource_pin}

  defp token_hold(state, entry, guardian, deadline) do
    token = make_ref()

    payload = %{
      resource: entry.resource,
      guardian: guardian,
      token: token,
      deadline: deadline,
      control_slot: %{
        operation: make_ref(),
        pid: self(),
        monitor: make_ref(),
        down: false,
        finished: false
      }
    }

    bytes = :erlang.external_size(payload)
    per_resource = Enum.count(state.tokens, fn {_, hold} -> hold.resource == entry.resource end)

    cond do
      map_size(state.tokens) >= state.limits.max_request_tokens or per_resource >= 32 ->
        {:error, {:capacity, :request_tokens}}

      aggregate(state).owned_serialized_payload_bytes + bytes >
          state.limits.max_owned_payload_bytes ->
        {:error, {:capacity, :owned_payload}}

      true ->
        {:ok, token,
         %{
           resource: entry.resource,
           guardian: guardian,
           guardian_monitor: nil,
           payload: payload,
           payload_bytes: bytes,
           completion: nil,
           guardian_down: false,
           abort_helper: nil,
           abort_result: nil,
           abort_down: false,
           cleanup_deadline: nil
         }}
    end
  end

  defp request_hold(state, handle, token, caller) do
    with true <- is_reference(token) || {:error, :invalid_request_token},
         {:ok, _} <- record(state, handle) do
      case state.tokens do
        %{^token => %{resource: resource, guardian: guardian} = hold} ->
          cond do
            resource != handle.resource -> {:error, :invalid_resource}
            caller != guardian -> {:error, :unauthorized}
            true -> {:ok, hold}
          end

        _ ->
          {:error, :unknown_request_token}
      end
    end
  end

  defp remove_token(state, token) do
    case Map.pop(state.tokens, token) do
      {nil, _} ->
        state

      {hold, tokens} ->
        Process.demonitor(hold.guardian_monitor, [:flush])
        state = %{state | tokens: tokens}
        resource = hold.resource

        case state.records do
          %{^resource => entry} -> close_unpinned(settle_entry(state, entry), resource)
          _ -> state
        end
    end
  end

  defp await_request(completion) do
    case HTTP.RequestCompletion.await(completion, 0) do
      :ok -> :ok
      {:error, :cleanup_pending} = error -> error
      _ -> {:error, :cleanup_unconfirmed}
    end
  rescue
    _ -> {:error, :cleanup_unconfirmed}
  catch
    _, _ -> {:error, :cleanup_unconfirmed}
  end

  defp guardian_down(state, token, %{completion: nil} = hold) do
    state = %{state | tokens: Map.put(state.tokens, token, %{hold | guardian_down: true})}
    retire_resource(state, hold.resource)
  end

  defp guardian_down(state, token, %{abort_helper: helper} = hold) when not is_nil(helper),
    do: %{state | tokens: Map.put(state.tokens, token, %{hold | guardian_down: true})}

  defp guardian_down(state, token, hold) do
    abort_request(state, token, %{hold | guardian_down: true})
  end

  defp abort_request(state, token, %{abort_helper: helper} = hold) when not is_nil(helper),
    do: %{state | tokens: Map.put(state.tokens, token, hold)}

  defp abort_request(state, _token, %{completion: nil} = hold),
    do: retire_resource(state, hold.resource)

  defp abort_request(state, token, hold) do
    owner = self()
    completion = hold.completion
    deadline = Lifecycle.deadline(5000)

    {helper, monitor} =
      spawn_monitor(fn ->
        result =
          Lifecycle.protect(fn ->
            HTTP.RequestCompletion.abort_and_await(completion, Lifecycle.remaining(deadline))
          end)

        send(owner, {:request_abort_result, token, self(), result})
      end)

    hold = %{
      hold
      | abort_helper: {helper, monitor},
        cleanup_deadline: deadline
    }

    %{state | tokens: Map.put(state.tokens, token, hold)}
  end

  defp join_request_helper(state, token, %{abort_down: true, abort_result: result} = hold)
       when not is_nil(result) do
    {_, monitor} = hold.abort_helper
    Process.demonitor(monitor, [:flush])
    hold = %{hold | abort_helper: nil, abort_result: nil, abort_down: false}
    state = %{state | tokens: Map.put(state.tokens, token, hold)}

    if result == :ok and await_request(hold.completion) == :ok,
      do: remove_token(state, token),
      else: request_poll(state)
  end

  defp join_request_helper(state, token, hold),
    do: %{state | tokens: Map.put(state.tokens, token, hold)}

  defp request_poll(%{request_timer: timer} = state) when not is_nil(timer), do: state

  defp request_poll(state) do
    waiting =
      Enum.any?(state.tokens, fn {_, hold} ->
        hold.guardian_down and hold.completion != nil and hold.abort_helper == nil and
          is_integer(hold.cleanup_deadline) and Lifecycle.remaining(hold.cleanup_deadline) > 0
      end)

    if waiting,
      do: %{state | request_timer: Process.send_after(self(), :check_requests, 10)},
      else: state
  end

  defp aggregate(state) do
    %{
      lifecycle: state.lifecycle,
      limits: state.limits,
      resources: map_size(state.records),
      reserved_connections:
        2 * Enum.count(state.records, fn {_, entry} -> not entry.transport_confirmed end),
      pins:
        Enum.reduce(state.pins, 0, fn {_, hold}, sum -> sum + length(hold.public.handles) end),
      request_tokens: map_size(state.tokens),
      failed_resources:
        Enum.count(state.records, fn {_, entry} -> entry.lifecycle == :failed end),
      helpers:
        Enum.reduce(state.records, 0, fn {_, entry}, sum ->
          sum + map_size(entry.helpers) + if(entry.opening, do: 1, else: 0)
        end) + Enum.count(state.tokens, fn {_, hold} -> hold.abort_helper != nil end),
      owned_serialized_payload_bytes:
        Enum.reduce(state.records, 0, fn {_, entry}, acc -> acc + entry.payload_bytes end) +
          Enum.reduce(state.pins, 0, fn {_, pin}, acc -> acc + :erlang.external_size(pin) end) +
          Enum.reduce(state.tokens, 0, fn {_, hold}, acc -> acc + hold.payload_bytes end)
    }
  end

  defp record(
         state,
         %{provider: __MODULE__, owner: owner, owner_epoch: epoch, resource: resource} = handle
       )
       when map_size(handle) == 4 and is_pid(owner) and is_reference(epoch) and
              is_reference(resource) do
    if owner == self() and epoch == state.epoch and Map.has_key?(state.records, resource),
      do: {:ok, state.records[resource]},
      else: {:error, :invalid_resource}
  end

  defp record(_, _), do: {:error, :invalid_resource}

  defp endpoint_identity(
         %{origin: origin, upstream_protocol: protocol, instance: instance} = identity
       )
       when map_size(identity) == 3 and is_binary(origin) and
              byte_size(origin) in 1..65_536 and is_pid(instance) and
              protocol in [:http1, :http2, :h2c] do
    with true <- :binary.referenced_byte_size(origin) <= 65_536 and endpoint_url_text?(origin),
         %URI{
           scheme: scheme,
           authority: authority,
           host: host,
           port: port,
           userinfo: nil,
           fragment: nil,
           query: nil,
           path: path
         } <- URI.parse(origin),
         true <-
           scheme in ["http", "https"] and is_binary(host) and byte_size(host) in 1..253 and
             is_integer(port) and port in 1..65_535 and path in [nil, "", "/"],
         true <- protocol_scheme?(protocol, scheme),
         true <- endpoint_authority?(authority, host, port) do
      scheme = if scheme == "http", do: :http, else: :https
      {:ok, {protocol, scheme, String.downcase(host), port}, instance}
    else
      _ -> {:error, :invalid_transport_endpoint}
    end
  rescue
    ArgumentError -> {:error, :invalid_transport_endpoint}
  end

  defp endpoint_identity(_), do: {:error, :invalid_transport_endpoint}

  defp protocol_scheme?(:http1, scheme), do: scheme in ["http", "https"]
  defp protocol_scheme?(:http2, scheme), do: scheme == "https"
  defp protocol_scheme?(:h2c, scheme), do: scheme == "http"

  defp policy_authority(%ManagedH1Preparation.Policy{} = policy),
    do: {:http1, policy.scheme, policy.host, policy.port}

  defp policy_authority(%ManagedH2Preparation.Policy{} = policy),
    do: {policy.protocol, policy.scheme, policy.host, policy.port}

  defp fetch_options(%ManagedH1Preparation.Policy{}), do: @fetch_options

  defp fetch_options(%ManagedH2Preparation.Policy{protocol: protocol}) do
    [
      http_version: protocol,
      tls_backend: :ssl,
      http2_profile: :native_v1,
      http2_reuse: true,
      redirect: :manual,
      request_mode: :proxy,
      decode_body: false,
      stream_response: true,
      telemetry: false
    ]
  end

  defp endpoint_authority?(authority, host, port) when is_binary(authority) do
    host = if String.contains?(host, ":"), do: "[" <> host <> "]", else: host
    prefix = host <> ":"

    cond do
      authority == host ->
        true

      String.starts_with?(authority, prefix) ->
        suffix =
          binary_part(authority, byte_size(prefix), byte_size(authority) - byte_size(prefix))

        String.trim_leading(suffix, "0") == Integer.to_string(port)

      true ->
        false
    end
  end

  defp endpoint_authority?(_, _, _), do: false

  defp endpoint_url_text?(<<>>), do: true

  defp endpoint_url_text?(<<?%, a, b, rest::binary>>),
    do: endpoint_hex?(a) and endpoint_hex?(b) and endpoint_url_text?(rest)

  defp endpoint_url_text?(<<?%, _::binary>>), do: false

  defp endpoint_url_text?(<<char, rest::binary>>) when char in 33..126 and char not in [?#, ?\\],
    do: endpoint_url_text?(rest)

  defp endpoint_url_text?(_), do: false
  defp endpoint_hex?(char), do: char in ?0..?9 or char in ?a..?f or char in ?A..?F

  defp handle(state, resource),
    do: %{provider: __MODULE__, owner: self(), owner_epoch: state.epoch, resource: resource}

  defp abandon(state, entry) do
    if entry.from, do: GenServer.reply(entry.from, pending())
    cancel_timer(entry.timer)
    entry = %{entry | from: nil, admission: :closed, retirement_requested: true}
    put_entry(state, entry)
  end

  defp put_entry(state, entry),
    do: %{state | records: Map.put(state.records, entry.resource, entry)}

  defp update_custodian(state, resource, pid, capability, lifecycle) do
    case state.records do
      %{^resource => %{custodian: ^pid, capability: ^capability, lifecycle: :failed}}
      when lifecycle == :retiring ->
        # Retry initiation cannot erase an unconfirmed failure. The separate
        # custodian_retired handler still accepts real retirement confirmation.
        {:noreply, state}

      %{^resource => %{custodian: ^pid, capability: ^capability} = entry} ->
        {:noreply,
         put_entry(state, %{
           entry
           | lifecycle: lifecycle,
             opening: false,
             admission: :closed,
             retirement_requested: true
         })}

      _ ->
        {:noreply, state}
    end
  end

  defp cleanup_monitors(entry) do
    Process.demonitor(entry.custodian_monitor, [:flush])
    Process.demonitor(entry.preparer_monitor, [:flush])
    cancel_timer(entry.timer)
  end

  defp update_helper(entry, helper, %{down: true, finished: true} = hold) do
    Process.demonitor(hold.monitor, [:flush])
    %{entry | helpers: Map.delete(entry.helpers, helper)}
  end

  defp update_helper(entry, helper, hold),
    do: %{entry | helpers: Map.put(entry.helpers, helper, hold)}

  defp settle_entry(
         state,
         %{transport_confirmed: true, custodian_down: true, opening: false, helpers: helpers} =
           entry
       )
       when map_size(helpers) == 0 do
    # A grouped capability remains intact until release or holder DOWN. Settling
    # one member cannot discard its other members' admission and payload holds.
    if Enum.any?(state.tokens, fn {_, hold} -> hold.resource == entry.resource end) or
         Enum.any?(state.pins, fn {_, hold} ->
           length(hold.public.handles) > 1 and
             Enum.any?(hold.public.handles, &(&1.resource == entry.resource))
         end) do
      state
    else
      cleanup_monitors(entry)

      refs =
        for {ref, hold} <- state.pins,
            Enum.any?(hold.public.handles, &(&1.resource == entry.resource)),
            do: ref

      pins = Map.drop(state.pins, refs)
      for ref <- refs, do: Process.demonitor(state.pins[ref].holder_monitor, [:flush])
      %{state | records: Map.delete(state.records, entry.resource), pins: pins}
    end
  end

  defp settle_entry(state, _), do: state

  defp begin_retirement(%{retirement: nil} = state, deadline) do
    receipt = %{
      provider: __MODULE__,
      owner: self(),
      owner_epoch: state.epoch,
      operation: make_ref()
    }

    for {_, hold} <- state.pins, do: Process.demonitor(hold.holder_monitor, [:flush])

    state = %{
      state
      | pins: %{},
        lifecycle: :retiring,
        retirement: %{
          receipt: receipt,
          deadline: deadline,
          result: nil,
          mode: :graceful,
          cleanup_deadline: deadline + 5000
        }
    }

    Enum.reduce(state.records, state, fn {_, entry}, acc ->
      entry = %{entry | admission: :closed, retirement_requested: true}
      acc = if entry.from, do: abandon(acc, entry), else: put_entry(acc, entry)
      send(entry.custodian, {:retire, entry.capability, :graceful, deadline})
      acc
    end)
  end

  defp begin_retirement(state, deadline) do
    retirement = state.retirement
    deadline = min(deadline, retirement.deadline)

    if deadline < retirement.deadline do
      for {_, entry} <- state.records,
          do: send(entry.custodian, {:retire, entry.capability, retirement.mode, deadline})
    end

    %{
      state
      | retirement: %{
          retirement
          | deadline: deadline,
            cleanup_deadline: min(retirement.cleanup_deadline, deadline + 5000)
        }
    }
  end

  defp retirement_progress(%{retirement: nil} = state), do: state

  defp retirement_progress(state) do
    state =
      Enum.reduce(state.tokens, state, fn {token, hold}, acc ->
        if hold.completion != nil and hold.abort_helper == nil and
             await_request(hold.completion) == :ok,
           do: remove_token(acc, token),
           else: acc
      end)

    operation = state.retirement

    result =
      cond do
        operation.result != nil ->
          operation.result

        Lifecycle.remaining(operation.deadline) == 0 ->
          pending()

        Enum.any?(state.tokens, fn {_, hold} -> hold.completion == nil end) ->
          {:error, :cleanup_unconfirmed}

        Enum.any?(state.records, fn {_, entry} -> entry.lifecycle == :failed end) ->
          {:error, :cleanup_unconfirmed}

        map_size(state.records) == 0 and map_size(state.tokens) == 0 ->
          :ok

        true ->
          nil
      end

    state = %{state | retirement: %{operation | result: result}}

    state =
      if Lifecycle.remaining(operation.deadline) == 0 and operation.mode != :abort do
        for {_, entry} <- state.records,
            do: send(entry.custodian, {:retire, entry.capability, :abort, operation.deadline})

        state = %{state | retirement: %{state.retirement | mode: :abort}}

        Enum.reduce(state.tokens, state, fn {token, hold}, acc ->
          abort_request(acc, token, hold)
        end)
      else
        state
      end

    state =
      if result != nil and state.core_reply != nil and not state.core_reply.sent do
        context = state.core_reply

        send(
          context.coordinator,
          {:gaoxy_lifecycle_result, state.registration, context.operation, self(), result}
        )

        %{state | core_reply: %{context | sent: true}}
      else
        state
      end

    complete = map_size(state.records) == 0 and map_size(state.tokens) == 0
    state = if complete, do: %{state | lifecycle: :retired}, else: state

    if state.retirement_timer == nil and
         ((state.instance_down and complete) or
            (not complete and
               Lifecycle.remaining(state.retirement.cleanup_deadline) > 0)) do
      %{state | retirement_timer: Process.send_after(self(), :check_owner_retirement, 10)}
    else
      state
    end
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(timer), do: Process.cancel_timer(timer)
  defp valid_deadline?(deadline), do: is_integer(deadline) and Lifecycle.remaining(deadline) > 0
  defp pending, do: {:error, {:deadline_exceeded, :cleanup_pending}}
end
