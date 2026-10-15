defmodule Gaoxy.Proxy.WebSocket.Session do
  @moduledoc false
  use GenServer, restart: :temporary
  alias Gaoxy.Lifecycle
  alias HTTP.WebSocket, as: Client
  alias HTTP.WebSocket.Event.{Open, Frame, Close, Error}

  def start_link(args), do: GenServer.start_link(__MODULE__, args)
  def cancel(pid), do: GenServer.cast(pid, :cancel)
  def close(pid, detail), do: GenServer.cast(pid, {:close, detail})
  def downstream_ready(pid, token), do: GenServer.cast(pid, {:ready, token})

  def await_open(pid, deadline), do: call(pid, :await_open, Lifecycle.remaining(deadline))
  def forward(pid, opcode, bytes, timeout), do: call(pid, {:forward, opcode, bytes}, timeout)

  defp call(pid, message, timeout) do
    GenServer.call(pid, message, timeout)
  catch
    :exit, {:timeout, _} -> {:error, :timeout}
    :exit, _ -> {:error, :closed}
  end

  @impl true
  def init(args) do
    monitors =
      for pid <- Enum.uniq([args.owner, args.service, args.instance, args.gate]),
          into: %{},
          do: {Process.monitor(pid), pid}

    timer = Process.send_after(self(), :opening_expired, Lifecycle.remaining(args.deadline))

    {:ok,
     Map.merge(args, %{
       monitors: monitors,
       timer: timer,
       token: nil,
       socket: nil,
       socket_monitor: nil,
       upstream_down: false,
       ready: false,
       downstream_ready: false,
       protocol: "",
       waiter: nil,
       send: nil,
       delivery: nil,
       closing: nil,
       close_sent: false,
       cancelled: false
     })}
  end

  @impl true
  def handle_call(:await_open, {owner, _} = from, %{owner: owner} = state) do
    cond do
      state.ready -> {:reply, {:ok, state.protocol}, state}
      state.closing != nil -> {:reply, {:error, :closed}, state}
      true -> {:noreply, %{state | waiter: from}}
    end
  end

  def handle_call(
        {:forward, opcode, bytes},
        {owner, _} = from,
        %{owner: owner, ready: true, send: nil, closing: nil} = state
      )
      when opcode in [:text, :binary] and is_binary(bytes) do
    case Client.send_frame_ack(state.socket, {opcode, bytes}) do
      {:ok, ref} -> {:noreply, %{state | send: {from, ref}}}
      {:error, reason} -> {:reply, {:error, reason}, cancel_state(state, {1011, ""})}
    end
  end

  def handle_call(_, _, state), do: {:reply, {:error, :closed}, state}

  @impl true
  def handle_cast({:ready, token}, %{token: token} = state),
    do: settle(%{state | downstream_ready: true})

  def handle_cast({:close, detail}, state), do: settle(cancel_state(state, detail))
  def handle_cast(:cancel, state), do: settle(cancel_state(state, {1001, ""}))
  def handle_cast(_, state), do: {:noreply, state}

  @impl true
  def handle_info({:gaoxy_cleanup_activate, token}, %{token: nil} = state) do
    state = %{state | token: token}

    if state.closing != nil do
      settle(state)
    else
      case Client.new(state.url, state.protocols, client_options(state)) do
        %Client{} = socket ->
          {:noreply, %{state | socket: socket, socket_monitor: Process.monitor(socket.pid)}}

        {:error, _reason} ->
          settle(cancel_state(state, {1011, ""}))
      end
    end
  end

  def handle_info({:gaoxy_cleanup_cancel, token, _reason, _deadline}, %{token: token} = state),
    do: settle(cancel_state(state, {1001, ""}))

  def handle_info({Client, socket, %Open{}}, %{socket: socket} = state) do
    if state.closing do
      {:noreply, state}
    else
      Process.cancel_timer(state.timer)
      protocol = Client.protocol(socket)
      if state.waiter, do: GenServer.reply(state.waiter, {:ok, protocol})
      timer = Process.send_after(self(), :lifetime_expired, state.config.limits.max_lifetime)
      {:noreply, %{state | ready: true, protocol: protocol, waiter: nil, timer: timer}}
    end
  end

  def handle_info(
        {Client, socket, %Frame{opcode: opcode, data: bytes}, ref},
        %{socket: socket, closing: nil, delivery: nil} = state
      ) do
    if opcode in [:text, :binary] do
      send(state.owner, {:gaoxy_proxy_frame, self(), ref, opcode, bytes})
      {:noreply, %{state | delivery: ref}}
    else
      # Both hops answer Ping automatically; control frames are not replayed.
      :ok = Client.acknowledge(socket, ref)
      {:noreply, state}
    end
  end

  def handle_info({:gaoxy_websocket_written, ref, :ok}, %{delivery: ref} = state) do
    :ok = Client.acknowledge(state.socket, ref)
    {:noreply, %{state | delivery: nil}}
  end

  def handle_info({:gaoxy_websocket_written, ref, {:error, _}}, %{delivery: ref} = state),
    do: settle(cancel_state(%{state | delivery: nil}, {1011, ""}))

  def handle_info(
        {Client, socket, {:send_result, ref, result}},
        %{socket: socket, send: {from, ref}} = state
      ) do
    GenServer.reply(from, result)
    state = %{state | send: nil}
    state = if result == :ok, do: send_close(state), else: cancel_state(state, {1011, ""})
    settle(state)
  end

  def handle_info({Client, socket, %Close{code: code, reason: reason}}, %{socket: socket} = state) do
    {code, reason} = wire_close(code, reason)
    if state.ready, do: send(state.owner, {:gaoxy_proxy_close, self(), code, reason})
    state = reply_waiter(state, {:error, :closed})
    {:noreply, %{state | closing: state.closing || {code, reason}, close_sent: true}}
  end

  def handle_info({Client, socket, %Error{}}, %{socket: socket} = state),
    do: {:noreply, reply_waiter(state, {:error, :upstream})}

  def handle_info({:DOWN, ref, :process, _, _}, %{socket_monitor: ref} = state) do
    state = reply_waiter(state, {:error, :closed})
    if state.send, do: GenServer.reply(elem(state.send, 0), {:error, :closed})
    settle(%{state | upstream_down: true, send: nil})
  end

  def handle_info({:DOWN, ref, :process, _, _}, state) when is_map_key(state.monitors, ref),
    do: settle(cancel_state(state, {1001, ""}))

  def handle_info(:opening_expired, %{ready: false} = state),
    do: settle(state |> reply_waiter({:error, :timeout}) |> cancel_state({1001, ""}))

  def handle_info(:lifetime_expired, state), do: settle(cancel_state(state, {1001, ""}))
  def handle_info(_, state), do: {:noreply, state}

  defp cancel_state(state, detail) do
    state
    |> Map.put(:cancelled, true)
    |> Map.put(:closing, state.closing || detail)
    |> reply_waiter({:error, :closed})
    |> send_close()
  end

  defp send_close(
         %{socket: socket, send: nil, closing: {code, reason}, close_sent: false} = state
       )
       when not is_nil(socket) do
    _ = Client.close(socket, code, reason)
    %{state | close_sent: true}
  end

  defp send_close(state), do: state

  defp reply_waiter(%{waiter: nil} = state, _result), do: state

  defp reply_waiter(state, result) do
    GenServer.reply(state.waiter, result)
    %{state | waiter: nil}
  end

  # The public socket PID is the cleanup barrier. Neither Close nor an accepted
  # close request proves termination. Keep the attachment through the native
  # upgrade transition, even when an upstream peer closes immediately.
  defp settle(state) do
    complete =
      (state.socket == nil or state.upstream_down) and
        (not state.ready or state.downstream_ready or state.cancelled)

    cond do
      complete and state.token != nil ->
        _ = Gaoxy.Service.complete_cleanup(state.service, state.token)
        {:stop, :normal, state}

      complete and state.token == nil and state.cancelled ->
        {:stop, :normal, state}

      true ->
        {:noreply, state}
    end
  end

  defp wire_close(nil, ""), do: {nil, ""}

  defp wire_close(code, reason) when code in 1000..1014 and code not in [1004, 1005, 1006],
    do: {code, reason}

  defp wire_close(code, reason) when code in 3000..4999, do: {code, reason}
  defp wire_close(_, _), do: {1011, "upstream closed"}

  defp client_options(state) do
    limits = state.config.limits
    opening = max(1, min(limits.opening_timeout, Lifecycle.remaining(state.deadline)))
    ssl = if state.config.cacertfile, do: [cacertfile: state.config.cacertfile], else: []

    [
      mode: :proxy,
      http_version: :http1,
      delivery: :ack,
      automatic_pong: true,
      headers: state.headers,
      telemetry_url: nil,
      tls_backend: :ssl,
      ssl: ssl,
      opening_timeout: opening,
      connect_timeout: opening,
      idle_timeout: limits.idle_timeout,
      close_timeout: limits.close_timeout,
      write_timeout: limits.write_timeout,
      max_message_size: limits.max_message_bytes,
      max_frame_parts: limits.max_fragments,
      max_queue_bytes: max(limits.max_message_bytes, 125) + 7,
      max_queue_events: 1,
      max_send_queue: max(limits.max_message_bytes, 125),
      max_send_frames: 1,
      max_control_frames: 2,
      socket_opts: [recbuf: 16_384, buffer: 16_384]
    ]
  end
end
