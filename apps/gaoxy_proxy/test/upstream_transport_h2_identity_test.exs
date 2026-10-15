defmodule Gaoxy.Proxy.UpstreamTransportH2IdentityTest do
  use ExUnit.Case, async: true

  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Proxy.ManagedH2Preparation
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports

  setup_all do
    directory =
      Path.join(
        System.tmp_dir!(),
        "gaoxy-h2-owner-identity-#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf!(directory) end)
    script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
    {log, status} = System.cmd("bash", [script, directory], stderr_to_stdout: true)
    assert status == 0, log

    certificates =
      directory
      |> Path.join("ca.pem")
      |> File.read!()
      |> :public_key.pem_decode()
      |> Enum.map(fn {:Certificate, der, :not_encrypted} -> der end)

    {:ok, certificates: certificates}
  end

  test "both H2 protocols open a real scope and checkout the exact immutable native profile",
       context do
    for protocol <- [:http2, :h2c] do
      f = fixture(protocol, nil, context.certificates)
      assert {:ok, expected, _} = ManagedH2Preparation.prepare_policy(f.source)
      assert {:ok, [pin]} = Resources.pin_many([f.handle], self(), :request, f.deadline)
      assert {:ok, client, token} = Transports.checkout(f.handle, [pin], self(), deadline())

      assert Enum.sort(Map.keys(client)) == [:fetch_options, :policy, :transport_scope]
      assert client.policy == expected
      assert client.policy.open_options[:max_connections] == 2
      assert client.policy.open_options[:max_requests] == 32
      assert client.policy.open_options[:max_pending] == 0

      assert client.fetch_options == [
               http_version: protocol,
               tls_backend: :ssl,
               http2_profile: :native_v1,
               http2_reuse: true,
               redirect: :manual,
               request_mode: :proxy,
               decode_body: false,
               stream_response: true,
               telemetry: false
             ]

      assert %HTTP.ManagedTransport{} = client.transport_scope

      assert {:ok, second, second_token} =
               Transports.checkout(f.handle, [pin], self(), deadline())

      assert second == client
      refute second_token == token
      assert {:error, :cleanup_unconfirmed} = Transports.finish(f.handle, token)
      assert {:error, :cleanup_unconfirmed} = Transports.finish(f.handle, second_token)
      assert :ok = Resources.release(pin)
      close_fixture(f)
    end
  end

  test "H1 and h2c at the same HTTP authority cannot alias on validation or delegation" do
    h2 = fixture(:h2c)
    h1 = fixture(:http1)

    for {f, wrong_protocol} <- [{h2, :http1}, {h1, :h2c}] do
      guardian = actor()
      assert {:ok, [pin]} = Resources.pin_many([f.handle], self(), :request, f.deadline)
      wrong = %{identity(f) | upstream_protocol: wrong_protocol}

      rejected(
        f,
        fn -> Transports.validate_endpoint(f.handle, wrong, deadline()) end,
        {:error, :transport_endpoint_mismatch}
      )

      rejected(
        f,
        fn -> delegate(f, pin, guardian, wrong) end,
        {:error, :transport_endpoint_mismatch}
      )

      assert :ok = Transports.validate_endpoint(f.handle, identity(f), deadline())
      assert {:ok, child} = delegate(f, pin, guardian)
      assert :ok = call(guardian, fn -> Resources.release(child) end)
      assert :ok = Resources.release(pin)
      close_fixture(f)
    end
  end

  test "TLS H2 and TLS H1 cannot alias even with identical verified authority", context do
    h2 = fixture(:http2, nil, context.certificates)
    h1 = fixture(:http1, "https://example.test", context.certificates)

    for {f, wrong_protocol} <- [{h2, :http1}, {h1, :http2}] do
      guardian = actor()
      assert {:ok, [pin]} = Resources.pin_many([f.handle], self(), :request, f.deadline)
      wrong = %{identity(f) | upstream_protocol: wrong_protocol}

      rejected(
        f,
        fn -> Transports.validate_endpoint(f.handle, wrong, deadline()) end,
        {:error, :transport_endpoint_mismatch}
      )

      rejected(
        f,
        fn -> delegate(f, pin, guardian, wrong) end,
        {:error, :transport_endpoint_mismatch}
      )

      assert :ok = Transports.validate_endpoint(f.handle, identity(f), deadline())
      assert :ok = Resources.release(pin)
      close_fixture(f)
    end
  end

  test "matching H2 identities normalize host case and effective port on both paths", context do
    for protocol <- [:http2, :h2c] do
      f = fixture(protocol, nil, context.certificates)
      guardian = actor()
      scheme = if protocol == :http2, do: "https", else: "http"
      port = if protocol == :http2, do: 443, else: 80

      for origin <- [scheme <> "://EXAMPLE.test/", scheme <> "://example.test:#{port}"] do
        endpoint = %{identity(f) | origin: origin}
        assert :ok = Transports.validate_endpoint(f.handle, endpoint, deadline())
        assert {:ok, [pin]} = Resources.pin_many([f.handle], self(), :request, f.deadline)
        assert {:ok, child} = delegate(f, pin, guardian, endpoint)
        assert child.handles == [f.handle]
        assert child.holder == guardian
        assert :ok = call(guardian, fn -> Resources.release(child) end)
        assert :ok = Resources.release(pin)
      end

      close_fixture(f)
    end
  end

  test "authority and instance mismatches leave the authentic H2 source right untouched",
       context do
    for protocol <- [:http2, :h2c] do
      f = fixture(protocol, nil, context.certificates)
      guardian = actor()
      assert {:ok, [pin]} = Resources.pin_many([f.handle], self(), :request, f.deadline)
      scheme = if protocol == :http2, do: "https", else: "http"

      for endpoint <- [
            %{identity(f) | origin: scheme <> "://other.test"},
            %{identity(f) | origin: scheme <> "://example.test:8080"},
            %{identity(f) | instance: guardian}
          ] do
        rejected(
          f,
          fn -> Transports.validate_endpoint(f.handle, endpoint, deadline()) end,
          {:error, :transport_endpoint_mismatch}
        )

        rejected(
          f,
          fn -> delegate(f, pin, guardian, endpoint) end,
          {:error, :transport_endpoint_mismatch}
        )
      end

      assert {:ok, child} = delegate(f, pin, guardian)
      assert :ok = call(guardian, fn -> Resources.release(child) end)
      assert :ok = Resources.release(pin)
      close_fixture(f)
    end
  end

  test "malformed ports expanded identities backing and protocol scheme mismatch reject before admission" do
    f = fixture(:h2c)
    guardian = actor()
    assert {:ok, [pin]} = Resources.pin_many([f.handle], self(), :request, f.deadline)
    root = "http://" <> String.duplicate("a", 100)
    retained = binary_part(root <> String.duplicate("x", 65_536), 0, byte_size(root))
    assert :binary.referenced_byte_size(retained) > 65_536

    invalid = [
      Map.put(identity(f), :extra, true),
      Map.delete(identity(f), :instance),
      %{identity(f) | instance: nil},
      %{identity(f) | upstream_protocol: :http3},
      %{identity(f) | upstream_protocol: :http2},
      %{identity(f) | origin: "https://example.test"},
      %{identity(f) | origin: retained},
      %{identity(f) | origin: "http://" <> String.duplicate("a", 65_536)}
    ]

    for endpoint <-
          invalid ++
            Enum.map(
              [
                "http://example.test:0",
                "http://example.test:65536",
                "http://example.test:abc",
                "http://example.test:80junk",
                "http://user:secret@example.test",
                "http://example.test/path",
                "http://example.test/?",
                "http://example.test/#"
              ],
              &%{identity(f) | origin: &1}
            ) do
      rejected(
        f,
        fn -> Transports.validate_endpoint(f.handle, endpoint, deadline()) end,
        {:error, :invalid_transport_endpoint}
      )

      rejected(
        f,
        fn -> delegate(f, pin, guardian, endpoint) end,
        {:error, :invalid_transport_endpoint}
      )
    end

    assert {:ok, child} = delegate(f, pin, guardian)
    assert :ok = call(guardian, fn -> Resources.release(child) end)
    assert :ok = Resources.release(pin)
    close_fixture(f)
  end

  test "stale epochs wrong resources and expanded handles cannot validate or delegate H2" do
    f = fixture(:h2c)
    guardian = actor()
    assert {:ok, [pin]} = Resources.pin_many([f.handle], self(), :request, f.deadline)

    for handle <- [
          %{f.handle | owner_epoch: make_ref()},
          %{f.handle | resource: make_ref()},
          Map.put(f.handle, :extra, true)
        ] do
      rejected(
        f,
        fn -> Transports.validate_endpoint(handle, identity(f), deadline()) end,
        {:error, :invalid_resource}
      )

      rejected(
        f,
        fn -> delegate(f, pin, guardian, identity(f), make_ref(), deadline(), handle) end,
        {:error, :invalid_resource}
      )
    end

    assert :ok = Resources.release(pin)
    close_fixture(f)
  end

  test "H2 delegation authenticates holder and operation then consumes the captured right once" do
    f = fixture(:h2c)
    guardian = actor()
    intruder = actor()
    assert {:ok, [pin]} = Resources.pin_many([f.handle], self(), :request, f.deadline)

    rejected(
      f,
      fn -> call(intruder, fn -> delegate(f, pin, guardian) end) end,
      {:error, :unauthorized}
    )

    for forged <- [
          Map.put(pin, :extra, true),
          %{pin | operation: make_ref()},
          %{pin | holder: guardian},
          %{pin | owner_epoch: make_ref()}
        ] do
      rejected(f, fn -> delegate(f, forged, guardian) end, {:error, :invalid_resource_pin})
    end

    rejected(
      f,
      fn -> delegate(f, pin, guardian, identity(f), :not_a_reference) end,
      {:error, :invalid_resource_pin}
    )

    operation = make_ref()
    assert {:ok, child} = delegate(f, pin, guardian, identity(f), operation)
    assert child.operation == operation
    assert child.handles == pin.handles
    assert child.holder == guardian
    assert map_size(child) == 8
    rejected(f, fn -> delegate(f, pin, guardian) end, {:error, :invalid_resource_pin})
    assert {:ok, ^child} = delegate(f, pin, guardian, identity(f), operation)
    assert :ok = Resources.release(pin)

    assert {:ok, client, token} =
             call(guardian, fn ->
               Transports.checkout(f.handle, [child], self(), deadline())
             end)

    assert client.policy.protocol == :h2c

    assert {:error, :cleanup_unconfirmed} =
             call(guardian, fn -> Transports.finish(f.handle, token) end)

    assert :ok = call(guardian, fn -> Resources.release(child) end)
    close_fixture(f)
  end

  test "a queued H2 delegation expires without consuming its source right or publishing a late grant" do
    f = fixture(:h2c)
    guardian = actor()
    assert {:ok, [pin]} = Resources.pin_many([f.handle], self(), :request, f.deadline)
    before = Transports.status(f.owner)
    :ok = :sys.suspend(f.owner)

    try do
      assert {:error, {:deadline_exceeded, :cleanup_pending}} =
               delegate(
                 f,
                 pin,
                 guardian,
                 identity(f),
                 make_ref(),
                 System.monotonic_time(:millisecond) + 20
               )
    after
      :ok = :sys.resume(f.owner)
    end

    assert Transports.status(f.owner) == before
    assert {:ok, child} = delegate(f, pin, guardian)
    assert :ok = call(guardian, fn -> Resources.release(child) end)
    assert :ok = Resources.release(pin)
    close_fixture(f)
  end

  test "joined H2 owner death returns not_running for validation and authenticated delegation" do
    f = fixture(:h2c)
    guardian = actor()
    assert {:ok, [pin]} = Resources.pin_many([f.handle], self(), :request, f.deadline)
    close_fixture(f)

    assert {:error, :not_running} =
             Transports.validate_endpoint(f.handle, identity(f), deadline())

    assert {:error, :not_running} = delegate(f, pin, guardian)
  end

  defp fixture(protocol, origin \\ nil, certificates \\ nil) do
    origin =
      origin || if(protocol == :http2, do: "https://example.test", else: "http://example.test")

    {:ok, instance} = Gaoxy.start_link()
    Process.unlink(instance)
    {:ok, owner} = Transports.start_link(instance: instance, limits: limits())
    Process.unlink(owner)

    f = %{
      instance: instance,
      owner: owner,
      protocol: protocol,
      origin: origin,
      deadline: deadline()
    }

    on_exit(fn -> close_fixture(f) end)
    trust = if String.starts_with?(origin, "https:"), do: certificates, else: nil
    source = %{origin: origin, connect_address: {127, 0, 0, 1}, trust: trust}
    source = if protocol == :http1, do: source, else: Map.put(source, :protocol, protocol)
    assert {:ok, handle, preparation} = Transports.prepare(owner, source, self(), f.deadline)
    Map.merge(f, %{handle: handle, source: source, preparation: preparation})
  end

  defp close_fixture(f) do
    unconfirmed =
      Process.alive?(f.owner) and
        match?({:ok, %{request_tokens: n}} when n > 0, Transports.status(f.owner))

    if Process.alive?(f.owner) do
      creators = Enum.map(:sys.get_state(f.owner).records, fn {_, entry} -> entry.custodian end)
      joins = Enum.map(creators, &{&1, Process.monitor(&1)})
      assert {:ok, receipt} = Transports.retire(f.owner, deadline())
      expected = if unconfirmed, do: {:error, :cleanup_unconfirmed}, else: :ok
      assert Transports.await_retirement(receipt, deadline()) == expected

      for {pid, monitor} <- joins do
        assert_receive {:DOWN, ^monitor, :process, ^pid, reason}, 5000
        assert reason in [:normal, :noproc]
      end

      unless unconfirmed do
        assert {:ok, %{resources: 0, pins: 0, request_tokens: 0, helpers: 0}} =
                 Transports.status(f.owner)
      end
    end

    if Process.alive?(f.instance) do
      instance_monitor = Process.monitor(f.instance)
      owner_monitor = Process.monitor(f.owner)
      retained_before_stop = if unconfirmed, do: Transports.status(f.owner)
      result = Gaoxy.stop(f.instance, 5000)

      if unconfirmed do
        assert {:error, {:shutdown, [], [{_, {:error, :cleanup_unconfirmed}}]}} = result
        assert Process.alive?(f.owner)

        assert {:ok,
                %{
                  resources: resources,
                  request_tokens: tokens,
                  owned_serialized_payload_bytes: payload,
                  reserved_connections: 0,
                  pins: 0,
                  helpers: 0
                } = held} = Transports.status(f.owner)

        assert resources > 0
        assert tokens > 0
        assert payload > 0
        assert {:ok, held} == retained_before_stop
        instance = f.instance
        assert_receive {:DOWN, ^instance_monitor, :process, ^instance, :normal}, 5000

        # Forced disposal of a test-owned owner is not successful public cleanup.
        assert :ok = GenServer.stop(f.owner, :test_cleanup_unconfirmed, 5000)
        owner = f.owner
        assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :test_cleanup_unconfirmed}, 5000
      else
        assert result == :ok
        instance = f.instance
        owner = f.owner
        assert_receive {:DOWN, ^instance_monitor, :process, ^instance, :normal}, 5000
        assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :normal}, 5000
      end
    end
  end

  defp rejected(f, operation, expected) do
    before = Transports.status(f.owner)
    assert operation.() == expected
    assert Transports.status(f.owner) == before
  end

  defp identity(f), do: %{origin: f.origin, upstream_protocol: f.protocol, instance: f.instance}

  defp delegate(
         f,
         pin,
         guardian,
         endpoint \\ nil,
         operation \\ make_ref(),
         d \\ nil,
         handle \\ nil
       ),
       do:
         Transports.delegate_request_pin(
           handle || f.handle,
           pin,
           guardian,
           endpoint || identity(f),
           operation,
           d || f.deadline
         )

  defp actor do
    pid = spawn(fn -> actor_loop() end)

    on_exit(fn ->
      monitor = Process.monitor(pid)
      send(pid, :stop)
      assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, 1000
    end)

    pid
  end

  defp actor_loop do
    receive do
      {:call, caller, ref, operation} ->
        send(caller, {:actor_reply, ref, operation.()})
        actor_loop()

      :stop ->
        :ok
    after
      30_000 -> exit(:actor_idle_deadline)
    end
  end

  defp call(actor, operation) do
    ref = make_ref()
    send(actor, {:call, self(), ref, operation})

    receive do
      {:actor_reply, ^ref, result} -> result
    after
      6000 -> flunk("actor call exceeded finite deadline")
    end
  end

  defp limits,
    do: %{
      max_resources: 2,
      max_pins: 16,
      max_request_tokens: 64,
      max_owned_payload_bytes: 131_072
    }

  defp deadline, do: System.monotonic_time(:millisecond) + 5000
end
