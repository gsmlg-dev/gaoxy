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
    do: begin_cleanup(state)

  def handle_info({:DOWN, monitor, :process, _, _}, %{owner_monitor: monitor} = state),
    do: begin_cleanup(state)

  def handle_info({:retire_result, helper, result}, %{retire_helper: {helper, _monitor}} = state) do
    join_helper(%{state | helper_result: result})
  end

  def handle_info(
        {:DOWN, monitor, :process, helper, _},
        %{retire_helper: {helper, monitor}} = state
      ) do
    join_helper(%{state | helper_down: true})
  end

  def handle_info(:check_retired, %{receipt: receipt} = state) when not is_nil(receipt) do
    case ManagedTransport.await_retired(receipt, 0) do
      :ok ->
        send(state.owner, {:custodian_retired, state.resource, self(), state.capability})
        {:stop, :normal, state}

      {:error, :cleanup_pending} ->
        if System.monotonic_time(:millisecond) < state.cleanup_deadline do
          Process.send_after(self(), :check_retired, 10)
        else
          send(state.owner, {:custodian_failed, state.resource, self(), state.capability})
        end

        {:noreply, state}

      _ ->
        send(state.owner, {:custodian_failed, state.resource, self(), state.capability})
        {:noreply, state}
    end
  end

  def handle_info(_, state), do: {:noreply, state}

  defp join_helper(%{helper_down: true, helper_result: result} = state) when not is_nil(result) do
    {helper, monitor} = state.retire_helper
    Process.demonitor(monitor, [:flush])

    send(
      state.owner,
      {:custodian_helper_finished, state.resource, self(), state.capability, helper}
    )

    state = %{state | retire_helper: nil, helper_result: nil, helper_down: false}

    case result do
      {:ok, receipt} ->
        send(self(), :check_retired)
        {:noreply, %{state | receipt: receipt}}

      _ ->
        send(state.owner, {:custodian_failed, state.resource, self(), state.capability})
        {:noreply, state}
    end
  end

  defp join_helper(state), do: {:noreply, state}

  defp open(%{open_options: options}) do
    ManagedTransport.open(options)
  catch
    _, _ -> {:error, :cleanup_unconfirmed}
  end

  defp open(_), do: {:error, :invalid_policy}

  defp begin_cleanup(%{scope: nil} = state), do: {:stop, :normal, state}

  defp begin_cleanup(%{retire_helper: helper} = state) when not is_nil(helper),
    do: {:noreply, state}

  defp begin_cleanup(%{receipt: receipt} = state) when not is_nil(receipt), do: {:noreply, state}

  defp begin_cleanup(state) do
    parent = self()
    scope = state.scope

    {helper, monitor} =
      spawn_monitor(fn ->
        result =
          try do
            ManagedTransport.retire(scope, mode: :abort)
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

    {:noreply,
     %{
       state
       | retire_helper: {helper, monitor},
         cleanup_deadline: System.monotonic_time(:millisecond) + @cleanup_timeout
     }}
  end
end
