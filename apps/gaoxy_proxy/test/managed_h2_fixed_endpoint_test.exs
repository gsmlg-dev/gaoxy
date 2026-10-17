defmodule Gaoxy.Proxy.ManagedH2FixedFixture do
  @moduledoc false
  import ExUnit.Assertions
  alias Gaoxy.HTTP.{Resources, HTTP2.Frame}
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports
  @timeout 5_000

  # This collector owns only the independent peer's public stdin/stdout port.
  # It never reads native Fetch processes or manufactures completion receipts.
  def peer(protocol, options \\ []) do
    caller = self()
    script = Path.expand("support/managed_h2_fixed_peer.py", __DIR__)

    args =
      [script, "--staged-start", "--protocol", if(protocol == :http2, do: "tls", else: "h2c")] ++
        options

    pid =
      spawn(fn ->
        monitor = Process.monitor(caller)

        port =
          Port.open(
            {:spawn_executable, ~c"/tmp/gaoxy-m3-h2-soak-venv/bin/python"},
            [:binary, :exit_status, {:line, 2_097_152}, {:args, args}]
          )

        try do
          peer_loop(port, caller, monitor, "")
        catch
          kind, reason -> peer_failed(port, kind, reason, __STACKTRACE__)
        end
      end)

    ExUnit.Callbacks.on_exit(fn ->
      if Process.alive?(pid) do
        monitor = Process.monitor(pid)
        send(pid, {:command, %{"op" => "stop"}})
        assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, @timeout
      end
    end)

    # TLS preparation retains its twenty-second budget plus bounded cleanup;
    # the listener-ready handshake still has the original five-second deadline.
    event(pid, "prepared", 25_000)
    send(pid, {:command, %{"op" => "start"}})
    ready = event(pid, "ready")
    Process.put({__MODULE__, :observed_requests, pid}, 0)
    {pid, ready}
  end

  defp peer_loop(port, caller, monitor, carry) do
    receive do
      {^port, {:data, {:noeol, bytes}}} ->
        peer_loop(port, caller, monitor, carry <> bytes)

      {^port, {:data, {:eol, bytes}}} ->
        value = JSON.decode!(carry <> bytes)
        send(caller, {:fixed_h2_peer, self(), value})
        peer_loop(port, caller, monitor, "")

      {^port, {:exit_status, status}} ->
        send(caller, {:fixed_h2_peer_exit, self(), status})

      {:command, value} ->
        true = Port.command(port, [JSON.encode!(value), "\n"])
        peer_loop(port, caller, monitor, carry)

      {:DOWN, ^monitor, :process, ^caller, _reason} ->
        true = Port.command(port, [JSON.encode!(%{"op" => "stop"}), "\n"])
        peer_stopping(port, System.monotonic_time(:millisecond) + @timeout)
    after
      120_000 ->
        Port.close(port)
        exit(:peer_collector_deadline)
    end
  end

  defp peer_failed(port, kind, reason, stacktrace) do
    stop =
      try do
        if Port.info(port) != nil do
          true = Port.command(port, [JSON.encode!(%{"op" => "stop"}), "\n"])
        end

        :ok
      catch
        failure_kind, failure -> {:error, {failure_kind, failure}}
      end

    # A failed stop write must not bypass observation of the owned port exit.
    join =
      try do
        peer_stopping(port, System.monotonic_time(:millisecond) + @timeout)
      catch
        failure_kind, failure -> {:error, {failure_kind, failure}}
      end

    case {stop, join} do
      {:ok, :ok} ->
        :erlang.raise(kind, reason, stacktrace)

      cleanup ->
        exit({:peer_collector_failed, {kind, reason, stacktrace}, {:cleanup_failed, cleanup}})
    end
  end

  defp peer_stopping(port, expires) do
    remaining = max(0, expires - System.monotonic_time(:millisecond))

    receive do
      {^port, {:data, _bytes}} -> peer_stopping(port, expires)
      {^port, {:exit_status, _status}} -> :ok
    after
      remaining ->
        if Port.info(port) != nil, do: Port.close(port)
        exit(:peer_collector_stop_deadline)
    end
  end

  def command(peer, request, op, extra \\ %{}) do
    send(
      peer,
      {:command,
       Map.merge(
         %{"op" => op, "connection" => request["connection"], "stream" => request["stream"]},
         extra
       )}
    )

    event(peer, "command")
  end

  def event(peer, name), do: event(peer, name, @timeout)

  defp event(peer, name, timeout) do
    monitor = Process.monitor(peer)

    try do
      receive do
        {:fixed_h2_peer, ^peer, %{"event" => ^name} = value} ->
          if name == "request" do
            key = {__MODULE__, :observed_requests, peer}
            Process.put(key, Process.get(key, 0) + 1)
          end

          value

        {:fixed_h2_peer, ^peer, %{"event" => "failure"} = value} ->
          flunk(inspect(value))

        {:fixed_h2_peer_exit, ^peer, status} ->
          flunk("peer exited #{status} before #{name}")

        {:DOWN, ^monitor, :process, ^peer, reason} ->
          flunk("peer collector exited #{inspect(reason)} before #{name}")
      after
        timeout -> flunk("independent peer did not report #{name}")
      end
    after
      Process.demonitor(monitor, [:flush])
    end
  end

  def no_event(peer, name) do
    refute_receive {:fixed_h2_peer, ^peer, %{"event" => ^name}}, 0
  end

  def upload_through(peer, request, expected, previous \\ 0) do
    upload_through(peer, request["connection"], request["stream"], expected, previous, deadline())
  end

  defp upload_through(peer, connection, stream, expected, previous, expires) do
    remaining = expires - System.monotonic_time(:millisecond)
    assert remaining > 0, "independent peer did not complete the expected upload"

    receive do
      {:fixed_h2_peer, ^peer,
       %{"event" => "upload", "connection" => ^connection, "stream" => ^stream} = value} ->
        chunk = value["chunk_bytes"]
        total = value["total_bytes"]
        assert is_integer(chunk) and chunk > 0
        assert total == previous + chunk
        assert total <= byte_size(expected)

        assert value["sha256"] ==
                 Base.encode16(:crypto.hash(:sha256, binary_part(expected, 0, total)),
                   case: :lower
                 )

        if total == byte_size(expected),
          do: value,
          else: upload_through(peer, connection, stream, expected, total, expires)

      {:fixed_h2_peer, ^peer,
       %{"event" => "upload_end", "connection" => ^connection, "stream" => ^stream}} ->
        flunk("independent peer ended before the expected upload bytes")

      {:fixed_h2_peer, ^peer, %{"event" => "failure"} = value} ->
        flunk(inspect(value))

      {:fixed_h2_peer_exit, ^peer, status} ->
        flunk("peer exited #{status} before the expected upload bytes")
    after
      remaining -> flunk("independent peer did not complete the expected upload")
    end
  end

  def fixture(protocol, downstream \\ :http1, peer_options \\ [], overrides \\ %{}) do
    {peer, ready} = peer(protocol, peer_options)
    scheme = if protocol == :http2, do: "https", else: "http"
    origin = scheme <> "://" <> Map.get(overrides, :hostname, "localhost") <> ":#{ready["port"]}"

    trust =
      if protocol == :http2, do: certificates(Map.get(overrides, :ca, ready["ca"])), else: nil

    source = %{protocol: protocol, origin: origin, connect_address: {127, 0, 0, 1}, trust: trust}
    caller = self()

    embedding =
      spawn(fn ->
        {:ok, instance} = Gaoxy.start_link()
        Process.unlink(instance)

        {:ok, owner} =
          Transports.start_link(
            instance: instance,
            limits: %{
              max_resources: 2,
              max_pins: 256,
              max_request_tokens: 64,
              max_owned_payload_bytes: 4_194_304
            }
          )

        Process.unlink(owner)
        send(caller, {:fixed_h2_embedding, self(), instance, owner})

        receive do
          {:stop, reply} ->
            result = Gaoxy.stop(instance, @timeout)
            send(reply, {:fixed_h2_embedding_stopped, self(), result})
        after
          120_000 -> exit(:embedding_deadline)
        end
      end)

    assert_receive {:fixed_h2_embedding, ^embedding, instance, owner}, @timeout

    ExUnit.Callbacks.on_exit(fn ->
      if Process.alive?(embedding) do
        monitor = Process.monitor(embedding)
        send(embedding, {:stop, self()})
        assert_receive {:fixed_h2_embedding_stopped, ^embedding, _}, 2 * @timeout
        assert_receive {:DOWN, ^monitor, :process, ^embedding, :normal}, @timeout
      end
    end)

    assert {:ok, handle, preparation} = Transports.prepare(owner, source, self(), deadline())
    assert {:ok, baseline} = Resources.pin_many([handle], embedding, :baseline, deadline())
    assert :ok = Resources.release(preparation)

    endpoint =
      Map.merge(
        %{upstream: origin, upstream_protocol: protocol, transport: handle},
        Map.get(overrides, :endpoint, %{})
      )

    service_options = [
      id: :http,
      endpoint: {Map.get(overrides, :endpoint_module, Gaoxy.Proxy.HTTP), endpoint},
      limits: %{max_bytes: 536_870_912, max_active: 64},
      http_limits:
        Map.merge(
          %{
            request_timeout: 10_000,
            write_timeout: 2_000,
            max_headers: 512,
            max_header_bytes: 131_072,
            max_trailers: 256,
            max_trailer_bytes: 131_072
          },
          Map.get(overrides, :http_limits, %{})
        )
    ]

    service_options =
      if downstream == :http2,
        do: service_options ++ [protocols: [:http2], h2c: :prior_knowledge],
        else: service_options

    assert {:ok, spec} = Gaoxy.HTTP.service_spec(service_options)
    assert {:ok, _} = Gaoxy.add(instance, spec)

    %{
      instance: instance,
      owner: owner,
      handle: handle,
      baseline: baseline,
      embedding: embedding,
      peer: peer,
      ready: ready,
      origin: origin,
      protocol: protocol,
      downstream: downstream
    }
  end

  def certificates(path) do
    for {:Certificate, der, :not_encrypted} <- :public_key.pem_decode(File.read!(path)), do: der
  end

  def connect(f) do
    {:ok, {ip, port}} = Gaoxy.info(f.instance, :http).local
    assert {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    ExUnit.Callbacks.on_exit(fn -> :gen_tcp.close(socket) end)

    if f.downstream == :http2,
      do:
        :ok =
          :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", Frame.encode(4, 0, 0, "")])

    socket
  end

  def send_request(f, socket, method, target, fields \\ [], ended \\ true, id \\ 1) do
    if f.downstream == :http2 do
      {block, _} =
        HPAX.encode(
          :never_store,
          [
            {":method", method},
            {":scheme", "http"},
            {":authority", "downstream.test"},
            {":path", target}
          ] ++ fields,
          HPAX.new(4_096)
        )

      :ok = :gen_tcp.send(socket, Frame.encode(1, if(ended, do: 5, else: 4), id, block))
    else
      :ok =
        :gen_tcp.send(socket, [
          method,
          " ",
          target,
          " HTTP/1.1\r\nHost: downstream.test\r\n",
          Enum.map(fields, fn {n, v} -> [n, ": ", v, "\r\n"] end),
          "\r\n"
        ])
    end
  end

  def send_body(f, socket, bytes, ended, id \\ 1) do
    if f.downstream == :http2,
      do: :gen_tcp.send(socket, Frame.encode(0, if(ended, do: 1, else: 0), id, bytes)),
      else: :gen_tcp.send(socket, bytes)
  end

  def response(f, socket, method \\ "GET", id \\ 1, progress \\ nil) do
    if f.downstream == :http2,
      do:
        h2_response(
          socket,
          id,
          %{status: nil, headers: [], body: "", trailers: [], inform: []},
          "",
          HPAX.new(4_096),
          progress
        ),
      else: h1_response(socket, method, [], progress)
  end

  defp observed_body(nil, _body, _ended), do: :ok

  defp observed_body(progress, body, ended),
    do: progress.(%{body: body, ended: ended})

  def request(f, method, target, fields \\ []) do
    socket = connect(f)
    :ok = send_request(f, socket, method, target, fields)
    result = response(f, socket, method)
    :ok = :gen_tcp.close(socket)
    clean(f)
    result
  end

  def h1_head(socket), do: until(socket, "\r\n\r\n")

  defp until(socket, delimiter, acc \\ "") do
    if String.ends_with?(acc, delimiter),
      do: acc,
      else:
        (
          assert {:ok, byte} = :gen_tcp.recv(socket, 1, @timeout)
          until(socket, delimiter, acc <> byte)
        )
  end

  defp h1_response(socket, method, inform, progress) do
    [line | lines] = h1_head(socket) |> String.trim_trailing("\r\n\r\n") |> String.split("\r\n")
    [_, code, _] = String.split(line, " ", parts: 3)
    status = String.to_integer(code)

    fields =
      Enum.map(lines, fn l ->
        [n, v] = String.split(l, ":", parts: 2)
        {String.downcase(n), String.trim_leading(v)}
      end)

    if status < 200 do
      h1_response(socket, method, inform ++ [{status, fields}], progress)
    else
      {body, trailers} =
        cond do
          method == "HEAD" or status in [204, 205, 304] ->
            {"", []}

          List.keyfind(fields, "transfer-encoding", 0) == {"transfer-encoding", "chunked"} ->
            h1_chunks(socket, "", progress)

          length_field = List.keyfind(fields, "content-length", 0) ->
            {_, value} = length_field
            count = String.to_integer(value)

            if count == 0,
              do: {"", []},
              else:
                (
                  assert {:ok, bytes} = :gen_tcp.recv(socket, count, @timeout)
                  {bytes, []}
                )

          true ->
            {until_closed(socket), []}
        end

      %{status: status, headers: fields, body: body, trailers: trailers, inform: inform}
    end
  end

  defp h1_chunks(socket, acc, progress) do
    size = until(socket, "\r\n") |> String.trim_trailing("\r\n") |> String.to_integer(16)

    if size == 0 do
      {acc, h1_trailers(socket, [])}
    else
      assert {:ok, <<bytes::binary-size(size), "\r\n">>} =
               :gen_tcp.recv(socket, size + 2, @timeout)

      next = acc <> bytes
      observed_body(progress, next, false)
      h1_chunks(socket, next, progress)
    end
  end

  defp h1_trailers(socket, acc) do
    case until(socket, "\r\n") do
      "\r\n" ->
        Enum.reverse(acc)

      line ->
        [n, v] = String.trim_trailing(line, "\r\n") |> String.split(":", parts: 2)
        h1_trailers(socket, [{String.downcase(n), String.trim_leading(v)} | acc])
    end
  end

  def until_closed(socket, acc \\ "") do
    case :gen_tcp.recv(socket, 0, @timeout) do
      {:ok, bytes} -> until_closed(socket, acc <> bytes)
      {:error, :closed} -> acc
      other -> flunk("downstream did not close: #{inspect(other)}")
    end
  end

  def frame(socket) do
    assert {:ok, <<size::24, type, flags, _::1, id::31>>} = :gen_tcp.recv(socket, 9, @timeout)

    payload =
      if size == 0,
        do: "",
        else:
          (
            assert {:ok, bytes} = :gen_tcp.recv(socket, size, @timeout)
            bytes
          )

    {type, flags, id, payload}
  end

  defp h2_response(socket, id, result, block, decoder, progress) do
    {type, flags, stream, payload} = frame(socket)

    cond do
      type == 4 and flags == 0 ->
        :ok = :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
        h2_response(socket, id, result, block, decoder, progress)

      type in [1, 9] and stream == id ->
        block = block <> payload

        if Bitwise.band(flags, 4) == 0 do
          h2_response(socket, id, result, block, decoder, progress)
        else
          assert {:ok, fields, decoder} = HPAX.decode(block, decoder)

          result =
            case List.keyfind(fields, ":status", 0) do
              {_, value} ->
                status = String.to_integer(value)
                fields = List.keydelete(fields, ":status", 0)

                if status < 200,
                  do: %{result | inform: result.inform ++ [{status, fields}]},
                  else: %{result | status: status, headers: fields}

              nil ->
                %{result | trailers: fields}
            end

          if Bitwise.band(flags, 1) == 1,
            do: result,
            else: h2_response(socket, id, result, "", decoder, progress)
        end

      type == 0 and stream == id ->
        if byte_size(payload) > 0,
          do:
            :ok =
              :gen_tcp.send(socket, [
                Frame.encode(8, 0, 0, <<0::1, byte_size(payload)::31>>),
                Frame.encode(8, 0, id, <<0::1, byte_size(payload)::31>>)
              ])

        result = %{result | body: result.body <> payload}

        if byte_size(payload) > 0,
          do: observed_body(progress, result.body, Bitwise.band(flags, 1) == 1)

        if Bitwise.band(flags, 1) == 1,
          do: result,
          else: h2_response(socket, id, result, block, decoder, progress)

      type in [3, 7] ->
        flunk("unexpected downstream control #{inspect({type, stream, payload})}")

      true ->
        h2_response(socket, id, result, block, decoder, progress)
    end
  end

  def hold(f, target \\ "/hold") do
    socket = connect(f)
    :ok = send_request(f, socket, "GET", target)
    seen = event(f.peer, "request")

    eventually(fn ->
      Enum.any?(:sys.get_state(f.owner).tokens, fn {_, hold} ->
        match?(%HTTP.RequestCompletion{}, hold.completion) and
          :sys.get_state(hold.guardian).submitted_url == f.origin <> target
      end)
    end)

    held =
      :sys.get_state(f.owner).tokens
      |> Map.values()
      |> Enum.find(fn hold ->
        :sys.get_state(hold.guardian).submitted_url == f.origin <> target
      end)

    {socket, seen, held.guardian, held.completion}
  end

  def clean(f) do
    eventually(fn ->
      match?(%{active: 0, cleanup_pending: 0, retained_bytes: 0}, Gaoxy.status(f.instance, :http)) and
        match?({:ok, %{request_tokens: 0, helpers: 0, pins: 1}}, Transports.status(f.owner))
    end)

    assert %{cleanup_failed: nil} = Gaoxy.status(f.instance, :http)
    assert {:ok, %{resources: 1, reserved_connections: 2}} = Transports.status(f.owner)
  end

  def close(f) do
    close(f, Process.get({__MODULE__, :observed_requests, f.peer}, 0))
  end

  def close_aborted(f, expected_requests) do
    close(f, expected_requests)
  end

  def physical_termination(peer) do
    value =
      receive do
        {:fixed_h2_peer, ^peer, %{"event" => signal} = value}
        when signal in ["eof", "connection_reset"] ->
          value

        {:fixed_h2_peer, ^peer, %{"event" => "failure"} = value} ->
          flunk(inspect(value))

        {:fixed_h2_peer_exit, ^peer, status} ->
          flunk("peer exited #{status} before physical termination")
      after
        @timeout -> flunk("independent peer did not report physical termination")
      end

    IO.puts(
      JSON.encode!(%{
        event: "fixed_h2_physical_termination",
        signal: value["event"],
        connection: value["connection"]
      })
    )

    value
  end

  defp close(f, expected_requests) do
    clean(f)
    custodians = :sys.get_state(f.owner).records |> Map.values() |> Enum.map(& &1.custodian)
    joins = Enum.map([f.instance, f.owner, f.embedding | custodians], &{&1, Process.monitor(&1)})
    send(f.embedding, {:stop, self()})
    assert_receive {:fixed_h2_embedding_stopped, _, :ok}, 2 * @timeout

    for {pid, ref} <- joins do
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, @timeout
    end

    physical_termination(f.peer)

    peer_monitor = Process.monitor(f.peer)
    send(f.peer, {:command, %{"op" => "stop"}})
    assert %{"forced" => 0, "live" => 0, "failed" => false} = joined = event(f.peer, "joined")
    assert joined["requests"] == expected_requests
    assert_receive {:fixed_h2_peer_exit, _, 0}, @timeout
    assert_receive {:DOWN, ^peer_monitor, :process, _, :normal}, @timeout
  end

  def eventually(predicate, expires \\ nil) do
    expires = expires || deadline()

    if predicate.(),
      do: :ok,
      else:
        (
          assert System.monotonic_time(:millisecond) < expires, "finite state barrier expired"

          receive do
          after
            1 -> :ok
          end

          eventually(predicate, expires)
        )
  end

  def deadline, do: System.monotonic_time(:millisecond) + @timeout
end

defmodule Gaoxy.Proxy.ManagedH2FixedEndpointTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH2FixedFixture, as: F
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports
  @moduletag :capture_log

  for protocol <- [:http2, :h2c], {pad, status} <- [{65_458, 200}, {65_459, 502}] do
    @wire_protocol protocol
    @wire_pad pad
    @wire_status status
    test "http1 -> #{protocol} complete H1 wire #{pad + 78} bytes returns #{status} before committing any excess head" do
      f = F.fixture(@wire_protocol, :http1, ["--manual"])
      socket = F.connect(f)
      :ok = F.send_request(f, socket, "GET", "/hold/wire-head", [{"connection", "close"}])
      seen = F.event(f.peer, "request")

      F.eventually(fn ->
        match?(
          [%{completion: %HTTP.RequestCompletion{}}],
          Map.values(:sys.get_state(f.owner).tokens)
        )
      end)

      [held] = Map.values(:sys.get_state(f.owner).tokens)
      completion = held.completion
      guardian = held.guardian
      monitor = Process.monitor(guardian)
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)

      fields = [
        ["content-length", "0"],
        ["x-pad", :binary.copy("a", @wire_pad)],
        ["x", "b"],
        ["y", "c"]
      ]

      logical =
        Enum.reduce(fields, 0, fn [name, value], acc ->
          acc + byte_size(name) + byte_size(value)
        end)

      assert logical == @wire_pad + 24
      assert logical + 4 * length(fields) + 2 == @wire_pad + 42

      complete_head =
        IO.iodata_to_binary([
          "HTTP/1.1 200 OK\r\nconnection: close\r\n",
          Enum.map(fields, fn [name, value] -> [name, ": ", value, "\r\n"] end),
          "\r\n"
        ])

      assert byte_size(complete_head) == @wire_pad + 78
      F.command(f.peer, seen, "respond", %{"fields" => fields})
      wire = F.until_closed(socket)

      if @wire_status == 200 do
        assert byte_size(wire) == 65_536
        assert wire == complete_head
      else
        # The only committed head is the bounded empty upstream failure. An
        # oversized 200 prefix or second response cannot satisfy this equality.
        assert wire ==
                 "HTTP/1.1 502 Bad Gateway\r\nconnection: close\r\ncontent-length: 0\r\n\r\n"
      end

      assert :ok = HTTP.RequestCompletion.await(completion, 5_000)
      assert :ok = HTTP.RequestCompletion.await(completion, 0)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 5_000
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      F.close(f)
    end
  end

  for protocol <- [:http2, :h2c],
      {failure, status, phrase, limits, malformed} <- [
        {:malformed_chunk, 400, "Bad Request", %{}, "Z\r\n"},
        {:body_limit, 413, "Request Entity Too Large", %{max_body_bytes: 4},
         "5\r\nabcde\r\n0\r\n\r\n"},
        {:trailer_count, 431, "Request Header Fields Too Large", %{max_trailers: 1},
         "0\r\nX-Check: first\r\nX-Check: second\r\n\r\n"},
        {:trailer_bytes, 431, "Request Header Fields Too Large", %{max_trailer_bytes: 8},
         "0\r\nX-Check: x\r\n\r\n"}
      ] do
    @local_protocol protocol
    @local_failure failure
    @local_status status
    @local_phrase phrase
    @local_limits limits
    @local_malformed malformed
    @tag :local_request_status
    test "http1 -> #{protocol} native #{failure} preserves #{status} with upstream final head withheld" do
      f = F.fixture(@local_protocol, :http1, ["--manual"], %{http_limits: @local_limits})
      socket = F.connect(f)
      target = "/hold/local-#{@local_failure}"

      :ok =
        F.send_request(
          f,
          socket,
          "POST",
          target,
          [{"transfer-encoding", "chunked"}, {"trailer", "x-check"}],
          false
        )

      seen = F.event(f.peer, "request")
      assert seen["target"] == target
      assert seen["connection"] == 1

      assert Enum.filter(seen["headers"], fn [name, _] -> String.starts_with?(name, ":") end) ==
               [
                 [":method", "POST"],
                 [":scheme", if(@local_protocol == :http2, do: "https", else: "http")],
                 [":authority", "localhost:#{f.ready["port"]}"],
                 [":path", target]
               ]

      refute Enum.any?(seen["headers"], fn [name, _] ->
               name in ["trailer", "transfer-encoding"]
             end)

      F.eventually(fn ->
        match?(
          [%{completion: %HTTP.RequestCompletion{}}],
          Map.values(:sys.get_state(f.owner).tokens)
        )
      end)

      [held] = Map.values(:sys.get_state(f.owner).tokens)
      guardian = held.guardian
      completion = held.completion
      state = :sys.get_state(guardian)
      assert state.client.completion(state.original_request) == completion
      assert state.submitted_url == f.origin <> target
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
      assert {:ok, %{request_tokens: 1, pins: 3, helpers: 0}} = Transports.status(f.owner)
      assert %{cleanup_pending: 1, retained_bytes: retained} = Gaoxy.status(f.instance, :http)
      assert retained >= 9_444_956
      monitor = Process.monitor(guardian)

      # The real peer's manual mode withholds every final response. These bytes
      # exercise the native parser and public service limits, not a fake error.
      :ok = :gen_tcp.send(socket, @local_malformed)

      assert F.until_closed(socket) ==
               "HTTP/1.1 #{@local_status} #{@local_phrase}\r\nconnection: close\r\ncontent-length: 0\r\n\r\n"

      assert :ok = HTTP.RequestCompletion.await(completion, 5_000)
      assert :ok = HTTP.RequestCompletion.await(completion, 0)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 5_000
      F.no_event(f.peer, "upload")
      F.no_event(f.peer, "upload_end")
      F.no_event(f.peer, "upload_trailers")
      F.no_event(f.peer, "request")
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      F.close(f)
    end
  end

  for downstream <- [:http1, :http2], protocol <- [:http2, :h2c] do
    @downstream downstream
    @protocol protocol
    test "#{downstream} -> #{protocol} exact escaped targets duplicate fields raw gzip manual redirect and sequential reuse" do
      f = F.fixture(@protocol, @downstream)

      for {target, expected} <- [{"/a%2Fb?q=%2F", "/a%2Fb?q=%2F"}, {"/empty?", "/empty?"}] do
        assert %{status: 200, body: ^expected} =
                 F.request(f, "GET", target, [
                   {"x-trace", "first"},
                   {"x-trace", "second"},
                   {"x-forwarded-for", "spoofed"}
                 ])

        seen = F.event(f.peer, "request")
        assert seen["target"] == target
        assert seen["connection"] == 1

        assert Enum.filter(seen["headers"], &(hd(&1) == "x-trace")) == [
                 ["x-trace", "first"],
                 ["x-trace", "second"]
               ]

        assert [":authority", "localhost:#{f.ready["port"]}"] in seen["headers"]
        refute Enum.any?(seen["headers"], &(List.last(&1) == "spoofed"))
      end

      if @protocol == :http2,
        do: assert(%{"alpn" => "h2", "sni" => "localhost"} = F.event(f.peer, "tls"))

      assert %{status: 200, headers: fields, body: compressed} = F.request(f, "GET", "/gzip")
      assert :zlib.gunzip(compressed) == "raw-compression"
      assert {"content-encoding", "gzip"} in fields
      assert {"content-length", Integer.to_string(byte_size(compressed))} in fields
      assert F.event(f.peer, "request")["connection"] == 1
      assert %{status: 302, headers: fields, body: "redirect"} = F.request(f, "GET", "/redirect")
      assert {"location", "http://unfollowed.invalid/never"} in fields
      assert F.event(f.peer, "request")["connection"] == 1
      F.no_event(f.peer, "request")
      F.close(f)
    end

    test "#{downstream} -> #{protocol} streamed bytes response trailers and bodyless framing" do
      f = F.fixture(@protocol, @downstream)
      bytes = "managed-h2-stream:" <> String.duplicate("s", 65_536)
      assert %{status: 200, body: ^bytes} = F.request(f, "GET", "/stream")
      F.event(f.peer, "request")

      assert %{
               status: 200,
               body: "trailers",
               trailers: [{"x-check", "first"}, {"x-check", "second"}],
               headers: fields
             } = F.request(f, "GET", "/trailers")

      assert Enum.filter(fields, &(elem(&1, 0) == "set-cookie")) == [
               {"set-cookie", "one=1"},
               {"set-cookie", "two=2"}
             ]

      F.event(f.peer, "request")

      for code <- [204, 205, 304] do
        assert %{status: ^code, body: ""} = F.request(f, "GET", "/#{code}")
        F.event(f.peer, "request")
      end

      assert %{status: 200, body: "", headers: fields} = F.request(f, "HEAD", "/head")
      assert {"content-length", "5"} in fields
      F.event(f.peer, "request")
      F.close(f)
    end

    test "#{downstream} -> #{protocol} original binding precedes producer bytes and actual PID preserves raw Content-Length" do
      f = F.fixture(@protocol, @downstream)
      socket = F.connect(f)

      :ok =
        F.send_request(
          f,
          socket,
          "POST",
          "/echo?raw=%2F",
          [{"content-length", "6"}, {"x-trace", "first"}],
          false
        )

      :ok = F.send_body(f, socket, "abc", false)
      seen = F.event(f.peer, "request")
      assert ["content-length", "6"] in seen["headers"]
      assert %{"total_bytes" => 3} = F.upload_through(f.peer, seen, "abc")
      F.no_event(f.peer, "upload_end")
      [held] = :sys.get_state(f.owner).tokens |> Map.values()
      state = :sys.get_state(held.guardian)
      assert %HTTP.RequestCompletion{} = held.completion
      assert held.completion == state.client.completion(state.original_request)
      assert state.managed_path == true
      assert state.managed_transport == nil
      assert state.request_options == nil
      assert state.selector == nil
      assert state.awaiting_transport == nil
      assert state.submitted_url == f.origin <> "/echo?raw=%2F"
      assert :binary.referenced_byte_size(state.submitted_url) == byte_size(state.submitted_url)
      assert Enum.sort(Map.keys(state.request)) == [:completion, :promise, :resolved, :stream]
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(held.completion, 0)
      :ok = F.send_body(f, socket, "def", true)
      assert %{"total_bytes" => 6} = F.upload_through(f.peer, seen, "abcdef", 3)
      connection = seen["connection"]
      stream = seen["stream"]

      assert %{"connection" => ^connection, "stream" => ^stream, "total_bytes" => 6} =
               F.event(f.peer, "upload_end")

      assert %{status: 200, body: "abcdef"} = F.response(f, socket)
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      assert :ok = HTTP.RequestCompletion.await(held.completion, 0)
      F.close(f)
    end

    test "#{downstream} -> #{protocol} early final response finishes an incomplete upload without replay" do
      f = F.fixture(@protocol, @downstream)
      socket = F.connect(f)
      :ok = F.send_request(f, socket, "POST", "/early", [{"content-length", "1000000"}], false)
      assert %{status: 413, body: "early-final"} = F.response(f, socket)
      assert %{"target" => "/early"} = F.event(f.peer, "request")
      F.no_event(f.peer, "upload")
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      assert %{status: 200, body: "/healthy"} = F.request(f, "GET", "/healthy")
      assert %{"target" => "/healthy"} = F.event(f.peer, "request")
      F.no_event(f.peer, "request")
      F.close(f)
    end

    test "#{downstream} -> #{protocol} simultaneous requests multiplex one connection and reset preserves healthy sibling" do
      f = F.fixture(@protocol, @downstream, ["--manual"])
      {first, one, guardian, completion} = F.hold(f, "/hold/one")
      second = F.connect(f)
      :ok = F.send_request(f, second, "GET", "/hold/two")
      two = F.event(f.peer, "request")
      assert one["connection"] == two["connection"]
      refute one["stream"] == two["stream"]
      F.command(f.peer, one, "reset")
      assert %{status: 502} = F.response(f, first)
      monitor = Process.monitor(guardian)
      assert :ok = HTTP.RequestCompletion.await(completion, 5_000)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, reason}, 5_000
      assert reason in [:normal, :noproc]

      F.command(f.peer, two, "respond", %{
        "body64" => Base.encode64("healthy"),
        "fields" => [["content-length", "7"]]
      })

      assert %{status: 200, body: "healthy"} = F.response(f, second)
      :ok = :gen_tcp.close(first)
      :ok = :gen_tcp.close(second)
      F.clean(f)
      F.close(f)
    end
  end

  for downstream <- [:http1, :http2], protocol <- [:http2, :h2c] do
    @trailer_downstream downstream
    @trailer_protocol protocol
    test "#{downstream} -> #{protocol} safe duplicate request trailers reach the peer in order" do
      f = F.fixture(@trailer_protocol, @trailer_downstream)
      socket = F.connect(f)

      fields =
        [{"trailer", "x-check"}] ++
          if(@trailer_downstream == :http1, do: [{"transfer-encoding", "chunked"}], else: [])

      :ok = F.send_request(f, socket, "POST", "/echo", fields, false)

      if @trailer_downstream == :http1 do
        :ok = :gen_tcp.send(socket, "4\r\nwire\r\n0\r\nX-Check: first\r\nX-Check: second\r\n\r\n")
      else
        :ok = F.send_body(f, socket, "wire", false)

        {block, _} =
          HPAX.encode(:never_store, [{"x-check", "first"}, {"x-check", "second"}], HPAX.new(4096))

        :ok = :gen_tcp.send(socket, Gaoxy.HTTP.HTTP2.Frame.encode(1, 5, 1, block))
      end

      assert %{"target" => "/echo"} = F.event(f.peer, "request")

      assert %{"fields" => [["x-check", "first"], ["x-check", "second"]]} =
               F.event(f.peer, "upload_trailers")

      assert %{"total_bytes" => 4} = F.event(f.peer, "upload_end")
      assert %{status: 200, body: "wire"} = F.response(f, socket)
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      F.close(f)
    end
  end

  test "C2 R32 P0 refuses the33rd simultaneous request without hidden pending Fetch or replay" do
    f = F.fixture(:h2c, :http1, ["--manual"])
    held = for index <- 1..32, do: F.hold(f, "/hold/#{index}")
    assert {:ok, %{request_tokens: 32}} = Transports.status(f.owner)
    assert %{cleanup_pending: 32, retained_bytes: bytes} = Gaoxy.status(f.instance, :http)
    assert bytes >= 302_238_592
    socket = F.connect(f)
    :ok = F.send_request(f, socket, "GET", "/refused33")
    assert %{status: 503} = F.response(f, socket)
    :ok = :gen_tcp.close(socket)
    F.no_event(f.peer, "request")
    assert {:ok, %{request_tokens: 32}} = Transports.status(f.owner)
    assert Enum.all?(held, fn {_, seen, _, _} -> seen["connection"] in [1, 2] end)

    assert held
           |> Enum.map(fn {_, seen, _, _} -> {seen["connection"], seen["stream"]} end)
           |> Enum.uniq()
           |> length() == 32

    for {socket, seen, _, completion} <- held do
      F.command(f.peer, seen, "respond", %{"fields" => [["content-length", "0"]]})
      assert %{status: 200, body: ""} = F.response(f, socket)
      :ok = :gen_tcp.close(socket)
      assert :ok = HTTP.RequestCompletion.await(completion, 5_000)
    end

    F.clean(f)
    F.close(f)
  end

  test "fixed managed H2 initialization is pure and protocol/scheme mismatches dedicated H2 and managed H3 reject" do
    alias Gaoxy.Proxy.HTTP, as: ProxyHTTP
    handle = %{provider: Transports, owner: self(), owner_epoch: make_ref(), resource: make_ref()}

    for {protocol, origin} <- [{:http2, "https://localhost"}, {:h2c, "http://localhost"}] do
      assert {:ok, config} =
               ProxyHTTP.init(%{upstream: origin, upstream_protocol: protocol, transport: handle})

      assert config.client == Gaoxy.Proxy.ManagedH2Client
      assert config.cacertfile == nil
      assert config.connect_address == nil
      assert {:ok, ^config} = ProxyHTTP.init(config)
      assert [^handle] = ProxyHTTP.resources(config)
      assert {:message_queue_len, 0} = Process.info(self(), :message_queue_len)

      for change <- [
            %{cacertfile: "/tmp/trust.pem"},
            %{connect_address: {127, 0, 0, 1}},
            %{max_chunk_bytes: 65_537},
            %{opening_timeout: 86_400_001},
            %{idle_timeout: :infinity},
            %{extra: true}
          ] do
        assert {:error, :invalid_http_proxy_options} =
                 ProxyHTTP.init(
                   Map.merge(
                     %{upstream: origin, upstream_protocol: protocol, transport: handle},
                     change
                   )
                 )
      end
    end

    for options <- [
          %{upstream: "http://localhost", upstream_protocol: :http2, transport: handle},
          %{upstream: "https://localhost", upstream_protocol: :h2c, transport: handle},
          %{upstream: "https://localhost", upstream_protocol: :http2},
          %{upstream: "http://localhost", upstream_protocol: :h2c},
          %{upstream: "https://localhost", upstream_protocol: :http3, transport: handle}
        ] do
      assert {:error, :invalid_http_proxy_options} = ProxyHTTP.init(options)
    end
  end
end
