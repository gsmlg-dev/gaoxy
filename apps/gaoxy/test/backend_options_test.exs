defmodule Gaoxy.BackendOptionsTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.{BackendOptions, Config}

  defmodule Echo do
    def init(_, _), do: {:ok, nil}
    def handle_data(bytes, state), do: {:send, bytes, state}
    def handle_datagram(packet, _), do: {:reply, packet.data}
  end

  defp spec(extra \\ %{}),
    do: Map.merge(%{id: :echo, transport: :tcp, handler: Echo}, extra)

  test "empty backend options preserve existing defaults and normalize idempotently" do
    assert {:ok, defaults} = Config.service(spec())
    assert defaults.hell_options == []
    assert defaults.abyss_options == []
    assert defaults.limits.max_active == 64
    assert {:ok, ^defaults} = Config.service(spec(%{hell_options: [], abyss_options: []}))
    assert {:ok, ^defaults} = Config.service(defaults)
  end

  test "strict backend and nested option lists reject duplicates, malformed and unknown entries" do
    for options <- [%{}, nil, [:binary], [num_acceptors: 1, num_acceptors: 2]] do
      assert {:error, {:invalid_backend_options, :hell_options}} =
               Config.service(spec(%{hell_options: options}))
    end

    for options <- [%{}, [:inet], [backlog: 1, backlog: 2]] do
      assert {:error, {:invalid_backend_options, {:hell_options, :transport_options}}} =
               Config.service(spec(%{hell_options: [transport_options: options]}))
    end

    assert {:error, {:unsupported_backend_option, :hell_options, :typo}} =
             Config.service(spec(%{hell_options: [typo: 1]}))
  end

  test "handler, binding, resource and lifecycle ownership cannot be overridden" do
    for key <- [
          :handler_module,
          :handler_options,
          :transport_module,
          :port,
          :ip,
          :genserver_options,
          :supervisor_options,
          :num_connections,
          :num_listen_sockets,
          :read_timeout,
          :handshake_timeout,
          :shutdown_timeout,
          :max_connections_retry_count,
          :max_connections_retry_wait,
          :silent_terminate_on_error
        ] do
      assert {:error, {:unsupported_backend_option, :hell_options, ^key}} =
               Config.service(spec(%{hell_options: [{key, 1}]}))
    end

    for key <- [
          :active,
          :mode,
          :packet,
          :ip,
          :port,
          :ifaddr,
          :fd,
          :raw,
          :inet_backend,
          :reuseaddr,
          :reuseport,
          :send_timeout,
          :send_timeout_close,
          :certfile,
          :keyfile,
          :alpn_preferred_protocols
        ] do
      assert {:error, {:unsupported_backend_option, :hell_options, {:transport_options, ^key}}} =
               Config.service(spec(%{hell_options: [transport_options: [{key, 1}]]}))
    end

    for key <- [
          :num_connections,
          :num_listeners,
          :dynamic_listeners,
          :datagram_handler,
          :datagram_dispatcher,
          :runtime_options,
          :read_timeout,
          :shutdown_timeout
        ] do
      assert {:error, {:unsupported_backend_option, :abyss_options, ^key}} =
               Config.service(spec(%{transport: :udp, abyss_options: [{key, 1}]}))
    end

    for key <- [:recbuf, :sndbuf, :buffer, :active, :mode, :ip, :reuseport] do
      assert {:error, {:unsupported_backend_option, :abyss_options, {:transport_options, ^key}}} =
               Config.service(
                 spec(%{transport: :udp, abyss_options: [transport_options: [{key, 1}]]})
               )
    end
  end

  test "backend-specific options and finite socket ranges fail before startup" do
    assert {:error, {:inapplicable_backend_options, :abyss_options}} =
             Config.service(spec(%{abyss_options: [udp_buffer_size: 1000]}))

    assert {:error, {:inapplicable_backend_options, :hell_options}} =
             Config.service(spec(%{transport: :udp, hell_options: [num_acceptors: 1]}))

    for value <- [0, -1, :infinity, 65, 1.5] do
      assert {:error, {:invalid_backend_option, :hell_options, :num_acceptors}} =
               Config.service(spec(%{hell_options: [num_acceptors: value]}))
    end

    for {key, value} <- [
          backlog: 0,
          recbuf: -1,
          sndbuf: :infinity,
          buffer: 2_147_483_648,
          nodelay: 1,
          keepalive: nil,
          tos: 256
        ] do
      assert {:error, {:invalid_backend_option, :hell_options, {:transport_options, ^key}}} =
               Config.service(spec(%{hell_options: [transport_options: [{key, value}]]}))
    end

    assert {:error, {:invalid_backend_option, :abyss_options, :udp_buffer_size}} =
             Config.service(spec(%{transport: :udp, abyss_options: [udp_buffer_size: 0]}))

    for key <- [:tos, :ttl] do
      assert {:error, {:invalid_backend_option, :abyss_options, {:transport_options, ^key}}} =
               Config.service(
                 spec(%{
                   transport: :udp,
                   ip: {0, 0, 0, 0, 0, 0, 0, 1},
                   abyss_options: [transport_options: [{key, 1}]]
                 })
               )
    end
  end

  test "QUIC polling aliases normalize before defaults and reject explicit conflicts" do
    raw = %{
      transport: :quic,
      quic: %{alpn: ["h3"]},
      abyss_options: [event_batch: 7, poll_interval: 3]
    }

    assert {:ok, normalized} = BackendOptions.normalize(raw)
    assert normalized.quic.poll_interval == 3
    assert normalized.abyss_options == [event_batch: 7]
    assert {:ok, ^normalized} = BackendOptions.normalize(normalized)

    assert {:ok, ^normalized} =
             BackendOptions.normalize(%{raw | quic: %{alpn: ["h3"], poll_interval: 3}})

    assert {:error, {:backend_option_conflict, :poll_interval}} =
             BackendOptions.normalize(%{raw | quic: %{poll_interval: 4}})

    for {key, value} <- [event_batch: 0, event_batch: 129, poll_interval: 0, poll_interval: 1001] do
      assert {:error, {:invalid_backend_option, :abyss_options, ^key}} =
               BackendOptions.normalize(%{transport: :quic, abyss_options: [{key, value}]})
    end

    for key <- [
          :quic_options,
          :transport_options,
          :udp_buffer_size,
          :handler,
          :alpn,
          :tls,
          :max_connections,
          :name,
          :init_timeout,
          :callback_timeout,
          :shutdown_timeout,
          :writer_timeout,
          :writer_max_queue,
          :writer_max_bytes,
          :_backend
        ] do
      assert {:error, {:unsupported_backend_option, :abyss_options, ^key}} =
               BackendOptions.normalize(%{transport: :quic, abyss_options: [{key, 1}]})
    end
  end
end
