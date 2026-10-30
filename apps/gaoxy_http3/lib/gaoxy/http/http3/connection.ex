defmodule Gaoxy.HTTP.HTTP3.Connection do
  @moduledoc false
  @behaviour Gaoxy.QUICHandler
  alias Gaoxy.{Admission, Lifecycle, QUIC}
  alias Gaoxy.HTTP.Exchange
  alias Gaoxy.HTTP.HTTP3.{Headers, Operations, Protocol, Stream, Transport}
  alias QuicHttp3.{Control, Frame, Qpack}

  @impl true
  def init(
        connection,
        metadata,
        %{endpoint: {Gaoxy.HTTP3Fixture.Endpoint, %{profile: :minimal} = fixture}} = options
      ) do
    initialize(connection, metadata, options, fixture)
  end

  def init(connection, metadata, %{endpoint: {module, _}} = options) when is_atom(module),
    do: initialize(connection, metadata, options, nil)

  defp initialize(connection, metadata, options, fixture) do
    # Canonical workers link this GenServer owner. A request-local kill must not
    # terminate its siblings; GenServer still handles its parent shutdown exit.
    Process.flag(:trap_exit, true)

    with {:ok, protocol} <- Protocol.new(options) do
      if fixture != nil and is_pid(fixture[:observer]),
        do: send(fixture.observer, {:http3_fixture_connection, fixture[:id], connection.gate})

      {:ok,
       %{
         connection: connection,
         options: options,
         metadata: metadata,
         protocol: protocol,
         operations: if(fixture == nil, do: Operations.new()),
         ready: false,
         control: nil,
         control_bytes: Control.local_payload(protocol.control),
         control_deadline: nil,
         streams: %{},
         order: :queue.new(),
         pending: %{},
         closed: false,
         idle_deadline: nil,
         keepalive: nil,
         turn_deadline: nil
       }}
    end
  end

  @impl true
  def handle_event({:ready, metadata}, state) do
    cond do
      metadata[:alpn] != "h3" ->
        {:stop, :unsupported_http3_alpn, state}

      metadata[:tls_complete] != true or metadata[:parameters_valid] != true ->
        {:stop, :http3_not_authenticated, state}

      true ->
        progress(%{state | ready: true, metadata: metadata, idle_deadline: nil})
    end
  end

  def handle_event({:stream_open, key, :uni}, %{control: key} = state), do: {:ok, state}

  def handle_event({:stream_open, key, kind}, state) do
    if map_size(state.streams) >= 2 * state.options.h3_limits.max_streams + 4 do
      fail(state, 0x107, :owner_stream_limit)
    else
      entry = %{
        kind: kind,
        request: nil,
        mode: nil,
        input: <<>>,
        trailers: [],
        token: nil,
        worker: nil,
        lease: nil,
        startup: nil,
        admission: :none,
        spawn_cancel: nil,
        resources_operation: make_ref(),
        resources_identity: nil,
        resources_terminal: false,
        stream_terminal: false,
        retiring: false,
        operation: nil,
        worker_finished: false,
        response_phase: :unset,
        abort_pending: false,
        out: <<>>,
        send_fin: false,
        send_done: false,
        recv_fin: false,
        fin_pending: false,
        cancel: [],
        cancel_deadline: nil,
        deadline: now() + state.options.http_limits.request_timeout,
        header_deadline: now() + state.options.http_limits.header_timeout,
        output_deadline: nil,
        work_deadline: if(kind == :uni, do: now() + state.options.http_limits.header_timeout),
        write_quantum:
          min(state.connection.limits.max_output, state.options.h3_limits.control_quantum)
      }

      state = %{
        state
        | streams: Map.put(state.streams, key, entry),
          order: :queue.in(key, state.order)
      }

      requests = Enum.count(state.streams, fn {_, stream} -> stream.kind == :bidi end)

      if kind == :bidi and requests > state.options.h3_limits.max_streams,
        do: {:ok, cancel(state, key, 0x107)},
        else: transition(state, key, Protocol.open(state.protocol, key, kind))
    end
  end

  def handle_event({:stopped, key, _code}, %{control: key} = state),
    do: fail(state, 0x104, :closed_local_control)

  def handle_event({:stopped, key, code}, state), do: peer_cancel(state, key, code)

  def handle_event({:closed, _}, state), do: {:stop, :normal, clear(state)}
  def handle_event(event, state) when event in [:tick, :writable], do: progress(state)
  def handle_event({:readable, _}, state), do: progress(%{state | idle_deadline: nil})
  def handle_event(_, state), do: {:ok, state}

  @impl true
  def terminate(_, state) do
    settle_local_workers(state)
    _ = clear(state)
    :ok
  end

  # The host is already terminating. Revoke local operation capabilities first
  # so a worker finishing a response can observe cancellation and exit normally
  # before the parent's terminal pair forces remaining children. This is local
  # cleanup only: no new writes, peer drain or request-deadline extension.
  defp settle_local_workers(%{operations: nil}), do: :ok

  defp settle_local_workers(state) do
    deadline = now() + min(50, state.connection.limits.callback_timeout)

    monitors =
      for {key, %{worker: worker, token: token}} <- state.streams,
          is_pid(worker),
          token != nil,
          Process.alive?(worker) do
        monitor = Process.monitor(worker)
        _ = Operations.cancel(state.operations, key, token, :closed)
        _ = Operations.remove(state.operations, key, token)
        {worker, monitor, min(deadline, terminal_deadline(state.streams[key]))}
      end

    Enum.each(monitors, fn {worker, monitor, deadline} ->
      receive do
        {:DOWN, ^monitor, :process, ^worker, _} -> :ok
      after
        Lifecycle.remaining(deadline) -> :ok
      end

      Process.demonitor(monitor, [:flush])
    end)
  end

  defp progress(%{ready: false} = state), do: {:ok, state}
  defp progress(%{closed: true} = state), do: {:stop, :normal, state}

  defp progress(state) do
    state = %{state | turn_deadline: now() + min(100, state.connection.limits.callback_timeout)}

    with {:ok, state} <- persistent_connection(state),
         {:ok, state} <- keepalive(state),
         {:ok, state} <- control(state) do
      if state.control == nil or state.control_bytes != <<>>,
        do: {:ok, state},
        # A small set of streams can still have several ready quanta. Spend the
        # existing round-robin turn budget instead of waiting another host poll
        # after one pass. The same turn count and absolute callback bound apply.
        else: turns(state, state.options.h3_limits.control_turn)
    end
  end

  # This is an idle policy for an empty HTTP/3 connection. Active requests and
  # their cleanup retain their own finite operation deadlines. It does not
  # replace QUIC's packet-level idle accounting.
  @doc false
  def persistence(state, at) do
    requests = Enum.any?(state.streams, fn {_, entry} -> entry.kind == :bidi end)

    idle_deadline =
      if requests, do: nil, else: state.idle_deadline || at + state.connection.limits.idle_timeout

    state = %{state | idle_deadline: idle_deadline}

    cond do
      idle_deadline != nil and at >= idle_deadline ->
        {:error, :idle_timeout, state}

      websocket_active?(state) ->
        case get_in(state.metadata, [:idle_timeout, :peer_ms]) do
          :infinity ->
            {:ok, %{state | keepalive: nil}}

          interval when is_integer(interval) and interval > 0 ->
            interval = max(1, div(interval, 3))

            keepalive =
              state.keepalive || %{interval: interval, next: at + interval, deadline: nil}

            {:ok, %{state | keepalive: keepalive}}

          _ ->
            {:error, :missing_peer_idle_policy, state}
        end

      Map.has_key?(state.pending, :websocket_keepalive) ->
        {:ok, state}

      true ->
        {:ok, %{state | keepalive: nil}}
    end
  end

  defp websocket_active?(state) do
    Enum.any?(state.streams, fn {_, entry} ->
      entry.mode in [:websocket_opening, :websocket] and entry.cancel == []
    end)
  end

  defp persistent_connection(state) do
    case persistence(state, now()) do
      {:ok, state} -> {:ok, state}
      {:error, reason, state} -> fail(state, 0x100, reason)
    end
  end

  defp keepalive(%{keepalive: nil} = state), do: {:ok, state}

  defp keepalive(state) do
    keepalive = state.keepalive

    if now() < keepalive.next do
      {:ok, state}
    else
      deadline =
        keepalive.deadline ||
          now() + min(keepalive.interval, state.options.http_limits.write_timeout)

      state = %{state | keepalive: %{keepalive | deadline: deadline}}

      case operation(state, :websocket_keepalive, deadline, &QUIC.ping(state.connection, &1)) do
        {:ok, state, {:ok, _reference}} ->
          keepalive =
            if websocket_active?(state),
              do: %{keepalive | next: now() + keepalive.interval, deadline: nil},
              else: nil

          {:ok, %{state | keepalive: keepalive}}

        {:ok, state, {:blocked, _}} ->
          {:ok, state}

        {:wait, state} ->
          {:ok, state}

        {:ok, state, failure} ->
          fail(state, 0x102, {:websocket_keepalive, failure})

        failure ->
          failure
      end
    end
  end

  defp control(%{control: nil} = state) do
    deadline = state.control_deadline || now() + state.options.http_limits.write_timeout
    state = %{state | control_deadline: deadline}

    case operation(state, :open_control, deadline, fn opts ->
           QUIC.open_stream(state.connection, :uni, opts)
         end) do
      {:ok, state, {:ok, handle}} ->
        stream =
          case handle do
            %QUIC.Stream{} = stream -> stream
            opaque -> %QUIC.Stream{handle: opaque, connection: state.connection}
          end

        # The engine may enqueue local open before an uncertain result resolves.
        # Remove that provisional peer entry before any destructive stream read.
        state = drop(state, stream)

        state = %{
          state
          | protocol: %{state.protocol | streams: Map.delete(state.protocol.streams, stream)}
        }

        control(%{state | control: stream})

      {:wait, state} ->
        {:ok, state}

      {:ok, state, {:blocked, _}} ->
        {:ok, state}

      {:ok, state, failure} ->
        fail(state, 0x102, {:control_open, failure})

      failure ->
        failure
    end
  end

  defp control(%{control_bytes: <<>>} = state), do: {:ok, state}

  defp control(state) do
    case operation(state, :control_write, state.control_deadline, fn opts ->
           QUIC.send_stream(state.control, state.control_bytes, false, opts)
         end) do
      {:ok, state, {:ok, _}} -> {:ok, %{state | control_bytes: <<>>, control_deadline: nil}}
      {:wait, state} -> {:ok, state}
      {:ok, state, {:blocked, _}} -> {:ok, state}
      {:ok, state, failure} -> fail(state, 0x102, {:control_write, failure})
      failure -> failure
    end
  end

  defp turns(state, remaining) when remaining <= 0, do: {:ok, state}

  defp turns(state, remaining) do
    if now() >= state.turn_deadline do
      {:ok, state}
    else
      case :queue.out(state.order) do
        {:empty, _} ->
          {:ok, state}

        {{:value, key}, rest} ->
          state = %{state | order: rest}

          if Map.has_key?(state.streams, key) do
            case stream_turn(state, key) do
              {:ok, next} ->
                next =
                  if Map.has_key?(next.streams, key),
                    do: %{next | order: :queue.in(key, next.order)},
                    else: next

                turns(next, remaining - 1)

              failure ->
                failure
            end
          else
            turns(state, remaining - 1)
          end
      end
    end
  end

  defp stream_turn(state, key) do
    entry = state.streams[key]

    cond do
      entry.retiring ->
        if Lifecycle.remaining(terminal_deadline(entry)) == 0,
          do: fail(state, 0x102, :stream_cleanup_timeout),
          else: {:ok, drop(state, key)}

      entry.cancel != [] ->
        cleanup_stream(state, key)

      entry.kind == :uni and entry.work_deadline != nil and now() >= entry.work_deadline ->
        fail(state, 0x107, :incomplete_uni_timeout)

      entry.kind == :bidi and Lifecycle.remaining(entry.deadline) == 0 ->
        cleanup_stream(cancel(state, key, 0x10C), key)

      entry.kind == :bidi and entry.request == nil and now() >= entry.header_deadline ->
        cleanup_stream(cancel(state, key, 0x10C), key)

      true ->
        with {:ok, state} <- endpoint_turn(state, key),
             {:ok, state} <- flush(state, key),
             {:ok, state} <- receive_stream(state, key),
             {:ok, state} <- flush(state, key),
             {:ok, state} <- complete_output(state, key),
             {:ok, state} <- websocket_delivery(state, key),
             do: {:ok, observe(retire(resource_terminal(state, key), key))}
    end
  end

  @doc false
  def receive_stream(state, key) do
    case state.streams[key] do
      nil ->
        {:ok, state}

      %{cancel: [_ | _]} ->
        {:ok, state}

      %{recv_fin: true} ->
        {:ok, state}

      entry ->
        # Preserve the exact write completion while its admission is uncertain.
        # Reserve one read quantum plus DATA framing before consuming application bytes.
        credit = receive_credit(state, key)

        if Map.has_key?(state.pending, {key, :write}) or
             (state.operations == nil and entry.kind == :bidi and
                credit < state.options.http_limits.max_read_chunk) do
          {:ok, state}
        else
          before = state.protocol.streams[key]

          with {:ok, state} <- transition(state, key, Protocol.feed(state.protocol, key, <<>>)) do
            after_feed = state.protocol.streams[key]

            cond do
              state.streams[key] == nil or state.streams[key].cancel != [] ->
                {:ok, state}

              before != after_feed ->
                {:ok, state}

              entry.fin_pending ->
                finish_receive(state, key)

              entry.kind == :bidi and credit <= 0 ->
                {:ok, state}

              true ->
                read_stream(state, key, min(credit, state.options.http_limits.max_read_chunk))
            end
          end
        end
    end
  end

  defp read_stream(state, key, maximum) do
    deadline = now() + state.options.http_limits.read_timeout

    deadline =
      if state.operations != nil and state.streams[key].kind == :bidi,
        do: Lifecycle.earlier(state.streams[key].deadline, deadline),
        else: deadline

    case operation(state, {key, :read}, deadline, fn opts -> QUIC.read(key, maximum, opts) end) do
      {:ok, state, {:ok, items}} ->
        Enum.reduce_while(items, {:ok, state}, fn item, {:ok, acc} ->
          case read_item(acc, key, item) do
            {:ok, next} -> {:cont, {:ok, next}}
            failure -> {:halt, failure}
          end
        end)

      {:wait, state} ->
        {:ok, state}

      {:ok, state, {:blocked, _}} ->
        {:ok, state}

      {:ok, state, {:error, :not_established}} ->
        {:stop, :normal, clear(state)}

      {:ok, state, {:error, :invalid_operation}} ->
        {:stop, :normal, clear(state)}

      {:ok, state, failure} ->
        fail(state, 0x102, {:read, failure})

      failure ->
        failure
    end
  end

  defp read_item(state, key, {:data, _id, bytes}) do
    if state.streams[key] == nil or state.streams[key].cancel != [],
      do: {:ok, state},
      else: transition(state, key, Protocol.feed(state.protocol, key, bytes))
  end

  defp read_item(state, key, {:fin, _id}) do
    {:ok, update_entry(state, key, &%{&1 | fin_pending: true})}
  end

  defp read_item(state, key, {:reset, _id, code, _final_size}),
    do: peer_cancel(state, key, code)

  defp finish_receive(state, key) do
    with {:ok, state} <- transition(state, key, Protocol.fin(state.protocol, key)) do
      {:ok, update_entry(state, key, &%{&1 | recv_fin: true, fin_pending: false})}
    end
  end

  defp transition(state, key, {:ok, protocol, actions}) do
    next =
      Enum.reduce(actions, %{state | protocol: protocol}, fn action, acc ->
        {:ok, next} = action(acc, action)
        next
      end)

    {:ok, work_deadline(next, key)}
  end

  defp transition(state, key, {:error, :stream, code, _reason, protocol}),
    do: {:ok, cancel(%{state | protocol: protocol}, key, code)}

  defp transition(state, _, {:error, :connection, code, reason, protocol}),
    do: fail(%{state | protocol: protocol}, code, reason)

  defp action(%{operations: nil} = state, {:headers, key, request}) do
    {status, body, mode} =
      case {request.method, request.path} do
        {"GET", "/ok"} -> {200, "ok", :discard}
        {"HEAD", "/ok"} -> {200, <<>>, :discard}
        {"POST", "/echo"} -> {200, <<>>, :echo}
        {"CONNECT", _} -> {501, <<>>, :discard}
        _ -> {404, <<>>, :discard}
      end

    {:ok, block} = Qpack.encode_header_block([{":status", Integer.to_string(status)}])
    bytes = Frame.encode!(:headers, block)
    bytes = if body == <<>>, do: bytes, else: bytes <> Frame.encode!(:data, body)

    state =
      update_entry(state, key, &%{&1 | request: request, mode: mode, send_fin: mode != :echo})

    enqueue(state, key, bytes)
  end

  defp action(state, {:headers, key, request}), do: start_endpoint(state, key, request)

  defp action(%{operations: table} = state, {:data, key, bytes}) when table != nil do
    entry = state.streams[key]

    if byte_size(entry.input) + byte_size(bytes) <= state.options.http_limits.max_buffer_bytes,
      do: {:ok, update_entry(state, key, &%{&1 | input: &1.input <> bytes})},
      else: {:ok, cancel(state, key, 0x107)}
  end

  defp action(state, {:data, key, bytes}) do
    if state.streams[key].mode == :echo,
      do: enqueue(state, key, Frame.encode!(:data, bytes)),
      else: {:ok, state}
  end

  defp action(%{operations: table} = state, {:trailers, key, fields}) when table != nil,
    do: {:ok, update_entry(state, key, &%{&1 | trailers: fields})}

  defp action(state, {:trailers, key, fields}) do
    if state.streams[key].mode == :echo do
      {:ok, block} = Qpack.encode_header_block(fields)
      enqueue(state, key, Frame.encode!(:headers, block))
    else
      {:ok, state}
    end
  end

  defp action(%{operations: table} = state, {:complete, _key}) when table != nil,
    do: {:ok, state}

  defp action(state, {:complete, key}),
    do:
      {:ok,
       update_entry(
         state,
         key,
         &%{
           &1
           | send_fin: true,
             output_deadline:
               &1.output_deadline || now() + state.options.http_limits.write_timeout
         }
       )}

  defp action(state, {:cancelled, key}), do: {:ok, cancel(state, key, 0x10C)}
  defp action(state, {:discard, key}), do: {:ok, cancel(state, key, 0x100, [:stop])}
  defp action(state, {:settings, _}), do: {:ok, state}
  defp action(state, {:goaway, _}), do: {:ok, state}

  defp enqueue(state, key, bytes) do
    entry = state.streams[key]

    if byte_size(entry.out) + byte_size(bytes) <= state.options.h3_limits.max_pending_output do
      {:ok,
       update_entry(
         state,
         key,
         &%{
           &1
           | out: &1.out <> bytes,
             output_deadline:
               &1.output_deadline || now() + state.options.http_limits.write_timeout
         }
       )}
    else
      {:ok, cancel(state, key, 0x107)}
    end
  end

  defp receive_credit(%{operations: nil} = state, key),
    do: state.options.h3_limits.max_pending_output - byte_size(state.streams[key].out) - 32

  defp receive_credit(state, key) do
    entry = state.streams[key]
    parser = state.protocol.streams[key]
    buffered = if parser == nil, do: 0, else: byte_size(parser.buffer)

    state.options.http_limits.max_buffer_bytes - byte_size(entry.input) - buffered -
      delivered_bytes(state, key, entry)
  end

  defp delivered_bytes(state, key, entry) do
    case Operations.status(state.operations, key, entry.token) do
      {:ok, %{demand: {:delivered, _, bytes}}} -> bytes
      _ -> 0
    end
  end

  defp websocket_delivery(state, key) do
    case state.streams[key] do
      %{mode: :websocket, token: token} = entry ->
        case Operations.status(state.operations, key, token) do
          {:ok, %{demand: {:pending, ref, credit}}} when entry.input != <<>> or entry.recv_fin ->
            size = min(credit, byte_size(entry.input))
            <<bytes::binary-size(^size), rest::binary>> = entry.input
            ended = entry.recv_fin and rest == <<>>

            case Operations.deliver(state.operations, key, token, ref, bytes, ended) do
              :ok -> {:ok, update_entry(state, key, &%{&1 | input: rest})}
              _ -> {:ok, cancel(state, key, 0x10C)}
            end

          _ ->
            {:ok, state}
        end

      _ ->
        {:ok, state}
    end
  end

  defp start_endpoint(state, key, request) do
    token = make_ref()
    state = update_entry(state, key, &%{&1 | request: request, token: token})
    entry = state.streams[key]
    gate = state.connection.gate

    with :ok <-
           Operations.register(
             state.operations,
             key,
             token,
             entry.deadline,
             state.options.http_limits
           ),
         parent when is_reference(parent) <- Map.get(state.connection, :lease) do
      bytes = Exchange.retained_bytes(exchange(state, key, nil))

      startup =
        Admission.spawn_request(
          gate,
          parent,
          token,
          bytes,
          entry.deadline,
          {Stream, :run_admitted, [self(), state.operations, token, gate, entry.deadline]},
          [kind: :h3_stream, memberships: %{request: token, h3_stream: {parent, token}}],
          :phase_receipt
        )

      state = update_entry(state, key, &%{&1 | startup: startup, admission: :pending})
      # The normal local receipt is immediate; retain its exact alias when the
      # canonical mutation takes longer than this bounded owner turn.
      {:ok, startup_turn(state, key, min(50, Lifecycle.remaining(entry.deadline)))}
    else
      _ ->
        _ = Operations.remove(state.operations, key, token)
        {:ok, cancel(state, key, 0x107)}
    end
  catch
    :exit, _ -> {:ok, cancel(state, key, 0x107)}
  end

  defp startup_turn(state, key, wait \\ 0) do
    case state.streams[key] do
      %{startup: startup} = entry when startup != nil ->
        case :gen_server.wait_response(startup, wait) do
          {:reply, {:ok, worker, lease}} when is_pid(worker) and is_reference(lease) ->
            state =
              update_entry(
                state,
                key,
                &%{&1 | startup: nil, admission: :admitted, worker: worker, lease: lease}
              )

            if entry.cancel != [] or entry.retiring or Lifecycle.remaining(entry.deadline) == 0 do
              Process.exit(worker, :kill)
              state
            else
              case Operations.bind(state.operations, key, entry.token, worker) do
                :ok ->
                  send(worker, {:h3_start, self(), entry.token})
                  state

                _ ->
                  cancel(state, key, 0x107)
              end
            end

          {:reply, {:error, {:not_reserved, token, :deadline_exceeded}}}
          when token == entry.token ->
            state = update_entry(state, key, &%{&1 | startup: nil, admission: :not_reserved})
            if entry.cancel != [] or entry.retiring, do: state, else: cancel(state, key, 0x107)

          :timeout ->
            state

          _ ->
            state = update_entry(state, key, &%{&1 | startup: nil, admission: :rejected})
            if entry.cancel != [] or entry.retiring, do: state, else: cancel(state, key, 0x107)
        end

      _ ->
        state
    end
  end

  defp endpoint_turn(%{operations: nil} = state, _), do: {:ok, state}

  defp endpoint_turn(state, key) do
    state = startup_turn(state, key)

    case state.streams[key] do
      %{token: nil} ->
        {:ok, state}

      %{cancel: [_ | _]} ->
        {:ok, state}

      %{admission: :pending} ->
        {:ok, state}

      %{token: token, worker: worker} = entry ->
        case Operations.status(state.operations, key, token) do
          {:ok, %{worker: ^worker, lease: lease, status: :ready}} ->
            if Process.alive?(worker) and
                 Operations.activate(state.operations, key, token, worker) == :ok do
              exchange = exchange(state, key, lease)
              send(worker, {:h3_dispatch, self(), key, token, exchange, state.options.endpoint})
              {:ok, update_entry(state, key, &%{&1 | lease: lease})}
            else
              {:ok, cancel(state, key, 0x107)}
            end

          {:ok, %{status: {:finished, {:error, :endpoint_failed}}}} ->
            {:ok, cancel(state, key, 0x10C)}

          {:ok, %{status: {:finished, _}}} ->
            if entry.send_done,
              do: {:ok, update_entry(state, key, &%{&1 | worker_finished: true})},
              else: {:ok, cancel(state, key, 0x102)}

          {:ok, %{status: {:cancelled, _, _}}} ->
            {:ok, cancel(state, key, 0x10C)}

          {:ok, %{worker: ^worker}} ->
            if Process.alive?(worker),
              do: claim_operation(state, key),
              else: {:ok, cancel(state, key, 0x102)}

          _ ->
            {:ok, cancel(state, key, 0x102)}
        end
    end
  end

  @doc false
  def exchange(state, key, lease) do
    entry = state.streams[key]
    request = %{entry.request | peer: state.metadata[:remote], local: state.metadata[:local]}
    ended = entry.recv_fin and entry.input == <<>>
    trailers = if ended, do: entry.trailers, else: []
    limits = Map.put(state.options.http_limits, :max_write_chunk, 16_384)

    limits =
      if request.protocol == "websocket" do
        Map.put(limits, :extended_connect, state.options.extended_connect)
      else
        limits
      end

    %Exchange{
      request: request,
      gate: state.connection.gate,
      lease: lease,
      deadline: entry.deadline,
      limits: limits,
      body: %{
        phase: if(ended, do: :done, else: :data),
        total: 0,
        trailers: trailers,
        trailer_bytes: Headers.bytes(trailers)
      },
      buffer: <<>>,
      transport: Transport,
      transport_state: {self(), state.operations, key, entry.token},
      peer: state.metadata[:remote],
      local: state.metadata[:local],
      secure: true,
      ssl: nil,
      peer_cert: nil,
      service: Map.get(state.connection, :service),
      instance: Map.get(state.connection, :instance),
      protocol_bytes:
        :erlang.external_size(
          {state.metadata, limits, {self(), state.operations, key, entry.token}}
        ) +
          :erlang.external_size(%{request | headers: [], head_bytes: 0})
    }
  end

  defp claim_operation(state, key) do
    entry = state.streams[key]

    if entry.operation == nil do
      case Operations.claim(state.operations, key, entry.token) do
        {:ok, worker, ref, operation, deadline} when worker == entry.worker ->
          state = update_entry(state, key, &%{&1 | operation: {ref, operation, deadline}})
          prepare_operation(state, key, operation, deadline)

        :idle ->
          if entry.abort_pending,
            do: {:ok, cancel(state, key, 0x10C)},
            else: {:ok, state}

        _ ->
          {:ok, cancel(state, key, 0x10C)}
      end
    else
      {_, operation, deadline} = entry.operation

      if elem(operation, 0) in [:head, :data, :trailers] and now() >= deadline and
           not Map.has_key?(state.pending, {key, :write}),
         do: {:ok, cancel(state, key, 0x10C)},
         else: {:ok, state}
    end
  end

  defp prepare_operation(state, key, {:head, status, fields, ended}, deadline) do
    entry = state.streams[key]

    if entry.response_phase != :final and (status >= 200 or not ended) do
      with :ok <-
             Headers.response(
               fields,
               state.options.http_limits.max_headers,
               state.options.http_limits.max_header_bytes
             ),
           {:ok, block} <-
             Qpack.encode_header_block([{":status", Integer.to_string(status)} | fields]) do
        state =
          update_entry(
            state,
            key,
            &%{&1 | response_phase: if(status < 200, do: :informational, else: :final)}
          )

        output_operation(state, key, Frame.encode!(:headers, block), ended, deadline)
      else
        _ -> {:ok, cancel(state, key, 0x102)}
      end
    else
      {:ok, cancel(state, key, 0x102)}
    end
  end

  defp prepare_operation(state, key, {:websocket_open, fields, lifetime}, deadline) do
    entry = state.streams[key]
    {ref, _, _} = entry.operation

    valid =
      state.options.extended_connect and entry.mode == nil and
        entry.response_phase in [:unset, :informational] and not entry.recv_fin and
        entry.trailers == [] and Lifecycle.remaining(entry.deadline) != 0 and
        Lifecycle.remaining(lifetime) != 0

    with true <- valid,
         {:ok, ^fields} <- Gaoxy.HTTP.WebSocket.ExtendedHandshake.headers(entry.request, fields),
         {:ok, protocol} <- Protocol.websocket_open(state.protocol, key),
         :ok <- Operations.upgrade(state.operations, key, entry.token, ref, lifetime) do
      state =
        %{state | protocol: protocol}
        |> update_entry(key, &%{&1 | mode: :websocket_opening, deadline: lifetime})

      prepare_operation(state, key, {:head, 200, fields, false}, deadline)
    else
      _ -> {:ok, cancel(state, key, 0x10C)}
    end
  end

  defp prepare_operation(state, key, {:websocket_finish}, deadline) do
    if state.streams[key].mode == :websocket and not state.streams[key].send_done do
      state = update_entry(state, key, &%{&1 | mode: :websocket_closing})
      output_operation(state, key, <<>>, true, deadline)
    else
      {:ok, cancel(state, key, 0x10C)}
    end
  end

  defp prepare_operation(state, key, {:data, bytes, ended}, deadline) do
    if state.streams[key].response_phase == :final and not state.streams[key].send_done,
      do:
        output_operation(
          state,
          key,
          if(bytes == <<>>, do: <<>>, else: Frame.encode!(:data, bytes)),
          ended,
          deadline
        ),
      else: {:ok, cancel(state, key, 0x102)}
  end

  defp prepare_operation(state, key, {:trailers, fields}, deadline) do
    with true <- state.streams[key].response_phase == :final and not state.streams[key].send_done,
         :ok <- Headers.trailers(fields, state.options.http_limits),
         {:ok, block} <- Qpack.encode_header_block(fields) do
      output_operation(state, key, Frame.encode!(:headers, block), true, deadline)
    else
      _ -> {:ok, cancel(state, key, 0x102)}
    end
  end

  defp prepare_operation(state, _key, operation, _deadline)
       when elem(operation, 0) in [:read, :poll, :abort],
       do: {:ok, state}

  defp output_operation(state, key, bytes, ended, deadline) do
    if byte_size(bytes) <= state.options.h3_limits.max_pending_output do
      {:ok,
       update_entry(state, key, &%{&1 | out: bytes, send_fin: ended, output_deadline: deadline})}
    else
      {:ok, cancel(state, key, 0x107)}
    end
  end

  defp complete_output(%{operations: nil} = state, _), do: {:ok, state}

  defp complete_output(state, key) do
    case state.streams[key] do
      %{cancel: [_ | _]} ->
        {:ok, state}

      %{operation: {_, {:read, credit, {:until, io_deadline}}, deadline}} = entry ->
        cond do
          now() >= deadline ->
            {:ok, cancel(state, key, 0x10C)}

          entry.input != <<>> or entry.recv_fin ->
            reply_read(state, key, credit)

          now() >= io_deadline ->
            reply_operation(state, key, :pending)

          true ->
            {:ok, state}
        end

      %{operation: {_, {:poll, {:until, io_deadline}}, deadline}} ->
        cond do
          now() >= deadline -> {:ok, cancel(state, key, 0x10C)}
          now() >= io_deadline -> reply_operation(state, key, :pending)
          true -> {:ok, state}
        end

      %{operation: {_, {:abort, _}, _}} ->
        with {:ok, next} <- reply_operation(state, key, :ok),
             do: {:ok, update_entry(next, key, &%{&1 | abort_pending: true})}

      %{operation: {_, {:websocket_finish}, deadline}} = entry ->
        cond do
          now() >= deadline ->
            {:ok, cancel(state, key, 0x10C)}

          entry.send_done and entry.recv_fin and entry.input == <<>> and
              not Map.has_key?(state.pending, {key, :write}) ->
            reply_operation(state, key, :ok)

          true ->
            {:ok, state}
        end

      %{operation: {_, operation, deadline}, out: <<>>}
      when elem(operation, 0) in [:head, :data, :trailers, :websocket_open] ->
        if Map.has_key?(state.pending, {key, :write}) do
          {:ok, state}
        else
          if now() >= deadline do
            {:ok, cancel(state, key, 0x10C)}
          else
            state =
              if elem(operation, 0) == :websocket_open,
                do: update_entry(state, key, &%{&1 | mode: :websocket}),
                else: state

            reply_operation(state, key, :ok)
          end
        end

      _ ->
        {:ok, state}
    end
  end

  @doc false
  def reply_read(state, key, credit) do
    entry = state.streams[key]
    count = min(credit, byte_size(entry.input))
    <<bytes::binary-size(^count), rest::binary>> = entry.input
    ended = entry.recv_fin and rest == <<>>
    result = {if(ended, do: :ok, else: :more), bytes, ended, entry.trailers}
    {ref, _, _} = entry.operation

    case Operations.reply(state.operations, key, entry.token, ref, result) do
      :ok -> {:ok, update_entry(state, key, &%{&1 | operation: nil, input: rest})}
      _ -> {:ok, cancel(state, key, 0x10C)}
    end
  end

  defp reply_operation(state, key, result) do
    entry = state.streams[key]
    {ref, _, _} = entry.operation

    case Operations.reply(state.operations, key, entry.token, ref, result) do
      :ok -> {:ok, update_entry(state, key, &%{&1 | operation: nil})}
      _ -> {:ok, cancel(state, key, 0x10C)}
    end
  end

  defp stop_endpoint(%{operations: nil} = state, _, _), do: state

  defp stop_endpoint(state, key, reason) do
    case state.streams[key] do
      %{token: token, worker: worker} = entry when token != nil ->
        _ = Operations.cancel(state.operations, key, token, reason)
        if is_pid(worker) and Process.alive?(worker), do: Process.exit(worker, :kill)
        # Revoke the worker's command capability immediately. The connection
        # entry separately retains native operations, admission aliases and
        # canonical terminal proofs until their actual cleanup completes.
        _ = Operations.remove(state.operations, key, token)

        if entry.spawn_cancel == nil and entry.admission != :none do
          reference = Admission.cancel_spawn(state.connection.gate, state.connection.lease, token)
          update_entry(state, key, &%{&1 | spawn_cancel: {:pending, reference}})
        else
          state
        end

      _ ->
        state
    end
  end

  defp cancel_receipt(state, key) do
    case state.streams[key].spawn_cancel do
      {:pending, reference} ->
        case :gen_server.wait_response(reference, 0) do
          :timeout -> state
          {:reply, result} -> update_entry(state, key, &%{&1 | spawn_cancel: {:done, result}})
          _ -> state
        end

      _ ->
        state
    end
  end

  defp settle_cancel(state, key) do
    Enum.reduce_while([:read, :write], {:ok, state}, fn kind, {:ok, acc} ->
      case acc.pending[{key, kind}] do
        nil ->
          {:cont, {:ok, acc}}

        {reference, deadline} ->
          if now() >= deadline do
            {:halt, fail(acc, 0x102, :uncertain_cancel_timeout)}
          else
            case QUIC.operation_status(acc.connection, reference) do
              %{result: _} ->
                {:cont, {:ok, %{acc | pending: Map.delete(acc.pending, {key, kind})}}}

              :unknown ->
                {:cont, {:ok, acc}}

              failure ->
                {:halt, fail(acc, 0x102, {:operation_status, failure})}
            end
          end
      end
    end)
  end

  defp observe(%{operations: nil} = state), do: state

  defp observe(state) do
    measurements =
      Enum.reduce(
        state.streams,
        %{slot_count: 0, ingress_bytes: 0, output_bytes: 0, parser_bytes: 0},
        fn {key, entry}, acc ->
          parser = state.protocol.streams[key]

          parser_bytes =
            if parser == nil, do: 0, else: byte_size(parser.buffer) + byte_size(parser.payload)

          %{
            slot_count: acc.slot_count + if(entry.token == nil, do: 0, else: 1),
            ingress_bytes: acc.ingress_bytes + byte_size(entry.input),
            output_bytes: acc.output_bytes + byte_size(entry.out),
            parser_bytes: acc.parser_bytes + parser_bytes
          }
        end
      )

    :telemetry.execute(
      [:gaoxy, :http3, :queue],
      measurements,
      Map.put(Map.get(state.connection, :scope, %{}), :connection, self())
    )

    state
  end

  defp flush(state, key) do
    case state.streams[key] do
      nil ->
        {:ok, state}

      %{cancel: [_ | _]} ->
        {:ok, state}

      %{send_done: true} ->
        {:ok, state}

      %{out: <<>>, send_fin: false} ->
        {:ok, state}

      entry ->
        size =
          min(
            byte_size(entry.out),
            entry.write_quantum
          )

        <<chunk::binary-size(^size), rest::binary>> = entry.out
        fin = entry.send_fin and rest == <<>>

        case operation(state, {key, :write}, entry.output_deadline, fn opts ->
               QUIC.send_stream(key, chunk, fin, opts)
             end) do
          {:ok, state, {:ok, _}} ->
            {:ok,
             update_entry(
               state,
               key,
               &%{
                 &1
                 | out: rest,
                   send_done: fin,
                   write_quantum:
                     min(
                       2 * &1.write_quantum,
                       min(
                         state.connection.limits.max_output,
                         state.options.h3_limits.control_quantum
                       )
                     ),
                   output_deadline: if(rest == <<>>, do: nil, else: &1.output_deadline)
               }
             )}

          {:wait, state} ->
            {:ok, state}

          {:ok, state, {:blocked, _}} ->
            {:ok, update_entry(state, key, &%{&1 | write_quantum: max(1, div(size, 2))})}

          {:ok, state, {:error, :stopped}} ->
            {:ok, cancel(state, key, 0x10C)}

          {:ok, state, {:error, :not_established}} ->
            {:stop, :normal, clear(state)}

          {:ok, state, failure} ->
            fail(state, 0x102, {:write, failure})

          failure ->
            failure
        end
    end
  end

  defp peer_cancel(state, key, code) do
    case state.streams[key] do
      # A reflexive peer event must not replace the first terminal decision or
      # requeue an admitted command while its remaining cleanup is unresolved.
      %{cancel: [_ | _]} ->
        {:ok, state}

      _ ->
        case transition(state, key, Protocol.reset(state.protocol, key)) do
          {:ok, next} -> {:ok, cancel(next, key, code)}
          failure -> failure
        end
    end
  end

  defp cancel(state, key, code, commands \\ [:reset, :stop]) do
    state = stop_endpoint(state, key, :cancelled)

    state = %{
      state
      | protocol: %{state.protocol | streams: Map.delete(state.protocol.streams, key)}
    }

    update_entry(
      state,
      key,
      &%{
        &1
        | out: <<>>,
          operation: nil,
          send_fin: false,
          cancel: Enum.map(commands, fn kind -> {kind, code} end),
          cancel_deadline:
            if(state.operations == nil,
              do: nil,
              else:
                &1.cancel_deadline ||
                  Lifecycle.earlier(
                    cleanup_deadline(&1.deadline),
                    now() + state.options.http_limits.write_timeout
                  )
            ),
          output_deadline: &1.output_deadline || now() + state.options.http_limits.write_timeout
      }
    )
  end

  defp cleanup_deadline(:infinity), do: :infinity
  defp cleanup_deadline(deadline), do: deadline + Lifecycle.cleanup_headroom()

  defp cleanup_stream(%{operations: nil} = state, key), do: cleanup_command(state, key)

  defp cleanup_stream(state, key) do
    with {:ok, state} <- settle_cancel(state, key) do
      if Map.has_key?(state.pending, {key, :write}) or Map.has_key?(state.pending, {key, :read}),
        do: {:ok, state},
        else: cleanup_command(state, key)
    end
  end

  defp cleanup_command(state, key) do
    entry = state.streams[key]
    [{kind, code} | rest] = entry.cancel

    case operation(state, {key, kind}, entry.cancel_deadline || entry.output_deadline, fn opts ->
           case kind do
             :reset -> QUIC.reset_stream(key, code, opts)
             :stop -> QUIC.stop_stream(key, code, opts)
           end
         end) do
      {:ok, state, {:ok, _}} ->
        if rest == [],
          do: {:ok, drop(state, key)},
          else: {:ok, update_entry(state, key, &%{&1 | cancel: rest})}

      {:wait, state} ->
        {:ok, state}

      {:ok, state, {:blocked, _}} ->
        {:ok, state}

      {:ok, state, {:error, :stopped}} ->
        if rest == [],
          do: {:ok, drop(state, key)},
          else: {:ok, update_entry(state, key, &%{&1 | cancel: rest})}

      {:ok, state, failure} ->
        fail(state, 0x102, {:cancel, failure})

      failure ->
        failure
    end
  end

  # Each uncertain reference is polled, never resubmitted. Its original deadline
  # stays fixed, including when a public read may have consumed bytes already.
  defp operation(state, key, deadline, fun) do
    case state.pending[key] do
      {reference, original_deadline} ->
        if now() >= original_deadline do
          fail(state, 0x102, :operation_timeout)
        else
          case QUIC.operation_status(state.connection, reference) do
            %{result: result} -> {:ok, %{state | pending: Map.delete(state.pending, key)}, result}
            :unknown -> {:wait, state}
            failure -> fail(state, 0x102, {:operation_status, failure})
          end
        end

      nil ->
        case operation_options(
               state.connection.limits.callback_timeout,
               state.turn_deadline,
               deadline,
               now()
             ) do
          :expired ->
            fail(state, 0x102, :operation_timeout)

          :yield ->
            {:wait, state}

          {:ok, options} ->
            case fun.(options) do
              {:unknown, reference} ->
                {:wait, %{state | pending: Map.put(state.pending, key, {reference, deadline})}}

              {:blocked, _} = result ->
                {:ok, state, result}

              result ->
                {:ok, state, result}
            end
        end
    end
  end

  @doc false
  def operation_options(callback_timeout, turn_deadline, deadline, at) do
    # Leave room for the call to return inside this turn, including configured
    # callback windows shorter than 50ms. Neither absolute deadline is renewed.
    allowance = min(50, max(1, div(callback_timeout, 2)))

    cond do
      at >= deadline -> :expired
      turn_deadline - at < min(allowance, deadline - at) -> :yield
      true -> {:ok, [timeout: allowance, deadline: min(deadline, turn_deadline) - at]}
    end
  end

  defp work_deadline(state, key) do
    case state.protocol.streams[key] do
      %{kind: kind} = parser when kind != :request ->
        incomplete =
          case parser.phase do
            :type -> parser.buffer != <<>>
            :qpack -> parser.buffer != <<>>
            _ -> true
          end

        update_entry(state, key, fn entry ->
          %{
            entry
            | work_deadline:
                if(incomplete,
                  do: entry.work_deadline || now() + state.options.http_limits.request_timeout,
                  else: nil
                )
          }
        end)

      _ ->
        state
    end
  end

  defp retire(%{operations: table} = state, key) when table != nil do
    case state.streams[key] do
      %{worker_finished: true, recv_fin: true, send_done: true} -> drop(state, key)
      %{worker_finished: true, send_done: true, cancel: []} -> cancel(state, key, 0x10C, [:stop])
      %{recv_fin: true, kind: :uni} -> drop(state, key)
      _ -> state
    end
  end

  defp retire(state, key) do
    case state.streams[key] do
      %{recv_fin: true, send_done: true} -> drop(state, key)
      %{recv_fin: true, kind: :uni} -> drop(state, key)
      _ -> state
    end
  end

  defp resource_terminal(%{operations: nil} = state, _key), do: state

  defp resource_terminal(state, key) do
    entry = state.streams[key]
    parser = state.protocol.streams[key]
    parser_empty = parser == nil or (parser.buffer == <<>> and parser.payload == <<>>)

    pending =
      Enum.any?(state.pending, fn {slot, _} -> is_tuple(slot) and elem(slot, 0) == key end)

    if entry != nil and entry.token != nil and not entry.resources_terminal and
         entry.admission != :pending and
         entry.input == <<>> and entry.out == <<>> and parser_empty and not pending and
         entry.operation == nil and (entry.retiring or (entry.send_done and entry.recv_fin)) do
      deadline = terminal_deadline(entry)
      identity = entry.resources_identity || entry.lease || {:spawn, entry.token}
      state = update_entry(state, key, &%{&1 | resources_identity: identity})

      result =
        Admission.finish_stream_resources(
          state.connection.gate,
          state.connection.lease,
          identity,
          entry.resources_operation,
          deadline
        )

      # Only the original OTP response alias and exact spawn token can prove
      # pre-reservation expiry. A stale cancel reply cannot establish absence.
      absent = entry.admission in [:none, :not_reserved]

      if result == :ok or (result == {:error, :stale_generation} and absent),
        do: update_entry(state, key, &%{&1 | resources_terminal: true}),
        else: state
    else
      state
    end
  catch
    :exit, _ -> state
  end

  defp terminal_deadline(entry) do
    entry.cancel_deadline ||
      if(entry.deadline == :infinity,
        do: Lifecycle.deadline(Lifecycle.cleanup_headroom()),
        else: cleanup_deadline(entry.deadline)
      )
  end

  defp drop(%{streams: streams} = state, key) when not is_map_key(streams, key), do: state

  defp drop(%{operations: nil} = state, key), do: delete_stream(state, key)

  defp drop(state, key) do
    state = stop_endpoint(state, key, :closed)

    state =
      update_entry(
        state,
        key,
        &%{&1 | retiring: true, input: <<>>, out: <<>>, trailers: [], operation: nil, cancel: []}
      )

    state = %{
      state
      | protocol: %{state.protocol | streams: Map.delete(state.protocol.streams, key)}
    }

    state = state |> startup_turn(key) |> cancel_receipt(key) |> resource_terminal(key)
    entry = state.streams[key]

    if entry.admission != :pending and not entry.stream_terminal and entry.token != nil do
      case Admission.end_stream(
             state.connection.gate,
             state.connection.lease,
             :h3_stream,
             entry.token,
             terminal_deadline(entry)
           ) do
        :ok -> finish_drop(update_entry(state, key, &%{&1 | stream_terminal: true}), key)
        _ -> state
      end
    else
      finish_drop(state, key)
    end
  catch
    :exit, _ -> state
  end

  defp finish_drop(state, key) do
    entry = state.streams[key]

    if entry.token == nil or (entry.resources_terminal and entry.stream_terminal) do
      if entry.token != nil, do: Operations.remove(state.operations, key, entry.token)
      delete_stream(state, key)
    else
      state
    end
  end

  defp delete_stream(state, key) do
    case state.streams[key] do
      %{spawn_cancel: {:pending, reference}} -> :gen_server.receive_response(reference, 0)
      _ -> :ok
    end

    %{
      state
      | streams: Map.delete(state.streams, key),
        pending:
          Map.reject(state.pending, fn {slot, _} -> is_tuple(slot) and elem(slot, 0) == key end)
    }
  end

  defp update_entry(state, key, fun) do
    if Map.has_key?(state.streams, key),
      do: %{state | streams: Map.update!(state.streams, key, fun)},
      else: state
  end

  defp fail(state, code, reason) do
    _ =
      QUIC.close(state.connection, code, <<>>,
        timeout: min(50, state.connection.limits.callback_timeout)
      )

    {:stop, {:http3, code, reason}, clear(state)}
  end

  defp clear(state) do
    state =
      Enum.reduce(state.streams, state, fn {key, _}, acc -> stop_endpoint(acc, key, :closed) end)

    if state.operations != nil and :ets.info(state.operations) != :undefined,
      do: :ets.delete(state.operations)

    observe(%{
      state
      | streams: %{},
        protocol: %{state.protocol | streams: %{}},
        order: :queue.new(),
        pending: %{},
        control: nil,
        control_bytes: <<>>,
        idle_deadline: nil,
        keepalive: nil,
        closed: true
    })
  end

  defp now, do: System.monotonic_time(:millisecond)
end
