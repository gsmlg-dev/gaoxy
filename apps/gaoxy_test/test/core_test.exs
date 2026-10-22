defmodule Gaoxy.Test.CoreTest do
  use ExUnit.Case, async: true
  alias Gaoxy.Test, as: Fixture

  defp request(fixture, method \\ "GET", path \\ "/", body \\ "") do
    uri = URI.parse(Fixture.url(fixture, path))
    {:ok, socket} = :gen_tcp.connect(~c"127.0.0.1", uri.port, [:binary, active: false], 1_000)

    :ok =
      :gen_tcp.send(socket, [
        method,
        " ",
        path,
        " HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\nContent-Length: ",
        Integer.to_string(byte_size(body)),
        "\r\n\r\n",
        body
      ])

    response = receive_all(socket, "")
    :gen_tcp.close(socket)
    response
  end

  defp receive_all(socket, received) do
    case :gen_tcp.recv(socket, 0, 2_000) do
      {:ok, bytes} -> receive_all(socket, received <> bytes)
      {:error, :closed} -> received
    end
  end

  test "real H1 uses actual port, normalized method and query-free route" do
    fixture = Fixture.open()
    assert Fixture.info(fixture).ready

    :ok =
      Fixture.expect_once(fixture, :get, "/hello", fn conn ->
        assert conn.query_string == "q=1"
        Plug.Conn.send_resp(conn, 200, "hello")
      end)

    assert request(fixture, "GET", "/hello?q=1") =~ "hello"
    assert :ok = Fixture.verify!(fixture)
    assert %{status: :ok, admitted: 1, completed: 1} = Fixture.close(fixture)
  end

  test "independent concurrent fixtures retain independent identities and ports" do
    first = Fixture.open()
    second = Fixture.open()
    refute Fixture.url(first) == Fixture.url(second)
    refute Fixture.info(first).fixture_id == Fixture.info(second).fixture_id

    for {fixture, body} <- [{first, "one"}, {second, "two"}] do
      Fixture.expect_once(fixture, :get, "/", &Plug.Conn.send_resp(&1, 200, body))
    end

    one = Task.async(fn -> request(first) end)
    two = Task.async(fn -> request(second) end)
    assert Task.await(one) =~ "one"
    assert Task.await(two) =~ "two"
    assert Fixture.requests(first).cursor == 1
    assert Fixture.requests(second).cursor == 1
  end

  test "atomic exact-once allows one callback under competing network requests" do
    fixture = Fixture.open(mode: :manual)
    owner = self()

    Fixture.expect_once(fixture, :get, "/", fn conn ->
      send(owner, {:entered, self()})

      receive do
        :release -> Plug.Conn.send_resp(conn, 200, "winner")
      after
        2_000 -> flunk("barrier timeout")
      end
    end)

    first = Task.async(fn -> request(fixture) end)
    assert_receive {:entered, executor}, 1_000
    assert request(fixture) =~ "500"
    refute_receive {:entered, _}, 0
    send(executor, :release)
    assert Task.await(first) =~ "winner"

    assert %{status: :error, failures: [%{type: :excessive}], admitted: 1} =
             Fixture.close(fixture)
  end

  test "await uses event-driven new request cursor and bounded timeout" do
    fixture = Fixture.open()
    Fixture.stub(fixture, :get, "/", &Plug.Conn.send_resp(&1, 200, "ok"))
    assert request(fixture) =~ "200"
    assert {:ok, %{id: 1}} = Fixture.await_request(fixture, %{method: :get, path: "/"}, 200)

    waiter =
      Task.async(fn ->
        Fixture.await_request(fixture, %{method: :get, path: "/", after: 1}, 1_000)
      end)

    assert request(fixture) =~ "200"
    assert {:ok, %{id: 2}} = Task.await(waiter)

    assert {:error, :timeout} =
             Fixture.await_request(fixture, %{method: :get, path: "/", after: 2}, 20)
  end

  test "journal eviction and capture bounds preserve lazy complete body reads" do
    fixture = Fixture.open(mode: :manual, journal_limit: 1, capture_body: 4)

    Fixture.expect_once(fixture, :post, "/body", fn conn ->
      assert conn.adapter |> elem(0) == Gaoxy.Test.DispatchPlug.CaptureAdapter
      {:ok, "abcdefgh", conn} = Plug.Conn.read_body(conn)
      Plug.Conn.send_resp(conn, 200, "read")
    end)

    assert request(fixture, "POST", "/body", "abcdefgh") =~ "read"

    assert [%{body: %{data: "abcd", complete: true, truncated: true}}] =
             Fixture.requests(fixture).entries

    assert request(fixture, "GET", "/unexpected") =~ "500"
    assert %{truncated: true, dropped: 1, entries: [%{id: 2}]} = Fixture.requests(fixture)
    assert %{status: :error, failures: [%{type: :unexpected}]} = Fixture.close(fixture)
  end

  test "capture disabled preserves normal adapter and never reads body eagerly" do
    fixture = Fixture.open()

    Fixture.expect_once(fixture, :post, "/", fn conn ->
      refute elem(conn.adapter, 0) == Gaoxy.Test.DispatchPlug.CaptureAdapter
      {:ok, "body", conn} = Plug.Conn.read_body(conn)
      Plug.Conn.send_resp(conn, 200, "ok")
    end)

    assert request(fixture, "POST", "/", "body") =~ "ok"
    refute Map.has_key?(hd(Fixture.requests(fixture).entries), :body)
  end

  test "events are direct observations with bounded journal display and durable failures" do
    fixture = Fixture.open(mode: :manual, journal_limit: 1)

    Fixture.expect_once(fixture, :get, "/", fn conn ->
      %{instance: instance, request_id: id} = conn.private.gaoxy_test

      for number <- 1..110,
          do: Gaoxy.Test.Instance.event(instance, id, %{type: :emitted, number: number})

      Gaoxy.Test.Instance.event(instance, id, %{type: :large, body: String.duplicate("a", 10_000)})

      Gaoxy.Test.Instance.event(instance, id, %{
        type: :session_failure,
        kind: :error,
        reason: RuntimeError.exception("retained"),
        stacktrace: []
      })

      Plug.Conn.send_resp(conn, 200, "ok")
    end)

    assert request(fixture) =~ "ok"
    identity = Fixture.info(fixture).fixture_id
    assert_receive {:gaoxy_test_event, ^identity, 1, %{type: :emitted, number: 1}}
    [entry] = Fixture.requests(fixture).entries
    assert length(entry.events) == 100
    assert entry.events_dropped == 12
    assert entry.events_truncated
    assert Enum.any?(entry.events, &match?(%{type: :large, truncated: true}, &1))

    assert %{failures: [%{type: :callback, reason: %RuntimeError{message: "retained"}}]} =
             Fixture.close(fixture)
  end

  test "invalid callback returns fail verification even with a recorded admission" do
    fixture = Fixture.open(mode: :manual)
    Fixture.expect_once(fixture, :get, "/", fn _conn -> :invalid end)
    assert request(fixture) =~ "500"

    assert %{
             status: :error,
             failures: [%{type: :callback, reason: %Gaoxy.Test.InvalidHandlerError{}}]
           } = Fixture.close(fixture)
  end

  test "public options reject infinity, malformed routes, duplicates and identity forgery" do
    for options <- [
          [timeout: :infinity],
          [retention: 0],
          [journal_limit: -1],
          [capture_body: true]
        ] do
      assert_raise ArgumentError, fn -> Fixture.open(options) end
    end

    fixture = Fixture.open()
    Fixture.stub(fixture, :get, "/", &Plug.Conn.send_resp(&1, 200, "ok"))
    assert_raise ArgumentError, fn -> Fixture.expect_once(fixture, :get, "/", & &1) end
    assert_raise Gaoxy.Test.UnavailableError, fn -> Fixture.info(%{fixture | id: make_ref()}) end
  end
end
