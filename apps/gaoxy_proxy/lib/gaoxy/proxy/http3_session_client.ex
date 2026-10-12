defmodule Gaoxy.Proxy.HTTP3SessionClient do
  @moduledoc false
  @behaviour Gaoxy.Proxy.UpstreamClient
  alias Gaoxy.Lifecycle
  alias QuicHttp3.Session
  alias QuicHttp3.Transport.Quic, as: Transport

  @window 262_144
  @chunk 16_384
  @fields 128
  @field_bytes 65_536
  @operations ~w(connect ready open request poll send_data send_trailers suspend_blocked resume reset_send close abort)a
  @streams [
    max_data: @window,
    max_buffer: @window,
    max_ready_bytes: @window,
    max_stream_data_bidi_local: 65_536,
    max_stream_data_uni: 65_536,
    max_streams_bidi: 1,
    max_streams_uni: 3,
    max_stream_records: 16
  ]

  @impl true
  def host_supported?, do: Code.ensure_loaded?(Session) and Code.ensure_loaded?(Transport)

  @impl true
  def reservation_bytes(fields, url_bytes, chunk_bytes),
    do: 8 * @window + 8 * chunk_bytes + 2 * :erlang.external_size({fields, ""}) + 2 * url_bytes

  @impl true
  def open(options), do: open(options, &apply/3)

  # Complete public calls are the only deterministic test boundary. HTTP
  # configuration cannot supply this driver; open/1 always uses the fixed SDK.
  @doc false
  def open(options, driver) when is_map(options) and is_function(driver, 3) do
    with :ok <- validate_options(options),
         # TODO(upstream): gsmlg-dev/http_fetch#105
         # WORKAROUND(upstream): gsmlg-dev/http_fetch#105
         # Session fragments wire frames; application DATA remains at most 16 KiB.
         {:ok, session} <-
           driver.(Session, :new, [
             [
               timeout: remaining_open(options),
               max_frame: 8_192,
               max_fields: @fields,
               max_encoded_headers: @field_bytes,
               max_header_bytes: @field_bytes,
               max_retained_bytes: @window
             ]
           ]) do
      id = make_ref()
      owner = self()
      uri = URI.parse(options.url)

      transport = [
        host: uri.host,
        tls: [cacertfile: options.cacertfile, verify: :verify_peer],
        streams: @streams,
        timeout: remaining_open(options)
      ]

      generation = make_ref()

      {pid, monitor} =
        :erlang.spawn_opt(
          fn ->
            bootstrap(
              owner,
              id,
              generation,
              transport,
              driver,
              min(options.deadline, options.opening_deadline)
            )
          end,
          [:link, :monitor]
        )

      handle = %{
        kind: :http3_session,
        id: id,
        owner: owner,
        generation: generation,
        driver: driver,
        promise: nil,
        stream: {:http3_session, id},
        resolved: false,
        endpoint: nil,
        endpoint_monitor: nil,
        endpoint_down: nil,
        bootstrap: %{pid: pid, monitor: monitor, down: nil, result: nil},
        caller: nil,
        caller_stop_sent: false,
        stop_task: nil,
        session: session,
        request_ref: nil,
        phase: :bootstrap,
        operation: nil,
        pending: nil,
        continuation: nil,
        abandoned_operation_identity: nil,
        upload_waiter: nil,
        upload_finished: false,
        upload_stopped: false,
        reset_pending: false,
        delivery: nil,
        events: [],
        event_bytes: 0,
        tick: nil,
        poll_due: Lifecycle.now(),
        deadline: options.deadline,
        opening_deadline: options.opening_deadline,
        write_timeout: options.write_timeout,
        max_upload_bytes: Map.get(options, :max_upload_bytes, @chunk),
        limits: Map.get(options, :limits, %{}),
        uri: uri,
        fields: request_fields(uri, options),
        transport: transport,
        cleanup_deadline: nil,
        cleanup: :not_started,
        cleanup_cancelled: false,
        cleanup_stop_due: nil,
        stop_result: nil,
        stop_trigger: nil,
        cleanup_session_result: nil,
        closed_reason: nil,
        terminal: false,
        error: nil,
        error_reported: false,
        ended: false
      }

      upload = {:http3_session_upload, owner, id, options.deadline, options.write_timeout}
      {:ok, tick(handle), upload}
    end
  end

  defp validate_options(options) do
    uri = URI.parse(options.url)

    cond do
      Lifecycle.remaining(options.deadline) == 0 ->
        {:error, :request_timeout}

      Lifecycle.remaining(options.opening_deadline) == 0 ->
        {:error, :timeout}

      uri.scheme != "https" or not is_binary(uri.host) or uri.userinfo != nil or
          uri.fragment != nil ->
        {:error, :invalid_http3_origin}

      not is_binary(options.cacertfile) or not File.regular?(options.cacertfile) ->
        {:error, :invalid_http3_ca}

      Map.get(options, :connect_address) != nil ->
        {:error, :invalid_http3_options}

      Enum.any?(
        [:driver, :client, :transport, :tls, :socket_opts, :ssl, :tls_backend],
        &Map.has_key?(options, &1)
      ) ->
        {:error, :invalid_http3_options}

      Map.get(options, :max_upload_bytes, @chunk) not in 1..@chunk ->
        {:error, :invalid_upload_chunk}

      true ->
        :ok
    end
  end

  defp remaining_open(options),
    do: min(Lifecycle.remaining(options.deadline), Lifecycle.remaining(options.opening_deadline))

  defp request_fields(uri, options) do
    host = if String.contains?(uri.host, ":"), do: "[#{uri.host}]", else: uri.host
    authority = if uri.port == 443, do: host, else: "#{host}:#{uri.port}"
    path = if uri.path in [nil, ""], do: "/", else: uri.path
    path = if uri.query == nil, do: path, else: path <> "?" <> uri.query
    method = options.method |> to_string() |> String.upcase()

    [{":method", method}, {":scheme", "https"}, {":authority", authority}, {":path", path}] ++
      Enum.reject(options.headers, fn {name, _} -> String.downcase(name) == "host" end)
  end

  @impl true
  def completion(handle), do: {:http3_session, handle.owner, handle.id}
  @impl true
  def await_completion(_, _), do: {:error, :unsupported_group_completion}
  @impl true
  def subscribe(_), do: :ok

  @impl true
  def write_body(token, bytes, timeout) when is_binary(bytes) and byte_size(bytes) <= @chunk,
    do: upload_call(token, :data, bytes, timeout)

  def write_body(_, _, _), do: {:error, :invalid_upload_chunk}

  @impl true
  def finish_body({:http3_session_upload, _, _, _, timeout} = token, trailers),
    do: upload_call(token, :finish, trailers, timeout)

  defp upload_call(
         {:http3_session_upload, owner, id, total, write_timeout},
         kind,
         payload,
         timeout
       ) do
    deadline = min(total, Lifecycle.deadline(min(timeout, write_timeout)))

    if Lifecycle.remaining(deadline) == 0 do
      {:error, :timeout}
    else
      ref = make_ref()
      monitor = Process.monitor(owner)
      send(owner, {:h3_upload, id, self(), ref, kind, payload, deadline})

      result =
        receive do
          {:h3_upload_reply, ^id, ^ref, result} -> result
          {:DOWN, ^monitor, :process, ^owner, _} -> {:error, :upstream_closed}
        after
          Lifecycle.remaining(deadline) ->
            send(owner, {:h3_upload_cancel, id, ref})
            {:error, :timeout}
        end

      Process.demonitor(monitor, [:flush])
      result
    end
  end

  @impl true
  def acknowledge(%{delivery: ref} = handle, ref), do: {:ok, tick(%{handle | delivery: nil}, 0)}
  def acknowledge(handle, _), do: {:ok, handle}

  @impl true
  def poll_headers(handle), do: advance(handle)

  @impl true
  def event(handle, message) do
    handle = receive_event(handle, message)
    advance(handle)
  end

  defp receive_event(%{id: id} = handle, {:h3_tick, id}), do: %{handle | tick: nil}

  defp receive_event(
         %{id: id, generation: generation, bootstrap: %{pid: creator}} = handle,
         {:h3_endpoint, id, generation, creator, %{pid: pid} = descriptor}
       )
       when is_pid(pid) do
    if handle.endpoint == nil do
      monitor = Process.monitor(pid)
      Process.link(pid)
      send(creator, {:h3_adopt, id, generation})
      handle = %{handle | endpoint: descriptor, endpoint_monitor: monitor}
      if handle.cleanup != :not_started, do: begin_stop(handle), else: handle
    else
      handle
    end
  end

  defp receive_event(
         %{id: id, generation: generation, bootstrap: %{pid: creator} = task} = handle,
         {:h3_bootstrap_result, id, generation, creator, result}
       ),
       do: %{handle | bootstrap: %{task | result: result}}

  defp receive_event(
         %{
           id: id,
           generation: generation,
           caller: %{pid: caller},
           operation: %{ref: ref} = operation
         } = handle,
         {:h3_result, id, generation, caller, ref, result}
       ) do
    handle = %{retain_session(handle, result) | operation: nil}

    cond do
      handle.cleanup != :not_started ->
        handle =
          if operation.kind in [:abort, :close],
            do: %{handle | cleanup_session_result: result},
            else: handle

        begin_stop(
          handle,
          if(operation.kind in [:abort, :close], do: :public_result, else: :immediate)
        )

      handle.terminal ->
        handle

      Lifecycle.remaining(operation.deadline) == 0 ->
        fail(handle, deadline_reason(handle))

      true ->
        operation_result(handle, operation, result)
    end
  end

  defp receive_event(
         %{id: id, generation: generation, caller: %{pid: caller}, closed_reason: nil} = handle,
         {:h3_closed, id, generation, caller, reason}
       ),
       do: %{handle | closed_reason: reason}

  defp receive_event(
         %{id: id, generation: generation, stop_task: %{pid: pid}} = handle,
         {:h3_stop_result, id, generation, pid, result}
       ) do
    handle = %{handle | stop_result: result}
    if result == :ok, do: handle, else: stop_owned(handle)
  end

  defp receive_event(%{id: id} = handle, {:h3_upload, id, pid, ref, kind, payload, deadline}) do
    reason =
      cond do
        handle.terminal or handle.upload_stopped or handle.upload_finished ->
          :upload_closed

        handle.upload_waiter != nil ->
          :upload_overlap

        Lifecycle.remaining(deadline) == 0 ->
          :timeout

        kind == :data and (not is_binary(payload) or byte_size(payload) > handle.max_upload_bytes) ->
          :invalid_upload_chunk

        kind == :finish and not valid_fields?(payload, handle, :trailers) ->
          :invalid_proxy_trailers

        kind not in [:data, :finish] ->
          :invalid_upload_command

        true ->
          nil
      end

    if reason do
      send(pid, {:h3_upload_reply, id, ref, {:error, reason}})
      handle
    else
      %{
        handle
        | upload_waiter: %{
            pid: pid,
            ref: ref,
            kind: kind,
            payload: payload,
            deadline: min(deadline, handle.deadline)
          }
      }
    end
  end

  defp receive_event(
         %{id: id, upload_waiter: %{ref: ref}} = handle,
         {:h3_upload_cancel, id, ref}
       ),
       do: fail(handle, :timeout)

  defp receive_event(
         %{endpoint_monitor: ref, endpoint: %{pid: pid}} = handle,
         {:DOWN, ref, :process, pid, reason}
       ) do
    handle = %{handle | endpoint_down: reason}

    if handle.cleanup == :not_started,
      do: fail(handle, {:upstream_endpoint, reason}),
      else: stop_owned(handle)
  end

  defp receive_event(handle, {:DOWN, ref, :process, pid, reason}) do
    cond do
      matches_task?(handle.bootstrap, pid, ref) ->
        task = %{handle.bootstrap | down: reason}
        handle = %{handle | bootstrap: task}

        if reason == :normal or handle.cleanup != :not_started,
          do: handle,
          else: fail(handle, {:upstream_bootstrap, reason})

      matches_task?(handle.caller, pid, ref) ->
        handle = %{handle | caller: %{handle.caller | down: reason}}

        if handle.cleanup != :not_started,
          do: begin_stop(handle, :caller_down),
          else: fail(handle, {:upstream_caller, reason})

      matches_task?(handle.stop_task, pid, ref) ->
        %{handle | stop_task: %{handle.stop_task | down: reason}}

      true ->
        handle
    end
  end

  defp receive_event(handle, _), do: handle

  defp matches_task?(%{pid: pid, monitor: ref}, pid, ref), do: true
  defp matches_task?(_, _, _), do: false

  defp advance(handle) do
    handle = check_deadlines(handle)

    handle =
      if handle.cleanup == :not_started, do: schedule(handle), else: cleanup_progress(handle)

    {event, handle} = delivery(handle)
    delay = if handle.delivery == nil and handle.events != [], do: 0, else: 5
    {event, tick(handle, delay)}
  end

  defp check_deadlines(%{cleanup: cleanup} = handle) when cleanup != :not_started, do: handle
  defp check_deadlines(%{terminal: true} = handle), do: handle

  defp check_deadlines(handle) do
    cond do
      Lifecycle.remaining(handle.deadline) == 0 ->
        fail(handle, :request_timeout)

      not handle.resolved and Lifecycle.remaining(handle.opening_deadline) == 0 ->
        fail(handle, :timeout)

      handle.upload_waiter != nil and Lifecycle.remaining(handle.upload_waiter.deadline) == 0 ->
        fail(handle, :timeout)

      handle.operation != nil and Lifecycle.remaining(handle.operation.deadline) == 0 ->
        fail(handle, :timeout)

      handle.pending != nil and Lifecycle.remaining(handle.pending.deadline) == 0 ->
        fail(handle, :timeout)

      true ->
        handle
    end
  end

  defp schedule(%{terminal: true} = handle), do: handle
  defp schedule(%{operation: operation} = handle) when operation != nil, do: handle

  defp schedule(
         %{phase: :bootstrap, bootstrap: %{down: :normal, result: :ok}, endpoint: endpoint} =
           handle
       )
       when not is_nil(endpoint) do
    owner = handle.owner
    id = handle.id
    generation = handle.generation
    driver = handle.driver

    {pid, monitor} =
      :erlang.spawn_opt(fn -> caller(owner, id, generation, driver) end, [:link, :monitor])

    handle = %{
      handle
      | caller: %{pid: pid, monitor: monitor, down: nil, sequence: 0},
        phase: :connect
    }

    schedule(handle)
  end

  defp schedule(
         %{phase: :bootstrap, bootstrap: %{down: :normal, result: {:error, reason}}} = handle
       ),
       do: fail(handle, reason)

  defp schedule(%{phase: :bootstrap} = handle), do: handle

  defp schedule(%{pending: %{kind: kind, deadline: deadline, action: action, due: due}} = handle) do
    if Lifecycle.remaining(due) == 0 do
      identity = Map.get(handle.pending, :identity)
      handle = command(%{handle | pending: nil}, kind, [handle.session], deadline, action)
      %{handle | operation: Map.put(handle.operation, :public_identity, identity)}
    else
      handle
    end
  end

  defp schedule(%{phase: :connect} = handle) do
    deadline = opening_deadline(handle)

    opts =
      Keyword.merge(handle.transport,
        endpoint: handle.endpoint,
        timeout: Lifecycle.remaining(deadline)
      )

    command(handle, :connect, [handle.session, handle.uri.host, handle.uri.port, opts], deadline)
  end

  defp schedule(%{phase: :ready} = handle) do
    if Lifecycle.remaining(handle.poll_due) == 0,
      do: command(handle, :ready, [handle.session], opening_deadline(handle)),
      else: handle
  end

  defp schedule(%{phase: :open} = handle),
    do: command(handle, :open, [handle.session], opening_deadline(handle))

  defp schedule(%{phase: :request} = handle) do
    deadline = opening_deadline(handle)

    command(
      handle,
      :request,
      [handle.session, handle.fields, :stream, [timeout: Lifecycle.remaining(deadline)]],
      deadline
    )
  end

  defp schedule(%{reset_pending: true} = handle),
    do:
      command(
        %{handle | reset_pending: false},
        :reset_send,
        [handle.session, handle.request_ref],
        handle.deadline
      )

  defp schedule(
         %{continuation: %{ready: true, token: token, deadline: deadline, action: action}} =
           handle
       ),
       do:
         command(
           %{handle | continuation: nil},
           :resume,
           [handle.session, token],
           deadline,
           action
         )

  defp schedule(%{continuation: nil, upload_waiter: waiter, phase: :streaming} = handle)
       when not is_nil(waiter) do
    timeout = Lifecycle.remaining(waiter.deadline)

    {kind, arguments} =
      case waiter do
        %{kind: :data, payload: bytes} ->
          {:send_data, [handle.session, handle.request_ref, bytes, false, [timeout: timeout]]}

        %{kind: :finish, payload: []} ->
          {:send_data, [handle.session, handle.request_ref, <<>>, true, [timeout: timeout]]}

        %{kind: :finish, payload: trailers} ->
          {:send_trailers, [handle.session, handle.request_ref, trailers, [timeout: timeout]]}
      end

    command(handle, kind, arguments, waiter.deadline, {:upload, waiter.kind})
  end

  defp schedule(%{phase: :streaming, ended: false} = handle) do
    # Never read another unpaused batch ahead of retained events. Paused polls
    # still process control/credit while the one delivery awaits its ACK.
    if (handle.events == [] or handle.delivery != nil) and
         Lifecycle.remaining(handle.poll_due) == 0 do
      paused = if handle.delivery, do: MapSet.new([handle.request_ref]), else: MapSet.new()
      deadline = if handle.resolved, do: handle.deadline, else: opening_deadline(handle)

      command(
        handle,
        :poll,
        [
          handle.session,
          16,
          [timeout: Lifecycle.remaining(deadline), max_read_batches: 1, paused: paused]
        ],
        deadline
      )
    else
      handle
    end
  end

  defp schedule(handle), do: handle

  defp opening_deadline(handle), do: min(handle.deadline, handle.opening_deadline)

  defp command(handle, kind, arguments, deadline, action \\ nil) do
    ref = make_ref()
    action = action || kind
    sequence = handle.caller.sequence + 1

    send(
      handle.caller.pid,
      {:h3_command, handle.owner, handle.id, handle.generation, ref, sequence, kind, arguments,
       deadline}
    )

    %{
      handle
      | caller: %{handle.caller | sequence: sequence},
        operation: %{ref: ref, kind: kind, deadline: deadline, action: action}
    }
  end

  defp retain_session(handle, {tag, session, _}) when tag in [:ok, :error, :unknown, :blocked],
    do: %{handle | session: session}

  defp retain_session(handle, {:ok, session}), do: %{handle | session: session}
  defp retain_session(handle, _), do: handle

  defp operation_result(handle, operation, {:unknown, _, identity}),
    do: %{
      handle
      | pending: %{
          kind: :resume,
          deadline: operation.deadline,
          action: operation.action,
          identity: identity,
          due: Lifecycle.deadline(5)
        }
    }

  defp operation_result(handle, %{action: {:upload, _}} = operation, {:blocked, _, _}),
    do: %{
      handle
      | pending: %{
          kind: :suspend_blocked,
          deadline: operation.deadline,
          action: operation.action,
          due: Lifecycle.now()
        }
    }

  defp operation_result(handle, %{kind: :open}, {:blocked, _, :not_ready}),
    do: %{handle | phase: :ready, poll_due: Lifecycle.deadline(5)}

  defp operation_result(handle, operation, {:blocked, _, _}),
    do: %{
      handle
      | pending: %{
          kind: :resume,
          deadline: operation.deadline,
          action: operation.action,
          due: Lifecycle.deadline(5)
        }
    }

  defp operation_result(handle, _, {:error, _, reason}), do: fail(handle, reason)
  defp operation_result(handle, _, {:error, reason}), do: fail(handle, reason)

  defp operation_result(handle, %{kind: :suspend_blocked} = operation, {:ok, _, continuation}),
    do: %{
      handle
      | continuation: %{
          token: continuation,
          ready: false,
          deadline: operation.deadline,
          action: operation.action
        }
    }

  defp operation_result(handle, %{action: :connect}, {:ok, _}), do: %{handle | phase: :ready}
  defp operation_result(handle, %{action: :ready}, :ready), do: %{handle | phase: :open}

  defp operation_result(handle, %{action: :ready}, :pending),
    do: %{handle | poll_due: Lifecycle.deadline(5)}

  defp operation_result(handle, %{action: :open}, {:ok, _}), do: %{handle | phase: :request}

  defp operation_result(handle, %{action: :request}, {:ok, _, ref}),
    do: %{handle | phase: :streaming, request_ref: ref}

  defp operation_result(handle, %{action: :poll}, {:ok, _, events}) when is_list(events) do
    progress =
      Enum.any?(events, fn
        {kind, ref, _} when kind in [:headers, :data, :trailers] -> ref == handle.request_ref
        {:done, ref} -> ref == handle.request_ref
        _ -> false
      end)

    due = if progress, do: Lifecycle.now(), else: Lifecycle.deadline(5)
    queue_events(%{handle | poll_due: due}, events)
  end

  defp operation_result(handle, %{action: {:upload, kind}}, {:ok, _}) do
    handle = reply_upload(handle, :ok)
    %{handle | upload_finished: kind == :finish}
  end

  defp operation_result(handle, %{action: :reset_send}, {:ok, _}), do: handle
  defp operation_result(handle, _, _), do: fail(handle, :invalid_session_result)

  defp queue_events(handle, events) do
    bytes =
      Enum.reduce(events, handle.event_bytes, fn event, size -> size + event_bytes(event) end)

    if length(handle.events) + length(events) > 256 or bytes > @window do
      fail(handle, :upstream_event_limit)
    else
      Enum.reduce_while(events, %{handle | event_bytes: bytes}, fn event, state ->
        case queue_event(state, event) do
          %{terminal: true} = state -> {:halt, state}
          state -> {:cont, state}
        end
      end)
    end
  end

  defp event_bytes({:data, _, bytes}) when is_binary(bytes), do: byte_size(bytes)
  defp event_bytes({:headers, _, fields}), do: field_bytes(fields)
  defp event_bytes({:trailers, _, fields}), do: field_bytes(fields)
  defp event_bytes({:informational, _, _, fields}), do: field_bytes(fields)
  defp event_bytes(_), do: 0

  defp queue_event(%{request_ref: ref} = handle, {:headers, ref, fields}) do
    case Enum.split_with(fields, fn {name, _} -> name == ":status" end) do
      {[{":status", <<a, b, c>>}], ordinary} when a in ?1..?5 and b in ?0..?9 and c in ?0..?9 ->
        status = (a - ?0) * 100 + (b - ?0) * 10 + c - ?0

        if status >= 200 and not handle.resolved and valid_fields?(ordinary, handle, :headers) and
             field_bytes(fields) <= field_limit(handle, :headers) and length(fields) <= @fields do
          handle =
            if not handle.upload_finished do
              handle = reply_upload(handle, {:error, :upload_stopped})

              %{
                handle
                | upload_stopped: true,
                  reset_pending: true,
                  continuation: nil,
                  pending: nil
              }
            else
              handle
            end

          append_event(%{handle | resolved: true}, {:headers, status, ordinary})
        else
          fail(handle, :invalid_upstream_headers)
        end

      _ ->
        fail(handle, :invalid_upstream_headers)
    end
  end

  defp queue_event(%{request_ref: ref} = handle, {:data, ref, bytes}) when is_binary(bytes),
    do: append_event(handle, {:data, bytes})

  defp queue_event(%{request_ref: ref} = handle, {:trailers, ref, fields}) do
    if valid_fields?(fields, handle, :trailers),
      do: append_event(handle, {:trailers, fields}),
      else: fail(handle, :invalid_upstream_trailers)
  end

  # The public done result follows Session's terminal request retirement and
  # reset of an open upload. A second reset_send would target a retired request.
  defp queue_event(%{request_ref: ref} = handle, {:done, ref}),
    do: append_event(%{handle | reset_pending: false}, :end)

  defp queue_event(%{request_ref: ref} = handle, {:informational, ref, status, fields}) do
    if status in 100..199 and valid_fields?(fields, handle, :headers),
      do: %{handle | event_bytes: handle.event_bytes - field_bytes(fields)},
      else: fail(handle, :invalid_upstream_headers)
  end

  defp queue_event(handle, :writable), do: writable(handle)
  defp queue_event(%{request_ref: ref} = handle, {:writable, ref}), do: writable(handle)
  defp queue_event(handle, {:error, _, reason}), do: fail(handle, reason)

  defp queue_event(handle, {:stream_error, _, code, reason}),
    do: fail(handle, {:upstream_reset, code, reason})

  defp queue_event(%{request_ref: ref} = handle, {:stream_reset, ref, code, final_size}),
    do: fail(handle, {:upstream_reset, code, final_size})

  defp queue_event(%{request_ref: ref} = handle, {:stopped, ref, code}) do
    handle = reply_upload(handle, {:error, {:upload_stopped, code}})
    %{handle | upload_stopped: true, reset_pending: true, continuation: nil}
  end

  defp queue_event(handle, _), do: handle

  defp writable(%{continuation: continuation} = handle) when not is_nil(continuation),
    do: %{handle | continuation: %{continuation | ready: true}}

  defp writable(handle), do: handle
  defp append_event(handle, event), do: %{handle | events: handle.events ++ [event]}

  defp valid_fields?(fields, handle, kind) when is_list(fields) do
    count =
      if kind == :trailers,
        do: Map.get(handle.limits, :max_trailers, @fields),
        else: Map.get(handle.limits, :max_headers, @fields)

    length(fields) <= min(count, @fields) and field_bytes(fields) <= field_limit(handle, kind) and
      Enum.all?(fields, fn
        {name, value} when is_binary(name) and is_binary(value) ->
          Regex.match?(~r/\A[!#$%&'*+.^_`|~0-9A-Za-z-]+\z/, name) and
            Enum.all?(:binary.bin_to_list(value), &(&1 == 9 or (&1 >= 32 and &1 != 127)))

        _ ->
          false
      end)
  end

  defp valid_fields?(_, _, _), do: false

  defp field_limit(handle, :headers),
    do: min(@field_bytes, Map.get(handle.limits, :max_header_bytes, @field_bytes))

  defp field_limit(handle, :trailers),
    do: min(@field_bytes, Map.get(handle.limits, :max_trailer_bytes, @field_bytes))

  defp field_bytes(fields) when is_list(fields) do
    Enum.reduce(fields, 2, fn
      {name, value}, size when is_binary(name) and is_binary(value) ->
        size + byte_size(name) + byte_size(value) + 4

      _, _ ->
        @window + 1
    end)
  end

  defp field_bytes(_), do: @window + 1

  defp delivery(%{error: reason, error_reported: false} = handle) when not is_nil(reason),
    do: {{:error, reason}, %{handle | error_reported: true}}

  defp delivery(%{terminal: true} = handle), do: {:none, handle}
  defp delivery(%{delivery: ref} = handle) when not is_nil(ref), do: {:none, handle}

  defp delivery(%{events: [{:data, bytes} | rest]} = handle) do
    size = min(byte_size(bytes), @chunk)
    <<chunk::binary-size(size), tail::binary>> = bytes
    events = if tail == <<>>, do: rest, else: [{:data, tail} | rest]
    ref = make_ref()

    {{:chunk, chunk, ref},
     %{handle | events: events, event_bytes: handle.event_bytes - size, delivery: ref}}
  end

  defp delivery(%{events: [event | rest]} = handle) do
    bytes =
      case event do
        {:headers, _, fields} -> field_bytes(fields) + byte_size(":status") + 3 + 4
        {:trailers, fields} -> field_bytes(fields)
        _ -> 0
      end

    {event,
     %{
       handle
       | events: rest,
         event_bytes: max(0, handle.event_bytes - bytes),
         ended: handle.ended or event == :end
     }}
  end

  defp delivery(handle), do: {:none, handle}

  defp deadline_reason(handle),
    do: if(Lifecycle.remaining(handle.deadline) == 0, do: :request_timeout, else: :timeout)

  defp fail(%{terminal: true} = handle, _reason), do: handle

  defp fail(handle, reason) do
    handle = reply_upload(handle, {:error, reason})

    identity =
      if handle.pending,
        do: Map.get(handle.pending, :identity),
        else: if(handle.operation, do: Map.get(handle.operation, :public_identity))

    %{
      handle
      | terminal: true,
        error: reason,
        upload_stopped: true,
        events: [],
        event_bytes: 0,
        pending: nil,
        continuation: nil,
        abandoned_operation_identity: identity
    }
  end

  defp reply_upload(%{upload_waiter: nil} = handle, _), do: handle

  defp reply_upload(handle, result) do
    waiter = handle.upload_waiter
    send(waiter.pid, {:h3_upload_reply, handle.id, waiter.ref, result})
    %{handle | upload_waiter: nil}
  end

  @impl true
  def begin_cleanup(%{cleanup: :not_started} = handle, cancelled, deadline) do
    deadline = min(deadline, handle.deadline + Lifecycle.cleanup_headroom())
    handle = reply_upload(handle, {:error, :upload_closed})

    identity =
      if handle.pending,
        do: Map.get(handle.pending, :identity),
        else: if(handle.operation, do: Map.get(handle.operation, :public_identity))

    handle = %{
      handle
      | cleanup: :pending,
        cleanup_deadline: deadline,
        cleanup_cancelled: cancelled,
        terminal: true,
        pending: nil,
        continuation: nil,
        events: [],
        event_bytes: 0,
        upload_stopped: true,
        abandoned_operation_identity: identity || handle.abandoned_operation_identity
    }

    handle =
      if handle.operation == nil and handle.caller != nil and handle.caller.down == nil and
           handle.session != nil and handle.endpoint_down == nil do
        kind = if cancelled, do: :abort, else: :close
        handle = command(handle, kind, [handle.session], deadline)
        %{handle | cleanup_stop_due: min(deadline, Lifecycle.deadline(100))}
      else
        begin_stop(handle)
      end

    {:ok, tick(handle)}
  end

  def begin_cleanup(handle, _, _), do: {:ok, handle}

  @impl true
  def cleanup(%{cleanup: :not_started} = handle, cancelled) do
    {:ok, handle} =
      begin_cleanup(handle, cancelled, min(Lifecycle.deadline(1_000), handle.deadline + 1_000))

    cleanup(handle, cancelled)
  end

  def cleanup(handle, _) do
    handle = cleanup_progress(handle)

    cond do
      all_down?(handle) and cleanup_proof?(handle) and
          Lifecycle.remaining(handle.cleanup_deadline) > 0 ->
        {:ok, cancel_tick(%{handle | cleanup: :complete})}

      all_down?(handle) and cleanup_failed?(handle) ->
        {:error, {:cleanup_unconfirmed, cleanup_reason(handle)},
         cancel_tick(%{handle | cleanup: :failed})}

      true ->
        {:pending, tick(handle)}
    end
  end

  defp cleanup_progress(%{cleanup: cleanup} = handle) when cleanup in [:complete, :failed],
    do: handle

  defp cleanup_progress(handle) do
    handle =
      if handle.cleanup_stop_due != nil and Lifecycle.remaining(handle.cleanup_stop_due) == 0,
        do: begin_stop(handle, :fallback),
        else: handle

    handle =
      if handle.endpoint_down != nil or (handle.stop_result != nil and handle.stop_result != :ok),
        do: stop_owned(handle),
        else: handle

    if Lifecycle.remaining(handle.cleanup_deadline) == 0,
      do: stop_owned(handle, true),
      else: handle
  end

  defp begin_stop(handle, trigger \\ :immediate)

  defp begin_stop(%{stop_task: nil, endpoint: endpoint} = handle, trigger)
       when not is_nil(endpoint) do
    owner = handle.owner
    id = handle.id
    generation = handle.generation
    driver = handle.driver

    {pid, monitor} =
      :erlang.spawn_opt(
        fn ->
          guardian_monitor = Process.monitor(owner)
          result = driver.(Transport, :stop_endpoint, [endpoint])

          unless guardian_lost?(owner, guardian_monitor),
            do: send(owner, {:h3_stop_result, id, generation, self(), result})
        end,
        [:link, :monitor]
      )

    %{
      handle
      | stop_task: %{pid: pid, monitor: monitor, down: nil},
        cleanup_stop_due: nil,
        stop_trigger: trigger
    }
  end

  defp begin_stop(handle, _trigger), do: handle

  defp stop_owned(handle, expired \\ false) do
    handle =
      case handle.caller do
        %{pid: pid, down: nil} when handle.operation == nil and not expired ->
          unless handle.caller_stop_sent,
            do: send(pid, {:h3_stop_caller, handle.owner, handle.id, handle.generation})

          %{handle | caller_stop_sent: true}

        %{pid: pid, down: nil} ->
          Process.exit(pid, :kill)
          handle

        _ ->
          handle
      end

    Enum.each([if(expired, do: handle.bootstrap), if(expired, do: handle.stop_task)], fn
      %{pid: pid, down: nil} -> Process.exit(pid, :kill)
      _ -> :ok
    end)

    handle
  end

  defp all_down?(handle),
    do:
      Enum.all?([handle.bootstrap, handle.caller, handle.stop_task], fn
        nil -> true
        %{down: down} -> down != nil
      end)

  defp cleanup_proof?(%{endpoint: nil, bootstrap: %{down: :normal, result: {:error, _}}}),
    do: true

  defp cleanup_proof?(handle),
    do:
      handle.endpoint_down == :normal and
        (handle.stop_result == :ok or
           (handle.stop_task == nil and handle.endpoint_down == :normal))

  defp cleanup_failed?(handle),
    do:
      Lifecycle.remaining(handle.cleanup_deadline) == 0 or
        (handle.stop_result != nil and handle.stop_result != :ok) or
        (handle.endpoint_down != nil and handle.endpoint_down != :normal) or
        (handle.endpoint == nil and handle.bootstrap.down != nil) or
        (handle.stop_task != nil and handle.stop_task.down != nil and handle.stop_result == nil)

  defp cleanup_reason(handle),
    do: handle.stop_result || handle.endpoint_down || :termination_unconfirmed

  defp tick(handle, delay \\ 5)
  defp tick(%{cleanup: cleanup} = handle, _) when cleanup in [:complete, :failed], do: handle

  defp tick(%{tick: nil} = handle, delay),
    do: %{handle | tick: Process.send_after(handle.owner, {:h3_tick, handle.id}, delay)}

  defp tick(handle, _), do: handle

  defp cancel_tick(handle) do
    if handle.tick, do: Process.cancel_timer(handle.tick)
    %{handle | tick: nil}
  end

  defp bootstrap(owner, id, generation, options, driver, deadline) do
    monitor = Process.monitor(owner)
    if guardian_lost?(owner, monitor), do: exit(:normal)
    result = driver.(Transport, :client, [Keyword.put(options, :acceptor, owner)])

    case result do
      {:ok, %{pid: pid} = endpoint} when is_pid(pid) ->
        if guardian_lost?(owner, monitor) do
          driver.(Transport, :stop_endpoint, [endpoint])
        else
          send(owner, {:h3_endpoint, id, generation, self(), endpoint})

          receive do
            {:h3_adopt, ^id, ^generation} ->
              Process.unlink(pid)

              if guardian_lost?(owner, monitor),
                do: driver.(Transport, :stop_endpoint, [endpoint]),
                else: send(owner, {:h3_bootstrap_result, id, generation, self(), :ok})

            {:DOWN, ^monitor, :process, ^owner, _} ->
              driver.(Transport, :stop_endpoint, [endpoint])
          after
            Lifecycle.remaining(deadline) ->
              driver.(Transport, :stop_endpoint, [endpoint])
              exit(:adoption_timeout)
          end
        end

      {:error, reason} ->
        unless guardian_lost?(owner, monitor),
          do: send(owner, {:h3_bootstrap_result, id, generation, self(), {:error, reason}})
    end
  end

  defp caller(owner, id, generation, driver) do
    monitor = Process.monitor(owner)
    caller_loop(owner, monitor, id, generation, driver, false, 0)
  end

  defp caller_loop(owner, monitor, id, generation, driver, closed, sequence) do
    if guardian_lost?(owner, monitor), do: exit(:normal)
    closed = drain_hints(owner, monitor, id, generation, closed, 16)

    receive do
      {:DOWN, ^monitor, :process, ^owner, _} ->
        :ok

      {:h3_stop_caller, ^owner, ^id, ^generation} ->
        :ok

      {:h3_command, ^owner, ^id, ^generation, ref, next, kind, arguments, deadline}
      when kind in @operations and next == sequence + 1 ->
        if guardian_lost?(owner, monitor), do: exit(:normal)
        closed = drain_hints(owner, monitor, id, generation, closed, 16)

        arguments =
          if kind == :connect do
            [session, host, port, options] = arguments
            [session, host, port, Keyword.put(options, :consumer, self())]
          else
            arguments
          end

        result =
          if Lifecycle.remaining(deadline) == 0,
            do: {:error, :deadline_expired},
            else: driver.(Session, kind, arguments)

        closed = drain_hints(owner, monitor, id, generation, closed, 16)
        if guardian_lost?(owner, monitor), do: exit(:normal)
        send(owner, {:h3_result, id, generation, self(), ref, result})
        caller_loop(owner, monitor, id, generation, driver, closed, next)

      {:quic_closed, _, reason} ->
        closed = relay_closed(owner, id, generation, reason, closed)
        caller_loop(owner, monitor, id, generation, driver, closed, sequence)

      _ ->
        caller_loop(owner, monitor, id, generation, driver, closed, sequence)
    end
  end

  defp guardian_lost?(owner, monitor) do
    receive do
      {:DOWN, ^monitor, :process, ^owner, _} -> true
    after
      0 -> false
    end
  end

  defp drain_hints(owner, monitor, id, generation, closed, remaining) do
    if guardian_lost?(owner, monitor), do: exit(:normal)

    if remaining > 0 do
      receive do
        {:quic_ready, _, _} ->
          drain_hints(owner, monitor, id, generation, closed, remaining - 1)

        {:quic_closed, _, reason} ->
          closed = relay_closed(owner, id, generation, reason, closed)
          drain_hints(owner, monitor, id, generation, closed, remaining - 1)
      after
        0 -> closed
      end
    else
      :erlang.yield()
      closed
    end
  end

  defp relay_closed(_, _, _, _, true), do: true

  defp relay_closed(owner, id, generation, reason, false) do
    if :erlang.external_size(reason) > @field_bytes, do: exit(:closed_reason_too_large)
    send(owner, {:h3_closed, id, generation, self(), reason})
    true
  end
end
