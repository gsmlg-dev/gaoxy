defmodule Gaoxy.Proxy.UpstreamGroupTLSTest do
  use ExUnit.Case, async: false
  @moduletag :capture_log
  alias Gaoxy.Proxy.{GroupEndpoint, UpstreamGroups}
  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Lifecycle
  @timeout 3_000

  setup_all do
    directory =
      Path.join(System.tmp_dir!(), "gaoxy-groups-tls-#{System.unique_integer([:positive])}")

    script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
    on_exit(fn -> File.rm_rf!(directory) end)

    for name <- ["trusted", "other"] do
      {output, status} =
        System.cmd("bash", [script, Path.join(directory, name)], stderr_to_stdout: true)

      assert status == 0, output
    end

    {:ok, directory: directory}
  end

  for reject <- [false, true] do
    test "verified TLS HEAD and selected request preserve SNI and numeric pin; later TLS rejection #{reject} has no retry",
         %{directory: directory} do
      trusted = Path.join(directory, "trusted")
      other = Path.join(directory, "other")

      {:ok, listener} =
        :ssl.listen(0, [
          :binary,
          active: false,
          ip: {127, 0, 0, 2},
          certfile: Path.join(trusted, "cert.pem"),
          keyfile: Path.join(trusted, "key.pem")
        ])

      {:ok, {_, port}} = :ssl.sockname(listener)
      parent = self()

      peer =
        spawn(fn ->
          {:ok, raw} = :ssl.transport_accept(listener, @timeout)
          {:ok, socket} = :ssl.handshake(raw, @timeout)
          {:ok, info} = :ssl.connection_information(socket, [:sni_hostname])
          probe = head(socket)
          send(parent, {:tls_head, self(), to_string(info[:sni_hostname]), probe})
          :ok = :ssl.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
          assert {:error, :closed} = :ssl.recv(socket, 0, @timeout)
          :ssl.close(socket)
          {:ok, raw} = :ssl.transport_accept(listener, @timeout)

          options =
            if unquote(reject),
              do: [
                certfile: Path.join(other, "cert.pem"),
                keyfile: Path.join(other, "key.pem")
              ],
              else: []

          case :ssl.handshake(raw, options, @timeout) do
            {:ok, socket} ->
              {:ok, info} = :ssl.connection_information(socket, [:sni_hostname])
              request = head(socket)
              send(parent, {:tls_request, self(), to_string(info[:sni_hostname]), request})
              :ok = :ssl.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 6\r\n\r\nsecure")
              assert {:error, :closed} = :ssl.recv(socket, 0, @timeout)
              :ssl.close(socket)

            {:error, reason} ->
              send(parent, {:tls_rejected, self(), reason})
          end

          send(parent, {:tls_done, self()})
        end)

      on_exit(fn ->
        :ssl.close(listener)
        if Process.alive?(peer), do: Process.exit(peer, :kill)
      end)

      groups = start_supervised!({UpstreamGroups, instance: self()})

      {:ok, compiled} =
        UpstreamGroups.compile(%{
          id: "api",
          members: [
            %{
              id: "one",
              upstream: "https://localhost:#{port}",
              cacertfile: Path.join(trusted, "ca.pem"),
              connect_address: {127, 0, 0, 2}
            }
          ]
        })

      {:ok, handle, preparation} =
        UpstreamGroups.prepare(groups, compiled, self(), Lifecycle.deadline(@timeout))

      assert_receive {:tls_head, ^peer, "localhost", probe}, @timeout
      assert probe =~ "HEAD / HTTP/1.1\r\n"
      assert String.downcase(probe) =~ "host: localhost:#{port}\r\n"
      eventually(fn -> hd(UpstreamGroups.status(handle).members).health == :healthy end)

      {:ok, baseline} =
        Resources.pin_many([handle], self(), :baseline, Lifecycle.deadline(@timeout))

      :ok = Resources.release(preparation)

      {:ok, server} =
        Gaoxy.HTTP.start_link(
          endpoint: {GroupEndpoint, %{group: handle}},
          limits: %{max_bytes: 16_777_216}
        )

      on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
      {:ok, {ip, downstream_port}} = Gaoxy.info(server, :http).local
      {:ok, client} = :gen_tcp.connect(ip, downstream_port, [:binary, active: false], @timeout)
      on_exit(fn -> :gen_tcp.close(client) end)

      :ok =
        :gen_tcp.send(
          client,
          "GET /secure?q=%2F HTTP/1.1\r\nHost: edge.test\r\nConnection: close\r\n\r\n"
        )

      response = receive_all(client)

      if unquote(reject) do
        assert response =~ "502 Bad Gateway"
        assert_receive {:tls_rejected, ^peer, {:tls_alert, {:unknown_ca, _}}}, @timeout
        refute_receive {:tls_request, ^peer, _, _}, 20
      else
        assert response =~ "200 OK"
        assert response =~ "\r\n\r\nsecure"
        assert_receive {:tls_request, ^peer, "localhost", request}, @timeout
        assert request =~ "GET /secure?q=%2F HTTP/1.1\r\n"
        assert String.downcase(request) =~ "host: localhost:#{port}\r\n"
      end

      assert_receive {:tls_done, ^peer}, @timeout
      eventually(fn -> UpstreamGroups.status(handle).inflight == 0 end)
      assert {:error, :timeout} = :ssl.transport_accept(listener, 0)
      :ok = Resources.release(baseline)
    end
  end

  defp head(socket, bytes \\ "") do
    if String.contains?(bytes, "\r\n\r\n"),
      do: bytes,
      else:
        (
          assert {:ok, more} = :ssl.recv(socket, 0, @timeout)
          head(socket, bytes <> more)
        )
  end

  defp receive_all(socket, bytes \\ "") do
    case :gen_tcp.recv(socket, 0, @timeout) do
      {:ok, more} -> receive_all(socket, bytes <> more)
      {:error, :closed} -> bytes
    end
  end

  defp eventually(fun, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(@timeout)

    if fun.(),
      do: :ok,
      else:
        (
          assert Lifecycle.remaining(deadline) > 0

          receive do
          after
            2 -> eventually(fun, deadline)
          end
        )
  end
end
