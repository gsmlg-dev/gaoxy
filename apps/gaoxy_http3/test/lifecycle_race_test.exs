defmodule Gaoxy.HTTP.HTTP3.LifecycleRaceTest do
  use ExUnit.Case, async: true
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Exchange, Request, Resources}
  alias Gaoxy.HTTP.HTTP3.{Operations, Options, Stream}

  defmodule Endpoint do
    def init(options), do: {:ok, options}

    def call(exchange, observer) do
      send(observer, {:dispatched, self(), exchange})
      {:ok, %{exchange | response: :sent}}
    end
  end

  defmodule CompletedTransport do
    def finish(exchange, []), do: {:ok, exchange}
  end

  defmodule Provider do
    use GenServer
    @behaviour Resources
    def start_link(observer), do: GenServer.start_link(__MODULE__, observer)
    def init(observer), do: {:ok, %{observer: observer, pins: %{}}}

    def pin_many([handle], holder, kind, operation, deadline),
      do: Lifecycle.call(handle.owner, {:pin, holder, kind, operation}, deadline)

    def release(pin), do: GenServer.call(pin.owner, {:release, pin.ref})
    def cancel(owner, operation), do: GenServer.cast(owner, {:cancel, operation})

    def handle_call({:pin, holder, kind, operation}, _, state) do
      ref = make_ref()
      monitor = Process.monitor(holder)
      pin = %{provider: __MODULE__, owner: self(), ref: ref, operation: operation, kind: kind}
      send(state.observer, {:request_pin, holder, ref})
      {:reply, {:ok, pin}, %{state | pins: Map.put(state.pins, ref, {monitor, operation})}}
    end

    def handle_call({:release, ref}, _, state), do: {:reply, :ok, remove(state, ref)}
    def handle_call(:count, _, state), do: {:reply, map_size(state.pins), state}

    def handle_cast({:cancel, operation}, state) do
      refs = for {ref, {_, op}} <- state.pins, op == operation, do: ref
      {:noreply, Enum.reduce(refs, state, &remove(&2, &1))}
    end

    def handle_info({:DOWN, monitor, :process, _, _}, state) do
      refs = for {ref, {mon, _}} <- state.pins, mon == monitor, do: ref
      {:noreply, Enum.reduce(refs, state, &remove(&2, &1))}
    end

    defp remove(state, ref) do
      case Map.pop(state.pins, ref) do
        {nil, _} ->
          state

        {{monitor, _}, pins} ->
          Process.demonitor(monitor, [:flush])
          %{state | pins: pins}
      end
    end
  end

  defmodule BusyPlug do
    def init(options), do: options

    def call(conn, %{observer: observer, provider: provider}) do
      exchange = elem(conn.adapter, 1)
      handle = %{provider: Provider, owner: provider, owner_epoch: make_ref()}
      {:ok, pins} = Resources.pin_many([handle], self(), :request, exchange.deadline)
      ref = make_ref()
      send(observer, {:plug_busy, self(), ref, exchange.deadline})
      # A busy Plug has no DOWN clause and the test never sends this release.
      receive do
        {:release_plug, ^ref} -> Resources.release(pins)
      end

      conn
    end
  end

  defp options do
    {:ok, spec} =
      Options.normalize(endpoint: {Endpoint, self()}, tls: %{certfile: "c", keyfile: "k"})

    spec
  end

  defp gate(limits) do
    start_supervised!({Admission, {limits, %{instance: make_ref(), service: :h3_test}}},
      id: make_ref()
    )
  end

  defp owner(gate, spec, endpoint, deadline, dispatch \\ true) do
    observer = self()

    owner =
      spawn(fn ->
        table = Operations.new()
        key = make_ref()
        token = make_ref()
        :ok = Operations.register(table, key, token, deadline)
        reserve = Options.reservation(spec.handler_options).request
        owner = self()

        {:ok, worker} =
          Task.Supervisor.start_child(Gaoxy.HTTP.Tasks, fn ->
            Stream.run(owner, table, key, token, gate, reserve, deadline)
          end)

        :ok = Operations.bind(table, key, token, worker)
        send(observer, {:starting, self(), table, key, token, worker})

        receive do
          :start -> send(worker, {:h3_start, self(), key, token})
        end

        await_ready(table, key, token, deadline)
        {:ok, %{lease: lease}} = Operations.status(table, key, token)
        send(observer, {:ready, self(), worker, lease})

        if dispatch do
          :ok = Operations.activate(table, key, token, worker)

          exchange = %Exchange{
            request: %Request{
              method: "GET",
              version: :"HTTP/3",
              path: "/",
              host: "localhost",
              headers: []
            },
            gate: gate,
            deadline: deadline,
            limits: spec.handler_options.http_limits,
            body: %{phase: :done, total: 0, trailers: [], trailer_bytes: 0},
            buffer: "",
            transport: CompletedTransport,
            transport_state: {self(), table, key, token},
            peer: {{127, 0, 0, 1}, 1234},
            local: {{127, 0, 0, 1}, 4321},
            secure: true
          }

          send(worker, {:h3_dispatch, self(), key, token, exchange, endpoint})
        end

        receive do
          :stop -> :ok
        end
      end)

    on_exit(fn -> if Process.alive?(owner), do: Process.exit(owner, :kill) end)
    assert_receive {:starting, ^owner, table, key, token, worker}, 1_000
    {owner, table, key, token, worker}
  end

  defp await_ready(table, key, token, deadline) do
    case Operations.status(table, key, token) do
      {:ok, %{status: :ready}} ->
        :ok

      _ ->
        if Lifecycle.remaining(deadline) == 0, do: raise("worker readiness deadline")

        receive do
        after
          1 -> await_ready(table, key, token, deadline)
        end
    end
  end

  defp confirmed(gate, provider, deadline) do
    status = Admission.status(gate)

    if status.active == 0 and status.retained_bytes == 0 and GenServer.call(provider, :count) == 0 do
      :ok
    else
      if Lifecycle.remaining(deadline) == 0,
        do: flunk("termination_unconfirmed: #{inspect(status)}")

      receive do
      after
        1 -> confirmed(gate, provider, deadline)
      end
    end
  end

  defp monitored(owner, worker, deadline) do
    case Process.info(worker, :monitors) do
      {:monitors, monitors} ->
        if {:process, owner} in monitors do
          :ok
        else
          if Lifecycle.remaining(deadline) == 0, do: flunk("owner monitor was not installed")

          receive do
          after
            1 -> monitored(owner, worker, deadline)
          end
        end

      nil ->
        flunk("worker exited before installing its owner monitor")
    end
  end

  test "start barrier binds the worker before admission and preserves the original deadline" do
    spec = options()
    gate = gate(spec.limits)
    deadline = Lifecycle.deadline(1_000)
    {owner, table, key, token, worker} = owner(gate, spec, {Endpoint, self()}, deadline)
    assert Admission.status(gate).active == 0
    refute_received {:dispatched, _, _}
    send(owner, :start)
    assert_receive {:ready, ^owner, ^worker, lease}, 1_000
    assert_receive {:dispatched, ^worker, exchange}, 1_000
    assert exchange.deadline == deadline
    assert exchange.lease == lease
    assert exchange.request.version == :"HTTP/3"
    monitor = Process.monitor(worker)
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    assert {:ok, %{status: {:finished, :ok}}} = Operations.status(table, key, token)
    send(owner, :stop)
  end

  test "owner death before the token start barrier ends the unadmitted worker" do
    spec = options()
    gate = gate(spec.limits)

    {owner, table, _, _, worker} =
      owner(gate, spec, {Endpoint, self()}, Lifecycle.deadline(1_000))

    assert monitored(owner, worker, Lifecycle.deadline(1_000)) == :ok
    monitor = Process.monitor(worker)
    owner_monitor = Process.monitor(owner)
    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :killed}, 1_000
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    assert :ets.info(table) == :undefined
    assert Admission.status(gate).active == 0
    refute_received {:dispatched, _, _}
  end

  test "stale start and dispatch tokens cannot invoke an endpoint and admitted owner loss is cooperative" do
    spec = options()
    gate = gate(spec.limits)
    deadline = Lifecycle.deadline(1_000)
    {owner, table, key, token, worker} = owner(gate, spec, {Endpoint, self()}, deadline, false)
    assert monitored(owner, worker, deadline) == :ok
    send(worker, {:h3_start, owner, key, make_ref()})
    assert Admission.status(gate).active == 0
    send(owner, :start)
    assert_receive {:ready, ^owner, ^worker, _}, 1_000
    assert Admission.status(gate).active == 1

    send(
      worker,
      {:h3_dispatch, owner, key, make_ref(), %{deadline: deadline}, {Endpoint, self()}}
    )

    assert {:ok, %{status: :ready}} = Operations.status(table, key, token)
    refute_received {:dispatched, _, _}
    monitor = Process.monitor(worker)
    owner_monitor = Process.monitor(owner)
    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :killed}, 1_000
    assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, 1_000
    assert :ets.info(table) == :undefined
    provider = start_supervised!({Provider, self()})
    assert confirmed(gate, provider, deadline) == :ok
    refute_received {:dispatched, _, _}
  end

  test "a busy Plug survives owner kill only until original D with confirmed independent cleanup" do
    spec = options()
    gate = gate(spec.limits)
    provider = start_supervised!({Provider, self()})
    deadline = Lifecycle.deadline(800)
    endpoint = {Gaoxy.HTTP.PlugEndpoint, {BusyPlug, %{observer: self(), provider: provider}}}
    {owner, table, _, _, worker} = owner(gate, spec, endpoint, deadline)
    send(owner, :start)
    assert_receive {:ready, ^owner, ^worker, _}, 1_000
    assert_receive {:request_pin, ^worker, _}, 1_000
    assert_receive {:plug_busy, ^worker, ref, ^deadline}, 1_000
    assert is_reference(ref)
    assert GenServer.call(provider, :count) == 1
    assert Admission.status(gate).active == 1
    monitor = Process.monitor(worker)
    owner_monitor = Process.monitor(owner)
    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :killed}, 1_000
    assert :ets.info(table) == :undefined
    # No link to the owner: only Admission's armed deadline can stop this Plug.
    assert Process.alive?(worker)
    cleanup_deadline = deadline + Lifecycle.cleanup_headroom()

    assert_receive {:DOWN, ^monitor, :process, ^worker, :killed},
                   Lifecycle.remaining(cleanup_deadline)

    assert Process.alive?(gate)
    assert confirmed(gate, provider, cleanup_deadline) == :ok
    # Separate connection on the same Admission service and a separate listener.
    for sibling_gate <- [gate, gate(spec.limits)] do
      {sibling, _, _, _, sibling_worker} =
        owner(sibling_gate, spec, {Endpoint, self()}, Lifecycle.deadline(1_000))

      send(sibling, :start)
      assert_receive {:ready, ^sibling, ^sibling_worker, _}, 1_000
      assert_receive {:dispatched, ^sibling_worker, _}, 1_000
      send(sibling, :stop)
    end
  end
end
