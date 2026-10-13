defmodule Gaoxy.Proxy.UpstreamTransports do
  @moduledoc """
  Instance-associated finite ownership of immutable managed H1 resources.

  Preparation authenticates the caller as the preparer. Status counts compact
  Gaoxy policy and metadata/control-slot serialized payload; dependency opaque
  handles, process heaps, native allocations and socket memory are excluded.
  Dedicated production endpoints are unaffected by this resource foundation.
  """
  use GenServer
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
           pins: %{}
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
          pins: Map.put(state.pins, pin.ref, pin)
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

      {:noreply, put_entry(state, entry)}
    else
      error -> {:reply, error, state}
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
              GenServer.reply(entry.from, {:ok, handle(state, resource), [state.pins[entry.pin]]})
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
            entry = %{entry | lifecycle: :failed, from: nil, custodian_down: true}
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

    pin = %{
      provider: __MODULE__,
      owner: self(),
      owner_epoch: state.epoch,
      operation: make_ref(),
      ref: pin_ref,
      handles: [handle(state, resource)],
      kind: :preparation,
      holder: preparer
    }

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
      helpers: %{}
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

  defp aggregate(state) do
    %{
      lifecycle: state.lifecycle,
      limits: state.limits,
      resources: map_size(state.records),
      reserved_connections:
        2 * Enum.count(state.records, fn {_, entry} -> not entry.transport_confirmed end),
      pins: map_size(state.pins),
      request_tokens: 0,
      failed_resources:
        Enum.count(state.records, fn {_, entry} -> entry.lifecycle == :failed end),
      helpers:
        Enum.reduce(state.records, 0, fn {_, entry}, sum ->
          sum + map_size(entry.helpers) + if(entry.opening, do: 1, else: 0)
        end),
      owned_serialized_payload_bytes:
        Enum.reduce(state.records, 0, fn {_, entry}, acc -> acc + entry.payload_bytes end) +
          Enum.reduce(state.pins, 0, fn {_, pin}, acc -> acc + :erlang.external_size(pin) end)
    }
  end

  defp record(
         state,
         %{provider: __MODULE__, owner: owner, owner_epoch: epoch, resource: resource} = handle
       )
       when map_size(handle) == 4 do
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
    cleanup_monitors(entry)

    %{
      state
      | records: Map.delete(state.records, entry.resource),
        pins: Map.delete(state.pins, entry.pin)
    }
  end

  defp settle_entry(state, _), do: state

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(timer), do: Process.cancel_timer(timer)
  defp valid_deadline?(deadline), do: is_integer(deadline) and Lifecycle.remaining(deadline) > 0
  defp pending, do: {:error, {:deadline_exceeded, :cleanup_pending}}
end
