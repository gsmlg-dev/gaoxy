defmodule Gaoxy.NativeStreamTest do
  use ExUnit.Case, async: true
  alias Gaoxy.{Admission, Config, Lifecycle}

  defmodule Native do
    use ThousandIsland.Handler

    def validate_options(%{owner: owner} = options) when is_pid(owner), do: {:ok, options}

    def validate_options(options) do
      case Keyword.fetch(options, :owner) do
        {:ok, owner} when is_pid(owner) -> {:ok, %{owner: owner}}
        _ -> {:error, :missing_owner}
      end
    end

    def handle_connection(_socket, %{spec: spec, gate: gate} = state) do
      {:ok, lease} = Admission.acquire(gate, 0, drain_notify: true)
      send(spec.handler_options.owner, {:native_connection, self(), gate, lease, state.scope})
      {:continue, Map.put(state, :lease, lease)}
    end

    def handle_data(data, socket, state) do
      :ok =
        Admission.begin_request(state.gate, state.lease, byte_size(data), Lifecycle.deadline(500))

      :ok = ThousandIsland.Socket.send(socket, data)
      :ok = Admission.retain(state.gate, state.lease, 0)
      {:continue, state}
    end

    def handle_info({:gaoxy_drain, gate, lease, deadline}, {socket, state}) do
      send(state.spec.handler_options.owner, {:native_drain, self(), gate, lease, deadline})
      {:stop, :normal, {socket, state}}
    end
  end

  defmodule MissingValidator do
    use ThousandIsland.Handler
  end

  defmodule InvalidValidator do
    use ThousandIsland.Handler
    def validate_options(_), do: :ok
  end

  defmodule Stream do
    def init(_, _), do: {:ok, ""}
    def handle_data(data, state), do: {:send, data, state}
  end

  defp spec(extra \\ %{}),
    do:
      Map.merge(
        %{
          id: "native",
          transport: :tcp,
          handler_mode: :native,
          handler: Native,
          handler_options: [owner: self()]
        },
        extra
      )

  test "stream remains the default and native options are normalized before binding" do
    assert {:ok, %{handler_mode: :stream}} =
             Config.service(%{id: "stream", transport: :tcp, handler: Stream})

    owner = self()

    assert {:ok, %{handler_mode: :native, handler_options: %{owner: ^owner}}} =
             Config.service(spec())

    assert {:ok, %{handler_mode: :native}} =
             Config.service(spec(%{transport: :tls, tls: %{certfile: "cert", keyfile: "key"}}))
  end

  test "invalid native mode, transport, callbacks and options fail before opening a listener" do
    assert {:error, :invalid_handler_mode} = Config.service(spec(%{handler_mode: :other}))
    assert {:error, :native_requires_stream_transport} = Config.service(spec(%{transport: :udp}))
    assert {:error, :invalid_handler} = Config.service(spec(%{handler: MissingValidator}))
    assert {:error, :invalid_handler} = Config.service(spec(%{handler: Stream}))
    assert {:error, :invalid_handler_options} = Config.service(spec(%{handler: InvalidValidator}))

    assert {:error, {:handler_options, :missing_owner}} =
             Config.service(spec(%{handler_options: []}))

    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)
    :gen_tcp.close(listener)

    assert {:error, {:handler_options, :missing_owner}} =
             Gaoxy.start_link(services: [spec(%{port: port, handler_options: []})])

    assert {:ok, available} = :gen_tcp.listen(port, [:binary, active: false, ip: {127, 0, 0, 1}])
    :gen_tcp.close(available)
  end

  test "native TCP dispatch gets context and service removal notifies and confirms cleanup" do
    runtime = start_supervised!({Gaoxy, services: [spec()]})
    {:ok, {ip, port}} = Gaoxy.info(runtime, "native").local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    assert_receive {:native_connection, handler, gate, lease,
                    %{service: "native", generation: generation}},
                   1000

    assert is_reference(generation)
    assert :ok = :gen_tcp.send(socket, "hello native")
    assert {:ok, "hello native"} = :gen_tcp.recv(socket, 0, 1000)
    assert %{active: 1, retained_bytes: 0} = Gaoxy.status(runtime, "native")

    assert {:ok, %{id: "other"}} =
             Gaoxy.add(runtime, %{id: "other", transport: :tcp, handler: Stream})

    monitor = Process.monitor(handler)
    started = Lifecycle.now()
    assert :ok = Gaoxy.remove(runtime, "native", 1000)
    assert_receive {:native_drain, ^handler, ^gate, ^lease, deadline}, 1000
    assert deadline in started..(started + 1000)
    assert_receive {:DOWN, ^monitor, :process, ^handler, :normal}, 1000
    refute Process.alive?(gate)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
    assert {:error, :not_running} = Gaoxy.info(runtime, "native")
  end

  test "drain atomically rejects new requests while admitted callbacks can progress" do
    gate = gate()
    {:ok, lease} = Admission.acquire(gate, 0, drain_notify: true)
    deadline = Lifecycle.deadline(1000)
    assert :ok = Admission.begin_request(gate, lease, 10, deadline)
    assert :ok = Admission.drain(gate, deadline)
    assert_receive {:gaoxy_drain, ^gate, ^lease, ^deadline}
    assert {:error, :draining} = Admission.begin_request(gate, lease, 20, deadline)
    assert {:error, :draining} = Admission.acquire(gate, 0)
    assert :ok = Admission.begin_callback(gate, lease, 20, deadline)
    assert %{retained_bytes: 20} = Admission.status(gate)
    assert :ok = Admission.retain(gate, lease, 0)
  end

  test "native notification is opt-in and duplicates preserve the original deadline" do
    gate = gate()
    {:ok, lease} = Admission.acquire(gate, 0, drain_notify: true)
    {:ok, _legacy} = Admission.acquire(gate, 0)
    deadline = Lifecycle.deadline(1000)
    assert :ok = Admission.drain(gate, deadline)
    assert_receive {:gaoxy_drain, ^gate, ^lease, ^deadline}
    assert :ok = Admission.drain(gate, deadline + 5000)
    refute_receive {:gaoxy_drain, _, _, _}, 30
    assert :ok = Admission.mode(gate, :ready)
    assert {:error, :draining} = Admission.begin_request(gate, lease, 0, deadline)
  end

  test "pause rejects new native requests while allowing admitted callback progress" do
    gate = gate()
    {:ok, lease} = Admission.acquire(gate, 0, drain_notify: true)
    deadline = Lifecycle.deadline(1000)
    assert :ok = Admission.begin_request(gate, lease, 10, deadline)
    assert :ok = Admission.mode(gate, :paused)
    assert {:error, :paused} = Admission.begin_request(gate, lease, 0, deadline)
    assert :ok = Admission.begin_callback(gate, lease, 20, deadline)
    assert :ok = Admission.retain(gate, lease, 0)
    assert :ok = Admission.mode(gate, :ready)
    assert :ok = Admission.begin_request(gate, lease, 10, deadline)
    assert :ok = Admission.retain(gate, lease, 0)
  end

  test "request and callback enforce ownership, retained bytes and absolute deadlines" do
    gate = gate()
    {:ok, lease} = Admission.acquire(gate, 0)
    deadline = Lifecycle.deadline(1000)

    for action <- [:begin_request, :begin_callback] do
      assert {:error, :stale_generation} =
               Task.async(fn -> apply(Admission, action, [gate, lease, 0, deadline]) end)
               |> Task.await()

      assert {:error, :byte_limit} = apply(Admission, action, [gate, lease, -1, deadline])
      assert {:error, :byte_limit} = apply(Admission, action, [gate, lease, 101, deadline])

      assert {:error, :deadline_exceeded} =
               apply(Admission, action, [gate, lease, 0, Lifecycle.now() - 1])
    end

    assert %{active: 1, retained_bytes: 0} = Admission.status(gate)
  end

  test "fresh setup callbacks cannot cross pause or drain admission barriers" do
    for mode <- [:paused, :draining] do
      gate = gate()
      {:ok, lease} = Admission.acquire(gate, 0, drain_notify: true)
      deadline = Lifecycle.deadline(1000)

      if mode == :paused,
        do: Admission.mode(gate, :paused),
        else: Admission.drain(gate, deadline)

      assert {:error, ^mode} = Admission.begin_callback(gate, lease, 0, deadline)
    end
  end

  test "setup callbacks retain their original deadline until a request is admitted" do
    gate = gate()
    owner = self()

    worker =
      spawn(fn ->
        {:ok, lease} = Admission.acquire(gate, 0)
        deadline = Lifecycle.deadline(100)
        :ok = Admission.begin_callback(gate, lease, 0, deadline)
        :ok = Admission.retain(gate, lease, 0)
        :ok = Admission.begin_callback(gate, lease, 0, Lifecycle.deadline(2000))
        send(owner, {:setup_started, self(), deadline})

        receive do
          :finished -> :ok
        end
      end)

    monitor = Process.monitor(worker)
    assert_receive {:setup_started, ^worker, deadline}
    assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, 500
    assert Lifecycle.now() < deadline + 400
  end

  test "absolute watchdog expires stalled native work without callback renewal" do
    gate = gate()
    owner = self()

    worker =
      spawn(fn ->
        {:ok, lease} = Admission.acquire(gate, 10, drain_notify: true)
        deadline = Lifecycle.deadline(100)
        :ok = Admission.begin_request(gate, lease, 10, deadline)
        send(owner, {:admitted, self(), lease, deadline})

        receive do
          {:gaoxy_drain, ^gate, ^lease, _} ->
            :ok = Admission.begin_callback(gate, lease, 20, Lifecycle.deadline(2000))
            send(owner, :continued)

            receive do
              :never -> :ok
            end
        end
      end)

    on_exit(fn -> if Process.alive?(worker), do: Process.exit(worker, :kill) end)
    monitor = Process.monitor(worker)
    assert_receive {:admitted, ^worker, _lease, deadline}
    assert :ok = Admission.drain(gate, Lifecycle.deadline(3000))
    assert_receive :continued
    assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, 500
    assert Lifecycle.now() < deadline + 400
    eventually(fn -> Admission.status(gate).active == 0 end)
    assert %{retained_bytes: 0} = Admission.status(gate)
  end

  test "a shorter callback budget does not shorten the original request deadline" do
    gate = gate()
    owner = self()

    worker =
      spawn(fn ->
        {:ok, lease} = Admission.acquire(gate, 0)
        :ok = Admission.begin_request(gate, lease, 0, Lifecycle.deadline(1000))
        :ok = Admission.begin_callback(gate, lease, 0, Lifecycle.deadline(40))
        :ok = Admission.retain(gate, lease, 0)
        :ok = Admission.begin_callback(gate, lease, 0, Lifecycle.deadline(500))
        send(owner, {:callback_active, self()})

        receive do
          :finish -> :ok
        end
      end)

    on_exit(fn -> if Process.alive?(worker), do: Process.exit(worker, :kill) end)
    monitor = Process.monitor(worker)
    assert_receive {:callback_active, ^worker}
    refute_receive {:DOWN, ^monitor, :process, ^worker, _}, 100
    send(worker, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, 1000
  end

  defp gate do
    {:ok, %{limits: limits}} =
      Config.service(%{id: "legacy", transport: :tcp, handler: Stream, limits: %{max_bytes: 100}})

    start_supervised!(
      {Admission, {limits, %{instance: self(), service: "native", generation: make_ref()}}},
      id: make_ref()
    )
  end

  defp eventually(fun, attempts \\ 100)

  defp eventually(fun, attempts) when attempts > 0 do
    if fun.(),
      do: :ok,
      else:
        (receive do
         after
           5 -> eventually(fun, attempts - 1)
         end)
  end

  defp eventually(_, 0), do: flunk("cleanup did not converge")
end
