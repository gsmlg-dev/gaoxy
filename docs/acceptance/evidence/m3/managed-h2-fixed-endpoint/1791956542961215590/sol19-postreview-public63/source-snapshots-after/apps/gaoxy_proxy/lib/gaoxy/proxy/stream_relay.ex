defmodule Gaoxy.Proxy.StreamRelay do
  @moduledoc """
  Native bounded duplex relay to a configured numeric destination.

  Modes are `:tcp`, `:tls_termination` (a TLS listener to TCP), `:tls_upstream`
  (TCP to verified TLS), and `:tls_passthrough` (opaque TCP bytes). Verified TLS
  requires `upstream_tls: %{server_name: name, cacertfile: path}`; it dials the
  numeric upstream without changing the explicit certificate identity.

  TCP FIN shuts down only the opposite write direction after acknowledged
  writes. TLS EOF closes both directions with an explicit unsupported-directional
  shutdown reason. There is no SNI inspection, protocol parsing or MITM.
  Receive buffers, carry and writer copies are reserved before polling or
  handoff; each direction has at most one bounded writer message outstanding.
  """
  use ThousandIsland.Handler
  @behaviour Gaoxy.NativeStreamHandler
  alias Gaoxy.{Admission, Lifecycle, Telemetry}
  alias Gaoxy.Proxy.StreamRelay.{Upstream, Writer}
  alias ThousandIsland.Socket

  @raw_limit 65_536
  # Audited OTP28 passive SSL delivery: at most100 transport buffers plus one
  # maximum TLS1.2 record (16384+2048+5). Reserve deliveries and copies before
  # receive, including carry while the independent writer has an occupied slot.
  @tls_limit 100 * 16_384 + 18_437
  @defaults %{
    mode: :tcp,
    max_chunk_bytes: 16_384,
    connect_timeout: 5_000,
    idle_timeout: 30_000,
    max_lifetime: 300_000,
    write_timeout: 5_000,
    upstream_tls: %{}
  }

  @impl Gaoxy.NativeStreamHandler
  def validate_options(options) when is_map(options) do
    config = Map.merge(@defaults, options)

    with true <- Map.keys(options) -- [:upstream | Map.keys(@defaults)] == [],
         {address, port} <- config[:upstream],
         true <- valid_address?(address) and is_integer(port) and port in 1..65_535,
         true <- config.mode in [:tcp, :tls_termination, :tls_upstream, :tls_passthrough],
         true <-
           Enum.all?(
             [:max_chunk_bytes, :connect_timeout, :idle_timeout, :max_lifetime, :write_timeout],
             &(is_integer(config[&1]) and config[&1] > 0)
           ),
         true <- config.max_chunk_bytes <= 16_384,
         true <- Application.get_env(:kernel, :inet_backend, :inet) == :inet,
         true <- tls_host_supported?(config.mode),
         :ok <- tls_options(config) do
      {:ok, config}
    else
      _ -> {:error, :invalid_stream_relay_options}
    end
  end

  def validate_options(_), do: {:error, :invalid_stream_relay_options}

  defp valid_address?(address) when is_tuple(address) and tuple_size(address) in [4, 8] do
    maximum = if tuple_size(address) == 4, do: 255, else: 65_535
    Enum.all?(Tuple.to_list(address), &(is_integer(&1) and &1 in 0..maximum))
  end

  defp valid_address?(_), do: false

  defp tls_host_supported?(mode) when mode in [:tls_termination, :tls_upstream] do
    active = Application.get_env(:ssl, :internal_active_n, 100)
    is_integer(active) and active in 1..100
  end

  defp tls_host_supported?(_), do: true

  defp tls_options(%{
         mode: :tls_upstream,
         upstream_tls: %{server_name: name, cacertfile: ca} = tls
       })
       when is_binary(name) and byte_size(name) in 1..253 and is_binary(ca) do
    if Map.keys(tls) -- [:server_name, :cacertfile] == [] and File.regular?(ca) and
         Enum.all?(
           String.split(name, "."),
           &(byte_size(&1) in 1..63 and
               Regex.match?(~r/\A[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\z/, &1))
         ),
       do: :ok,
       else: {:error, :invalid_upstream_tls}
  end

  defp tls_options(%{mode: mode, upstream_tls: tls})
       when mode != :tls_upstream and map_size(tls) == 0,
       do: :ok

  defp tls_options(_), do: {:error, :invalid_upstream_tls}

  @doc "Validates and dials a numeric upstream within the caller's absolute deadline."
  def connect(options, deadline) when is_integer(deadline) do
    with {:ok, config} <- validate_options(options),
         true <- Lifecycle.remaining(deadline) > 0 || {:error, :deadline_exceeded},
         do: Upstream.connect(config, min(config.connect_timeout, Lifecycle.remaining(deadline)))
  end

  def connect(_, _), do: {:error, :invalid_relay_deadline}

  @doc """
  Synchronously bridges an already-dialled upstream from the current native owner.

  The existing admitted lease and absolute deadline remain in force. Relay
  windows are added before writer/payload handoff; initial bytes (at most64KiB)
  are forwarded once before further downstream reads. This function closes the
  supplied upstream on every outcome and returns a native close/error result.
  """
  def bridge(socket, upstream, context, options, lease, deadline, initial_bytes) do
    try do
      with {:ok, config} <- validate_options(options),
           true <- is_integer(deadline) || {:error, :invalid_relay_deadline},
           true <- Lifecycle.remaining(deadline) > 0 || {:error, :deadline_exceeded},
           true <-
             (is_binary(initial_bytes) and byte_size(initial_bytes) <= @raw_limit) ||
               {:error, :initial_buffer_limit},
           true <-
             Socket.secure?(socket) == (config.mode == :tls_termination) ||
               {:error, :relay_listener_mode},
           :ok <- passive(socket, config),
           :ok <- Admission.adjust_bytes(context.gate, lease, reservation(config)) do
        run(socket, upstream, context, config, lease, deadline, initial_bytes)
      else
        {:error, reason} -> {:error, reason, context}
      end
    after
      Upstream.close(upstream)
    end
  end

  defp delivery_limit(%{mode: mode}) when mode in [:tls_termination, :tls_upstream],
    do: @tls_limit

  defp delivery_limit(_), do: @raw_limit

  defp reservation(config), do: 4 * delivery_limit(config) + 4 * config.max_chunk_bytes + 4_096

  @impl true
  def handle_connection(socket, %{spec: spec, gate: gate} = context) do
    config = spec.handler_options
    deadline = Lifecycle.deadline(config.max_lifetime)
    reserve = reservation(config)

    with true <-
           Socket.secure?(socket) == (config.mode == :tls_termination) ||
             {:error, :relay_listener_mode},
         :ok <- passive(socket, config),
         {:ok, lease} <- Admission.acquire(gate, reserve, drain_notify: true),
         :ok <- Admission.begin_request(gate, lease, reserve, deadline),
         {:ok, upstream} <-
           Upstream.connect(config, min(config.connect_timeout, Lifecycle.remaining(deadline))) do
      try do
        run(socket, upstream, context, config, lease, deadline)
      after
        Upstream.close(upstream)
      end
    else
      {:error, reason} -> {:error, reason, context}
    end
  end

  defp passive(socket, config) do
    options = [
      active: false,
      packet: :raw,
      buffer: config.max_chunk_bytes,
      recbuf: config.max_chunk_bytes,
      send_timeout: config.write_timeout,
      send_timeout_close: false
    ]

    options = if Socket.secure?(socket), do: options, else: [{:exit_on_close, false} | options]
    Socket.setopts(socket, options)
  end

  defp run(socket, upstream, context, config, lease, deadline, initial_bytes \\ "") do
    owner = self()
    capability = make_ref()

    arguments = %{
      owner: owner,
      gate: context.gate,
      reserve: 2 * config.max_chunk_bytes + 1_024,
      deadline: deadline,
      max_chunk: config.max_chunk_bytes,
      write_timeout: config.write_timeout,
      capability: capability
    }

    case start_writer(Map.put(arguments, :target, {:upstream, upstream})) do
      {:ok, up_writer} ->
        up_monitor = Process.monitor(up_writer)

        case start_writer(Map.put(arguments, :target, {:downstream, socket})) do
          {:ok, down_writer} ->
            down_monitor = Process.monitor(down_writer)

            directions = %{
              up: direction(up_writer, up_monitor),
              down: direction(down_writer, down_monitor)
            }

            state =
              Map.merge(context, %{
                lease: lease,
                config: config,
                socket: socket,
                upstream: upstream,
                directions: directions,
                capability: capability,
                deadline: deadline,
                cleanup_deadline: deadline,
                idle_deadline: Lifecycle.deadline(config.idle_timeout),
                writers_stopped: false,
                cancelled: false,
                reason: nil
              })

            final =
              try do
                state |> dispatch(:up, initial_bytes) |> pump()
              catch
                kind, _ -> cancel(state, {:relay_exception, kind})
              end

            if final.cancelled, do: abort_sockets(final)

            cleanup =
              if final.writers_stopped,
                do: :ok,
                else: stop_writers(directions, final.cleanup_deadline)

            reason = if cleanup == :ok, do: final.reason, else: :writer_down_unconfirmed

            Telemetry.emit(:relay_closed, %{count: 1}, context.scope, %{
              mode: config.mode,
              reason: reason
            })

            if cleanup == :ok,
              do: {:close, Map.put(context, :relay_reason, reason)},
              else: {:error, {:relay_cleanup_failed, reason}, context}

          {:error, reason} ->
            cleanup = stop_writers(%{up: direction(up_writer, up_monitor)}, deadline)

            reason =
              if cleanup == :ok,
                do: reason,
                else: {:relay_cleanup_failed, :writer_down_unconfirmed}

            {:error, reason, context}
        end

      {:error, reason} ->
        {:error, reason, context}
    end
  end

  defp start_writer(arguments),
    do: DynamicSupervisor.start_child(Gaoxy.Proxy.SessionSupervisor, {Writer, arguments})

  defp direction(writer, monitor),
    do: %{writer: writer, monitor: monitor, eof: false, pending: nil, carry: ""}

  defp pump(state) do
    state = messages(state)

    cond do
      state.cancelled ->
        state

      Lifecycle.remaining(state.deadline) == 0 ->
        cancel(state, :lifetime_or_drain_timeout)

      Lifecycle.remaining(state.idle_deadline) == 0 ->
        cancel(state, :idle_timeout)

      Enum.all?(state.directions, fn {_, direction} ->
        direction.eof and direction.pending == nil
      end) ->
        finish_output(state)

      true ->
        state = poll(state, :up)
        state = messages(state)
        state = if state.cancelled, do: state, else: poll(state, :down)
        # Bound CPU when both writes are pending; receive shutdown/control on every turn.
        state = wait_if_pending(state)
        pump(state)
    end
  end

  defp finish_output(%{writers_stopped: false} = state) do
    case stop_writers(state.directions, state.cleanup_deadline) do
      :ok -> finish_output(%{state | writers_stopped: true})
      {:error, reason} -> cancel(state, reason)
    end
  end

  defp finish_output(state) do
    state = messages(state)

    cond do
      state.cancelled ->
        state

      Lifecycle.remaining(state.deadline) == 0 ->
        cancel(state, :lifetime_or_drain_timeout)

      Lifecycle.remaining(state.idle_deadline) == 0 ->
        cancel(state, :idle_timeout)

      true ->
        with {:ok, downstream} <- Socket.getstat(state.socket),
             {:ok, upstream} <- Upstream.getstat(state.upstream) do
          if downstream[:send_pend] == 0 and upstream[:send_pend] == 0 do
            %{state | reason: :normal}
          else
            state |> wait_if_pending() |> finish_output()
          end
        else
          {:error, reason} -> cancel(state, {:output_drain, reason})
        end
    end
  end

  defp poll(state, name) do
    direction = state.directions[name]

    cond do
      direction.pending != nil or direction.eof ->
        state

      direction.carry != "" ->
        dispatch(state, name, direction.carry)

      true ->
        timeout =
          min(
            5,
            min(Lifecycle.remaining(state.deadline), Lifecycle.remaining(state.idle_deadline))
          )

        result =
          if name == :up,
            do: Socket.recv(state.socket, 0, timeout),
            else: Upstream.recv(state.upstream, timeout)

        case result do
          {:ok, bytes} ->
            if byte_size(bytes) <= delivery_limit(state.config),
              do: dispatch(state, name, bytes),
              else: cancel(state, :receive_limit)

          {:error, :timeout} ->
            state

          {:error, :closed} ->
            eof(state, name)

          {:error, reason} ->
            cancel(state, {:receive, name, reason})
        end
    end
  end

  defp dispatch(state, _name, ""), do: state

  defp dispatch(state, name, bytes) do
    size = min(byte_size(bytes), state.config.max_chunk_bytes)
    <<chunk::binary-size(size), carry::binary>> = bytes
    token = make_ref()
    direction = state.directions[name]
    deadline = min(state.deadline, Lifecycle.deadline(state.config.write_timeout))
    send(direction.writer, {:relay_write, state.capability, token, chunk, deadline})
    state = put_in(state.directions[name], %{direction | pending: token, carry: carry})
    %{state | idle_deadline: Lifecycle.deadline(state.config.idle_timeout)}
  end

  defp eof(state, name) do
    tls = Socket.secure?(state.socket) or elem(state.upstream, 0) == :tls

    if tls do
      cancel(state, :tls_directional_shutdown_not_supported)
    else
      result =
        if name == :up,
          do: Upstream.shutdown(state.upstream),
          else: Socket.shutdown(state.socket, :write)

      case result do
        :ok -> put_in(state.directions[name].eof, true)
        {:error, reason} -> cancel(state, {:half_close, name, reason})
      end
    end
  end

  defp messages(state) do
    receive do
      message -> state |> message(message) |> messages()
    after
      0 -> state
    end
  end

  defp message(state, {:relay_written, writer, capability, token, result})
       when capability == state.capability do
    case Enum.find(state.directions, fn {_, direction} ->
           direction.writer == writer and direction.pending == token
         end) do
      {name, _} when result == :ok ->
        state = put_in(state.directions[name].pending, nil)
        %{state | idle_deadline: Lifecycle.deadline(state.config.idle_timeout)}

      {name, _} ->
        cancel(state, {:write, name, result})

      nil ->
        state
    end
  end

  defp message(state, {:gaoxy_drain, gate, lease, deadline})
       when gate == state.gate and lease == state.lease do
    # Writer DOWN, socket closure and the service receipt share this budget.
    cleanup_margin = min(25, div(Lifecycle.remaining(deadline), 4))

    %{
      state
      | deadline: min(state.deadline, deadline - cleanup_margin),
        cleanup_deadline: min(state.cleanup_deadline, deadline)
    }
  end

  defp message(state, {:DOWN, ref, :process, _, reason}) do
    if Enum.any?(state.directions, fn {_, direction} -> direction.monitor == ref end),
      do: cancel(state, {:writer_down, reason}),
      else: state
  end

  defp message(state, {:EXIT, writer, reason}) when state.writers_stopped do
    if reason == :normal or
         Enum.any?(state.directions, fn {_, direction} -> direction.writer == writer end),
       do: state,
       else: cancel(state, {:shutdown, reason})
  end

  defp message(state, {:EXIT, _, :normal}), do: state
  defp message(state, {:EXIT, _, reason}), do: cancel(state, {:shutdown, reason})
  defp message(state, _), do: state

  defp wait_if_pending(state) do
    if Enum.all?(state.directions, fn {_, direction} ->
         direction.eof or direction.pending != nil
       end) do
      receive do
        event -> message(state, event)
      after
        min(5, Lifecycle.remaining(state.deadline)) -> state
      end
    else
      state
    end
  end

  defp cancel(state, reason), do: %{state | cancelled: true, reason: reason}

  defp abort_sockets(state) do
    # Independent senders never close a descriptor behind a pending passive
    # receive. On hard failure the receive owner discards uncertain queued output
    # rather than allowing OTP's default close to wait180s for a blocked peer.
    if Socket.secure?(state.socket) do
      :ssl.close(state.socket.socket, 0)
    else
      Socket.setopts(state.socket, linger: {true, 0})
      Socket.close(state.socket)
    end

    Upstream.abort(state.upstream)
  end

  defp stop_writers(directions, deadline) do
    # Uncertain writes are never retried. Confirm child termination before the
    # native owner releases its socket/admission lifecycle. Both children share
    # one absolute budget, and a consumed original DOWN cannot hide termination.
    deadline = min(deadline, Lifecycle.deadline(25))

    confirmations =
      Enum.map(directions, fn {_, %{writer: writer, monitor: monitor}} ->
        confirmation = Process.monitor(writer)
        Process.demonitor(monitor, [:flush])
        {writer, confirmation}
      end)

    Enum.each(confirmations, fn {writer, _} -> Process.exit(writer, :kill) end)

    Enum.reduce(confirmations, :ok, fn {writer, confirmation}, result ->
      receive do
        {:DOWN, ^confirmation, :process, ^writer, _} -> result
      after
        Lifecycle.remaining(deadline) ->
          Process.demonitor(confirmation, [:flush])
          {:error, :writer_down_unconfirmed}
      end
    end)
  end
end
