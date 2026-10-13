# Run only after independent SPEC/CODE review, with the parent's qualified build:
# GAOXY_H1_RESOURCE_EVIDENCE=/absolute/new/run/directory unbuffer mix run \
#   --no-compile --no-start integration/http_fetch_contract/h1_resource_foundation_probe.exs
# Exactly eight cases. This collector has no filtering, exclusions or skips.
defmodule GaoxyH1ResourceFoundationProbe do
  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Proxy.UpstreamTransports, as: Owner
  alias HTTP.{ManagedTransport, Promise, RequestCompletion}

  @wait 6_000
  @case_budget 60_000
  @event_limit 2_048
  @byte_limit 2_097_152
  @limits %{
    max_resources: 2,
    max_pins: 16,
    max_request_tokens: 64,
    max_owned_payload_bytes: 262_144
  }

  def run do
    directory = System.fetch_env!("GAOXY_H1_RESOURCE_EVIDENCE") |> Path.expand()
    :ok = File.mkdir_p(directory)
    for app <- [:gaoxy_proxy, :http_fetch], do: {:ok, _} = Application.ensure_all_started(app)

    cases =
      for protocol <- ["tcp", "tls"],
          scenario <- [:sequential_reuse, :retirement_isolation, :unread_abort, :held_upload],
          do: run_case(directory, protocol, scenario)

    failures = Enum.count(cases, &(&1.status == "FAIL"))

    summary = %{
      tests: 8,
      executed: length(cases),
      failures: failures,
      skips: 0,
      excluded: 0,
      cases: cases,
      exit: if(failures == 0, do: 0, else: 1)
    }

    write_json(Path.join(directory, "summary.json"), summary)
    IO.puts("H1_RESOURCE_FOUNDATION_SUMMARY " <> JSON.encode!(json_value(summary)))
    System.halt(summary.exit)
  end

  defp run_case(directory, protocol, scenario) do
    name = protocol <> "_" <> Atom.to_string(scenario)

    Process.put(__MODULE__, %{
      name: name,
      deadline: deadline(@case_budget),
      peer: nil,
      events: [],
      raw_lines: [],
      bytes: 0,
      consumed: MapSet.new(),
      owners: [],
      guardians: [],
      sources: [],
      scopes: [],
      completions: [],
      observations: [],
      extra_cleanup: []
    })

    primary =
      capture(fn ->
        peer = start_peer(protocol)

        case scenario do
          :sequential_reuse -> sequential(peer)
          :retirement_isolation -> isolation(peer)
          :unread_abort -> unread(peer)
          :held_upload -> upload(peer)
        end
      end)

    # Cleanup has its own finite budget; expiry of the acceptance deadline
    # cannot turn every owned cleanup attempt into an immediate timeout.
    update(&%{&1 | deadline: deadline(@case_budget)})
    cleanup = cleanup()
    state = state()
    errors = for %{status: "FAIL"} = item <- cleanup ++ state.extra_cleanup, do: item
    status = if primary.status == "PASS" and errors == [], do: "PASS", else: "FAIL"

    record = %{
      case: name,
      status: status,
      primary: primary,
      cleanup: cleanup,
      extra_cleanup: state.extra_cleanup,
      observations: Enum.reverse(state.observations),
      peer_events: length(state.events),
      peer_bytes: state.bytes,
      creator_helper_join_evidence:
        "public owner receipt and zero resources/helpers/accounting; reviewed ledger requires DOWN/result joins"
    }

    write_json(Path.join(directory, name <> ".json"), record)
    write_json(Path.join(directory, name <> "-peer.json"), Enum.reverse(state.events))

    File.write!(
      Path.join(directory, name <> "-peer.jsonl"),
      state.raw_lines |> Enum.reverse() |> Enum.map(&[&1, "\n"])
    )

    IO.puts("H1_RESOURCE_FOUNDATION_CASE " <> JSON.encode!(json_value(record)))
    Process.delete(__MODULE__)
    %{case: name, status: status}
  end

  defp start_peer(protocol) do
    python = System.get_env("HTTP_FETCH_PEER_PYTHON") || System.find_executable("python3")
    check(is_binary(python), "BLOCKED_ENV: Python3 unavailable")

    port =
      Port.open({:spawn_executable, python}, [
        :binary,
        :exit_status,
        {:line, 32_768},
        args: [Path.join(__DIR__, "h1_resource_foundation_peer.py"), "--protocol", protocol]
      ])

    update(
      &%{&1 | peer: %{port: port, protocol: protocol, ready: nil, stopped: false, exit: nil}}
    )

    ready = event(&(&1["event"] == "ready"))

    check(
      ready["protocol"] == protocol and ready["address"] == "127.0.0.1" and
        ready["hostname"] == "localhost" and is_integer(ready["port"]),
      "peer readiness identity"
    )

    scheme = if protocol == "tls", do: "https", else: "http"

    peer =
      Map.merge(state().peer, %{ready: ready, origin: "#{scheme}://localhost:#{ready["port"]}"})

    update(&%{&1 | peer: peer})
    observe("ready", ready)
    peer
  end

  defp owner(peer, label) do
    {:ok, instance} = Gaoxy.start_link()
    Process.unlink(instance)

    item = %{
      label: label,
      instance: instance,
      instance_monitor: Process.monitor(instance),
      owner: nil,
      owner_monitor: nil,
      stopped: false,
      expected_stop: :ok,
      receipt: nil
    }

    update(&%{&1 | owners: [item | &1.owners]})
    {:ok, owner} = Owner.start_link(instance: instance, limits: @limits)
    Process.unlink(owner)
    update_owner(instance, &%{&1 | owner: owner, owner_monitor: Process.monitor(owner)})

    trust =
      if peer.protocol == "tls" do
        for {:Certificate, der, :not_encrypted} <-
              :public_key.pem_decode(File.read!(peer.ready["ca"])),
            do: der
      else
        nil
      end

    if peer.protocol == "tls", do: check(trust != [], "TLS CA DER was not loaded")
    source = %{origin: peer.origin, connect_address: {127, 0, 0, 1}, trust: trust}
    {:ok, handle, pins} = Owner.prepare(owner, source, self(), operation_deadline())
    {:ok, baseline} = Resources.pin_many([handle], self(), :baseline, operation_deadline())
    observe(label <> "_prepared", ledger(owner))

    %{
      label: label,
      instance: instance,
      owner: owner,
      handle: handle,
      pins: pins,
      baseline: baseline
    }
  end

  defp sequential(peer) do
    resource = owner(peer, "A")
    first = successful_request(peer, resource, "/sequential-one?raw=%2F&n=1", 1, 1)
    second = successful_request(peer, resource, "/sequential-two?raw=%25&n=2", 1, 2)

    check(
      first.connection == second.connection,
      "sequential requests did not reuse one connection"
    )

    snapshot(1, 2, 1)
    retire(resource, [1])
    exact_requests([first, second])
    stop_instance(resource)
  end

  defp isolation(peer) do
    a = owner(peer, "A")
    b = owner(peer, "B")
    first = successful_request(peer, a, "/isolation-A?owner=A", 1, 1)
    second = successful_request(peer, b, "/isolation-B-before?owner=B", 2, 2)
    check(a.owner != b.owner and a.instance != b.instance, "instances and owners must differ")
    snapshot(2, 2, 2)
    retire(a, [1])
    stop_instance(a)
    snapshot(2, 2, 1)
    third = successful_request(peer, b, "/isolation-B-after?owner=B", 2, 3)

    check(
      second.connection == third.connection and first.connection != third.connection,
      "cross-instance reuse or loss of B's own live connection"
    )

    retire(b, [2])
    exact_requests([first, second, third])
    stop_instance(b)
  end

  defp unread(peer) do
    resource = owner(peer, "A")
    target = "/hold-unread?reader=absent"
    request = request(peer, resource, target)
    held = event(&(&1["event"] == "held" and &1["phase"] == "response_body"))
    check(held["connection"] == 1 and held["request"] == 1, "unread barrier IDs")
    check(rpc(request, :response_head) == :ok, "unread response head")
    pending(request, resource)

    check(
      RequestCompletion.abort_and_await(request.completion, remaining()) == :ok,
      "original unread completion abort did not confirm"
    )

    check(finish_request(request, "unread token settlement") == :ok, "unread token settlement")
    refunded(resource)
    join_guardian(request)
    check(RequestCompletion.await(request.completion, 0) == :ok, "durable original completion")
    retire(resource, [1])
    exact_heads([%{connection: 1, request: 1, path: target, method: "GET"}])

    [%{"body_bytes" => 0, "body_sha256" => hash, "upload_trailers" => []}] =
      events("request")

    check(hash == sha(""), "unread request body hash")
    check(events("response") == [], "held response unexpectedly completed/replayed")
    stop_instance(resource)
  end

  defp upload(peer) do
    resource = owner(peer, "A")
    {:ok, source} = HTTP.Stream.start_link(0)
    Process.unlink(source)
    source_monitor = Process.monitor(source)

    update(
      &%{&1 | sources: [%{pid: source, monitor: source_monitor, joined: false} | &1.sources]}
    )

    target = "/upload-held?source=caller-owned"
    request = request(peer, resource, target, method: :post, body: source, duplex: "half")
    held = event(&(&1["event"] == "held" and &1["phase"] == "upload_body"))
    check(held["connection"] == 1 and held["request"] == 1, "upload barrier IDs")
    # Only this explicitly caller-owned public Stream PID is suspended. The
    # controller executing this function owns both suspension and resumption.
    true = :erlang.suspend_process(source)

    receipt =
      try do
        pending(request, resource)
        short = deadline(100)
        {:ok, receipt} = Owner.retire(resource.owner, short)
        remember_receipt(resource, receipt, {:error, {:deadline_exceeded, :cleanup_pending}})

        check(
          Owner.await_retirement(receipt, deadline(1_000)) ==
            {:error, {:deadline_exceeded, :cleanup_pending}},
          "short-D retirement must permanently fail"
        )

        pending(request, resource, :after_abort)

        check(
          Owner.await_retirement(receipt, operation_deadline()) ==
            {:error, {:deadline_exceeded, :cleanup_pending}},
          "short-D failure was not cached"
        )

        observe("short_D_failure_while_source_suspended", %{
          ledger: ledger(resource.owner),
          completion: "cleanup_pending",
          retirement: "{:error, {:deadline_exceeded, :cleanup_pending}}"
        })

        receipt
      after
        result =
          capture(fn ->
            true = :erlang.resume_process(source)
            :ok
          end)

        update(
          &%{
            &1
            | extra_cleanup: [
                %{operation: "resume_caller_owned_source", status: result.status, result: result}
                | &1.extra_cleanup
              ]
          }
        )
      end

    check(
      RequestCompletion.await(request.completion, remaining()) == :ok,
      "late upload completion"
    )

    check(finish_request(request, "late upload finish") == :ok, "late upload finish")
    join_guardian(request)
    join_source(source, source_monitor)
    retire_scope(request.scope)
    zero(resource.owner)
    eof(1)
    # The receipt is owner-hosted: both repeated waits occur before instance DOWN.
    check(Process.alive?(resource.owner), "failed owner must remain inert and alive")
    {:ok, same} = Owner.retire(resource.owner, operation_deadline())
    check(same == receipt, "repeated retire changed owner receipt")

    check(
      Owner.await_retirement(receipt, operation_deadline()) ==
        {:error, {:deadline_exceeded, :cleanup_pending}},
      "late cleanup rewrote cached owner failure"
    )

    observe("late_cleanup_cached_failure_before_instance_DOWN", %{
      ledger: ledger(resource.owner),
      original_completion: "ok",
      owner_receipt: "{:error, {:deadline_exceeded, :cleanup_pending}}",
      owner_alive: true
    })

    exact_heads([%{connection: 1, request: 1, path: target, method: "POST"}])
    check(events("request") == [], "aborted held upload unexpectedly completed/replayed")
    check(events("response") == [], "aborted held upload unexpectedly produced response")
    stop_instance(resource)
  end

  defp successful_request(peer, resource, target, connection, id) do
    request = request(peer, resource, target)
    head = event(&(&1["event"] == "request_head" and &1["path"] == target))
    check(head["connection"] == connection and head["request"] == id, "request identity")
    check(rpc(request, :response_head) == :ok, "response head")
    pending(request, resource)
    expected = "foundation:" <> target
    check(rpc(request, {:read, expected}) == :ok, "exact body/trailers")
    check(RequestCompletion.await(request.completion, remaining()) == :ok, "original completion")
    before = ledger(resource.owner)

    check(
      before.request_tokens == 1 and before.reserved_connections == 2,
      "completion refund boundary"
    )

    check(rpc(request, :finish) == :ok, "finish request")
    after_finish = refunded(resource)

    check(
      after_finish.pins == before.pins and
        after_finish.owned_serialized_payload_bytes < before.owned_serialized_payload_bytes,
      "finish must refund exactly request token, preserving metadata pins"
    )

    check(rpc(request, :finish) == :ok, "idempotent finish")
    join_guardian(request)

    eventually(
      fn ->
        case ManagedTransport.snapshot(request.scope, 100) do
          {:ok, %{active_requests: 0, preparing_requests: 0, connections: 1}} -> true
          _ -> false
        end
      end,
      "public idle transport snapshot"
    )

    observe("request_refunded_idle_transport_retained", %{
      ledger: ledger(resource.owner),
      public_scope: elem(ManagedTransport.snapshot(request.scope, remaining()), 1),
      body_sha256: sha(expected),
      request: id,
      connection: connection
    })

    wire = event(&(&1["event"] == "request" and &1["request"] == id))
    response = event(&(&1["event"] == "response" and &1["request"] == id))

    check(
      wire["body_bytes"] == 0 and wire["body_sha256"] == sha("") and
        wire["upload_trailers"] == [],
      "request body/hash/trailers"
    )

    check(
      response["connection"] == connection and response["body_bytes"] == byte_size(expected) and
        response["body_sha256"] == sha(expected) and
        response["trailers"] == [["x-foundation", "done"], ["x-bodysha", sha(expected)]],
      "peer response bytes/hash/ordered trailers"
    )

    %{connection: connection, request: id, path: target, method: "GET"}
  end

  defp request(peer, resource, target, extra \\ []) do
    controller = self()
    {guardian, monitor} = spawn_monitor(fn -> guardian(controller) end)
    item = %{pid: guardian, monitor: monitor, joined: false}
    update(&%{&1 | guardians: [item | &1.guardians]})
    send(guardian, {:start, resource.handle, peer.origin <> target, extra, operation_deadline()})

    receive do
      {:bound, ^guardian, completion, scope} ->
        update(
          &%{
            &1
            | completions: [completion | &1.completions],
              scopes: [%{owner: resource.owner, scope: scope} | &1.scopes]
          }
        )

        %{pid: guardian, monitor: monitor, completion: completion, scope: scope}

      {:setup_failure, ^guardian, failure} ->
        raise "request setup failed: #{inspect(failure)}"
    after
      remaining() -> raise "request guardian binding deadline exceeded"
    end
  end

  defp guardian(controller) do
    Process.put(:request_holds, %{
      handle: nil,
      pins: [],
      token: nil,
      completion: nil,
      promise: nil,
      response: nil,
      stream_monitor: nil
    })

    receive do
      {:start, handle, url, extra, d} ->
        setup =
          capture(fn ->
            Process.put(:request_holds, %{Process.get(:request_holds) | handle: handle})
            {:ok, pins} = Resources.pin_many([handle], self(), :request, d)
            Process.put(:request_holds, %{Process.get(:request_holds) | pins: pins})
            {:ok, client, token} = Owner.checkout(handle, pins, self(), d)
            Process.put(:request_holds, %{Process.get(:request_holds) | token: token})

            options =
              client.fetch_options ++
                [transport_scope: client.transport_scope, timeout: 20_000, connect_timeout: 3_000] ++
                extra

            promise = HTTP.fetch(url, options)
            completion = Promise.completion(promise)

            Process.put(:request_holds, %{
              Process.get(:request_holds)
              | promise: promise,
                completion: completion
            })

            :ok = Owner.bind_completion(handle, token, completion)
            # The first publication occurs strictly after binding the ORIGINAL completion.
            send(controller, {:bound, self(), completion, client.transport_scope})
            :ok
          end)

        if setup.status == "FAIL", do: send(controller, {:setup_failure, self(), setup})
        guardian_loop(controller)
    after
      @wait -> send(controller, {:setup_failure, self(), "start deadline"})
    end
  end

  defp guardian_loop(controller) do
    receive do
      {:operation, ref, operation} ->
        result = capture(fn -> guardian_operation(operation) end)
        send(controller, {:operation_result, self(), ref, result})
        if operation != :close, do: guardian_loop(controller)
    after
      @case_budget ->
        result = capture(fn -> guardian_operation(:close) end)
        send(controller, {:guardian_expired, self(), result})
    end
  end

  defp guardian_operation(:response_head) do
    holds = Process.get(:request_holds)
    %HTTP.Response{status: 200, body: stream} = response = Promise.await(holds.promise, @wait)
    check(is_pid(stream), "public response stream PID")

    Process.put(:request_holds, %{
      holds
      | response: response,
        stream_monitor: Process.monitor(stream)
    })

    :ok
  end

  defp guardian_operation({:read, expected}) do
    holds = Process.get(:request_holds)
    stream = holds.response.body
    {body, trailers} = read(stream, deadline(@wait), [], nil, 0)
    check(body == expected and sha(body) == sha(expected), "exact raw response body/hash")

    check(
      trailers == [{"x-foundation", "done"}, {"x-bodysha", sha(expected)}],
      "ordered response trailers"
    )

    down(stream, holds.stream_monitor, deadline(@wait))
    Process.put(:request_holds, %{holds | stream_monitor: nil})
    :ok
  end

  defp guardian_operation(:finish) do
    holds = Process.get(:request_holds)
    Owner.finish(holds.handle, holds.token)
  end

  defp guardian_operation(:close) do
    holds = Process.get(:request_holds)

    operations = [
      {"original_completion",
       fn ->
         if holds.completion, do: :ok = RequestCompletion.abort_and_await(holds.completion, @wait)
         :ok
       end},
      {"finish",
       fn ->
         if holds.token, do: :ok = Owner.finish(holds.handle, holds.token)
         :ok
       end},
      {"request_metadata_pins", fn -> :ok = Resources.release(holds.pins) end},
      {"response_stream_DOWN",
       fn ->
         if holds.stream_monitor,
           do: down(holds.response.body, holds.stream_monitor, deadline(@wait))

         :ok
       end}
    ]

    results = for {name, fun} <- operations, do: %{operation: name, result: capture(fun)}

    check(
      Enum.all?(results, &(&1.result.status == "PASS")),
      "guardian cleanup: #{inspect(results)}"
    )

    :ok
  end

  defp finish_request(request, label) do
    d = operation_deadline()

    poll(
      fn ->
        result = rpc(request, :finish, d)
        observe("request_finish_result", %{check: label, result: inspect(result)})

        case result do
          :ok -> true
          {:error, :cleanup_pending} -> false
          other -> raise label <> " unexpected result: " <> inspect(other)
        end
      end,
      d,
      label
    )
  end

  defp rpc(request, operation, d \\ operation_deadline()) do
    check(now() < d, "guardian operation deadline exceeded: #{inspect(operation)}")
    ref = make_ref()
    send(request.pid, {:operation, ref, operation})

    receive do
      {:operation_result, pid, ^ref, %{status: "PASS", value: result}} when pid == request.pid ->
        result

      {:operation_result, pid, ^ref, failure} when pid == request.pid ->
        raise "guardian #{inspect(operation)} failed: #{inspect(failure)}"
    after
      max(d - now(), 0) -> raise "guardian operation deadline exceeded: #{inspect(operation)}"
    end
  end

  defp join_guardian(request) do
    close = capture(fn -> :ok = rpc(request, :close) end)
    joined = capture(fn -> down(request.pid, request.monitor, operation_deadline()) end)

    if joined.status == "PASS" do
      update(
        &%{
          &1
          | guardians:
              Enum.map(&1.guardians, fn item ->
                if item.pid == request.pid, do: %{item | joined: true}, else: item
              end)
        }
      )
    end

    check(
      close.status == "PASS" and joined.status == "PASS",
      "guardian close and DOWN: #{inspect(%{close: close, joined: joined})}"
    )

    observe("guardian_DOWN_original_completion_joined", %{result: "ok"})
  end

  defp join_source(pid, monitor) do
    down(pid, monitor, operation_deadline())

    update(
      &%{
        &1
        | sources:
            Enum.map(&1.sources, fn item ->
              if item.pid == pid, do: %{item | joined: true}, else: item
            end)
      }
    )

    observe("caller_owned_upload_source_DOWN", %{result: "ok"})
  end

  defp read(stream, d, chunks, trailers, bytes) do
    send(stream, {:read_chunk, self(), :ack})

    receive do
      {:stream_chunk, ^stream, chunk, ack} ->
        check(bytes + byte_size(chunk) <= 65_536, "response body cap")
        send(stream, {:stream_chunk_ack, ack})
        read(stream, d, [chunk | chunks], trailers, bytes + byte_size(chunk))

      {:stream_trailers, ^stream, %HTTP.Headers{headers: fields}} ->
        check(trailers == nil, "duplicate trailer publication")
        read(stream, d, chunks, fields, bytes)

      {:stream_end, ^stream} ->
        {IO.iodata_to_binary(Enum.reverse(chunks)), trailers}

      {:stream_error, ^stream, reason} ->
        raise "response stream failed: #{inspect(reason)}"
    after
      max(d - now(), 0) -> raise "response read deadline exceeded"
    end
  end

  defp pending(request, resource, phase \\ :before_abort) do
    check(
      RequestCompletion.await(request.completion, 0) == {:error, :cleanup_pending},
      "original completion must remain pending at barrier"
    )

    check(
      ledger(resource.owner).request_tokens == 1 and
        ledger(resource.owner).reserved_connections == 2,
      "pending request token and C2 reservation must be retained"
    )

    {:ok, scope_status} = ManagedTransport.snapshot(request.scope, remaining())

    if phase == :before_abort do
      check(
        scope_status.active_requests == 1 and scope_status.preparing_requests == 0,
        "public scope request credit must remain held before abort"
      )
    end

    # After abort, the public snapshot does not prescribe the representation
    # of a held source slot. Completion and Gaoxy token/C2 holds above remain
    # mandatory until their public confirmation; the native aggregate is an observation.

    observe("pending_original_completion_credits_retained", %{
      ledger: ledger(resource.owner),
      public_scope: scope_status,
      phase: phase
    })
  end

  defp refunded(resource) do
    status = ledger(resource.owner)

    check(
      status.resources == 1 and status.request_tokens == 0 and status.reserved_connections == 2,
      "request token refund must preserve resource C2 reservation"
    )

    status
  end

  defp retire(resource, connections) do
    before = ledger(resource.owner)
    check(before.pins >= 2, "baseline/preparation metadata pins must still be live at retirement")
    {:ok, receipt} = Owner.retire(resource.owner, operation_deadline())
    remember_receipt(resource, receipt, :ok)
    check(Owner.await_retirement(receipt, operation_deadline()) == :ok, "public owner retirement")

    for %{owner: owner, scope: scope} <- Enum.uniq(state().scopes),
        owner == resource.owner,
        do: retire_scope(scope)

    zero(resource.owner)
    for connection <- connections, do: eof(connection)

    observe(resource.label <> "_public_retirement_creator_helpers_joined", %{
      ledger: ledger(resource.owner),
      owner_receipt: "ok",
      owner_alive: Process.alive?(resource.owner)
    })

    check(Process.alive?(resource.owner), "retired owner must remain inert until instance DOWN")
    :ok = Resources.release(resource.pins)
    :ok = Resources.release(resource.baseline)
  end

  defp retire_scope(scope) do
    {:ok, receipt} = ManagedTransport.retire(scope, mode: :abort)

    check(
      ManagedTransport.await_retired(receipt, remaining()) == :ok,
      "public managed scope retirement"
    )

    observe("public_scope_retirement", %{result: "ok"})
  end

  defp zero(owner) do
    eventually(
      fn ->
        case Owner.status(owner) do
          {:ok,
           %{
             resources: 0,
             pins: 0,
             request_tokens: 0,
             reserved_connections: 0,
             helpers: 0,
             failed_resources: 0,
             owned_serialized_payload_bytes: 0
           }} ->
            true

          _ ->
            false
        end
      end,
      "eventual zero ledger including creator/helper joins"
    )

    observe("zero_ledger_creator_helpers_joined", ledger(owner))
  end

  defp stop_instance(resource) do
    item = Enum.find(state().owners, &(&1.instance == resource.instance))
    stopped = capture(fn -> Gaoxy.stop(resource.instance, remaining()) end)

    instance_join =
      capture(fn -> down(item.instance, item.instance_monitor, operation_deadline()) end)

    owner_join = capture(fn -> down(item.owner, item.owner_monitor, operation_deadline()) end)

    if instance_join.status == "PASS" and owner_join.status == "PASS",
      do: update_owner(item.instance, &%{&1 | stopped: true})

    check(
      stopped.status == "PASS" and instance_join.status == "PASS" and owner_join.status == "PASS",
      "instance cleanup/join: #{inspect(%{stop: stopped, instance: instance_join, owner: owner_join})}"
    )

    result = stopped.value

    case item.expected_stop do
      :ok ->
        check(result == :ok, "Gaoxy.stop success")

      {:error, {:deadline_exceeded, :cleanup_pending}} ->
        check(
          result == item.expected_stop,
          "Gaoxy.stop must propagate earlier failed owner retirement: #{inspect(result)}"
        )
    end

    observe(item.label <> "_instance_owner_DOWN", %{stop_result: inspect(result)})
  end

  defp remember_receipt(resource, receipt, expected) do
    update_owner(resource.instance, &%{&1 | receipt: receipt, expected_stop: expected})
  end

  defp exact_requests(expected) do
    exact_heads(expected)

    check(
      length(events("request")) == length(expected) and
        length(events("response")) == length(expected),
      "exact completed request/response counts; no replay"
    )
  end

  defp exact_heads(expected) do
    # Snapshot is an ordered control barrier; final EOF gives each connection's terminal barrier.
    command(%{command: "snapshot"})
    event(&(&1["event"] == "snapshot"))

    heads =
      for head <- events("request_head"),
          do: Map.take(head, ["connection", "request", "path", "method"])

    want = for item <- expected, do: Map.new(item, fn {k, v} -> {Atom.to_string(k), v} end)
    check(heads == want, "exact ordered request identities/no replay: #{inspect(heads)}")
    authority = "localhost:#{state().peer.ready["port"]}"

    check(
      Enum.all?(events("request_head"), &(&1["authority"] == authority)),
      "exact origin authority"
    )

    # The qualified explicit managed-H1 profile sends no ALPN advertisement.
    # Keep the exact null contract; any selected protocol is an unexpected policy.
    check(
      Enum.all?(events("connected"), &(Map.fetch!(&1, "alpn") == nil)),
      "H1 ALPN identity: explicit null"
    )

    accepts = expected |> Enum.map(& &1.connection) |> Enum.uniq() |> length()

    check(
      length(events("accepted")) == accepts,
      "unexpected accepted connection/replay"
    )
  end

  defp snapshot(accepts, requests, alive) do
    command(%{command: "snapshot"})
    receipt = event(&(&1["event"] == "snapshot"))

    check(
      receipt["accepts"] == accepts and receipt["requests"] == requests and
        receipt["current_alive"] == alive and receipt["failed"] == false,
      "peer snapshot counts"
    )

    observe("peer_snapshot", receipt)
  end

  defp eof(connection) do
    receipt =
      Enum.find(events("eof"), &(&1["connection"] == connection)) ||
        event(&(&1["event"] == "eof" and &1["connection"] == connection))

    check(
      receipt["remote_eof"] == true and receipt["reason"] in ["remote_eof", "remote_abort"],
      "fixture-owned stop cannot certify client closure"
    )

    observe("genuine_remote_EOF_before_fixture_stop", receipt)
  end

  defp cleanup do
    # Every operation is captured independently: a primary or cleanup failure
    # never prevents attempts to clean up other owned actors/resources.
    guardians =
      for item <- state().guardians, not item.joined do
        cleanup_item("guardian", fn -> join_guardian(item) end)
      end

    completions =
      for completion <- state().completions do
        cleanup_item("original_completion", fn ->
          :ok = RequestCompletion.abort_and_await(completion, remaining())
        end)
      end

    scopes =
      for %{scope: scope} <- Enum.uniq(state().scopes) do
        cleanup_item("public_scope", fn -> retire_scope(scope) end)
      end

    owners =
      for item <- state().owners, not item.stopped, item.owner != nil do
        cleanup_item("public_owner", fn ->
          {:ok, receipt} = Owner.retire(item.owner, operation_deadline())
          expected = if item.receipt, do: item.expected_stop, else: :ok

          check(
            Owner.await_retirement(receipt, operation_deadline()) == expected,
            "cleanup owner result"
          )

          update_owner(item.instance, &%{&1 | receipt: receipt, expected_stop: expected})
          zero(item.owner)
        end)
      end

    sources =
      for item <- state().sources, not item.joined do
        cleanup_item("caller_owned_source", fn ->
          if Process.alive?(item.pid) do
            :ok = HTTP.Stream.error(item.pid, :fixture_cleanup)
            send(item.pid, {:read_chunk, self()})
          end

          join_source(item.pid, item.monitor)
        end)
      end

    instances =
      for item <- state().owners, not item.stopped do
        cleanup_item("instance_owner_DOWN", fn ->
          if item.owner,
            do: stop_instance(item),
            else: :ok = Gaoxy.stop(item.instance, remaining())
        end)
      end

    client_eofs = [
      cleanup_item("all_client_EOF_before_fixture_stop", fn ->
        if state().peer && state().peer.ready do
          command(%{command: "snapshot"})
          snapshot = event(&(&1["event"] == "snapshot"))
          for connection <- 1..snapshot["accepts"], snapshot["accepts"] > 0, do: eof(connection)
        end

        :ok
      end)
    ]

    peer = [cleanup_item("peer_process_threads_connections_certificates", fn -> stop_peer() end)]
    guardians ++ completions ++ scopes ++ owners ++ sources ++ instances ++ client_eofs ++ peer
  end

  defp stop_peer do
    if state().peer do
      port = state().peer.port

      command_result =
        capture(fn ->
          command(%{command: "stop"})
          :ok
        end)

      receipt =
        capture(fn ->
          stopped = event(&(&1["event"] == "stopped"), true)
          observe("peer_stopped", stopped)

          check(
            stopped["live_threads"] == 0 and stopped["current_alive"] == 0 and
              stopped["temp_removed"] == true and stopped["failed"] == false and
              stopped["primary_failure"] == nil and stopped["reporting_error"] == nil,
            "peer shutdown receipt"
          )

          :ok
        end)

      certificates =
        capture(fn ->
          if state().peer.ready && state().peer.ready["ca"],
            do:
              check(
                not File.exists?(Path.dirname(state().peer.ready["ca"])),
                "temporary TLS certificates remain"
              )

          :ok
        end)

      exited =
        capture(fn ->
          if state().peer.exit == nil do
            receive do
              {^port, {:exit_status, status}} ->
                update(&%{&1 | peer: %{&1.peer | exit: status, stopped: true}})
            after
              remaining() -> raise "peer process exit deadline exceeded"
            end
          end

          check(state().peer.exit == 0, "peer process exit #{inspect(state().peer.exit)}")
          :ok
        end)

      results = %{
        command: command_result,
        receipt: receipt,
        certificates: certificates,
        exit: exited
      }

      check(
        Enum.all?(results, fn {_, result} -> result.status == "PASS" end),
        "peer cleanup: #{inspect(results)}"
      )
    end

    :ok
  end

  defp command(fields), do: true = Port.command(state().peer.port, JSON.encode!(fields) <> "\n")

  defp event(predicate, allow_failure \\ false) do
    d = operation_deadline()
    event_until(predicate, d, allow_failure)
  end

  defp event_until(predicate, d, allow_failure) do
    found =
      Enum.find(Enum.with_index(Enum.reverse(state().events)), fn {item, index} ->
        not MapSet.member?(state().consumed, index) and predicate.(item)
      end)

    case found do
      {item, index} ->
        update(&%{&1 | consumed: MapSet.put(&1.consumed, index)})
        item

      nil ->
        port = state().peer.port

        receive do
          {^port, {:data, {:eol, line}}} ->
            item = JSON.decode!(line)

            update(
              &%{
                &1
                | events: [item | &1.events],
                  raw_lines: [line | &1.raw_lines],
                  bytes: &1.bytes + byte_size(line) + 1
              }
            )

            check(
              length(state().events) <= @event_limit and state().bytes <= @byte_limit,
              "peer transcript finite cap exceeded"
            )

            if item["event"] == "failure" and not allow_failure,
              do: raise("peer failure: #{inspect(item)}")

            event_until(predicate, d, allow_failure)

          {^port, {:data, {:noeol, _}}} ->
            raise "peer line exceeded finite cap"

          {^port, {:exit_status, status}} ->
            update(&%{&1 | peer: %{&1.peer | exit: status}})
            raise "peer exited before expected receipt: #{status}"
        after
          max(d - now(), 0) -> raise "peer receipt deadline exceeded"
        end
    end
  end

  defp events(name), do: state().events |> Enum.reverse() |> Enum.filter(&(&1["event"] == name))

  defp ledger(owner) do
    {:ok, counts} = Owner.status(owner)
    counts
  end

  defp eventually(fun, label), do: poll(fun, operation_deadline(), label)

  defp poll(fun, d, label) do
    if fun.() do
      :ok
    else
      check(now() < d, label <> " deadline exceeded")

      receive do
      after
        min(5, max(d - now(), 0)) -> poll(fun, d, label)
      end
    end
  end

  defp down(pid, monitor, d) do
    receive do
      {:DOWN, ^monitor, :process, ^pid, reason} ->
        check(
          reason in [:normal, :noproc, :shutdown],
          "owned actor abnormal DOWN: #{inspect(reason)}"
        )

        :ok
    after
      max(d - now(), 0) -> raise "owned actor DOWN deadline exceeded"
    end
  end

  defp cleanup_item(operation, fun), do: Map.put(capture(fun), :operation, operation)

  defp capture(fun) do
    try do
      %{status: "PASS", value: fun.()}
    rescue
      error -> %{status: "FAIL", error: Exception.format(:error, error, __STACKTRACE__)}
    catch
      kind, reason -> %{status: "FAIL", error: Exception.format(kind, reason, __STACKTRACE__)}
    end
  end

  defp check(true, _), do: :ok
  defp check(false, message), do: raise(message)

  defp observe(name, data),
    do: update(&%{&1 | observations: [%{name: name, data: json_value(data)} | &1.observations]})

  defp json_value(value) when is_map(value),
    do: Map.new(value, fn {key, item} -> {to_string(key), json_value(item)} end)

  defp json_value(value) when is_list(value), do: Enum.map(value, &json_value/1)

  defp json_value(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: value

  defp json_value(value) when is_atom(value), do: Atom.to_string(value)
  defp json_value(value), do: inspect(value, limit: 30, printable_limit: 1_000)
  defp write_json(path, value), do: File.write!(path, JSON.encode!(json_value(value)) <> "\n")
  defp sha(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp state, do: Process.get(__MODULE__)

  defp update(fun) do
    Process.put(__MODULE__, fun.(state()))
    :ok
  end

  defp update_owner(instance, fun),
    do:
      update(
        &%{
          &1
          | owners:
              Enum.map(&1.owners, fn item ->
                if item.instance == instance, do: fun.(item), else: item
              end)
        }
      )

  defp now, do: System.monotonic_time(:millisecond)
  defp deadline(timeout), do: now() + timeout
  defp operation_deadline, do: min(state().deadline, deadline(@wait))
  defp remaining, do: max(operation_deadline() - now(), 0)
end

GaoxyH1ResourceFoundationProbe.run()
