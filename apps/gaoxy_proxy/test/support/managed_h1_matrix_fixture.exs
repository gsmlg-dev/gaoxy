defmodule Gaoxy.Proxy.ManagedH1MatrixFixture do
  @moduledoc false
  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Proxy.{GroupEndpoint, UpstreamGroups}
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports

  @timeout 5_000
  @python "/tmp/gaoxy-m3-h2-soak-venv/bin/python"
  @root Path.expand("../../../..", __DIR__)

  defmodule NativeResultEndpoint do
    @moduledoc false
    @behaviour Gaoxy.HTTP.Endpoint

    @impl true
    def init({module, options, parent, peer}) do
      with {:ok, config} <- module.init(options), do: {:ok, {module, config, parent, peer}}
    end

    @impl true
    def resources({module, config, _parent, _peer}), do: module.resources(config)

    @impl true
    def call(exchange, {module, config, parent, peer}) do
      result = module.call(exchange, config)

      case result do
        {:error, reason, %{response: response}} ->
          Gaoxy.Proxy.ManagedH1MatrixFixture.native_result(
            parent,
            peer,
            exchange,
            reason,
            response
          )

        _ ->
          :ok
      end

      result
    end
  end

  # Explicit ownership: the caller keeps the fixture, its event queue and the
  # original completion. Neither adapter requires ExUnit callbacks.
  def start(row, overrides \\ %{})

  def start(
        %{"mount" => mount, "downstream" => downstream, "upstream" => upstream} = row,
        overrides
      ) do
    directory =
      Path.join(System.tmp_dir!(), "gaoxy-h1-matrix-#{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)
    wire = if upstream == "tls", do: :ssl, else: :gen_tcp

    try do
      options = [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true]

      downstream_tls = Map.get(row, "downstream_tls", false)

      if upstream == "tls" or downstream_tls do
        {log, 0} =
          System.cmd("bash", [Path.join(@root, "scripts/generate-fixtures.sh"), directory],
            stderr_to_stdout: true
          )

        true = String.contains?(log, "Certificate tool:")
      end

      options =
        if upstream == "tls",
          do:
            options ++
              [
                certfile: Path.join(directory, "cert.pem"),
                keyfile: Path.join(directory, "key.pem")
              ],
          else: options

      {:ok, listener} = wire.listen(0, options)

      {:ok, {_, port}} =
        if wire == :ssl, do: :ssl.sockname(listener), else: :inet.sockname(listener)

      parent = self()
      peer = spawn(fn -> accept_loop(wire, listener, parent, %{}, 0) end)
      key = make_ref()
      Process.put({__MODULE__, key, :events}, [])

      f = %{
        key: key,
        instance: nil,
        peer: peer,
        wire: wire,
        listener: listener,
        directory: directory,
        mount: mount,
        downstream: downstream,
        upstream: upstream,
        downstream_tls: downstream_tls
      }

      Process.put({__MODULE__, :starting}, f)
      {:ok, instance} = Gaoxy.start_link()
      Process.unlink(instance)
      f = %{f | instance: instance}
      Process.put({__MODULE__, :starting}, f)

      {:ok, owner} =
        Transports.start_link(
          instance: instance,
          limits: %{
            max_resources: 2,
            max_pins: 32,
            max_request_tokens: 64,
            max_owned_payload_bytes: 4_194_304
          }
        )

      Process.unlink(owner)
      trust = if wire == :ssl, do: certificates(Path.join(directory, "ca.pem")), else: nil
      origin = "#{if wire == :ssl, do: "https://localhost", else: "http://127.0.0.1"}:#{port}"
      source = %{origin: origin, connect_address: {127, 0, 0, 1}, trust: trust}
      {:ok, handle, preparation} = Transports.prepare(owner, source, self(), deadline())
      {:ok, _baseline} = Resources.pin_many([handle], self(), :baseline, deadline())
      :ok = Resources.release(preparation)
      f = Map.merge(f, %{owner: owner, handle: handle, origin: origin, groups: nil, group: nil})
      Process.put({__MODULE__, :starting}, f)

      {f, endpoint} =
        if mount == "group" do
          {:ok, groups} = UpstreamGroups.start_link(instance: instance, limits: %{max_probes: 1})
          Process.unlink(groups)

          {:ok, compiled} =
            UpstreamGroups.compile(%{
              id: "matrix",
              members: [%{id: "member", upstream: origin, transport: handle}],
              health: %{
                path: "/health",
                interval: 60_000,
                stale_after: 120_000,
                timeout: 2_000,
                jitter: 0,
                recovery_threshold: 1
              }
            })

          {:ok, group, preparation} = UpstreamGroups.prepare(groups, compiled, self(), deadline())

          {:ok, _baseline} =
            Resources.pin_many(UpstreamGroups.resources(group), self(), :baseline, deadline())

          :ok = Resources.release(preparation)
          f = %{f | groups: groups, group: group}
          Process.put({__MODULE__, :starting}, f)

          eventually(fn ->
            status = UpstreamGroups.status(group)

            status.probes == 0 and
              Enum.all?(status.members, &(&1.health == :healthy and not &1.probe)) and
              match?({:ok, %{request_tokens: 0}}, Transports.status(owner))
          end)

          {f, {GroupEndpoint, %{group: group}}}
        else
          {f, {Gaoxy.Proxy.HTTP, %{upstream: origin, transport: handle}}}
        end

      {endpoint_module, endpoint_config} = endpoint

      endpoint = {
        Map.get(overrides, :endpoint_module, endpoint_module),
        Map.merge(endpoint_config, Map.get(overrides, :endpoint, %{}))
      }

      endpoint =
        if downstream == "h1" and not Map.has_key?(overrides, :endpoint_module) do
          {module, config} = endpoint
          {NativeResultEndpoint, {module, config, parent, peer}}
        else
          endpoint
        end

      options = [
        id: :http,
        endpoint: endpoint,
        limits: %{max_bytes: 16_777_216},
        http_limits: %{request_timeout: 10_000, write_timeout: 2_000}
      ]

      options =
        if downstream == "h2" do
          Keyword.merge(options,
            protocols: [:http2],
            h2c: if(downstream_tls, do: :disabled, else: :prior_knowledge),
            limits: %{max_bytes: 67_108_864},
            http_limits:
              Map.merge(options[:http_limits], %{
                max_body_bytes: 1_048_576,
                max_header_bytes: 8_192,
                max_read_chunk: 16_384,
                max_buffer_bytes: 32_768
              }),
            h2_limits: %{
              max_streams: 1,
              max_frame: 16_384,
              max_header_block: 4_096,
              table_size: 1_024,
              receive_window: 16_384
            }
          )
        else
          options
        end

      options =
        if downstream_tls,
          do:
            options ++
              [
                transport: :tls,
                tls: %{
                  certfile: Path.join(directory, "cert.pem"),
                  keyfile: Path.join(directory, "key.pem")
                }
              ],
          else: options

      {:ok, spec} = Gaoxy.HTTP.service_spec(options)
      {:ok, _} = Gaoxy.add(instance, spec)
      {:ok, {_, downstream_port}} = Gaoxy.info(instance, :http).local
      f = Map.put(f, :port, downstream_port)
      Process.delete({__MODULE__, :starting})
      f
    rescue
      error ->
        if f = Process.delete({__MODULE__, :starting}), do: stop(f)
        File.rm_rf!(directory)
        reraise error, __STACKTRACE__
    end
  end

  def command(f, %{"connection" => connection, "request" => request} = command) do
    send(f.peer, {:command, connection, request, command})
    event(f, %{"event" => "command", "connection" => connection, "request" => request})
  end

  def dispatch_command(f, %{"connection" => connection, "request" => request} = command) do
    send(f.peer, {:command, connection, request, command})
    :ok
  end

  def event(f, selector, timeout \\ @timeout) do
    queued = Process.get({__MODULE__, f.key, :events}, [])

    case Enum.split_while(queued, &(&1["event"] != "failure" and not selected?(&1, selector))) do
      {_before, [%{"event" => "failure"} = value | _rest]} ->
        raise "#{inspect(value)} queued_fixture_events=#{inspect(failure_events(f), limit: :infinity)}"

      {before, [value | rest]} ->
        Process.put({__MODULE__, f.key, :events}, before ++ rest)
        value

      _ ->
        monitor = Process.monitor(f.peer)

        try do
          next_event(f, selector, System.monotonic_time(:millisecond) + timeout, monitor)
        after
          Process.demonitor(monitor, [:flush])
        end
    end
  end

  defp next_event(f, selector, expires, monitor) do
    remaining = max(0, expires - System.monotonic_time(:millisecond))

    receive do
      {:matrix_peer, peer, %{"event" => "failure"} = value} when peer == f.peer ->
        raise "#{inspect(value)} queued_fixture_events=#{inspect(failure_events(f), limit: :infinity)}"

      {:matrix_peer, peer, value} when peer == f.peer ->
        if selected?(value, selector) do
          value
        else
          key = {__MODULE__, f.key, :events}
          Process.put(key, Process.get(key, []) ++ [value])
          next_event(f, selector, expires, monitor)
        end

      {:DOWN, ^monitor, :process, _, reason} ->
        raise "managed-H1 peer exited before #{inspect(selector)}: #{inspect(reason)}"
    after
      remaining -> raise "managed-H1 event deadline: #{inspect(selector)}"
    end
  end

  defp failure_events(f) do
    queued = Process.get({__MODULE__, f.key, :events}, [])

    summaries =
      queued
      |> Stream.filter(
        &(&1["event"] in ["accepted", "request", "upload_prefix", "upload_end", "command"])
      )
      |> Enum.take(16)
      |> Enum.map(fn value ->
        Map.put(diagnostic_fields(value), "event", value["event"])
      end)

    %{
      "events" => summaries,
      "total" => length(queued),
      "truncated" => length(queued) > length(summaries)
    }
  end

  defp failure_diagnostic(f) do
    key = {__MODULE__, f.key, :events}
    queued = Process.get(key, [])
    {additional, cap_reached} = diagnostic_messages(f.peer, [], 0)
    observed = queued ++ additional
    Process.put(key, observed)

    summaries =
      observed
      |> Stream.filter(
        &(&1["event"] in [
            "accepted",
            "request",
            "upload_prefix",
            "upload_end",
            "command",
            "failure",
            "joined",
            "peer_terminal",
            "worker_terminal",
            "local_socket_close",
            "native_result"
          ])
      )
      |> Enum.take(32)
      |> Enum.map(fn value ->
        Map.merge(
          diagnostic_fields(value),
          Map.take(value, [
            "event",
            "peer_at_us",
            "phase",
            "terminal_label",
            "method_label",
            "route_label",
            "outcome",
            "response_class"
          ])
        )
      end)

    %{
      "event" => "failure_diagnostic",
      "events" => summaries,
      "observed_total" => length(observed),
      "truncated" => length(observed) > length(summaries),
      "additional_cap_reached" => cap_reached
    }
  end

  defp diagnostic_messages(_peer, reversed, 32), do: {Enum.reverse(reversed), true}

  defp diagnostic_messages(peer, reversed, count) do
    receive do
      {:matrix_peer, ^peer, value} -> diagnostic_messages(peer, [value | reversed], count + 1)
    after
      0 -> {Enum.reverse(reversed), false}
    end
  end

  defp diagnostic_fields(value) do
    Enum.reduce(
      [
        {"method", "method_label", %{"POST" => "POST", "DELETE" => "DELETE"}},
        {"target", "route_label", %{"/temporal" => "temporal", "/trailers" => "trailers"}},
        {"action", "action_label", %{"send" => "send", "continue_upload" => "continue_upload"}}
      ],
      Map.take(value, ["connection", "request", "ended"]),
      fn {key, label, allowed}, fields ->
        case Map.fetch(value, key) do
          {:ok, raw} -> Map.put(fields, label, Map.get(allowed, raw, "other"))
          :error -> fields
        end
      end
    )
  end

  def native_result(parent, peer, exchange, reason, response) do
    fields =
      diagnostic_fields(%{
        "method" => exchange.request.method,
        "target" => exchange.request.path
      })

    outcome =
      case reason do
        :closed -> "closed"
        :timeout -> "timeout"
        _ -> "other"
      end

    response_class =
      case response do
        {:fixed_stream, 0} -> "fixed_zero"
        {:fixed_stream, _} -> "fixed_remaining"
        :bodyless_stream -> "bodyless"
        :chunked -> "chunked"
        _ -> "other"
      end

    emit(
      parent,
      peer,
      Map.merge(fields, %{
        "event" => "native_result",
        "outcome" => outcome,
        "response_class" => response_class
      })
    )
  end

  defp selected?(value, selector),
    do: Enum.all?(selector, fn {key, expected} -> value[key] == expected end)

  def pending(f) do
    [{token, hold}] = Map.to_list(:sys.get_state(f.owner).tokens)
    %HTTP.RequestCompletion{} = completion = hold.completion
    guardian = hold.guardian
    state = :sys.get_state(guardian)
    true = state.transport_selection == {f.handle, token}
    true = state.client.completion(state.original_request) == completion
    true = state.token != token
    true = Enum.all?(state.transport_pins, &(&1.holder == guardian and &1.kind == :request))
    [_] = state.transport_pins
    {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)

    group_token =
      if f.group do
        {group, group_token} = state.selection
        true = group == f.group
        true = group_token != token and group_token != state.token
        true = :sys.get_state(f.groups).tokens[group_token].completion == completion
        group_token
      else
        nil = state.selection
      end

    binding = %{
      guardian: guardian,
      original_request: state.original_request,
      completion: completion,
      transport_token: token,
      group_token: group_token,
      session_token: state.token,
      transport_pins: state.transport_pins
    }

    key = {__MODULE__, f.key, :binding}

    if original = Process.get(key),
      do: true = original == binding,
      else: Process.put(key, binding)

    %{
      "pending" => true,
      "identity" => Map.new(binding, fn {k, v} -> {Atom.to_string(k), identity(v)} end),
      "transport" => public_status(f),
      "service" => service_status(f)
    }
  end

  def clean(f) do
    receipt = request_clean(f)
    baseline = if f.group, do: 2, else: 1

    eventually(fn ->
      match?(
        %{active: 0, cleanup_pending: 0, retained_bytes: 0, cleanup_failed: nil},
        Gaoxy.status(f.instance, :http)
      ) and
        match?(
          {:ok, %{request_tokens: 0, helpers: 0, pins: ^baseline}},
          Transports.status(f.owner)
        ) and
        (is_nil(f.group) or UpstreamGroups.status(f.group).inflight == 0)
    end)

    true =
      Enum.all?(:sys.get_state(f.owner).pins, fn {_, held} -> held.public.kind == :baseline end)

    Map.merge(receipt, %{"transport" => public_status(f), "service" => service_status(f)})
  end

  def request_clean(f) do
    binding = Process.get({__MODULE__, f.key, :binding})
    if binding, do: :ok = HTTP.RequestCompletion.await(binding.completion, @timeout)

    eventually(fn ->
      match?({:ok, %{request_tokens: 0, helpers: 0}}, Transports.status(f.owner)) and
        (is_nil(f.group) or UpstreamGroups.status(f.group).inflight == 0)
    end)

    Process.delete({__MODULE__, f.key, :binding})

    %{
      "completion_joined" => true,
      "identity" =>
        if(binding,
          do: Map.new(binding, fn {k, v} -> {Atom.to_string(k), identity(v)} end),
          else: nil
        ),
      "transport" => public_status(f),
      "service" => service_status(f)
    }
  end

  defp public_status(f) do
    {:ok, status} = Transports.status(f.owner)

    Map.new(
      Map.take(status, [:request_tokens, :helpers, :pins, :resources, :reserved_connections]),
      fn {k, v} -> {Atom.to_string(k), v} end
    )
  end

  defp service_status(f),
    do:
      Map.new(
        Map.take(Gaoxy.status(f.instance, :http), [
          :active,
          :cleanup_pending,
          :retained_bytes,
          :cleanup_failed
        ]),
        fn {k, v} -> {Atom.to_string(k), v} end
      )

  def stop(f, timeout \\ 10_000) do
    # Stop the embedding first so worker EOF is the normal socket termination.
    monitor = Process.monitor(f.peer)
    expires = System.monotonic_time(:millisecond) + timeout

    try do
      result =
        if is_pid(f.instance) and Process.alive?(f.instance),
          do:
            Gaoxy.stop(
              f.instance,
              min(@timeout, max(0, expires - System.monotonic_time(:millisecond)))
            ),
          else: :ok

      :ok = f.wire.close(f.listener)

      joined =
        event(f, %{"event" => "joined"}, max(0, expires - System.monotonic_time(:millisecond)))

      receive do
        {:DOWN, ^monitor, :process, _, :normal} ->
          :ok

        {:DOWN, ^monitor, :process, _, reason} ->
          raise "managed-H1 peer join failed: #{inspect(reason)}"
      after
        max(0, expires - System.monotonic_time(:millisecond)) ->
          raise "managed-H1 peer did not join normally"
      end

      :ok = result
      true = joined["forced"] == 0 and joined["live"] == 0
      joined
    after
      f.wire.close(f.listener)

      if Process.alive?(f.peer) do
        # A failed join stays failed; killing this linked peer tree only bounds
        # cleanup of resources created by this fixture.
        Process.exit(f.peer, :kill)

        receive do
          {:DOWN, ^monitor, :process, _, _} -> :ok
        after
          max(0, expires - System.monotonic_time(:millisecond)) -> :ok
        end
      end

      Process.demonitor(monitor, [:flush])
      Process.delete({__MODULE__, f.key, :events})
      Process.delete({__MODULE__, f.key, :binding})
      File.rm_rf!(f.directory)
    end
  end

  # Both adapters use the same bridge; only the owner of a fixture can mutate it.
  def dispatch(nil, %{"op" => "start", "row" => row}) do
    f = start(row)

    ready = %{
      "event" => "ready",
      "row" => row,
      "port" => f.port,
      "origin" => f.origin,
      "downstream_url" =>
        "#{if f.downstream_tls, do: "https://localhost", else: "http://127.0.0.1"}:#{f.port}"
    }

    ready =
      if f.upstream == "tls" or f.downstream_tls do
        cert = Path.join(f.directory, "cert.pem")

        Map.merge(ready, %{
          "ca" => Path.join(f.directory, "ca.pem"),
          "server_cert" => cert,
          "server_cert_sha256" =>
            Base.encode16(:crypto.hash(:sha256, File.read!(cert)), case: :lower)
        })
      else
        ready
      end

    {f, ready}
  end

  def dispatch(f, %{"op" => "event", "match" => selector}), do: {f, event(f, selector)}
  def dispatch(f, %{"op" => "upstream"} = value), do: {f, command(f, value)}
  def dispatch(f, %{"op" => "pending"}), do: {f, pending(f)}
  def dispatch(f, %{"op" => "request_clean"}), do: {f, request_clean(f)}
  def dispatch(f, %{"op" => "clean"}), do: {f, clean(f)}
  def dispatch(f, %{"op" => "stop"}), do: {nil, stop(f)}
  def dispatch(f, %{"op" => "failure_diagnostic"}), do: {f, failure_diagnostic(f)}

  def run_case(case_id) do
    port =
      Port.open({:spawn_executable, String.to_charlist(@python)}, [
        :binary,
        :exit_status,
        {:line, 2_097_152},
        {:args,
         [
           Path.join(@root, "integration/upstream_transport/run.py"),
           "--attached",
           "--case",
           case_id
         ]}
      ])

    {:os_pid, pid} = Port.info(port, :os_pid)
    Process.put({__MODULE__, :attached}, nil)
    Process.put({__MODULE__, :driver_group}, nil)

    outcome =
      try do
        {:ok,
         attached_loop(
           port,
           nil,
           %{receipt: nil, joined: nil},
           "",
           System.monotonic_time(:millisecond) + 35_000,
           pid,
           case_id
         )}
      catch
        kind, reason -> {:error, kind, reason, __STACKTRACE__}
      end

    # Each cleanup is attempted even if stopping the fixture itself fails.
    expires = System.monotonic_time(:millisecond) + 10_000

    errors =
      for cleanup <- [
            fn ->
              if group = Process.delete({__MODULE__, :driver_group}),
                do: stop_driver_group(group, expires)
            end,
            fn ->
              if owned = Process.delete({__MODULE__, :attached}),
                do: stop(owned, max(0, expires - System.monotonic_time(:millisecond)))
            end,
            fn -> if Port.info(port), do: Port.close(port) end
          ],
          error <- cleanup_error(cleanup),
          do: error

    case outcome do
      {:ok, result} ->
        if errors != [], do: raise("matrix attached cleanup failed: #{inspect(errors)}")
        result

      {:error, kind, reason, stacktrace} ->
        if errors != [], do: IO.warn("matrix attached cleanup failed: #{inspect(errors)}")
        :erlang.raise(kind, reason, stacktrace)
    end
  end

  defp attached_loop(port, fixture, result, carry, expires, pid, case_id) do
    Process.put({__MODULE__, :attached}, fixture)
    remaining = max(0, expires - System.monotonic_time(:millisecond))

    receive do
      {^port, {:data, {:noeol, bytes}}} ->
        attached_loop(port, fixture, result, carry <> bytes, expires, pid, case_id)

      {^port, {:data, {:eol, bytes}}} ->
        value = JSON.decode!(carry <> bytes)

        {fixture, result} =
          case value["event"] do
            "driver_ready" ->
              nil = Process.get({__MODULE__, :driver_group})
              %{"pid" => ^pid, "group" => ^pid} = value
              Process.put({__MODULE__, :driver_group}, pid)
              {fixture, result}

            "driver_joined" ->
              nil = result.joined
              ^case_id = value["case"]
              {fixture, %{result | joined: value}}

            "case_result" ->
              nil = result.receipt
              ^case_id = value["case"]
              true = is_map(result.joined)
              {fixture, %{result | receipt: value}}

            _ ->
              ^pid = Process.get({__MODULE__, :driver_group})
              {fixture, response} = dispatch(fixture, value)
              true = Port.command(port, [JSON.encode!(response), "\n"])
              {fixture, result}
          end

        attached_loop(port, fixture, result, "", expires, pid, case_id)

      {^port, {:exit_status, 0}} ->
        nil = fixture
        %{"status" => "PASS"} = result.receipt

        %{"live" => 0, "forced" => 0, "errors" => [], "owned" => count, "joined" => joined} =
          result.joined

        true = count == joined
        false = driver_group_alive?(pid)
        result.receipt

      {^port, {:exit_status, status}} ->
        raise "matrix driver exited #{status}: #{inspect(result)}"
    after
      remaining -> raise "matrix attached driver deadline"
    end
  end

  defp cleanup_error(cleanup) do
    cleanup.()
    []
  rescue
    error -> [Exception.message(error)]
  catch
    kind, reason -> [inspect({kind, reason})]
  end

  defp driver_group_alive?(group) do
    case System.cmd("kill", ["-0", "--", "-#{group}"], stderr_to_stdout: true) do
      {_, 0} -> true
      {_, 1} -> false
    end
  end

  defp stop_driver_group(group, expires) do
    if driver_group_alive?(group) do
      System.cmd("kill", ["-TERM", "--", "-#{group}"], stderr_to_stdout: true)

      unless await_driver_group(
               group,
               min(expires, System.monotonic_time(:millisecond) + @timeout)
             ) do
        System.cmd("kill", ["-KILL", "--", "-#{group}"], stderr_to_stdout: true)
        true = await_driver_group(group, expires)
      end

      raise "matrix driver required forced process-group cleanup"
    end
  end

  defp await_driver_group(group, expires) do
    cond do
      not driver_group_alive?(group) ->
        true

      System.monotonic_time(:millisecond) >= expires ->
        false

      true ->
        receive do
        after
          10 -> await_driver_group(group, expires)
        end
    end
  end

  defp accept_loop(wire, listener, parent, workers, count) do
    receive do
      {:command, connection, request, command} ->
        {worker, _monitor} = Map.fetch!(workers, connection)
        send(worker, {:command, request, command})
        accept_loop(wire, listener, parent, workers, count)
    after
      0 ->
        accepted =
          if wire == :ssl,
            do: :ssl.transport_accept(listener, 20),
            else: :gen_tcp.accept(listener, 20)

        case accepted do
          {:ok, socket} ->
            peer = self()
            connection = count + 1

            {worker, monitor} =
              :erlang.spawn_opt(
                fn ->
                  receive do
                    :owned ->
                      result =
                        try do
                          {:ok, connected} =
                            if wire == :ssl,
                              do: :ssl.handshake(socket, @timeout),
                              else: {:ok, socket}

                          tls =
                            if wire == :ssl do
                              {:ok, info} =
                                :ssl.connection_information(connected, [:sni_hostname])

                              alpn =
                                case :ssl.negotiated_protocol(connected) do
                                  {:ok, value} -> value
                                  {:error, :protocol_not_negotiated} -> nil
                                end

                              %{
                                "sni" => to_string(info[:sni_hostname]),
                                "alpn" => alpn,
                                "wire" => "tls-h1"
                              }
                            else
                              %{"wire" => "tcp-h1"}
                            end

                          emit(
                            parent,
                            peer,
                            Map.merge(%{"event" => "accepted", "connection" => connection}, tls)
                          )

                          serve(wire, connected, parent, peer, connection, 1)
                          :ok
                        rescue
                          error ->
                            emit(parent, peer, %{
                              "event" => "worker_terminal",
                              "connection" => connection,
                              "phase" => "worker_rescue",
                              "terminal_label" => "worker_exception"
                            })

                            emit(parent, peer, %{
                              "event" => "failure",
                              "connection" => connection,
                              "reason" => Exception.message(error)
                            })

                            {:error, Exception.message(error)}
                        after
                          close_result = wire.close(socket)

                          emit(parent, peer, %{
                            "event" => "local_socket_close",
                            "connection" => connection,
                            "phase" => "worker_after",
                            "terminal_label" =>
                              case close_result do
                                :ok -> "close_ok"
                                {:error, _} -> "close_error"
                                _ -> "close_other"
                              end
                          })

                          close_result
                        end

                      send(peer, {:worker_finished, connection, result})
                  after
                    @timeout -> exit(:ownership_deadline)
                  end
                end,
                [:link, :monitor]
              )

            :ok = wire.controlling_process(socket, worker)
            send(worker, :owned)

            accept_loop(
              wire,
              listener,
              parent,
              Map.put(workers, connection, {worker, monitor}),
              connection
            )

          {:error, :timeout} ->
            accept_loop(wire, listener, parent, workers, count)

          {:error, :closed} ->
            for {connection, {worker, monitor}} <- workers do
              receive do
                {:worker_finished, ^connection, :ok} -> :ok
                {:worker_finished, ^connection, failure} -> raise inspect(failure)
              after
                @timeout -> raise "upstream worker did not finish"
              end

              receive do
                {:DOWN, ^monitor, :process, ^worker, :normal} -> :ok
              after
                @timeout -> raise "upstream worker did not join"
              end
            end

            emit(parent, self(), %{
              "event" => "joined",
              "accepted" => count,
              "forced" => 0,
              "live" => 0
            })
        end
    end
  end

  defp serve(wire, socket, parent, peer, connection, request) do
    case wire.recv(socket, 1, @timeout) do
      {:error, reason} when reason in [:closed, :enotconn] ->
        emit(parent, peer, %{
          "event" => "peer_terminal",
          "connection" => connection,
          "request" => request,
          "phase" => "await_request",
          "terminal_label" => if(reason == :closed, do: "peer_closed", else: "peer_enotconn")
        })

        :ok

      {:ok, first} ->
        head = until(wire, socket, "\r\n\r\n", first)
        [line | lines] = String.split(String.trim_trailing(head, "\r\n\r\n"), "\r\n")
        [method, target, "HTTP/1.1"] = String.split(line, " ")
        fields = fields(lines)

        base = %{
          "connection" => connection,
          "request" => request,
          "method" => method,
          "target" => target
        }

        role = if method == "HEAD" and target == "/health", do: "health", else: "application"

        emit(
          parent,
          peer,
          Map.merge(base, %{"event" => "request", "role" => role, "headers" => fields})
        )

        if role == "health" do
          :ok = wire.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
        else
          {body, trailers} = upload(wire, socket, parent, peer, base, fields)

          emit(
            parent,
            peer,
            Map.merge(
              base,
              Map.merge(%{"event" => "upload_end", "trailers" => trailers}, bytes(body))
            )
          )

          respond(wire, socket, parent, peer, base)
        end

        serve(wire, socket, parent, peer, connection, request + 1)

      other ->
        emit(parent, peer, %{
          "event" => "peer_terminal",
          "connection" => connection,
          "request" => request,
          "phase" => "await_request",
          "terminal_label" =>
            if(other == {:error, :timeout}, do: "recv_timeout", else: "recv_other")
        })

        raise "upstream read failed: #{inspect(other)}"
    end
  end

  defp upload(wire, socket, parent, peer, base, fields) do
    cond do
      field(fields, "transfer-encoding") == "chunked" ->
        chunks(wire, socket, "")

      field(fields, "content-length") != nil ->
        count = String.to_integer(field(fields, "content-length"))
        true = count in 0..1_048_576

        if base["target"] == "/temporal" do
          6 = count
          first = read(wire, socket, 3)

          emit(
            parent,
            peer,
            Map.merge(
              base,
              Map.merge(%{"event" => "upload_prefix", "complete" => false}, bytes(first))
            )
          )

          request = base["request"]

          receive do
            {:command, ^request, %{"action" => "continue_upload"}} ->
              emit(
                parent,
                peer,
                Map.merge(base, %{"event" => "command", "action" => "continue_upload"})
              )
          after
            @timeout -> raise "upload release deadline"
          end

          {first <> read(wire, socket, 3), []}
        else
          {read(wire, socket, count), []}
        end

      true ->
        {"", []}
    end
  end

  defp respond(wire, socket, parent, peer, base) do
    request = base["request"]

    receive do
      {:command, ^request, %{"action" => "send", "body64" => encoded, "ended" => ended}} ->
        raw = Base.decode64!(encoded)
        :ok = wire.send(socket, raw)

        emit(
          parent,
          peer,
          Map.merge(
            base,
            Map.merge(%{"event" => "command", "action" => "send", "ended" => ended}, bytes(raw))
          )
        )

        if not ended, do: respond(wire, socket, parent, peer, base)
    after
      @timeout ->
        raise "response release deadline #{inspect(diagnostic_fields(base), limit: :infinity)}"
    end
  end

  defp chunks(wire, socket, body) do
    size =
      until(wire, socket, "\r\n")
      |> String.trim()
      |> String.split(";", parts: 2)
      |> hd()
      |> String.to_integer(16)

    true = size in 0..1_048_576 and byte_size(body) + size <= 1_048_576

    if size == 0 do
      {body, trailer_fields(wire, socket, [])}
    else
      chunk = read(wire, socket, size)
      "\r\n" = read(wire, socket, 2)
      chunks(wire, socket, body <> chunk)
    end
  end

  defp trailer_fields(wire, socket, acc) do
    case until(wire, socket, "\r\n") do
      "\r\n" ->
        fields(Enum.reverse(acc))

      line ->
        true = length(acc) < 128
        trailer_fields(wire, socket, [String.trim_trailing(line, "\r\n") | acc])
    end
  end

  defp fields(lines),
    do:
      Enum.map(lines, fn line ->
        [name, value] = String.split(line, ":", parts: 2)
        [String.downcase(name), String.trim_leading(value)]
      end)

  defp field(fields, name) do
    case Enum.find(fields, fn [key, _] -> key == name end) do
      nil -> nil
      [_, value] -> value
    end
  end

  defp read(_wire, _socket, 0), do: ""

  defp read(wire, socket, count) do
    {:ok, data} = wire.recv(socket, count, @timeout)
    ^count = byte_size(data)
    data
  end

  defp until(wire, socket, delimiter, acc \\ "") do
    true = byte_size(acc) <= 131_072

    if String.ends_with?(acc, delimiter),
      do: acc,
      else: until(wire, socket, delimiter, acc <> read(wire, socket, 1))
  end

  defp bytes(body),
    do: %{
      "body64" => Base.encode64(body),
      "body_bytes" => byte_size(body),
      "body_sha256" => Base.encode16(:crypto.hash(:sha256, body), case: :lower)
    }

  defp identity(value),
    do: Base.encode16(:crypto.hash(:sha256, :erlang.term_to_binary(value)), case: :lower)

  defp emit(parent, peer, value),
    do:
      send(
        parent,
        {:matrix_peer, peer, Map.put(value, "peer_at_us", System.monotonic_time(:microsecond))}
      )

  defp certificates(path),
    do:
      for(
        {:Certificate, der, :not_encrypted} <- :public_key.pem_decode(File.read!(path)),
        do: der
      )

  defp deadline, do: Gaoxy.Lifecycle.deadline(@timeout)
  defp eventually(fun), do: eventually(fun, System.monotonic_time(:millisecond) + @timeout)

  defp eventually(fun, expires) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) >= expires,
        do: raise("managed-H1 accounting deadline")

      :erlang.yield()
      eventually(fun, expires)
    end
  end
end
