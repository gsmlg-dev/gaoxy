defmodule Gaoxy.Proxy.ManagedH2ControlProjection do
  @moduledoc false
  import ExUnit.Assertions
  alias Gaoxy.Proxy.ManagedH2Envelope, as: Envelope
  alias Gaoxy.Proxy.HTTP.Session

  # Test-only accounting contract. Preserve complete maps/tuples and every
  # scalar. A marker replaces ONLY a separately validated, named ledger slot.
  # Opaque scope/completion/socket interiors are never passed to external_size.
  @session_keys ~w(owner service instance gate started_at deadline config selector
    transport_handoff request_options monitors client cleanup_deadline
    cleanup_requested_deadline cleanup_started opening_timer activated_at
    opening_deadline total_timer selection awaiting_transport transport_pins
    transport_selection managed_transport managed_path submitted_url poll_timer
    original_request outcome token request headers delivery trailers cancelled consumed)a
  @pump_keys ~w(exchange config client policy response_policy session monitor deadline
    transport_handoff upload ready upload_stopped last_activity)a
  @families ~w(activate cleanup_cancel handoff down timer cast acknowledge task
    data trailers stream_end stream_error ready handoff_request delivery drain)a

  def families, do: @families

  def session(state) do
    exact(state, @session_keys)
    assert state.client == Gaoxy.Proxy.ManagedH2Client
    assert state.selection == nil
    assert map_size(state.monitors) <= 4
    Enum.each(state.monitors, fn {ref, pid} -> scalar(ref); scalar(pid) end)
    Enum.each([:owner, :service, :instance, :gate], &scalar(state[&1]))
    Enum.each([:opening_timer, :total_timer, :poll_timer, :transport_handoff,
      :delivery, :token], &optional_scalar(state[&1]))
    Enum.each([:started_at, :deadline, :cleanup_deadline, :cleanup_requested_deadline,
      :activated_at, :opening_deadline], &optional_time(state[&1]))
    Enum.each([:cleanup_started, :managed_path, :headers, :cancelled, :consumed],
      fn key -> assert is_boolean(state[key]) end)
    assert state.outcome in [:cancelled, :success, :upstream_failure]
    assert length(state.transport_pins) <= 1
    Enum.each(state.transport_pins, &pin/1)
    selection(state.transport_selection)

    projection = %{state |
      config: config_slot(state.config),
      selector: selector(state.selector),
      request_options: request_slot(state.request_options),
      awaiting_transport: awaiting(state.awaiting_transport),
      managed_transport: checked_slot(state.managed_transport, state.config.upstream_protocol),
      submitted_url: binary_slot(state.submitted_url, 65_536, :session_request_url),
      original_request: handle(state.original_request), request: handle(state.request),
      trailers: fields_slot(state.trailers, 128, 65_536, 67_079, :terminal_trailer_lists)}
    bounded(projection, 16_384)
  end

  def pump(state) do
    exact(state, @pump_keys)
    assert state.client == Gaoxy.Proxy.ManagedH2Client
    scalar(state.session); scalar(state.monitor)
    time(state.deadline); time(state.last_activity)
    optional_scalar(state.upload)
    assert is_boolean(state.ready) and is_boolean(state.upload_stopped)
    projection = %{state | exchange: exchange(state.exchange),
      config: config_slot(state.config), policy: policy_slot(state.policy),
      response_policy: policy_slot(state.response_policy),
      transport_handoff: pump_handoff(state.transport_handoff)}
    bounded(projection, 8_192)
  end

  def handle(nil), do: nil
  def handle(value) do
    exact(value, [:promise, :completion, :stream, :resolved])
    assert %HTTP.Promise{} = value.promise
    exact(value.promise, [:__struct__, :task, :completion])
    assert %Task{} = value.promise.task
    exact(value.promise.task, [:__struct__, :owner, :pid, :ref, :mfa])
    assert value.promise.task.mfa in [nil, {:erlang, :apply, 2}]
    Enum.each([value.promise.task.owner, value.promise.task.pid, value.promise.task.ref], &scalar/1)
    assert %HTTP.RequestCompletion{} = value.completion
    assert value.promise.completion === value.completion
    assert Gaoxy.Proxy.ManagedH2Client.completion(value) === value.completion
    optional_scalar(value.stream)
    assert is_boolean(value.resolved)
    marker = {:opaque, HTTP.RequestCompletion}
    bounded(%{value | completion: marker, promise: %{value.promise | completion: marker}}, 4_096)
  end

  # Exactly the sixteen families in the design. Unknown shapes cannot be
  # silently pruned into a passing projection. Raw DOWN/error diagnostics are
  # not retained controls: their finite replacement is measured after the same
  # public Session normalization, and live tests check the resulting state.
  def message(message, submitted_url \\ nil) do
    {family, projection} = message_projection(message, submitted_url)
    assert family in @families
    {family, bounded(projection, 2_048)}
  end

  defp message_projection({:gaoxy_cleanup_activate, token} = m, _) do
    scalar(token); {:activate, m}
  end
  defp message_projection({:gaoxy_cleanup_cancel, token, reason, deadline}, _) do
    scalar(token); time(deadline)
    {:cleanup_cancel, {:gaoxy_cleanup_cancel, token, finite(reason), deadline}}
  end
  defp message_projection({:gaoxy_transport_handoff, ref, {:ok, value}, deadline}, _) do
    scalar(ref); time(deadline); pin(value)
    {:handoff, {:gaoxy_transport_handoff, ref, {:ok, value}, deadline}}
  end
  defp message_projection({:gaoxy_transport_handoff, ref, {:error, reason}, deadline}, _) do
    scalar(ref); time(deadline)
    {:handoff, {:gaoxy_transport_handoff, ref, {:error, finite(reason)}, deadline}}
  end
  defp message_projection({:DOWN, ref, :process, pid, reason}, _) do
    scalar(ref); scalar(pid); {:down, {:DOWN, ref, :process, pid, finite(reason)}}
  end
  defp message_projection(m, _) when m in [:opening_expired, :total_expired, :poll],
    do: {:timer, m}
  defp message_projection({:"$gen_cast", op} = m, _) when op in [:cancel, :expire, :consumed],
    do: {:cast, m}
  defp message_projection({:"$gen_cast", {:acknowledge, ref}} = m, _) do
    scalar(ref); {:acknowledge, m}
  end
  defp message_projection({ref, %HTTP.Response{} = response}, url) when is_reference(ref) do
    scalar(ref)
    assert {:ok, _} = Envelope.validate_response(response, url)
    {:task, {ref, {:slot, :extra_public_metadata_and_response_heads}}}
  end
  defp message_projection({ref, {:error, reason}}, _) when is_reference(ref) do
    scalar(ref); {:task, {ref, {:error, finite(reason)}}}
  end
  defp message_projection({:stream_chunk, pid, bytes, ref}, _) do
    scalar(pid); scalar(ref); assert is_binary(bytes)
    {:data, {:stream_chunk, pid, binary_slot(bytes, 1_048_576, :data_event), ref}}
  end
  defp message_projection({:stream_trailers, pid, %HTTP.Headers{headers: fields} = headers}, _) do
    scalar(pid); exact(headers, [:__struct__, :headers])
    {:trailers, {:stream_trailers, pid,
      %{headers | headers: fields_slot(fields, 128, 65_536, 67_079, :terminal_trailer_lists)}}}
  end
  defp message_projection({:stream_end, pid} = m, _) do
    scalar(pid); {:stream_end, m}
  end
  defp message_projection({:stream_error, pid, reason}, _) do
    scalar(pid); {:stream_error, {:stream_error, pid, finite(reason)}}
  end
  defp message_projection({:gaoxy_proxy_http, pid, {:ready, upload, limits, deadline}} = m, _) do
    scalar(pid); optional_scalar(upload); limits(limits); time(deadline); {:ready, m}
  end
  defp message_projection({:gaoxy_proxy_http, pid,
    {:transport_handoff, ref, value, identity, deadline}}, _) do
    scalar(pid); scalar(ref); transport(value); time(deadline)
    exact(identity, [:origin, :upstream_protocol, :instance])
    assert identity.upstream_protocol in [:http2, :h2c]
    scalar(identity.instance)
    {:handoff_request, {:gaoxy_proxy_http, pid,
      {:transport_handoff, ref, value,
        %{identity | origin: binary_slot(identity.origin, 65_536, :fixed_configs)}, deadline}}}
  end
  defp message_projection({:gaoxy_proxy_http, pid, {:headers, status, fields}}, _) do
    scalar(pid); assert status in 200..599
    {:delivery, {:gaoxy_proxy_http, pid,
      {:headers, status, fields_slot(fields, 256, 65_536, 68_615, :response_heads)}}}
  end
  defp message_projection({:gaoxy_proxy_http, pid, {:chunk, bytes, ref}}, _) do
    scalar(pid); scalar(ref); assert is_binary(bytes)
    {:delivery, {:gaoxy_proxy_http, pid, {:chunk, binary_slot(bytes, 1_048_576, :data_event), ref}}}
  end
  defp message_projection({:gaoxy_proxy_http, pid, {:end, fields}}, _) do
    scalar(pid)
    {:delivery, {:gaoxy_proxy_http, pid,
      {:end, fields_slot(fields, 128, 65_536, 67_079, :terminal_trailer_lists)}}}
  end
  defp message_projection({:gaoxy_proxy_http, pid, {:error, reason}}, _) do
    scalar(pid); {:delivery, {:gaoxy_proxy_http, pid, {:error, finite(reason)}}}
  end
  defp message_projection({:gaoxy_drain, gate, lease, deadline} = m, _) do
    scalar(gate); scalar(lease); time(deadline); {:drain, m}
  end
  defp message_projection(_, _), do: flunk("unknown control family or expanded wrapper")

  defp config_slot(config) do
    exact(config, [:__struct__, :uri, :cacertfile, :connect_address, :transport,
      :limits, :upstream_protocol, :client])
    assert config.__struct__ == Gaoxy.Proxy.HTTP
    assert config.client == Gaoxy.Proxy.ManagedH2Client
    assert config.upstream_protocol in [:http2, :h2c]
    limits(config.limits)
    if config.uri == nil do
      assert config.transport == nil and config.cacertfile == nil and config.connect_address == nil
    else
      assert :ok = Envelope.validate_config(config)
    end
    bounded(config, 147_456)
    {:slot, :fixed_configs}
  end
  defp request_slot(nil), do: nil
  defp request_slot(request) do
    assert :ok = Envelope.validate_request(request)
    bounded(request, 205_337); {:slot, :request_representations}
  end
  defp checked_slot(nil, _), do: nil
  defp checked_slot(client, protocol) do
    assert :ok = Envelope.validate_checked_client(client, protocol)
    {:slot, :checked_policies}
  end
  defp policy_slot(nil), do: nil
  defp policy_slot(policy) do
    assert :ok = Envelope.validate_trailer_policy(policy)
    bounded(policy, 67_689); {:slot, :trailer_policies}
  end
  defp selector(nil), do: nil
  defp selector({:fixed, config}), do: {:fixed, config_slot(config)}
  defp selector(_), do: flunk("group or unknown selector in fixed H2")
  defp awaiting(nil), do: nil
  defp awaiting(value) do
    exact(value, [:handle, :config]); transport(value.handle)
    %{value | config: config_slot(value.config)}
  end
  defp selection(nil), do: :ok
  defp selection({value, token}), do: (transport(value); scalar(token))

  defp pump_handoff(nil), do: nil
  defp pump_handoff(value) do
    exact(value, [:ref, :handles, :source_pins, :used])
    scalar(value.ref); assert is_boolean(value.used)
    assert length(value.handles) == 1 and length(value.source_pins) == 1
    Enum.each(value.handles, &transport/1); Enum.each(value.source_pins, &pin/1)
    value
  end
  defp transport(value) do
    exact(value, [:provider, :owner, :owner_epoch, :resource])
    assert value.provider == Gaoxy.Proxy.UpstreamTransports
    Enum.each([value.owner, value.owner_epoch, value.resource], &scalar/1)
    bounded(value, 2_048)
  end
  defp pin(value) do
    exact(value, [:provider, :owner, :owner_epoch, :operation, :ref, :handles, :kind, :holder])
    assert value.provider == Gaoxy.Proxy.UpstreamTransports and value.kind == :request
    assert length(value.handles) == 1
    Enum.each(value.handles, &transport/1)
    Enum.each([value.owner, value.owner_epoch, value.operation, value.ref, value.holder], &scalar/1)
    bounded(value, 2_048)
  end

  # Native Exchange payloads already have their own Service lease. Retain ALL
  # public Exchange controls, including the full limits, Body decoder shell,
  # response state, peers and resource pin shells. Only request/body bytes,
  # terminal declaration names and native socket/TLS ownership are replaced.
  defp exchange(value) do
    assert %Gaoxy.HTTP.Exchange{} = value
    exact(value, Map.keys(%Gaoxy.HTTP.Exchange{}))
    assert %Gaoxy.HTTP.Request{} = value.request
    exact(value.request, Map.keys(%Gaoxy.HTTP.Request{}))
    assert byte_size(value.request.method) <= 16
    Enum.each([value.request.target, value.request.path, value.request.query_string,
      value.request.host], fn v -> if v != nil, do: binary_slot(v, 65_536, :native_request) end)
    fields_slot(value.request.headers, 512, 131_072, 147_456, :native_request)
    bounded(value.request, 205_337)
    buffer = binary_slot(value.buffer, 65_536, :native_read_buffer)
    assert %Gaoxy.HTTP.HTTP1.Body{} = value.body
    exact(value.body, [:__struct__, :phase, :total, :trailers, :trailer_bytes, :limits])
    body = %{value.body | trailers:
      fields_slot(value.body.trailers, 256, 131_072, 147_456, :native_request_trailers)}
    bounded(body, 4_096)
    exact(value.limits, [:max_request_line, :max_header_bytes, :max_headers,
      :max_body_bytes, :max_chunk_line, :max_trailer_bytes, :max_trailers,
      :max_read_chunk, :max_buffer_bytes, :request_timeout, :header_timeout,
      :read_timeout, :write_timeout, :max_write_chunk])
    Enum.each(value.limits, fn {key, number} -> assert is_atom(key); unsigned(number) end)
    assert length(value.resource_pins) <= 1
    Enum.each(value.resource_pins, &pin/1)
    projection = %{value | request: {:slot, :native_request}, body: body, buffer: buffer,
      response_trailers: names_slot(value.response_trailers),
      socket: native_socket(value.socket), ssl: native_tls(value.ssl),
      peer_cert: native_certificate(value.peer_cert)}
    # All remaining controls must be finite; no recursive pruning or opaque
    # serialization. The fixed fixture uses no TLS downstream private payload.
    assert finite_controls?(projection, 0)
    bounded(projection, 8_192)
  end
  defp native_socket(%ThousandIsland.Socket{}), do: {:opaque, :native_socket_lease}
  defp native_socket(nil), do: nil
  defp native_socket(_), do: flunk("unknown native socket capability")
  defp native_tls(nil), do: nil
  defp native_tls(_), do: flunk("unexpected downstream TLS policy in control fixture")
  defp native_certificate(nil), do: nil
  defp native_certificate(_), do: flunk("unexpected downstream certificate in control fixture")
  defp names_slot(names) do
    assert is_list(names) and length(names) <= 128
    assert Enum.all?(names, &is_binary/1)
    assert Enum.sum(Enum.map(names, &byte_size/1)) <= 65_536
    assert Enum.sum(Enum.map(names, &:binary.referenced_byte_size/1)) <= 65_536
    bounded(names, 66_183); {:slot, :downstream_declaration_names}
  end

  defp fields_slot(fields, count, bytes, complete, name) do
    assert :ok = Gaoxy.HTTP.RendererBounds.fields(fields, count, bytes)
    bounded(fields, complete); {:slot, name}
  end
  defp binary_slot(nil, _, _), do: nil
  defp binary_slot(value, cap, name) do
    assert is_binary(value)
    assert byte_size(value) <= cap and :binary.referenced_byte_size(value) <= cap
    bounded(value, cap + 6); {:slot, name}
  end
  defp limits(value) do
    exact(value, [:max_chunk_bytes, :opening_timeout, :idle_timeout, :write_timeout, :max_lifetime])
    assert value.max_chunk_bytes in 1..65_536
    Enum.each([:opening_timeout, :idle_timeout, :write_timeout, :max_lifetime],
      fn key -> assert value[key] in 1..86_400_000 end)
  end
  defp finite(reason) do
    result = Session.finite_reason(reason)
    assert finite_shape?(result, 0)
    result
  end
  defp finite_shape?(value, _) when is_atom(value), do: value in [:invalid_request,
    :invalid_policy, :invalid_response, :upstream_failure, :upstream_task,
    :upstream_delivery_limit, :upstream_delivery_overlap, :upstream_trailer_limit,
    :timeout, :request_timeout, :unavailable, :cancelled, :cleanup_pending,
    :cleanup_unconfirmed, :invalid_resource, :invalid_resource_pin,
    :invalid_transport_endpoint, :unauthorized, :retiring, :resource_unavailable]
  defp finite_shape?({kind, reason}, depth) when depth < 3 do
    kind in [:cleanup_failed, :transport_cleanup_failed, :pin_release_failed,
      :service_cleanup_failed, :selection_cleanup_failed] and finite_shape?(reason, depth + 1)
  end
  defp finite_shape?(_, _), do: false
  defp scalar(v), do: (assert(is_pid(v) or is_reference(v)); bounded(v, 2_048))
  defp optional_scalar(nil), do: :ok
  defp optional_scalar(v), do: scalar(v)
  defp optional_time(nil), do: :ok
  defp optional_time(v), do: time(v)
  defp time(v), do: assert(is_integer(v) and v in -9_223_372_036_854_775_808..9_223_372_036_854_775_807)
  defp unsigned(v), do: assert(is_integer(v) and v in 0..18_446_744_073_709_551_615)
  defp exact(value, keys), do: assert(is_map(value) and Enum.sort(Map.keys(value)) == Enum.sort(keys))
  defp bounded(value, cap) do
    assert :erlang.external_size(value) <= cap
    value
  end
  # This validates, never removes, remaining public native control fields.
  # Complete serialization follows validation; no function/opaque private actor
  # or deeply nested diagnostic can enter the measured shell.
  defp finite_controls?(_, depth) when depth > 8, do: false
  defp finite_controls?(value, _) when is_atom(value) or is_pid(value) or is_reference(value),
    do: true
  defp finite_controls?(value, _) when is_integer(value),
    do: value in -9_223_372_036_854_775_808..18_446_744_073_709_551_615
  defp finite_controls?(value, _) when is_binary(value),
    do: byte_size(value) <= 65_536 and :binary.referenced_byte_size(value) <= 65_536
  defp finite_controls?(value, depth) when is_tuple(value),
    do: tuple_size(value) <= 8 and Enum.all?(Tuple.to_list(value), &finite_controls?(&1, depth + 1))
  defp finite_controls?(value, depth) when is_map(value),
    do: map_size(value) <= 32 and Enum.all?(value, fn {k, v} ->
      is_atom(k) and finite_controls?(v, depth + 1) end)
  defp finite_controls?(value, depth) when is_list(value),
    do: length(value) <= 128 and Enum.all?(value, &finite_controls?(&1, depth + 1))
  defp finite_controls?(_, _), do: false
end
