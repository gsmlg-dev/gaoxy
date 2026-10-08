defmodule Gaoxy.LifecycleOwnershipTest do
  use ExUnit.Case, async: true

  defmodule Child do
    use GenServer
    def start_link, do: GenServer.start_link(__MODULE__, nil)
    def init(nil), do: {:ok, nil}

    def handle_call({:link, pid}, _, state) do
      Process.link(pid)
      {:reply, :ok, state}
    end
  end

  defmodule Backend do
    use GenServer
    def start_link, do: GenServer.start_link(__MODULE__, nil)

    def init(nil) do
      {:ok, child} = Child.start_link()
      {:ok, child}
    end

    def handle_call(:child, _, child), do: {:reply, child, child}
    def handle_call(:force, _, child), do: {:reply, :ok, child}

    def handle_call({:link, pid}, _, child) do
      Process.link(pid)
      {:reply, :ok, child}
    end
  end

  defmodule NamedOwner do
    use GenServer
    def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

    def init(nil) do
      Process.flag(:trap_exit, true)
      {:ok, backend} = Backend.start_link()
      {:ok, backend}
    end

    def handle_call(:backend, _, backend), do: {:reply, backend, backend}
    def handle_info({:EXIT, _, _}, backend), do: {:noreply, backend}

    def terminate(_, backend) do
      if Process.alive?(backend), do: Process.exit(backend, :kill)
    end
  end

  test "cleanup captures descendants whose owner is an OTP registered name" do
    owner = start_supervised!({NamedOwner, []})
    backend = GenServer.call(owner, :backend)
    child = GenServer.call(backend, :child)
    cleanup_backend(backend, child)
    {:dictionary, dictionary} = Process.info(backend, :dictionary)
    assert [NamedOwner | _] = Keyword.fetch!(dictionary, :"$ancestors")
    resources = Gaoxy.Lifecycle.resources(backend, owner)
    assert backend in resources
    assert child in resources
    refute owner in resources
    monitor = Process.monitor(child)
    assert :ok = Gaoxy.Lifecycle.force(resources, backend)
    assert_receive {:DOWN, ^monitor, :process, ^child, :killed}, 1_000
    assert Process.alive?(owner)
  end

  test "ordinary cleanup excludes unrelated raw processes linked by handlers" do
    {:ok, backend} = Backend.start_link()
    Process.unlink(backend)
    child = GenServer.call(backend, :child)
    cleanup_backend(backend, child)
    unrelated = raw_process()
    assert :ok = GenServer.call(child, {:link, unrelated})
    resources = Gaoxy.Lifecycle.resources(backend, self())
    assert backend in resources
    assert child in resources
    refute unrelated in resources
    monitor = Process.monitor(child)
    assert :ok = Gaoxy.Lifecycle.force(resources, backend)
    assert_receive {:DOWN, ^monitor, :process, ^child, :killed}, 1_000
    assert Process.alive?(unrelated)
    stop_raw(unrelated)
  end

  test "QUIC raw receiver allowance is limited to the backend root" do
    {:ok, backend} = Backend.start_link()
    Process.unlink(backend)
    child = GenServer.call(backend, :child)
    cleanup_backend(backend, child)
    receiver = raw_process()
    unrelated = raw_process()
    assert :ok = GenServer.call(backend, {:link, receiver})
    assert :ok = GenServer.call(child, {:link, unrelated})
    resources = Gaoxy.Lifecycle.resources(backend, self(), true)
    assert receiver in resources
    refute unrelated in resources
    monitor = Process.monitor(receiver)
    assert :ok = Gaoxy.Lifecycle.force(resources, backend)
    assert_receive {:DOWN, ^monitor, :process, ^receiver, :killed}, 1_000
    assert Process.alive?(unrelated)
    stop_raw(unrelated)
  end

  defp raw_process do
    owner = self()

    pid =
      spawn(fn ->
        Process.flag(:trap_exit, true)
        send(owner, {:ready, self()})
        raw_loop()
      end)

    assert_receive {:ready, ^pid}, 1_000
    on_exit(fn -> if Process.alive?(pid), do: stop_raw(pid) end)
    pid
  end

  defp cleanup_backend(backend, child) do
    on_exit(fn ->
      for pid <- [backend, child], Process.alive?(pid) do
        monitor = Process.monitor(pid)
        Process.exit(pid, :kill)
        assert_receive {:DOWN, ^monitor, :process, ^pid, _}, 1_000
      end
    end)
  end

  defp raw_loop do
    receive do
      :stop -> :ok
      {:EXIT, _, _} -> raw_loop()
    end
  end

  defp stop_raw(pid) do
    monitor = Process.monitor(pid)
    send(pid, :stop)
    assert_receive {:DOWN, ^monitor, :process, ^pid, _}, 1_000
  end
end
