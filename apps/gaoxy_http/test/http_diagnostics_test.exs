defmodule Gaoxy.HTTP.DiagnosticsTest do
  use ExUnit.Case, async: false

  defmodule FailurePlug do
    def init(options), do: options

    def call(conn, owner) do
      case conn.request_path do
        "/after" ->
          Plug.Conn.send_resp(conn, 201, "ok")
          raise "secret exception message"

        "/prepared" ->
          Plug.Conn.resp(conn, 202, "secret body")
          raise "secret exception message"

        "/throw" ->
          throw({:secret, "credential"})

        "/timeout" ->
          send(owner, {:blocked, self()})

          receive do
            :never -> conn
          end

        "/health" ->
          Plug.Conn.send_resp(conn, 200, "ok")

        _ ->
          raise "secret exception message"
      end
    end
  end

  setup do
    id = make_ref()
    :ok = :telemetry.attach(id, [:gaoxy, :http, :failure], &__MODULE__.observe/4, self())
    on_exit(fn -> :telemetry.detach(id) end)
    :ok
  end

  def observe(_, measurements, metadata, owner),
    do: send(owner, {:failure, measurements, metadata})

  test "malformed HTTP1 headers retain bounded rejection reason and sent status" do
    socket = connect()

    :ok =
      :gen_tcp.send(
        socket,
        "GET /secret?token=credential HTTP/1.1\r\nhost: localhost\r\nbad header\r\n\r\n"
      )

    assert read_all(socket) =~ "400 Bad Request"
    assert_receive {:failure, %{count: 1, duration: duration}, metadata}, 2_000
    assert duration >= 0
    assert metadata.protocol == :http1
    assert metadata.stage == :headers
    assert metadata.reason == :header
    assert metadata.status == 400
    assert metadata.response_committed
    safe(metadata)
    refute_receive {:failure, _, _}, 0
  end

  test "incomplete headers time out without inventing a sent 408" do
    socket = connect(header_timeout: 100, request_timeout: 2_000)
    :ok = :gen_tcp.send(socket, "GET / HTTP/1.1\r\nhost:")
    assert read_all(socket) == ""

    assert_receive {:failure, _,
                    %{
                      stage: :headers,
                      reason: :header_timeout,
                      status: nil,
                      response_committed: false
                    }},
                   2_000

    refute_receive {:failure, _, _}, 0
  end

  for {path, status} <- [{"before", 500}, {"prepared", 500}, {"after", 201}, {"throw", nil}] do
    @path path
    @status status
    test "#{path} endpoint failure reports the actual sent status once" do
      socket = connect()

      :ok =
        :gen_tcp.send(
          socket,
          "GET /#{@path}?password=secret HTTP/1.1\r\nhost: localhost\r\nconnection: close\r\n\r\n"
        )

      wire = read_all(socket)
      if @status, do: assert(wire =~ "HTTP/1.1 #{@status}"), else: assert(wire == "")
      assert_receive {:failure, _, metadata}, 2_000
      assert metadata.stage == :endpoint
      assert metadata.reason == if(@path == "throw", do: :endpoint_throw, else: :plug_exception)
      assert metadata.status == @status
      assert metadata.response_committed == (@status != nil)
      safe(metadata)
      refute_receive {:failure, _, _}, 0
    end
  end

  test "watchdog termination of blocked Plug emits request timeout" do
    socket = connect(header_timeout: 1_000, request_timeout: 200)
    :ok = :gen_tcp.send(socket, "GET /timeout HTTP/1.1\r\nhost: localhost\r\n\r\n")
    assert_receive {:blocked, _}, 2_000
    assert read_all(socket) == ""

    assert_receive {:failure, _,
                    %{
                      stage: :endpoint,
                      reason: :request_timeout,
                      status: nil,
                      response_committed: false
                    }},
                   2_000

    refute_receive {:failure, _, _}, 0
  end

  test "success and orderly peer closure produce no failure diagnostic" do
    socket = connect()

    :ok =
      :gen_tcp.send(
        socket,
        "GET /health HTTP/1.1\r\nhost: localhost\r\nconnection: close\r\n\r\n"
      )

    assert read_all(socket) =~ "200 OK"
    peer = connect()
    :ok = :gen_tcp.close(peer)
    refute_receive {:failure, _, _}, 50
  end

  defp connect(limits \\ []) do
    {:ok, runtime} =
      Gaoxy.HTTP.start_link(
        plug: {FailurePlug, self()},
        port: 0,
        protocols: [:http1],
        http_limits: Map.new(limits)
      )

    on_exit(fn -> if Process.alive?(runtime), do: Gaoxy.stop(runtime, 2_000) end)
    {:ok, {ip, port}} = Gaoxy.info(runtime, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 2_000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    socket
  end

  defp read_all(socket, acc \\ "") do
    case :gen_tcp.recv(socket, 0, 2_000) do
      {:ok, bytes} -> read_all(socket, acc <> bytes)
      {:error, :closed} -> acc
      other -> flunk("unexpected socket result #{inspect(other)}")
    end
  end

  defp safe(metadata) do
    assert is_reference(metadata.request_id)

    assert Map.keys(metadata) |> Enum.sort() ==
             Enum.sort([
               :protocol,
               :stage,
               :reason,
               :status,
               :response_committed,
               :request_id,
               :stream_id
             ])

    refute inspect(metadata) =~ "secret"
    refute inspect(metadata) =~ "credential"
  end
end
