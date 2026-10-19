fixture =
  Enum.find(
    [
      Path.expand("support/managed_h1_matrix_fixture.exs", __DIR__),
      Path.expand("apps/gaoxy_proxy/test/support/managed_h1_matrix_fixture.exs"),
      Path.expand("test/support/managed_h1_matrix_fixture.exs")
    ],
    &File.regular?/1
  ) || raise "managed H1 fixture source not found"

Code.require_file(fixture)

defmodule Gaoxy.Proxy.HTTPCompletedResponseTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH1MatrixFixture, as: Fixture
  alias Gaoxy.Proxy.UpstreamTransports

  @moduletag :capture_log
  @moduletag timeout: 20_000
  @phase_ms 5_000

  defmodule Endpoint do
    @behaviour Gaoxy.HTTP.Endpoint

    def init(
          %{close_observer: observer, close_reference: reference, close_deadline: deadline} =
            options
        ) do
      options = Map.drop(options, [:close_observer, :close_reference, :close_deadline])

      with {:ok, config} <- Gaoxy.Proxy.HTTP.init(options),
           do: {:ok, {config, observer, reference, deadline}}
    end

    def resources({config, _, _, _}), do: Gaoxy.Proxy.HTTP.resources(config)

    def call(exchange, {config, observer, reference, deadline}) do
      send(observer, {:close_native, reference, self(), exchange.request.path, exchange.deadline})

      exchange =
        if exchange.request.path == "/successful-close" do
          %{
            exchange
            | transport: Gaoxy.Proxy.HTTPCompletedResponseTest.Transport,
              transport_state: {observer, reference, deadline}
          }
        else
          exchange
        end

      result = Gaoxy.Proxy.HTTP.call(exchange, config)
      send(observer, {:close_result, reference, self(), result})
      result
    end
  end

  defmodule Transport do
    alias Gaoxy.HTTP.Exchange
    alias Gaoxy.HTTP.HTTP1.Response
    alias Hell.Socket

    def send_resp(exchange, status, fields, body),
      do: wrap(Response.send_resp(native(exchange), status, fields, body), exchange)

    def send_chunked(exchange, status, fields),
      do: wrap(Response.send_chunked(native(exchange), status, fields), exchange)

    def finish(exchange, trailers),
      do: wrap(Response.finish(native(exchange), trailers), exchange)

    def body_complete?(exchange), do: Exchange.body_complete?(native(exchange))

    def poll_connection(exchange, wait),
      do: wrap(Exchange.poll_connection(native(exchange), wait), exchange)

    def chunk(exchange, bytes) do
      case Response.chunk(native(exchange), bytes) do
        {:ok, %{response: {:fixed_stream, 0}} = next} -> barrier(next, exchange.transport_state)
        result -> wrap(result, exchange)
      end
    end

    defp native(exchange), do: %{exchange | transport: nil, transport_state: nil}

    defp wrap({:ok, next}, exchange), do: {:ok, wrapped(next, exchange)}
    defp wrap({:pending, next}, exchange), do: {:pending, wrapped(next, exchange)}
    defp wrap({:more, next}, exchange), do: {:more, wrapped(next, exchange)}

    defp wrap({:error, reason, next}, exchange),
      do: {:error, reason, wrapped(next, exchange)}

    defp wrap(result, _), do: result

    defp wrapped(next, exchange),
      do: %{next | transport: __MODULE__, transport_state: exchange.transport_state}

    defp barrier(next, {observer, reference, phase_deadline}) do
      phase_deadline = min(phase_deadline, next.deadline)
      send(observer, {:close_body_written, reference, self()})

      receive do
        {:close_arm, ^reference, guardian, deadline} ->
          case collect_end(guardian, reference, deadline, []) do
            {:ok, held} ->
              send(observer, {:close_end_fenced, reference, self(), held})
              confirm_eof(next, observer, reference, deadline)

            :abort ->
              {:error, :test_barrier_aborted}
          end

        {:close_abort, ^reference} ->
          {:error, :test_barrier_aborted}
      after
        remaining(phase_deadline) -> raise "final native write barrier was not armed"
      end
    end

    defp collect_end(guardian, reference, deadline, held) do
      receive do
        {:gaoxy_proxy_http, ^guardian, {:end, _}} = original when held == [] ->
          collect_end(guardian, reference, deadline, [original])

        {:gaoxy_proxy_http, ^guardian, {:end, _}} ->
          raise "duplicate original upstream end at native write barrier"

        {:gaoxy_proxy_http, ^guardian, {:error, _}} ->
          raise "upstream error before native write fence"

        {:close_end_fence, ^reference, ^guardian} ->
          {:ok, held}

        {:close_abort, ^reference} ->
          Enum.each(held, &send(self(), &1))
          :abort
      after
        remaining(deadline) ->
          Enum.each(held, &send(self(), &1))
          raise "own Session end fence did not arrive"
      end
    end

    defp confirm_eof(next, observer, reference, deadline) do
      receive do
        {:close_check_eof, ^reference} ->
          case Socket.recv(next.socket, 1, remaining(deadline)) do
            {:error, :closed} ->
              send(observer, {:close_eof, reference, self()})

              receive do
                {:close_release, ^reference} -> {:ok, next}
                {:close_abort, ^reference} -> {:error, :test_barrier_aborted}
              after
                remaining(deadline) -> raise "native write release deadline"
              end

            _ ->
              raise "real downstream EOF was not established"
          end

        {:close_abort, ^reference} ->
          {:error, :test_barrier_aborted}
      after
        remaining(deadline) -> raise "downstream close command did not arrive"
      end
    end

    defp remaining(deadline), do: max(0, deadline - System.monotonic_time(:millisecond))
  end

  test "a completed native fixed response survives downstream close before original upstream end" do
    reference = make_ref()
    deadline = System.monotonic_time(:millisecond) + @phase_ms

    f =
      Fixture.start(%{"mount" => "fixed", "downstream" => "h1", "upstream" => "tcp"}, %{
        endpoint_module: Endpoint,
        endpoint: %{close_observer: self(), close_reference: reference, close_deadline: deadline}
      })

    Process.put(reference, %{
      fixture: f,
      clients: [],
      native: nil,
      guardian: nil,
      held: [],
      actors: []
    })

    on_exit(fn ->
      if Process.alive?(f.instance) or Process.alive?(f.peer), do: Fixture.stop(f)
    end)

    outcome =
      try do
        run(f, reference, deadline)
        :ok
      catch
        kind, reason -> {:error, kind, reason, __STACKTRACE__}
      end

    cleanup_errors = cleanup(reference)

    case outcome do
      :ok ->
        assert cleanup_errors == [], "regression teardown failed: #{inspect(cleanup_errors)}"

      {:error, kind, reason, stack} ->
        if cleanup_errors != [],
          do: IO.warn("regression teardown failed: #{inspect(cleanup_errors)}")

        :erlang.raise(kind, reason, stack)
    end
  end

  defp run(f, reference, deadline) do
    client = connect(f, reference, deadline)
    :ok = :gen_tcp.send(client, request("/successful-close"))
    native = native(reference, "/successful-close", deadline)
    remember(reference, :native, native)
    track(reference, native)
    native_monitor = Process.monitor(native)

    first =
      Fixture.event(f, %{"event" => "request", "target" => "/successful-close"}, left(deadline))

    {guardian, completion} = binding(f, native, deadline)
    remember(reference, :guardian, guardian)
    track(reference, guardian)
    guardian_monitor = Process.monitor(guardian)

    on_exit(fn ->
      send(native, {:close_abort, reference})
      if Process.alive?(guardian), do: :sys.resume(guardian, @phase_ms)
    end)

    respond(f, first, "body", deadline)
    assert read_response(client, deadline) == "body"
    assert_receive {:close_body_written, ^reference, ^native}, left(deadline)
    assert :ok = :sys.suspend(guardian, left(deadline))
    send(native, {:close_arm, reference, guardian, deadline})

    :sys.replace_state(
      guardian,
      fn opaque ->
        send(native, {:close_end_fence, reference, guardian})
        opaque
      end,
      left(deadline)
    )

    assert_receive {:close_end_fenced, ^reference, ^native, held}, left(deadline)
    assert length(held) <= 1
    remember(reference, :held, held)
    assert :ok = :gen_tcp.close(client)
    send(native, {:close_check_eof, reference})
    assert_receive {:close_eof, ^reference, ^native}, left(deadline)
    send(native, {:close_release, reference})
    await_native_wait(native, native_monitor, reference, deadline)

    restore(reference)
    assert :ok = :sys.resume(guardian, left(deadline))
    assert_receive {:close_result, ^reference, ^native, {:ok, %{response: :sent}}}, left(deadline)
    assert :ok = HTTP.RequestCompletion.await(completion, left(deadline))
    assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, left(deadline)

    assert_receive {:DOWN, ^native_monitor, :process, ^native, {:shutdown, :local_closed}},
                   left(deadline)

    remember(reference, :guardian, nil)
    remember(reference, :native, nil)

    next_client = connect(f, reference, deadline)
    :ok = :gen_tcp.send(next_client, request("/after"))
    next_native = native(reference, "/after", deadline)
    track(reference, next_native)
    next_monitor = Process.monitor(next_native)
    second = Fixture.event(f, %{"event" => "request", "target" => "/after"}, left(deadline))

    assert second["connection"] == first["connection"],
           "application changed accepted upstream connection"

    assert second["request"] == first["request"] + 1
    {next_guardian, next_completion} = binding(f, next_native, deadline)
    track(reference, next_guardian)
    next_guardian_monitor = Process.monitor(next_guardian)
    respond(f, second, "next", deadline)
    assert read_response(next_client, deadline) == "next"

    assert_receive {:close_result, ^reference, ^next_native, {:ok, %{response: :sent}}},
                   left(deadline)

    assert :ok = HTTP.RequestCompletion.await(next_completion, left(deadline))

    assert_receive {:DOWN, ^next_guardian_monitor, :process, ^next_guardian, :normal},
                   left(deadline)

    assert_receive {:DOWN, ^next_monitor, :process, ^next_native, {:shutdown, :local_closed}},
                   left(deadline)

    :ok = :gen_tcp.close(next_client)
    await_clean(f, deadline)
  end

  defp binding(f, native, deadline) do
    case Map.to_list(:sys.get_state(f.owner, left(deadline)).tokens) do
      [{token, %{completion: %HTTP.RequestCompletion{}} = hold}] ->
        state = :sys.get_state(hold.guardian, left(deadline))
        assert state.owner == native
        assert state.transport_selection == {f.handle, token}
        assert state.client == Gaoxy.Proxy.HTTPFetchClient
        assert state.client.completion(state.original_request) == hold.completion
        {hold.guardian, hold.completion}

      _ ->
        wait = min(1, left(deadline))

        receive do
        after
          wait -> binding(f, native, deadline)
        end
    end
  end

  defp await_native_wait(native, monitor, reference, deadline) do
    receive do
      {:close_result, ^reference, ^native, result} ->
        summary =
          case result do
            {:error, reason, exchange} -> {:error, reason, exchange.response}
            {:ok, exchange} -> {:ok, exchange.response}
          end

        flunk("proxy returned before original upstream end was released: #{inspect(summary)}")

      {:DOWN, ^monitor, :process, ^native, reason} ->
        flunk("native owner exited before original upstream end: #{inspect(reason)}")
    after
      0 -> :ok
    end

    case Process.info(native, [:status, :current_function, :current_stacktrace]) do
      [
        status: :waiting,
        current_function: {Gaoxy.Proxy.HTTP, :pump_wait, 2},
        current_stacktrace: _
      ] ->
        :ok

      _ ->
        wait = min(1, left(deadline))

        receive do
        after
          wait -> await_native_wait(native, monitor, reference, deadline)
        end
    end
  end

  defp await_clean(f, deadline) do
    {service, transport} =
      within(
        fn -> {Gaoxy.status(f.instance, :http), UpstreamTransports.status(f.owner)} end,
        deadline
      )

    if match?(%{active: 0, cleanup_pending: 0, retained_bytes: 0, cleanup_failed: nil}, service) and
         match?(
           {:ok,
            %{request_tokens: 0, helpers: 0, pins: 1, resources: 1, reserved_connections: 2}},
           transport
         ) do
      :ok
    else
      wait = min(1, left(deadline))

      receive do
      after
        wait -> await_clean(f, deadline)
      end
    end
  end

  defp within(fun, deadline) do
    parent = self()
    reference = make_ref()
    {pid, monitor} = spawn_monitor(fn -> send(parent, {reference, fun.()}) end)

    receive do
      {^reference, result} ->
        assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, left(deadline)
        result

      {:DOWN, ^monitor, :process, ^pid, reason} ->
        flunk("own status observer failed: #{inspect(reason)}")
    after
      left(deadline) ->
        Process.exit(pid, :kill)
        assert_receive {:DOWN, ^monitor, :process, ^pid, _}, @phase_ms
        flunk("own status observer exceeded the original phase deadline")
    end
  end

  defp native(reference, path, deadline) do
    assert_receive {:close_native, ^reference, native, ^path, original_deadline}, left(deadline)
    assert original_deadline >= deadline
    assert original_deadline - System.monotonic_time(:millisecond) <= 10_000
    native
  end

  defp connect(f, reference, deadline) do
    assert {:ok, socket} =
             :gen_tcp.connect({127, 0, 0, 1}, f.port, [:binary, active: false], left(deadline))

    remember(reference, :clients, [socket | Process.get(reference).clients])
    socket
  end

  defp request(path),
    do: "GET #{path} HTTP/1.1\r\nHost: downstream.test\r\nConnection: close\r\n\r\n"

  defp respond(f, request, body, deadline) do
    raw = "HTTP/1.1 200 OK\r\nContent-Length: #{byte_size(body)}\r\n\r\n#{body}"

    command =
      Map.merge(Map.take(request, ["connection", "request"]), %{
        "action" => "send",
        "body64" => Base.encode64(raw),
        "ended" => true
      })

    assert :ok = Fixture.dispatch_command(f, command)

    assert %{"ended" => true} =
             Fixture.event(
               f,
               Map.put(Map.take(request, ["connection", "request"]), "event", "command"),
               left(deadline)
             )
  end

  defp read_response(socket, deadline) do
    head = read_head(socket, deadline, "")
    assert head =~ "HTTP/1.1 200 OK\r\n"
    assert String.downcase(head) =~ "\r\ncontent-length: 4\r\n"
    assert {:ok, body} = :gen_tcp.recv(socket, 4, left(deadline))
    body
  end

  defp read_head(socket, deadline, bytes) do
    assert byte_size(bytes) < 8192

    if String.ends_with?(bytes, "\r\n\r\n") do
      bytes
    else
      assert {:ok, byte} = :gen_tcp.recv(socket, 1, left(deadline))
      read_head(socket, deadline, bytes <> byte)
    end
  end

  defp remember(reference, field, value),
    do: Process.put(reference, Map.put(Process.get(reference), field, value))

  defp track(reference, actor),
    do: remember(reference, :actors, [actor | Process.get(reference).actors])

  defp restore(reference) do
    context = Process.get(reference)
    remember(reference, :held, [])
    Enum.each(context.held, &send(context.native, &1))
  end

  defp cleanup(reference) do
    context = Process.get(reference)
    deadline = System.monotonic_time(:millisecond) + @phase_ms

    operations = [
      fn ->
        if is_pid(context.native) and Process.alive?(context.native) do
          receive do
            {:close_end_fenced, ^reference, native, held} when native == context.native ->
              remember(reference, :held, held)
          after
            0 -> :ok
          end

          restore(reference)
          send(context.native, {:close_abort, reference})
        end
      end,
      fn ->
        if is_pid(context.guardian) and Process.alive?(context.guardian),
          do: :sys.resume(context.guardian, left(deadline))
      end,
      fn -> Enum.each(context.clients, &:gen_tcp.close/1) end,
      fn ->
        joined = Fixture.stop(context.fixture, left(deadline))
        assert joined["accepted"] == 1
        assert joined["forced"] == 0 and joined["live"] == 0
      end,
      fn ->
        for actor <- context.actors do
          monitor = Process.monitor(actor)
          assert_receive {:DOWN, ^monitor, :process, ^actor, _}, left(deadline)
        end
      end
    ]

    Enum.flat_map(operations, fn operation ->
      try do
        operation.()
        []
      catch
        kind, reason -> [{kind, Exception.format_banner(kind, reason)}]
      end
    end)
  end

  defp left(deadline) do
    remaining = max(0, deadline - System.monotonic_time(:millisecond))
    assert remaining > 0, "original successful-close phase deadline exhausted"
    remaining
  end
end
