defmodule Gaoxy.Proxy.StreamRelay.Upstream do
  @moduledoc false

  def connect(config, timeout) do
    {address, port} = config.upstream

    base = [
      :binary,
      active: false,
      packet: :raw,
      buffer: config.max_chunk_bytes,
      recbuf: config.max_chunk_bytes,
      send_timeout: config.write_timeout,
      send_timeout_close: false
    ]

    family = if tuple_size(address) == 8, do: :inet6, else: :inet

    if config.mode == :tls_upstream do
      tls = config.upstream_tls

      options =
        [family | base] ++
          [
            verify: :verify_peer,
            cacertfile: String.to_charlist(tls.cacertfile),
            server_name_indication: String.to_charlist(tls.server_name),
            customize_hostname_check: [
              match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
            ],
            versions: [:"tlsv1.3", :"tlsv1.2"]
          ]

      case :ssl.connect(address, port, options, timeout) do
        {:ok, socket} -> {:ok, {:tls, socket}}
        error -> error
      end
    else
      case :gen_tcp.connect(address, port, [family, {:exit_on_close, false} | base], timeout) do
        {:ok, socket} -> {:ok, {:tcp, socket}}
        error -> error
      end
    end
  end

  def recv({:tcp, socket}, timeout), do: :gen_tcp.recv(socket, 0, timeout)
  def recv({:tls, socket}, timeout), do: :ssl.recv(socket, 0, timeout)

  def send({:tcp, socket}, bytes, timeout) do
    with :ok <- :inet.setopts(socket, send_timeout: timeout, send_timeout_close: false),
         do: :gen_tcp.send(socket, bytes)
  end

  def send({:tls, socket}, bytes, timeout) do
    with :ok <- :ssl.setopts(socket, send_timeout: timeout, send_timeout_close: false),
         do: :ssl.send(socket, bytes)
  end

  def shutdown({:tcp, socket}), do: :gen_tcp.shutdown(socket, :write)
  def getstat({:tcp, socket}), do: :inet.getstat(socket, [:send_pend])

  def abort({:tcp, socket}) do
    :inet.setopts(socket, linger: {true, 0})
    :gen_tcp.close(socket)
  end

  def abort({:tls, socket}), do: :ssl.close(socket, 0)
  def close({:tcp, socket}), do: :gen_tcp.close(socket)
  def close({:tls, socket}), do: :ssl.close(socket, 0)
end
