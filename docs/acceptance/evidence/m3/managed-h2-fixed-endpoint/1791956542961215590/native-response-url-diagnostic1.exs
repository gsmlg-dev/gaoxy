defmodule FixedH2ResponseDiagnostic do
  def event(port, name) do
    receive do
      {^port, {:data, {:eol, bytes}}} ->
        value = JSON.decode!(bytes)
        cond do
          value["event"] == name -> value
          value["event"] == "failure" -> raise inspect(value)
          true -> event(port, name)
        end
      {^port, {:exit_status, code}} -> raise "peer exited #{code} before #{name}"
    after
      5000 -> raise "peer event deadline #{name}"
    end
  end

  def run do
    script = Path.expand("apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py")
    port = Port.open({:spawn_executable, ~c"/tmp/gaoxy-m3-h2-soak-venv/bin/python"},
      [:binary, :exit_status, {:line, 2_097_152}, {:args, [script, "--protocol", "h2c"]}])
    ready = event(port, "ready")
    origin = "http://localhost:#{ready["port"]}"
    url = :binary.copy(origin <> "/a%2Fb?")
    {:ok, policy, _} = Gaoxy.Proxy.ManagedH2Preparation.prepare_policy(%{
      protocol: :h2c, origin: origin, connect_address: {127, 0, 0, 1}, trust: nil})
    {:ok, scope} = HTTP.ManagedTransport.open(policy.open_options)
    options = [http_version: :h2c, tls_backend: :ssl, http2_profile: :native_v1,
      http2_reuse: true, redirect: :manual, request_mode: :proxy, decode_body: false,
      stream_response: true, telemetry: false, transport_scope: scope, timeout: 5000,
      connect_timeout: 5000]
    promise = HTTP.fetch(url, options)
    completion = HTTP.Promise.completion(promise)
    response = HTTP.Promise.await(promise, 5000)
    %HTTP.Response{} = response
    submitted = URI.parse(url)
    original = Gaoxy.Proxy.ManagedH2Envelope.validate_response(response, url)
    restored = Gaoxy.Proxy.ManagedH2Envelope.validate_response(%{response | url: submitted}, url)
    handle = %{promise: promise, completion: completion, stream: nil, resolved: false}
    malformed = Map.put(response, :extra, :forbidden)
    concat_url = origin <> "/a%2Fb?"
    plain = Gaoxy.Proxy.ManagedH2Client.event({handle, concat_url}, {promise.task.ref, malformed})
    copied = Gaoxy.Proxy.ManagedH2Client.event({handle, :binary.copy(concat_url)}, {promise.task.ref, malformed})
    result = %{native_response_keys: Enum.sort(Map.keys(response)),
      response_url: Map.from_struct(response.url), submitted_url: Map.from_struct(submitted),
      schema: %{status: response.status, http_version: response.http_version,
        stream_pid: is_pid(response.stream), body: if(is_pid(response.body), do: :pid, else: response.body),
        fields: length(response.headers.headers)},
      native_validation: inspect(original), restored_uri_validation: inspect(restored, limit: 10),
      concat_url_bytes: byte_size(concat_url), concat_url_backing: :binary.referenced_byte_size(concat_url),
      compact_url_backing: :binary.referenced_byte_size(:binary.copy(concat_url)),
      malformed_concat_result: inspect(elem(plain, 0)), malformed_compact_result: inspect(elem(copied, 0))}
    {:error, :invalid_response} = original
    {:ok, _} = restored
    :ok = HTTP.RequestCompletion.abort_and_await(completion, 5000)
    {:ok, receipt} = HTTP.ManagedTransport.retire(scope, mode: :abort)
    :ok = HTTP.ManagedTransport.await_retired(receipt, 5000)
    eof = event(port, "eof")
    true = Port.command(port, [JSON.encode!(%{op: "stop"}), "\n"])
    joined = event(port, "joined")
    %{"forced" => 0, "live" => 0, "failed" => false, "requests" => 1} = joined
    receive do
      {^port, {:exit_status, 0}} -> :ok
    after
      5000 -> raise "peer process join deadline"
    end
    IO.puts(JSON.encode!(Map.merge(result, %{eof: eof, joined: joined, assertions: 8, status: "PASS_DIAGNOSIS"})))
  end
end

FixedH2ResponseDiagnostic.run()
