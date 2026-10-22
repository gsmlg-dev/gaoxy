defmodule Gaoxy.HTTP.StreamLifetimeConfigTest do
  use ExUnit.Case, async: true
  @moduletag :unit

  defmodule StreamPlug do
    def init(options), do: options

    def call(conn, owner) do
      case conn.request_path do
        "/body" ->
          {:ok, _body, conn} = Plug.Conn.read_body(conn)
          Plug.Conn.send_resp(conn, 200, "body")

        "/upload" ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          conn = conn |> Gaoxy.HTTP.put_stream_timeout(:infinity) |> Plug.Conn.send_chunked(200)
          send(owner, {:uploaded_stream, self(), body})
          loop(conn, owner)

        path ->
          conn =
            case path do
              "/infinite" -> Gaoxy.HTTP.put_stream_timeout(conn, :infinity)
              "/finite" -> Gaoxy.HTTP.put_stream_timeout(conn, :request)
              "/short" -> Gaoxy.HTTP.put_stream_timeout(conn, 150)
              _ -> conn
            end

          conn = Plug.Conn.send_chunked(conn, 200)
          send(owner, {:stream_started, self()})
          loop(conn, owner)
      end
    end

    defp loop(conn, owner) do
      receive do
        {:chunk, data} ->
          case Plug.Conn.chunk(conn, data) do
            {:ok, next} ->
              send(owner, {:chunk_sent, self()})
              loop(next, owner)

            {:error, reason} ->
              send(owner, {:stream_error, self(), reason})
              conn
          end

        :flood ->
          Enum.reduce_while(1..4096, conn, fn _, current ->
            case Plug.Conn.chunk(current, :binary.copy("x", 16_384)) do
              {:ok, next} ->
                {:cont, next}

              {:error, reason} ->
                send(owner, {:stream_error, self(), reason})
                {:halt, current}
            end
          end)

        :finish ->
          conn

        :cancel ->
          {:ok, conn} = Gaoxy.HTTP.abort(conn, :cancelled)
          conn
      after
        20 ->
          case Gaoxy.HTTP.poll_connection(conn, 0) do
            {kind, next} when kind in [:pending, :more] ->
              loop(next, owner)

            {:error, reason, next} ->
              send(owner, {:stream_error, self(), reason})
              next
          end
      end
    end
  end

  test "stream lifetime accepts explicit infinity while I/O deadlines stay finite" do
    for timeout <- [:infinity, :request, 500] do
      assert {:ok, spec} =
               Gaoxy.HTTP.service_spec(
                 plug: {StreamPlug, self()},
                 http_limits: %{stream_timeout: timeout}
               )

      assert spec.handler_options.http_limits.stream_timeout == timeout
    end

    for timeout <- [0, -1, nil, true, 1.5] do
      assert {:error, :invalid_http_limit} =
               Gaoxy.HTTP.service_spec(
                 plug: {StreamPlug, self()},
                 http_limits: %{stream_timeout: timeout}
               )
    end

    for key <- [:header_timeout, :read_timeout, :write_timeout] do
      assert {:error, :invalid_http_limit} =
               Gaoxy.HTTP.service_spec(
                 plug: {StreamPlug, self()},
                 http_limits: %{key => :infinity}
               )
    end
  end

  test "request lifetime explicitly accepts infinity and retains finite defaults and I/O limits" do
    assert {:ok, default} = Gaoxy.HTTP.service_spec(plug: {StreamPlug, self()})
    assert default.handler_options.http_limits.request_timeout == 30_000

    for protocols <- [[:http1], [:http2], [:http2, :http1]] do
      assert {:ok, spec} =
               Gaoxy.HTTP.service_spec(
                 plug: {StreamPlug, self()},
                 protocols: protocols,
                 h2c: if(:http2 in protocols, do: :prior_knowledge, else: :disabled),
                 http_limits: %{request_timeout: :infinity}
               )

      assert spec.handler_options.http_limits.request_timeout == :infinity
      assert spec.handler_options.http_limits.header_timeout == 5_000
      assert spec.handler_options.http_limits.read_timeout == 5_000
      assert spec.handler_options.http_limits.write_timeout == 5_000
    end

    for timeout <- [0, -1, nil, true, 1.5, :request] do
      assert {:error, :invalid_http_limit} =
               Gaoxy.HTTP.service_spec(
                 plug: {StreamPlug, self()},
                 http_limits: %{request_timeout: timeout}
               )
    end
  end

  test "generation endpoints reject unsupported infinite request lifetime before initialization" do
    generation = {Gaoxy.HTTP.Generation, []}

    target =
      {Gaoxy.HTTP.ListenerSet.Target,
       %Gaoxy.HTTP.ListenerSet.PreparedTarget{endpoint: generation}}

    for endpoint <- [generation, target] do
      assert {:error, :unsupported_request_timeout} =
               Gaoxy.HTTP.service_spec(
                 endpoint: endpoint,
                 http_limits: %{request_timeout: :infinity}
               )
    end

    target = %Gaoxy.HTTP.ListenerSet.PreparedTarget{
      endpoint: {Gaoxy.HTTP.PlugEndpoint, {StreamPlug, self()}}
    }

    assert {:ok, _} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Gaoxy.HTTP.ListenerSet.Target, target},
               http_limits: %{request_timeout: :infinity}
             )
  end
end
