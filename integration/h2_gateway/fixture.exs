defmodule Gaoxy.H2Soak.Endpoint do
  alias Gaoxy.HTTP.{Exchange, Response}

  def init(options), do: {:ok, options}

  def call(exchange, %{owner: owner, tag: tag} = options) do
    {connection, _, _} = exchange.transport_state
    send(owner, {:owned, [self(), connection, exchange.gate]})

    case options do
      %{proxy: proxy} ->
        Gaoxy.Proxy.HTTP.call(exchange, proxy)

      _ ->
        with {:ok, next} <- Response.send_chunked(exchange, 200, [{"x-fixture-generation", tag}]),
             do: echo(next)
    end
  end

  defp echo(exchange) do
    case Exchange.read_body_step(exchange, 16_384, 500) do
      {:pending, next} ->
        echo(next)

      {:error, reason, next} ->
        {:error, reason, next}

      {kind, bytes, next} when kind in [:ok, :more] ->
        case Response.chunk(next, bytes) do
          {:ok, next} when kind == :ok -> Response.finish(next)
          {:ok, next} -> echo(next)
          {:error, reason} -> {:error, reason, next}
        end
    end
  end
end

defmodule Gaoxy.H2Soak.Fixture do
  alias Gaoxy.HTTP.Generation
  @prefix "GAOXY_H2_FIXTURE "

  def run do
    port = System.fetch_env!("GAOXY_H2_ORIGIN_PORT") |> String.to_integer()
    true = port in 1..65_535
    upstream = "http://127.0.0.1:#{port}"
    {:ok, proxy} = Gaoxy.Proxy.HTTP.init(%{upstream: upstream, max_lifetime: 30_000})
    routes = routes(self(), proxy, "0")
    {:ok, store} = Generation.start_link(routes: routes)

    {:ok, runtime} =
      Gaoxy.HTTP.start_link(
        ip: {127, 0, 0, 1},
        port: 0,
        endpoint: {Generation, store},
        protocols: [:http2],
        h2c: :prior_knowledge,
        limits: %{max_active: 128, max_bytes: 536_870_912},
        http_limits: %{request_timeout: 30_000, write_timeout: 5_000},
        h2_limits: %{max_streams: 32}
      )

    {:ok, {{127, 0, 0, 1}, port}} = Gaoxy.info(runtime, :http).local

    state = %{
      runtime: runtime,
      store: store,
      proxy: proxy,
      port: port,
      owned: %{},
      captured: 0,
      down: 0,
      reloads: 0
    }

    emit(%{
      event: "ready",
      port: port,
      pid: String.to_integer(System.pid()),
      process_count: :erlang.system_info(:process_count),
      otp: to_string(:erlang.system_info(:otp_release)),
      elixir: System.version()
    })

    loop(state)
  end

  defp routes(owner, proxy, tag),
    do: [
      %{path: "/local", target: {Gaoxy.H2Soak.Endpoint, %{owner: owner, tag: tag}}},
      %{path: "/proxy", target: {Gaoxy.H2Soak.Endpoint, %{owner: owner, tag: tag, proxy: proxy}}}
    ]

  defp loop(state) do
    case IO.gets("") do
      :eof ->
        stop(state)

      line ->
        %{"command" => command} = JSON.decode!(line)
        state = collect(state) |> capture_guardians()

        case command do
          "sample" ->
            emit(sample(state))
            loop(state)

          "reload" ->
            {:ok, _} =
              Generation.reload(
                state.store,
                routes(self(), state.proxy, Integer.to_string(state.reloads + 1)),
                2_000
              )

            {:ok, {{127, 0, 0, 1}, port}} = Gaoxy.info(state.runtime, :http).local
            true = port == state.port
            emit(%{event: "reload", count: state.reloads + 1, port: port})
            loop(%{state | reloads: state.reloads + 1})

          "stop" ->
            stop(state)
        end
    end
  end

  defp sample(state) do
    mailboxes =
      for {pid, _} <- state.owned,
          {:message_queue_len, size} <- [Process.info(pid, :message_queue_len)],
          do: %{pid: inspect(pid), size: size}

    status = Gaoxy.status(state.runtime, :http)
    true = is_map(status)

    %{
      event: "sample",
      process_count: :erlang.system_info(:process_count),
      mailboxes: mailboxes,
      admission:
        Map.take(status, [
          :active,
          :retained_bytes,
          :retained_high_water,
          :cleanup_pending,
          :cleanup_failed
        ]),
      captured: state.captured,
      down: state.down,
      live_captured: map_size(state.owned)
    }
  end

  defp capture_guardians(state) do
    guardians = DynamicSupervisor.which_children(Gaoxy.Proxy.SessionSupervisor)
    state = Enum.reduce(guardians, state, fn {_, pid, _, _}, acc -> capture(acc, pid) end)
    Enum.reduce(Task.Supervisor.children(Gaoxy.HTTP.Tasks), state, &capture(&2, &1))
  end

  defp capture(state, pid) do
    if Map.has_key?(state.owned, pid) do
      state
    else
      %{
        state
        | owned: Map.put(state.owned, pid, Process.monitor(pid)),
          captured: state.captured + 1
      }
    end
  end

  defp collect(state) do
    receive do
      {:owned, pids} ->
        collect(Enum.reduce(pids, state, &capture(&2, &1)))

      {:DOWN, monitor, :process, pid, _} ->
        if state.owned[pid] == monitor,
          do: collect(%{state | owned: Map.delete(state.owned, pid), down: state.down + 1}),
          else: collect(state)
    after
      0 -> state
    end
  end

  defp stop(state) do
    deadline = Gaoxy.Lifecycle.deadline(15_000)
    state = collect(state) |> capture_guardians()
    status = await_zero(state.runtime, deadline)
    monitor = Process.monitor(state.runtime)
    :ok = Gaoxy.stop(state.runtime, Gaoxy.Lifecycle.remaining(deadline))

    receive do
      {:DOWN, ^monitor, :process, _, _} -> :ok
    after
      Gaoxy.Lifecycle.remaining(deadline) -> raise "runtime DOWN deadline"
    end

    state = await_owned(state, deadline)
    [] = DynamicSupervisor.which_children(Gaoxy.Proxy.SessionSupervisor)
    GenServer.stop(state.store, :normal, max(1, Gaoxy.Lifecycle.remaining(deadline)))
    [] = Task.Supervisor.children(Gaoxy.HTTP.Tasks)

    {:error, :econnrefused} =
      :gen_tcp.connect(
        {127, 0, 0, 1},
        state.port,
        [:binary, active: false],
        max(1, Gaoxy.Lifecycle.remaining(deadline))
      )

    {:ok, rebound} =
      :gen_tcp.listen(state.port, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])

    :ok = :gen_tcp.close(rebound)
    true = Gaoxy.Lifecycle.remaining(deadline) > 0

    emit(%{
      event: "stopped",
      admission: Map.take(status, [:active, :retained_bytes, :cleanup_pending]),
      captured: state.captured,
      down: state.down,
      live_captured: map_size(state.owned),
      runtime_down: true,
      guardian_children: 0,
      http_tasks: 0,
      rebind: true,
      elapsed_ms: 15_000 - Gaoxy.Lifecycle.remaining(deadline)
    })

    %{"command" => "exit"} = IO.gets("") |> JSON.decode!()
    emit(%{event: "exiting"})
  end

  defp await_zero(runtime, deadline) do
    status = Gaoxy.status(runtime, :http)

    case status do
      %{active: 0, retained_bytes: 0, cleanup_pending: 0} ->
        status

      _ ->
        true = Gaoxy.Lifecycle.remaining(deadline) > 0

        receive do
        after
          5 -> await_zero(runtime, deadline)
        end
    end
  end

  defp await_owned(state, deadline) do
    state = collect(state)

    if map_size(state.owned) == 0 do
      state
    else
      receive do
        {:DOWN, monitor, :process, pid, _} ->
          true = state.owned[pid] == monitor

          await_owned(
            %{state | owned: Map.delete(state.owned, pid), down: state.down + 1},
            deadline
          )

        {:owned, pids} ->
          await_owned(Enum.reduce(pids, state, &capture(&2, &1)), deadline)
      after
        Gaoxy.Lifecycle.remaining(deadline) -> raise "captured owned process DOWN deadline"
      end
    end
  end

  defp emit(data), do: IO.puts(@prefix <> JSON.encode!(data))
end

Gaoxy.H2Soak.Fixture.run()
