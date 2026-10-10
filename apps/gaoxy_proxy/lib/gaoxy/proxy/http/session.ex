defmodule Gaoxy.Proxy.HTTP.Session do
  @moduledoc false
  use GenServer, restart: :temporary
  alias Gaoxy.{Lifecycle, Proxy.HTTPFetchClient}
  alias Gaoxy.Proxy.UpstreamGroups
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

    {:ok,
     Map.merge(args, %{
       monitors: monitors,
       opening_timer: nil,
       activated_at: nil,
       opening_deadline: nil,
       total_timer: nil,
       selection: nil,
       outcome: :cancelled,
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
  def handle_cast(:cancel, state), do: settle(mark_cancelled(state))

  def handle_cast(:consumed, %{cancelled: true} = state), do: settle(state)
  def handle_cast(:consumed, state), do: settle(%{state | consumed: true, outcome: :success})

  def handle_cast({:acknowledge, ref}, %{delivery: ref} = state) do
    :ok = @client.acknowledge(state.request, ref)
    {:noreply, %{state | delivery: nil}}
  end

  def handle_cast(_, state), do: {:noreply, state}

  @impl true
  def handle_info({:gaoxy_cleanup_activate, token}, %{token: nil} = state) do
    activated_at = Lifecycle.now()
    opening_deadline = min(state.deadline, activated_at + state.config.limits.opening_timeout)

    state = %{
      state
      | token: token,
        activated_at: activated_at,
        opening_deadline: opening_deadline,
        opening_timer:
          Process.send_after(self(), :opening_expired, Lifecycle.remaining(opening_deadline)),
        total_timer:
          Process.send_after(self(), :total_expired, Lifecycle.remaining(state.deadline))
    }

    cond do
      state.cancelled ->
        settle(state)

      not @client.host_supported?() ->
        fail(state, :unsupported_http_proxy_host)

      Lifecycle.remaining(state.deadline) <= 0 ->
        fail(state, :timeout)

      true ->
        with {:ok, state, config} <- select(state) do
          state = apply_limits(state, config.limits)

          options =
            Map.merge(state.request_options, %{
              url:
                URI.to_string(%{
                  config.uri
                  | path: state.request_options.path,
                    query: state.request_options.query
                }),
              timeout: Lifecycle.remaining(state.deadline),
              opening_timeout: Lifecycle.remaining(state.opening_deadline),
              write_timeout: state.config.limits.write_timeout,
              cacertfile: config.cacertfile,
              connect_address: config.connect_address
            })

          result =
            cond do
              options.timeout <= 0 -> {:error, :request_timeout}
              options.opening_timeout <= 0 -> {:error, :timeout}
              true -> @client.open(options)
            end

          case result do
            {:ok, request, upload} ->
              state = %{state | request: request}

              case bind(state) do
                :ok ->
                  notify(state, {:ready, upload, state.config.limits, state.deadline})
                  schedule()
                  {:noreply, state}

                {:error, reason} ->
                  fail(state, reason)
              end

            {:error, {:cleanup_unconfirmed, _} = reason} ->
              notify(state, {:error, reason})
              {:stop, reason, state}

            {:error, reason} ->
              upstream_fail(state, reason)
          end
        else
          {:error, reason} -> fail(state, reason)
        end
    end
  end

  def handle_info({:gaoxy_cleanup_cancel, token, _reason, _deadline}, %{token: token} = state),
    do: settle(mark_cancelled(state))

  def handle_info({:DOWN, ref, :process, _, _}, state) when is_map_key(state.monitors, ref),
    do: settle(mark_cancelled(state))

  def handle_info(event, %{cancelled: true} = state)
      when event in [:opening_expired, :total_expired],
      do: settle(state)

  def handle_info(:opening_expired, %{headers: false} = state),
    do: upstream_fail(state, :timeout)

  def handle_info(:opening_expired, state), do: {:noreply, state}
  def handle_info(:total_expired, state), do: fail(state, :timeout)

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

  defp dispatch({:error, reason}, state), do: upstream_fail(state, reason)

  defp dispatch(:none, state) do
    if not state.headers, do: schedule()
    {:noreply, state}
  end

  defp fail(state, reason) do
    notify(state, {:error, reason})
    settle(%{state | cancelled: true, consumed: true})
  end

  defp upstream_fail(%{cancelled: true} = state, _reason), do: settle(state)

  defp upstream_fail(state, reason) do
    outcome =
      if reason == :request_timeout or Lifecycle.remaining(state.deadline) <= 0,
        do: :cancelled,
        else: :upstream_failure

    fail(%{state | outcome: outcome}, reason)
  end

  defp mark_cancelled(%{cancelled: true} = state), do: state
  defp mark_cancelled(state), do: %{state | cancelled: true, consumed: true, outcome: :cancelled}

  defp apply_limits(state, member_limits) do
    limits =
      Map.new(state.config.limits, fn {key, value} -> {key, min(value, member_limits[key])} end)

    deadline = min(state.deadline, state.started_at + limits.max_lifetime)

    opening_deadline =
      min(state.opening_deadline, min(deadline, state.activated_at + limits.opening_timeout))

    Process.cancel_timer(state.opening_timer)
    Process.cancel_timer(state.total_timer)

    %{
      state
      | config: %{state.config | limits: limits},
        deadline: deadline,
        opening_deadline: opening_deadline,
        opening_timer:
          Process.send_after(self(), :opening_expired, Lifecycle.remaining(opening_deadline)),
        total_timer: Process.send_after(self(), :total_expired, Lifecycle.remaining(deadline))
    }
  end

  defp settle(%{token: nil, cancelled: true} = state), do: {:stop, :normal, state}
  defp settle(%{token: nil} = state), do: {:noreply, state}

  defp settle(state) do
    result = if state.request, do: @client.cleanup(state.request, state.cancelled), else: :ok

    case result do
      :ok ->
        if state.consumed or state.cancelled do
          case finish_selection(state) do
            :ok ->
              _ = Gaoxy.Service.complete_cleanup(state.service, state.token)
              {:stop, :normal, state}

            {:error, reason} ->
              {:stop, {:selection_cleanup_failed, reason}, state}
          end
        else
          {:noreply, state}
        end

      {:error, :cleanup_pending} ->
        if Lifecycle.remaining(state.deadline + 1_000) > 0 do
          schedule()
          {:noreply, state}
        else
          {:stop, :cleanup_unconfirmed, state}
        end

      {:error, reason} ->
        notify(state, {:error, {:cleanup_failed, reason}})
        {:stop, {:cleanup_failed, reason}, state}
    end
  end

  defp select(%{selector: {:fixed, config}} = state), do: {:ok, state, config}

  defp select(%{selector: {:group, handle, pins}} = state) do
    case UpstreamGroups.checkout(
           handle,
           pins,
           self(),
           %{},
           min(state.deadline, state.opening_deadline)
         ) do
      {:ok, member, token} -> {:ok, %{state | selection: {handle, token}}, member.config}
      {:error, reason} -> {:error, reason}
    end
  end

  defp bind(%{selection: nil}), do: :ok

  defp bind(%{selection: {handle, token}, request: request}),
    do: UpstreamGroups.bind_completion(handle, token, @client.completion(request))

  defp finish_selection(%{selection: nil}), do: :ok

  defp finish_selection(%{selection: {handle, token}} = state),
    do: UpstreamGroups.finish(handle, token, state.outcome)

  defp notify(state, event), do: send(state.owner, {:gaoxy_proxy_http, self(), event})
  defp schedule, do: Process.send_after(self(), :poll, @poll_ms)
end
