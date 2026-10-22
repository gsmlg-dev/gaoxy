defmodule Gaoxy.HTTP.SupervisedShutdownBudgetConfigTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  @moduletag :capture_log

  defmodule BodyPlug do
    def init(owner), do: owner

    def call(conn, owner) do
      send(owner, {:body_worker, self()})
      read(conn)
    end

    defp read(conn) do
      case Plug.Conn.read_body(conn, length: 16_384) do
        {:more, _, conn} -> read(conn)
        {:ok, _, conn} -> Plug.Conn.send_resp(conn, 200, "complete")
      end
    end
  end

  test "HTTP child spec inherits the validated instance budget and defers invalid startup errors" do
    for limits <- [%{}, %{drain_timeout: 5_500}] do
      options = [id: :budget, plug: {BodyPlug, self()}, limits: limits]
      assert {:ok, service} = Gaoxy.HTTP.service_spec(options)
      expected = Gaoxy.child_spec(services: [service])
      actual = Gaoxy.HTTP.child_spec(options)
      assert Map.get(actual, :shutdown) == expected.shutdown
      assert actual.id == {Gaoxy.HTTP, :budget}
      assert actual.start == {Gaoxy.HTTP, :start_link, [options]}
      assert actual.restart == :transient
    end

    invalid = [plug: {BodyPlug, self()}, limits: %{drain_timeout: -1}]

    assert %{shutdown: 7_000, start: {Gaoxy.HTTP, :start_link, [^invalid]}} =
             Gaoxy.HTTP.child_spec(invalid)

    assert {:error, _} = Gaoxy.HTTP.start_link(invalid)
  end
end
