defmodule Gaoxy.Proxy.UpstreamTransports do
  @moduledoc """
  Instance-associated finite ownership of immutable managed H1 resources.

  Preparation authenticates the caller as the preparer. Status counts compact
  Gaoxy policy and metadata/control-slot serialized payload; dependency opaque
  scopes and completions, process heaps, native allocations and socket memory
  are excluded. Pins count admitted per-handle holds, not grouped pin maps.
  Cancellation is ordered with acquisition by its caller and original deadline;
  only live pin groups retain operation metadata, with no cancellation history.
  Checkout returns the immutable prepared policy, opaque public scope and fixed
  raw/manual H1 Fetch profile. Capture and bind the original Promise completion
  before publishing request success; a completion cannot replace transport
  retirement or an unresolved request/helper hold.
  Dedicated production endpoints are unaffected by this resource foundation.
  """
  use GenServer
  @behaviour Gaoxy.HTTP.Resources
  alias Gaoxy.Lifecycle
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
    do: Lifecycle.call(owner, {:release, pin}, Lifecycle.deadline(1000))

  def release(_), do: {:error, :invalid_resource_pin}

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
           request_timer: nil
         }}

      _ ->
        {:stop, :instance_unavailable}
    end
  end

  @impl true
  def handle_call(:status, _, state), do: {:reply, {:ok, aggregate(state)}, state}

  def handle_call({:status, handle}, _, state) do
    case record(state, handle) do
      {:ok, _} -> {:reply, {:ok, aggregate(state)}, state}
      error -> {:reply, error, state}
    end
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
         {:ok, pin, state} <- acquire_pins(state, handles, holder, kind, operation, caller) do
      {:reply, {:ok, pin}, state}
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
         true <- state.lifecycle == :running || {:error, :retiring},
         true <- valid_deadline?(deadline) || pending(),
         {:ok, entry} <- record(state, handle),
         true <-
           (entry.lifecycle == :active and not entry.transport_confirmed) ||
             {:error, :resource_unavailable},
         :ok <- request_pin(state, handle, pins, guardian),
         {:ok, token, hold} <- token_hold(state, entry, guardian, deadline) do
      hold = %{hold | guardian_monitor: Process.monitor(guardian)}
      state = %{state | tokens: Map.put(state.tokens, token, hold)}

      client = %{
        policy: entry.policy,
        transport_scope: entry.scope,
        fetch_options: @fetch_options
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
      {:reply, :ok,
       %{state | tokens: Map.put(state.tokens, token, %{hold | completion: completion})}}
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

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_info({:custodian_ready, resource, custodian, capability}, state) do
    case state.records do
      %{
        ^resource =>
          %{custodian: ^custodian, capability: ^capability, lifecycle: :opening} = entry
      } ->
        send(custodian, {:open, entry.capability})
        {:noreply, state}

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
                 state.lifecycle == :running do
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
            entry = %{entry | lifecycle: :failed, from: nil, opening: false}
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
        {:noreply, settle_entry(put_entry(state, entry), entry)}

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
            {:noreply, settle_entry(put_entry(state, entry), entry)}

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
        {:noreply, join_request_helper(state, token, %{hold | abort_result: result})}

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
    for {_, entry} <- state.records, do: send(entry.custodian, {:retire, entry.capability})
    {:noreply, %{state | lifecycle: :retiring}}
  end

  def handle_info({:DOWN, monitor, :process, _, _}, state) do
    state =
      Enum.reduce(state.records, state, fn {_, entry}, acc ->
        cond do
          entry.custodian_monitor == monitor ->
            if entry.from, do: GenServer.reply(entry.from, {:error, :cleanup_unconfirmed})
            lifecycle = if entry.transport_confirmed, do: :retired, else: :failed
            entry = %{entry | lifecycle: lifecycle, from: nil, custodian_down: true}
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

    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  @impl true
  def terminate(_, state) do
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
      admission: :open
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
        {:ok, %{lifecycle: :active, admission: :open, transport_confirmed: false}} -> {:cont, :ok}
        {:ok, _} -> {:halt, {:error, :resource_admission_closed}}
        error -> {:halt, error}
      end
    end)
  end

  defp acquire_pins(state, handles, holder, kind, operation, caller) do
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
        send(entry.custodian, {:retire, entry.capability})
        put_entry(state, %{entry | admission: :closed})

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
      | guardian_down: true,
        abort_helper: {helper, monitor},
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

  defp handle(state, resource),
    do: %{provider: __MODULE__, owner: self(), owner_epoch: state.epoch, resource: resource}

  defp abandon(state, entry) do
    if entry.from, do: GenServer.reply(entry.from, pending())
    cancel_timer(entry.timer)
    entry = %{entry | from: nil}
    put_entry(state, entry)
  end

  defp put_entry(state, entry),
    do: %{state | records: Map.put(state.records, entry.resource, entry)}

  defp update_custodian(state, resource, pid, capability, lifecycle) do
    case state.records do
      %{^resource => %{custodian: ^pid, capability: ^capability} = entry} ->
        {:noreply, put_entry(state, %{entry | lifecycle: lifecycle, opening: false})}

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

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(timer), do: Process.cancel_timer(timer)
  defp valid_deadline?(deadline), do: is_integer(deadline) and Lifecycle.remaining(deadline) > 0
  defp pending, do: {:error, {:deadline_exceeded, :cleanup_pending}}
end
