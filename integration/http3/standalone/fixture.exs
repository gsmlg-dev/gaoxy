defmodule Gaoxy.StandaloneH3Fixture do
  import ExUnit.Assertions
  alias Gaoxy.Server.{Config, Supervisor}
  alias Gaoxy.HTTP.Generation

  def emit(data), do: IO.puts("GAOXY_STANDALONE " <> JSON.encode!(data))

  def run do
    if System.get_env("GAOXY_STANDALONE_MODE") == "rollback" do
      rollback()
    else
      {:ok, _apps} = Application.ensure_all_started(:gaoxy_server)
      runtime = Process.whereis(Gaoxy.Server.Runtime)
      assert is_pid(runtime)
      ports = ports()

      emit(%{
        event: "ready",
        ports: ports,
        config_path: System.fetch_env!("GAOXY_CONFIG"),
        elixir: System.version(),
        otp: System.otp_release(),
        erts: to_string(:erlang.system_info(:version))
      })

      loop(runtime, ports)
    end
  end

  defp ports do
    Map.new(Gaoxy.services(Gaoxy.Server.Runtime), fn id ->
      {:ok, {_, port}} = Gaoxy.info(Gaoxy.Server.Runtime, id).local
      {id, port}
    end)
  end

  defp loop(runtime, original) do
    case IO.gets("") do
      :eof ->
        stop(runtime, original)

      line ->
        case JSON.decode!(line) do
          %{"command" => "sample"} ->
            admission =
              Map.new(original, fn {id, _} ->
                {id,
                 Map.take(Gaoxy.status(runtime, id), [
                   :active,
                   :retained_bytes,
                   :cleanup_pending,
                   :cleanup_failed,
                   :queued_items,
                   :queued_bytes
                 ])}
              end)

            emit(%{event: "sample", admission: admission})
            loop(runtime, original)

          %{"command" => command} when command in ["reload", "invalid-reload"] ->
            store = Supervisor.route_store("h3")
            {:ok, before, _} = Generation.snapshot(store)

            key =
              if command == "reload",
                do: "GAOXY_STANDALONE_ROUTES",
                else: "GAOXY_STANDALONE_INVALID"

            result = Gaoxy.Server.reload_routes("h3", System.fetch_env!(key), 2_000)
            {:ok, after_generation, _} = Generation.snapshot(store)
            assert ports() == original

            if command == "reload" do
              assert {:ok, ^after_generation} = result
              assert after_generation != before
            else
              assert {:error, _} = result
              assert before == after_generation
            end

            emit(%{
              event: command,
              result: inspect(result),
              listener_unchanged: true,
              generation_changed: before != after_generation
            })

            loop(runtime, original)

          %{"command" => "stop"} ->
            stop(runtime, original)
        end
    end
  end

  defp stop(runtime, ports) do
    deadline = Gaoxy.Lifecycle.deadline(5_000)

    owners =
      [runtime, Process.whereis(Supervisor), Process.whereis(Gaoxy.Server.RouteStores)] ++
        Enum.map(Map.keys(ports), &GenServer.whereis(Supervisor.route_store(&1)))

    monitors = for owner <- owners, do: {owner, Process.monitor(owner)}
    :ok = Application.stop(:gaoxy_server)

    for {owner, monitor} <- monitors do
      receive do
        {:DOWN, ^monitor, :process, ^owner, _} -> :ok
      after
        Gaoxy.Lifecycle.remaining(deadline) -> raise "standalone owner DOWN missing"
      end
    end

    for {id, port} <- ports do
      if id == "h3" do
        {:ok, socket} = :gen_udp.open(port, [:binary, ip: {127, 0, 0, 1}])
        :ok = :gen_udp.close(socket)
      else
        {:ok, socket} = :gen_tcp.listen(port, [:binary, ip: {127, 0, 0, 1}, reuseaddr: true])
        :ok = :gen_tcp.close(socket)
      end
    end

    assert Gaoxy.Lifecycle.remaining(deadline) > 0

    emit(%{
      event: "stopped",
      owners_down: length(owners),
      ports_rebound: true,
      elapsed_ms: 5_000 - Gaoxy.Lifecycle.remaining(deadline),
      ports: ports
    })
  end

  defp rollback do
    Process.flag(:trap_exit, true)
    path = System.fetch_env!("GAOXY_CONFIG")
    System.delete_env("GAOXY_CONFIG")
    {:ok, _} = Application.ensure_all_started(:gaoxy_server)
    data = path |> File.read!() |> JSON.decode!()
    {:ok, occupied} = :gen_udp.open(0, [:binary, ip: {127, 0, 0, 1}])
    {:ok, {_, occupied_port}} = :inet.sockname(occupied)
    {:ok, candidate} = :gen_udp.open(0, [:binary, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(candidate)
    :ok = :gen_udp.close(candidate)
    [h3 | rest] = data["services"]

    data =
      Map.put(
        data,
        "services",
        [Map.put(h3, "port", port) | rest] ++
          [
            %{
              "id" => "occupied",
              "transport" => "udp",
              "handler" => "datagram_echo",
              "port" => occupied_port
            }
          ]
      )

    {:ok, options} = Config.decode(data)
    assert {:error, _} = result = Supervisor.start_link(options)
    assert inspect(result) =~ "eaddrinuse"
    assert_no_owners()
    {:ok, rebound} = :gen_udp.open(port, [:binary, ip: {127, 0, 0, 1}])
    :ok = :gen_udp.close(rebound)
    assert {:error, :eaddrinuse} = :gen_udp.open(occupied_port, [:binary, ip: {127, 0, 0, 1}])
    :ok = :gen_udp.close(occupied)

    emit(%{
      event: "check",
      name: "standalone_startup_rollback",
      result: "PASS",
      error: inspect(result),
      earlier_h3_port_rebound: true,
      port: port,
      owners_absent: true
    })

    data =
      put_in(data, ["services", Access.at(0), "tls", "certfile"], path <> ".missing-certificate")

    result = with {:ok, options} <- Config.decode(data), do: Supervisor.start_link(options)
    assert {:error, _} = result
    assert_no_owners()
    {:ok, rebound} = :gen_udp.open(port, [:binary, ip: {127, 0, 0, 1}])
    :ok = :gen_udp.close(rebound)

    emit(%{
      event: "check",
      name: "standalone_missing_certificate_rollback",
      result: "PASS",
      error: inspect(result),
      port_rebound: true,
      owners_absent: true
    })

    :ok = Application.stop(:gaoxy_server)
  end

  defp assert_no_owners do
    assert Process.whereis(Supervisor) == nil
    assert Process.whereis(Gaoxy.Server.Runtime) == nil
    assert Process.whereis(Gaoxy.Server.RouteStores) == nil
  end
end

Gaoxy.StandaloneH3Fixture.run()
