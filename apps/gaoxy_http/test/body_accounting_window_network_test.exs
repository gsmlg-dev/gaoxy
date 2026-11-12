defmodule Gaoxy.HTTP.BodyAccountingWindowNetworkTest do
  use ExUnit.Case, async: false

  @body_size 5 * 1_024 * 1_024
  @call_limit 150
  @accounting_calls [
    {Gaoxy.Admission, :update_until, 5},
    {Gaoxy.Admission, :repartition_until, 5}
  ]

  defmodule UploadPlug do
    def init(options), do: options

    def call(%{request_path: "/next"} = conn, options) do
      {:ok, "", conn} = Plug.Conn.read_body(conn)
      send(options.owner, :next_request_complete)
      Plug.Conn.send_resp(conn, 200, "ready")
    end

    def call(conn, options) do
      {Gaoxy.PlugAdapter, exchange} = conn.adapter
      send(options.owner, {:reading, self(), exchange.deadline})

      case read(conn, options.read_options, :crypto.hash_init(:sha256), 0, 0) do
        {:ok, conn, digest, size, more} ->
          send(options.owner, {:body_complete, size, digest, more})
          Plug.Conn.send_resp(conn, 200, Base.encode16(digest, case: :lower))

        {:error, reason} ->
          send(options.owner, {:body_error, reason})

          if reason == :timeout do
            {:ok, conn} = Gaoxy.HTTP.abort(conn, :timeout)
            conn
          else
            conn
            |> Plug.Conn.put_resp_header("connection", "close")
            |> Plug.Conn.send_resp(500, inspect(reason))
          end
      end
    end

    defp read(conn, options, hash, size, more) do
      case Plug.Conn.read_body(conn, options) do
        {:more, bytes, conn} ->
          read(conn, options, :crypto.hash_update(hash, bytes), size + byte_size(bytes), more + 1)

        {:ok, bytes, conn} ->
          digest = hash |> :crypto.hash_update(bytes) |> :crypto.hash_final()
          {:ok, conn, digest, size + byte_size(bytes), more}

        {:error, _} = error ->
          error
      end
    end
  end

  setup do
    on_exit(fn ->
      for mfa <- @accounting_calls, do: :erlang.trace_pattern(mfa, false, [:call_count])
    end)

    :ok
  end

  for read_chunk <- [16_384, 1_024] do
    @read_chunk read_chunk
    test "5 MiB content-length accounting stays bounded at #{@read_chunk}-byte native reads" do
      body = payload(@body_size)
      {server, socket} = start_server(http_limits: %{max_read_chunk: @read_chunk})

      counts =
        accounting_counts(fn ->
          :ok = :gen_tcp.send(socket, content_length(body))
          assert_complete(socket, body)
        end)

      assert_window_bound(counts, "content_length_read_chunk_#{@read_chunk}")
      assert_clean_stop(server, socket)
    end
  end

  test "5 MiB chunked input and 1024-byte Plug reads use the same accounting bound" do
    body = payload(@body_size)
    {server, socket} = start_server([], read_length: 1_024)

    chunks =
      for <<part::binary-size(4_096) <- body>>,
        do: ["1000\r\n", part, "\r\n"]

    counts =
      accounting_counts(fn ->
        :ok =
          :gen_tcp.send(socket, [
            "POST /upload HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\n\r\n",
            chunks,
            "0\r\nx-upload: complete\r\n\r\n"
          ])

        assert_complete(socket, body)
      end)

    assert_window_bound(counts, "chunked_plug_read_length_1024")
    assert_clean_stop(server, socket)
  end

  test "partial Plug reads release accounting before a pipelined keep-alive request" do
    body = payload(3 * 262_144 + 37)
    {server, socket} = start_server([], length: 262_144, read_length: 1_024)

    :ok =
      :gen_tcp.send(socket, [
        content_length(body),
        "GET /next HTTP/1.1\r\nHost: localhost\r\n\r\n"
      ])

    expected = :crypto.hash(:sha256, body)
    assert {200, digest, rest} = response(socket)
    assert digest == Base.encode16(expected, case: :lower)
    assert_receive {:body_complete, 786_469, ^expected, 3}, 1_000
    assert {200, "ready", ""} = response(socket, rest)
    assert_receive :next_request_complete, 1_000
    assert_clean_stop(server, socket)
  end

  test "an insufficient explicit byte budget still rejects body acquisition exactly" do
    limit = 524_288
    {server, socket} = start_server(limits: %{max_bytes: limit})
    :ok = :gen_tcp.send(socket, content_length(payload(1_048_576)))
    assert {500, ":byte_limit", ""} = response(socket)
    assert_receive {:body_error, :byte_limit}, 1_000
    assert %{retained_high_water: high} = Gaoxy.status(server, :http)
    assert high > 0 and high <= limit
    assert_clean_stop(server, socket)
  end

  test "the HTTP body ceiling still rejects an oversized content-length before Plug" do
    {server, socket} = start_server(http_limits: %{max_body_bytes: 65_536})
    :ok = :gen_tcp.send(socket, content_length(payload(65_537)))
    assert {413, "", ""} = response(socket)
    refute_receive {:reading, _, _}, 0
    refute_receive {:body_complete, _, _, _}, 0
    assert_clean_stop(server, socket)
  end

  test "an incomplete body remains bounded by its finite request deadline" do
    {server, socket} =
      start_server(http_limits: %{request_timeout: 250, read_timeout: 5_000})

    :ok =
      :gen_tcp.send(
        socket,
        "POST /upload HTTP/1.1\r\nHost: localhost\r\nContent-Length: 1024\r\n\r\npartial"
      )

    assert_receive {:reading, reader, deadline}, 1_000
    monitor = Process.monitor(reader)
    assert is_integer(deadline)
    assert_receive {:DOWN, ^monitor, :process, ^reader, _}, 2_000
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1_000)
    assert_clean_stop(server, socket)
  end

  defp start_server(options, read_options \\ []) do
    http_limits =
      Map.merge(%{request_timeout: 30_000}, Keyword.get(options, :http_limits, %{}))

    options =
      Keyword.merge(
        [
          plug: {UploadPlug, %{owner: self(), read_options: read_options}},
          protocols: [:http1],
          limits: %{max_bytes: 67_108_864}
        ],
        options
      )
      |> Keyword.put(:http_limits, http_limits)

    assert {:ok, server} = Gaoxy.HTTP.start_link(options)
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, 2_000) end)
    assert %{local: {:ok, {_, port}}} = Gaoxy.info(server, :http)

    assert {:ok, socket} =
             :gen_tcp.connect(
               ~c"127.0.0.1",
               port,
               [:binary, active: false, send_timeout: 30_000, send_timeout_close: true],
               1_000
             )

    on_exit(fn -> :gen_tcp.close(socket) end)
    {server, socket}
  end

  defp payload(size) do
    block = :binary.list_to_bin(Enum.to_list(0..255))
    binary_part(:binary.copy(block, div(size + 255, 256)), 0, size)
  end

  defp content_length(body),
    do: [
      "POST /upload HTTP/1.1\r\nHost: localhost\r\nContent-Length: ",
      Integer.to_string(byte_size(body)),
      "\r\n\r\n",
      body
    ]

  defp assert_complete(socket, body) do
    expected = :crypto.hash(:sha256, body)
    size = byte_size(body)
    assert {200, digest, ""} = response(socket)
    assert digest == Base.encode16(expected, case: :lower)
    assert_receive {:body_complete, ^size, ^expected, 0}, 1_000
  end

  defp accounting_counts(operation) do
    assert Code.ensure_loaded?(Gaoxy.Admission)

    for mfa <- @accounting_calls do
      assert :erlang.trace_pattern(mfa, true, [:call_count]) == 1
    end

    try do
      operation.()

      Map.new(@accounting_calls, fn {_, function, _} = mfa ->
        assert {:call_count, count} = :erlang.trace_info(mfa, :call_count)
        {function, count}
      end)
    after
      for mfa <- @accounting_calls, do: :erlang.trace_pattern(mfa, false, [:call_count])
    end
  end

  defp assert_window_bound(counts, label) do
    total = counts.update_until + counts.repartition_until
    IO.puts("BODY_ACCOUNTING_WINDOW #{label} #{inspect(counts)} total=#{total}")
    assert total > 0

    assert total <= @call_limit,
           "expected at most #{@call_limit} admission calls, got #{inspect(counts)}"
  end

  defp response(socket, buffer \\ "", deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(30_000)

    case :binary.split(buffer, "\r\n\r\n") do
      [head, body] ->
        [status_line | fields] = String.split(head, "\r\n")
        [_, status | _] = String.split(status_line, " ")

        length =
          Enum.find_value(fields, 0, fn field ->
            case String.split(field, ":", parts: 2) do
              [name, value] ->
                if String.downcase(name) == "content-length",
                  do: String.to_integer(String.trim(value))
            end
          end)

        if byte_size(body) >= length do
          <<body::binary-size(^length), rest::binary>> = body
          {String.to_integer(status), body, rest}
        else
          receive_response(socket, buffer, deadline)
        end

      [_] ->
        receive_response(socket, buffer, deadline)
    end
  end

  defp receive_response(socket, buffer, deadline) do
    remaining = Gaoxy.Lifecycle.remaining(deadline)
    assert remaining > 0, "response deadline expired"
    assert {:ok, bytes} = :gen_tcp.recv(socket, 0, remaining)
    response(socket, buffer <> bytes, deadline)
  end

  defp assert_clean_stop(server, socket) do
    :ok = :gen_tcp.close(socket)
    await_clean(server, Gaoxy.Lifecycle.deadline(2_000))
    assert :ok = Gaoxy.stop(server, 2_000)
  end

  defp await_clean(server, deadline) do
    case Gaoxy.status(server, :http) do
      %{active: 0, retained_bytes: 0, cleanup_pending: 0, cleanup_failed: nil} ->
        :ok

      status ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)
        Process.sleep(5)
        await_clean(server, deadline)
    end
  end
end
