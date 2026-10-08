defmodule Gaoxy.LifecycleFaultTest do
  # Exclusive ephemeral-port reuse must not race other tests allocating UDP sockets.
  use ExUnit.Case, async: false
  @moduletag :loopback
  @moduletag :capture_log

  defmodule Handler do
    def handle_datagram(packet, owner) do
      send(owner, {:admitted, self(), packet.data})

      receive do
        :release -> {:reply, packet.data}
      end
    end
  end

  defp spec(id, timeout \\ 300),
    do: %{
      id: id,
      transport: :udp,
      handler: Handler,
      handler_options: self(),
      limits: %{drain_timeout: timeout, callback_timeout: 5_000}
    }

  defp runtime(ids \\ ["one"]), do: start_supervised!({Gaoxy, services: Enum.map(ids, &spec/1)})

  defp service(runtime, id \\ "one") do
    {:ok, pid, _} = GenServer.call(runtime, {:lookup, id})
    {pid, :sys.get_state(pid)}
  end

  defp admit(runtime, id \\ "one") do
    {ip, port} = Gaoxy.info(runtime, id).local
    {:ok, client} = :gen_udp.open(0, [:binary, active: false])
    on_exit(fn -> :gen_udp.close(client) end)
    :ok = :gen_udp.send(client, ip, port, id)
    assert_receive {:admitted, worker, ^id}, 2_000
    {client, worker, {ip, port}}
  end

  defp async_call(tag, fun) do
    owner = self()
    spawn(fn -> send(owner, {tag, fun.()}) end)
  end

  defp wait(predicate, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(2_000)

    if predicate.() do
      :ok
    else
      assert Gaoxy.Lifecycle.remaining(deadline) > 0

      receive do
      after
        2 -> wait(predicate, deadline)
      end
    end
  end

  test "two stalled services share one parent deadline and both barriers precede cleanup" do
    parent =
      start_supervised!(%{
        id: make_ref(),
        start:
          {Supervisor, :start_link,
           [[{Gaoxy, services: [spec("a"), spec("b")]}], [strategy: :one_for_one]]},
        type: :supervisor
      })

    [{_, instance, _, _}] = Supervisor.which_children(parent)

    owned =
      for id <- ["a", "b"] do
        {pid, state} = service(instance, id)
        {_, worker, endpoint} = admit(instance, id)
        [listener] = Abyss.Listener.for_server(state.backend)
        {socket, _} = Abyss.Listener.socket_info(listener)
        resources = Gaoxy.Lifecycle.resources(state.backend, pid)
        {pid, state, worker, endpoint, socket, resources}
      end

    started = Gaoxy.Lifecycle.now()
    async_call(:stopped, fn -> Supervisor.stop(parent) end)
    for {pid, _, _, _, _, _} <- owned, do: wait(fn -> :sys.get_state(pid).mode == :draining end)

    deadlines =
      for {pid, state, worker, _, _, _} <- owned do
        assert {:error, :draining} = Gaoxy.Admission.acquire(state.gate, 0)
        assert Process.alive?(worker)
        :sys.get_state(pid).drain.deadline
      end

    assert [deadline] = Enum.uniq(deadlines)
    assert deadline - started <= 350
    assert_receive {:stopped, :ok}, 1_500
    assert Gaoxy.Lifecycle.now() - started < 1_000

    for {pid, state, worker, {ip, port}, original_socket, resources} <- owned do
      refute Enum.any?([pid, state.backend, state.gate, worker | resources], &Process.alive?/1)
      assert :erlang.port_info(original_socket) == :undefined
      assert {:ok, socket} = :gen_udp.open(port, ip: ip, active: false)
      :gen_udp.close(socket)
    end
  end

  for fault <- [:error, :exception, :normal_exit, :block] do
    @tag fault: fault
    test "drain backend #{fault} cannot produce false success", %{fault: fault} do
      instance = runtime()
      {pid, state} = service(instance)
      {_, worker, _} = admit(instance)
      owner = self()

      :sys.replace_state(pid, fn s ->
        %{
          s
          | drain_fun: fn _, _, _, _ ->
              send(owner, {:helper, self()})

              case fault do
                :error ->
                  {:error, :injected}

                :exception ->
                  raise "injected backend failure"

                :normal_exit ->
                  :erlang.exit(self(), :normal)

                :block ->
                  receive do
                    :never -> :ok
                  end
              end
            end
        }
      end)

      started = Gaoxy.Lifecycle.now()
      result = Gaoxy.remove(instance, "one", 100)

      if fault == :block do
        assert {:error, {:deadline_exceeded, :cleanup_pending}} = result
      else
        assert {:error, {:cleanup_failed, _}} = result
      end

      assert Gaoxy.Lifecycle.now() - started < 500
      wait(fn -> not Process.alive?(pid) end)
      refute Enum.any?([state.backend, state.gate, worker], &Process.alive?/1)
      assert [] = Gaoxy.services(instance)
    end
  end

  test "a helper returning ok while resources live requires confirmed forced cleanup" do
    instance = runtime()
    {pid, state} = service(instance)
    {_, worker, _} = admit(instance)
    :sys.replace_state(pid, &%{&1 | drain_fun: fn _, _, _, _ -> :ok end})
    assert :ok = Gaoxy.remove(instance, "one", 1_000)
    refute Enum.any?([pid, state.backend, state.gate, worker], &Process.alive?/1)
  end

  test "zero and small budgets return uncertainty and owned cleanup still completes" do
    for timeout <- [0, 1] do
      instance = start_supervised!({Gaoxy, services: [spec("zero")]}, id: make_ref())
      {pid, state} = service(instance, "zero")
      {_, worker, _} = admit(instance, "zero")

      assert {:error, {:deadline_exceeded, :cleanup_pending}} =
               Gaoxy.remove(instance, "zero", timeout)

      wait(fn -> not Process.alive?(pid) end)
      refute Enum.any?([state.backend, state.gate, worker], &Process.alive?/1)
    end
  end

  test "caller death does not abandon removal and concurrent removal is rejected" do
    instance = runtime()
    {pid, state} = service(instance)
    {client, worker, {ip, port}} = admit(instance)
    caller = async_call(:removed, fn -> Gaoxy.remove(instance, "one", 1_000) end)
    wait(fn -> :sys.get_state(pid).mode == :draining end)
    assert {:error, :already_draining} = Gaoxy.remove(instance, "one", 1_000)
    Process.exit(caller, :kill)
    send(worker, :release)
    assert {:ok, {^ip, ^port, "one"}} = :gen_udp.recv(client, 0, 1_000)
    wait(fn -> not Process.alive?(pid) end)
    refute Process.alive?(state.backend)
    assert [] = Gaoxy.services(instance)
    assert {:error, :not_running} = Gaoxy.remove(instance, "one", 100)
  end

  test "instance stop aggregates multiple cleanup errors without multiplying its deadline" do
    instance = runtime(["one", "two"])

    for id <- ["one", "two"] do
      {pid, _} = service(instance, id)
      :sys.replace_state(pid, &%{&1 | drain_fun: fn _, _, _, _ -> {:error, :injected} end})
    end

    monitor = Process.monitor(instance)
    assert {:error, {:services, errors}} = Gaoxy.stop(instance, 1_000)

    assert [
             {"one", {:error, {:cleanup_failed, {:error, :injected}}}},
             {"two", {:error, {:cleanup_failed, {:error, :injected}}}}
           ] = Enum.sort(errors)

    assert_receive {:DOWN, ^monitor, :process, ^instance, :normal}, 1_000
  end

  test "pause backend error and resume backend error retain a fail-closed admission barrier" do
    for operation <- [:pause, :resume] do
      instance = start_supervised!({Gaoxy, services: [spec("one")]}, id: make_ref())
      {pid, state} = service(instance)
      if operation == :resume, do: assert(:ok == Gaoxy.pause(instance, "one"))
      :sys.replace_state(pid, &%{&1 | backend_control: fn _, _, _ -> {:error, :injected} end})

      assert {:error, {:transition_failed, ^operation, {:error, :injected}}} =
               apply(Gaoxy, operation, [instance, "one"])

      assert %{state: :failed} = Gaoxy.status(instance, "one")
      assert {:error, :paused} = Gaoxy.Admission.acquire(state.gate, 0)
      assert {:error, :failed} = Gaoxy.resume(instance, "one")
      assert :ok = Gaoxy.remove(instance, "one", 1_000)
    end
  end

  test "gate failure after backend success closes owned resources without publishing ready" do
    for operation <- [:pause, :resume] do
      instance = start_supervised!({Gaoxy, services: [spec("one")]}, id: make_ref())
      {pid, state} = service(instance)
      if operation == :resume, do: assert(:ok == Gaoxy.pause(instance, "one"))

      :sys.replace_state(
        pid,
        &%{
          &1
          | backend_control: fn op, transport, backend ->
              :ok = state.backend_control.(op, transport, backend)
              :ok = :sys.suspend(state.gate)
              :ok
            end
        }
      )

      assert {:error, {:transition_failed, ^operation, _}} =
               apply(Gaoxy, operation, [instance, "one"])

      wait(fn -> not Process.alive?(pid) end)
      refute Process.alive?(state.backend)
      refute Process.alive?(state.gate)
    end
  end

  test "a late resume cannot reopen admission after drain starts" do
    instance = runtime()
    {pid, state} = service(instance)
    {client, worker, {ip, port}} = admit(instance)
    assert :ok = Gaoxy.pause(instance, "one")
    owner = self()

    :sys.replace_state(
      pid,
      &%{
        &1
        | backend_control: fn _, _, _ ->
            send(owner, :resuming)

            receive do
              :finish -> :ok
            end
          end
      }
    )

    async_call(:resumed, fn -> Gaoxy.resume(instance, "one") end)
    assert_receive :resuming, 1_000
    control = :sys.get_state(pid).control
    async_call(:removed, fn -> Gaoxy.remove(instance, "one", 1_000) end)
    assert_receive {:resumed, {:error, :draining}}, 1_000
    wait(fn -> :sys.get_state(pid).mode == :draining end)
    send(pid, {:controlled, state.generation, control.token, control.pid, :ok})
    assert {:error, :draining} = Gaoxy.Admission.acquire(state.gate, 0)
    send(worker, :release)
    assert {:ok, {^ip, ^port, "one"}} = :gen_udp.recv(client, 0, 1_000)
    assert_receive {:removed, :ok}, 1_000
    assert {:ok, fresh} = Gaoxy.add(instance, spec("one"))
    assert fresh.generation != state.generation
    {replacement, _} = service(instance)
    send(replacement, {:controlled, state.generation, control.token, control.pid, :ok})
    send(replacement, {:drained, state.generation, make_ref(), self(), :ok})
    send(replacement, {:drain_deadline, make_ref()})
    assert %{state: :ready} = Gaoxy.status(instance, fresh)
  end

  test "stop caller death and repeated stop keep one owned cleanup operation" do
    instance = runtime(["one", "two"])
    resources = for id <- ["one", "two"], do: {id, service(instance, id), admit(instance, id)}
    monitor = Process.monitor(instance)
    caller = async_call(:stopped, fn -> Gaoxy.stop(instance, 1_000) end)
    for {_, {pid, _}, _} <- resources, do: wait(fn -> :sys.get_state(pid).mode == :draining end)
    assert {:error, :stopping} = Gaoxy.stop(instance, 100)
    assert {:error, :stopping} = Gaoxy.remove(instance, "one", 100)
    Process.exit(caller, :kill)

    for {id, _, {client, worker, {ip, port}}} <- resources do
      send(worker, :release)
      assert {:ok, {^ip, ^port, ^id}} = :gen_udp.recv(client, 0, 1_000)
    end

    assert_receive {:DOWN, ^monitor, :process, ^instance, :normal}, 1_500

    for {_, {pid, state}, {_, worker, _}} <- resources do
      refute Enum.any?([pid, state.backend, state.gate, worker], &Process.alive?/1)
    end
  end

  test "pause helper exits and times out without reopening the gate" do
    for fault <- [:exit, :block] do
      instance = start_supervised!({Gaoxy, services: [spec("one")]}, id: make_ref())
      {pid, state} = service(instance)

      :sys.replace_state(
        pid,
        &%{
          &1
          | backend_control: fn _, _, _ ->
              case fault do
                :exit ->
                  exit(:injected)

                :block ->
                  receive do
                    :never -> :ok
                  end
              end
            end
        }
      )

      assert {:error, {:transition_failed, :pause, _}} = Gaoxy.pause(instance, "one")
      assert %{state: :failed} = Gaoxy.status(instance, "one")
      assert {:error, :paused} = Gaoxy.Admission.acquire(state.gate, 0)
      assert :ok = Gaoxy.remove(instance, "one", 1_000)
    end
  end
end
