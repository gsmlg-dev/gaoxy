defmodule Gaoxy.CleanupAttachmentTest do
  use ExUnit.Case, async: true
  alias Gaoxy.{Admission, Config, Lifecycle, Service}

  defmodule Native do
    use ThousandIsland.Handler

    def validate_options(%{owner: owner} = options) when is_pid(owner), do: {:ok, options}

    def handle_connection(_socket, state) do
      {:ok, lease} = Admission.acquire(state.gate, 10, drain_notify: true)
      deadline = Lifecycle.deadline(10_000)
      :ok = Admission.begin_request(state.gate, lease, 10, deadline)
      send(state.spec.handler_options.owner, {:connection, self(), state, lease, deadline})
      {:continue, Map.merge(state, %{lease: lease, deadline: deadline})}
    end

    def handle_info({:attach, guardian, bytes}, {socket, state}) do
      result =
        Service.attach_cleanup(
          state.service,
          state.gate,
          state.lease,
          guardian,
          bytes,
          state.deadline
        )

      send(state.spec.handler_options.owner, {:attached, result})
      {:noreply, {socket, state}}
    end

    def handle_info({:gaoxy_drain, _, _, _}, {socket, state}),
      do: {:stop, :normal, {socket, state}}
  end

  defp guardian do
    observer = self()
    supervisor = start_supervised!({Task.Supervisor, []}, id: make_ref())

    {:ok, pid} =
      Task.Supervisor.start_child(supervisor, fn -> guardian_loop(observer, nil, nil) end)

    on_exit(fn -> if Process.alive?(pid), do: send(pid, :finish) end)
    pid
  end

  defp guardian_loop(observer, service, token) do
    receive do
      {:configure, service} ->
        guardian_loop(observer, service, token)

      {:gaoxy_cleanup_activate, token} ->
        send(observer, {:activated, self(), token})
        guardian_loop(observer, service, token)

      {:gaoxy_cleanup_cancel, token, reason, deadline} ->
        send(observer, {:cancelled, self(), token, reason, deadline})
        guardian_loop(observer, service, token)

      :receipt ->
        result = Service.complete_cleanup(service, token)
        send(observer, {:receipt, self(), result})
        guardian_loop(observer, service, token)

      :finish ->
        if service && Process.alive?(service), do: Service.complete_cleanup(service, token)
        :ok

      {:die, reason} ->
        exit(reason)
    end
  end

  defp gate do
    {:ok, spec} =
      Config.service(%{
        id: "native",
        transport: :tcp,
        handler_mode: :native,
        handler: Native,
        handler_options: %{owner: self()},
        limits: %{max_active: 1, max_bytes: 100}
      })

    start_supervised!(
      {Admission,
       {spec.limits,
        %{instance: self(), service: "native", generation: make_ref(), service_pid: self()}}}
    )
  end

  defp connected do
    runtime =
      start_supervised!(
        {Gaoxy,
         services: [
           %{
             id: "native",
             transport: :tcp,
             handler_mode: :native,
             handler: Native,
             handler_options: %{owner: self()},
             limits: %{drain_timeout: 200, max_bytes: 100}
           }
         ]}
      )

    {:ok, {ip, port}} = Gaoxy.info(runtime, "native").local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    assert_receive {:connection, owner, context, lease, deadline}, 1000
    assert context.instance == runtime
    assert is_pid(context.service)
    {runtime, owner, context, lease, deadline}
  end

  defp attached do
    {runtime, owner, context, lease, deadline} = connected()
    guardian = guardian()
    send(guardian, {:configure, context.service})
    send(owner, {:attach, guardian, 30})
    assert_receive {:attached, {:ok, token}}, 1000
    assert_receive {:activated, ^guardian, ^token}, 1000
    {runtime, owner, context, lease, deadline, guardian, token}
  end

  defp eventually(fun, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(1500)

    if fun.() do
      :ok
    else
      assert Lifecycle.remaining(deadline) > 0

      receive do
      after
        2 -> eventually(fun, deadline)
      end
    end
  end

  test "reservation survives absolute native accounting and owner death without another slot" do
    gate = gate()
    observer = self()

    owner =
      spawn(fn ->
        {:ok, lease} = Admission.acquire(gate, 10, drain_notify: true)
        deadline = Lifecycle.deadline(5000)
        :ok = Admission.begin_request(gate, lease, 10, deadline)
        send(observer, {:lease, self(), lease, deadline})

        receive do
          :update ->
            :ok = Admission.begin_callback(gate, lease, 20, deadline)
            :ok = Admission.update(gate, lease, 40)
            :ok = Admission.retain(gate, lease, 0)
            send(observer, :updated)

            receive do
              :finish -> :ok
            end
        end
      end)

    on_exit(fn -> if Process.alive?(owner), do: Process.exit(owner, :kill) end)
    assert_receive {:lease, ^owner, lease, deadline}
    guardian = guardian()
    token = make_ref()
    assert :ok = Admission.attach_cleanup(gate, owner, lease, guardian, 30, deadline, token)
    assert %{active: 1, cleanup_pending: 1, retained_bytes: 40} = Admission.status(gate)
    assert {:error, :active_limit} = Admission.acquire(gate, 0)
    send(owner, :update)
    assert_receive :updated
    assert %{retained_bytes: 30} = Admission.status(gate)
    send(owner, :finish)
    eventually(fn -> Admission.status(gate).active == 0 end)
    assert %{cleanup_pending: 1, retained_bytes: 30} = Admission.status(gate)
    send(guardian, :finish)
    eventually(fn -> Admission.status(gate).cleanup_pending == 0 end)
    assert %{retained_bytes: 0} = Admission.status(gate)
  end

  test "only the service can attach an active native request with one reservation" do
    gate = gate()
    {:ok, lease} = Admission.acquire(gate, 10, drain_notify: true)
    guardian = guardian()
    deadline = Lifecycle.deadline(5000)
    token = make_ref()

    assert {:error, :inactive_request} =
             Admission.attach_cleanup(gate, self(), lease, guardian, 20, deadline, token)

    assert :ok = Admission.begin_request(gate, lease, 10, deadline)
    parent = self()

    spawn(fn ->
      send(
        parent,
        {:unauthorized,
         Admission.attach_cleanup(gate, parent, lease, guardian, 20, deadline, token)}
      )
    end)

    assert_receive {:unauthorized, {:error, :unauthorized_service}}

    assert {:error, :byte_limit} =
             Admission.attach_cleanup(gate, self(), lease, guardian, 91, deadline, token)

    assert {:error, :deadline_exceeded} =
             Admission.attach_cleanup(gate, self(), lease, guardian, 20, deadline - 1, token)

    assert :ok = Admission.attach_cleanup(gate, self(), lease, guardian, 20, deadline, token)

    assert {:error, :cleanup_attached} =
             Admission.attach_cleanup(gate, self(), lease, guardian, 20, deadline, make_ref())
  end

  test "service authenticates lease owner and rejects attachment after its drain barrier" do
    {runtime, owner, context, lease, deadline} = connected()
    guardian = guardian()

    assert {:error, :stale_generation} =
             Service.attach_cleanup(context.service, context.gate, lease, guardian, 20, deadline)

    :ok = :sys.suspend(context.service)
    parent = self()
    spawn(fn -> send(parent, {:removed, Gaoxy.remove(runtime, "native", 1000)}) end)
    eventually(fn -> elem(Process.info(context.service, :message_queue_len), 1) > 0 end)
    send(owner, {:attach, guardian, 20})
    :ok = :sys.resume(context.service)
    assert_receive {:attached, {:error, :draining}}, 1000
    refute_receive {:activated, ^guardian, _}, 30
    assert_receive {:removed, :ok}, 1500
  end

  test "WebSocket upgrade renews the admitted request while preserving its cleanup reservation" do
    gate = gate()
    {:ok, lease} = Admission.acquire(gate, 10, drain_notify: true)
    deadline = Lifecycle.deadline(5000)
    assert {:error, :inactive_request} = Admission.upgrade(gate, lease, 10, deadline)
    assert :ok = Admission.begin_request(gate, lease, 10, deadline)
    guardian = guardian()
    token = make_ref()
    assert :ok = Admission.attach_cleanup(gate, self(), lease, guardian, 20, deadline, token)
    lifetime = deadline + 5000
    assert :ok = Admission.upgrade(gate, lease, 40, lifetime)
    assert %{active: 1, cleanup_pending: 1, retained_bytes: 60} = Admission.status(gate)
    assert {:error, :cleanup_pending} = Admission.begin_request(gate, lease, 0, lifetime)
    assert :ok = Admission.begin_callback(gate, lease, 5, lifetime)
    assert :ok = Admission.retain(gate, lease, 0)
    assert %{retained_bytes: 20} = Admission.status(gate)
    assert :ok = Admission.mode(gate, :paused)
    assert {:error, :paused} = Admission.upgrade(gate, lease, 0, lifetime)
  end

  test "a stalled admission registration fails closed without activating the guardian" do
    {_runtime, owner, context, _lease, _deadline} = connected()
    guardian = guardian()
    monitor = Process.monitor(owner)
    :ok = :sys.suspend(context.gate)
    send(owner, {:attach, guardian, 20})
    assert_receive {:DOWN, ^monitor, :process, ^owner, :killed}, 1000
    eventually(fn -> not Process.alive?(context.service) end)
    refute_receive {:activated, ^guardian, _}, 30
    assert Process.alive?(guardian)
  end

  test "admission fails closed on guardian death before service observes it" do
    gate = gate()
    {:ok, lease} = Admission.acquire(gate, 10, drain_notify: true)
    deadline = Lifecycle.deadline(5000)
    assert :ok = Admission.begin_request(gate, lease, 10, deadline)
    guardian = guardian()
    assert :ok = Admission.attach_cleanup(gate, self(), lease, guardian, 20, deadline, make_ref())
    send(guardian, {:die, :normal})
    eventually(fn -> Admission.status(gate).cleanup_pending == 0 end)
    assert {:error, :failed} = Admission.acquire(gate, 0)
    assert {:error, :failed} = Admission.begin_request(gate, lease, 0, deadline)
  end

  test "clean stop needs both authenticated receipt and guardian DOWN" do
    {runtime, _owner, context, _lease, _deadline, guardian, token} = attached()
    assert {:error, :stale_cleanup} = Service.complete_cleanup(context.service, token)
    parent = self()
    spawn(fn -> send(parent, {:stopped, Gaoxy.stop(runtime, 1000)}) end)
    assert_receive {:cancelled, ^guardian, _, :draining, _}, 1000
    send(guardian, :receipt)
    assert_receive {:receipt, ^guardian, :ok}, 1000
    refute_receive {:stopped, _}, 30
    assert Process.alive?(context.service)
    send(guardian, :finish)
    assert_receive {:stopped, :ok}, 1500
  end

  test "timed out stop keeps guardian alive and reports cleanup pending" do
    {runtime, _owner, context, _lease, _deadline, guardian, _token} = attached()
    assert {:error, {:deadline_exceeded, :cleanup_pending}} = Gaoxy.stop(runtime, 10)
    assert Process.alive?(guardian)
    assert_receive {:cancelled, ^guardian, _, _, _}, 1000
    send(guardian, :finish)
    eventually(fn -> not Process.alive?(context.service) end)
  end

  test "gate death cancels cleanup without killing guardian or reporting clean removal" do
    {_runtime, _owner, context, _lease, _deadline, guardian, _token} = attached()
    Process.exit(context.gate, :kill)
    assert_receive {:cancelled, ^guardian, _, _, _}, 1000
    assert Process.alive?(guardian)
    assert Process.alive?(context.service)
    send(guardian, :finish)
    eventually(fn -> not Process.alive?(context.service) end)
  end

  test "guardian death without receipt fails the service closed" do
    {runtime, _owner, context, _lease, _deadline, guardian, _token} = attached()
    send(guardian, {:die, :normal})
    eventually(fn -> not Process.alive?(context.service) end)
    assert {:error, :not_running} = Gaoxy.info(runtime, "native")
  end

  test "abnormal guardian exit after receipt cannot yield successful drain" do
    {runtime, _owner, _context, _lease, _deadline, guardian, _token} = attached()
    parent = self()
    spawn(fn -> send(parent, {:removed, Gaoxy.remove(runtime, "native", 1000)}) end)
    assert_receive {:cancelled, ^guardian, _, :draining, _}, 1000
    send(guardian, :receipt)
    assert_receive {:receipt, ^guardian, :ok}, 1000
    send(guardian, {:die, :injected})
    assert_receive {:removed, {:error, {:cleanup_failed, _}}}, 1500
  end

  test "connection death retains reservation until independently supervised cleanup finishes" do
    {runtime, owner, context, _lease, _deadline, guardian, _token} = attached()
    Process.exit(owner, :kill)
    eventually(fn -> Admission.status(context.gate).active == 0 end)
    assert %{cleanup_pending: 1, retained_bytes: 30} = Gaoxy.status(runtime, "native")
    send(guardian, :finish)
    eventually(fn -> Admission.status(context.gate).cleanup_pending == 0 end)
  end

  test "external instance owner death cancels but does not kill a pending guardian" do
    observer = self()

    external_owner =
      spawn(fn ->
        {:ok, runtime} =
          Gaoxy.start_link(
            services: [
              %{
                id: "native",
                transport: :tcp,
                handler_mode: :native,
                handler: Native,
                handler_options: %{owner: observer},
                limits: %{drain_timeout: 30, max_bytes: 100}
              }
            ]
          )

        send(observer, {:runtime, runtime})

        receive do
          :finish -> :ok
        end
      end)

    assert_receive {:runtime, runtime}
    {:ok, {ip, port}} = Gaoxy.info(runtime, "native").local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    assert_receive {:connection, owner, context, _lease, _deadline}, 1000
    service_monitor = Process.monitor(context.service)
    guardian = guardian()
    send(guardian, {:configure, context.service})
    send(owner, {:attach, guardian, 30})
    assert_receive {:attached, {:ok, token}}, 1000
    assert_receive {:activated, ^guardian, ^token}, 1000
    send(external_owner, :finish)
    assert_receive {:cancelled, ^guardian, ^token, _, _}, 1000
    eventually(fn -> not Process.alive?(runtime) end, Lifecycle.deadline(3000))
    assert Process.alive?(guardian)
    send(guardian, :finish)
    assert_receive {:DOWN, ^service_monitor, :process, service, :shutdown}, 1500
    assert service == context.service
  end
end
