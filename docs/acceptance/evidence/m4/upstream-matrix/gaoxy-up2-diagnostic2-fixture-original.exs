defmodule Gaoxy.UpstreamMatrixEndpoint do
  @behaviour Gaoxy.HTTP.Endpoint

  def init(options) do
    configs =
      for {name, config} <- options.configs, into: %{} do
        {:ok, validated} = Gaoxy.Proxy.HTTP.init(config)
        {name, validated}
      end

    {:ok, %{options | configs: configs}}
  end

  def call(exchange, options) do
    [id] = for {"x-matrix-id", value} <- exchange.request.headers, do: value
    [_, "matrix", authority | _] = String.split(exchange.request.path, "/")
    config = Map.fetch!(options.configs, authority)
    started = Gaoxy.Lifecycle.now()
    send(options.observer, {:watch, self(), id})

    receive do
      {:watched, ^id} -> :ok
    after
      1_000 -> raise "matrix owner trace registration deadline"
    end

    result = Gaoxy.Proxy.HTTP.call(exchange, config)
    :erlang.trace(self(), false, [:receive])
    reference = :erlang.trace_delivered(self())

    receive do
      {:trace_delivered, _, ^reference} -> :ok
    after
      1_000 -> raise "matrix owner trace delivery deadline"
    end

    send(options.observer, {:completed, id, result_summary(result), started})
    result
  end

  defp result_summary({:ok, exchange}),
    do: %{outcome: "ok", response: inspect(exchange.response)}

  defp result_summary({:error, reason, _}),
    do: %{outcome: "error", reason: inspect(reason, limit: 32, printable_limit: 512)}
end

defmodule Gaoxy.UpstreamMatrixFixture do
  @client Gaoxy.Proxy.HTTP3SessionClient
  @fields [
    :active,
    :retained_bytes,
    :cleanup_pending,
    :cleanup_failed,
    :retained_high_water,
    :queued_items,
    :queued_bytes
  ]

  def emit(data), do: IO.puts("GAOXY_UPSTREAM_MATRIX_FIXTURE " <> JSON.encode!(data))

  def run do
    directory = System.fetch_env!("GAOXY_HTTP3_CERT_DIR")
    a = System.fetch_env!("GAOXY_UPSTREAM_URL_A")
    b = System.fetch_env!("GAOXY_UPSTREAM_URL_B")
    ca = System.fetch_env!("GAOXY_UPSTREAM_CA_A")
    other_ca = System.fetch_env!("GAOXY_UPSTREAM_CA_B")

    base = %{
      upstream: a,
      upstream_protocol: :http3,
      cacertfile: ca,
      opening_timeout: 5_000,
      max_lifetime: 5_000,
      write_timeout: 5_000
    }

    configs = %{
      "a" => base,
      "b" => %{base | upstream: b, cacertfile: other_ca},
      "wrong-ca" => %{base | cacertfile: other_ca},
      "wrong-host" => %{base | upstream: String.replace(a, "localhost", "127.0.0.1")},
      "opening" => %{base | opening_timeout: 500},
      "total" => %{base | max_lifetime: 1_500}
    }

    # These are actual production-policy rejections, before endpoint allocation.
    {:error, :invalid_http_proxy_options} = Gaoxy.Proxy.HTTP.init(Map.delete(base, :cacertfile))

    {:error, :invalid_http_proxy_options} =
      Gaoxy.Proxy.HTTP.init(Map.put(base, :connect_address, {127, 0, 0, 1}))

    {:ok, selected} = Gaoxy.Proxy.HTTP.init(base)
    true = selected.client == @client
    true = Code.ensure_loaded?(@client)
    table = :ets.new(:upstream_matrix_observations, [:set, :public])
    observer = spawn_link(fn -> observe(table, %{}, %{}, %{}) end)
    # Trace only this Gaoxy adapter entry; never SDK calls or opaque Session terms.
    1 = :erlang.trace_pattern({@client, :open, 1}, true, [])
    :erlang.trace(:new_processes, true, [:call, {:tracer, observer}])
    tls = %{certfile: Path.join(directory, "cert.pem"), keyfile: Path.join(directory, "key.pem")}

    specs =
      for protocol <- [:h1, :h2, :h3], sibling <- [false, true] do
        id = "#{protocol}#{if sibling, do: "_sibling", else: ""}"

        options = [
          id: id,
          ip: {127, 0, 0, 1},
          port: 0,
          endpoint: {Gaoxy.UpstreamMatrixEndpoint, %{configs: configs, observer: observer}},
          tls: tls,
          limits: %{max_bytes: 536_870_912, max_active: 64},
          http_limits: %{request_timeout: 5_000, write_timeout: 5_000}
        ]

        {:ok, spec} =
          case protocol do
            :h3 ->
              Gaoxy.HTTP.HTTP3.service_spec(options)

            :h1 ->
              Gaoxy.HTTP.service_spec(options ++ [transport: :tls, protocols: [:http1]])

            :h2 ->
              Gaoxy.HTTP.service_spec(
                options ++
                  [transport: :tls, protocols: [:http2], h2_limits: %{receive_window: 16_384}]
              )
          end

        spec
      end

    {:ok, runtime} = Gaoxy.start_link(services: specs)

    ports =
      Map.new(specs, fn spec ->
        {:ok, {_, port}} = Gaoxy.info(runtime, spec.id).local
        {spec.id, port}
      end)

    emit(%{
      event: "ready",
      ports: ports,
      elixir: System.version(),
      otp: System.otp_release(),
      http_fetch: to_string(Application.spec(:http_fetch, :vsn)),
      absent_trust: "invalid_http_proxy_options",
      address_policy: "invalid_http_proxy_options",
      opening_timeout_ms: 500,
      total_timeout_ms: 1_500,
      normal_total_timeout_ms: 5_000,
      cleanup_headroom_ms: 1_000
    })

    loop(runtime, ports, observer, table)
  end

  defp observe(table, owners, guardians, monitors) do
    {:message_queue_len, messages} = Process.info(self(), :message_queue_len)
    true = messages <= 256

    Process.put(
      :matrix_mailbox_high_water,
      max(messages, Process.get(:matrix_mailbox_high_water, 0))
    )

    receive do
      {:watch, owner, id} ->
        :ets.insert_new(table, {id, %{id: id, errors: [], public_closed: [], events: []}})
        :erlang.trace(owner, true, [:receive, {:tracer, self()}])
        reference = Process.monitor(owner)
        send(owner, {:watched, id})

        observe(
          table,
          Map.put(owners, owner, id),
          guardians,
          Map.put(monitors, reference, {:owner, id})
        )

      {:trace, guardian, :call, {@client, :open, [options]}} ->
        [id] = for {"x-matrix-id", value} <- options.headers, do: value
        true = byte_size(id) <= 128

        flags =
          if String.ends_with?(id, "-tiny_window_1mib"),
            do: [:receive, :send, :monotonic_timestamp],
            else: [:receive]

        :erlang.trace(guardian, true, flags ++ [{:tracer, self()}])
        reference = Process.monitor(guardian)

        update(table, id, fn receipt ->
          Map.merge(receipt, %{client: inspect(@client), guardian: inspect(guardian)})
        end)

        observe(
          table,
          owners,
          Map.put(guardians, guardian, id),
          Map.put(monitors, reference, {:guardian, id})
        )

      {:trace, owner, :receive, {:gaoxy_proxy_http, _, {:error, reason}}} ->
        if id = owners[owner],
          do: update(table, id, &%{&1 | errors: append(&1.errors, bounded(reason))})

        observe(table, owners, guardians, monitors)

      {:trace, guardian, :receive, {:h3_closed, _, _, _, reason}} ->
        if id = guardians[guardian],
          do: update(table, id, &%{&1 | public_closed: append(&1.public_closed, bounded(reason))})

        observe(table, owners, guardians, monitors)

      {:trace_ts, guardian, :receive, {:h3_closed, _, _, _, reason}, _timestamp} ->
        if id = guardians[guardian],
          do: update(table, id, &%{&1 | public_closed: append(&1.public_closed, bounded(reason))})

        observe(table, owners, guardians, monitors)

      {:trace_ts, guardian, :receive, message, timestamp} ->
        observe_upload(table, guardians, guardian, :receive, message, timestamp)
        observe(table, owners, guardians, monitors)

      {:trace_ts, guardian, :send, message, _destination, timestamp} ->
        observe_upload(table, guardians, guardian, :send, message, timestamp)
        observe(table, owners, guardians, monitors)

      {:trace_ts, _, :send_to_non_existing_process, _, _, _} ->
        observe(table, owners, guardians, monitors)

      {:trace, owner, :receive, {:gaoxy_proxy_http, _, event}} ->
        kind = if is_tuple(event), do: elem(event, 0), else: event

        if id = owners[owner],
          do: update(table, id, &%{&1 | events: Enum.take(&1.events ++ [to_string(kind)], -16)})

        observe(table, owners, guardians, monitors)

      {:completed, id, result, started} ->
        update(
          table,
          id,
          &Map.merge(&1, %{result: result, elapsed_ms: Gaoxy.Lifecycle.now() - started})
        )

        observe(table, Map.reject(owners, fn {_, value} -> value == id end), guardians, monitors)

      {:DOWN, reference, :process, pid, reason} ->
        Process.delete({:matrix_upload_timing, pid})

        case monitors[reference] do
          {:guardian, id} -> update(table, id, &Map.put(&1, :guardian_down, bounded(reason)))
          {:owner, id} -> update(table, id, &Map.put(&1, :owner_down, bounded(reason)))
        end

        observe(
          table,
          Map.delete(owners, pid),
          Map.delete(guardians, pid),
          Map.delete(monitors, reference)
        )

      {:flush, caller, reference} ->
        send(
          caller,
          {:flushed, reference, map_size(guardians), Process.get(:matrix_mailbox_high_water, 0)}
        )

        observe(table, owners, guardians, monitors)

      {:stop, caller} ->
        :erlang.trace(:new_processes, false, [:call])
        :erlang.trace_pattern({@client, :open, 1}, false, [])

        for {owner, _} <- owners,
            Process.alive?(owner),
            do: :erlang.trace(owner, false, [:receive])

        for {guardian, _} <- guardians,
            Process.alive?(guardian),
            do: :erlang.trace(guardian, false, [:receive, :send, :monotonic_timestamp])

        send(caller, :observer_stopped)

      {:trace, _, :receive, _} ->
        # Unselected messages are discarded without inspecting SDK state.
        observe(table, owners, guardians, monitors)
    end
  end

  # Observe only Gaoxy envelopes. Session values and command arguments stay opaque.
  defp observe_upload(table, guardians, guardian, direction, message, timestamp) do
    with id when is_binary(id) <- guardians[guardian],
         event when is_map(event) <- upload_event(direction, message) do
      event = Map.put(event, :at_us, System.convert_time_unit(timestamp, :native, :microsecond))
      event = upload_timing(guardian, direction, message, event)

      update(table, id, fn receipt ->
        trace =
          Map.get(receipt, :upload_trace, %{counts: %{}, first: [], last: [], upload_bytes: 0})

        key = event.kind <> ":" <> Map.get(event, :category, Map.get(event, :operation, ""))

        trace = %{
          trace
          | counts: Map.update(trace.counts, key, 1, &(&1 + 1)),
            first: if(length(trace.first) < 8, do: trace.first ++ [event], else: trace.first),
            last: Enum.take(trace.last ++ [event], -8),
            upload_bytes: trace.upload_bytes + Map.get(event, :bytes, 0)
        }

        trace =
          if event.kind == "upload" and Map.has_key?(event, :bytes) do
            sizes = Map.get(trace, :upload_sizes, %{})
            size = Integer.to_string(event.bytes)

            if Map.has_key?(sizes, size) or map_size(sizes) < 16,
              do: Map.put(trace, :upload_sizes, Map.update(sizes, size, 1, &(&1 + 1))),
              else: Map.update(trace, :other_upload_sizes, 1, &(&1 + 1))
          else
            trace
          end

        trace =
          Enum.reduce(
            [
              :command_us,
              :upload_reply_us,
              :upload_interval_us,
              :ingress_gap_us,
              :polls_since_upload
            ],
            trace,
            fn metric, acc ->
              if Map.has_key?(event, metric) do
                name = Atom.to_string(metric)
                name = if metric == :command_us, do: name <> ":" <> event.operation, else: name
                metrics = Map.get(acc, :metrics, %{})

                Map.put(
                  acc,
                  :metrics,
                  Map.update(
                    metrics,
                    name,
                    measurement(event[metric]),
                    &measure(&1, event[metric])
                  )
                )
              else
                acc
              end
            end
          )

        trace =
          case event do
            %{poll_events: events} ->
              totals = Map.get(trace, :poll_events, %{})
              Map.put(trace, :poll_events, Map.merge(totals, events, fn _, a, b -> a + b end))

            _ ->
              trace
          end

        Map.put(receipt, :upload_trace, trace)
      end)
    else
      _ -> :ok
    end
  end

  # One scalar/ref context per selected guardian, never a Session or message history.
  defp upload_timing(guardian, direction, message, %{kind: kind} = event)
       when kind in ["command", "result", "upload", "upload_reply"] do
    key = {:matrix_upload_timing, guardian}

    context =
      Process.get(key, %{command: nil, upload: nil, last_upload: nil, last_reply: nil, polls: 0})

    {event, context} = timing_event(direction, message, event, context)
    Process.put(key, context)
    event
  end

  defp upload_timing(_, _, _, event), do: event

  defp timing_event(:send, {:h3_command, _, _, _, ref, _, operation, _, _}, event, context) do
    polls = context.polls + if(operation == :poll, do: 1, else: 0)
    {event, %{context | command: {ref, operation, event.at_us}, polls: polls}}
  end

  defp timing_event(
         :receive,
         {:h3_result, _, _, _, ref, result},
         event,
         %{command: {ref, operation, started}} = context
       ) do
    event =
      Map.merge(event, %{operation: Atom.to_string(operation), command_us: event.at_us - started})

    event =
      if operation == :poll,
        do: Map.put(event, :poll_events, poll_event_counts(result)),
        else: event

    {event, %{context | command: nil}}
  end

  defp timing_event(:receive, {:h3_upload, _, _, ref, :data, _, _}, event, context) do
    event = Map.put(event, :polls_since_upload, context.polls)

    event =
      if context.last_upload,
        do: Map.put(event, :upload_interval_us, event.at_us - context.last_upload),
        else: event

    event =
      if context.last_reply,
        do: Map.put(event, :ingress_gap_us, event.at_us - context.last_reply),
        else: event

    {event,
     %{context | upload: {ref, event.at_us}, last_upload: event.at_us, last_reply: nil, polls: 0}}
  end

  defp timing_event(:receive, {:h3_upload, _, _, ref, :finish, _, _}, event, context),
    do: {event, %{context | upload: {ref, event.at_us}}}

  defp timing_event(
         :send,
         {:h3_upload_reply, _, ref, _},
         event,
         %{upload: {ref, started}} = context
       ),
       do:
         {Map.put(event, :upload_reply_us, event.at_us - started),
          %{context | upload: nil, last_reply: event.at_us}}

  defp timing_event(_, _, event, context), do: {event, context}

  defp measurement(value), do: %{count: 1, total: value, min: value, max: value}

  defp measure(stats, value),
    do: %{
      count: stats.count + 1,
      total: stats.total + value,
      min: min(stats.min, value),
      max: max(stats.max, value)
    }

  # Poll results are public event lists; inspect tags only, not metadata or Session.
  defp poll_event_counts({:ok, _, events}) when is_list(events),
    do:
      Enum.reduce(events, %{}, fn event, counts ->
        Map.update(counts, poll_event_kind(event), 1, &(&1 + 1))
      end)

  defp poll_event_counts(_), do: %{}

  defp poll_event_kind(:writable), do: "writable"
  defp poll_event_kind(:ready), do: "ready"
  defp poll_event_kind({:writable, _}), do: "writable"
  defp poll_event_kind({:ready, _}), do: "ready"
  defp poll_event_kind({:settings, _}), do: "settings"
  defp poll_event_kind({:headers, _, _}), do: "headers"
  defp poll_event_kind({:data, _, _}), do: "data"
  defp poll_event_kind({:trailers, _, _}), do: "trailers"
  defp poll_event_kind({:done, _}), do: "done"
  defp poll_event_kind({:informational, _, _, _}), do: "informational"
  defp poll_event_kind(_), do: "other"

  defp upload_event(:receive, {:h3_upload, _, _, _, :data, bytes, _}) when is_binary(bytes),
    do: %{kind: "upload", category: "data", bytes: byte_size(bytes)}

  defp upload_event(:receive, {:h3_upload, _, _, _, :finish, _, _}),
    do: %{kind: "upload", category: "finish"}

  defp upload_event(:receive, {:h3_tick, _}), do: %{kind: "tick"}

  defp upload_event(:receive, {:h3_upload_cancel, _, _}),
    do: %{kind: "upload", category: "cancel"}

  defp upload_event(:receive, {:h3_result, _, _, _, _, result}),
    do: %{kind: "result", category: result_category(result)}

  defp upload_event(:send, {:h3_command, _, _, _, _, _, operation, _, _})
       when is_atom(operation),
       do: %{kind: "command", operation: Atom.to_string(operation)}

  defp upload_event(:send, {:h3_upload_reply, _, _, result}),
    do: %{kind: "upload_reply", category: result_category(result)}

  defp upload_event(_, _), do: nil

  defp result_category({:ok, _}), do: "ok"
  defp result_category({:ok, _, _}), do: "ok"
  defp result_category({:blocked, _, _}), do: "blocked"
  defp result_category({:unknown, _, _}), do: "unknown"
  defp result_category({:error, _}), do: "error"
  defp result_category({:error, _, _}), do: "error"
  defp result_category(:ready), do: "ready"
  defp result_category(:pending), do: "pending"
  defp result_category(:ok), do: "ok"
  defp result_category(_), do: "other"

  defp bounded(reason) do
    true = :erlang.external_size(reason) <= 4_096
    inspect(reason, limit: 64, printable_limit: 1_024)
  end

  defp append(values, value) do
    true = length(values) < 16
    values ++ [value]
  end

  defp update(table, id, operation) do
    [{^id, receipt}] = :ets.lookup(table, id)
    :ets.insert(table, {id, operation.(receipt)})
  end

  defp loop(runtime, ports, observer, table) do
    case IO.gets("") do
      :eof ->
        stop(runtime, ports, observer)

      line ->
        case JSON.decode!(line) do
          %{"command" => "sample"} ->
            reference = make_ref()
            send(observer, {:flush, self(), reference})

            receive do
              {:flushed, ^reference, guardians, messages} ->
                true = messages <= 256

                emit(%{
                  event: "sample",
                  admission:
                    Map.new(ports, fn {id, _} ->
                      {id, Map.take(Gaoxy.status(runtime, id), @fields)}
                    end),
                  receipts: Enum.map(:ets.tab2list(table), &elem(&1, 1)),
                  observed_guardians: guardians,
                  observer_mailbox: messages,
                  session_children:
                    DynamicSupervisor.count_children(Gaoxy.Proxy.SessionSupervisor).active
                })
            after
              1_000 -> raise "matrix observer sample deadline"
            end

            loop(runtime, ports, observer, table)

          %{"command" => "stop"} ->
            stop(runtime, ports, observer)
        end
    end
  end

  defp stop(runtime, ports, observer) do
    reference = Process.monitor(observer)
    send(observer, {:stop, self()})

    receive do
      :observer_stopped -> :ok
    after
      1_000 -> raise "matrix observer stop deadline"
    end

    receive do
      {:DOWN, ^reference, :process, ^observer, :normal} -> :ok
    after
      1_000 -> raise "matrix observer DOWN missing"
    end

    started = Gaoxy.Lifecycle.now()
    monitor = Process.monitor(runtime)
    :ok = Gaoxy.stop(runtime, 5_000)

    receive do
      {:DOWN, ^monitor, :process, ^runtime, :normal} -> :ok
    after
      1_000 -> raise "matrix runtime DOWN missing"
    end

    for {id, port} <- ports do
      if String.starts_with?(id, "h3") do
        {:ok, socket} = :gen_udp.open(port, [:binary, ip: {127, 0, 0, 1}])
        :ok = :gen_udp.close(socket)
      else
        {:ok, socket} = :gen_tcp.listen(port, [:binary, ip: {127, 0, 0, 1}, reuseaddr: true])
        :ok = :gen_tcp.close(socket)
      end
    end

    emit(%{
      event: "stopped",
      runtime_down: true,
      observer_down: true,
      ports_rebound: true,
      elapsed_ms: Gaoxy.Lifecycle.now() - started
    })
  end
end

Gaoxy.UpstreamMatrixFixture.run()
