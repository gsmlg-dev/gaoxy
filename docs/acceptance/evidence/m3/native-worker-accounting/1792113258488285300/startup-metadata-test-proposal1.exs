# Proposal only: append this module to http2_worker_startup_test.exs.
# Root owns RED/GREEN execution; this proposal has not been compiled or run.
defmodule Gaoxy.HTTP2StartupMetadataTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Admission
  alias Gaoxy.HTTP.Connection
  @wait 3_000

  defmodule Endpoint do
    def init(owner), do: {:ok, owner}
    def call(exchange, owner) do
      send(owner, {:unexpected_startup_endpoint, self()})
      {:error, :unexpected_startup_endpoint, exchange}
    end
  end

  defmodule TLSBarrier do
    @wait 3_000
    def secure?, do: true

    def negotiated_protocol({native, owner, token}) do
      actual = :ssl.negotiated_protocol(native)
      send(owner, {:startup_alpn, self(), token, actual})

      receive do
        {:observe_peer_close, ^token} ->
          closed = :ssl.recv(native, 0, @wait)
          peer = :ssl.peername(native)
          send(owner, {:startup_tls_closed, self(), token, closed, peer})
      after
        @wait -> raise "startup peer-close observation deadline"
      end

      receive do
        {:resume_alpn, ^token} -> actual
      after
        @wait -> raise "startup ALPN release deadline"
      end
    end

    def peername({native, owner, token}) do
      actual = :ssl.peername(native)
      send(owner, {:startup_peername, self(), token, actual})
      actual
    end

    def sockname({native, _, _}), do: :ssl.sockname(native)
    def connection_information({native, _, _}), do: :ssl.connection_information(native)
    def peercert({native, _, _}), do: :ssl.peercert(native)
    def setopts({native, _, _}, options), do: :ssl.setopts(native, options)
    def getstat({native, _, _}), do: :ssl.getstat(native)
    def close({native, _, _}), do: :ssl.close(native)
  end

  defmodule CloseAfterPeername do
    def secure?, do: false
    def peername({native, owner}) do
      actual = :inet.peername(native)
      send(owner, {:startup_open_peername, actual})
      :ok = :gen_tcp.close(native)
      actual
    end
    def sockname({native, owner}) do
      actual = :inet.sockname(native)
      send(owner, {:startup_closed_sockname, actual})
      actual
    end
  end

  test "closed real TCP metadata ends startup without admission" do
    {native, _client} = tcp_pair()
    assert :ok = :gen_tcp.close(native)
    assert {:error, :einval} = :inet.peername(native)
    {context, hook} = context([])
    socket = socket(native, ThousandIsland.Transports.TCP)
    assert {:close, ^context} = Connection.handle_connection(socket, context)
    assert_no_admission(context.gate, hook)
  end

  test "real socket closure after peername handles sockname failure without admission" do
    {native, _client} = tcp_pair()
    {context, hook} = context([])
    socket = socket({native, self()}, CloseAfterPeername)
    assert {:close, ^context} = Connection.handle_connection(socket, context)
    assert_receive {:startup_open_peername, {:ok, {{127, 0, 0, 1}, port}}}, @wait
    assert port > 0
    assert_receive {:startup_closed_sockname, {:error, :einval}}, @wait
    assert_no_admission(context.gate, hook)
  end

  @tag :tmp_dir
  test "real TLS peer closes after actual h2 ALPN and generated startup ends orderly", %{tmp_dir: dir} do
    script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
    assert {_, 0} = System.cmd("bash", [script, dir], stderr_to_stdout: true)
    cert = Path.join(dir, "cert.pem")
    key = Path.join(dir, "key.pem")
    {context, hook} = context(transport: :tls, tls: %{certfile: cert, keyfile: key}, h2c: :disabled)

    {:ok, listener} = :ssl.listen(0, [:binary, active: false, reuseaddr: true,
      certfile: String.to_charlist(cert), keyfile: String.to_charlist(key),
      alpn_preferred_protocols: ["h2"]])
    on_exit(fn -> :ssl.close(listener) end)
    {:ok, {{127, 0, 0, 1}, _}} = {:ok, {{127, 0, 0, 1}, 0}}
    {:ok, {_, port}} = :ssl.sockname(listener)
    owner = self()
    token = make_ref()

    {worker, monitor} = spawn_monitor(fn ->
      {:ok, accepted} = :ssl.transport_accept(listener, @wait)
      {:ok, native} = :ssl.handshake(accepted, @wait)
      socket = socket({native, owner, token}, TLSBarrier)
      try do
        result = Connection.handle_continue(:handle_connection, {socket, context})
        send(owner, {:startup_continuation, self(), token, result})
        case result do
          {:stop, reason, {^socket, ^context}} -> Connection.terminate(reason, {socket, context})
          _ -> :ok
        end
      after
        :ssl.close(native)
      end
    end)
    on_exit(fn -> stop_owned_worker(worker) end)

    {:ok, client} = :ssl.connect({127, 0, 0, 1}, port, [:binary, active: false,
      verify: :verify_peer, cacertfile: String.to_charlist(Path.join(dir, "ca.pem")),
      server_name_indication: ~c"localhost", alpn_advertised_protocols: ["h2"]], @wait)
    on_exit(fn -> :ssl.close(client) end)
    assert {:ok, "h2"} = :ssl.negotiated_protocol(client)
    assert_receive {:startup_alpn, ^worker, ^token, {:ok, "h2"}}, @wait
    assert :ok = :ssl.close(client, @wait)
    send(worker, {:observe_peer_close, token})
    assert_receive {:startup_tls_closed, ^worker, ^token, {:error, :closed}, {:error, reason}}, @wait
    assert reason in [:closed, :einval, :enotconn]
    send(worker, {:resume_alpn, token})
    assert_receive {:DOWN, ^monitor, :process, ^worker, terminal}, @wait
    assert terminal == :normal
    assert_receive {:startup_peername, ^worker, ^token, {:error, actual}}, @wait
    assert actual in [:closed, :einval, :enotconn]
    assert_receive {:startup_continuation, ^worker, ^token,
      {:stop, {:shutdown, :local_closed}, {_socket, ^context}}}, @wait
    assert_no_admission(context.gate, hook)
  end

  defp context(extra) do
    options = Keyword.merge([endpoint: {Endpoint, self()}, protocols: [:http2],
      h2c: :prior_knowledge, limits: %{max_bytes: 536_870_912}], extra)
    {:ok, spec} = Gaoxy.HTTP.service_spec(options)
    gate = start_supervised!({Admission, {spec.limits, %{instance: make_ref(), service: :metadata}}})
    owner = self()
    hook = make_ref()
    :ok = :sys.install(gate, {hook, fn previous, event, _ ->
      case event do
        {:in, {:"$gen_call", _, {:acquire, _, _}}} -> send(owner, {:startup_acquire, hook})
        _ -> :ok
      end
      previous
    end, nil}, @wait)
    {%{spec: spec, gate: gate}, hook}
  end

  defp socket(native, transport) do
    struct!(ThousandIsland.Socket, socket: native, transport_module: transport,
      read_timeout: @wait, handshake_timeout: @wait, silent_terminate_on_error: false,
      span: ThousandIsland.Telemetry.start_span(:connection, %{}, %{handler: Connection}))
  end

  defp tcp_pair do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    on_exit(fn -> :gen_tcp.close(listener) end)
    {:ok, {_, port}} = :inet.sockname(listener)
    {:ok, client} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false], @wait)
    on_exit(fn -> :gen_tcp.close(client) end)
    {:ok, native} = :gen_tcp.accept(listener, @wait)
    on_exit(fn -> :gen_tcp.close(native) end)
    {native, client}
  end

  defp assert_no_admission(gate, hook) do
    # Same-Gate reply follows any debug notification sent before that callback.
    assert %{active: 0, retained_bytes: 0, cleanup_pending: 0} = Admission.status(gate)
    refute_receive {:startup_acquire, ^hook}, 0
    refute_receive {:unexpected_startup_endpoint, _}, 0
  end

  defp stop_owned_worker(worker) do
    monitor = Process.monitor(worker)
    if Process.alive?(worker), do: Process.exit(worker, :kill)
    receive do
      {:DOWN, ^monitor, :process, ^worker, _} -> :ok
    after
      @wait -> raise "owned metadata fixture cleanup join deadline"
    end
  end
end
