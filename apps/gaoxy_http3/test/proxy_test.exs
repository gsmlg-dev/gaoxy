defmodule Gaoxy.HTTP.HTTP3.ProxyTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.Request
  @timeout 3_000

  defmodule Transport do
    defdelegate send_resp(exchange, status, headers, body), to: Gaoxy.HTTP.FramedResponse
    defdelegate send_chunked(exchange, status, headers), to: Gaoxy.HTTP.FramedResponse
    defdelegate chunk(exchange, bytes), to: Gaoxy.HTTP.FramedResponse
    defdelegate finish(exchange, trailers), to: Gaoxy.HTTP.FramedResponse
    def body_complete?(exchange), do: exchange.body.phase == :done

    def operation(exchange, operation) do
      send(
        exchange.transport_state.observer,
        {:response_operation, self(), operation, exchange.deadline}
      )

      :ok
    end

    def read_body_step(exchange, _, _) do
      send(exchange.transport_state.observer, {:body_read, self()})
      [bytes | rest] = exchange.transport_state.pieces
      done = rest == []

      body = %{
        exchange.body
        | phase: if(done, do: :done, else: :data),
          total: exchange.body.total + byte_size(bytes)
      }

      state = %{exchange.transport_state | pieces: rest}
      {if(done, do: :ok, else: :more), bytes, %{exchange | body: body, transport_state: state}}
    end

    def poll_connection(%{transport_state: %{hold_ready: true}} = exchange, wait) do
      receive do
        {:gaoxy_proxy_http, session, {:ready, _, _, _} = ready} ->
          send(exchange.transport_state.observer, {:ready_held, self()})

          receive do
            :allow_ready -> :ok
          after
            Gaoxy.Lifecycle.remaining(exchange.deadline) -> raise "missing ready release barrier"
          end

          send(self(), {:gaoxy_proxy_http, session, ready})

          {:pending,
           %{exchange | transport_state: %{exchange.transport_state | hold_ready: false}}}
      after
        wait -> {:pending, exchange}
      end
    end

    def poll_connection(exchange, wait) do
      if exchange.transport_state.reorder do
        receive do
          {:gaoxy_proxy_http, session, {:ready, _, _, _} = ready} ->
            send(exchange.transport_state.observer, {:ready_held, self()})

            receive do
              :allow_reorder -> :ok
            after
              Gaoxy.Lifecycle.remaining(exchange.deadline) ->
                raise "missing ready reorder barrier"
            end

            head =
              receive do
                {:gaoxy_proxy_http, ^session, {:headers, 413, _} = event} -> event
              after
                Gaoxy.Lifecycle.remaining(exchange.deadline) -> raise "missing early origin head"
              end

            ending =
              receive do
                {:gaoxy_proxy_http, ^session, {:end, []} = event} -> event
              after
                Gaoxy.Lifecycle.remaining(exchange.deadline) -> raise "missing early origin end"
              end

            send(self(), {:gaoxy_proxy_http, session, head})
            send(self(), {:gaoxy_proxy_http, session, ready})
            send(self(), {:gaoxy_proxy_http, session, ending})

            {:pending,
             %{exchange | transport_state: %{exchange.transport_state | reorder: false}}}
        after
          wait -> {:pending, exchange}
        end
      else
        receive do
        after
          wait -> {:pending, exchange}
        end
      end
    end
  end

  defmodule Endpoint do
    def init(options) do
      with {:ok, proxy} <- Gaoxy.Proxy.HTTP.init(options.proxy),
           do: {:ok, Map.put(options, :proxy, proxy)}
    end

    def call(original, options) do
      trailers = [{"x-trace", "first"}, {"x-trace", "second"}]

      fields =
        if options.trailers,
          do: [{"trailer", "x-trace"}, {"content-length", "#{options.size}"}],
          else: if(options.undeclared, do: [{"content-length", "0"}], else: [])

      exchange = %{
        original
        | request: %Request{
            method: "POST",
            version: options.version,
            target_form: :origin,
            target: "/wire?",
            path: "/wire",
            query_string: "",
            host: "downstream.test",
            headers: fields,
            body:
              if(options.trailers or options.undeclared, do: {:length, options.size}, else: :none)
          },
          body: %{
            phase: if(options.complete, do: :done, else: :data),
            total: 0,
            trailers: if(options.trailers or options.undeclared, do: trailers, else: []),
            trailer_bytes: 0
          },
          transport: Transport,
          transport_state: %{
            observer: options.observer,
            pieces: ["a", "bc"],
            reorder: options.reorder,
            hold_ready: options.hold_ready
          },
          secure: true
      }

      :erlang.trace(self(), true, [:send, {:tracer, options.observer}])
      send(options.observer, {:proxy_started, self(), exchange.deadline})
      result = Gaoxy.Proxy.HTTP.call(exchange, options.proxy)
      send(options.observer, {:proxy_finished, self(), result})
      :erlang.trace(self(), false, [:send])
      Gaoxy.HTTP.HTTP1.Response.send_resp(original, 200, [], "finished")
    end
  end

  for version <- [:"HTTP/2", :"HTTP/3"], size <- [0, 3] do
    test "#{version} fixed #{size} trailers use real H1 chunk framing and one finish" do
      {url, origin, origin_monitor} =
        origin(fn socket, observer ->
          headers = head(socket)
          send(observer, {:origin_head, self(), headers})
          {body, trailers} = chunks(socket)
          send(observer, {:origin_body, self(), body, trailers})
          assert {:error, :timeout} = :gen_tcp.recv(socket, 0, 30)
          :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
          assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
        end)

      server =
        server(url, version: unquote(version), size: unquote(size), complete: unquote(size) == 0)

      start_request(server)
      assert_receive {:proxy_started, worker, deadline}, @timeout
      assert_receive {:origin_head, ^origin, headers}, @timeout
      assert headers =~ "POST /wire? HTTP/1.1\r\n"
      assert String.downcase(headers) =~ "transfer-encoding: chunked\r\n"
      refute String.downcase(headers) =~ "content-length:"
      expected = if unquote(size) == 0, do: "", else: "abc"
      trailers = [{"x-trace", "first"}, {"x-trace", "second"}]
      assert_receive {:origin_body, ^origin, ^expected, ^trailers}, @timeout
      assert_receive {:trace, ^worker, :send, {:finish, fields}, upload}, @timeout
      assert HTTP.Headers.to_list(fields) == trailers
      assert is_pid(upload)
      assert_receive {:proxy_finished, ^worker, {:ok, result}}, @timeout
      assert result.deadline == deadline
      refute_received {:trace, ^worker, :send, {:finish, _}, ^upload}
      refute_received {:trace, ^worker, :send, :finish, ^upload}
      if unquote(size) == 0, do: refute_received({:body_read, ^worker})
      assert_origin(origin, origin_monitor)
      assert_cleanup(server)
    end
  end

  test "a completed nil upload does not finish a stream or read the body" do
    {url, origin, origin_monitor} =
      origin(fn socket, observer ->
        send(observer, {:origin_head, self(), head(socket)})
        :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      end)

    server = server(url, trailers: false, complete: true)
    start_request(server)
    assert_receive {:proxy_started, worker, deadline}, @timeout
    assert_receive {:origin_head, ^origin, _}, @timeout
    assert_receive {:proxy_finished, ^worker, {:ok, result}}, @timeout
    assert result.deadline == deadline
    refute_received {:body_read, ^worker}
    refute_received {:trace, ^worker, :send, :finish, _}
    refute_received {:trace, ^worker, :send, {:finish, _}, _}
    assert_origin(origin, origin_monitor)
    assert_cleanup(server)
  end

  test "a completed nil upload rejects undeclared trailers without reading or finishing" do
    {url, origin, origin_monitor} =
      origin(fn socket, observer ->
        send(observer, {:origin_head, self(), head(socket)})
        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      end)

    server = server(url, trailers: false, undeclared: true, hold_ready: true, complete: true)
    start_request(server)
    assert_receive {:proxy_started, worker, deadline}, @timeout
    assert_receive {:ready_held, ^worker}, @timeout
    assert_receive {:origin_head, ^origin, _}, @timeout
    send(worker, :allow_ready)
    assert_receive {:response_operation, ^worker, {:head, 502, _, _}, ^deadline}, @timeout
    assert_receive {:proxy_finished, ^worker, {:ok, result}}, @timeout
    assert result.deadline == deadline
    refute_received {:body_read, ^worker}
    refute_received {:trace, ^worker, :send, :finish, _}
    refute_received {:trace, ^worker, :send, {:finish, _}, _}
    assert_origin(origin, origin_monitor)
    assert_cleanup(server)
  end

  test "ready after an early final head never reopens a completed upload" do
    {url, origin, origin_monitor} =
      origin(fn socket, observer ->
        send(observer, {:origin_head, self(), head(socket)})

        receive do
          :respond -> :ok
        after
          @timeout -> raise "missing early response barrier"
        end

        :ok = :gen_tcp.send(socket, "HTTP/1.1 413 Content Too Large\r\nContent-Length: 0\r\n\r\n")
        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      end)

    server = server(url, reorder: true, complete: true)
    start_request(server)
    assert_receive {:proxy_started, worker, deadline}, @timeout
    assert_receive {:origin_head, ^origin, _}, @timeout
    assert_receive {:ready_held, ^worker}, @timeout
    send(origin, :respond)
    send(worker, :allow_reorder)
    assert_receive {:response_operation, ^worker, {:head, 413, _, _}, ^deadline}, @timeout
    assert_receive {:proxy_finished, ^worker, {:ok, result}}, @timeout
    assert result.deadline == deadline
    refute_received {:body_read, ^worker}
    refute_received {:trace, ^worker, :send, :finish, _}
    refute_received {:trace, ^worker, :send, {:finish, _}, _}
    assert_origin(origin, origin_monitor)
    assert_cleanup(server)
  end

  defp server(url, options) do
    config =
      Map.merge(
        %{
          proxy: %{upstream: url, max_lifetime: 5_000},
          observer: self(),
          version: :"HTTP/3",
          size: 0,
          complete: true,
          reorder: false,
          trailers: true,
          undeclared: false,
          hold_ready: false
        },
        Map.new(options)
      )

    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint: {Endpoint, config},
        http_limits: %{request_timeout: 2_000},
        limits: %{max_bytes: 33_554_432}
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, @timeout) end)
    server
  end

  defp start_request(server) do
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(
        socket,
        "GET / HTTP/1.1\r\nHost: downstream.test\r\nConnection: close\r\n\r\n"
      )
  end

  defp assert_cleanup(server), do: assert_cleanup(server, Gaoxy.Lifecycle.deadline(@timeout))

  defp assert_cleanup(server, deadline) do
    case Gaoxy.status(server, :http) do
      %{active: 0, retained_bytes: 0, cleanup_pending: 0} ->
        :ok

      status ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)

        receive do
        after
          2 -> assert_cleanup(server, deadline)
        end
    end
  end

  defp origin(fun) do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)
    observer = self()

    {pid, monitor} =
      spawn_monitor(fn ->
        try do
          {:ok, socket} = :gen_tcp.accept(listener, @timeout)

          try do
            fun.(socket, observer)
          after
            :gen_tcp.close(socket)
          end

          send(observer, {:origin_done, self()})
        rescue
          error ->
            send(
              observer,
              {:origin_error, self(), Exception.format(:error, error, __STACKTRACE__)}
            )
        after
          :gen_tcp.close(listener)
        end
      end)

    on_exit(fn ->
      :gen_tcp.close(listener)
      if Process.alive?(pid), do: Process.exit(pid, :kill)
    end)

    {"http://127.0.0.1:#{port}", pid, monitor}
  end

  defp assert_origin(pid, monitor) do
    receive do
      {:origin_done, ^pid} -> :ok
      {:origin_error, ^pid, error} -> flunk(error)
    after
      @timeout -> flunk("independent origin completion missing")
    end

    assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, @timeout
  end

  defp head(socket, bytes \\ "") do
    next = bytes <> line(socket)
    if String.ends_with?(next, "\r\n\r\n"), do: next, else: head(socket, next)
  end

  defp line(socket, bytes \\ "") do
    {:ok, byte} = :gen_tcp.recv(socket, 1, @timeout)
    next = bytes <> byte
    if String.ends_with?(next, "\r\n"), do: next, else: line(socket, next)
  end

  defp chunks(socket, body \\ "") do
    size = socket |> line() |> String.trim() |> String.to_integer(16)

    if size == 0 do
      {body, trailers(socket)}
    else
      {:ok, bytes} = :gen_tcp.recv(socket, size, @timeout)
      assert {:ok, "\r\n"} = :gen_tcp.recv(socket, 2, @timeout)
      chunks(socket, body <> bytes)
    end
  end

  defp trailers(socket, fields \\ []) do
    case line(socket) do
      "\r\n" ->
        Enum.reverse(fields)

      field ->
        [name, value] = String.split(String.trim_trailing(field, "\r\n"), ":", parts: 2)
        trailers(socket, [{String.downcase(name), String.trim(value)} | fields])
    end
  end
end
