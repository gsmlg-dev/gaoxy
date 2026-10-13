defmodule Gaoxy.Proxy.HTTP3GuardianTest do
  use ExUnit.Case, async: true
  alias Gaoxy.{Admission, Lifecycle, Service}
  alias Gaoxy.HTTP.{Exchange, Response}
  alias Gaoxy.Proxy.{HTTP, HTTP3SessionClient, HTTPFetchClient}
  alias Gaoxy.Proxy.HTTP.Session

  @moduletag :capture_log
  @timeout 3_000

  defmodule Origin do
    def init(observer), do: {:ok, observer}

    def call(exchange, observer) do
      send(observer, {:origin_request, self(), exchange.request.path})
      exchange = drain(exchange)

      case exchange.request.path do
        "/held" ->
          {:ok, exchange} = Response.send_chunked(exchange, 200, [])
          send(observer, {:origin_held, self()})

          receive do
            :release -> Response.finish(exchange, [])
          after
            Lifecycle.remaining(exchange.deadline) -> {:error, :timeout, exchange}
          end

        "/stream" ->
          bytes = :binary.copy("x", 20_000)
          {:ok, exchange} = Response.send_chunked(exchange, 200, [{"trailer", "x-check"}])
          {:ok, exchange} = Response.chunk(exchange, bytes)
          Response.finish(exchange, [{"x-check", "one"}, {"x-check", "two"}])
      end
    end

    defp drain(exchange) do
      if Exchange.body_complete?(exchange) do
        exchange
      else
        case Exchange.read_body_step(exchange, 16_384, 100) do
          {kind, _bytes, exchange} when kind in [:ok, :more] -> drain(exchange)
          {:pending, exchange} -> drain(exchange)
          {:error, reason, _exchange} -> raise "origin body failed: #{inspect(reason)}"
        end
      end
    end
  end

  defmodule LeaseOwner do
    use ThousandIsland.Handler

    def validate_options(%{observer: observer} = options) when is_pid(observer),
      do: {:ok, options}

    def handle_connection(_socket, state) do
      {:ok, lease} = Admission.acquire(state.gate, 10, drain_notify: true)
      deadline = Lifecycle.deadline(5_000)
      :ok = Admission.begin_request(state.gate, lease, 10, deadline)
      send(state.spec.handler_options.observer, {:lease_owner, self(), state, deadline})
      {:continue, Map.merge(state, %{lease: lease, deadline: deadline})}
    end

    def handle_info({:attach, guardian, reservation}, {socket, state}) do
      result =
        Service.attach_cleanup(
          state.service,
          state.gate,
          state.lease,
          guardian,
          reservation,
          state.deadline
        )

      send(state.spec.handler_options.observer, {:attached, result})
      {:noreply, {socket, state}}
    end

    def handle_info(:stop, {socket, state}), do: {:stop, :normal, {socket, state}}

    def handle_info({:gaoxy_drain, _, _, _}, {socket, state}),
      do: {:stop, :normal, {socket, state}}
  end

  setup_all do
    directory =
      Path.join(System.tmp_dir!(), "gaoxy-h3-guardian-#{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)
    ca = Path.join(directory, "ca.pem")
    ca_key = Path.join(directory, "ca-key.pem")
    cert = Path.join(directory, "cert.pem")
    key = Path.join(directory, "key.pem")
    csr = Path.join(directory, "request.pem")
    extensions = Path.join(directory, "extensions.cnf")

    File.write!(
      extensions,
      "basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=serverAuth\nsubjectAltName=DNS:localhost,IP:127.0.0.1\nsubjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid\n"
    )

    for args <- [
          [
            "req",
            "-x509",
            "-newkey",
            "ec",
            "-pkeyopt",
            "ec_paramgen_curve:P-256",
            "-nodes",
            "-days",
            "2",
            "-subj",
            "/CN=Gaoxy guardian test CA",
            "-keyout",
            ca_key,
            "-out",
            ca,
            "-addext",
            "basicConstraints=critical,CA:TRUE,pathlen:0",
            "-addext",
            "keyUsage=critical,keyCertSign,cRLSign"
          ],
          [
            "req",
            "-new",
            "-newkey",
            "ec",
            "-pkeyopt",
            "ec_paramgen_curve:P-256",
            "-nodes",
            "-subj",
            "/CN=localhost",
            "-keyout",
            key,
            "-out",
            csr
          ],
          [
            "x509",
            "-req",
            "-in",
            csr,
            "-CA",
            ca,
            "-CAkey",
            ca_key,
            "-CAcreateserial",
            "-days",
            "2",
            "-extfile",
            extensions,
            "-out",
            cert
          ]
        ] do
      {output, exit} = System.cmd("openssl", args, stderr_to_stdout: true)
      assert exit == 0, output
    end

    {:ok, ca: ca, cert: cert, key: key}
  end

  test "actual guardian retains stateful ACKs and Service bytes until owned H3 cleanup",
       context do
    {url, _origin} = origin(context)

    {runtime, owner, native, guardian, monitor, deadline, reservation} =
      guardian(url, context.ca, "/stream")

    assert_receive {:gaoxy_proxy_http, ^guardian, {:ready, upload, _, ^deadline}}, @timeout
    assert {:http3_session_upload, ^guardian, _, ^deadline, _} = upload
    assert :ok = HTTP3SessionClient.finish_body(upload, [])
    assert_receive {:origin_request, _, "/stream"}, @timeout
    assert_receive {:gaoxy_proxy_http, ^guardian, {:headers, 200, fields}}, @timeout
    assert {"trailer", "x-check"} in fields
    refute_receive {:gaoxy_proxy_http, ^guardian, {:end, _}}, 0
    assert_receive {:gaoxy_proxy_http, ^guardian, {:chunk, first, ref}}, @timeout
    assert byte_size(first) in 1..16_384
    before_ack = :sys.get_state(guardian)
    assert before_ack.delivery == ref
    assert before_ack.request.stream != nil
    assert before_ack.request.promise == nil
    assert before_ack.deadline == deadline

    Session.acknowledge(guardian, make_ref())
    stale_ack = :sys.get_state(guardian)
    assert stale_ack.delivery == ref
    refute_receive {:gaoxy_proxy_http, ^guardian, {:chunk, _, _}}, 30
    refute_receive {:gaoxy_proxy_http, ^guardian, {:end, _}}, 0
    Session.acknowledge(guardian, ref)
    bytes = receive_body(guardian, first)
    assert bytes == :binary.copy("x", 20_000)
    complete = :sys.get_state(guardian)
    assert complete.deadline == deadline
    assert complete.opening_deadline == before_ack.opening_deadline
    assert complete.request != before_ack.request
    assert %{cleanup_pending: 1, retained_bytes: retained} = Gaoxy.status(runtime, "guardian")
    assert retained >= reservation

    endpoint = complete.request.endpoint.pid
    caller = complete.request.caller.pid
    endpoint_monitor = Process.monitor(endpoint)
    caller_monitor = Process.monitor(caller)
    true = :erlang.suspend_process(endpoint)

    try do
      Session.consumed(guardian)
      cleaning = :sys.get_state(guardian)
      assert cleaning.cleanup_started
      assert cleaning.request.cleanup_deadline == cleaning.cleanup_deadline
      assert cleaning.cleanup_deadline <= min(Lifecycle.now() + 1_000, deadline + 1_000)
      assert %{cleanup_pending: 1, retained_bytes: retained} = Gaoxy.status(runtime, "guardian")
      assert retained >= reservation
      refute_receive {:DOWN, ^monitor, :process, ^guardian, _}, 30
      Session.consumed(guardian)
      assert :sys.get_state(guardian).cleanup_deadline == cleaning.cleanup_deadline
    after
      if Process.alive?(endpoint), do: true = :erlang.resume_process(endpoint)
    end

    assert_receive {:DOWN, ^endpoint_monitor, :process, ^endpoint, :normal}, @timeout
    assert_receive {:DOWN, ^caller_monitor, :process, ^caller, _}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout
    assert_baseline(runtime, owner, native)
  end

  test "actual HTTP endpoint uses the H3 upload finish and response client", context do
    {url, _origin} = origin(context)

    {:ok, proxy} =
      Gaoxy.HTTP.start_link(
        endpoint: {HTTP, %{upstream: url, upstream_protocol: :http3, cacertfile: context.ca}},
        limits: %{max_bytes: 8_388_608}
      )

    on_exit(fn -> if Process.alive?(proxy), do: Gaoxy.stop(proxy, @timeout) end)
    {:ok, {ip, port}} = Gaoxy.info(proxy, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(
        socket,
        "GET /stream HTTP/1.1\r\nHost: edge.test\r\nConnection: close\r\n\r\n"
      )

    wire = receive_wire(socket, "")
    [head, body] = String.split(wire, "\r\n\r\n", parts: 2)
    assert head =~ "HTTP/1.1 200 OK"
    assert String.downcase(head) =~ "transfer-encoding: chunked"
    {bytes, trailers} = decode_chunks(body, "")
    assert bytes == :binary.copy("x", 20_000)
    assert trailers == "x-check: one\r\nx-check: two\r\n\r\n"
    assert_receive {:origin_request, _, "/stream"}, @timeout
    refute_receive {:origin_request, _, "/stream"}, 0

    eventually(fn ->
      match?(
        %{active: 0, cleanup_pending: 0, retained_bytes: 0},
        Gaoxy.status(proxy, :http)
      )
    end)
  end

  test "actual guardian opening timer remains responsive to a silent QUIC origin", context do
    {:ok, silent} = :gen_udp.open(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(silent)
    on_exit(fn -> :gen_udp.close(silent) end)

    {runtime, owner, native, guardian, monitor, deadline, _reservation} =
      guardian("https://127.0.0.1:#{port}", context.ca, "/held", opening_timeout: 150)

    assert_receive {:gaoxy_proxy_http, ^guardian, {:ready, _, _, ^deadline}}, @timeout
    opening = :sys.get_state(guardian).opening_deadline
    assert opening < deadline
    assert_receive {:gaoxy_proxy_http, ^guardian, {:error, :timeout}}, 750
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout
    assert_baseline(runtime, owner, native)
  end

  for first <- [:owner, :timer] do
    test "#{first} expiry first emits exactly one H3 total timeout without changing its deadline" do
      deadline = Lifecycle.now() - 1
      state = expiry_state(HTTP3SessionClient, deadline)
      guardian = self()

      first =
        case unquote(first) do
          :owner -> Session.handle_cast(:expire, state)
          :timer -> Session.handle_info(:total_expired, state)
        end

      assert {:stop, :normal, settled} = first
      assert settled == %{state | cancelled: true, consumed: true}
      assert settled.deadline == deadline
      assert_received {:gaoxy_proxy_http, ^guardian, {:error, :request_timeout}}
      refute_received {:gaoxy_proxy_http, ^guardian, _}

      assert {:stop, :normal, ^settled} = Session.handle_cast(:expire, settled)
      assert {:stop, :normal, ^settled} = Session.handle_info(:total_expired, settled)
      assert {:stop, :normal, ^settled} = Session.handle_cast(:expire, settled)
      refute_received {:gaoxy_proxy_http, ^guardian, _}
    end
  end

  test "owner expiry preserves H1 timeout and an earlier H3 owner timeout category" do
    guardian = self()

    for {client, deadline} <- [
          {HTTPFetchClient, Lifecycle.now() - 1},
          {HTTP3SessionClient, Lifecycle.deadline(60_000)}
        ] do
      state = expiry_state(client, deadline)
      assert {:stop, :normal, settled} = Session.handle_cast(:expire, state)
      assert settled == %{state | cancelled: true, consumed: true}
      assert settled.deadline == deadline
      assert_received {:gaoxy_proxy_http, ^guardian, {:error, :timeout}}
      refute_received {:gaoxy_proxy_http, ^guardian, _}
      assert {:stop, :normal, ^settled} = Session.handle_info(:total_expired, settled)
      refute_received {:gaoxy_proxy_http, ^guardian, _}
    end
  end

  test "owner expiry and timer replay never notify cancelled or consumed requests" do
    state = expiry_state(HTTP3SessionClient, Lifecycle.now() - 1)
    guardian = self()
    assert {:stop, :normal, cancelled} = Session.handle_cast(:cancel, state)
    assert cancelled == %{state | cancelled: true, consumed: true}
    assert {:stop, :normal, ^cancelled} = Session.handle_cast(:expire, cancelled)
    assert {:stop, :normal, ^cancelled} = Session.handle_info(:total_expired, cancelled)
    refute_received {:gaoxy_proxy_http, ^guardian, _}

    assert {:noreply, consumed} = Session.handle_cast(:consumed, state)
    assert consumed == %{state | consumed: true, outcome: :success}
    assert {:noreply, ^consumed} = Session.handle_cast(:expire, consumed)
    assert {:noreply, ^consumed} = Session.handle_info(:total_expired, consumed)
    assert {:noreply, ^consumed} = Session.handle_info(:opening_expired, consumed)
    assert consumed.deadline == state.deadline
    refute_received {:gaoxy_proxy_http, ^guardian, _}
  end

  test "actual guardian total timer survives headers and paused downstream delivery", context do
    {url, _origin} = origin(context)

    {runtime, owner, native, guardian, monitor, deadline, _reservation} =
      guardian(url, context.ca, "/stream", max_lifetime: 1_500)

    assert_receive {:gaoxy_proxy_http, ^guardian, {:ready, upload, _, ^deadline}}, @timeout
    assert :ok = HTTP3SessionClient.finish_body(upload, [])
    assert_receive {:gaoxy_proxy_http, ^guardian, {:headers, 200, _}}, @timeout
    assert_receive {:gaoxy_proxy_http, ^guardian, {:chunk, _, ref}}, @timeout
    state = :sys.get_state(guardian)
    assert state.delivery == ref
    assert state.deadline == deadline
    assert_receive {:gaoxy_proxy_http, ^guardian, {:error, :request_timeout}}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout
    assert_baseline(runtime, owner, native)
  end

  test "actual Service cancellation keeps its earlier absolute cleanup deadline", context do
    {url, _origin} = origin(context)

    {runtime, owner, native, guardian, monitor, deadline, reservation} =
      guardian(url, context.ca, "/held")

    assert_receive {:gaoxy_proxy_http, ^guardian, {:ready, upload, _, ^deadline}}, @timeout
    assert :ok = HTTP3SessionClient.finish_body(upload, [])
    assert_receive {:gaoxy_proxy_http, ^guardian, {:headers, 200, _}}, @timeout
    assert_receive {:origin_held, origin_worker}, @timeout
    state = :sys.get_state(guardian)
    endpoint = state.request.endpoint.pid
    true = :erlang.suspend_process(endpoint)
    cleanup_deadline = Lifecycle.deadline(500)

    try do
      send(guardian, {:gaoxy_cleanup_cancel, state.token, :test, cleanup_deadline})
      cleaning = :sys.get_state(guardian)
      assert cleaning.cancelled
      assert cleaning.cleanup_deadline == cleanup_deadline
      assert cleaning.request.cleanup_deadline == cleanup_deadline
      send(guardian, {:gaoxy_cleanup_cancel, state.token, :test, deadline + 1_000})
      assert :sys.get_state(guardian).cleanup_deadline == cleanup_deadline
      assert %{cleanup_pending: 1, retained_bytes: retained} = Gaoxy.status(runtime, "guardian")
      assert retained >= reservation
      refute_receive {:DOWN, ^monitor, :process, ^guardian, _}, 30
    after
      if Process.alive?(endpoint), do: true = :erlang.resume_process(endpoint)
    end

    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout
    send(origin_worker, :release)
    assert_baseline(runtime, owner, native)
  end

  test "missing endpoint stop confirmation fails actual guardian without a Service receipt",
       context do
    {url, _origin} = origin(context)

    {runtime, _owner, native, guardian, monitor, deadline, reservation} =
      guardian(url, context.ca, "/held")

    assert_receive {:gaoxy_proxy_http, ^guardian, {:ready, upload, _, ^deadline}}, @timeout
    assert :ok = HTTP3SessionClient.finish_body(upload, [])
    assert_receive {:gaoxy_proxy_http, ^guardian, {:headers, 200, _}}, @timeout
    assert_receive {:origin_held, origin_worker}, @timeout
    state = :sys.get_state(guardian)
    endpoint = state.request.endpoint.pid
    caller = state.request.caller.pid
    endpoint_monitor = Process.monitor(endpoint)
    caller_monitor = Process.monitor(caller)
    :erlang.trace(guardian, true, [:send, {:tracer, self()}])
    true = :erlang.suspend_process(endpoint)

    try do
      send(guardian, {:gaoxy_cleanup_cancel, state.token, :test, Lifecycle.deadline(100)})
      cleaning = :sys.get_state(guardian)
      assert cleaning.cancelled
      assert %{cleanup_pending: 1, retained_bytes: retained} = Gaoxy.status(runtime, "guardian")
      assert retained >= reservation
      assert_receive {:DOWN, ^monitor, :process, ^guardian, :cleanup_unconfirmed}, @timeout

      token = state.token
      service = native.service

      refute_receive {:trace, ^guardian, :send, {:"$gen_call", _, {:complete_cleanup, ^token}},
                      ^service},
                     0
    after
      if Process.alive?(endpoint), do: true = :erlang.resume_process(endpoint)
      if Process.alive?(guardian), do: :erlang.trace(guardian, false, [:send])
      send(origin_worker, :release)
    end

    assert_receive {:DOWN, ^endpoint_monitor, :process, ^endpoint, _observed_reason}, @timeout
    assert_receive {:DOWN, ^caller_monitor, :process, ^caller, _}, @timeout
    eventually(fn -> Gaoxy.info(runtime, "guardian") == {:error, :not_running} end)
  end

  defp origin(context) do
    {:ok, runtime} =
      Gaoxy.HTTP.HTTP3.start_link(
        endpoint: {Origin, self()},
        tls: %{certfile: context.cert, keyfile: context.key},
        http_limits: %{request_timeout: 5_000}
      )

    on_exit(fn -> if Process.alive?(runtime), do: Gaoxy.stop(runtime, @timeout) end)
    {:ok, {_, port}} = Gaoxy.info(runtime, :http3).local
    {"https://127.0.0.1:#{port}", runtime}
  end

  defp guardian(url, ca, path, limits \\ []) do
    {:ok, runtime} =
      Gaoxy.start_link(
        services: [
          %{
            id: "guardian",
            transport: :tcp,
            handler_mode: :native,
            handler: LeaseOwner,
            handler_options: %{observer: self()},
            limits: %{max_bytes: 8_388_608}
          }
        ]
      )

    on_exit(fn -> if Process.alive?(runtime), do: Gaoxy.stop(runtime, @timeout) end)
    {:ok, {ip, port}} = Gaoxy.info(runtime, "guardian").local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)
    assert_receive {:lease_owner, owner, native, lease_deadline}, @timeout

    options =
      Map.merge(%{upstream: url, upstream_protocol: :http3, cacertfile: ca}, Map.new(limits))

    assert {:ok, config} = HTTP.init(options)

    {:ok, normalized} =
      Gaoxy.HTTP.Options.normalize(%{endpoint: {Origin, self()}, http_limits: %{}})

    started_at = Lifecycle.now()
    deadline = min(lease_deadline, started_at + config.limits.max_lifetime)

    args = %{
      owner: self(),
      service: native.service,
      instance: native.instance,
      gate: native.gate,
      started_at: started_at,
      deadline: deadline,
      config: config,
      selector: {:fixed, config},
      request_options: %{
        method: :get,
        headers: [],
        body: :none,
        path: path,
        query: nil,
        max_upload_bytes: config.limits.max_chunk_bytes,
        limits: normalized.http_limits
      }
    }

    assert {:ok, guardian} = Session.start_link(args)
    Process.unlink(guardian)
    on_exit(fn -> if Process.alive?(guardian), do: Session.cancel(guardian) end)
    monitor = Process.monitor(guardian)
    reservation = HTTP3SessionClient.reservation_bytes([], byte_size(url <> path), 16_384)
    send(owner, {:attach, guardian, reservation})
    assert_receive {:attached, {:ok, _}}, @timeout
    {runtime, owner, native, guardian, monitor, deadline, reservation}
  end

  defp expiry_state(client, deadline) do
    %{
      owner: self(),
      client: client,
      deadline: deadline,
      token: nil,
      request: nil,
      headers: true,
      delivery: make_ref(),
      outcome: :cancelled,
      cancelled: false,
      consumed: false
    }
  end

  defp receive_body(guardian, bytes) do
    receive do
      {:gaoxy_proxy_http, ^guardian, {:chunk, next, ref}} ->
        assert byte_size(next) in 1..16_384
        Session.acknowledge(guardian, ref)
        receive_body(guardian, bytes <> next)

      {:gaoxy_proxy_http, ^guardian, {:end, trailers}} ->
        assert trailers == [{"x-check", "one"}, {"x-check", "two"}]
        bytes

      {:gaoxy_proxy_http, ^guardian, {:error, reason}} ->
        flunk("guardian response failed: #{inspect(reason)}")
    after
      @timeout -> flunk("guardian response exceeded finite deadline")
    end
  end

  defp receive_wire(socket, bytes) do
    case :gen_tcp.recv(socket, 0, @timeout) do
      {:ok, next} -> receive_wire(socket, bytes <> next)
      {:error, :closed} -> bytes
      error -> flunk("proxy wire failed: #{inspect(error)}")
    end
  end

  defp decode_chunks(wire, bytes) do
    [size, rest] = String.split(wire, "\r\n", parts: 2)

    case String.to_integer(size, 16) do
      0 ->
        {bytes, rest}

      count ->
        <<chunk::binary-size(count), "\r\n", tail::binary>> = rest
        decode_chunks(tail, bytes <> chunk)
    end
  end

  defp assert_baseline(runtime, owner, native) do
    send(owner, :stop)

    eventually(fn ->
      match?(
        %{active: 0, cleanup_pending: 0, retained_bytes: 0},
        Gaoxy.status(runtime, "guardian")
      )
    end)

    assert %{active: 0, cleanup_pending: 0, retained_bytes: 0} = Admission.status(native.gate)
  end

  defp eventually(fun, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(@timeout)

    if fun.() do
      :ok
    else
      assert Lifecycle.remaining(deadline) > 0

      receive do
      after
        2 -> eventually(fun, deadline)
      end
    end
  end
end
