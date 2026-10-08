defmodule Gaoxy.Service do
  @moduledoc false
  use GenServer, restart: :transient
  alias Gaoxy.{Admission, Telemetry}
  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  @impl true
  def init({table, id, instance}) do
    Process.flag(:trap_exit, true)
    [{^id, spec}] = :ets.lookup(table, id)
    generation = make_ref()
    scope = %{instance: instance, service: id, generation: generation}
    {:ok, _} = Registry.register(Gaoxy.Registry, {instance, id}, generation)
    {:ok, gate} = Admission.start_link({spec.limits, scope})
    context = %{spec: spec, gate: gate, scope: scope}

    result =
      try do
        start_backend(spec, context)
      rescue
        error -> {:error, {:backend_configuration, error.__struct__}}
      catch
        :exit, reason -> {:error, {:backend_start, reason}}
      end

    case result do
      {:ok, backend} ->
        {:ok, _} = Telemetry.bind_backend(backend, scope)
        Telemetry.emit(:lifecycle, %{count: 1}, scope, %{state: :ready})

        {:ok,
         %{
           spec: spec,
           table: table,
           backend: backend,
           gate: gate,
           scope: scope,
           generation: generation,
           mode: :ready,
           drain: nil
         }}

      {:error, reason} ->
        GenServer.stop(gate)
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:request, generation, _}, _, state)
      when not is_nil(generation) and generation != state.generation,
      do: {:reply, {:error, :stale_generation}, state}

  def handle_call({:request, _, :handle}, _, state),
    do: {:reply, %{id: state.spec.id, generation: state.generation}, state}

  def handle_call({:request, _, :info}, _, state),
    do:
      {:reply,
       %{
         id: state.spec.id,
         generation: state.generation,
         transport: state.spec.transport,
         mode: state.mode,
         local: local(state),
         pause:
           case state.spec.transport do
             :udp -> :admission_only
             :quic -> :unsupported
             _ -> :unbind_rebind
           end,
         drain: if(state.spec.transport == :quic, do: :local_host_cleanup, else: :admitted_work)
       }, state}

  def handle_call({:request, _, :status}, _, state),
    do:
      {:reply,
       Map.merge(Admission.status(state.gate), %{
         state: state.mode,
         backend: backend_status(state)
       }), state}

  def handle_call({:request, _, operation}, _, %{mode: mode} = state)
      when operation in [:pause, :resume] and mode in [:draining, :stopped],
      do: {:reply, {:error, mode}, state}

  def handle_call({:request, _, operation}, _, %{spec: %{transport: :quic}} = state)
      when operation in [:pause, :resume],
      do: {:reply, {:error, {:unsupported_capability, :quic_pause}}, state}

  def handle_call({:request, _, :pause}, _, state) do
    :ok = Admission.mode(state.gate, :paused)
    host = if state.spec.transport == :udp, do: Abyss, else: ThousandIsland

    case host.suspend(state.backend) do
      :ok -> {:reply, :ok, transition(state, :paused)}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:request, _, :resume}, _, state) do
    host = if state.spec.transport == :udp, do: Abyss, else: ThousandIsland

    case host.resume(state.backend) do
      :ok ->
        Admission.mode(state.gate, :ready)
        {:reply, :ok, transition(state, :ready)}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:request, _, :memberships}, _, state),
    do: {:reply, membership_list(state), state}

  def handle_call({:request, _, {:membership, operation, membership}}, _, state) do
    result = membership_change(state, operation, membership)

    if result == :ok do
      spec = put_in(state.spec, [:udp, :memberships], Abyss.memberships(state.backend))
      :ets.insert(state.table, {spec.id, spec})
      {:reply, :ok, %{state | spec: spec}}
    else
      {:reply, result, state}
    end
  end

  def handle_call({:drain, generation, timeout}, from, state)
      when generation == state.generation and is_nil(state.drain) do
    :ok = Admission.mode(state.gate, :draining)
    deadline = System.monotonic_time(:millisecond) + timeout
    owner = self()
    backend = state.backend
    host = host(state)
    # Only control work is spawned. Datagram processing never creates rejected-work tasks.
    {pid, monitor} =
      spawn_monitor(fn ->
        result =
          if host in [Abyss, Abyss.QUIC] do
            host.stop(backend, max(0, deadline - System.monotonic_time(:millisecond)))
          else
            ThousandIsland.suspend(backend)
            send(owner, {:tcp_admission_stopped, self()})

            receive do
              :close_backend -> Supervisor.stop(backend, :normal, :infinity)
            end
          end

        send(owner, {:drained, self(), result})
      end)

    token = make_ref()
    timer = Process.send_after(self(), {:drain_deadline, token}, timeout)
    if host not in [Abyss, Abyss.QUIC], do: send(self(), :check_drain)

    drain = %{
      pid: pid,
      monitor: monitor,
      from: from,
      timer: timer,
      token: token,
      deadline: deadline
    }

    {:noreply, %{transition(state, :draining) | drain: drain}}
  end

  def handle_call({:drain, _, _}, _, state),
    do: {:reply, {:error, :already_draining_or_stale}, state}

  @impl true
  def handle_info(:check_drain, %{drain: nil} = state), do: {:noreply, state}

  def handle_info(:check_drain, state) do
    if Admission.status(state.gate).active == 0 do
      send(state.drain.pid, :close_backend)
    else
      Process.send_after(self(), :check_drain, 5)
    end

    {:noreply, state}
  end

  def handle_info({:drained, pid, :ok}, %{drain: %{pid: pid}} = state),
    do: finish_drain(state, :completed)

  def handle_info({:drain_deadline, token}, %{drain: %{token: token}} = state) do
    Process.exit(state.backend, :kill)
    Process.exit(state.drain.pid, :kill)
    finish_drain(state, :forced)
  end

  def handle_info({:EXIT, pid, _}, %{backend: pid, mode: mode} = state)
      when mode in [:draining, :stopped], do: {:noreply, state}

  def handle_info({:EXIT, pid, reason}, state) when pid == state.backend or pid == state.gate,
    do: {:stop, {:backend_failed, reason}, state}

  def handle_info({:DOWN, monitor, :process, _pid, reason}, %{drain: %{monitor: monitor}} = state)
      when reason != :normal,
      do: finish_drain(state, {:cleanup_error, reason})

  def handle_info(_, state), do: {:noreply, state}
  @impl true
  def terminate(_, state) do
    if state.drain, do: Process.exit(state.drain.pid, :kill)
    if Process.alive?(state.gate), do: GenServer.stop(state.gate)

    if Process.alive?(state.backend) do
      try do
        Supervisor.stop(state.backend, :normal, 1_000)
      catch
        :exit, _ -> Process.exit(state.backend, :kill)
      end
    end
  end

  defp finish_drain(state, outcome) do
    Process.cancel_timer(state.drain.timer)
    GenServer.reply(state.drain.from, :ok)
    Telemetry.emit(:drain, %{count: 1}, state.scope, %{outcome: outcome})
    {:noreply, %{transition(state, :stopped) | drain: nil}}
  end

  defp transition(state, mode) do
    Telemetry.emit(:lifecycle, %{count: 1}, state.scope, %{state: mode})
    %{state | mode: mode}
  end

  defp host(%{spec: %{transport: :udp}}), do: Abyss
  defp host(%{spec: %{transport: :quic}}), do: Abyss.QUIC
  defp host(_), do: ThousandIsland
  defp local(%{mode: :stopped}), do: {:error, :stopped}
  defp local(%{spec: %{transport: :quic}} = state), do: Abyss.QUIC.local(state.backend)

  defp local(%{spec: %{transport: :udp}} = state) do
    case Abyss.Listener.for_server(state.backend) do
      [listener] -> Abyss.Listener.listener_info(listener)
      _ -> {:error, :not_ready}
    end
  end

  defp local(state), do: ThousandIsland.listener_info(state.backend)
  defp backend_status(%{mode: :stopped}), do: :stopped
  defp backend_status(%{spec: %{transport: :quic}}), do: :quic_connection_host

  defp backend_status(%{spec: %{transport: :udp}} = state) do
    case Abyss.Listener.for_server(state.backend) do
      [listener] -> Abyss.Listener.status(listener)
      _ -> :not_ready
    end
  end

  defp backend_status(_), do: :stream

  defp membership_list(%{spec: %{transport: :udp, mode: :multicast}} = state),
    do: Abyss.memberships(state.backend)

  defp membership_list(_), do: {:error, {:unsupported_capability, :memberships}}

  defp membership_change(
         %{spec: %{transport: :udp, mode: :multicast}, mode: mode} = state,
         operation,
         membership
       )
       when mode in [:ready, :paused] do
    with true <-
           Gaoxy.Config.valid_membership?(membership, state.spec.ip) ||
             {:error, :invalid_membership},
         {:ok, canonical} <- Abyss.Transport.UDP.Multicast.normalize_membership(membership) do
      current = Abyss.memberships(state.backend)

      if operation == :join and canonical not in current and
           length(current) >= state.spec.limits.max_memberships do
        {:error, :membership_limit}
      else
        apply(Abyss, operation, [state.backend, membership])
      end
    end
  end

  defp membership_change(_, _, _), do: {:error, {:unsupported_capability, :memberships}}

  defp start_backend(%{transport: :udp} = spec, context) do
    transport =
      case spec.mode do
        :unicast -> Abyss.Transport.UDP.Unicast
        :broadcast -> Abyss.Transport.UDP.Broadcast
        :multicast -> Abyss.Transport.UDP.Multicast
      end

    options =
      Enum.map(Map.get(spec.udp, :memberships, []), &{:add_membership, &1}) ++
        Map.to_list(Map.drop(spec.udp, [:memberships, :inet_backend]))

    options = [
      {:inet_backend, Map.get(spec.udp, :inet_backend, :inet)},
      if(tuple_size(spec.ip) == 8, do: :inet6, else: :inet),
      {:ip, spec.ip} | options
    ]

    Abyss.start_link(
      handler_module: Gaoxy.DatagramBridge,
      handler_options: context,
      port: spec.port,
      transport_module: transport,
      transport_options: options,
      num_listeners: 1,
      num_connections: spec.limits.max_active,
      max_packet_size: spec.limits.max_packet,
      admission_start_timeout: spec.limits.callback_timeout,
      read_timeout: spec.limits.idle_timeout,
      shutdown_timeout: spec.limits.drain_timeout,
      connection_telemetry_sample_rate: 1.0
    )
  end

  defp start_backend(%{transport: :quic} = spec, context) do
    with {:ok, tls} <- quic_credentials(spec.tls) do
      Abyss.QUIC.start_link(
        handler: {Gaoxy.QUICBridge, context},
        ip: spec.ip,
        port: spec.port,
        alpn: spec.quic.alpn,
        tls: tls,
        max_connections: spec.limits.max_active,
        init_timeout: spec.limits.callback_timeout,
        callback_timeout: spec.limits.callback_timeout,
        shutdown_timeout: spec.limits.drain_timeout,
        writer_timeout: spec.limits.callback_timeout,
        writer_max_queue: spec.limits.max_active,
        writer_max_bytes: spec.limits.max_bytes,
        quic_options: [
          streams: [
            max_data: spec.limits.max_bytes,
            max_stream_data: spec.limits.max_bytes,
            max_buffer: spec.limits.max_bytes,
            max_ready_bytes: spec.limits.max_bytes,
            max_streams_bidi: spec.limits.max_active,
            max_streams_uni: spec.limits.max_active,
            # The engine reserves both peer quotas before allocating local streams.
            max_stream_records: spec.limits.max_active * 3,
            max_recv_ranges: 128
          ]
        ]
      )
    end
  end

  defp start_backend(spec, context) do
    tls =
      if spec.transport == :tls do
        [
          certfile: spec.tls.certfile,
          keyfile: spec.tls.keyfile,
          versions: Map.get(spec.tls, :versions, [:"tlsv1.3"]),
          alpn_preferred_protocols: Map.get(spec.tls, :alpn, [])
        ]
      else
        []
      end

    ThousandIsland.start_link(
      handler_module: Gaoxy.StreamBridge,
      handler_options: context,
      port: spec.port,
      transport_module:
        if(spec.transport == :tls,
          do: ThousandIsland.Transports.SSL,
          else: ThousandIsland.Transports.TCP
        ),
      transport_options: [
        if(tuple_size(spec.ip) == 8, do: :inet6, else: :inet),
        {:ip, spec.ip},
        {:send_timeout, spec.limits.callback_timeout},
        {:send_timeout_close, true} | tls
      ],
      num_acceptors: 1,
      num_connections: spec.limits.max_active,
      max_connections_retry_count: 0,
      read_timeout: spec.limits.idle_timeout,
      handshake_timeout: spec.limits.callback_timeout,
      shutdown_timeout: spec.limits.drain_timeout
    )
  end

  defp quic_credentials(tls) do
    with {:ok, certificate} <- File.read(tls.certfile),
         {:ok, key} <- File.read(tls.keyfile),
         certificates when certificates != [] <-
           for(
             {:Certificate, der, :not_encrypted} <- :public_key.pem_decode(certificate),
             do: der
           ),
         [{type, der, :not_encrypted}] <- :public_key.pem_decode(key) do
      {:ok, [cert: certificates, key: {type, der}]}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_quic_credentials}
    end
  end
end
