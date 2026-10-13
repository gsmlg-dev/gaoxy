defmodule Gaoxy.Proxy.UpstreamTransportIdentityTest do
  use ExUnit.Case, async: true

  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports

  setup_all do
    directory =
      Path.join(
        System.tmp_dir!(),
        "gaoxy-transport-identity-#{System.unique_integer([:positive])}"
      )

    script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
    on_exit(fn -> File.rm_rf!(directory) end)
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

  test "root HTTP authorities normalize host case and the effective default port" do
    fixture = prepared("http://Example.TEST")

    assert Enum.sort(Map.keys(fixture.handle)) == [:owner, :owner_epoch, :provider, :resource]

    assert %{provider: Transports, owner: owner, owner_epoch: epoch, resource: resource} =
             fixture.handle

    assert owner == fixture.owner
    assert is_reference(epoch)
    assert is_reference(resource)

    for origin <- ["http://example.test", "http://EXAMPLE.TEST/", "http://example.test:80/"] do
      assert :ok = unchanged(fixture, fixture.handle, identity(fixture, origin))
    end

    assert {:ok, %{resources: 1, pins: 1, request_tokens: 0, helpers: 0, reserved_connections: 2}} =
             Transports.status(fixture.owner)
  end

  test "HTTPS root authorities normalize port 443 with explicitly prepared DER trust", context do
    fixture = prepared("https://Example.TEST:443/", context.certificates)

    for origin <- ["https://example.test", "https://EXAMPLE.TEST/", "https://example.test:443"] do
      assert :ok = unchanged(fixture, fixture.handle, identity(fixture, origin))
    end
  end

  test "valid authority and instance mismatches do not poison a later matching validation" do
    fixture = prepared("http://example.test:8080/")
    owner_state = :sys.get_state(fixture.owner)
    other_instance = embedded(false).instance

    for origin <- [
          "http://other.test:8080/",
          "http://example.test/",
          "https://example.test:8080/"
        ] do
      assert {:error, :transport_endpoint_mismatch} =
               unchanged(fixture, fixture.handle, identity(fixture, origin))

      assert :ok = unchanged(fixture, fixture.handle, identity(fixture))
    end

    assert {:error, :transport_endpoint_mismatch} =
             unchanged(fixture, fixture.handle, %{identity(fixture) | instance: other_instance})

    assert :ok = unchanged(fixture, fixture.handle, identity(fixture))
    assert :sys.get_state(fixture.owner) == owner_state
  end

  test "malformed and expanded handles reject without contacting their supplied owner" do
    fixture = prepared("http://example.test")
    observer = observer()
    handle = %{fixture.handle | owner: observer}

    for malformed <- [
          nil,
          [],
          Map.delete(handle, :resource),
          Map.put(handle, :policy, %{}),
          %{handle | provider: HTTP.ManagedTransport},
          %{handle | owner: :not_a_pid},
          %{handle | owner_epoch: :not_a_reference},
          %{handle | resource: :not_a_reference}
        ] do
      assert {:error, :invalid_resource} = unchanged(fixture, malformed, identity(fixture))
      refute_receive {:identity_owner_call, ^observer, _}, 0
    end

    assert :ok = unchanged(fixture, fixture.handle, identity(fixture))
  end

  test "stale epoch and resource references preserve invalid_resource" do
    fixture = prepared("http://example.test")

    for handle <- [
          %{fixture.handle | owner_epoch: make_ref()},
          %{fixture.handle | resource: make_ref()}
        ] do
      assert {:error, :invalid_resource} = unchanged(fixture, handle, identity(fixture))
    end

    assert :ok = unchanged(fixture, fixture.handle, identity(fixture))
  end

  test "identity requires exactly origin, HTTP1 protocol and an instance PID before owner call" do
    fixture = prepared("http://example.test")
    observer = observer()
    handle = %{fixture.handle | owner: observer}

    for malformed <- [
          nil,
          [],
          Map.delete(identity(fixture), :instance),
          Map.put(identity(fixture), :trust, nil),
          %{identity(fixture) | upstream_protocol: :http2},
          %{identity(fixture) | upstream_protocol: :http3},
          %{identity(fixture) | upstream_protocol: nil},
          %{identity(fixture) | instance: :not_a_pid},
          %{identity(fixture) | origin: ~c"http://example.test"}
        ] do
      assert {:error, :invalid_transport_endpoint} = unchanged(fixture, handle, malformed)
      refute_receive {:identity_owner_call, ^observer, _}, 0
    end

    assert :ok = unchanged(fixture, fixture.handle, identity(fixture))
  end

  test "authority grammar rejects credentials, paths, queries, fragments and malformed text" do
    fixture = prepared("http://example.test")
    observer = observer()
    handle = %{fixture.handle | owner: observer}

    for origin <- [
          "",
          "ftp://example.test",
          "http://",
          "http://example.test:0",
          "http://example.test:65536",
          "http://example.test:abc",
          "http://user:password@example.test",
          "http://example.test/path",
          "http://example.test/?",
          "http://example.test/?q=1",
          "http://example.test/#",
          "http://example.test/#fragment",
          "http://example.test/\\path",
          "http://example.test/\r\n",
          "http://example.test/%GG",
          "http://" <> String.duplicate("a", 254),
          <<"http://example.test/", 255>>
        ] do
      assert {:error, :invalid_transport_endpoint} =
               unchanged(fixture, handle, identity(fixture, origin)),
             "origin: #{inspect(origin)}"

      refute_receive {:identity_owner_call, ^observer, _}, 0
    end

    assert :ok = unchanged(fixture, fixture.handle, identity(fixture))
  end

  test "the 65536 byte bound covers both logical origin bytes and retained backing" do
    fixture = prepared("http://example.test")
    observer = observer()
    handle = %{fixture.handle | owner: observer}
    oversized = "http://" <> String.duplicate("a", 65_536)
    root = "http://" <> String.duplicate("a", 100)
    backing = root <> String.duplicate("x", 65_536)
    retained = binary_part(backing, 0, byte_size(root))
    assert byte_size(retained) < 65_536
    assert :binary.referenced_byte_size(retained) > 65_536

    for origin <- [oversized, retained] do
      assert {:error, :invalid_transport_endpoint} =
               unchanged(fixture, handle, identity(fixture, origin))

      refute_receive {:identity_owner_call, ^observer, _}, 0
    end

    assert {:error, :transport_endpoint_mismatch} =
             unchanged(fixture, fixture.handle, identity(fixture, :binary.copy(retained)))
  end

  test "expired and malformed deadlines preserve finite cleanup-pending errors" do
    fixture = prepared("http://example.test")

    for d <- [System.monotonic_time(:millisecond) - 1, nil, :infinity] do
      assert {:error, {:deadline_exceeded, :cleanup_pending}} =
               unchanged(fixture, fixture.handle, identity(fixture), d)
    end

    assert :ok = unchanged(fixture, fixture.handle, identity(fixture))
  end

  test "unavailable and non-admitting records reject without changing ownership" do
    fixture = prepared("http://example.test")

    for changes <- [%{lifecycle: :failed}, %{transport_confirmed: true}, %{admission: :closed}] do
      before = :sys.get_state(fixture.owner)

      :sys.replace_state(fixture.owner, fn state ->
        entry = Map.merge(state.records[fixture.handle.resource], changes)
        %{state | records: Map.put(state.records, fixture.handle.resource, entry)}
      end)

      try do
        expected =
          if Map.has_key?(changes, :admission),
            do: {:error, :resource_admission_closed},
            else: {:error, :resource_unavailable}

        assert ^expected = unchanged(fixture, fixture.handle, identity(fixture))
      after
        :sys.replace_state(fixture.owner, fn _ -> before end)
      end
    end

    assert :ok = unchanged(fixture, fixture.handle, identity(fixture))
  end

  test "validation cannot authorize a checkout after retirement closes admission" do
    fixture = prepared("http://example.test")
    assert :ok = unchanged(fixture, fixture.handle, identity(fixture))
    assert {:ok, pins} = Resources.pin_many([fixture.handle], self(), :request, deadline())
    entry = :sys.get_state(fixture.owner).records[fixture.handle.resource]
    :ok = :sys.suspend(entry.custodian)

    receipt =
      try do
        assert {:ok, receipt} = Transports.retire(fixture.owner, deadline())
        assert {:error, :retiring} = unchanged(fixture, fixture.handle, identity(fixture))

        assert {:error, :retiring} =
                 Transports.checkout(fixture.handle, pins, self(), deadline())

        receipt
      after
        :ok = :sys.resume(entry.custodian)
      end

    assert :ok = Transports.await_retirement(receipt, deadline())

    assert {:ok, %{resources: 0, pins: 0, request_tokens: 0, helpers: 0}} =
             Transports.status(fixture.owner)
  end

  test "a joined stopped instance and owner preserve not_running for valid identity" do
    fixture = prepared("http://example.test")
    join_instance(fixture)

    assert {:error, :not_running} = unchanged(fixture, fixture.handle, identity(fixture))
  end

  defp unchanged(fixture, handle, endpoint, d \\ deadline()) do
    before = Transports.status(fixture.owner)

    try do
      apply(Transports, :validate_endpoint, [handle, endpoint, d])
    after
      assert Transports.status(fixture.owner) == before
    end
  end

  defp identity(fixture, origin \\ nil),
    do: %{
      origin: origin || fixture.origin,
      upstream_protocol: :http1,
      instance: fixture.instance
    }

  defp prepared(origin, trust \\ nil) do
    fixture = Map.put(embedded(true), :origin, origin)
    source = %{origin: origin, connect_address: {127, 0, 0, 1}, trust: trust}

    assert {:ok, handle, preparation_pins} =
             Transports.prepare(fixture.owner, source, self(), deadline())

    assert {:ok, [_baseline]} =
             Resources.pin_many([handle], fixture.embedding, :baseline, deadline())

    assert :ok = Resources.release(preparation_pins)
    Map.put(fixture, :handle, handle)
  end

  defp join_instance(fixture) do
    operation = make_ref()
    send(fixture.embedding, {:join_instance, self(), operation})
    assert_receive {:instance_joined, ^operation, :ok, joins}, 6000

    for {_actor, reason} <- joins, do: assert(reason == :normal)
    refute Process.alive?(fixture.instance)
    if fixture.owner, do: refute(Process.alive?(fixture.owner))
  end

  defp embedded(with_owner) do
    parent = self()

    embedding =
      spawn(fn ->
        {:ok, instance} = Gaoxy.start_link()

        owner =
          if with_owner do
            {:ok, owner} = Transports.start_link(instance: instance, limits: limits())
            owner
          end

        fixture = %{instance: instance, owner: owner, embedding: self()}
        send(parent, {:embedding_ready, fixture})
        embedding_loop(fixture, nil)
      end)

    assert_receive {:embedding_ready, %{embedding: ^embedding} = fixture}, 5000

    on_exit(fn ->
      join_instance(fixture)
      monitor = Process.monitor(embedding)
      send(embedding, :stop)
      assert_receive {:DOWN, ^monitor, :process, ^embedding, :normal}, 1000
    end)

    fixture
  end

  defp embedding_loop(fixture, joined) do
    receive do
      {:join_instance, caller, operation} ->
        {result, joins} = joined || stop_embedding_instance(fixture)
        send(caller, {:instance_joined, operation, result, joins})
        embedding_loop(fixture, {result, joins})

      :stop ->
        :ok
    end
  end

  defp stop_embedding_instance(fixture) do
    actors =
      if fixture.owner do
        state = :sys.get_state(fixture.owner)
        [fixture.instance, fixture.owner | Enum.map(state.records, fn {_, e} -> e.custodian end)]
      else
        [fixture.instance]
      end

    monitors = Enum.map(actors, &{&1, Process.monitor(&1)})
    d = deadline()
    result = Gaoxy.stop(fixture.instance, Gaoxy.Lifecycle.remaining(d))

    joins =
      for {actor, monitor} <- monitors do
        receive do
          {:DOWN, ^monitor, :process, ^actor, reason} -> {actor, reason}
        after
          Gaoxy.Lifecycle.remaining(d) -> {actor, :join_timeout}
        end
      end

    {result, joins}
  end

  defp observer do
    parent = self()

    pid =
      spawn(fn ->
        receive do
          :stop -> :ok
          message -> send(parent, {:identity_owner_call, self(), message})
        end
      end)

    on_exit(fn ->
      monitor = Process.monitor(pid)
      send(pid, :stop)
      assert_receive {:DOWN, ^monitor, :process, ^pid, _}, 1000
    end)

    pid
  end

  defp limits,
    do: %{max_resources: 2, max_pins: 8, max_request_tokens: 64, max_owned_payload_bytes: 131_072}

  defp deadline, do: System.monotonic_time(:millisecond) + 5000
end
