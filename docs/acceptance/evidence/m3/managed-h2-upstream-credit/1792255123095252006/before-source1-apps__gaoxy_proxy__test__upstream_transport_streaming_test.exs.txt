Code.require_file("support/managed_h2_group_fixture.exs", __DIR__)

defmodule Gaoxy.Proxy.UpstreamTransportStreamingTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH2FixedFixture, as: F
  alias Gaoxy.Proxy.ManagedH2GroupFixture, as: G
  alias Gaoxy.Proxy.{ManagedH2GroupBoundary, UpstreamGroups, UpstreamTransports}
  @moduletag :capture_log
  @reserve 16_478_862

  for mount <- [:fixed, :group] do
    describe "#{mount} managed H2 response prefix" do
      if mount == :group do
        setup do
          assert :ok === boundary(:activation)
          :ok
        end
      end

      for downstream <- [:http1, :http2], upstream <- [:h2c, :http2] do
        @mount mount
        @downstream downstream
        @upstream upstream
        test "#{downstream} -> #{upstream} observes original held prefix before suffix and ordered terminal trailers" do
          prefix = <<0, "managed-h2-prefix", 255>>
          suffix = <<128, "|suffix", 0>>
          trailers = [["x-check", "first"], ["x-check", "second"]]
          f = fixture(@mount, @upstream, @downstream)
          {socket, seen, guardian, completion} = hold(@mount, f, "/hold/response-prefix")
          assert seen["target"] === "/hold/response-prefix"
          assert [":method", "GET"] in seen["headers"]
          connection = seen["connection"]
          stream = seen["stream"]

          assert %{"connection" => ^connection, "stream" => ^stream, "total_bytes" => 0} =
                   F.event(f.peer, "upload_end")

          if @upstream == :http2,
            do: assert(%{"alpn" => "h2", "sni" => "localhost"} = F.event(f.peer, "tls"))

          held = capture_holds(@mount, f, guardian, completion)
          tag = make_ref()

          assert %{"op" => "respond", "connection" => ^connection, "stream" => ^stream} =
                   F.command(f.peer, seen, "respond", %{
                     "status" => 200,
                     "fields" => [
                       ["content-type", "application/octet-stream"],
                       ["trailer", "x-check"]
                     ],
                     "body64" => Base.encode64(prefix),
                     "ended" => false
                   })

          progress = fn %{body: body, ended: ended} ->
            if byte_size(body) <= byte_size(prefix) do
              assert body === binary_part(prefix, 0, byte_size(body))
              refute ended

              if body === prefix do
                assert_held(@mount, f, held, guardian, completion)
                send(self(), {:response_prefix_observed, tag, body})

                assert %{"op" => "data", "connection" => ^connection, "stream" => ^stream} =
                         F.command(f.peer, seen, "data", %{
                           "body64" => Base.encode64(suffix),
                           "trailers" => trailers,
                           "ended" => true
                         })
              end
            end
          end

          result = F.response(f, socket, "GET", 1, progress)
          assert result.status === 200
          assert result.body === prefix <> suffix
          assert result.trailers === [{"x-check", "first"}, {"x-check", "second"}]
          assert {"content-type", "application/octet-stream"} in result.headers

          if @downstream == :http1,
            do: assert({"transfer-encoding", "chunked"} in result.headers)

          assert_receive {:response_prefix_observed, ^tag, ^prefix}, 0
          refute_receive {:response_prefix_observed, ^tag, _}, 0
          :ok = :gen_tcp.close(socket)
          clean(@mount, f)
          assert :ok = HTTP.RequestCompletion.await(completion, 0)
          close(@mount, f)
        end
      end
    end
  end

  defp fixture(:fixed, upstream, downstream), do: F.fixture(upstream, downstream, ["--manual"])
  defp fixture(:group, upstream, downstream), do: G.fixture(upstream, downstream, ["--manual"])
  defp hold(:fixed, f, target), do: F.hold(f, target)
  defp hold(:group, f, target), do: G.hold(f, target)
  defp clean(:fixed, f), do: F.clean(f)
  defp clean(:group, f), do: G.clean(f)
  defp close(:fixed, f), do: F.close(f)
  defp close(:group, f), do: G.close(f)

  defp capture_holds(mount, f, guardian, completion) do
    [{transport_token, transport_hold}] = Map.to_list(:sys.get_state(f.owner).tokens)
    assert transport_hold.guardian === guardian
    assert transport_hold.completion === completion
    assert transport_hold.resource === f.handle.resource
    assert %HTTP.RequestCompletion{} = completion
    state = :sys.get_state(guardian)
    assert state.client.completion(state.original_request) === completion
    assert state.transport_selection === {f.handle, transport_token}
    assert state.managed_path === true
    assert state.managed_transport === nil
    assert state.request_options === nil
    assert state.selector === nil
    assert state.awaiting_transport === nil
    assert state.submitted_url === f.origin <> "/hold/response-prefix"
    assert :binary.referenced_byte_size(state.submitted_url) === byte_size(state.submitted_url)
    assert Enum.sort(Map.keys(state.request)) === [:completion, :promise, :resolved, :stream]
    assert [_ | _] = state.transport_pins

    for pin <- state.transport_pins do
      assert pin.provider === UpstreamTransports
      assert pin.owner === f.owner
      assert pin.holder === guardian
      assert pin.kind === :request
      assert pin.handles === [f.handle]
      assert :sys.get_state(f.owner).pins[pin.ref].public === pin
    end

    held = %{
      transport_token: transport_token,
      transport_selection: state.transport_selection,
      original_request: state.original_request,
      transport_pins: state.transport_pins
    }

    case mount do
      :fixed ->
        assert state.selection === nil
        held

      :group ->
        [{group_token, group_hold}] = Map.to_list(:sys.get_state(f.groups).tokens)
        assert group_hold.guardian === guardian
        assert group_hold.completion === completion
        refute group_token === transport_token
        assert state.selection === {f.group, group_token}
        Map.merge(held, %{group_token: group_token, selection: state.selection})
    end
  end

  defp assert_held(mount, f, held, guardian, completion) do
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
    transport = :sys.get_state(f.owner)
    transport_hold = Map.fetch!(transport.tokens, held.transport_token)
    assert transport_hold.guardian === guardian
    assert transport_hold.completion === completion
    assert transport_hold.resource === f.handle.resource
    state = :sys.get_state(guardian)
    assert state.original_request === held.original_request
    assert state.client.completion(state.original_request) === completion
    assert state.transport_selection === held.transport_selection
    assert state.transport_selection === {f.handle, held.transport_token}
    assert state.transport_pins === held.transport_pins
    assert [_ | _] = state.transport_pins

    for pin <- held.transport_pins do
      assert pin.holder === guardian
      assert pin.kind === :request
      assert transport.pins[pin.ref].public === pin
    end

    case mount do
      :fixed ->
        assert state.selection === nil

      :group ->
        group = :sys.get_state(f.groups)
        group_hold = Map.fetch!(group.tokens, held.group_token)
        assert group_hold.guardian === guardian
        assert group_hold.completion === completion
        assert state.selection === held.selection
        assert state.selection === {f.group, held.group_token}
        assert %{inflight: 1} = UpstreamGroups.status(f.group)
        assert G.assert_cleanup(f, 1) === @reserve
        G.assert_exact_controls(:sys.get_state(f.groups))
    end
  end

  defp boundary(function), do: apply(ManagedH2GroupBoundary, function, [])
end
