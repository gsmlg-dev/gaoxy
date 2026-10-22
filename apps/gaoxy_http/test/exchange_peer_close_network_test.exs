defmodule Gaoxy.HTTP.ExchangePeerCloseNetworkTest do
  use ExUnit.Case, async: true

  alias Gaoxy.HTTP.HTTP1.Parser

  @wait 2_000

  defmodule HealthPlug do
    def init(owner), do: owner

    def call(conn, owner) do
      send(owner, {:endpoint_called, self(), conn.request_path})
      Plug.Conn.send_resp(conn, 200, "healthy")
    end
  end

  for {name, body} <- [{"headers only", ""}, {"short body", "abc"}] do
    @body body
    test "PUT peer reset after #{name} closes normally before exchange construction" do
      observer = self()
      token = make_ref()

      assert :ok =
               :telemetry.attach(
                 token,
                 [:hell, :connection, :start],
                 &__MODULE__.connection_started/4,
                 {observer, token}
               )

      on_exit(fn -> :telemetry.detach(token) end)

      assert {:ok, server} =
               Gaoxy.HTTP.start_link(
                 plug: {HealthPlug, observer},
                 port: 0,
                 protocols: [:http1],
                 http_limits: %{request_timeout: :infinity}
               )

      on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, @wait) end)
      {:ok, {ip, port}} = Gaoxy.info(server, :http).local

      # An existing keep-alive connection must survive the other owner's close.
      {sibling, _} = connect(ip, port, token)
      :ok = :gen_tcp.send(sibling, get("keep-alive"))
      assert_receive {:endpoint_called, _, "/health"}, @wait
      assert recv_response(sibling, "", Gaoxy.Lifecycle.deadline(@wait)) =~ "200 OK"

      {client, owner} = connect(ip, port, token)
      assert {%Hell.Socket{} = socket, %{phase: :idle}} = :sys.get_state(owner, @wait)
      monitor = Process.monitor(owner)
      barrier = make_ref()

      assert :ok =
               :telemetry.attach_many(
                 barrier,
                 [
                   [:hell, :connection, :async_recv],
                   [:hell, :connection, :stop],
                   [:hell, :connection, :exception]
                 ],
                 &__MODULE__.observe_owner/4,
                 {observer, owner, barrier}
               )

      on_exit(fn ->
        send(owner, {barrier, :release})
        :telemetry.detach(barrier)
      end)

      wire = "PUT /cancel HTTP/1.1\r\nHost: localhost\r\nContent-Length: 32\r\n\r\n" <> @body
      :ok = :gen_tcp.send(client, wire)
      assert_receive {^barrier, :before_exchange, head}, @wait
      assert {:ok, %{method: "PUT", body: {:length, 32}}, observed_body} = Parser.parse_head(head)
      assert String.starts_with?(@body, observed_body)
      refute_receive {:endpoint_called, ^owner, _}, 0

      # async_recv runs synchronously before handle_data. The owner remains
      # fenced until the real socket reports lost peer identity; a late reset
      # that never reaches this constructor window cannot pass this test.
      :ok = :inet.setopts(client, linger: {true, 0})
      :ok = :gen_tcp.close(client)
      reason = await_metadata_error(socket, Gaoxy.Lifecycle.deadline(@wait))
      assert reason in [:closed, :einval, :enotconn]
      send(owner, {barrier, :release})

      assert_receive {^barrier, :stop, metadata}, @wait
      refute Map.has_key?(metadata, :error)
      assert_receive {:DOWN, ^monitor, :process, ^owner, {:shutdown, :local_closed}}, @wait
      refute_receive {^barrier, :exception, _}, 0
      refute_receive {:endpoint_called, ^owner, _}, 0
      await_usage(server, 1, Gaoxy.Lifecycle.deadline(@wait))

      :ok = :gen_tcp.send(sibling, get("close"))
      assert recv_closed(sibling, "", Gaoxy.Lifecycle.deadline(@wait)) =~ "200 OK"
      {followup, _} = connect(ip, port, token)
      :ok = :gen_tcp.send(followup, get("close"))
      assert recv_closed(followup, "", Gaoxy.Lifecycle.deadline(@wait)) =~ "200 OK"
      await_usage(server, 0, Gaoxy.Lifecycle.deadline(@wait))
      assert Gaoxy.info(server, :http).mode == :ready

      IO.puts(
        "PASS peer-close sent_body=#{byte_size(@body)} observed_body=#{byte_size(observed_body)} peername=#{inspect({:error, reason})} normal-close cleanup sibling followup"
      )
    end
  end

  def connection_started(_, _, %{handler: Gaoxy.HTTP.Connection, remote_port: port}, config) do
    {observer, token} = config
    send(observer, {token, :started, port, self()})
  end

  def connection_started(_, _, _, _), do: :ok

  def observe_owner(event, measurements, metadata, {observer, owner, barrier}) do
    if self() == owner do
      case event do
        [:hell, :connection, :async_recv] ->
          # Retain only this small fixture request across arbitrary TCP delivery
          # boundaries, and fence the delivery that completes its headers.
          head = Process.get(barrier, "") <> measurements.data
          Process.put(barrier, head)

          if match?({:ok, _, _}, Parser.parse_head(head)) do
            send(observer, {barrier, :before_exchange, head})

            receive do
              {^barrier, :release} -> :ok
            after
              5_000 -> send(observer, {barrier, :barrier_timeout})
            end
          end

        [:hell, :connection, terminal] ->
          send(observer, {barrier, terminal, metadata})
      end
    end
  end

  defp connect(ip, port, token) do
    assert {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @wait)
    on_exit(fn -> :gen_tcp.close(socket) end)
    {:ok, {_, local_port}} = :inet.sockname(socket)
    assert_receive {^token, :started, ^local_port, owner}, @wait
    {socket, owner}
  end

  defp get(connection),
    do: "GET /health HTTP/1.1\r\nHost: localhost\r\nConnection: #{connection}\r\n\r\n"

  defp recv_response(socket, bytes, deadline) do
    if String.ends_with?(bytes, "\r\n\r\nhealthy") do
      bytes
    else
      assert {:ok, chunk} = :gen_tcp.recv(socket, 0, Gaoxy.Lifecycle.remaining(deadline))
      recv_response(socket, bytes <> chunk, deadline)
    end
  end

  defp recv_closed(socket, bytes, deadline) do
    case :gen_tcp.recv(socket, 0, Gaoxy.Lifecycle.remaining(deadline)) do
      {:ok, chunk} -> recv_closed(socket, bytes <> chunk, deadline)
      {:error, :closed} -> bytes
      other -> flunk("expected complete healthy response and close, got #{inspect(other)}")
    end
  end

  defp await_metadata_error(socket, deadline) do
    case Hell.Socket.peername(socket) do
      {:error, reason} ->
        reason

      {:ok, _} ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0, "peer reset never reached metadata lookup"

        receive do
        after
          1 -> await_metadata_error(socket, deadline)
        end
    end
  end

  defp await_usage(server, active, deadline) do
    case Gaoxy.status(server, :http) do
      %{active: ^active, retained_bytes: 0} ->
        :ok

      _ ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0, "admission ownership was not restored"

        receive do
        after
          1 -> await_usage(server, active, deadline)
        end
    end
  end
end
