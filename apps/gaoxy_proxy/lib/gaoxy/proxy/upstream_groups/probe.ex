defmodule Gaoxy.Proxy.UpstreamGroups.Probe do
  @moduledoc false
  use GenServer, restart: :temporary
  alias Gaoxy.Lifecycle
  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Proxy.{HTTPFetchClient, UpstreamGroups, UpstreamTransports}
  def start_link(args), do: GenServer.start_link(__MODULE__, args)
  def cancel(pid), do: GenServer.cast(pid, :cancel)

  @impl true
  def init(%{recovery: _} = args) do
    send(self(), :recover)
    {:ok, Map.put(args, :owner_monitor, Process.monitor(args.owner))}
  end

  def init(args) do
    deadline = Map.get(args, :deadline, Lifecycle.deadline(args.health.timeout))
    timer = Process.send_after(self(), :expired, Lifecycle.remaining(deadline))

    state =
      Map.merge(args, %{
        deadline: deadline,
        cleanup_deadline: deadline + 1_000,
        owner_monitor: Process.monitor(args.owner),
        timer: timer,
        request: nil,
        original_request: nil,
        managed_transport: nil,
        transport_selection: nil,
        transport_pins: [],
        terminal: false,
        cancelled: false,
        headers: false,
        outcome: :failure
      })

    {:ok, state, {:continue, :open}}
  end

  @impl true
  def handle_continue(:open, %{member: %{config: %{transport: nil}}} = state),
    do: open(state)

  def handle_continue(:open, state) do
    config = state.member.config

    with {:ok, instance} <- UpstreamGroups.claim_probe(state.owner, state.token, state.deadline),
         :ok <- opening_allowed(state),
         :ok <-
           UpstreamTransports.validate_endpoint(
             config.transport,
             %{
               origin: URI.to_string(config.uri),
               upstream_protocol: :http1,
               instance: instance
             },
             state.deadline
           ),
         :ok <- opening_allowed(state),
         {:ok, pins} <- Resources.pin_many([config.transport], self(), :request, state.deadline) do
      state = %{state | transport_pins: pins}

      with :ok <- opening_allowed(state),
           {:ok, client, token} <-
             UpstreamTransports.checkout(config.transport, pins, self(), state.deadline) do
        state = %{
          state
          | transport_selection: {config.transport, token},
            managed_transport: client
        }

        case opening_allowed(state) do
          :ok -> open(state)
          {:error, _} -> rejected(state)
        end
      else
        {:error, _} -> rejected(state)
      end
    else
      {:error, _} -> rejected(state)
    end
  end

  defp opening_allowed(state) do
    monitor = state.owner_monitor

    receive do
      {:"$gen_cast", :cancel} -> {:error, :cancelled}
      :expired -> {:error, :cancelled}
      {:DOWN, ^monitor, :process, _, _} -> {:error, :cancelled}
    after
      0 ->
        if Lifecycle.remaining(state.deadline) > 0 and Process.alive?(state.owner),
          do: :ok,
          else: {:error, :cancelled}
    end
  end

  defp rejected(state),
    do: settle(%{state | terminal: true, cancelled: true, outcome: :cancelled})

  defp open(state) do
    config = state.member.config

    options = %{
      url: state.url,
      method: :head,
      headers: [],
      body: :none,
      cacertfile: config.cacertfile,
      connect_address: config.connect_address,
      managed_transport: state.managed_transport,
      timeout: Lifecycle.remaining(state.deadline),
      opening_timeout: state.health.timeout,
      write_timeout: min(config.limits.write_timeout, state.health.timeout)
    }

    case HTTPFetchClient.open(options) do
      {:ok, request, _} ->
        state = %{state | request: request, original_request: request}

        case bind(state) do
          :ok ->
            schedule()
            {:noreply, state}

          {:error, _} ->
            settle(%{state | cancelled: true, terminal: true})
        end

      {:error, {:cleanup_unconfirmed, _} = reason} ->
        {:stop, reason, state}

      {:error, _} ->
        complete(%{state | terminal: true})
    end
  end

  defp bind(state) do
    completion = HTTPFetchClient.completion(state.original_request)

    with :ok <- bind_transport(state.transport_selection, completion),
         do: UpstreamGroups.bind_probe(state.owner, state.token, completion)
  end

  defp bind_transport(nil, _), do: :ok

  defp bind_transport({handle, token}, completion),
    do: UpstreamTransports.bind_completion(handle, token, completion)

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
    request = if state.managed_transport, do: state.original_request, else: state.request

    case HTTPFetchClient.cleanup(request, state.cancelled) do
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

    case finish_transport(state) do
      {:ok, state} ->
        case UpstreamGroups.probe_finished(state.owner, state.token, state.outcome) do
          :ok -> {:stop, :normal, state}
          {:error, _} -> {:stop, :owner_unavailable, state}
        end

      {:pending, state} ->
        if Lifecycle.remaining(state.cleanup_deadline) > 0 do
          schedule()
          {:noreply, state}
        else
          {:stop, :cleanup_unconfirmed, state}
        end

      {:error, reason, state} ->
        {:stop, {:cleanup_failed, reason}, state}
    end
  end

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

  defp schedule, do: Process.send_after(self(), :poll, 5)
end
