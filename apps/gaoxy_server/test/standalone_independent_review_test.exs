defmodule Gaoxy.Server.StandaloneIndependentReviewTest do
  use ExUnit.Case, async: false
  import Bitwise
  alias Gaoxy.HTTP.Generation
  alias Gaoxy.Server.{Config, RouteConfig}
  alias HTTP.HTTP2.HPACK
  @moduletag :tmp_dir
  @timeout 2_000

  test "a nonregular route file cannot hold reload beyond its deadline", %{tmp_dir: dir} do
    {:ok, routes} = RouteConfig.decode(routes("old"))
    store = start_supervised!({Generation, routes: routes})
    assert {:ok, original, router} = Generation.snapshot(store)
    tasks = start_supervised!(Task.Supervisor)
    path = Path.join(dir, "routes.fifo")
    assert {"", 0} = System.cmd("mkfifo", [path])
    {:ok, keeper} = :file.open(String.to_charlist(path), [:read, :write, :binary, :raw])

    try do
      :ok = :file.write(keeper, JSON.encode!(routes("new")))
      task = Task.Supervisor.async_nolink(tasks, fn -> RouteConfig.reload(store, path, 50) end)

      try do
        assert {:ok, {:error, _}} = Task.yield(task, 250)
      after
        Task.shutdown(task, :brutal_kill)
      end
    after
      :file.close(keeper)
    end

    assert {:ok, ^original, ^router} = Generation.snapshot(store)
  end

  for {kind, limits, fields} <- [
        {:count, %{"max_headers" => 5}, for(n <- 1..4, do: ["x-#{n}", "v"])},
        {:bytes, %{"max_header_bytes" => 256}, [["x", String.duplicate("v", 144)]]}
      ] do
    test "static #{kind} overflow rejects standalone configuration before startup" do
      limits = unquote(Macro.escape(limits))
      fields = unquote(Macro.escape(fields))
      refute Process.whereis(Gaoxy.Server.RouteStores)
      refute Process.whereis(Gaoxy.Server.Runtime)
      assert {:error, _} = Config.decode(config(limits, routes("unsafe", fields)))
      refute Process.whereis(Gaoxy.Server.RouteStores)
      refute Process.whereis(Gaoxy.Server.Runtime)
    end

    test "static #{kind} overflow cannot replace a usable live generation", %{tmp_dir: dir} do
      limits = unquote(Macro.escape(limits))
      fields = unquote(Macro.escape(fields))
      assert {:ok, options} = Config.decode(config(limits, routes("old")))
      start_supervised!({Gaoxy.Server.Supervisor, options})
      store = Gaoxy.Server.Supervisor.route_store("review-web")
      assert {:ok, original, router} = Generation.snapshot(store)
      before = Gaoxy.info(Gaoxy.Server.Runtime, "review-web").local
      assert %{status: "200", body: "old"} = response(before)
      path = Path.join(dir, "invalid.json")
      File.write!(path, JSON.encode!(routes("unsafe", fields)))

      assert {:error, _} = Gaoxy.Server.reload_routes("review-web", path, 1_000)
      assert {:ok, ^original, ^router} = Generation.snapshot(store)
      assert Gaoxy.info(Gaoxy.Server.Runtime, "review-web").local == before
      assert %{status: "200", body: "old"} = response(before)
    end
  end

  defp config(limits, routes) do
    %{
      "version" => 1,
      "services" => [
        %{
          "id" => "review-web",
          "transport" => "tcp",
          "handler" => "http",
          "protocols" => ["http2"],
          "h2c" => "prior_knowledge",
          "http_limits" => limits,
          "routes" => routes,
          "limits" => %{"max_bytes" => 536_870_912, "max_active" => 128}
        }
      ]
    }
  end

  defp routes(body, headers \\ []) do
    %{
      "version" => 1,
      "routes" => [%{"target" => %{"type" => "static", "body" => body, "headers" => headers}}]
    }
  end

  defp response({:ok, {ip, port}}) do
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)

    fields = [
      {":method", "GET"},
      {":scheme", "http"},
      {":authority", "localhost"},
      {":path", "/"}
    ]

    {_, block} =
      HPACK.encode_headers(HPACK.new_encoder(), fields, indexing: :never, huffman: :never)

    try do
      :ok =
        :gen_tcp.send(socket, [
          "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n",
          frame(4, 0, 0, ""),
          frame(1, 5, 1, block)
        ])

      receive_response(
        socket,
        %{status: nil, body: ""},
        "",
        HPACK.new_decoder(max_dynamic_size: 4_096),
        Gaoxy.Lifecycle.deadline(@timeout)
      )
    after
      :gen_tcp.close(socket)
    end
  end

  defp receive_response(socket, result, block, decoder, deadline) do
    remaining = Gaoxy.Lifecycle.remaining(deadline)
    assert remaining > 0
    {:ok, <<size::24, type, flags, _::1, id::31>>} = :gen_tcp.recv(socket, 9, remaining)

    bytes =
      if size == 0 do
        ""
      else
        {:ok, bytes} = :gen_tcp.recv(socket, size, max(1, Gaoxy.Lifecycle.remaining(deadline)))
        bytes
      end

    case {type, id} do
      {4, 0} ->
        if (flags &&& 1) == 0, do: :gen_tcp.send(socket, frame(4, 1, 0, ""))
        receive_response(socket, result, block, decoder, deadline)

      {type, 1} when type in [1, 9] ->
        block = block <> bytes

        if (flags &&& 4) != 0 do
          {:ok, decoder, fields} = HPACK.decode(decoder, block)
          {":status", status} = List.keyfind(fields, ":status", 0)
          result = %{result | status: status}

          if (flags &&& 1) != 0,
            do: result,
            else: receive_response(socket, result, "", decoder, deadline)
        else
          receive_response(socket, result, block, decoder, deadline)
        end

      {0, 1} ->
        result = %{result | body: result.body <> bytes}

        if (flags &&& 1) != 0,
          do: result,
          else: receive_response(socket, result, block, decoder, deadline)

      other ->
        flunk("unexpected HTTP/2 frame #{inspect(other)} flags=#{flags} bytes=#{inspect(bytes)}")
    end
  end

  defp frame(type, flags, id, bytes) do
    bytes = IO.iodata_to_binary(bytes)
    <<byte_size(bytes)::24, type, flags, 0::1, id::31, bytes::binary>>
  end
end
