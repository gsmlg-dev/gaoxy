defmodule Gaoxy.Proxy.HTTP.Session do
  @moduledoc false
  use GenServer, restart: :temporary
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.HTTP
  alias Gaoxy.Proxy.UpstreamGroups
  alias Gaoxy.Proxy.UpstreamTransports
  alias Gaoxy.HTTP.Resources
  @poll_ms 5

  def start_link(args), do: GenServer.start_link(__MODULE__, args)
  def cancel(pid), do: GenServer.cast(pid, :cancel)
  def expire(pid), do: GenServer.cast(pid, :expire)
  def consumed(pid), do: GenServer.cast(pid, :consumed)
  def acknowledge(pid, ref), do: GenServer.cast(pid, {:acknowledge, ref})

  @impl true
  def init(args) do
    Process.flag(:trap_exit, true)

    monitors =
      for pid <- Enum.uniq([args.owner, args.service, args.instance, args.gate]),
          into: %{},
          do: {Process.monitor(pid), pid}

    {:ok,
     Map.merge(args, %{
       monitors: monitors,
       client: HTTP.selected_client(args.config),
       cleanup_deadline: nil,
       cleanup_requested_deadline: nil,
       cleanup_started: false,
       opening_timer: nil,
       activated_at: nil,
       opening_deadline: nil,
       total_timer: nil,
       selection: nil,
       transport_pins: [],
       transport_selection: nil,
       managed_transport: nil,
       original_request: nil,
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

  def handle_cast(:expire, %{cancelled: true} = state), do: settle(state)
  def handle_cast(:expire, %{consumed: true} = state), do: settle(state)

  def handle_cast(:expire, state) do
    reason =
      if state.client == Gaoxy.Proxy.HTTP3SessionClient and
           Lifecycle.remaining(state.deadline) == 0,
         do: :request_timeout,
         else: :timeout

    fail(state, reason)
  end

  def handle_cast(:consumed, %{cancelled: true} = state), do: settle(state)
  def handle_cast(:consumed, state), do: settle(%{state | consumed: true, outcome: :success})

  def handle_cast(
        {:acknowledge, ref},
        %{delivery: ref, cancelled: false, consumed: false} = state
      ) do
    case state.client.acknowledge(state.request, ref) do
      :ok -> {:noreply, %{state | delivery: nil}}
      {:ok, request} -> {:noreply, %{state | request: request, delivery: nil}}
    end
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

      not state.client.host_supported?() ->
        fail(state, :unsupported_http_proxy_host)

      Lifecycle.remaining(state.deadline) <= 0 ->
        fail(state, :timeout)

      true ->
        with {:ok, state, config} <- select(state) do
          state = apply_limits(state, config.limits)
          state = %{state | client: HTTP.selected_client(config)}

          options =
            Map.merge(state.request_options, %{
              url:
                URI.to_string(%{
                  config.uri
                  | path: state.request_options.path,
                    query: state.request_options.query
                }),
              deadline: state.deadline,
              opening_deadline: state.opening_deadline,
              timeout: Lifecycle.remaining(state.deadline),
              opening_timeout: Lifecycle.remaining(state.opening_deadline),
              write_timeout: state.config.limits.write_timeout,
              cacertfile: config.cacertfile,
              connect_address: config.connect_address,
              managed_transport: state.managed_transport
            })

          result =
            cond do
              options.timeout <= 0 -> {:error, :request_timeout}
              options.opening_timeout <= 0 -> {:error, :timeout}
              true -> state.client.open(options)
            end

          case result do
            {:ok, request, upload} ->
              state = %{state | request: request, original_request: request}

              case bind(state) do
                :ok ->
                  notify(state, {:ready, upload, state.config.limits, state.deadline})
                  schedule(state)
                  {:noreply, state}

                {:error, reason} ->
                  fail(state, reason)
              end

            {:error, {:cleanup_unconfirmed, _} = reason} ->
              if state.transport_selection == nil do
                notify(state, {:error, reason})
                {:stop, reason, state}
              else
                fail(state, reason)
              end

            {:error, reason} ->
              upstream_fail(state, reason)
          end
        else
          {:error, reason, state} -> fail(state, reason)
          {:error, reason} -> fail(state, reason)
        end
    end
  end

  def handle_info({:gaoxy_cleanup_cancel, token, _reason, deadline}, %{token: token} = state) do
    state = %{state | cleanup_requested_deadline: deadline}
    settle(mark_cancelled(state))
  end

  def handle_info({:DOWN, ref, :process, _, _}, state) when is_map_key(state.monitors, ref),
    do: settle(mark_cancelled(state))

  def handle_info(event, %{cancelled: true} = state)
      when event in [:opening_expired, :total_expired],
      do: settle(state)

  def handle_info(event, %{consumed: true} = state)
      when event in [:opening_expired, :total_expired],
      do: settle(state)

  def handle_info(:opening_expired, %{headers: false} = state),
    do: upstream_fail(state, :timeout)

  def handle_info(:opening_expired, state), do: {:noreply, state}

  def handle_info(:total_expired, %{client: Gaoxy.Proxy.HTTP3SessionClient} = state),
    do: fail(state, :request_timeout)

  def handle_info(:total_expired, state), do: fail(state, :timeout)

  def handle_info(:poll, %{request: nil} = state), do: settle(state)
  def handle_info(:poll, %{cancelled: true} = state), do: settle(state)
  def handle_info(:poll, %{consumed: true} = state), do: settle(state)

  def handle_info(:poll, state) do
    {event, request} = state.client.poll_headers(state.request)
    dispatch(event, %{state | request: request})
  end

  def handle_info(message, %{request: request} = state) when not is_nil(request) do
    {event, request} = state.client.event(request, message)
    dispatch(event, %{state | request: request})
  end

  def handle_info(_, state), do: {:noreply, state}

  defp dispatch(_event, %{cancelled: true} = state), do: settle(state)
  defp dispatch(_event, %{consumed: true} = state), do: settle(state)

  defp dispatch({:headers, status, fields}, state) do
    Process.cancel_timer(state.opening_timer)
    notify(state, {:headers, status, fields})
    :ok = state.client.subscribe(state.request)
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
    if not state.headers, do: schedule(state)
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
    state = begin_cleanup(state)
    request = if state.managed_transport, do: state.original_request, else: state.request
    result = if request, do: state.client.cleanup(request, state.cancelled), else: :ok

    case result do
      :ok -> cleanup_complete(state)
      {:ok, request} -> cleanup_complete(%{state | request: request})
      {:pending, request} -> cleanup_pending(%{state | request: request})
      {:error, :cleanup_pending} -> cleanup_pending(state)
      {:error, reason, request} -> cleanup_failed(%{state | request: request}, reason)
      {:error, reason} -> cleanup_failed(state, reason)
    end
  end

  defp begin_cleanup(%{cleanup_started: true} = state), do: state

  defp begin_cleanup(state) do
    deadline =
      if state.client == Gaoxy.Proxy.HTTP3SessionClient do
        deadline = min(Lifecycle.now() + 1_000, state.deadline + 1_000)

        if is_integer(state.cleanup_requested_deadline),
          do: min(deadline, state.cleanup_requested_deadline),
          else: deadline
      else
        state.deadline + 1_000
      end

    state = %{state | cleanup_started: true, cleanup_deadline: deadline}

    if state.request && function_exported?(state.client, :begin_cleanup, 3) do
      {:ok, request} = state.client.begin_cleanup(state.request, state.cancelled, deadline)
      %{state | request: request}
    else
      state
    end
  end

  defp cleanup_complete(state) do
    if state.consumed or state.cancelled do
      case finish_transport(state) do
        {:ok, state} ->
          case finish_selection(state) do
            :ok ->
              case complete_service(state) do
                :ok -> {:stop, :normal, state}
                {:error, reason} -> cleanup_failed(state, {:service_cleanup_failed, reason})
              end

            {:error, reason} ->
              {:stop, {:selection_cleanup_failed, reason}, state}
          end

        {:pending, state} ->
          cleanup_pending(state)

        {:error, reason, state} ->
          cleanup_failed(state, {:transport_cleanup_failed, reason})
      end
    else
      {:noreply, state}
    end
  end

  defp cleanup_pending(state) do
    if Lifecycle.remaining(state.cleanup_deadline) > 0 do
      schedule(state)
      {:noreply, state}
    else
      {:stop, :cleanup_unconfirmed, state}
    end
  end

  defp cleanup_failed(state, reason) do
    notify(state, {:error, {:cleanup_failed, reason}})
    {:stop, {:cleanup_failed, reason}, state}
  end

  defp select(%{selector: {:fixed, config}} = state), do: select_transport(state, config)

  defp select(%{selector: {:group, handle, pins}} = state) do
    case UpstreamGroups.checkout(
           handle,
           pins,
           self(),
           %{},
           min(state.deadline, state.opening_deadline)
         ) do
      {:ok, member, token} ->
        select_transport(%{state | selection: {handle, token}}, member.config)

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  defp select_transport(state, %HTTP{transport: nil} = config), do: {:ok, state, config}

  defp select_transport(state, %HTTP{transport: handle} = config) do
    deadline = min(state.deadline, state.opening_deadline)

    identity = %{
      origin: URI.to_string(config.uri),
      upstream_protocol: :http1,
      instance: state.instance
    }

    with :ok <- UpstreamTransports.validate_endpoint(handle, identity, deadline),
         {:ok, pins} <- Resources.pin_many([handle], self(), :request, deadline) do
      state = %{state | transport_pins: pins}

      case UpstreamTransports.checkout(handle, pins, self(), deadline) do
        {:ok, client, token} ->
          state = %{state | transport_selection: {handle, token}, managed_transport: client}
          {:ok, state, %{config | uri: URI.parse(client.policy.origin)}}

        {:error, reason} ->
          case Resources.release(pins) do
            :ok ->
              {:error, reason, %{state | transport_pins: []}}

            {:error, release_reason} ->
              {:error, {:transport_pin_release_failed, reason, release_reason}, state}
          end
      end
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp bind(%{transport_selection: nil} = state), do: bind_selection(state)

  defp bind(%{transport_selection: {handle, token}, original_request: request} = state) do
    with :ok <-
           UpstreamTransports.bind_completion(handle, token, state.client.completion(request)),
         do: bind_selection(state)
  end

  defp bind_selection(%{selection: nil}), do: :ok

  defp bind_selection(%{selection: {handle, token}, original_request: request} = state),
    do: UpstreamGroups.bind_completion(handle, token, state.client.completion(request))

  defp finish_transport(%{transport_selection: nil} = state), do: release_transport_pins(state)

  defp finish_transport(%{transport_selection: {handle, token}} = state) do
    case UpstreamTransports.finish(handle, token) do
      :ok -> release_transport_pins(%{state | transport_selection: nil})
      {:error, :cleanup_pending} -> {:pending, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp release_transport_pins(state) do
    case Resources.release(state.transport_pins) do
      :ok -> {:ok, %{state | transport_pins: []}}
      {:error, reason} -> {:error, {:pin_release_failed, reason}, state}
    end
  end

  defp complete_service(%{managed_transport: nil} = state) do
    _ = Gaoxy.Service.complete_cleanup(state.service, state.token)
    :ok
  end

  defp complete_service(state), do: Gaoxy.Service.complete_cleanup(state.service, state.token)

  defp finish_selection(%{selection: nil}), do: :ok

  defp finish_selection(%{selection: {handle, token}} = state),
    do: UpstreamGroups.finish(handle, token, state.outcome)

  defp notify(state, event), do: send(state.owner, {:gaoxy_proxy_http, self(), event})
  defp schedule(%{client: Gaoxy.Proxy.HTTP3SessionClient}), do: :ok
  defp schedule(_state), do: Process.send_after(self(), :poll, @poll_ms)
end
