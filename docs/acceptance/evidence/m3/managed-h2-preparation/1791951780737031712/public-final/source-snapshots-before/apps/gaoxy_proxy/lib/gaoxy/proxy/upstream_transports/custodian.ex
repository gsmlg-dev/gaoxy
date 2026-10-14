defmodule Gaoxy.Proxy.UpstreamTransports.Custodian do
  @moduledoc false
  use GenServer

  alias HTTP.ManagedTransport

  @cleanup_timeout 5000

  def child_spec(options),
    do: %{
      id: {__MODULE__, make_ref()},
      start: {__MODULE__, :start, [options]},
      restart: :temporary
    }

  # Unlinked deliberately: owner death must not erase the scope creator before
  # public retirement has been joined. The custodian watches its owner instead.
  def start(options), do: GenServer.start(__MODULE__, options)

  @impl true
  def init(options) do
    owner = Keyword.fetch!(options, :owner)
    resource = Keyword.fetch!(options, :resource)
    capability = Keyword.get(options, :capability)
    if capability, do: send(owner, {:custodian_ready, resource, self(), capability})

    {:ok,
     %{
       owner: owner,
       owner_monitor: Process.monitor(owner),
       resource: resource,
       policy: Keyword.fetch!(options, :policy),
       capability: capability,
       opened: false,
       scope: nil,
       retire_helper: nil,
       helper_result: nil,
       helper_down: false,
       retry_helper: nil,
       retry_result: nil,
       retry_down: false,
       control_calls: 0,
       initial_mode: nil,
       managed_retirement: false,
       mode: nil,
       stop_deadline: nil,
       check_timer: nil,
       confirmed: false,
       failed: false,
       receipt: nil,
       cleanup_deadline: nil
     }}
  end

  @impl true
  def handle_info({:open, capability}, %{opened: false, capability: stored} = state)
      when is_reference(capability) and (stored == nil or stored == capability) do
    result = open(state.policy)
    send(state.owner, {:custodian_open_result, state.resource, self(), capability, result})

    scope =
      case result do
        {:ok, scope} -> scope
        _ -> nil
      end

    {:noreply, %{state | capability: capability, opened: true, scope: scope}}
  end

  def handle_info({:discard, capability}, %{capability: capability, scope: nil} = state),
    do: {:stop, :normal, state}

  def handle_info({:retire, capability}, %{capability: capability} = state),
    do: begin_cleanup(state, :abort, now() + @cleanup_timeout)

  def handle_info({:retire, capability, mode, deadline}, %{capability: capability} = state)
      when mode in [:graceful, :abort] and is_integer(deadline),
      do: begin_cleanup(%{state | managed_retirement: true}, mode, deadline)

  def handle_info({:DOWN, monitor, :process, _, _}, %{owner_monitor: monitor} = state),
    do: begin_cleanup(state, :abort, state.stop_deadline || now() + @cleanup_timeout)

  def handle_info({:retire_result, helper, result}, %{retire_helper: {helper, _monitor}} = state) do
    progress(%{state | helper_result: result})
  end

  def handle_info({:retire_result, helper, result}, %{retry_helper: {helper, _}} = state),
    do: progress(%{state | retry_result: result})

  def handle_info(
        {:DOWN, monitor, :process, helper, _},
        %{retire_helper: {helper, monitor}} = state
      ) do
    progress(%{state | helper_down: true})
  end

  def handle_info(
        {:DOWN, monitor, :process, helper, _},
        %{retry_helper: {helper, monitor}} = state
      ),
      do: progress(%{state | retry_down: true})

  def handle_info(:check_retired, state), do: progress(%{state | check_timer: nil})

  def handle_info(_, state), do: {:noreply, state}

  defp join_helper(%{retire_helper: {_, _}, helper_down: true, helper_result: result} = state)
       when not is_nil(result) do
    {helper, monitor} = state.retire_helper
    Process.demonitor(monitor, [:flush])

    send(
      state.owner,
      {:custodian_helper_finished, state.resource, self(), state.capability, helper}
    )

    state = %{state | retire_helper: nil, helper_result: nil, helper_down: false}
    keep_receipt(state, result)
  end

  defp join_helper(state), do: state

  defp open(%{open_options: options}) do
    ManagedTransport.open(options)
  catch
    _, _ -> {:error, :cleanup_unconfirmed}
  end

  defp open(_), do: {:error, :invalid_policy}

  defp begin_cleanup(%{scope: nil, opened: false} = state, _, _) do
    # The authenticated ready/open handshake has not permitted any allocation.
    send(state.owner, {:custodian_retired, state.resource, self(), state.capability})
    {:stop, :normal, state}
  end

  defp begin_cleanup(%{scope: nil} = state, _, _), do: {:stop, :normal, state}

  defp begin_cleanup(state, mode, deadline) do
    stop_deadline = if state.stop_deadline, do: min(state.stop_deadline, deadline), else: deadline

    cleanup_deadline =
      if state.cleanup_deadline,
        do: min(state.cleanup_deadline, stop_deadline + @cleanup_timeout),
        else: stop_deadline + @cleanup_timeout

    mode =
      if state.mode == :abort or mode == :abort or now() >= stop_deadline,
        do: :abort,
        else: :graceful

    state = %{
      state
      | mode: mode,
        stop_deadline: stop_deadline,
        cleanup_deadline: cleanup_deadline
    }

    progress(state)
  end

  defp start_helper(state, slot) do
    parent = self()
    scope = state.scope
    mode = state.mode

    {helper, monitor} =
      spawn_monitor(fn ->
        result =
          try do
            ManagedTransport.retire(scope, mode: mode)
          catch
            _, _ -> {:error, :cleanup_unconfirmed}
          end

        send(parent, {:retire_result, self(), result})
      end)

    send(state.owner, {:custodian_retiring, state.resource, self(), state.capability})

    send(
      state.owner,
      {:custodian_helper_started, state.resource, self(), state.capability, helper}
    )

    state = %{state | control_calls: state.control_calls + 1}

    if slot == :initial,
      do: %{state | retire_helper: {helper, monitor}, initial_mode: mode},
      else: %{state | retry_helper: {helper, monitor}}
  end

  defp join_retry(
         %{retry_helper: {helper, monitor}, retry_down: true, retry_result: result} = state
       )
       when not is_nil(result) do
    Process.demonitor(monitor, [:flush])

    send(
      state.owner,
      {:custodian_helper_finished, state.resource, self(), state.capability, helper}
    )

    keep_receipt(%{state | retry_helper: nil, retry_result: nil, retry_down: false}, result)
  end

  defp join_retry(state), do: state
  defp keep_receipt(state, {:ok, receipt}), do: %{state | receipt: receipt}
  defp keep_receipt(state, _), do: state

  defp progress(state) do
    # Count an occupied initiation slot before joining its actor so recovery
    # cannot exceed the two reserved control calls.
    state =
      if state.retire_helper != nil and state.control_calls == 0,
        do: %{state | control_calls: 1, initial_mode: state.mode || :abort},
        else: state

    state = join_helper(state) |> join_retry()

    state =
      if state.mode == nil,
        do: %{
          state
          | mode: :abort,
            stop_deadline: state.cleanup_deadline || now() + @cleanup_timeout,
            cleanup_deadline: state.cleanup_deadline || now() + @cleanup_timeout
        },
        else: state

    state = if now() >= state.stop_deadline, do: %{state | mode: :abort}, else: state

    state =
      cond do
        state.control_calls == 0 ->
          start_helper(state, :initial)

        state.control_calls == 1 and state.retry_helper == nil and
            ((state.managed_retirement and state.helper_down and state.helper_result == nil) or
               (state.retire_helper == nil and state.receipt == nil) or
               (state.mode == :abort and state.initial_mode == :graceful and not state.confirmed)) ->
          # An initiation without a receipt is uncertain, including a joined error.
          # Use the single replacement for cancellation and receipt recovery.
          state =
            if (state.managed_retirement and state.helper_down and state.helper_result == nil) or
                 (state.retire_helper == nil and state.receipt == nil),
               do: %{state | mode: :abort},
               else: state

          start_helper(state, :retry)

        true ->
          state
      end

    outcome = if state.receipt, do: ManagedTransport.await_retired(state.receipt, 0), else: nil
    state = if outcome == :ok, do: confirm(state), else: state

    # The original return may be permanently lost. Genuine original DOWN plus
    # a repeated public retirement confirmation supplies the recovery evidence.
    state =
      if state.confirmed and state.retire_helper != nil and state.helper_down and
           state.helper_result == nil do
        {helper, monitor} = state.retire_helper
        Process.demonitor(monitor, [:flush])

        send(
          state.owner,
          {:custodian_helper_finished, state.resource, self(), state.capability, helper}
        )

        %{state | retire_helper: nil, helper_down: false}
      else
        state
      end

    cond do
      state.confirmed and state.retire_helper == nil and state.retry_helper == nil ->
        {:stop, :normal, state}

      outcome == {:error, :cleanup_unconfirmed} or now() >= state.cleanup_deadline or
          (state.control_calls == 2 and state.retire_helper == nil and state.retry_helper == nil and
             state.receipt == nil) ->
        {:noreply, fail(state)}

      state.check_timer == nil ->
        {:noreply, %{state | check_timer: Process.send_after(self(), :check_retired, 10)}}

      true ->
        {:noreply, state}
    end
  end

  defp confirm(%{confirmed: true} = state), do: state

  defp confirm(state) do
    send(state.owner, {:custodian_retired, state.resource, self(), state.capability})
    %{state | confirmed: true}
  end

  defp fail(%{failed: true} = state), do: state

  defp fail(state) do
    send(state.owner, {:custodian_failed, state.resource, self(), state.capability})
    %{state | failed: true}
  end

  defp now, do: System.monotonic_time(:millisecond)
end
