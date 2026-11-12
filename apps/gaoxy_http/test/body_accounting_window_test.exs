defmodule Gaoxy.HTTP.BodyAccountingWindowTest do
  use ExUnit.Case, async: false
  @moduletag :component

  alias Gaoxy.{Admission, Lifecycle, ResourceBudget}
  alias Gaoxy.HTTP.{Exchange, HTTP1.Body, HTTP1.Parser}

  @mib 1_048_576
  @funding 8_192

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: {:ok, exchange}
  end

  defmodule RejectingGate do
    use GenServer

    def start_link(options), do: GenServer.start_link(__MODULE__, options)
    def init(options), do: {:ok, options}

    def handle_call({action, _, accounting, _, _}, _, {owner, reason} = state)
        when action in [:update_until, :repartition_until] do
      send(owner, {:admission_attempt, self(), action, accounting})
      {:reply, {:error, reason}, state}
    end
  end

  test "a confirmed window charges its whole envelope as temporary and reuses its receipt" do
    context = funded()
    projected = %{context.exchange | adapter_body_bytes: 4_096}
    assert {:ok, reserved} = Exchange.reserve_plug_body(projected)
    owner = self()
    gate = reserved.gate
    lease = reserved.lease

    assert %{owner: ^owner, gate: ^gate, lease: ^lease, ceiling: ceiling} = reserved.body_window
    assert ceiling >= Exchange.retained_bytes(projected)
    assert ceiling > @funding

    assert %{retained_bytes: 0, temporary_bytes: ^ceiling, usage: ^ceiling} = snapshot(context)
    before = allocation(context)
    assert before.accounting.transport_bytes == ceiling
    assert before.accounting.memberships == reserved.funding.memberships

    assert :ok = Exchange.update_body_retention(reserved, ceiling)
    assert allocation(context) == before
  end

  for condition <- [:stale, :high_pressure] do
    @condition condition
    test "existing completion credit survives a #{@condition} safety sample" do
      context = funded()
      condition = @condition
      Agent.update(context.control, &Map.put(&1, :condition, condition))
      assert :ok = ResourceBudget.refresh(context.server)

      assert {:ok, reserved} =
               Exchange.reserve_plug_body(%{context.exchange | adapter_body_bytes: 64})

      assert reserved.body_window == :disabled
      expected = Exchange.accounting(reserved, Exchange.retained_bytes(reserved))
      assert allocation(context).accounting == expected
      assert snapshot(context).usage == @funding
    end
  end

  test "shared hard-limit rejection of rounded headroom retries the fitting exact obligation" do
    context = funded(hard_limit: 32_768)

    assert {:ok, reserved} =
             Exchange.reserve_plug_body(%{context.exchange | adapter_body_bytes: 16_384})

    assert reserved.body_window == :disabled
    expected = Exchange.accounting(reserved, Exchange.retained_bytes(reserved))
    assert expected.transport_bytes > @funding
    assert expected.transport_bytes < 32_768
    assert allocation(context).accounting == expected
    assert snapshot(context).usage == expected.transport_bytes
  end

  test "partial and completed buffered Plug reads settle the exact ordinary accounting split" do
    context = funded()

    assert {:ok, reserved} =
             Exchange.reserve_plug_body(%{context.exchange | adapter_body_bytes: 4_096})

    assert {:more, "abcd", partial} =
             Gaoxy.PlugAdapter.read_req_body(reserved, length: 4, read_length: 2)

    assert partial.body_window == nil
    assert partial.adapter_body_bytes == 0
    assert partial.buffer == "efgh"

    assert allocation(context).accounting ==
             Exchange.accounting(partial, Exchange.retained_bytes(partial))

    assert {:ok, "efgh", complete} =
             Gaoxy.PlugAdapter.read_req_body(partial, length: 4, read_length: 2)

    assert complete.body_window == nil
    assert complete.adapter_body_bytes == 0
    assert complete.buffer == ""
    assert Exchange.body_complete?(complete)

    assert allocation(context).accounting ==
             Exchange.accounting(complete, Exchange.retained_bytes(complete))

    assert snapshot(context).usage == @funding
  end

  test "a body-limit error releases the accumulator window before propagating HTTP 413" do
    context = funded()
    exchange = %{context.exchange | body: Body.new({:length, 8}, %{max_body_bytes: 4})}
    assert {:ok, reserved} = Exchange.reserve_plug_body(%{exchange | adapter_body_bytes: 4_096})

    error =
      assert_raise Gaoxy.HTTP.RequestError, fn ->
        Gaoxy.PlugAdapter.read_req_body(reserved, [])
      end

    assert error.plug_status == 413

    assert allocation(context).accounting ==
             Exchange.accounting(exchange, Exchange.retained_bytes(exchange))

    assert snapshot(context).usage == @funding
  end

  test "a copied window cannot authorize another process's lease mutation" do
    context = funded()
    assert {:ok, reserved} = Exchange.reserve_plug_body(context.exchange)
    before = allocation(context)

    assert {:error, :stale_generation} =
             Task.async(fn -> Exchange.reserve_plug_body(reserved) end) |> Task.await(1_000)

    assert allocation(context) == before
  end

  test "a copied window cannot authorize a different lease" do
    context = funded()
    assert {:ok, reserved} = Exchange.reserve_plug_body(context.exchange)
    before = allocation(context)

    assert {:error, :stale_generation} =
             Exchange.reserve_plug_body(%{reserved | lease: make_ref()})

    assert allocation(context) == before
  end

  test "an expired request cannot consume a previously confirmed window" do
    context = funded()
    assert {:ok, reserved} = Exchange.reserve_plug_body(context.exchange)
    before = allocation(context)
    expired = %{reserved | deadline: Lifecycle.deadline(0)}
    assert {:error, :timeout} = Exchange.reserve_plug_body(expired)
    assert {:error, :timeout} = Exchange.update_body_retention(expired, 1)
    assert allocation(context) == before
  end

  test "a stopped gate cannot authorize cached window credit" do
    context = funded()
    assert {:ok, reserved} = Exchange.reserve_plug_body(context.exchange)
    monitor = Process.monitor(context.gate)
    # Isolate the caller to exercise the guard after the native owner link dies.
    assert Process.unlink(context.gate)
    assert Process.exit(context.gate, :kill)
    assert_receive {:DOWN, ^monitor, :process, _, :killed}, 1_000
    refute Process.alive?(context.gate)
    assert {:error, :closed} = Exchange.reserve_plug_body(reserved)
    assert {:error, :closed} = Exchange.update_body_retention(reserved, 1)
  end

  for reason <- [:budget_timeout, :budget_pending, :budget_unavailable] do
    @reason reason
    test "ambiguous #{@reason} never retries an exact reservation or installs a window" do
      gate = start_supervised!({RejectingGate, {self(), @reason}})
      exchange = exchange(gate, make_ref(), %{connection: make_ref(), request: make_ref()})
      assert {:error, @reason} = Exchange.reserve_plug_body(exchange)
      assert_receive {:admission_attempt, ^gate, _, _}
      refute_receive {:admission_attempt, ^gate, _, _}, 0
    end
  end

  defp funded(options \\ []) do
    identity = make_ref()

    control =
      start_supervised!(
        Supervisor.child_spec(
          {Agent, fn -> %{condition: :healthy, now: System.monotonic_time(:millisecond)} end},
          id: make_ref()
        )
      )

    now = fn -> Agent.get(control, & &1.now) end

    start_supervised!(
      {Gaoxy.ResourceBudget.Supervisor,
       identity: identity,
       capacity_probe: fn -> %{capacity: 1_000 * @mib, fallback?: false, source: :controlled} end,
       safety_probe: fn _ ->
         %{condition: condition, now: current} = Agent.get(control, & &1)

         {:ok,
          %{
            available_bytes: 1_000 * @mib,
            cgroup_headroom_bytes: nil,
            sampled_at: current - if(condition == :stale, do: 4_000, else: 0),
            high_pressure?: condition == :high_pressure
          }}
       end,
       now: now,
       processes: fn -> %{count: 1, limit: 1_000} end}
    )

    server = Gaoxy.ResourceBudget.Supervisor.name(Gaoxy.ResourceBudget.Authority, identity)
    assert :ok = ResourceBudget.refresh(server)
    hard = Keyword.get(options, :hard_limit, 32 * @mib)

    assert {:ok, instance} =
             ResourceBudget.register_instance(
               server,
               self(),
               %{soft_limit: hard, hard_limit: hard},
               deadline()
             )

    id = make_ref()

    assert {:ok, service} =
             ResourceBudget.register_service(
               server,
               instance,
               %{id: id, owner: self(), generation: make_ref()},
               %{
                 max_active: nil,
                 max_bytes: nil,
                 max_connections: 10,
                 max_requests: 10,
                 max_streams: 10,
                 provenance: %{}
               },
               deadline()
             )

    scope = %{
      instance: make_ref(),
      service: id,
      generation: make_ref(),
      service_pid: self(),
      budget: %{server: server, instance: instance, service: service}
    }

    gate =
      start_supervised!(
        Supervisor.child_spec(
          {Admission, {%{max_active: 10, max_bytes: 32 * @mib, callback_timeout: 5_000}, scope}},
          id: make_ref(),
          restart: :temporary
        )
      )

    memberships = %{connection: make_ref(), request: make_ref()}
    initial = exchange(gate, nil, memberships)
    accounting = Exchange.accounting(initial, Exchange.retained_bytes(initial))
    assert {:ok, lease} = Admission.acquire(gate, accounting, kind: :connection)

    %{
      server: server,
      instance: instance,
      gate: gate,
      control: control,
      exchange: %{initial | lease: lease}
    }
  end

  defp exchange(gate, lease, memberships) do
    assert {:ok, spec} = Gaoxy.HTTP.service_spec(endpoint: {Endpoint, []}, protocols: [:http1])

    limits =
      Map.merge(spec.handler_options.http_limits, %{
        max_buffer_bytes: 1_024,
        max_read_chunk: 128,
        max_trailer_bytes: 128
      })

    assert {:ok, request, ""} =
             Parser.parse_head(
               "POST / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 8\r\n\r\n",
               limits
             )

    %Exchange{
      request: %{request | head_bytes: 16},
      gate: gate,
      lease: lease,
      deadline: deadline(),
      limits: limits,
      body: Body.new({:length, 8}, limits),
      buffer: "abcdefgh",
      protocol_bytes: 512
    }
    |> Exchange.fund(@funding, 512, memberships)
  end

  defp allocation(context) do
    assert {:ok, client} = Admission.budget_client(context.gate)
    assert {:ok, %{allocations: [allocation]}} = ResourceBudget.allocations(client)
    allocation
  end

  defp snapshot(context), do: ResourceBudget.snapshot(context.server, context.instance)
  defp deadline, do: Lifecycle.deadline(1_000)
end
