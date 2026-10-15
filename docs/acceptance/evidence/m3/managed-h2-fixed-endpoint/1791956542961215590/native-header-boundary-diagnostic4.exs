defmodule FixedH2NormalRetirementDiagnostic do
  def event(port, names) do
    receive do
      {^port, {:data, {:eol, bytes}}} ->
        IO.puts("PEER_NORMAL_DIAGNOSTIC " <> bytes)
        value = JSON.decode!(bytes)
        cond do
          value["event"] in names -> value
          value["event"] == "failure" -> raise inspect(value)
          true -> event(port, names)
        end
      {^port, {:exit_status, code}} -> raise "peer exited #{code} before #{inspect(names)}"
    after
      5000 -> raise "peer event deadline #{inspect(names)}"
    end
  end

  def read(stream, deadline, chunks \\ [], total \\ 0) do
    receive do
      {:stream_chunk, ^stream, bytes, ref} when is_binary(bytes) and is_reference(ref) ->
        true = total + byte_size(bytes) <= byte_size("managed-h2-stream:") + 65_536
        send(stream, {:stream_chunk_ack, ref})
        read(stream, deadline, [bytes | chunks], total + byte_size(bytes))
      {:stream_end, ^stream} -> chunks |> Enum.reverse() |> IO.iodata_to_binary()
      {:stream_error, ^stream, reason} -> raise "public stream failed #{inspect(reason)}"
    after
      max(0, deadline - System.monotonic_time(:millisecond)) -> raise "public body deadline"
    end
  end

  def run(protocol) do
    script = Path.expand("apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py")
    port = Port.open({:spawn_executable, ~c"/tmp/gaoxy-m3-h2-soak-venv/bin/python"},
      [:binary, :exit_status, {:line, 2_097_152}, {:args, [script, "--protocol", if(protocol == :http2, do: "tls", else: "h2c")]}])
    ready = event(port, ["ready"])
    origin = if(protocol == :http2, do: "https", else: "http") <> "://localhost:#{ready["port"]}"
    trust = if protocol == :http2 do
      for {:Certificate, der, :not_encrypted} <- :public_key.pem_decode(File.read!(ready["ca"])), do: der
    end
    {:ok, policy, _} = Gaoxy.Proxy.ManagedH2Preparation.prepare_policy(%{
      protocol: protocol, origin: origin, connect_address: {127, 0, 0, 1}, trust: trust})
    {:ok, scope} = HTTP.ManagedTransport.open(policy.open_options)
    options = [http_version: protocol, tls_backend: :ssl, http2_profile: :native_v1,
      http2_reuse: true, redirect: :manual, request_mode: :proxy, decode_body: false,
      stream_response: true, telemetry: false, transport_scope: scope, timeout: 5000,
      connect_timeout: 5000]
    for {target, expected} <- [{"/a%2Fb?", "/a%2Fb?"}, {"/empty?", "/empty?"},
                             {"/stream", "managed-h2-stream:" <> :binary.copy("s", 65_536)}] do
      url = :binary.copy(origin <> target)
      promise = HTTP.fetch(url, options)
      original = HTTP.Promise.completion(promise)
      %HTTP.Response{status: 200, stream: stream} = response = HTTP.Promise.await(promise, 5000)
      {:ok, _} = Gaoxy.Proxy.ManagedH2Envelope.validate_response(response, url)
      send(stream, {:read_chunk, self(), :ack})
      ^expected = read(stream, System.monotonic_time(:millisecond) + 5000)
      :ok = HTTP.RequestCompletion.await(original, 5000)
      IO.puts("NORMAL_COMPLETION " <> JSON.encode!(%{protocol: protocol, target: target,
        body_bytes: byte_size(expected), completion: "ok"}))
    end
    {:ok, snapshot} = HTTP.ManagedTransport.snapshot(scope, 5000)
    IO.puts("PUBLIC_IDLE_SNAPSHOT " <> JSON.encode!(snapshot))
    {:ok, receipt} = HTTP.ManagedTransport.retire(scope, mode: :graceful)
    :ok = HTTP.ManagedTransport.await_retired(receipt, 5000)
    physical = event(port, ["eof", "connection_reset"])
    true = Port.command(port, [JSON.encode!(%{op: "stop"}), "\n"])
    joined = event(port, ["joined"])
    %{"forced" => 0, "live" => 0, "failed" => false, "requests" => 3} = joined
    receive do
      {^port, {:exit_status, 0}} -> :ok
    after
      5000 -> raise "peer process join deadline"
    end
    IO.puts("NORMAL_RETIREMENT_DIAGNOSIS " <> JSON.encode!(%{status: "PASS_DIAGNOSIS_ONLY",
      protocol: protocol, mode: "graceful", requests: 3, original_completions: 3,
      public_retirement: "ok", physical_close: physical, joined: joined}))
  end
end


defmodule FixedH2HeaderBoundaryDiagnostic do
  alias FixedH2NormalRetirementDiagnostic, as: Peer
  def run(count) do
    script = Path.expand("apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py")
    port = Port.open({:spawn_executable, ~c"/tmp/gaoxy-m3-h2-soak-venv/bin/python"},
      [:binary, :exit_status, {:line, 2_097_152}, {:args, [script, "--protocol", "h2c", "--manual"]}])
    ready = Peer.event(port, ["ready"])
    origin = "http://localhost:#{ready["port"]}"
    url = :binary.copy(origin <> "/head-boundary")
    {:ok, policy, _} = Gaoxy.Proxy.ManagedH2Preparation.prepare_policy(%{
      protocol: :h2c, origin: origin, connect_address: {127,0,0,1}, trust: nil})
    {:ok, scope} = HTTP.ManagedTransport.open(policy.open_options)
    options = [http_version: :h2c, tls_backend: :ssl, http2_profile: :native_v1,
      http2_reuse: true, redirect: :manual, request_mode: :proxy, decode_body: false,
      stream_response: true, telemetry: false, transport_scope: scope, timeout: 5000,
      connect_timeout: 5000]
    promise = HTTP.fetch(url, options)
    completion = HTTP.Promise.completion(promise)
    request = Peer.event(port, ["request"])
    true = Port.command(port, [JSON.encode!(%{op: "respond", connection: request["connection"],
      stream: request["stream"], status: 200, fields: List.duplicate(["x-check", "x"], count), ended: true}), "\n"])
    result = HTTP.Promise.await(promise, 5000)
    observed = case result do
      %HTTP.Response{} = response ->
        %{kind: "response", status: response.status, regular_fields: length(response.headers.headers),
          adapter: inspect(Gaoxy.Proxy.ManagedH2Envelope.validate_response(response, url), limit: 4)}
      {:error, reason} -> %{kind: "public_error", reason: inspect(reason, limit: 10)}
    end
    IO.puts("HEADER_BOUNDARY_DIAGNOSTIC " <> JSON.encode!(%{regular_input_fields: count,
      total_input_fields: count+1, observed: observed}))
    if count == 255 do
      %HTTP.Response{status: 200} = result
      255 = length(result.headers.headers)
      {:ok, _} = Gaoxy.Proxy.ManagedH2Envelope.validate_response(result, url)
    else
      {:error, _} = result
    end
    :ok = HTTP.RequestCompletion.abort_and_await(completion, 5000)
    {:ok, receipt} = HTTP.ManagedTransport.retire(scope, mode: :graceful)
    :ok = HTTP.ManagedTransport.await_retired(receipt, 5000)
    physical = Peer.event(port, ["eof", "connection_reset"])
    true = Port.command(port, [JSON.encode!(%{op: "stop"}), "\n"])
    joined = Peer.event(port, ["joined"])
    %{"forced" => 0, "live" => 0, "failed" => false, "requests" => 1} = joined
    receive do
      {^port, {:exit_status, 0}} -> :ok
    after 5000 -> raise "boundary peer join deadline" end
    IO.puts("HEADER_BOUNDARY_OUTCOME " <> JSON.encode!(%{status: "PASS_DIAGNOSIS_ONLY",
      regular_fields: count, observed: observed, physical_close: physical, joined: joined}))
  end
end
for count <- [255, 256, 257], do: FixedH2HeaderBoundaryDiagnostic.run(count)
