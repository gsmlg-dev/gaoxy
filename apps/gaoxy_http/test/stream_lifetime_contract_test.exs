defmodule Gaoxy.HTTP.StreamLifetimeContractTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.{Exchange, HTTP2.Transport}

  test "an infinite response retains a finite owner wait for a body-read operation" do
    parent = self()

    owner =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    exchange = %Exchange{
      deadline: :infinity,
      limits: %{read_timeout: 50},
      transport_state: {owner, 1, make_ref()}
    }

    caller =
      spawn(fn -> send(parent, {:read_result, Transport.operation(exchange, {:read, 1, 40})}) end)

    on_exit(fn ->
      Process.exit(caller, :kill)
      Process.exit(owner, :kill)
    end)

    assert_receive {:read_result, {:error, :timeout}}, 500
  end

  test "route selection validates values and cannot extend pre-response work" do
    exchange = %Exchange{deadline: 123, response: :unset}
    conn = %{Plug.Test.conn("GET", "/") | adapter: {Gaoxy.PlugAdapter, exchange}}
    selected = Gaoxy.HTTP.put_stream_timeout(conn, :infinity)
    {Gaoxy.PlugAdapter, next} = selected.adapter
    assert next.deadline == 123
    assert next.stream_timeout == :infinity

    for invalid <- [0, -1, true, nil, 1.5] do
      assert_raise ArgumentError, fn -> Gaoxy.HTTP.put_stream_timeout(conn, invalid) end
    end

    assert_raise ArgumentError, fn ->
      Gaoxy.HTTP.put_stream_timeout(%{conn | state: :sent}, :infinity)
    end
  end

  test "unsupported HTTP3 stream timeout fails before changing any admission lease" do
    exchange = %Exchange{
      transport: Gaoxy.HTTP.HTTP3.Transport,
      limits: %{stream_timeout: :infinity}
    }

    assert {:error, :unsupported_stream_timeout} = Exchange.begin_stream(exchange)
  end
end
