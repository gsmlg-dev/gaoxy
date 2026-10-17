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
    script = Path.expand("managed_h2_fixed_peer.py", __DIR__)

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
