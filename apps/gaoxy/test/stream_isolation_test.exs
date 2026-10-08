defmodule Gaoxy.StreamIsolationTest do
  use ExUnit.Case, async: true
  @moduletag :loopback

  defmodule Actions do
    @behaviour Gaoxy.StreamHandler
    def init(_, %{action: :init_error}), do: {:error, :fixture_init_error}
    def init(_, options), do: {:ok, options}
    def handle_data(_, %{action: :crash}), do: raise("fixture callback crash")
    def handle_data(_, %{action: :close} = state), do: {:close, state}

    def handle_data(_, %{action: :state} = state),
      do: {:continue, Map.put(state, :retained, :binary.copy("x", 2_048))}

    def handle_data(_, %{action: :output} = state),
      do: {:send, :binary.copy("x", 2_048), state}

    def handle_data(bytes, state), do: {:send, bytes, state}
    def terminate(reason, %{owner: owner}), do: send(owner, {:terminated, reason})
  end

  test "init errors, callback crashes, close and independent state/output limits isolate connections" do
    actions = [:init_error, :crash, :close, :state, :output, :echo]

    services =
      for action <- actions do
        %{
          id: action,
          transport: :tcp,
          handler: Actions,
          handler_options: %{owner: self(), action: action},
          limits: %{max_state: 1_024, max_output: 1_024}
        }
      end

    runtime = start_supervised!({Gaoxy, services: services})
    on_exit(fn -> if Process.alive?(runtime), do: Gaoxy.stop(runtime, 0) end)
    handles = Map.new(actions, &{&1, Gaoxy.handle(runtime, &1)})

    for action <- actions -- [:echo] do
      {ip, port} = endpoint(runtime, action)
      {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false])
      # Initialization can close before input is sent; the public wire result
      # must still be a closed connection and a running independent listener.
      if action != :init_error, do: assert(:ok = :gen_tcp.send(client, "trigger"))
      assert {:error, :closed} = :gen_tcp.recv(client, 0, 2_000)
      :gen_tcp.close(client)
      assert Gaoxy.handle(runtime, action) == handles[action]
      {echo_ip, echo_port} = endpoint(runtime, :echo)
      {:ok, echo} = :gen_tcp.connect(echo_ip, echo_port, [:binary, active: false])
      :ok = :gen_tcp.send(echo, "still-running")
      assert {:ok, "still-running"} = :gen_tcp.recv(echo, 0, 2_000)
      :gen_tcp.close(echo)
    end

    assert_receive {:terminated, :state_limit}, 2_000
    assert_receive {:terminated, :output_limit}, 2_000
    assert_receive {:terminated, :closed}, 2_000
  end

  defp endpoint(runtime, id) do
    %{local: {:ok, address}} = Gaoxy.info(runtime, id)
    address
  end
end
