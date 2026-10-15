defmodule Gaoxy.Proxy.ManagedH2Client do
  @moduledoc false
  @behaviour Gaoxy.Proxy.UpstreamClient

  alias Gaoxy.Proxy.{ManagedH2Envelope, ManagedH2Reservation}
  alias Gaoxy.Proxy.UpstreamTransports.Options
  alias HTTP.{Promise, RequestCompletion, Stream}

  @signed_min -9_223_372_036_854_775_808
  @signed_max 9_223_372_036_854_775_807
  @data_cap 1_048_576
  @upload_cap 65_536
  @errors [
    :invalid_request,
    :invalid_policy,
    :invalid_response,
    :upstream_failure,
    :upstream_task,
    :upstream_delivery_limit,
    :upstream_delivery_overlap,
    :upstream_trailer_limit,
    :timeout,
    :request_timeout,
    :unavailable,
    :cancelled,
    :cleanup_pending,
    :cleanup_unconfirmed,
    :invalid_resource,
    :invalid_resource_pin,
    :invalid_transport_endpoint,
    :unauthorized,
    :retiring,
    :resource_unavailable
  ]

  @impl true
  def host_supported?, do: Gaoxy.Proxy.HTTPFetchClient.host_supported?()

  @impl true
  def reservation_bytes(fields, url_bytes, chunk_bytes),
    do: ManagedH2Reservation.reservation_bytes(fields, url_bytes, chunk_bytes)

  @impl true
  def open(options) do
    with :ok <- opening_shape(options),
         {:ok, total, opening} <- remaining(options),
         {:ok, upload} <- create_upload(options.request.body_mode) do
      open_prepared(options, upload, total, opening)
    else
      {:error, reason} -> {:error, normalize(reason, :invalid_request)}
    end
  end

  @impl true
  def completion(handle) do
    if valid_handle?(handle), do: handle.completion, else: nil
  end

  @impl true
  def await_completion(completion, abort?) when is_boolean(abort?) do
    if completion_shell?(completion) do
      result =
        if abort?,
          do: RequestCompletion.abort_and_await(completion, 0),
          else: RequestCompletion.await(completion, 0)

      cleanup_result(result)
    else
      {:error, :cleanup_unconfirmed}
    end
  rescue
    _ -> {:error, :cleanup_unconfirmed}
  catch
    _, _ -> {:error, :cleanup_unconfirmed}
  end

  def await_completion(_, _), do: {:error, :cleanup_unconfirmed}

  @impl true
  def cleanup(handle, abort?) when is_boolean(abort?) do
    if valid_handle?(handle),
      do: await_completion(handle.completion, abort?),
      else: {:error, :cleanup_unconfirmed}
  end

  def cleanup(_, _), do: {:error, :cleanup_unconfirmed}

  @impl true
  def poll_headers(context) do
    with {:ok, handle, url} <- context(context) do
      if handle.resolved do
        {:none, handle}
      else
        ref = handle.promise.task.ref
        pid = handle.promise.task.pid

        # These are the public Task result/monitor shapes. Match both identities
        # before accepting DOWN, without retaining arbitrary task diagnostics.
        receive do
          {^ref, result} ->
            Process.demonitor(ref, [:flush])
            head_result(handle, url, result)

          {:DOWN, ^ref, :process, ^pid, _reason} ->
            {{:error, :upstream_task}, %{handle | resolved: true}}
        after
          0 -> {:none, handle}
        end
      end
    else
      _ -> invalid_context()
    end
  end

  @impl true
  def event(context, message) do
    with {:ok, handle, url} <- context(context) do
      public_event(handle, url, message)
    else
      _ -> invalid_context()
    end
  end

  @impl true
  def subscribe(handle) do
    if valid_handle?(handle) and is_pid(handle.stream),
      do: send(handle.stream, {:read_chunk, self(), :ack})

    :ok
  end

  @impl true
  def acknowledge(handle, ref) do
    if valid_handle?(handle) and is_pid(handle.stream) and is_reference(ref) and
         scalar_bound?(ref),
       do: send(handle.stream, {:stream_chunk_ack, ref})

    :ok
  end

  @impl true
  def write_body(pid, bytes, timeout)
      when is_pid(pid) and is_binary(bytes) and is_integer(timeout) and timeout in 1..86_400_000 do
    if bounded_binary?(bytes, @upload_cap) do
      case Stream.chunk(pid, :binary.copy(bytes), timeout) do
        :ok -> :ok
        {:error, reason} -> {:error, normalize(reason, :upstream_failure)}
        _ -> {:error, :upstream_failure}
      end
    else
      {:error, :invalid_request}
    end
  rescue
    _ -> {:error, :upstream_failure}
  catch
    _, _ -> {:error, :upstream_failure}
  end

  def write_body(_, _, _), do: {:error, :invalid_request}

  @impl true
  def finish_body(pid, fields) when is_pid(pid) do
    with :ok <- trailer_fields(fields) do
      case Stream.finish(pid, copy_pairs(fields)) do
        :ok -> :ok
        _ -> {:error, :upstream_trailer_limit}
      end
    end
  rescue
    _ -> {:error, :upstream_trailer_limit}
  catch
    _, _ -> {:error, :upstream_trailer_limit}
  end

  def finish_body(_, _), do: {:error, :invalid_request}

  defp opening_shape(
         %{
           request: request,
           managed_transport: client,
           timeout: timeout,
           opening_timeout: opening,
           write_timeout: write,
           deadline: deadline,
           opening_deadline: opening_deadline
         } = options
       )
       when map_size(options) == 7 and is_integer(timeout) and timeout in 1..86_400_000 and
              is_integer(opening) and opening in 1..86_400_000 and is_integer(write) and
              write in 1..86_400_000 and
              is_integer(deadline) and deadline in @signed_min..@signed_max and
              is_integer(opening_deadline) and opening_deadline in @signed_min..@signed_max and
              opening_deadline <= deadline do
    with :ok <- ManagedH2Envelope.validate_request(request),
         :ok <- ManagedH2Envelope.validate_checked_client(client, request.protocol),
         request_uri = URI.parse(request.url),
         policy_uri = URI.parse(client.policy.origin),
         true <- authority(request_uri) == authority(policy_uri) do
      :ok
    else
      _ -> {:error, :invalid_request}
    end
  end

  defp opening_shape(_), do: {:error, :invalid_request}

  defp remaining(options) do
    now = System.monotonic_time(:millisecond)
    total = options.deadline - now
    opening = options.opening_deadline - now

    cond do
      now not in @signed_min..@signed_max or total not in @signed_min..@signed_max or
          opening not in @signed_min..@signed_max ->
        {:error, :invalid_request}

      total <= 0 ->
        {:error, :request_timeout}

      opening <= 0 ->
        {:error, :timeout}

      true ->
        {:ok, min(total, options.timeout), min(opening, min(total, options.opening_timeout))}
    end
  end

  defp create_upload(mode) when mode in [:none, {:length, 0}], do: {:ok, nil}

  defp create_upload(_mode) do
    case Stream.start_link(0) do
      {:ok, pid} ->
        Process.unlink(pid)
        {:ok, pid}

      _ ->
        {:error, :unavailable}
    end
  rescue
    _ -> {:error, :unavailable}
  catch
    _, _ -> {:error, :unavailable}
  end

  defp open_prepared(options, upload, total, opening) do
    envelope = options.request

    source = %{
      url: envelope.url,
      method: envelope.method,
      fields: envelope.fields,
      body: upload,
      trailers: [],
      timeout: total,
      connect_timeout: opening
    }

    with {:ok, request, accounting} <-
           Options.prepare_request(options.managed_transport.policy, source),
         true <-
           accounting.preparation.effective_field_count <= envelope.request_limits.max_headers and
             accounting.preparation.effective_field_bytes <=
               envelope.request_limits.max_header_bytes,
         true <- complete_preparation?(request, accounting) do
      # Nil-body preflight never supplied these fields. Actual upload PID and
      # raw source Content-Length are prepared together before public Fetch.
      fetch_options =
        options.managed_transport.fetch_options ++
          [
            transport_scope: options.managed_transport.transport_scope,
            method: request.method,
            headers: request.fields,
            body: request.body,
            timeout: request.timeout,
            connect_timeout: request.connect_timeout
          ]

      fetch_options = if upload, do: fetch_options ++ [duplex: :half], else: fetch_options
      fetch_open(request.url, fetch_options, upload, options)
    else
      _ -> open_failed(upload, options, :invalid_request)
    end
  end

  defp complete_preparation?(request, accounting) do
    # Both values came from the accepted closed, finite preparer. Its complete
    # return, including the manifest, occupies the canonical request slot once.
    :erlang.external_size(request) <= 201_753 and
      :erlang.external_size(accounting.preparation) <= 3072 and
      :erlang.external_size(accounting) <= 3456 and
      :erlang.external_size({:ok, request, accounting}) <= 205_337
  end

  defp fetch_open(url, fetch_options, upload, options) do
    promise = HTTP.fetch(url, fetch_options)
    original = Promise.completion(promise)
    handle = %{promise: promise, completion: original, stream: nil, resolved: false}

    if valid_handle?(handle) do
      {:ok, handle, upload}
    else
      # A malformed public return cannot be accepted or replaced with a made-up
      # completion. Preserve negative cleanup evidence if its barrier is lost.
      if completion_shell?(original) do
        _ = RequestCompletion.abort_and_await(original, cleanup_timeout(options))
      end

      open_failed(upload, options, :cleanup_unconfirmed)
    end
  rescue
    _ -> open_failed(upload, options, :upstream_failure)
  catch
    _, _ -> open_failed(upload, options, :upstream_failure)
  end

  defp open_failed(nil, _options, reason), do: {:error, reason}

  defp open_failed(upload, options, reason) do
    monitor = Process.monitor(upload)
    Process.exit(upload, :kill)

    receive do
      {:DOWN, ^monitor, :process, ^upload, _} -> {:error, reason}
    after
      cleanup_timeout(options) ->
        Process.demonitor(monitor, [:flush])
        {:error, :cleanup_unconfirmed}
    end
  end

  defp cleanup_timeout(options) do
    remaining = options.deadline - System.monotonic_time(:millisecond)

    if remaining in @signed_min..@signed_max,
      do: max(0, min(remaining, options.write_timeout)),
      else: 0
  end

  defp context({handle, url}) do
    if valid_handle?(handle) and context_url?(handle, url),
      do: {:ok, handle, url},
      else: {:error, :invalid_request}
  end

  defp context(_), do: {:error, :invalid_request}
  defp context_url?(%{resolved: true}, nil), do: true

  defp context_url?(%{resolved: false}, url) when is_binary(url) do
    # Validate before parsing; this transient context owns no copied URL or
    # extra handle key. The full Response provenance is checked at extraction.
    with true <-
           byte_size(url) in 1..65_536 and
             :binary.referenced_byte_size(url) == byte_size(url),
         true <- url_text?(url),
         %URI{scheme: scheme, userinfo: nil, host: host, port: port, fragment: nil} = uri <-
           URI.parse(url),
         true <-
           scheme in ["http", "https"] and is_binary(host) and byte_size(host) in 1..253 and
             is_integer(port) and port in 1..65_535,
         true <- authority_valid?(uri.authority, host) do
      uri.path in [nil, ""] or String.starts_with?(uri.path, "/")
    else
      _ -> false
    end
  rescue
    ArgumentError -> false
  end

  defp context_url?(_, _), do: false

  defp authority_valid?(authority, host) when is_binary(authority) do
    prefix = if String.contains?(host, ":"), do: "[" <> host <> "]", else: host
    size = byte_size(prefix)

    case authority do
      ^prefix -> true
      <<^prefix::binary-size(size), ?:, port::binary>> -> port != "" and digits?(port)
      _ -> false
    end
  end

  defp authority_valid?(_, _), do: false
  defp digits?(<<>>), do: true
  defp digits?(<<char, rest::binary>>) when char in ?0..?9, do: digits?(rest)
  defp digits?(_), do: false
  defp url_text?(<<>>), do: true
  defp url_text?(<<?%, a, b, rest::binary>>), do: hex?(a) and hex?(b) and url_text?(rest)
  defp url_text?(<<?%, _::binary>>), do: false

  defp url_text?(<<char, rest::binary>>) when char in 33..126 and char not in [?#, ?\\],
    do: url_text?(rest)

  defp url_text?(_), do: false
  defp hex?(char), do: char in ?0..?9 or char in ?a..?f or char in ?A..?F

  defp public_event(
         %{promise: %{task: %{ref: ref}}, resolved: false} = handle,
         url,
         {ref, result}
       ) do
    Process.demonitor(ref, [:flush])
    head_result(handle, url, result)
  end

  defp public_event(
         %{promise: %{task: %{ref: ref, pid: pid}}, resolved: false} = handle,
         _url,
         {:DOWN, ref, :process, pid, _reason}
       ),
       do: {{:error, :upstream_task}, %{handle | resolved: true}}

  defp public_event(%{stream: stream} = handle, _url, {:stream_chunk, stream, bytes, ref})
       when is_pid(stream) do
    if is_reference(ref) and scalar_bound?(ref) and bounded_binary?(bytes, @data_cap),
      do: {{:chunk, :binary.copy(bytes), ref}, handle},
      else: {{:error, :upstream_delivery_limit}, handle}
  end

  defp public_event(%{stream: stream} = handle, _url, {:stream_trailers, stream, fields})
       when is_pid(stream) do
    case fields do
      %HTTP.Headers{headers: pairs} when map_size(fields) == 2 ->
        case trailer_fields(pairs) do
          :ok -> {{:trailers, copy_pairs(pairs)}, handle}
          _ -> {{:error, :upstream_trailer_limit}, handle}
        end

      _ ->
        {{:error, :upstream_trailer_limit}, handle}
    end
  end

  defp public_event(%{stream: stream} = handle, _url, {:stream_end, stream})
       when is_pid(stream),
       do: {:end, handle}

  defp public_event(%{stream: stream} = handle, _url, {:stream_error, stream, reason})
       when is_pid(stream),
       do: {{:error, normalize(reason, :upstream_failure)}, handle}

  defp public_event(handle, _, _), do: {:none, handle}

  defp head_result(handle, _url, {:error, reason}),
    do: {{:error, normalize(reason, :upstream_failure)}, %{handle | resolved: true}}

  defp head_result(handle, url, response) do
    case ManagedH2Envelope.validate_response(response, url) do
      {:ok, %{status: status, fields: fields, stream: stream}} ->
        {{:headers, status, fields}, %{handle | resolved: true, stream: stream}}

      _ ->
        {{:error, :invalid_response}, %{handle | resolved: true}}
    end
  end

  defp valid_handle?(
         %{
           promise:
             %Promise{
               task: %Task{owner: owner, pid: pid, ref: ref, mfa: mfa} = task,
               completion: original
             } = promise,
           completion: completion,
           stream: stream,
           resolved: resolved
         } = handle
       )
       when map_size(handle) == 4 and map_size(promise) == 3 and map_size(task) == 5 and
              is_pid(owner) and is_pid(pid) and is_reference(ref) and is_boolean(resolved) do
    if mfa in [nil, {:erlang, :apply, 2}] and (stream == nil or is_pid(stream)) and
         completion_shell?(completion) and original === completion and
         scalar_bound?(owner) and scalar_bound?(pid) and scalar_bound?(ref) do
      marker = {:opaque, RequestCompletion}
      projection = %{handle | completion: marker, promise: %{promise | completion: marker}}
      :erlang.external_size(projection) <= 4096
    else
      false
    end
  end

  defp valid_handle?(_), do: false

  defp completion_shell?(%RequestCompletion{} = completion),
    do:
      map_size(completion) == 4 and
        Enum.sort(Map.keys(completion)) == Enum.sort(Map.keys(%RequestCompletion{}))

  defp completion_shell?(_), do: false

  defp invalid_context,
    do:
      {{:error, :invalid_request}, %{promise: nil, completion: nil, stream: nil, resolved: true}}

  defp trailer_fields(fields) do
    with :ok <- pairs(fields, 0, 0, 0),
         true <- :erlang.external_size(fields) <= 67_079 do
      :ok
    else
      _ -> {:error, :upstream_trailer_limit}
    end
  end

  defp pairs([], _, _, _), do: :ok

  defp pairs([{name, value} | rest], count, logical, backing)
       when count < 128 and is_binary(name) and is_binary(value) do
    logical = logical + byte_size(name) + byte_size(value)
    backing = backing + :binary.referenced_byte_size(name) + :binary.referenced_byte_size(value)

    if logical <= 65_536 and backing <= 65_536 and token?(name) and field_value?(value),
      do: pairs(rest, count + 1, logical, backing),
      else: {:error, :upstream_trailer_limit}
  end

  defp pairs(_, _, _, _), do: {:error, :upstream_trailer_limit}

  defp token?(<<>>), do: false
  defp token?(value), do: token_bytes?(value)
  defp token_bytes?(<<>>), do: true

  defp token_bytes?(<<char, rest::binary>>),
    do:
      (char in ?0..?9 or char in ?A..?Z or char in ?a..?z or
         char in ~c"!#$%&'*+-.^_`|~") and token_bytes?(rest)

  defp field_value?(<<>>), do: true

  defp field_value?(<<char, rest::binary>>) when char == 9 or (char >= 32 and char != 127),
    do: field_value?(rest)

  defp field_value?(_), do: false

  defp bounded_binary?(bytes, maximum) when is_binary(bytes),
    do: byte_size(bytes) <= maximum and :binary.referenced_byte_size(bytes) <= maximum

  defp bounded_binary?(_, _), do: false
  defp scalar_bound?(scalar), do: :erlang.external_size(scalar) <= 2048

  defp copy_pairs(fields),
    do: Enum.map(fields, fn {name, value} -> {:binary.copy(name), :binary.copy(value)} end)

  defp authority(uri), do: {uri.scheme, String.downcase(uri.host), uri.port}
  defp cleanup_result(:ok), do: :ok

  defp cleanup_result({:error, reason}) when reason in [:cleanup_pending, :cleanup_unconfirmed],
    do: {:error, reason}

  defp cleanup_result(_), do: {:error, :cleanup_unconfirmed}
  defp normalize(reason, _fallback) when reason in @errors, do: reason

  defp normalize({:transport_scope_capacity, kind}, _fallback)
       when kind in [:requests, :connections],
       do: :unavailable

  defp normalize(_reason, fallback), do: fallback
end
