defmodule Gaoxy.HTTP.StreamLifetimeGenerationTest do
  use ExUnit.Case, async: true
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Exchange, Generation, Request, Router}

  defmodule Provider do
    use GenServer
    @behaviour Gaoxy.HTTP.Resources
    def start_link(observer), do: GenServer.start_link(__MODULE__, observer)
    def init(observer), do: {:ok, %{observer: observer, pins: %{}}}

    def pin_many([handle], holder, kind, operation, deadline),
      do: Lifecycle.call(handle.owner, {:pin, holder, kind, operation}, deadline)

    def release(pin), do: GenServer.call(pin.owner, {:release, pin})
    def cancel(owner, operation), do: GenServer.call(owner, {:cancel, operation})

    def handle_call({:pin, holder, kind, operation}, _, state) do
      pin = %{provider: __MODULE__, owner: self(), ref: make_ref(), operation: operation}
      record = %{holder: holder, kind: kind, monitor: Process.monitor(holder)}
      {:reply, {:ok, pin}, %{state | pins: Map.put(state.pins, pin.ref, record)}}
    end

    def handle_call({:release, pin}, {holder, _}, state) do
      case state.pins[pin.ref] do
        %{holder: ^holder} -> {:reply, :ok, remove(state, pin.ref)}
        _ -> {:reply, {:error, :unauthorized}, state}
      end
    end

    def handle_call({:cancel, operation}, _, state) do
      # Acquisition rollback is not exercised by this fixture.
      send(state.observer, {:unexpected_cancel, operation})
      {:reply, :ok, state}
    end

    def handle_call(:requests, _, state),
      do: {:reply, Enum.count(state.pins, fn {_, pin} -> pin.kind == :request end), state}

    def handle_info({:DOWN, monitor, :process, _, _}, state) do
      refs = for {ref, pin} <- state.pins, pin.monitor == monitor, do: ref
      {:noreply, Enum.reduce(refs, state, &remove(&2, &1))}
    end

    defp remove(state, ref) do
      Process.demonitor(state.pins[ref].monitor, [:flush])
      %{state | pins: Map.delete(state.pins, ref)}
    end
  end

  defmodule Accounting do
    def reservation(m, _), do: {:ok, {:native_generation_capture_v1, m, 65_536, 65_536, 16_384}}

    def validate_manifest(handles),
      do: with({:ok, _} <- Gaoxy.HTTP.Resources.validate(handles), do: :ok)

    def correlate(
          %{provider: provider, owner: owner, operation: operation},
          {provider, owner, operation, _},
          _holder
        ),
        do: :ok

    def preflight_cons(pin, pins), do: summary([pin | pins])
    def preflight_append(new, old), do: summary(new ++ old)
    def finite_checked_reason(reason), do: reason

    def release(pin, deadline) do
      send(Process.get(__MODULE__), {:release_deadline, self(), deadline})
      Lifecycle.call(pin.owner, {:release, pin}, deadline)
    end

    defp summary(pins), do: {:ok, %{count: length(pins), bytes: :erlang.external_size(pins)}}
  end

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def resources(options), do: [options.handle]

    def call(exchange, options) do
      original = exchange

      exchange =
        if options.timeout == :request do
          exchange
        else
          {:ok, latest} =
            exchange |> Exchange.put_stream_timeout(options.timeout) |> Exchange.begin_stream()

          %{latest | response: :chunked}
        end

      send(options.observer, {:generation_stream_started, self(), exchange})

      receive do
        :complete ->
          case options.outcome do
            :ok -> {:ok, exchange}
            :error -> {:error, :test_stream_error, exchange}
            :lost_latest -> {:error, :test_stream_error, original}
            :throw -> throw(:test_stream_throw)
          end
      after
        5_000 -> raise "generation stream fixture was not completed"
      end
    end
  end

  for {timeout, outcome} <- [
        {:infinity, :ok},
        {3_000, :ok},
        {:infinity, :error},
        {:infinity, :lost_latest},
        {:infinity, :throw}
      ] do
    test "#{inspect(timeout)} streaming #{outcome} releases generation pins past the old cleanup deadline" do
      fixture = fixture(unquote(timeout), unquote(outcome))
      assert_receive {:generation_stream_started, worker, latest}, 1_000
      assert worker == fixture.worker
      assert latest.deadline != fixture.deadline
      assert GenServer.call(fixture.provider, :requests) == 1
      wait_until(fixture.deadline + 1_010)
      assert Process.alive?(worker)
      completed_at = Lifecycle.now()
      send(worker, :complete)
      assert_receive {:generation_result, ^worker, result}, 1_000

      case unquote(outcome) do
        :ok ->
          assert result == {:ok, latest}

        :error ->
          assert result == {:error, :test_stream_error, latest}

        :lost_latest ->
          assert {:error, :test_stream_error, %{deadline: original}} = result
          assert original == fixture.deadline

        :throw ->
          assert result == {:caught, :throw, :test_stream_throw}
      end

      assert_receive {:release_deadline, ^worker, cleanup_deadline}, 100
      assert cleanup_deadline >= completed_at
      assert cleanup_deadline <= Lifecycle.now() + 1_000
      assert GenServer.call(fixture.provider, :requests) == 0
      assert Process.alive?(worker)
      finish(fixture)
    end
  end

  test "request deadline inspection is owner-only and bounds its call timeout" do
    assert {:ok, spec} = Gaoxy.HTTP.service_spec(plug: {Plug.Logger, []})
    gate = start_supervised!({Admission, {spec.limits, %{}}})
    assert {:ok, lease} = Admission.acquire(gate, 0, drain_notify: true)
    deadline = Lifecycle.deadline(1_000)
    assert :ok = Admission.begin_request(gate, lease, 0, deadline)
    assert {:ok, ^deadline} = Admission.request_deadline(gate, lease, 50)
    observer = self()

    spawn(fn ->
      send(observer, {:other_owner_deadline, Admission.request_deadline(gate, lease, 50)})
    end)

    assert_receive {:other_owner_deadline, {:error, :stale_lease}}
    assert {:error, :stale_lease} = Admission.request_deadline(gate, make_ref(), 50)

    for timeout <- [0, 51, :infinity] do
      assert_raise FunctionClauseError, fn -> Admission.request_deadline(gate, lease, timeout) end
    end
  end

  test "request deadline inspection does not wait indefinitely for an unresponsive owner" do
    observer = self()

    stalled =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    caller =
      spawn(fn ->
        result =
          try do
            Admission.request_deadline(stalled, make_ref(), 50)
          catch
            :exit, {:timeout, _} -> :bounded_timeout
          end

        send(observer, {:deadline_probe, result})
      end)

    on_exit(fn ->
      Process.exit(stalled, :kill)
      Process.exit(caller, :kill)
    end)

    assert_receive {:deadline_probe, :bounded_timeout}, 500
    send(stalled, :stop)
  end

  for outcome <- [:ok, :throw] do
    test "ordinary #{outcome} retains its original bounded generation cleanup deadline" do
      fixture = fixture(:request, unquote(outcome))
      assert_receive {:generation_stream_started, worker, latest}, 1_000
      assert latest.deadline == fixture.deadline
      send(worker, :complete)
      assert_receive {:generation_result, ^worker, result}, 1_000

      if unquote(outcome) == :ok,
        do: assert(result == {:ok, latest}),
        else: assert(result == {:caught, :throw, :test_stream_throw})

      assert_receive {:release_deadline, ^worker, deadline}, 100
      assert deadline == fixture.deadline + 1_000
      assert GenServer.call(fixture.provider, :requests) == 0
      finish(fixture)
    end
  end

  defp fixture(timeout, outcome) do
    observer = self()
    provider = start_supervised!({Provider, observer})
    handle = %{provider: Provider, owner: provider, owner_epoch: make_ref()}
    options = %{observer: observer, handle: handle, timeout: timeout, outcome: outcome}
    assert {:ok, router} = Router.compile([%{target: {Endpoint, options}}])
    store = start_supervised!({Generation, router: router})
    assert {:ok, spec} = Gaoxy.HTTP.service_spec(endpoint: {Endpoint, options})
    gate = start_supervised!({Admission, {spec.limits, %{}}})
    deadline = Lifecycle.deadline(500)

    {worker, monitor} =
      spawn_monitor(fn ->
        Process.put(Accounting, observer)
        {:ok, lease} = Admission.acquire(gate, 0, drain_notify: true)
        :ok = Admission.begin_request(gate, lease, 0, deadline)
        {:ok, config} = Generation.init({store, accounting: Accounting})

        exchange = %Exchange{
          gate: gate,
          lease: lease,
          deadline: deadline,
          buffer: "",
          limits: spec.handler_options.http_limits,
          request: %Request{method: "GET", path: "/", host: "localhost", head_bytes: 0},
          body: Gaoxy.HTTP.HTTP1.Body.new(:none)
        }

        result =
          try do
            Generation.call(exchange, config)
          catch
            kind, value -> {:caught, kind, value}
          end

        send(observer, {:generation_result, self(), result})

        receive do
          :finish -> :ok
        after
          2_000 -> exit(:generation_stream_not_joined)
        end
      end)

    on_exit(fn -> if Process.alive?(worker), do: Process.exit(worker, :kill) end)
    %{worker: worker, monitor: monitor, deadline: deadline, provider: provider, gate: gate}
  end

  defp finish(fixture) do
    send(fixture.worker, :finish)
    assert_receive {:DOWN, monitor, :process, worker, :normal}, 1_000
    assert monitor == fixture.monitor and worker == fixture.worker

    eventually(fn ->
      status = Admission.status(fixture.gate)
      status.active == 0 and status.retained_bytes == 0 and status.cleanup_pending == 0
    end)
  end

  defp wait_until(deadline) do
    receive do
    after
      max(Lifecycle.remaining(deadline), 0) -> :ok
    end
  end

  defp eventually(check, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(1_000)

    unless check.() do
      assert Lifecycle.remaining(deadline) > 0

      receive do
      after
        2 -> eventually(check, deadline)
      end
    end
  end
end
