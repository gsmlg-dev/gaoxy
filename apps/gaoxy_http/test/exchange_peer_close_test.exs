defmodule Gaoxy.HTTP.ExchangePeerCloseTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Connection, Exchange}
  alias Gaoxy.HTTP.HTTP1.Parser

  defmodule Transport do
    def secure?, do: false
    def setopts(_, _), do: :ok
    def peername(%{peer: result}), do: result
    def sockname(%{local: result}), do: result
    def getstat(_), do: {:ok, []}
    def close(%{owner: owner}), do: Kernel.send(owner, {:socket_closed, self()})

    def send(%{owner: owner}, bytes) do
      Kernel.send(owner, {:unexpected_write, bytes})
      :ok
    end
  end

  defmodule Endpoint do
    def init(owner), do: {:ok, owner}

    def call(exchange, owner) do
      send(owner, {:endpoint_called, exchange})
      {:ok, %{exchange | response: :sent, close: true}}
    end
  end

  test "peer identity failures are returned without constructing an exchange" do
    spec = spec()
    {:ok, request, ""} = Parser.parse_head(head(), spec.handler_options.http_limits)

    for reason <- [:enotconn, :closed, :einval, :eio] do
      assert {:error, ^reason} =
               Exchange.new(
                 request,
                 socket(peer: {:error, reason}),
                 nil,
                 nil,
                 :infinity,
                 spec.handler_options.http_limits,
                 ""
               )
    end
  end

  test "local identity failures are returned after a successful peer lookup" do
    spec = spec()
    {:ok, request, ""} = Parser.parse_head(head(), spec.handler_options.http_limits)

    for reason <- [:enotconn, :closed, :einval, :eio] do
      assert {:error, ^reason} =
               Exchange.new(
                 request,
                 socket(local: {:error, reason}),
                 nil,
                 nil,
                 :infinity,
                 spec.handler_options.http_limits,
                 ""
               )
    end
  end

  for identity <- [:peer, :local] do
    test "#{identity} closure aborts short PUTs normally and releases admission" do
      identity = unquote(identity)

      assert capture_log(fn ->
               for timeout <- [:infinity, 30_000],
                   reason <- [:enotconn, :closed, :einval],
                   body <- ["", "abc"] do
                 result = run_connection([{identity, {:error, reason}}], timeout, body)
                 assert {:close, state} = result
                 assert state.phase == :header
                 assert Process.read_timer(state.header_timer) == false
                 refute_received {:endpoint_called, _}
                 refute_received {:unexpected_write, _}
               end
             end) == ""
    end
  end

  test "unexpected identity errors retain their error disposition" do
    for identity <- [:peer, :local] do
      assert {:error, :eio, _state} =
               run_connection([{identity, {:error, :eio}}], 30_000, "")

      refute_received {:endpoint_called, _}
      refute_received {:unexpected_write, _}
    end
  end

  test "successful construction preserves identities, framing, buffer and lease" do
    spec = spec()
    limits = spec.handler_options.http_limits
    {:ok, request, ""} = Parser.parse_head(head(), limits)
    socket = socket()
    lease = make_ref()
    deadline = Lifecycle.deadline(30_000)

    assert %Exchange{
             request: ^request,
             socket: ^socket,
             gate: :gate,
             lease: ^lease,
             deadline: ^deadline,
             limits: ^limits,
             buffer: "abc",
             peer: {{127, 0, 0, 2}, 4321},
             local: {{127, 0, 0, 1}, 8080},
             close: false,
             body: %{phase: {:length, 10}}
           } = Exchange.new(request, socket, :gate, lease, deadline, limits, "abc")
  end

  test "successful dispatch retains finite defaults and infinite request deadlines" do
    assert spec().handler_options.http_limits.request_timeout == 30_000

    for timeout <- [30_000, :infinity] do
      assert {:close, state} = run_connection([], timeout, "0123456789")
      assert_receive {:endpoint_called, exchange}
      assert exchange.peer == {{127, 0, 0, 2}, 4321}
      assert exchange.local == {{127, 0, 0, 1}, 8080}
      assert exchange.service == self()
      assert exchange.instance == :controlled_instance
      assert exchange.deadline == state.deadline
      assert exchange.limits.max_write_chunk > 0

      if timeout == :infinity do
        assert exchange.deadline == :infinity
      else
        assert Lifecycle.remaining(exchange.deadline) in 1..30_000
      end
    end
  end

  def observe_admission([:gaoxy, :work], %{active: 0}, %{instance: instance}, {owner, instance}) do
    send(owner, {:admission_empty, instance})
  end

  def observe_admission(_, _, _, _), do: :ok

  defp run_connection(identity, timeout, body) do
    owner = self()
    spec = spec(timeout)
    instance = make_ref()
    gate = start_supervised!({Admission, {spec.limits, %{instance: instance}}}, id: instance)
    observer = {__MODULE__, instance}

    :ok =
      :telemetry.attach(
        observer,
        [:gaoxy, :work],
        &__MODULE__.observe_admission/4,
        {owner, instance}
      )

    on_exit(fn -> :telemetry.detach(observer) end)

    {worker, monitor} =
      spawn_monitor(fn ->
        socket = socket(Keyword.put(identity, :owner, owner))

        {:continue, state} =
          Connection.handle_connection(socket, %{
            spec: spec,
            gate: gate,
            service: owner,
            instance: :controlled_instance
          })

        result = Connection.handle_data(head() <> body, socket, state)
        send(owner, {:connection_result, self(), result})

        receive do
          :terminate ->
            {:stop, reason, state} = Hell.Handler.handle_continuation(result, socket)
            Connection.terminate(reason, state)
        after
          1_000 -> raise "controlled connection was not terminated"
        end
      end)

    on_exit(fn -> if Process.alive?(worker), do: Process.exit(worker, :kill) end)
    assert_receive {:connection_result, ^worker, result}, 1_000
    assert %{active: 1, retained_bytes: retained} = Admission.status(gate)
    assert retained > 0
    send(worker, :terminate)
    assert_receive {:socket_closed, ^worker}, 1_000
    assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, 1_000
    assert_receive {:admission_empty, ^instance}, 1_000
    assert %{active: 0, retained_bytes: 0, cleanup_pending: 0} = Admission.status(gate)
    :telemetry.detach(observer)
    result
  end

  defp spec(timeout \\ 30_000) do
    {:ok, spec} =
      Gaoxy.HTTP.service_spec(
        endpoint: {Endpoint, self()},
        protocols: [:http1],
        http_limits: %{request_timeout: timeout}
      )

    spec
  end

  defp socket(identity \\ []) do
    transport_state =
      Map.merge(
        %{
          owner: self(),
          peer: {:ok, {{127, 0, 0, 2}, 4321}},
          local: {:ok, {{127, 0, 0, 1}, 8080}}
        },
        Map.new(identity)
      )

    struct!(Hell.Socket,
      socket: transport_state,
      transport_module: Transport,
      read_timeout: 1_000,
      handshake_timeout: 1_000,
      silent_terminate_on_error: false,
      span: Hell.Telemetry.start_span(:connection, %{}, %{handler: __MODULE__})
    )
  end

  defp head,
    do: "PUT /upload HTTP/1.1\r\nHost: localhost\r\nContent-Length: 10\r\n\r\n"
end
