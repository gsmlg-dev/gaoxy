defmodule Gaoxy.Proxy.HTTPFetchClient do
  @moduledoc false
  @behaviour Gaoxy.Proxy.UpstreamClient
  alias HTTP.{Promise, RequestCompletion, Response, Stream}

  # Pinned 0.19.0/default :inet receive bound: OTP SSL can combine at most
  # internal_active_n (<=100) receive buffers with one maximum TLS 1.2 record.
  # HTTP framing carry is independently bounded to 65,536 bytes. Eight windows
  # cover retained deliveries and copies; this excludes OTP/kernel socket
  # buffers and process metadata and is not a total BEAM memory measurement.
  @receive_buffer 8_192
  @max_delivery 100 * @receive_buffer + 18_437
  @framing_carry 65_536

  @impl true
  def host_supported? do
    backend = Application.get_env(:kernel, :inet_backend, :inet)
    active = Application.get_env(:ssl, :internal_active_n, 100)
    backend == :inet and is_integer(active) and active in 1..100
  end

  @impl true
  def completion(handle), do: handle.completion
  @impl true
  def await_completion(completion, true), do: RequestCompletion.abort_and_await(completion, 0)
  def await_completion(completion, false), do: RequestCompletion.await(completion, 0)

  def reservation(fields, url, chunk_bytes),
    do:
      8 * (@max_delivery + @framing_carry) + 8 * chunk_bytes +
        2 * :erlang.external_size({fields, url})

  @impl true
  def reservation_bytes(fields, url_bytes, chunk_bytes),
    do: reservation(fields, "", chunk_bytes) + 2 * url_bytes

  @impl true
  def open(options) do
    upload =
      if options.body in [:none, {:length, 0}] do
        nil
      else
        {:ok, stream} = Stream.start_link(0)
        Process.unlink(stream)
        stream
      end

    # The dedicated-H1 adapter uses the caller's certificate file directly.
    ssl = if options.cacertfile, do: [cacertfile: options.cacertfile], else: []

    try do
      promise =
        HTTP.fetch(options.url,
          method: options.method,
          headers: options.headers,
          # Managed 0.21.2 charges normalized inputs and generated fields (#87).
          # Keep URL strings, explicit fields and nil/PID body inputs here.
          body: upload,
          duplex: if(upload, do: :half, else: nil),
          # v0.2.0 uses one dedicated H1 connection per request.
          # Reusable H1 and upstream H2 adapters are not implemented.
          http_version: :http1,
          http1_reuse: false,
          redirect: :manual,
          request_mode: :proxy,
          decode_body: false,
          stream_response: true,
          tls_backend: :ssl,
          ssl: ssl,
          connect_address: Map.get(options, :connect_address),
          timeout: options.timeout,
          connect_timeout: min(options.timeout, options.opening_timeout),
          telemetry: false,
          socket_opts: [
            buffer: @receive_buffer,
            recbuf: @receive_buffer,
            send_timeout: min(options.timeout, options.write_timeout),
            send_timeout_close: true
          ]
        )

      {:ok,
       %{promise: promise, completion: Promise.completion(promise), stream: nil, resolved: false},
       upload}
    catch
      kind, reason ->
        case stop_upload(upload, options.timeout) do
          :ok -> {:error, {kind, reason}}
          :unconfirmed -> {:error, {:cleanup_unconfirmed, {kind, reason}}}
        end
    end
  end

  defp stop_upload(nil, _timeout), do: :ok

  defp stop_upload(upload, timeout) do
    monitor = Process.monitor(upload)
    Process.exit(upload, :kill)

    receive do
      {:DOWN, ^monitor, :process, ^upload, _} -> :ok
    after
      timeout ->
        Process.demonitor(monitor, [:flush])
        :unconfirmed
    end
  end

  @impl true
  def poll_headers(%{resolved: true} = handle), do: {:none, handle}

  def poll_headers(handle) do
    case Task.yield(handle.promise.task, 0) do
      nil -> {:none, handle}
      {:ok, result} -> head_result(handle, result)
      {:exit, reason} -> {{:error, {:upstream_task, reason}}, %{handle | resolved: true}}
    end
  end

  @impl true
  def event(%{promise: %{task: %{ref: ref}}, resolved: false} = handle, {ref, result}) do
    Process.demonitor(ref, [:flush])
    head_result(handle, result)
  end

  def event(
        %{promise: %{task: %{ref: ref}}, resolved: false} = handle,
        {:DOWN, ref, :process, _, reason}
      ),
      do: {{:error, {:upstream_task, reason}}, %{handle | resolved: true}}

  def event(%{stream: stream} = handle, {:stream_chunk, stream, bytes, ref}) do
    if is_binary(bytes) and byte_size(bytes) <= @max_delivery + @framing_carry,
      do: {{:chunk, bytes, ref}, handle},
      else: {{:error, :upstream_delivery_limit}, handle}
  end

  def event(%{stream: stream} = handle, {:stream_trailers, stream, fields}),
    do: {{:trailers, HTTP.Headers.to_list(fields)}, handle}

  def event(%{stream: stream} = handle, {:stream_end, stream}), do: {:end, handle}

  def event(%{stream: stream} = handle, {:stream_error, stream, reason}),
    do: {{:error, reason}, handle}

  def event(handle, _), do: {:none, handle}

  defp head_result(handle, %Response{stream: stream, body: body} = response)
       when is_pid(stream) or body in [nil, ""] do
    handle = %{handle | stream: stream, resolved: true}
    {{:headers, response.status, HTTP.Headers.to_list(response.headers)}, handle}
  end

  defp head_result(handle, {:error, reason}), do: {{:error, reason}, %{handle | resolved: true}}
  defp head_result(handle, _), do: {{:error, :unstreamed_response}, %{handle | resolved: true}}

  @impl true
  def subscribe(%{stream: stream}) when is_pid(stream) do
    send(stream, {:read_chunk, self(), :ack})
    :ok
  end

  def subscribe(_), do: :ok

  @impl true
  def write_body(stream, bytes, timeout), do: Stream.chunk(stream, bytes, timeout)

  @impl true
  def finish_body(stream, trailers), do: Stream.finish(stream, trailers)

  @impl true
  def acknowledge(%{stream: stream}, ref) do
    send(stream, {:stream_chunk_ack, ref})
    :ok
  end

  @impl true
  def cleanup(handle, true), do: RequestCompletion.abort_and_await(handle.completion, 0)
  def cleanup(handle, false), do: RequestCompletion.await(handle.completion, 0)
end
