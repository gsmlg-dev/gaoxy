base = Path.join(System.get_env("HTTP_FETCH_AUDIT_DIR", ".audit/http_fetch"), "apps")
paths = [
  "http_core/lib/http/headers.ex", "http_core/lib/http/blob.ex", "http_core/lib/http/form_data.ex",
  "http_core/lib/http/request.ex", "http_core/lib/http/http1.ex", "http_core/lib/http/transport.ex",
  "http_core/lib/http/transport/tcp.ex", "http_core/lib/http/transport/ssl.ex", "http_core/lib/http/tls_backend.ex",
  "http_runtime/lib/http/runtime/dialer.ex",
  "http_fetch/lib/http/config.ex", "http_fetch/lib/http/telemetry.ex", "http_fetch/lib/http/content_decoder.ex",
  "http_fetch/lib/http/stream.ex", "http_fetch/lib/http/response.ex", "http_fetch/lib/http/promise.ex",
  "http_fetch/lib/http/abort_controller.ex", "http_fetch/lib/http/fetch_options.ex", "http_fetch/lib/http/status_text.ex",
  "http_fetch/lib/http/socket_client.ex", "http_fetch/lib/http.ex"
]
{:ok, _, _} = Kernel.ParallelCompiler.compile(Enum.map(paths, &Path.join(base, &1)))
{:ok, _} = Application.ensure_all_started(:telemetry)
{:ok, _} = Task.Supervisor.start_link(name: :http_fetch_task_supervisor)
{:ok, _} = Task.Supervisor.start_link(name: :http_runtime_task_supervisor)
{:ok, _} = Registry.start_link(keys: :unique, name: HTTP.AbortController)

defmodule AuditPeer do
  def start(wire) do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, packet: :raw, active: false, ip: {127,0,0,1}, reuseaddr: true])
    {:ok, {_, port}} = :inet.sockname(listener)
    pid = spawn(fn ->
      {:ok, socket} = :gen_tcp.accept(listener)
      head(socket, <<>>)
      :ok = :gen_tcp.send(socket, wire)
      receive do :stop -> :ok after 3000 -> :ok end
      :gen_tcp.close(socket)
      :gen_tcp.close(listener)
    end)
    {"http://127.0.0.1:#{port}/", pid}
  end
  defp head(socket, bytes) do
    if :binary.match(bytes, "\r\n\r\n") != :nomatch do
      :ok
    else
      {:ok, next} = :gen_tcp.recv(socket, 0, 1000)
      head(socket, bytes <> next)
    end
  end
end
plain = "proxy-content"
encoded = :zlib.gzip(plain)
for streaming <- [false, true] do
  framing = if streaming do
    ["Transfer-Encoding: chunked\r\n\r\n", Integer.to_string(byte_size(encoded),16), "\r\n",encoded,"\r\n0\r\nX-Checksum: expected\r\n\r\n"]
  else
    ["Content-Length: ", to_string(byte_size(encoded)),"\r\n\r\n",encoded]
  end
  {url, peer} = AuditPeer.start(["HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nSet-Cookie: a=1\r\nSet-Cookie: b=2\r\n", framing])
  # TODO(upstream): gsmlg-dev/http_fetch#27 - explicit raw mode for both paths.
  # TODO(upstream): gsmlg-dev/http_fetch#29 - H1 trailers before stream completion.
  response = HTTP.fetch(url, http_version: :http1, redirect: :manual, timeout: 1000, raw_body: true, decompress: false) |> HTTP.Promise.await(2000)
  if streaming do
    stream = response.body
    send(stream, {:read_chunk, self(), :ack})
    result = receive do
      {:stream_chunk, ^stream, bytes, ref} ->
        send(stream, {:stream_chunk_ack, ref})
        {bytes, ref}
    after 1000 -> :timeout end
    terminal = receive do message -> message after 1000 -> :timeout end
    IO.inspect({:streamed, result, terminal, HTTP.Headers.get(response.headers,"content-encoding"), HTTP.Headers.to_list(response.trailers),HTTP.Headers.get_all(response.headers,"set-cookie")})
  else
    IO.inspect({:buffered, response.body, HTTP.Headers.get(response.headers,"content-encoding"),HTTP.Headers.get(response.headers,"content-length"), byte_size(encoded)})
  end
  send(peer,:stop)
end
{url, peer} = AuditPeer.start("HTTP/1.1 413 Payload Too Large\r\nContent-Length: 0\r\n\r\n")
{:ok, upload} = HTTP.Stream.start_link(0)
# TODO(upstream): gsmlg-dev/http_fetch#28 - receive the 413 before upload EOF.
result = HTTP.fetch(url, method: :post, body: upload, duplex: "half", timeout: 150, redirect: :manual) |> HTTP.Promise.await(2000)
IO.inspect({:h1_early_response, result})
send(peer, :stop)
