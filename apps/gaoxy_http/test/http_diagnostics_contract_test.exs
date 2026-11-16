defmodule Gaoxy.HTTP.DiagnosticsContractTest do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.Diagnostics
  @moduletag :unit

  setup do
    id = make_ref()
    :ok = :telemetry.attach(id, [:gaoxy, :http, :failure], &__MODULE__.observe/4, self())
    on_exit(fn -> :telemetry.detach(id) end)
    :ok
  end

  def observe(_, measurements, metadata, owner),
    do: send(owner, {:failure, measurements, metadata})

  test "external terms collapse into finite metadata" do
    secret = String.duplicate("credential", 1_000)

    Diagnostics.emit(secret, secret, {:bad, secret}, secret, secret, System.monotonic_time(), %{
      request_id: secret,
      stream_id: secret
    })

    assert_receive {:failure, %{count: 1, duration: duration}, metadata}
    assert duration >= 0

    assert metadata == %{
             protocol: :unknown,
             stage: :request,
             reason: :protocol_error,
             status: nil,
             response_committed: false,
             request_id: nil,
             stream_id: nil
           }
  end

  test "concurrent watchdog and endpoint failure claim one event" do
    Diagnostics.start(:http1)
    owner = self()

    tasks =
      for _ <- 1..8, do: Task.async(fn -> Diagnostics.timeout(nil, nil, %{owner: owner}, nil) end)

    Diagnostics.failure(:endpoint, :endpoint_error)
    Enum.each(tasks, &Task.await/1)
    assert_receive {:failure, _, _}
    refute_receive {:failure, _, _}, 0
    Diagnostics.finish()
  end

  test "completed and upgraded lifecycles cannot become HTTP watchdog failures" do
    Diagnostics.start(:http1)
    Diagnostics.response(101)
    Diagnostics.finish()
    Diagnostics.timeout(nil, nil, %{owner: self()}, nil)
    refute_receive {:failure, _, _}, 0
  end

  test "keep-alive begins a new correlation and commitment state" do
    Diagnostics.start(:http1)
    Diagnostics.response(201)
    Diagnostics.failure(:endpoint, :plug_exception)
    assert_receive {:failure, _, %{request_id: first, status: 201, response_committed: true}}
    Diagnostics.finish()
    Diagnostics.start(:http1)
    Diagnostics.failure(:headers, :header_timeout)
    assert_receive {:failure, _, %{request_id: second, status: nil, response_committed: false}}
    refute first == second
    Diagnostics.finish()
  end
end
