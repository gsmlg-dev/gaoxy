# Disposable VM-wide diagnostic, not a passing retained-transport-bound gate.
System.put_env("HTTP_FETCH_PROBE_LIBRARY", "1")
Code.require_file("pooled_completion_probe.exs", __DIR__)
System.delete_env("HTTP_FETCH_PROBE_LIBRARY")

defmodule EmptyContinuationPublicProbe do
  alias HTTPFetchPublicProbe, as: Probe
  @batch_size 20_000
  @batches 4

  def sample do
    # Only collect this measurement process; never enumerate/inspect/GC owners.
    :erlang.garbage_collect()
    memory = :erlang.memory()

    %{
      total: memory[:total],
      processes_used: memory[:processes_used],
      binary: memory[:binary],
      process_count: :erlang.system_info(:process_count)
    }
  end

  def settled_sample do
    # Finite observation intervals, not a lifecycle barrier. The peer's sendall
    # receipt confirms sent bytes, not an application ACK of unfinished headers.
    samples =
      for _ <- 1..3 do
        receive do
        after
          50 -> sample()
        end
      end

    %{
      samples: samples,
      processes_used: Enum.map(samples, & &1.processes_used) |> Enum.sort() |> Enum.at(1)
    }
  end

  def run do
    Probe.start_apps()
    source = Path.expand("../../deps/http_runtime/lib/http/http2/connection_owner.ex", __DIR__)

    IO.inspect(
      %{
        source: source,
        sha256: Base.encode16(:crypto.hash(:sha256, File.read!(source)), case: :lower),
        batch_frames: @batch_size,
        batch_ceiling: @batches,
        frame_payload_bytes: 0,
        measurement: :vm_wide_only
      },
      label: "EMPTY_CONTINUATION_ENV"
    )

    Probe.with_peer("h2c", fn peer ->
      {promise, completion} = Probe.fetch(peer, "/empty-continuation")

      %{"connection" => 1, "stream" => sid, "payload_bytes" => 0} =
        Probe.event(peer.port, &(&1["event"] == "open_headers"))

      baseline = settled_sample()

      IO.inspect(%{frames: 0, payload_bytes: 0, wire_bytes: 9, memory: baseline},
        label: "EMPTY_CONTINUATION_SAMPLE"
      )

      samples =
        for batch <- 1..@batches do
          Probe.command(peer.port, %{
            "command" => "empty_batch",
            "path" => "/empty-continuation",
            "count" => @batch_size
          })

          %{
            "stream" => ^sid,
            "count" => @batch_size,
            "payload_bytes" => 0,
            "wire_bytes" => 180_000
          } = Probe.event(peer.port, &(&1["event"] == "empty_batch"))

          memory = settled_sample()

          IO.inspect(
            %{
              batch: batch,
              frames: batch * @batch_size,
              payload_bytes: 0,
              wire_bytes: 9 + batch * @batch_size * 9,
              memory: memory
            },
            label: "EMPTY_CONTINUATION_SAMPLE"
          )

          memory.processes_used
        end

      :ok = HTTP.RequestCompletion.abort_and_await(completion, 2_000)
      Probe.complete(completion)
      {:error, promise_error} = HTTP.Promise.await(promise, 2_000)
      %{"stream" => ^sid} = Probe.barrier(peer, "reset", "/empty-continuation")
      events = Probe.snapshot(peer)
      1 = Probe.accepts(events)
      [%{"path" => "/empty-continuation"}] = Probe.requests(events)
      batches = Enum.filter(events, &(&1["event"] == "empty_batch"))
      @batches = length(batches)
      80_000 = Enum.sum(Enum.map(batches, & &1["count"]))
      0 = Enum.sum(Enum.map(batches, & &1["payload_bytes"]))

      deltas =
        [baseline.processes_used | samples]
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [before, after_sample] -> after_sample - before end)

      growth = List.last(samples) - baseline.processes_used
      # Thresholds establish a conservative finite reproduction of fragment
      # metadata growth, never a total-memory cap or steady-state assertion.
      correlated = growth >= 640_000 and Enum.count(deltas, &(&1 >= 160_000)) >= 3
      verdict = if correlated, do: :reproduced, else: :inconclusive

      IO.inspect(
        %{
          verdict: verdict,
          frames: 80_000,
          compressed_payload_bytes: 0,
          processes_used_growth: growth,
          per_batch_deltas: deltas,
          promise_error: promise_error,
          public_cleanup: :ok,
          reset_observed: true,
          after_cleanup: settled_sample(),
          limit:
            "peer send receipts are not header application acknowledgements; finite diagnostic only"
        },
        label: "EMPTY_CONTINUATION_RESULT"
      )
    end)

    IO.puts(
      "EMPTY_CONTINUATION_DIAGNOSTIC_FINISHED peer_shutdown=confirmed; bound gate remains unqualified"
    )
  end
end

EmptyContinuationPublicProbe.run()
