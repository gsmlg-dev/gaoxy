defmodule Gaoxy.Proxy.UpstreamGroups.Probe do
  @moduledoc false
  use GenServer, restart: :temporary
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.{HTTPFetchClient, UpstreamGroups}
  def start_link(args), do: GenServer.start_link(__MODULE__, args)
  def cancel(pid), do: GenServer.cast(pid, :cancel)

  @impl true
  def init(%{recovery: _} = args) do
    send(self(), :recover)
    {:ok, Map.put(args, :owner_monitor, Process.monitor(args.owner))}
  end

  def init(args) do
    deadline = Lifecycle.deadline(args.health.timeout)
    timer = Process.send_after(self(), :expired, Lifecycle.remaining(deadline))

    state =
      Map.merge(args, %{
        deadline: deadline,
        cleanup_deadline: deadline + 1_000,
        owner_monitor: Process.monitor(args.owner),
        timer: timer,
        request: nil,
        terminal: false,
        cancelled: false,
        headers: false,
        outcome: :failure
      })

    {:ok, state, {:continue, :open}}
  end

  @impl true
  def handle_continue(:open, state) do
    config = state.member.config

    options = %{
      url: state.url,
      method: :head,
      headers: [],
      body: :none,
      cacertfile: config.cacertfile,
      connect_address: config.connect_address,
      timeout: Lifecycle.remaining(state.deadline),
      opening_timeout: state.health.timeout,
      write_timeout: min(config.limits.write_timeout, state.health.timeout)
    }

    case HTTPFetchClient.open(options) do
      {:ok, request, _} ->
        case UpstreamGroups.bind_probe(
               state.owner,
               state.token,
               HTTPFetchClient.completion(request)
             ) do
          :ok ->
            schedule()
            {:noreply, %{state | request: request}}

          {:error, _} ->
            settle(%{state | request: request, cancelled: true, terminal: true})
        end

      {:error, {:cleanup_unconfirmed, _} = reason} ->
        {:stop, reason, state}

      {:error, _} ->
        complete(%{state | terminal: true})
    end
  end

  @impl true
  def handle_cast(:cancel, state), do: settle(%{state | cancelled: true, terminal: true})

  @impl true
  def handle_info(:recover, %{recovery: {kind, token}} = state) do
    case HTTPFetchClient.await_completion(state.completion, true) do
      :ok ->
        send(state.owner, {:recovered, kind, token, self(), :ok})
        {:stop, :normal, state}

      {:error, :cleanup_pending} ->
        if Lifecycle.remaining(state.deadline) > 0 do
          Process.send_after(self(), :recover, 5)
          {:noreply, state}
        else
          send(state.owner, {:recovered, kind, token, self(), {:error, :cleanup_unconfirmed}})
          {:stop, :cleanup_unconfirmed, state}
        end

      {:error, reason} ->
        send(state.owner, {:recovered, kind, token, self(), {:error, reason}})
        {:stop, reason, state}
    end
  end

  def handle_info(:expired, state), do: settle(%{state | cancelled: true, terminal: true})
  def handle_info(:poll, %{terminal: true} = state), do: settle(state)

  def handle_info(:poll, state) do
    {event, request} = HTTPFetchClient.poll_headers(state.request)
    dispatch(event, %{state | request: request})
  end

  def handle_info({:DOWN, ref, :process, _, _}, %{owner_monitor: ref, recovery: _} = state),
    do: {:stop, :owner_down, state}

  def handle_info({:DOWN, ref, :process, _, _}, %{owner_monitor: ref} = state),
    do: settle(%{state | cancelled: true, terminal: true})

  def handle_info(message, %{request: request} = state) when not is_nil(request) do
    {event, request} = HTTPFetchClient.event(request, message)
    dispatch(event, %{state | request: request})
  end

  def handle_info(_, state), do: {:noreply, state}

  defp dispatch({:headers, status, _}, state) do
    state = %{
      state
      | headers: true,
        outcome: if(status in 200..299, do: :success, else: :failure)
    }

    if state.request.stream == nil do
      settle(%{state | terminal: true})
    else
      :ok = HTTPFetchClient.subscribe(state.request)
      {:noreply, state}
    end
  end

  defp dispatch(:end, state), do: settle(%{state | terminal: true})

  defp dispatch({:chunk, _, _}, state),
    do: settle(%{state | outcome: :failure, cancelled: true, terminal: true})

  defp dispatch({:error, _}, state),
    do: settle(%{state | outcome: :failure, cancelled: true, terminal: true})

  defp dispatch(:none, state) do
    if not state.headers, do: schedule()
    {:noreply, state}
  end

  defp dispatch(_, state), do: {:noreply, state}

  defp settle(%{request: nil} = state), do: complete(state)

  defp settle(state) do
    case HTTPFetchClient.cleanup(state.request, state.cancelled) do
      :ok ->
        complete(state)

      {:error, :cleanup_pending} ->
        if Lifecycle.remaining(state.cleanup_deadline) > 0 do
          schedule()
          {:noreply, state}
        else
          {:stop, :cleanup_unconfirmed, state}
        end

      {:error, reason} ->
        {:stop, {:cleanup_failed, reason}, state}
    end
  end

  defp complete(state) do
    Process.cancel_timer(state.timer)

    case UpstreamGroups.probe_finished(state.owner, state.token, state.outcome) do
      :ok -> {:stop, :normal, state}
      {:error, _} -> {:stop, :owner_unavailable, state}
    end
  end

  defp schedule, do: Process.send_after(self(), :poll, 5)
end
