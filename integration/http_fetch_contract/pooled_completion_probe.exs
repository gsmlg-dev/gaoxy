# Public option-gate probe; this is blocker evidence, not pool/H2 wire acceptance.
{:ok, _} = Application.ensure_all_started(:http_fetch)

defmodule PooledCompletionProbe do
  @timeout 1_000

  def run(version, reuse, reason) do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)
    scheme = if version == :http2, do: "https", else: "http"

    try do
      # A passive listener never sends an HTTP response; the finite request
      # deadline lets the public Promise settle without private cancellation.
      promise =
        HTTP.fetch("#{scheme}://127.0.0.1:#{port}/completion-probe",
          http_version: version,
          http1_reuse: reuse,
          redirect: :manual,
          tls_backend: :ssl,
          stream_response: true,
          decode_body: false,
          timeout: @timeout,
          connect_timeout: @timeout,
          telemetry: false
        )

      completion = HTTP.Promise.completion(promise)
      expected = {:error, {:unsupported_completion, reason}}
      awaited = HTTP.RequestCompletion.await(completion, 0)
      aborted = HTTP.RequestCompletion.abort_and_await(completion, 0)
      ^expected = awaited
      ^expected = aborted
      {:error, _} = result = HTTP.Promise.await(promise, @timeout + 2_000)

      IO.inspect(%{
        http_version: version,
        http1_reuse: reuse,
        await: awaited,
        abort_and_await: aborted,
        promise_result: result,
        blocker_reproduced: true
      })
    after
      :gen_tcp.close(listener)
    end
  end
end

IO.inspect(%{
  http_fetch_version: Application.spec(:http_fetch, :vsn),
  elixir_version: System.version(),
  otp_release: System.otp_release(),
  erts_version: :erlang.system_info(:version)
})

PooledCompletionProbe.run(:http1, true, :http1_reuse)
PooledCompletionProbe.run(:http2, false, :http_version)
