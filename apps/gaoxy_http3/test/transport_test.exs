defmodule Gaoxy.HTTP.HTTP3.TransportTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Exchange, Request, Response}
  alias Gaoxy.HTTP.HTTP3.{Operations, Options, Transport}

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: {:ok, exchange}
  end

  defp exchange(responses \\ [], mode \\ :reply) do
    {:ok, spec} =
      Options.normalize(endpoint: {Endpoint, nil}, tls: %{certfile: "cert", keyfile: "key"})

    gate =
      start_supervised!({Admission, {spec.limits, %{instance: make_ref(), service: :transport}}},
        id: make_ref()
      )

    {:ok, lease} = Admission.acquire(gate, 0)
    deadline = Lifecycle.deadline(2_000)
    :ok = Admission.begin_request(gate, lease, 0, deadline)
    worker = self()

    owner =
      spawn(fn ->
        table = Operations.new()
        key = make_ref()
        token = make_ref()
        :ok = Operations.register(table, key, token, deadline, spec.handler_options.http_limits)
        :ok = Operations.bind(table, key, token, worker)
        send(worker, {:owner_ready, self(), table, key, token})

        receive do
          :activate ->
            :ok = Operations.activate(table, key, token, worker)
            send(worker, {:activated, self()})
            owner_loop(table, key, token, worker, responses, mode)
        end
      end)

    on_exit(fn -> if Process.alive?(owner), do: Process.exit(owner, :kill) end)
    assert_receive {:owner_ready, ^owner, table, key, token}
    assert :ok = Operations.ready(table, key, token, lease)
    send(owner, :activate)
    assert_receive {:activated, ^owner}

    exchange = %Exchange{
      request: %Request{method: "GET", path: "/", version: :"HTTP/3", head_bytes: 0},
      gate: gate,
      lease: lease,
      deadline: deadline,
      limits: spec.handler_options.http_limits,
      body: %{phase: :data, trailers: [], trailer_bytes: 0, total: 0},
      buffer: "",
      transport: Transport,
      transport_state: {owner, table, key, token},
      secure: true,
      peer: {{127, 0, 0, 1}, 12_345},
      local: {{127, 0, 0, 1}, 443}
    }

    {exchange, owner}
  end

  defp owner_loop(table, key, token, worker, responses, mode) do
    receive do
      :stop -> :ok
    after
      1 ->
        case Operations.claim(table, key, token) do
          {:ok, ^worker, ref, operation, deadline} ->
            send(worker, {:operation, self(), operation, deadline})

            if mode == :late_notification do
              :erlang.suspend_process(worker)

              try do
                :ok = Operations.reply(table, key, token, ref, :ok)

                receive do
                after
                  Lifecycle.remaining(deadline) + 1 -> :ok
                end
              after
                :erlang.resume_process(worker)
              end

              owner_loop(table, key, token, worker, responses, :reply)
            else
              if mode == :hold do
                owner_loop(table, key, token, worker, responses, mode)
              else
                {result, remaining} =
                  case {operation, responses} do
                    {{:read, _, _}, [next | tail]} -> {next, tail}
                    {{:read, _, _}, []} -> {:pending, []}
                    {{:poll, _}, []} -> {:pending, []}
                    _ -> {:ok, responses}
                  end

                _ = Operations.reply(table, key, token, ref, result)
                owner_loop(table, key, token, worker, remaining, mode)
              end
            end

          _ ->
            owner_loop(table, key, token, worker, responses, mode)
        end
    end
  end

  test "complete iodata responses traverse bounded semantic operations" do
    {exchange, owner} = exchange()
    x = :binary.copy("x", 8_192)
    y = :binary.copy("y", 8_192)
    z = :binary.copy("z", 8_192)
    assert {:ok, %{response: :sent}} = Response.send_resp(exchange, 200, [], [x, [y, z]])
    assert_receive {:operation, ^owner, {:head, 200, [{"content-length", "24576"}], false}, _}
    assert_receive {:operation, ^owner, {:data, first, false}, _}
    assert first == x <> y
    assert_receive {:operation, ^owner, {:data, ^z, true}, _}
    assert Admission.status(exchange.gate).retained_bytes == Exchange.retained_bytes(exchange)
  end

  test "HEAD and bodyless statuses never enqueue DATA" do
    for {method, status, headers, expected} <- [
          {"HEAD", 200, [], [{"content-length", "4"}]},
          {"GET", 204, [{"content-length", "99"}], []},
          {"GET", 205, [], [{"content-length", "0"}]},
          {"GET", 304, [{"content-length", "99"}], [{"content-length", "99"}]}
        ] do
      {exchange, owner} = exchange()
      exchange = %{exchange | request: %{exchange.request | method: method}}
      assert {:ok, %{response: :sent}} = Response.send_resp(exchange, status, headers, "body")
      assert_receive {:operation, ^owner, {:head, ^status, ^expected, true}, _}
      refute_received {:operation, ^owner, {:data, _, _}, _}
    end
  end

  test "streamed trailers and informational responses preserve facade ordering" do
    {exchange, owner} = exchange()
    assert :ok = Response.inform(exchange, 103, [{"link", "</asset>"}])
    assert_receive {:operation, ^owner, {:head, 103, [{"link", "</asset>"}], false}, _}
    assert {:ok, exchange} = Response.send_chunked(exchange, 200, [{"trailer", "x-end"}])
    assert {:ok, exchange} = Response.chunk(exchange, "piece")
    assert {:ok, %{response: :sent}} = Response.finish(exchange, [{"x-end", "done"}])
    assert_receive {:operation, ^owner, {:head, 200, [{"trailer", "x-end"}], false}, _}
    assert_receive {:operation, ^owner, {:data, "piece", false}, _}
    assert_receive {:operation, ^owner, {:trailers, [{"x-end", "done"}]}, _}
  end

  test "fixed response length rejects overflow and incomplete finish" do
    {exchange, owner} = exchange()
    assert {:ok, exchange} = Response.send_chunked(exchange, 200, [{"content-length", "3"}])
    assert {:error, :content_length_exceeded} = Response.chunk(exchange, "four")
    assert {:error, :content_length_mismatch} = Response.finish(exchange)
    assert_receive {:operation, ^owner, {:head, 200, [{"content-length", "3"}], false}, _}
    refute_received {:operation, ^owner, {:data, _, _}, _}
  end

  @tag :tmp_dir
  test "file ranges use admitted chunks and one terminal operation", %{tmp_dir: directory} do
    path = Path.join(directory, "body")
    File.write!(path, "0123456789")
    {exchange, owner} = exchange()
    assert {:ok, %{response: :sent}} = Response.send_file(exchange, 200, [], path, 2, 4)
    assert_receive {:operation, ^owner, {:head, 200, [{"content-length", "4"}], false}, _}
    assert_receive {:operation, ^owner, {:data, "2345", true}, _}
    assert Admission.status(exchange.gate).retained_bytes == Exchange.retained_bytes(exchange)
  end

  test "pending then streamed reads retain state, trailers and one Continue" do
    responses = [:pending, {:more, "ab", false, []}, {:ok, "cd", true, [{"x-end", "done"}]}]
    {exchange, owner} = exchange(responses)
    exchange = %{exchange | request: %{exchange.request | expect_continue: true}}
    assert {:pending, exchange} = Exchange.read_body_step(exchange, 2, 100)
    assert exchange.expect_sent
    assert {:more, "ab", exchange} = Exchange.read_body_step(exchange, 2, 100)
    assert {:ok, "cd", exchange} = Exchange.read_body_step(exchange, 2, 100)
    assert Exchange.body_complete?(exchange)
    assert Exchange.request_trailers(exchange) == [{"x-end", "done"}]
    assert exchange.body.total == 4
    assert_receive {:operation, ^owner, {:head, 100, [], false}, _}
    assert_receive {:operation, ^owner, {:read, 2, _}, _}
    assert_receive {:operation, ^owner, {:read, 2, _}, _}
    assert_receive {:operation, ^owner, {:read, 2, _}, _}
    refute_received {:operation, ^owner, {:head, 100, [], false}, _}
    assert Admission.status(exchange.gate).retained_bytes == Exchange.retained_bytes(exchange)
  end

  test "zero waits do not leave destructive operations after returning pending" do
    {exchange, owner} = exchange()
    assert {:pending, ^exchange} = Exchange.read_body_step(exchange, 1, 0)
    assert {:pending, ^exchange} = Exchange.poll_connection(exchange, 0)
    refute_received {:operation, ^owner, _, _}
    assert {:ok, _} = Response.send_resp(exchange, 200, [], "later")
  end

  test "zero-wait polling rejects stale tokens, workers and table owners" do
    {exchange, owner} = exchange()
    {^owner, table, key, token} = exchange.transport_state

    for state <- [
          {owner, table, key, make_ref()},
          {owner, table, make_ref(), token},
          {self(), table, key, token}
        ] do
      stale = %{exchange | transport_state: state}
      assert {:error, :closed, ^stale} = Exchange.poll_connection(stale, 0)
    end

    task = Task.async(fn -> Exchange.poll_connection(exchange, 0) end)
    assert {:error, :closed, ^exchange} = Task.await(task, 1_000)
    assert {:ok, %{status: :idle}} = Operations.status(table, key, token)
    refute_received {:operation, ^owner, _, _}
  end

  test "zero-wait polling rejects finished slots without submitting an operation" do
    {exchange, owner} = exchange()
    {^owner, table, key, token} = exchange.transport_state
    assert :ok = Operations.finish(table, key, token, :ok)
    assert {:error, :closed, ^exchange} = Exchange.poll_connection(exchange, 0)
    assert {:ok, %{status: {:finished, :ok}}} = Operations.status(table, key, token)
    refute_received {:operation, ^owner, _, _}
  end

  test "finite five millisecond polling confirms pending and keeps the original deadline" do
    {exchange, owner} = exchange([:pending, {:ok, "later", true, []}])
    assert {:pending, ^exchange} = Exchange.read_body_step(exchange, 5, 5)
    assert_receive {:operation, ^owner, {:read, 5, {:until, io_deadline}}, confirmation}
    assert confirmation == min(exchange.deadline, io_deadline + exchange.limits.write_timeout)
    assert {:pending, ^exchange} = Exchange.poll_connection(exchange, 5)
    assert_receive {:operation, ^owner, {:poll, {:until, poll_deadline}}, poll_confirmation}

    assert poll_confirmation ==
             min(exchange.deadline, poll_deadline + exchange.limits.write_timeout)

    assert {:ok, "later", next} = Exchange.read_body_step(exchange, 5, 5)
    assert next.deadline == exchange.deadline
    assert {:ok, _} = Response.send_resp(next, 200, [], "response")
  end

  test "a queued reply after a paused caller's deadline cannot permit more output" do
    {exchange, owner} = exchange([], :late_notification)
    exchange = %{exchange | limits: %{exchange.limits | write_timeout: 100}}
    assert {:error, :timeout} = Response.send_resp(exchange, 200, [], "once")
    assert_receive {:operation, ^owner, {:head, 200, _, false}, _}
    assert {:error, :closed} = Response.send_resp(exchange, 200, [], "retry")
    refute_received {:operation, ^owner, {:data, _, _}, _}
  end

  test "write timeout retains terminal tombstone and never retries output" do
    {exchange, owner} = exchange([], :hold)
    exchange = %{exchange | limits: %{exchange.limits | write_timeout: 30}}
    started = Lifecycle.now()
    assert {:error, :timeout} = Response.send_resp(exchange, 200, [], "once")
    finished = Lifecycle.now()
    assert (finished - started) in 30..299
    assert_receive {:operation, ^owner, {:head, 200, _, false}, deadline}
    assert deadline >= started + 30 and deadline <= finished
    assert {:error, :closed} = Response.send_resp(exchange, 200, [], "once")
    refute_received {:operation, ^owner, {:head, 200, _, false}, _}
  end

  test "owner DOWN and deleted ETS end a cooperative transport wait" do
    {exchange, owner} = exchange()
    monitor = Process.monitor(owner)
    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^owner, :killed}
    assert {:error, :closed} = Response.send_resp(exchange, 200, [], "late")
    assert {:error, :closed, ^exchange} = Exchange.read_body_step(exchange, 1, 100)
    assert {:error, :closed, ^exchange} = Exchange.poll_connection(exchange, 0)
  end
end
