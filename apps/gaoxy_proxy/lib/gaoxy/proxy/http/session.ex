defmodule Gaoxy.Proxy.HTTP.Session do
  @moduledoc false
  use GenServer, restart: :temporary
  alias Gaoxy.{Lifecycle, Proxy.HTTPFetchClient}
  @client HTTPFetchClient
  @poll_ms 5

  def start_link(args), do: GenServer.start_link(__MODULE__, args)
  def cancel(pid), do: GenServer.cast(pid, :cancel)
  def consumed(pid), do: GenServer.cast(pid, :consumed)
  def acknowledge(pid, ref), do: GenServer.cast(pid, {:acknowledge, ref})

  @impl true
  def init(args) do
    monitors =
      for pid <- Enum.uniq([args.owner, args.service, args.instance, args.gate]),
          into: %{},
          do: {Process.monitor(pid), pid}

    timer =
      Process.send_after(
        self(),
        :opening_expired,
        min(args.config.limits.opening_timeout, Lifecycle.remaining(args.deadline))
      )

    {:ok,
     Map.merge(args, %{
       monitors: monitors,
       opening_timer: timer,
       token: nil,
       request: nil,
       headers: false,
       delivery: nil,
       trailers: [],
       cancelled: false,
       consumed: false
     })}
  end

  @impl true
  def handle_cast(:cancel, state), do: settle(%{state | cancelled: true, consumed: true})
  def handle_cast(:consumed, state), do: settle(%{state | consumed: true})

  def handle_cast({:acknowledge, ref}, %{delivery: ref} = state) do
    :ok = @client.acknowledge(state.request, ref)
    {:noreply, %{state | delivery: nil}}
  end

  def handle_cast(_, state), do: {:noreply, state}

  @impl true
  def handle_info({:gaoxy_cleanup_activate, token}, %{token: nil} = state) do
    state = %{state | token: token}

    cond do
      state.cancelled ->
        settle(state)

      not @client.host_supported?() ->
        fail(state, :unsupported_http_proxy_host)

      Lifecycle.remaining(state.deadline) <= 0 ->
        fail(state, :timeout)

      true ->
        options =
          Map.merge(state.request_options, %{timeout: Lifecycle.remaining(state.deadline)})

        case @client.open(options) do
          {:ok, request, upload} ->
            notify(state, {:ready, upload})
            schedule()
            {:noreply, %{state | request: request}}

          {:error, {:cleanup_unconfirmed, _} = reason} ->
            notify(state, {:error, reason})
            {:stop, reason, state}

          {:error, reason} ->
            fail(state, reason)
        end
    end
  end

  def handle_info({:gaoxy_cleanup_cancel, token, _reason, _deadline}, %{token: token} = state),
    do: settle(%{state | cancelled: true, consumed: true})

  def handle_info({:DOWN, ref, :process, _, _}, state) when is_map_key(state.monitors, ref),
    do: settle(%{state | cancelled: true, consumed: true})

  def handle_info(:opening_expired, %{headers: false} = state), do: fail(state, :timeout)
  def handle_info(:opening_expired, state), do: {:noreply, state}

  def handle_info(:poll, %{request: nil} = state), do: settle(state)
  def handle_info(:poll, %{cancelled: true} = state), do: settle(state)
  def handle_info(:poll, %{consumed: true} = state), do: settle(state)

  def handle_info(:poll, state) do
    {event, request} = @client.poll_headers(state.request)
    dispatch(event, %{state | request: request})
  end

  def handle_info(message, %{request: request} = state) when not is_nil(request) do
    {event, request} = @client.event(request, message)
    dispatch(event, %{state | request: request})
  end

  def handle_info(_, state), do: {:noreply, state}

  defp dispatch({:headers, status, fields}, state) do
    Process.cancel_timer(state.opening_timer)
    notify(state, {:headers, status, fields})
    :ok = @client.subscribe(state.request)
    state = %{state | headers: true}
    if state.request.stream == nil, do: notify(state, {:end, []})
    {:noreply, state}
  end

  defp dispatch({:chunk, bytes, ref}, %{delivery: nil, cancelled: false} = state) do
    notify(state, {:chunk, bytes, ref})
    {:noreply, %{state | delivery: ref}}
  end

  defp dispatch({:chunk, _, _}, state), do: fail(state, :upstream_delivery_overlap)
  defp dispatch({:trailers, trailers}, state), do: {:noreply, %{state | trailers: trailers}}

  defp dispatch(:end, state) do
    notify(state, {:end, state.trailers})
    {:noreply, state}
  end

  defp dispatch({:error, reason}, state), do: fail(state, reason)

  defp dispatch(:none, state) do
    if not state.headers, do: schedule()
    {:noreply, state}
  end

  defp fail(state, reason) do
    notify(state, {:error, reason})
    settle(%{state | cancelled: true, consumed: true})
  end

  defp settle(%{token: nil, cancelled: true} = state), do: {:stop, :normal, state}
  defp settle(%{token: nil} = state), do: {:noreply, state}

  defp settle(state) do
    result = if state.request, do: @client.cleanup(state.request, state.cancelled), else: :ok

    case result do
      :ok ->
        if state.consumed or state.cancelled do
          _ = Gaoxy.Service.complete_cleanup(state.service, state.token)
          {:stop, :normal, state}
        else
          {:noreply, state}
        end

      {:error, :cleanup_pending} ->
        schedule()
        {:noreply, state}

      {:error, reason} ->
        notify(state, {:error, {:cleanup_failed, reason}})
        {:stop, {:cleanup_failed, reason}, state}
    end
  end

  defp notify(state, event), do: send(state.owner, {:gaoxy_proxy_http, self(), event})
  defp schedule, do: Process.send_after(self(), :poll, @poll_ms)
end
