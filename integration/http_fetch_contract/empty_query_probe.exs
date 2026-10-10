# Regression for gsmlg-dev/http_fetch#64, fixed in the published 0.19.1 packages.
# Public HTTP.fetch/2 wire regression; exits nonzero when an empty query is lost.
{:ok, _} = Application.ensure_all_started(:http_fetch)

defmodule EmptyQueryProbe do
  @timeout 2_000

  def run(input) do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)
    observer = self()

    {peer, monitor} =
      spawn_monitor(fn ->
        {:ok, socket} = :gen_tcp.accept(listener, @timeout)

        try do
          request = head(socket, "")
          send(observer, {:request, self(), hd(String.split(request, "\r\n"))})

          :ok =
            :gen_tcp.send(
              socket,
              "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            )
        after
          :gen_tcp.close(socket)
        end
      end)

    try do
      raw_url = "http://127.0.0.1:#{port}/upload?"
      url = if input == :uri, do: URI.parse(raw_url), else: raw_url

      promise =
        HTTP.fetch(url,
          request_mode: :proxy,
          http_version: :http1,
          http1_reuse: false,
          redirect: :manual,
          tls_backend: :ssl,
          stream_response: true,
          decode_body: false,
          timeout: @timeout,
          telemetry: false
        )

      %HTTP.Response{status: 200} = HTTP.Promise.await(promise, @timeout)
      :ok = HTTP.RequestCompletion.abort_and_await(HTTP.Promise.completion(promise), @timeout)

      actual =
        receive do
          {:request, ^peer, line} -> line
        after
          @timeout -> raise "peer did not record request"
        end

      receive do
        {:DOWN, ^monitor, :process, ^peer, :normal} -> :ok
        {:DOWN, ^monitor, :process, ^peer, reason} -> raise "peer failed: #{inspect(reason)}"
      after
        @timeout -> raise "peer did not finish"
      end

      expected = "GET /upload? HTTP/1.1"

      IO.inspect(%{
        input: input,
        uri_query: URI.parse(raw_url).query,
        expected: expected,
        actual: actual,
        completion: :ok,
        preserved: actual == expected
      })

      actual == expected
    after
      :gen_tcp.close(listener)
      if Process.alive?(peer), do: Process.exit(peer, :kill)
    end
  end

  defp head(socket, bytes) do
    if String.ends_with?(bytes, "\r\n\r\n") do
      bytes
    else
      {:ok, byte} = :gen_tcp.recv(socket, 1, @timeout)
      head(socket, bytes <> byte)
    end
  end
end

results = Enum.map([:string, :uri], &EmptyQueryProbe.run/1)
if not Enum.all?(results), do: System.halt(1)
