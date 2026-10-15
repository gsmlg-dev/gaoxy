#!/usr/bin/env python3
"""Independent clients and peers against the fixed managed-H2 Gaoxy adapter."""
import argparse
import base64
import gzip
import hashlib
import json
from pathlib import Path
import queue
import subprocess
import sys
import threading
import time
import traceback

from h2_0214_qualification import PEER_IDENTITY, WRAPPER, identity_check

ROOT = Path(__file__).resolve().parents[2]
PEER = ROOT / "apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py"
PYTHON = Path("/tmp/gaoxy-m3-h2-soak-venv/bin/python")
PACKAGES = {"h2": "4.3.0", "hpack": "4.1.0", "hyperframe": "6.1.0"}
CELLS = tuple(downstream + "-to-" + upstream for downstream in ("h1", "h2") for upstream in ("tls", "h2c"))
FUNCTIONAL = ("escaped", "empty-query", "stream", "gzip", "redirect", "upload", "trailers", "head", "204", "205", "304")
CONCURRENT = ("reset", "goaway", "c2", "r32")
CONTROLLED = ("pre-eof-upload", "early-final", "request-trailers")
BOUNDARIES = ("head255", "native-head256", "native-head257", "head-bytes-exact", "head-bytes-over",
              "trailer128", "trailer129", "trailer-bytes-exact", "trailer-bytes-over",
              "inform128", "inform129", "inform-bytes-exact", "inform-bytes-over",
              "declaration128", "declaration129")
NEGATIVES = ("wrong-ca", "wrong-name", "no-alpn")
REQUIRED_CASES = tuple([cell + "/" + name for cell in CELLS for name in FUNCTIONAL] +
                       [cell + "-" + name for cell in CELLS for name in CONCURRENT + CONTROLLED + BOUNDARIES] +
                       list(NEGATIVES))
WIRE_CONSTRAINTS = {
    "final_adapter_field256_257": "Native HPACK counts :status:255 regular fields reach adapter;256/257 reject natively.",
    "informational_field2048": "Valid nonempty names need at least33 bytes/field with accounting overhead;2048*33>65536. Unit coverage remains separate.",
    "connection_declarations": "Connection is forbidden in HTTP/2; repeated128/129 Connection token adapter checks remain pure-unit evidence.",
    "head_bytes": "Explicit content-length0: H1 exact/over65536 complete rendered wire; H2 exact/over65536 proxy field wire. Adapter name+value and native decoded budgets remain separate.",
    "trailer_bytes": "Exact/over65536 native trailer metadata (name+value+32), with smaller adapter logical and downstream wire budgets; pure adapter boundaries remain separate.",
}

HOST = WRAPPER.split("[before_path, after_path, runner | args]")[0] + r'''
defmodule FixedGaoxyIdentity do
  alias HTTPFetch0214Identity, as: Identity
  def record(path) do
    root = File.cwd!() |> Path.expand()
    applications = for app <- [:gaoxy, :gaoxy_http, :gaoxy_proxy] do
      loaded = Application.load(app)
      true = loaded in [:ok, {:error, {:already_loaded, app}}]
      modules = for module <- Application.spec(app, :modules) do
        Code.ensure_loaded!(module)
        {^module, bytes, beam_path} = :code.get_object_code(module)
        beam_path = to_string(beam_path) |> Path.expand()
        true = String.starts_with?(beam_path, root <> "/_build/")
        ^bytes = File.read!(beam_path)
        {:ok, {^module, md5}} = :beam_lib.md5(bytes)
        ^md5 = module.module_info(:md5)
        source = module.module_info(:compile) |> Keyword.fetch!(:source) |> to_string() |> Path.expand()
        true = String.starts_with?(source, Path.join(root, "apps/#{app}") <> "/")
        %{module: to_string(module), beam: Identity.file(beam_path),
          loaded_code_md5: Base.encode16(md5, case: :lower),
          disk_code_md5: Base.encode16(md5, case: :lower), source: Identity.file(source),
          compile_source: source}
      end
      true = modules != []
      %{application: to_string(app), version: to_string(Application.spec(app, :vsn)),
        app: Identity.file(:code.where_is_file(~c"#{app}.app") |> to_string() |> Path.expand()), modules: modules}
    end
    File.write!(path, JSON.encode!(%{pid: System.pid(), root: root, applications: applications}) <> "\n")
  end
end
defmodule FixedManagedH2Host do
  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports
  def deadline, do: System.monotonic_time(:millisecond) + 5000
  def emit(value), do: IO.puts("FIXED_H2_HOST " <> JSON.encode!(value))

  defp admission_projection(app_state) do
    leases = Map.new(app_state.leases, fn {ref, lease} ->
      {ref, {lease.pid, lease.bytes, lease.cleanup, lease.request_active}}
    end)
    cleanups = Map.new(app_state.cleanups, fn {token, cleanup} ->
      {token, {cleanup.lease, cleanup.bytes, cleanup.receipt}}
    end)
    {app_state.service, app_state.mode, app_state.bytes, leases, cleanups}
  end
  defp admission_observer(host, gate, credits) do
    host_ref = Process.monitor(host)
    gate_ref = Process.monitor(gate)
    send(host, {:admission_observer_ready, self()})
    admission_observer_loop(%{host: host, host_ref: host_ref, gate: gate,
      gate_ref: gate_ref, credits: credits, seen: MapSet.new(), count: 0,
      received: 0, high_water: 0, failure: nil})
  end
  defp admission_failure(state, reason) do
    if state.failure == nil, do: send(state.host, {:admission_observer_failure, self(), reason})
    %{state | failure: state.failure || reason}
  end
  defp admission_summary(state) do
    %{observer: inspect(self()), gate: inspect(state.gate), received_raw: state.received,
      distinct: state.count, distinct_bound: 1024, outstanding_bound: 1024,
      outstanding: :atomics.get(state.credits, 1), high_water: state.high_water,
      raw_candidates: :atomics.get(state.credits, 2), adjacent_suppressed: :atomics.get(state.credits, 3),
      rejected_candidates: :atomics.get(state.credits, 4),
      failure: if(state.failure, do: inspect(state.failure, limit: :infinity), else: nil)}
  end
  defp admission_observer_loop(state) do
    receive do
      {:admission_raw, gate, ordinal, app_state, outstanding} when gate == state.gate ->
        state = %{state | high_water: max(state.high_water, outstanding)}
        state = try do
          true = ordinal == state.received + 1
          true = outstanding in 1..1024
          snapshot = admission_snapshot(app_state, gate)
          digest = :crypto.hash(:sha256, :erlang.term_to_binary(snapshot))
          if MapSet.member?(state.seen, digest) do
            state
          else
            true = state.count < 1024
            send(state.host, {:fixed_h2_admission_receipt, Map.put(snapshot, :sequence, state.count + 1)})
            %{state | seen: MapSet.put(state.seen, digest), count: state.count + 1}
          end
        rescue
          error -> admission_failure(state, {:snapshot_exception, error, __STACKTRACE__})
        catch
          kind, reason -> admission_failure(state, {:snapshot_exception, kind, reason})
        end
        :atomics.sub(state.credits, 1, 1)
        admission_observer_loop(%{state | received: ordinal})
      {:admission_overflow, gate, outstanding, ordinal} when gate == state.gate ->
        admission_observer_loop(admission_failure(state, {:collector_overflow, outstanding, ordinal}))
      {:admission_gate_fence, gate, marker} when gate == state.gate ->
        send(state.host, {:admission_observer_fence, self(), marker, admission_summary(state)})
        admission_observer_loop(state)
      {:DOWN, ref, :process, gate, reason} when ref == state.gate_ref and gate == state.gate ->
        state = if :atomics.get(state.credits, 1) == 0, do: state,
          else: admission_failure(state, :outstanding_raw_after_gate_down)
        send(state.host, {:admission_observer_closed, self(),
          Map.put(admission_summary(state), :gate_reason, inspect(reason))})
      {:DOWN, ref, :process, host, reason} when ref == state.host_ref and host == state.host ->
        emit(admission_summary(state) |> Map.put(:event, "admission_observer_host_down")
          |> Map.put(:host_reason, inspect(reason)))
    end
  end
  defp admission_prefix(state, summary, terminal) do
    state = collect_originals(state)
    true = summary.failure == nil and state.admission_observer_failure == nil
    true = summary.distinct <= 1024 and summary.high_water <= 1024
    if terminal do
      true = summary.rejected_candidates == 0
      true = summary.raw_candidates == summary.received_raw + summary.adjacent_suppressed
    end
    count = length(state.admission_receipts)
    true = count >= summary.distinct and (not terminal or count == summary.distinct)
    true = Enum.map(state.admission_receipts, & &1.sequence) ==
      (if count == 0, do: [], else: Enum.to_list(1..count))
    state
  end
  defp finish_admission(%{admission_observer_join: join} = state, _) when not is_nil(join) do
    true = join.reason == ":normal" and join.outstanding == 0
    admission_prefix(state, join, true)
  end
  defp finish_admission(state, expires) do
    observer = state.admission_observer
    summary = receive do
      {:admission_observer_closed, ^observer, summary} -> summary
    after max(0, expires - System.monotonic_time(:millisecond)) ->
      raise "Admission observer terminal fence deadline"
    end
    ref = state.admission_observer_ref
    reason = receive do
      {:DOWN, ^ref, :process, ^observer, reason} -> reason
    after max(0, expires - System.monotonic_time(:millisecond)) ->
      raise "Admission observer join deadline"
    end
    state = %{state | admission_observer_join: Map.put(summary, :reason, inspect(reason))}
    Process.put(:fixed_h2_admission_evidence, state)
    true = reason == :normal and summary.outstanding == 0
    admission_prefix(state, summary, true)
  end
  defp flush_admission(state, expires) do
    if Process.alive?(state.gate) do
      marker = make_ref()
      observer = state.admission_observer
      try do
        :sys.replace_state(state.gate, fn exact_state ->
          send(observer, {:admission_gate_fence, self(), marker})
          exact_state
        end, max(0, expires - System.monotonic_time(:millisecond)))
        receive do
          {:admission_observer_fence, ^observer, ^marker, summary} ->
            admission_prefix(state, summary, false)
          {:DOWN, ref, :process, ^observer, reason} when ref == state.admission_observer_ref ->
            raise "Admission observer ended before live fence: #{inspect(reason)}"
        after max(0, expires - System.monotonic_time(:millisecond)) ->
          raise "Admission observer fence deadline"
        end
      catch
        :exit, reason ->
          if Process.alive?(state.gate), do: exit(reason), else: finish_admission(state, expires)
      end
    else
      finish_admission(state, expires)
    end
  end
  defp admission_host_failure(nil, reason, _),
    do: emit(%{event: "admission_collector_failure", reason: inspect(reason, limit: :infinity)})
  defp admission_host_failure(state, reason, expires) do
    state = Process.get(:fixed_h2_admission_evidence, state)
    state = try do
      flush_admission(state, expires)
    rescue
      _ -> collect_originals(Process.get(:fixed_h2_admission_evidence, state))
    catch
      _, _ -> collect_originals(Process.get(:fixed_h2_admission_evidence, state))
    end
    emit(%{event: "admission_collector_failure", reason: inspect(reason, limit: :infinity),
      admission_receipts: state.admission_receipts, service_failures: state.failures,
      observer_failure: inspect(state.admission_observer_failure, limit: :infinity),
      observer_join: state.admission_observer_join, originals: original_rows(state),
      receipt_coverage: if(state.admission_observer_join, do: "TERMINAL_FENCED", else: "UNCONFIRMED_PREFIX")})
  end
  def run(evidence) do
    for app <- [:http_core, :http_runtime, :http_fetch] do
      {:ok, _} = Application.ensure_all_started(app)
    end
    HTTPFetch0214Identity.record(Path.join(evidence, "host-loaded-before.json"))
    FixedGaoxyIdentity.record(Path.join(evidence, "host-gaoxy-before.json"))
    emit(%{event: "ready", elixir: System.version(), otp: System.otp_release(), pid: System.pid()})
    state = Enum.reduce(IO.stream(:stdio, :line), nil, fn line, state ->
      command = JSON.decode!(line)
      expires = deadline()
      Process.put(:fixed_h2_admission_evidence, state)
      next_state = try do
      case command["op"] do
        "start" ->
          nil = state
          protocol = case command["protocol"] do "tls" -> :http2; "h2c" -> :h2c end
          {:ok, instance} = Gaoxy.start_link()
          Process.unlink(instance)
          {:ok, owner} = Transports.start_link(instance: instance,
            limits: %{max_resources: 2, max_pins: 256, max_request_tokens: 64,
              max_owned_payload_bytes: 4_194_304})
          Process.unlink(owner)
          caller = self()
          debug = fn state, event, _ ->
            case event do
              {:in, {:"$gen_call", _, {:bind_completion, _, token, completion}}} ->
                send(caller, {:fixed_h2_original, token, completion})
              _ -> :ok
            end
            state
          end
          :ok = :sys.install(owner, {make_ref(), debug, nil})
          scheme = if protocol == :http2, do: "https", else: "http"
          origin = scheme <> "://" <> Map.get(command, "hostname", "localhost") <> ":#{command["port"]}"
          trust = if protocol == :http2 do
            for {:Certificate, der, :not_encrypted} <- :public_key.pem_decode(File.read!(command["ca"])), do: der
          end
          {:ok, handle, preparation} = Transports.prepare(owner,
            %{protocol: protocol, origin: origin, connect_address: {127,0,0,1}, trust: trust}, self(), deadline())
          {:ok, pins} = Resources.pin_many([handle], self(), :baseline, deadline())
          :ok = Resources.release(preparation)
          options = [id: :http, endpoint: {Gaoxy.Proxy.HTTP, %{upstream: origin,
            upstream_protocol: protocol, transport: handle}},
            limits: %{max_bytes: 536_870_912, max_active: 64},
            http_limits: %{request_timeout: 10_000, write_timeout: 2000}]
          options = if command["boundary_limits"] do
            Keyword.update!(options, :http_limits, &Map.merge(&1, %{max_headers: 512,
              max_header_bytes: 131_072, max_trailers: 256, max_trailer_bytes: 131_072}))
          else options end
          options = if command["downstream"] == "h2", do: options ++ [protocols: [:http2], h2c: :prior_knowledge], else: options
          options = if command["downstream_tls"] do
            Keyword.merge(options, protocols: [:http2, :http1], transport: :tls,
              h2c: :disabled, tls: %{certfile: command["cert"], keyfile: command["key"]})
          else
            options
          end
          {:ok, spec} = Gaoxy.HTTP.service_spec(options)
          {spec, allowance} = case command["native_clients"] do
            nil ->
              {spec, %{mode: "DEFAULT", max_bytes: spec.limits.max_bytes, max_active: spec.limits.max_active}}
            clients when is_integer(clients) and clients in 1..33 ->
              true = command["downstream"] == "h2"
              reserves = Gaoxy.HTTP.HTTP2.Limits.reservation(
                spec.handler_options.http_limits, spec.handler_options.h2_limits)
              # Each independent client owns C+Writer+one native stream lease.
              # The upstream scope still has exactly32 request slots/C2/P0.
              bytes = max(536_870_912,
                clients * (reserves.connection + reserves.writer + reserves.stream) + 32 * 9_444_956)
              active = max(64, 3 * clients)
              true = bytes <= 8_589_934_592 and active <= 128
              options = Keyword.update!(options, :limits, &Map.merge(&1, %{max_bytes: bytes, max_active: active}))
              {:ok, expanded} = Gaoxy.HTTP.service_spec(options)
              {expanded, %{mode: "DERIVED_CONCURRENT_NATIVE_CLIENTS", native_clients: clients,
                max_bytes: bytes, max_active: active, native_reservations: reserves,
                upstream_request_slots: 32, upstream_request_reservation: 9_444_956}}
            other -> raise "invalid finite native_clients: #{inspect(other)}"
          end
          {:ok, _} = Gaoxy.add(instance, spec)
          {:ok, {_, port}} = Gaoxy.info(instance, :http).local
          {:ok, service, _} = GenServer.call(instance, {:lookup, :http}, 1000)
          gate = :sys.get_state(service).gate
          service_debug = fn seen, event, _ ->
            case event do
              {:noreply, %{cleanup_failed: :cleanup_receipt_missing} = service_state} when not seen ->
                send(caller, {:fixed_h2_service_failure, %{failure: "cleanup_receipt_missing",
                  pending: map_size(service_state.cleanups)}})
                true
              _ -> seen
            end
          end
          :ok = :sys.install(service, {make_ref(), service_debug, false})
          credits = :atomics.new(4, signed: true)
          {admission_observer, admission_observer_ref} = spawn_monitor(fn ->
            admission_observer(caller, gate, credits)
          end)
          receive do
            {:admission_observer_ready, ^admission_observer} -> :ok
          after max(0, expires - System.monotonic_time(:millisecond)) ->
            raise "Admission observer setup deadline"
          end
          admission_debug = fn trace, event, _ ->
            app_state = case event do
              {:out, _, _, app_state} -> app_state
              {:noreply, app_state} -> app_state
              _ -> nil
            end
            if not trace.failed and is_map(app_state) and
                 (trace.active or map_size(app_state.cleanups) > 0 or app_state.mode == :failed) do
              :atomics.add(credits, 2, 1)
              projection = admission_projection(app_state)
              if projection === trace.projection do
                :atomics.add(credits, 3, 1)
                trace
              else
                outstanding = :atomics.add_get(credits, 1, 1)
                if outstanding <= 1024 do
                  ordinal = trace.submitted + 1
                  send(admission_observer, {:admission_raw, gate, ordinal, app_state, outstanding})
                  %{trace | active: true, submitted: ordinal, projection: projection}
                else
                  :atomics.sub(credits, 1, 1)
                  :atomics.add(credits, 4, 1)
                  send(admission_observer, {:admission_overflow, gate, outstanding, trace.submitted + 1})
                  %{trace | failed: true}
                end
              end
            else
              trace
            end
          end
          :ok = :sys.install(gate, {make_ref(), admission_debug,
            %{active: false, submitted: 0, failed: false, projection: nil}})
          scope = :sys.get_state(owner).records[handle.resource].scope
          creators = :sys.get_state(owner).records |> Map.values() |> Enum.map(& &1.custodian)
          joins = Enum.map([instance, owner | creators], &{&1, Process.monitor(&1)})
          state = %{instance: instance, owner: owner, pins: pins, origin: origin,
            scope: scope, originals: %{}, reported: MapSet.new(), failures: [], joins: joins,
            creators: creators, service: service, gate: gate, spec: spec,
            gate_join: {gate, Process.monitor(gate)}, native_joins: %{}, admission_receipts: [],
            admission_observer: admission_observer, admission_observer_ref: admission_observer_ref,
            admission_observer_failure: nil, admission_observer_join: nil}
          emit(%{event: "started", port: port, origin: origin, owner: inspect(owner), instance: inspect(instance),
            native_allowance: allowance})
          state
        "status" ->
          state = flush_admission(state, expires)
          state = collect_originals(state)
          emit(status(state) |> Map.put(:admission_receipts, state.admission_receipts))
          state
        "observe" ->
          state = flush_admission(state, expires)
          state = collect_originals(state)
          emit(status(state) |> Map.put(:event, "observed")
            |> Map.put(:originals, original_rows(state))
            |> Map.put(:original_repeat, original_rows(state))
            |> Map.put(:service_failures, state.failures)
            |> Map.put(:admission_receipts, state.admission_receipts)
            |> Map.put(:admission_terminal_failed, terminal_failed(state.admission_receipts))
            |> Map.put(:owner_ledger, owner_ledger(state.owner)))
          state
        "clean" ->
          state = wait_clean(state, expires)
          state = flush_admission(state, expires)
          state = collect_originals(state)
          originals = original_rows(state)
          true = originals != [] and Enum.all?(originals, &(&1.result == ":ok"))
          emit(status(state) |> Map.put(:event, "clean") |> Map.put(:originals, originals))
          %{state | reported: MapSet.new(Map.keys(state.originals))}
        "request_clean" ->
          {state, ledger} = wait_request_clean(state, expires)
          state = flush_admission(state, expires)
          state = collect_originals(state)
          originals = original_rows(state)
          true = originals != [] and Enum.all?(originals, &(&1.result == ":ok"))
          emit(status(state) |> Map.put(:event, "request_clean") |> Map.put(:originals, originals)
            |> Map.put(:original_repeat, original_rows(state)) |> Map.put(:native_idle, ledger))
          state
        "stop" ->
          state = flush_admission(state, expires)
          state = collect_originals(state)
          before = status(state)
          creators = state.creators
          joins = state.joins
          for pin <- state.pins, do: :ok = Resources.release(pin)
          result = Gaoxy.stop(state.instance, 5000)
          confirmed = result == :ok
          helper_settlement = if not confirmed and Process.alive?(state.owner),
            do: settle_owner_helpers(state.owner, creators, deadline(), result), else: nil
          retained = if Process.alive?(state.owner), do: elem(Transports.status(state.owner), 1), else: nil
          retained_ledger = if Process.alive?(state.owner), do: owner_ledger(state.owner), else: nil
          forced = not confirmed and Process.alive?(state.owner)
          disposals = if forced do
            for pid <- creators ++ [state.owner], Process.alive?(pid) do
              :ok = GenServer.stop(pid, :normal, 5000)
              %{pid: inspect(pid), outcome: "TEST_OWNED_DISPOSAL_AFTER_UNCONFIRMED_PUBLIC_STOP"}
            end
          else [] end
          reasons = Enum.map(joins, fn {pid, ref} ->
            receive do
              {:DOWN, ^ref, :process, ^pid, reason} -> %{pid: inspect(pid), reason: inspect(reason)}
            after 5000 -> raise "host actor join deadline" end
          end)
          native_joins = Enum.map(state.native_joins, fn {pid, ref} -> joined(pid, ref) end)
          {gate, gate_ref} = state.gate_join
          gate_join = joined(gate, gate_ref)
          state = finish_admission(state, expires)
          state = collect_originals(state)
          emit(%{event: "stopped", cleanup_confirmed: confirmed, public_result: inspect(result),
            before: before, retained: retained, originals: original_rows(state),
            original_repeat: original_rows(state), service_failures: state.failures,
            forced_test_disposal: forced, test_disposals: disposals, joins: reasons,
            native_joins: native_joins, gate_join: gate_join,
            admission_receipts: state.admission_receipts, retained_owner_ledger: retained_ledger,
            admission_observer: state.admission_observer_join,
            helper_settlement: helper_settlement,
            admission_terminal_failed: terminal_failed(state.admission_receipts),
            public_stop: public_stop(result), terminal_service_alive: Process.alive?(state.service),
            terminal_gate_alive: Process.alive?(state.gate)})
          nil
        "exit" ->
          nil = state
          HTTPFetch0214Identity.record(Path.join(evidence, "host-loaded-after.json"))
          FixedGaoxyIdentity.record(Path.join(evidence, "host-gaoxy-after.json"))
          emit(%{event: "exited"})
          System.halt(0)
      end
      rescue
        error ->
          admission_host_failure(state, error, expires)
          reraise error, __STACKTRACE__
      catch
        kind, reason ->
          admission_host_failure(state, {kind, reason}, expires)
          :erlang.raise(kind, reason, __STACKTRACE__)
      end
      Process.put(:fixed_h2_admission_evidence, next_state)
      next_state
    end)
    if state != nil, do: raise("host stdin ended with live fixture")
  end
  defp status(state) do
    {:ok, owner} = Transports.status(state.owner)
    service = Gaoxy.status(state.instance, :http)
    service = case service do
      %{} -> Map.take(service, [:active, :cleanup_pending, :retained_bytes, :cleanup_failed, :state])
        |> Map.update(:cleanup_failed, nil, fn reason -> if reason == nil, do: nil, else: inspect(reason) end)
      other -> %{public_result: inspect(other)}
    end
    snapshot = case HTTP.ManagedTransport.snapshot(state.scope, 1000) do
      {:ok, snapshot} -> snapshot
      other -> %{public_result: inspect(other)}
    end
    %{event: "status", service: service, owner: owner, native_scope: snapshot,
      instance: inspect(state.instance), owner_pid: inspect(state.owner),
      service_pid: inspect(state.service), gate_pid: inspect(state.gate),
      service_alive: Process.alive?(state.service), gate_alive: Process.alive?(state.gate)}
  end
  defp collect_originals(state) do
    receive do
      {:fixed_h2_original, token, completion} ->
        collect_originals(%{state | originals: Map.put(state.originals, token, completion)})
      {:fixed_h2_service_failure, failure} ->
        collect_originals(%{state | failures: [failure | state.failures]})
      {:admission_observer_failure, observer, reason} when observer == state.admission_observer ->
        collect_originals(%{state | admission_observer_failure: reason})
      {:fixed_h2_admission_receipt, receipt} ->
        collect_originals(%{state | admission_receipts: state.admission_receipts ++ [receipt]})
    after 0 ->
      Process.put(:fixed_h2_admission_evidence, state)
      state
    end
  end
  defp original_rows(state) do
    for {token, completion} <- state.originals, not MapSet.member?(state.reported, token) do
      %{token: inspect(token), result: inspect(HTTP.RequestCompletion.await(completion, 0))}
    end |> Enum.sort_by(& &1.token)
  end
  defp joined(pid, ref) do
    receive do
      {:DOWN, ^ref, :process, ^pid, reason} -> %{pid: inspect(pid), reason: inspect(reason)}
    after 5000 -> raise "native actor join deadline: #{inspect(pid)}" end
  end
  defp public_stop(:ok), do: %{kind: "confirmed"}
  defp public_stop({:error, {:shutdown, services, participants}}) do
    %{kind: "shutdown", services: Enum.map(services, &inspect/1),
      participants: Enum.map(participants, fn {registration, result} ->
        %{registration: inspect(registration), result: inspect(result)}
      end)}
  end
  defp public_stop(other), do: %{kind: "other", result: inspect(other)}
  defp terminal_failed(receipts), do: Enum.find(Enum.reverse(receipts), &(&1.mode == ":failed"))
  defp admission_snapshot(app_state, gate) do
    leases = for {ref, lease} <- app_state.leases do
      %{lease: inspect(ref), owner: inspect(lease.pid), bytes: lease.bytes,
        cleanup: if(lease.cleanup, do: inspect(lease.cleanup), else: nil), request_active: lease.request_active}
    end |> Enum.sort_by(& &1.lease)
    cleanups = for {token, cleanup} <- app_state.cleanups do
      %{token: inspect(token), lease: inspect(cleanup.lease), bytes: cleanup.bytes, receipt: cleanup.receipt}
    end |> Enum.sort_by(& &1.token)
    lease_bytes = Enum.sum(Enum.map(leases, & &1.bytes))
    cleanup_bytes = Enum.sum(Enum.map(cleanups, & &1.bytes))
    true = app_state.bytes == lease_bytes + cleanup_bytes
    %{gate: inspect(gate), service: inspect(app_state.service), mode: inspect(app_state.mode),
      leases: leases, cleanups: cleanups, lease_bytes: lease_bytes, cleanup_bytes: cleanup_bytes,
      retained_bytes: app_state.bytes, active: length(leases), cleanup_pending: length(cleanups),
      total_invariant: true}
  end
  defp owner_ledger(owner) do
    app_state = :sys.get_state(owner, 1000)
    resources = for {ref, entry} <- app_state.records do
      %{resource: inspect(ref), payload_bytes: entry.payload_bytes,
        lifecycle: inspect(entry.lifecycle), transport_confirmed: entry.transport_confirmed}
    end |> Enum.sort_by(& &1.resource)
    tokens = for {token, hold} <- app_state.tokens do
      %{token: inspect(token), resource: inspect(hold.resource), payload_bytes: hold.payload_bytes,
        original_result: if(hold.completion, do: inspect(HTTP.RequestCompletion.await(hold.completion, 0)), else: nil)}
    end |> Enum.sort_by(& &1.token)
    pins = for {ref, pin} <- app_state.pins do
      %{pin: inspect(ref), payload_bytes: :erlang.external_size(pin)}
    end |> Enum.sort_by(& &1.pin)
    %{owner: inspect(owner), resources: resources, tokens: tokens, pins: pins,
      owned_serialized_payload_bytes: Enum.sum(Enum.map(resources ++ tokens ++ pins, & &1.payload_bytes))}
  end
  defp settle_owner_helpers(owner, creators, expires, result) do
    caller = self()
    tag = make_ref()
    debug = fn previous, event, _ ->
      case event do
        {:out, _, _, _} -> send(caller, {:fixed_h2_helper_progress, tag})
        {:noreply, _} -> send(caller, {:fixed_h2_helper_progress, tag})
        _ -> :ok
      end
      previous
    end
    :ok = :sys.install(owner, {tag, debug, nil}, helper_timeout(expires))
    creator_monitors = Map.new(creators, fn pid -> {Process.monitor(pid), %{pid: pid, reason: nil}} end)
    try do
      abort_required = result == {:error, {:deadline_exceeded, :cleanup_pending}}
      wait_owner_helpers(owner, creators, tag, expires, %{}, creator_monitors, abort_required)
    after
      for {ref, _} <- creator_monitors, do: Process.demonitor(ref, [:flush])
      if Process.alive?(owner), do: :sys.remove(owner, tag, 1000)
    end
  end
  defp helper_timeout(expires) do
    remaining = Gaoxy.Lifecycle.remaining(expires)
    if remaining == 0, do: raise("owner helper settlement deadline; no test-owned disposal")
    min(1000, remaining)
  end
  defp creator_state(creator, expires) do
    if Process.alive?(creator), do: :sys.get_state(creator, helper_timeout(expires)), else: nil
  catch
    :exit, {:noproc, _} -> nil
    :exit, {:normal, _} -> nil
  end
  defp wait_owner_helpers(owner, creators, tag, expires, monitors, creator_monitors, abort_required) do
    app_state = :sys.get_state(owner, helper_timeout(expires))
    retirement_mode = if app_state.retirement, do: app_state.retirement.mode, else: nil
    tokens = for {token, hold} <- app_state.tokens do
      %{token: inspect(token), guardian: inspect(hold.guardian), guardian_down: hold.guardian_down,
        completion_bound: hold.completion != nil,
        original_result: if(hold.completion, do: inspect(HTTP.RequestCompletion.await(hold.completion, 0)), else: nil)}
    end |> Enum.sort_by(& &1.token)
    tokens_ready = Enum.all?(tokens, &(&1.completion_bound and &1.guardian_down))
    creator_states = Map.new(creators, &{&1, creator_state(&1, expires)})
    creator_receipts = for {_, hold} <- creator_monitors do
      custodian = creator_states[hold.pid]
      failed_entry = Enum.any?(app_state.records, fn {_, entry} ->
        entry.custodian == hold.pid and entry.lifecycle == :failed and not entry.transport_confirmed
      end)
      owner_down = Enum.all?(app_state.records, fn {_, entry} ->
        entry.custodian != hold.pid or entry.custodian_down
      end)
      # Failed Custodians deliberately remain alive. Both initiation slots and
      # their entire two-call budget must settle before test-owned disposal.
      terminal_failed = custodian != nil and failed_entry and custodian.failed and
        custodian.mode == :abort and custodian.control_calls == 2 and
        custodian.retire_helper == nil and custodian.retry_helper == nil
      %{pid: inspect(hold.pid), down: hold.reason != nil, reason: hold.reason, owner_down: owner_down,
        terminal_failed: terminal_failed,
        failed: if(custodian, do: custodian.failed, else: nil),
        mode: if(custodian, do: inspect(custodian.mode), else: nil),
        control_calls: if(custodian, do: custodian.control_calls, else: nil),
        retire_helper_empty: if(custodian, do: custodian.retire_helper == nil, else: nil),
        retry_helper_empty: if(custodian, do: custodian.retry_helper == nil, else: nil)}
    end |> Enum.sort_by(& &1.pid)
    creators_ready = Enum.all?(creator_receipts, &((&1.down and &1.owner_down) or &1.terminal_failed))
    phase = %{instance_down: app_state.instance_down, retirement_mode: inspect(retirement_mode),
      abort_required: abort_required, abort_phase_ready: retirement_mode == :abort,
      tokens_ready: tokens_ready, tokens: tokens, creators_ready: creators_ready, creators: creator_receipts}
    phase_ready = app_state.instance_down and (not abort_required or phase.abort_phase_ready) and
      tokens_ready and creators_ready
    resource_helpers = for {resource, entry} <- app_state.records, {pid, hold} <- entry.helpers,
      do: {pid, %{kind: "custodian", resource: inspect(resource), down: hold.down, finished: hold.finished}}
    request_helpers = for {token, hold} <- app_state.tokens, hold.abort_helper != nil,
      do: {elem(hold.abort_helper, 0), %{kind: "request_abort", token: inspect(token), down: hold.abort_down,
        finished: hold.abort_result != nil}}
    custodian_helpers = for {creator, custodian} <- creator_states, custodian != nil,
      slot <- [:retire_helper, :retry_helper], custodian[slot] != nil,
      do: {elem(custodian[slot], 0), %{kind: "custodian_slot", custodian: inspect(creator), slot: to_string(slot)}}
    helpers = resource_helpers ++ request_helpers ++ custodian_helpers
    openings = for {resource, entry} <- app_state.records, entry.opening, do: inspect(resource)
    known = MapSet.new(Enum.map(monitors, fn {_, hold} -> hold.pid end))
    monitors = Enum.reduce(helpers, monitors, fn {pid, row}, acc ->
      if MapSet.member?(known, pid) or Enum.any?(acc, fn {_, hold} -> hold.pid == pid end), do: acc,
        else: Map.put(acc, Process.monitor(pid), %{pid: pid, row: row, reason: nil})
    end)
    rows = Enum.map(helpers, fn {pid, row} -> Map.put(row, :pid, inspect(pid)) end)
    joined = Enum.all?(monitors, fn {_, hold} -> hold.reason != nil end)
    if phase_ready and helpers == [] and openings == [] and joined do
      {:ok, %{helpers: 0}} = Transports.status(owner)
      Map.merge(phase, %{settled: true, helpers: 0, openings: [], joins: Enum.map(monitors, fn {_, hold} ->
        Map.merge(hold.row, %{pid: inspect(hold.pid), reason: hold.reason})
      end) |> Enum.sort_by(& &1.pid)})
    else
      emit(Map.merge(phase, %{event: "owner_helper_settlement", owner: inspect(owner), helpers: rows, openings: openings}))
      receive do
        {:fixed_h2_helper_progress, ^tag} ->
          wait_owner_helpers(owner, creators, tag, expires, monitors, creator_monitors, abort_required)
        {:DOWN, ref, :process, pid, reason} when is_map_key(monitors, ref) ->
          ^pid = monitors[ref].pid
          monitors = Map.update!(monitors, ref, &%{&1 | reason: inspect(reason)})
          wait_owner_helpers(owner, creators, tag, expires, monitors, creator_monitors, abort_required)
        {:DOWN, ref, :process, pid, reason} when is_map_key(creator_monitors, ref) ->
          ^pid = creator_monitors[ref].pid
          creator_monitors = Map.update!(creator_monitors, ref, &%{&1 | reason: inspect(reason)})
          wait_owner_helpers(owner, creators, tag, expires, monitors, creator_monitors, abort_required)
      after Gaoxy.Lifecycle.remaining(expires) ->
        raise "owner helper settlement deadline; no test-owned disposal: #{inspect({phase, rows})}"
      end
    end
  end
  defp ready_native_snapshot(state, reserves, expires) do
    if System.monotonic_time(:millisecond) >= expires, do: raise("native Writer readiness deadline")
    gate = :sys.get_state(state.gate, max(1, min(1000, Gaoxy.Lifecycle.remaining(expires))))
    connections = for {ref, lease} <- gate.leases, lease.bytes == reserves.connection, do: {ref, lease.pid}
    native_states = for {_, pid} <- connections, into: %{} do
      {_, native} = :sys.get_state(pid, max(1, min(1000, Gaoxy.Lifecycle.remaining(expires))))
      {pid, native}
    end
    if Enum.all?(native_states, fn {_, native} -> native.writer_ready == true end) do
      # Writer readiness is emitted only after its real Admission acquire.
      # Never classify the stale pre-readiness gate that may contain2C+1W.
      fresh = :sys.get_state(state.gate, max(1, min(1000, Gaoxy.Lifecycle.remaining(expires))))
      fresh_connections = for {ref, lease} <- fresh.leases, lease.bytes == reserves.connection, do: {ref, lease.pid}
      if MapSet.new(fresh_connections) == MapSet.new(connections) do
        {fresh, native_states}
      else
        ready_native_snapshot(state, reserves, expires)
      end
    else
      receive do after 1 -> :ok end
      ready_native_snapshot(state, reserves, expires)
    end
  end
  defp idle_ledger(state, expires) do
    reserves = Gaoxy.HTTP.HTTP2.Limits.reservation(
      state.spec.handler_options.http_limits, state.spec.handler_options.h2_limits)
    {gate, native_states} = ready_native_snapshot(state, reserves, expires)
    leases = Enum.to_list(gate.leases)
    diagnostic = for {ref, lease} <- leases do
      native = Map.get(native_states, lease.pid)
      %{pid: inspect(lease.pid), lease: inspect(ref), bytes: lease.bytes,
        request_active: lease.request_active, cleanup: inspect(lease.cleanup), send: inspect(lease.send),
        token: inspect(lease.token), timer: inspect(lease.timer), deadline: lease.deadline,
        native: if(native, do: %{phase: inspect(native.phase), lease: inspect(native.lease),
          writer: inspect(native.writer), preface: native.preface, streams: map_size(native.streams),
          buffer_bytes: byte_size(native.buffer), writer_ready: native.writer_ready}, else: nil)}
    end
    emit(%{event: "native_idle_snapshot", reservations: reserves, leases: diagnostic, status: status(state)})
    connections = for {ref, lease} <- leases, lease.bytes == reserves.connection do
      # This is the documented callback state of Gaoxy.HTTP.Connection, not a
      # private upstream dependency process or an opaque capability interior.
      native = Map.fetch!(native_states, lease.pid)
      true = native.gate == state.gate and native.lease == ref and native.phase == :http2
      true = native.writer_ready == true
      true = native.reserves == reserves and native.streams == %{} and native.starting == nil
      true = native.buffer == "" and native.inflight == nil and native.inflight_write == nil
      true = native.outgoing_block == nil and :queue.is_empty(native.output)
      %{pid: lease.pid, writer: native.writer, preface: native.preface, lease: ref}
    end
    true = connections != []
    true = length(Enum.uniq_by(connections, & &1.pid)) == length(connections)
    rows = for {ref, lease} <- leases do
      true = not lease.request_active and lease.cleanup == nil and lease.send == nil
      true = lease.token == nil and lease.timer == nil and lease.deadline == nil and lease.drain_notify
      true = Process.alive?(lease.pid)
      connection = Enum.find(connections, &(&1.pid == lease.pid and &1.lease == ref))
      writer = Enum.find(connections, &(&1.writer == lease.pid))
      cond do
        connection ->
          %{pid: lease.pid, lease: ref, class: "native_h2_connection", bytes: reserves.connection,
            preface: connection.preface, writer: inspect(connection.writer)}
        writer ->
          true = lease.bytes == reserves.writer
          %{pid: lease.pid, lease: ref, class: "native_h2_writer", bytes: reserves.writer,
            connection: inspect(writer.pid)}
        true -> raise "unclassified native idle lease: #{inspect({ref, lease})}"
      end
    end
    writers = Enum.filter(rows, &(&1.class == "native_h2_writer"))
    true = length(writers) == length(connections)
    true = Enum.all?(connections, fn connection ->
      Enum.count(writers, &(&1.pid == connection.writer)) == 1
    end)
    true = length(Enum.uniq_by(rows, & &1.pid)) == length(rows)
    true = map_size(gate.cleanups) == 0
    bytes = Enum.sum(Enum.map(rows, & &1.bytes))
    true = gate.bytes == bytes
    current = status(state)
    true = current.service.active == length(rows) and current.service.retained_bytes == bytes
    true = current.service.cleanup_pending == 0 and current.service.cleanup_failed == nil
    true = match?(%{request_tokens: 0, helpers: 0, pins: 1, resources: 1, reserved_connections: 2}, current.owner)
    true = current.native_scope.active_requests == 0 and current.native_scope.preparing_requests == 0
    true = current.native_scope.pending == 0
    {rows, %{active: length(rows), retained_bytes: bytes, reservations: reserves,
      leases: Enum.map(rows, fn row -> row |> Map.update!(:pid, &inspect/1) |> Map.update!(:lease, &inspect/1) end)}}
  end
  defp wait_request_clean(state, expires) do
    current = status(state)
    settled = current.service.cleanup_pending == 0 and current.service.cleanup_failed == nil and
      match?(%{request_tokens: 0, helpers: 0, pins: 1}, current.owner)
    if settled do
      {rows, ledger} = idle_ledger(state, expires)
      monitors = Enum.reduce(rows, state.native_joins, fn row, monitors ->
        Map.put_new_lazy(monitors, row.pid, fn -> Process.monitor(row.pid) end)
      end)
      {%{state | native_joins: monitors}, ledger}
    else
      if System.monotonic_time(:millisecond) >= expires, do: raise("request cleanup deadline: #{inspect(current)}")
      receive do after 1 -> :ok end
      wait_request_clean(state, expires)
    end
  end
  defp wait_clean(state, expires) do
    state = collect_originals(state)
    current = status(state)
    clean = match?(%{active: 0, cleanup_pending: 0, retained_bytes: 0, cleanup_failed: nil}, current.service) and
      match?(%{request_tokens: 0, helpers: 0, pins: 1, resources: 1, reserved_connections: 2}, current.owner)
    if clean do
      state
    else
      if System.monotonic_time(:millisecond) >= expires, do: raise("clean deadline: #{inspect(current)}")
      receive do after 1 -> :ok end
      wait_clean(state, expires)
    end
  end
end
[evidence] = System.argv()
FixedManagedH2Host.run(evidence)
'''


def require(value, message):
    if not value:
        raise AssertionError(message)


def inventory():
    paths = set(ROOT.glob("apps/*/lib/**/*.ex")) | set(ROOT.glob("apps/*/test/**/*.exs"))
    paths.update(ROOT.glob("integration/http_fetch_contract/*"))
    paths.update(ROOT.glob("apps/*/mix.exs"))
    paths.update(ROOT.glob("config/**/*"))
    paths.update(ROOT / name for name in ("mix.exs", "mix.lock", "flake.nix", "flake.lock",
                 "docs/designs/m3-managed-h2-fixed-endpoint.md", "docs/plans/m3-managed-h2-fixed-endpoint.md",
                 "docs/acceptance/m3-managed-h2-fixed-endpoint.md"))
    paths.add(PEER)
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(paths) if path.is_file()}


def candidate_identity_check(directory):
    directory = Path(directory)
    before = json.loads((directory / "host-gaoxy-before.json").read_text())
    after = json.loads((directory / "host-gaoxy-after.json").read_text())
    require(before == after and before["root"] == str(ROOT), "actual HOST candidate identity changed")
    require({app["application"] for app in before["applications"]} == {"gaoxy", "gaoxy_http", "gaoxy_proxy"},
            "candidate applications incomplete")
    sources = inventory()
    for app in before["applications"]:
        require(app["modules"] and len({module["module"] for module in app["modules"]}) == len(app["modules"]),
                "candidate loaded module manifest incomplete")
        for record in [app["app"], *(module["beam"] for module in app["modules"])]:
            path = Path(record["path"])
            require(path.is_relative_to(ROOT / "_build") and
                    hashlib.sha256(path.read_bytes()).hexdigest() == record["sha256"],
                    "candidate build identity differs from actual HOST")
        for module in app["modules"]:
            source = Path(module["source"]["path"])
            require(source.is_relative_to(ROOT / "apps" / app["application"]) and
                    str(source) == module["compile_source"] and
                    sources[str(source.relative_to(ROOT))] == module["source"]["sha256"] and
                    module["loaded_code_md5"] == module["disk_code_md5"],
                    "loaded candidate module/source binding mismatch")
    return before


def toolchain_identity():
    result = subprocess.run([str(PYTHON), "-c", PEER_IDENTITY], cwd=ROOT,
                            capture_output=True, text=True, check=True, timeout=20)
    identity = json.loads(result.stdout)
    require(identity["packages"] == PACKAGES, "independent Python toolchain differs from pinned versions")
    return identity


def execution_manifest(cases):
    executed = [case["case"] for case in cases]
    require(len(executed) == len(set(executed)), "duplicate counted cohort")
    required, actual = set(REQUIRED_CASES), set(executed)
    return dict(required=list(REQUIRED_CASES), executed=executed,
                missing=sorted(required - actual), unexpected=sorted(actual - required),
                exclusions=[], skips=[], complete=actual == required and all(case["status"] == "PASS" for case in cases))


class Process:
    def __init__(self, command, log, prefix=""):
        self.log = log.open("x")
        self.prefix, self.events, self.seen = prefix, queue.Queue(), []
        self.backlog = []
        self.process = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        self.reader = threading.Thread(target=self.read)
        self.reader.start()

    def read(self):
        try:
            for line in self.process.stdout:
                self.log.write(line)
                self.log.flush()
                if line.startswith(self.prefix):
                    try:
                        event = json.loads(line[len(self.prefix):])
                    except json.JSONDecodeError:
                        continue
                    self.seen.append(event)
                    self.events.put(event)
        finally:
            self.events.put({"event": "process_eof"})

    def send(self, value):
        self.process.stdin.write(json.dumps(value) + "\n")
        self.process.stdin.flush()

    def event(self, name, timeout=20, predicate=None):
        deadline = time.monotonic() + timeout
        names = (name,) if isinstance(name, str) else name
        matches = lambda event: event.get("event") in names and (predicate is None or predicate(event))
        for index, event in enumerate(self.backlog):
            if matches(event):
                return self.backlog.pop(index)
        while time.monotonic() < deadline:
            event = self.events.get(timeout=max(0.001, deadline - time.monotonic()))
            require(event.get("event") not in ("failure", "process_eof"), repr(event))
            if matches(event):
                return event
            self.backlog.append(event)
        raise TimeoutError("missing event " + repr(names))

    def join(self):
        code = self.process.wait(timeout=15)
        self.reader.join(5)
        require(not self.reader.is_alive(), "process output reader failed to join")
        self.log.close()
        require(code == 0, "process failed with exit " + str(code))

    def dispose(self):
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=5)
        self.reader.join(5)
        self.log.close()


def downstream_client(directory, name, started, downstream, target, method="GET", body=b"", fields=()):
    command = [str(PYTHON), str(PEER), "--client", "--downstream", downstream,
               "--port", str(started["port"]), "--target", target, "--method", method,
               "--body64", base64.b64encode(body).decode(), "--headers-json", json.dumps(fields)]
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=25)
    (directory / (name + "-client.log")).write_text(result.stdout + result.stderr)
    require(result.returncode == 0, "independent client failure: " + result.stdout[-2000:])
    response = json.loads(result.stdout)
    require(response["protocol"] == ("http/1.1" if downstream == "h1" else "h2c"), "actual downstream protocol mismatch")
    require(response["identity"]["packages"] == PACKAGES and response["socket_closed"], "independent client identity/join mismatch")
    require(response["body_bytes"] == len(base64.b64decode(response["body64"])) and
            response["body_sha256"] == hashlib.sha256(base64.b64decode(response["body64"])).hexdigest(), "client body evidence mismatch")
    return response


def client_actor(directory, name, started, downstream, target, actors, method="GET", fields=(),
                 controlled=False, incomplete=False):
    command = [str(PYTHON), str(PEER), "--client", "--events", "--downstream", downstream,
               "--port", str(started["port"]), "--target", target, "--method", method,
               "--headers-json", json.dumps(fields)]
    if controlled:
        command.append("--controlled")
    if incomplete:
        command.append("--allow-incomplete")
    actor = Process(command, directory / (name + "-client.log"))
    actors.append(actor)
    return actor


def client_result(actor, downstream, status, body, complete=True):
    result = actor.event("client_response")
    require(result["protocol"] == ("http/1.1" if downstream == "h1" else "h2c"),
            "concurrent client protocol mismatch")
    require(result["identity"]["packages"] == PACKAGES and result["socket_closed"] and
            result["upload_helper_joined"], "concurrent client identity/join mismatch")
    data = base64.b64decode(result["body64"], validate=True)
    require(result["status"] == status and data == body and result["body_bytes"] == len(data)
            and result["body_sha256"] == hashlib.sha256(data).hexdigest(), "exact response mismatch")
    require(result["complete"] is complete, "unexpected response completion")
    expected_terminal = "complete" if complete else ("eof" if downstream == "h1" else "reset")
    require(result["termination"] == expected_terminal, "unexpected downstream terminal event")
    actor.join()
    return result


def fixture(directory, name, protocol, downstream, host, actors, max_streams=None, boundary_limits=False,
            native_clients=None):
    command = [str(PYTHON), str(PEER), "--protocol", protocol, "--manual"]
    if max_streams is not None:
        command += ["--max-streams", str(max_streams)]
    peer = Process(command, directory / (name + "-peer.log"))
    actors.append(peer)
    ready = peer.event("ready")
    require(ready["identity"]["packages"] == PACKAGES, "cohort peer identity mismatch")
    host.send(dict(op="start", protocol=protocol, port=ready["port"], ca=ready["ca"], downstream=downstream,
                   boundary_limits=boundary_limits, native_clients=native_clients))
    return peer, ready, host.event("started")


def request_event(peer, target):
    return peer.event("request", predicate=lambda event: event["target"] == target)


def peer_command(peer, request, operation, **values):
    identifier = "command-" + str(len(peer.seen)) + "-" + operation
    peer.send(dict(op=operation, connection=request["connection"], stream=request["stream"],
                   command_id=identifier, **values))
    receipt = peer.event("command", predicate=lambda event: event.get("command_id") == identifier)
    require(receipt["op"] == operation and receipt["connection"] == request["connection"] and
            receipt["stream"] == request["stream"], "peer command correlation mismatch")
    for key in ("code", "last_stream", "max_streams"):
        if key in values:
            require(receipt[key] == values[key], "peer command parameter mismatch")
    return receipt


def observe(host):
    host.send({"op": "observe"})
    return host.event("observed")


def rejection_observation(host):
    expires = time.monotonic() + 5
    while True:
        value = observe(host)
        originals = value["originals"]
        if len(originals) == 1:
            result = originals[0]["result"]
            confirmed = (result == ":ok" and value["owner"]["request_tokens"] == 0 and
                         value["owner"]["helpers"] == 0 and value["service"].get("cleanup_pending") == 0)
            failed = (result == "{:error, :cleanup_unconfirmed}" and
                      not value["service_alive"] and not value["gate_alive"] and
                      value["service_failures"] == [{"failure": "cleanup_receipt_missing", "pending": 0}])
            if confirmed or failed:
                return value
            require(result in (":ok", "{:error, :cleanup_pending}", "{:error, :cleanup_unconfirmed}"),
                    "unexpected TLS rejection original result")
        else:
            require(not originals, "TLS rejection created multiple original requests")
        require(time.monotonic() < expires, "TLS rejection original/timeline observation deadline")


def rejection_cleanup(observed, stopped):
    originals = observed["originals"]
    require(len(originals) == 1 and originals == observed["original_repeat"] ==
            stopped["originals"] == stopped["original_repeat"], "TLS rejection original identity/result changed")
    result = originals[0]["result"]
    require(result in (":ok", "{:error, :cleanup_unconfirmed}"), "TLS rejection original was not terminal")
    receipts = stopped["admission_receipts"]
    require(0 < len(receipts) <= 1024 and observed["admission_receipts"] == receipts[:len(observed["admission_receipts"])],
            "TLS rejection lost immutable live Admission receipts")
    require([row["sequence"] for row in receipts] == list(range(1, len(receipts) + 1)),
            "Admission receipt sequence incomplete")
    for snapshot in receipts:
        require(snapshot["gate"] == observed["gate_pid"] and snapshot["service"] == observed["service_pid"] and
                snapshot["total_invariant"] and snapshot["active"] == len(snapshot["leases"]) and
                snapshot["cleanup_pending"] == len(snapshot["cleanups"]), "Admission live identity/count mismatch")
        require(snapshot["lease_bytes"] == sum(row["bytes"] for row in snapshot["leases"]) and
                snapshot["cleanup_bytes"] == sum(row["bytes"] for row in snapshot["cleanups"]) and
                snapshot["retained_bytes"] == snapshot["lease_bytes"] + snapshot["cleanup_bytes"],
                "actual Admission retained reserve sum changed")
    holds = [(snapshot, cleanup) for snapshot in receipts for cleanup in snapshot["cleanups"]]
    require(holds and len({row["token"] for _, row in holds}) == 1 and
            all(row["bytes"] == 9_444_956 for _, row in holds), "TLS rejection lacked exact live cleanup reservation")
    attached = [(snapshot, cleanup) for snapshot, cleanup in holds if not cleanup["receipt"] and
                any(lease["lease"] == cleanup["lease"] and lease["cleanup"] == cleanup["token"] and
                    lease["request_active"] for lease in snapshot["leases"])]
    require(attached, "exact request reservation was not attached to its actual live lease")
    live, hold = attached[0]

    def payload_matches(ledger, public):
        require(ledger["owner"] == observed["owner_pid"] and
                len(ledger["resources"]) == public["resources"] and len(ledger["tokens"]) == public["request_tokens"],
                "TLS rejection retained owner identities/counts changed")
        total = sum(row["payload_bytes"] for group in ("resources", "tokens", "pins") for row in ledger[group])
        require(total == ledger["owned_serialized_payload_bytes"] == public["owned_serialized_payload_bytes"] and
                0 < total <= public["limits"]["max_owned_payload_bytes"], "actual retained owner payload sum changed")

    payload_matches(observed["owner_ledger"], observed["owner"])
    require(stopped["terminal_service_alive"] is False and stopped["terminal_gate_alive"] is False and
            stopped["gate_join"] == {"pid": observed["gate_pid"], "reason": ":killed"},
            "TLS rejection Service/gate disappearance lacked actual join evidence")
    if result == ":ok":
        require(any(cleanup["receipt"] for _, cleanup in holds) and
                stopped["admission_terminal_failed"] is None and not stopped["service_failures"] and
                not observed["service_failures"], "confirmed original lacked actual positive cleanup receipt")
        require(stopped["public_stop"] == {"kind": "confirmed"} and stopped["public_result"] == ":ok" and
                stopped["cleanup_confirmed"] and not stopped["forced_test_disposal"] and not stopped["test_disposals"],
                "confirmed TLS original did not have confirmed public shutdown")
        require(observed["owner"]["request_tokens"] == 0 and observed["owner"]["helpers"] == 0,
                "confirmed TLS original retained request holds")
        cleanup_status = "PASS"
    else:
        require(all(not cleanup["receipt"] for _, cleanup in holds), "unconfirmed TLS cleanup manufactured a receipt")
        terminal = stopped["admission_terminal_failed"]
        require(terminal in receipts and terminal["mode"] == ":failed" and
                terminal["sequence"] > live["sequence"] and terminal["cleanups"] == [] and
                terminal["cleanup_pending"] == terminal["cleanup_bytes"] == 0,
                "missing cleanup receipt lacked actual terminal failed Admission snapshot")
        expected_failure = [{"failure": "cleanup_receipt_missing", "pending": 0}]
        require(observed["service_failures"] == stopped["service_failures"] == expected_failure and
                observed["service"] == stopped["before"]["service"] == {"public_result": "{:error, :not_running}"} and
                observed["service_alive"] is False and observed["gate_alive"] is False,
                "TLS rejection lost failed Service disappearance timeline")
        public_stop = stopped["public_stop"]
        require(public_stop["kind"] == "shutdown" and public_stop["services"] == [] and
                len(public_stop["participants"]) == 1 and
                public_stop["participants"][0]["result"] == "{:error, :cleanup_unconfirmed}",
                "unconfirmed TLS original did not preserve exact public shutdown error")
        registration = public_stop["participants"][0]["registration"]
        require(stopped["public_result"] == "{:error, {:shutdown, [], [{" + registration +
                ", {:error, :cleanup_unconfirmed}}]}}" and not stopped["cleanup_confirmed"] and
                stopped["forced_test_disposal"], "failed public shutdown was relabeled successful")
        retained = stopped["retained"]
        settlement = stopped["helper_settlement"]
        require(settlement["settled"] and settlement["helpers"] == 0 and settlement["openings"] == [] and
                len({row["pid"] for row in settlement["joins"]}) == len(settlement["joins"]) and
                all(row["reason"] in (":normal", ":noproc") for row in settlement["joins"]),
                "TLS failure helpers lacked genuine bounded settlement/join before test-owned disposal")
        require({key: retained[key] for key in ("request_tokens", "pins", "helpers", "resources",
                "reserved_connections", "failed_resources", "lifecycle")} ==
                dict(request_tokens=1, pins=0, helpers=0, resources=1, reserved_connections=2,
                     failed_resources=1, lifecycle="retiring"), "TLS failure retained owner shape changed")
        ledger = stopped["retained_owner_ledger"]
        payload_matches(ledger, retained)
        require(len(ledger["tokens"]) == len(ledger["resources"]) == 1 and ledger["pins"] == [] and
                ledger["tokens"][0]["token"] == originals[0]["token"] and
                ledger["tokens"][0]["original_result"] == result and ledger["tokens"][0]["payload_bytes"] > 0 and
                ledger["tokens"][0]["resource"] == ledger["resources"][0]["resource"] and
                ledger["resources"][0]["lifecycle"] == ":failed" and
                ledger["resources"][0]["transport_confirmed"] is False,
                "original token/failed resource actual payload was not retained")
        expected_disposals = {row["pid"] for row in stopped["joins"]} - {observed["instance"]}
        require({row["pid"] for row in stopped["test_disposals"]} == expected_disposals and
                all(row["outcome"] == "TEST_OWNED_DISPOSAL_AFTER_UNCONFIRMED_PUBLIC_STOP"
                    for row in stopped["test_disposals"]), "failed actors did not have explicit test-owned teardown")
        cleanup_status = "UNCONFIRMED_WITH_RETAINED_FAILURE"
    require(all(row["reason"] == ":normal" for row in stopped["joins"]), "TLS rejection owned actors did not join")
    return dict(cleanup_status=cleanup_status, original=originals[0], live_admission=live,
                exact_cleanup_reservation=hold, terminal_admission=stopped["admission_terminal_failed"])


def held_ledger(host, count, connections=None):
    expires = time.monotonic() + 5
    while True:
        value = observe(host)
        owner, service, native = value["owner"], value["service"], value["native_scope"]
        settled = owner["request_tokens"] == count and owner["helpers"] == 0 and \
            service.get("cleanup_pending") == count and \
            sum(row["result"] == "{:error, :cleanup_pending}" for row in value["originals"]) == count
        if settled:
            break
        require(time.monotonic() < expires, "held ownership barrier expired: " + repr(value))
    require(service["retained_bytes"] >= count * 9_444_956 and service["cleanup_failed"] is None,
            "held Service reserve mismatch")
    require(native["active_requests"] == count and native["preparing_requests"] == 0 and
            native["pending"] == 0 and native["limits"]["max_requests"] == 32 and
            native["limits"]["max_connections"] == 2 and native["limits"]["max_pending"] == 0,
            "public C2/R32/P0 snapshot mismatch")
    if connections is not None:
        require(native["connections"] == connections, "actual connection capacity mismatch")
    require(value["originals"] == value["original_repeat"], "pending original identity changed")
    return value


def clean_cohort(host, count):
    host.send({"op": "clean"})
    value = host.event("clean")
    require(len(value["originals"]) == count and all(row["result"] == ":ok" for row in value["originals"]),
            "cohort original completion mismatch")
    require(value["owner"]["request_tokens"] == 0 and value["owner"]["helpers"] == 0 and
            value["owner"]["pins"] == 1 and value["service"]["retained_bytes"] == 0 and
            value["service"]["cleanup_pending"] == 0, "cohort cleanup ledger mismatch")
    return value


def finish_cohort(host, peer, requests, connections=1, uncertain=False):
    host.send({"op": "stop"})
    stopped = host.event("stopped")
    if uncertain:
        require(not stopped["cleanup_confirmed"] and stopped["forced_test_disposal"] and
                stopped["public_result"] == "{:error, {:deadline_exceeded, :cleanup_pending}}",
                "native rejection manufactured successful shutdown")
        require(stopped["originals"] == stopped["original_repeat"] and len(stopped["originals"]) == 1 and
                stopped["originals"][0]["result"] == "{:error, :cleanup_unconfirmed}",
                "native rejection original uncertainty changed")
        retained = stopped["retained"]
        require(retained["request_tokens"] == 1 and retained["pins"] == 0 and retained["helpers"] == 0 and
                retained["reserved_connections"] == 0, "negative owner holds disappeared")
        require(stopped["service_failures"] == [{"failure": "cleanup_receipt_missing", "pending": 0}],
                "missing Service receipt failure was not observed")
        require(stopped["test_disposals"] and all(row["outcome"] ==
                "TEST_OWNED_DISPOSAL_AFTER_UNCONFIRMED_PUBLIC_STOP" for row in stopped["test_disposals"]),
                "negative teardown was not explicit")
    else:
        require(stopped["cleanup_confirmed"] and stopped["public_result"] == ":ok" and
                not stopped["forced_test_disposal"] and not stopped["test_disposals"],
                "positive cohort shutdown unconfirmed")
    require(all(row["reason"] == ":normal" for row in stopped["joins"]), "owned actor join mismatch")
    physical = [peer.event(("eof", "connection_reset"), predicate=lambda event, number=number:
                          event["connection"] == number) for number in range(1, connections + 1)]
    peer.send({"op": "stop"})
    joined = peer.event("joined")
    require(joined == dict(event="joined", accepts=connections, requests=requests, forced=0, live=0, failed=False),
            "cohort peer join/no replay mismatch")
    peer.join()
    return dict(cleanup=stopped, physical_termination=physical, joined=joined)


def concurrent_cohort(directory, name, protocol, downstream, host, actors, kind):
    limit = 1 if kind == "c2" else 16 if kind == "r32" else None
    count = 32 if kind == "r32" else 2
    intended_clients = count + (kind in ("c2", "r32", "goaway"))
    peer, ready, started = fixture(directory, name, protocol, downstream, host, actors, limit,
                                  native_clients=intended_clients if downstream == "h2" else None)
    clients, requests = [], []
    prepared_phases = []
    if kind == "r32":
        # P0 refuses requests while a new connection is still connecting.
        # Establish each acknowledged16-slot connection before filling it;
        # every response head remains withheld across both preparation phases.
        for start in (0, 16):
            target = "/hold/r32/" + str(start)
            clients.append(client_actor(directory, name + "-" + str(start), started, downstream, target, actors))
            seed = request_event(peer, target)
            requests.append(seed)
            require(not prepared_phases or seed["connection"] != prepared_phases[0]["connection"],
                    "R32 second preparation reused the full first connection")
            settings = peer.event("settings_ack", predicate=lambda event, number=seed["connection"]:
                                  event["connection"] == number and event["max_streams"] == limit)
            for index in range(start + 1, start + 16):
                target = "/hold/r32/" + str(index)
                clients.append(client_actor(directory, name + "-" + str(index), started, downstream, target, actors))
            for index in range(start + 1, start + 16):
                requests.append(request_event(peer, "/hold/r32/" + str(index)))
            phase_requests = requests[start:start + 16]
            require(len(phase_requests) == 16 and
                    all(request["connection"] == seed["connection"] for request in phase_requests),
                    "R32 preparation did not fill exactly16 streams on its acknowledged connection")
            response_commands = sum(event.get("event") == "command" and event.get("op") == "respond"
                                    for event in peer.seen)
            require(response_commands == 0, "R32 preparation responded before all32 requests were held")
            prepared_phases.append(dict(connection=seed["connection"], settings_ack=settings,
                                        requests=phase_requests, response_commands=response_commands))
        require(not any(event.get("event") in ("client_head", "client_response")
                        for client in clients for event in client.seen),
                "R32 prepared clients received a head before all32 requests were held")
    else:
        for index in range(count):
            target = "/hold/" + kind + "/" + str(index)
            clients.append(client_actor(directory, name + "-" + str(index), started, downstream, target, actors))
            # Establish the first connection's acknowledged initial limit before
            # opening the remaining requests; all response heads remain withheld.
            if index == 0 or kind == "c2":
                request = request_event(peer, target)
                requests.append(request)
                if limit is not None:
                    peer.event("settings_ack", predicate=lambda event, number=request["connection"]:
                               event["connection"] == number and event["max_streams"] == limit)
        known = {request["target"] for request in requests}
        for index in range(count):
            target = "/hold/" + kind + "/" + str(index)
            if target not in known:
                requests.append(request_event(peer, target))
    requests.sort(key=lambda request: int(request["target"].rsplit("/", 1)[1]))
    require(len({(request["connection"], request["stream"]) for request in requests}) == count,
            "concurrent stream identities reused")
    expected_connections = 2 if limit is not None else 1
    require(len({request["connection"] for request in requests}) == expected_connections,
            "simultaneous connection count mismatch")
    pending = held_ledger(host, count, expected_connections)
    responses, commands = [], []
    if kind in ("c2", "r32"):
        refused = client_actor(directory, name + "-refused", started, downstream, "/refused", actors)
        responses.append(client_result(refused, downstream, 503, b""))
        after_refusal = held_ledger(host, count, 2)
        require(not any(event.get("event") == "request" and event["target"] == "/refused"
                        for event in peer.seen), "refused request reached independent peer")
        require(len([event for event in peer.seen if event.get("event") == "request"]) == count,
                "capacity refusal replayed a request")
        expected_originals = count + (kind == "c2")
    elif kind == "reset":
        commands.append(peer_command(peer, requests[0], "reset", code=8))
        responses.append(client_result(clients[0], downstream, 502, b""))
        remaining = held_ledger(host, 1, 1)
        require(sum(row["result"] == ":ok" for row in remaining["originals"]) == 1,
                "reset original completion was not joined")
        expected_originals = 2
    else:
        require(requests[0]["stream"] < requests[1]["stream"], "GOAWAY stream ordering mismatch")
        commands.append(peer_command(peer, requests[1], "goaway", last_stream=requests[0]["stream"], code=0))
        responses.append(client_result(clients[1], downstream, 502, b""))
        remaining = held_ledger(host, 1, 1)
        require(sum(row["result"] == ":ok" for row in remaining["originals"]) == 1,
                "GOAWAY rejected original completion was not joined")
        expected_originals = 3
    r32_results = []
    response_phases = dict(observation_scope="COLLECTOR_ONLY_NOT_SESSION_TIMER_RECEIPTS",
                           dispatch_started_ns=time.monotonic_ns(), commands=[]) if kind == "r32" else None
    for index, (client, request) in enumerate(zip(clients, requests)):
        if (kind == "reset" and index == 0) or (kind == "goaway" and index == 1):
            continue
        body = ("healthy-" + str(index)).encode()
        sent_ns = time.monotonic_ns() if kind == "r32" else None
        commands.append(peer_command(peer, request, "respond", fields=[["content-length", str(len(body))]],
                                     body64=base64.b64encode(body).decode()))
        if kind == "r32":
            response_phases["commands"].append(dict(target=request["target"], connection=request["connection"],
                                                   stream=request["stream"], command_id=commands[-1]["command_id"],
                                                   sent_ns=sent_ns, acknowledged_ns=time.monotonic_ns()))
            r32_results.append((client, body))
        else:
            responses.append(client_result(client, downstream, 200, body))
    if kind == "r32":
        # Start every held response before client validation/process joins consume
        # the unchanged opening deadlines of requests still awaiting their heads.
        response_phases["dispatch_finished_ns"] = time.monotonic_ns()
        response_phases["results_started_ns"] = time.monotonic_ns()
        for client, body in r32_results:
            responses.append(client_result(client, downstream, 200, body))
        response_phases["results_joined_ns"] = time.monotonic_ns()
    if kind == "goaway":
        later = client_actor(directory, name + "-later", started, downstream, "/hold/later", actors)
        request = request_event(peer, "/hold/later")
        require(request["connection"] != requests[0]["connection"], "GOAWAY connection reused")
        requests.append(request)
        commands.append(peer_command(peer, request, "respond", fields=[["content-length", "5"]],
                                     body64=base64.b64encode(b"later").decode()))
        responses.append(client_result(later, downstream, 200, b"later"))
        expected_connections = 2
    clean = clean_cohort(host, expected_originals)
    finished = finish_cohort(host, peer, len(requests), expected_connections)
    return dict(case=name, status="PASS", native_allowance=started["native_allowance"],
                **(dict(prepared_phases=prepared_phases, response_phases=response_phases) if kind == "r32" else {}),
                pending=pending, requests=requests, responses=responses,
                commands=commands, clean=clean, after_refusal=after_refusal if kind in ("c2", "r32") else None,
                **finished)


def upload_cohort(directory, name, protocol, downstream, host, actors, kind):
    peer, ready, started = fixture(directory, name, protocol, downstream, host, actors)
    target, trailers = "/hold/" + kind, [["x-check", "first"], ["x-check", "second"]]
    prefix = b"wire" if kind == "request-trailers" else b"pre-eof:" + b"u" * 16384
    suffix = b"tail:" + b"v" * 16384
    fields = [["content-length", str(len(prefix) + len(suffix))]]
    if kind == "request-trailers":
        fields = [["trailer", "x-check"]] + ([["transfer-encoding", "chunked"]] if downstream == "h1"
                                               else [["content-length", str(len(prefix))]])
    client = client_actor(directory, name, started, downstream, target, actors,
                          method="POST", fields=fields, controlled=True)
    client.send(dict(op="upload", body64=base64.b64encode(prefix).decode(), ended=False))
    request = request_event(peer, target)
    upload = peer.event("upload", predicate=lambda event: event["connection"] == request["connection"] and
                        event["stream"] == request["stream"] and event["total_bytes"] == len(prefix))
    require(not request["ended"] and upload["sha256"] == hashlib.sha256(prefix).hexdigest(),
            "first upload bytes did not reach independent peer before EOF")
    require(not any(event.get("event") == "upload_end" and event.get("stream") == request["stream"]
                    for event in peer.seen), "producer EOF preceded controlled upload barrier")
    pending = held_ledger(host, 1, 1)
    commands, upload_end, received_trailers = [], None, None
    if kind == "early-final":
        expected, status = b"early-final", 413
    else:
        terminal = dict(op="upload", body64=base64.b64encode(suffix).decode(), ended=True)
        expected, status = prefix + suffix, 200
        if kind == "request-trailers":
            terminal.update(body64="", trailers=trailers)
            expected = prefix
        client.send(terminal)
        if kind == "request-trailers":
            received_trailers = peer.event("upload_trailers", predicate=lambda event:
                event["connection"] == request["connection"] and event["stream"] == request["stream"])
            require(received_trailers["fields"] == trailers, "request trailer duplicates/order changed")
            require(not any(pair[0] == "content-length" for pair in request["headers"]),
                    "request trailers retained incompatible upstream content-length")
        upload_end = peer.event("upload_end", predicate=lambda event:
            event["connection"] == request["connection"] and event["stream"] == request["stream"])
        require(upload_end["total_bytes"] == len(expected), "controlled upload lost exact bytes")
        complete_upload = peer.event("upload", predicate=lambda event:
            event["connection"] == request["connection"] and event["stream"] == request["stream"] and
            event["total_bytes"] == len(expected)) if kind != "request-trailers" else upload
        require(complete_upload["sha256"] == hashlib.sha256(expected).hexdigest(), "upload body hash changed")
    commands.append(peer_command(peer, request, "respond", status=status,
                                 fields=[["content-length", str(len(expected))]],
                                 body64=base64.b64encode(expected).decode()))
    response = client_result(client, downstream, status, expected)
    require(response["upload_bytes"] == (len(prefix) if kind == "early-final" else len(expected)) and
            response["upload_eof"] is (kind != "early-final"), "producer completion/stop mismatch")
    clean = clean_cohort(host, 1)
    finished = finish_cohort(host, peer, 1)
    if kind == "early-final":
        require(not any(event.get("event") == "upload_end" for event in peer.seen),
                "early final manufactured producer EOF")
        require(sum(event.get("chunk_bytes", 0) for event in peer.seen if event.get("event") == "upload") == len(prefix),
                "producer continued after early final")
    return dict(case=name, status="PASS", request=request, pre_eof=upload, pending=pending,
                upload_end=upload_end, request_trailers=received_trailers, commands=commands,
                response=response, clean=clean, **finished)


def boundary_cohort(directory, name, protocol, downstream, host, actors, kind):
    peer, ready, started = fixture(directory, name, protocol, downstream, host, actors, boundary_limits=True)
    target = "/hold/" + kind
    terminal_rejection = kind in ("trailer129", "trailer-bytes-over")
    uncertain = kind in ("native-head256", "native-head257")
    client = client_actor(directory, name, started, downstream, target, actors, incomplete=terminal_rejection)
    request = request_event(peer, target)
    pending = held_ledger(host, 1, 1)
    fields, trailers, body, commands, status = [], [], b"", [], 200
    proof = "NATIVE_VALID_ADAPTER_BOUNDARY"
    byte_budgets = None
    if kind in ("head255", "native-head256", "native-head257"):
        count = {"head255": 255, "native-head256": 256, "native-head257": 257}[kind]
        fields = [["x-check", str(index)] for index in range(1, count + 1)]
        if uncertain:
            status, proof = 502, "NATIVE_HPACK_REJECTION_BEFORE_ADAPTER"
    elif kind.startswith("head-bytes"):
        # CL0 selects fixed framing: H1 adds status17+connection-close19.
        # H2's proxy field-wire limit excludes those H1-only bytes.
        over = kind == "head-bytes-over"
        padding = (65458 if downstream == "h1" else 65494) + over
        fields = [["content-length", "0"], ["x-pad", "a" * padding], ["x", "b"], ["y", "c"]]
        logical = sum(len(n) + len(v) for n, v in fields)
        field_wire = logical + 4 * len(fields) + 2
        rendered = field_wire + len("HTTP/1.1 200 OK\r\n") + len("connection: close\r\n")
        byte_budgets = dict(envelope_logical_bytes=logical, envelope_compact_backing_bytes=logical,
                            native_decoded_bytes=logical + len(":status") + len("200"),
                            proxy_field_wire_bytes=field_wire,
                            h1_full_render_bytes=rendered if downstream == "h1" else None,
                            boundary_unit="H1_FULL_RENDERED_WIRE" if downstream == "h1" else "PROXY_FIELD_WIRE",
                            boundary_bytes=rendered if downstream == "h1" else field_wire,
                            boundary_limit=65536)
        require(byte_budgets["boundary_bytes"] == 65536 + over and
                logical <= 65536 and byte_budgets["native_decoded_bytes"] <= 65536,
                "head byte fixture accounting mismatch")
        status = 502 if over else 200
        proof = byte_budgets["boundary_unit"] + ("_REJECTION" if over else "_EXACT")
    elif kind.startswith("trailer"):
        fields, body = [["trailer", "x-check"]], b"wire"
        if kind in ("trailer128", "trailer129"):
            count = 128 if kind == "trailer128" else 129
            trailers = [["x-check", str(index)] for index in range(1, count + 1)]
        else:
            over = kind == "trailer-bytes-over"
            trailers = [["x-check", "a" * (65497 + over)]]
            logical = sum(len(n) + len(v) for n, v in trailers)
            field_wire = logical + 4 * len(trailers) + 2
            byte_budgets = dict(envelope_logical_bytes=logical, envelope_compact_backing_bytes=logical,
                                native_decoded_bytes=logical, native_metadata_bytes=logical + 32 * len(trailers),
                                proxy_field_wire_bytes=field_wire,
                                h1_full_render_bytes=field_wire + len("0\r\n") if downstream == "h1" else None,
                                boundary_unit="NATIVE_TRAILER_METADATA", boundary_bytes=logical + 32 * len(trailers),
                                boundary_limit=65536)
            require(byte_budgets["boundary_bytes"] == 65536 + over and logical <= 65536 and
                    field_wire <= 65536, "trailer byte fixture accounting mismatch")
            proof = "NATIVE_TRAILER_METADATA_REJECTION_BEFORE_ADAPTER" if over else "NATIVE_TRAILER_METADATA_EXACT"
    elif kind.startswith("inform"):
        if kind in ("inform128", "inform129"):
            count, info_fields = (128 if kind == "inform128" else 129), [["link", "</asset>"]]
        else:
            count, info_fields = 1, [["x", "a" * (65503 + (kind == "inform-bytes-over"))]]
            require(sum(len(n) + len(v) + 32 for n, v in info_fields) ==
                    65536 + (kind == "inform-bytes-over"), "informational byte fixture accounting mismatch")
        for _ in range(count):
            commands.append(peer_command(peer, request, "inform", status=103, fields=info_fields))
        status = 502 if kind in ("inform129", "inform-bytes-over") else 200
    elif kind.startswith("declaration"):
        count = 128 if kind == "declaration128" else 129
        fields = [["trailer", ",".join(["x-check"] * count)]]
        status = 200 if count == 128 else 502
    else:
        raise ValueError("unknown boundary cohort " + kind)
    if terminal_rejection:
        commands.append(peer_command(peer, request, "respond", fields=fields, ended=False))
        head = client.event("client_head")
        require(head["status"] == 200, "over-limit trailer was not sent after an actual final head")
        commands.append(peer_command(peer, request, "data", body64=base64.b64encode(body).decode(),
                                     trailers=trailers, ended=True))
    elif kind not in ("inform129",):
        commands.append(peer_command(peer, request, "respond", fields=fields,
                                     body64=base64.b64encode(body).decode(), trailers=trailers))
    response = client_result(client, downstream, status, body if status == 200 else b"", complete=not terminal_rejection)
    if terminal_rejection:
        require(response["trailers"] == [], "over-limit trailers escaped before failed terminal")
    elif status == 200:
        if kind == "head255":
            require([pair for pair in response["headers"] if pair[0] == "x-check"] == fields,
                    "exact native final field order changed")
        if kind == "head-bytes-exact":
            require([pair for pair in response["headers"] if pair[0] in ("x-pad", "x", "y", "content-length")] == fields,
                    "exact head bytes changed")
            if downstream == "h1":
                require(len("HTTP/1.1 200 OK\r\n") +
                        sum(len(n) + len(v) + 4 for n, v in response["headers"]) + 2 ==
                        byte_budgets["h1_full_render_bytes"], "exact complete H1 head wire bytes changed")
        if trailers:
            require(response["trailers"] == trailers, "exact trailer bytes/order changed")
        if kind == "declaration128":
            require([pair for pair in response["headers"] if pair[0] == "trailer"] == [["trailer", "x-check"]],
                    "repeated declaration token normalization mismatch")
    observed, clean = None, None
    if uncertain:
        expires = time.monotonic() + 5
        while True:
            observed = observe(host)
            if (len(observed["originals"]) == 1 and observed["originals"][0]["result"] == "{:error, :cleanup_unconfirmed}"
                    and observed["service_failures"]):
                break
            require(time.monotonic() < expires, "native uncertainty receipt barrier expired: " + repr(observed))
        require(observed["originals"] == observed["original_repeat"] and
                observed["owner"]["request_tokens"] == 1 and observed["owner"]["helpers"] == 0,
                "native rejection lost original negative ownership evidence")
    else:
        clean = clean_cohort(host, 1)
    finished = finish_cohort(host, peer, 1, uncertain=uncertain)
    return dict(case=name, status="PASS", proof=proof, byte_budgets=byte_budgets, request=request, pending=pending,
                commands=commands, response=response, clean=clean, observed=observed, **finished)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    directory = args.evidence.resolve()
    directory.mkdir(parents=True, exist_ok=False)
    before, cases, cells, actors = inventory(), [], [], []
    host_script = directory / "fixed-managed-h2-host.exs"
    host_script.write_text(HOST)
    command = ["nix", "develop", "--command", "env", "ERL_FLAGS=+S 2:2", "MIX_ENV=test",
               "mix", "run", str(host_script), str(directory)]
    host, passed, failure, tools_identity, candidate = None, False, None, None, None
    started_at = time.monotonic()
    try:
        tools_identity = toolchain_identity()
        host = Process(command, directory / "host.log", "FIXED_H2_HOST ")
        actors.append(host)
        identity = host.event("ready", 90)
        for downstream in ("h1", "h2"):
            for protocol in ("tls", "h2c"):
                cell = downstream + "-to-" + protocol
                peer = Process([str(PYTHON), str(PEER), "--protocol", protocol], directory / (cell + "-peer.log"))
                actors.append(peer)
                ready = peer.event("ready")
                require(ready["identity"]["packages"] == PACKAGES, "peer identity mismatch")
                host.send(dict(op="start", protocol=protocol, port=ready["port"], ca=ready["ca"], downstream=downstream))
                started = host.event("started")
                probes = [("escaped", "/a%2Fb?q=%2F", "GET", b"", "/a%2Fb?q=%2F".encode(), 200),
                          ("empty-query", "/empty?", "GET", b"", b"/empty?", 200),
                          ("stream", "/stream", "GET", b"", b"managed-h2-stream:" + b"s" * 65536, 200),
                          ("gzip", "/gzip", "GET", b"", gzip.compress(b"raw-compression", mtime=0), 200),
                          ("redirect", "/redirect", "GET", b"", b"redirect", 302),
                          ("upload", "/echo", "POST", b"u" * 65536, b"u" * 65536, 200),
                          ("trailers", "/trailers", "GET", b"", b"trailers", 200),
                          ("head", "/head", "HEAD", b"", b"", 200),
                          ("204", "/204", "GET", b"", b"", 204),
                          ("205", "/205", "GET", b"", b"", 205),
                          ("304", "/304", "GET", b"", b"", 304)]
                request_ids, outcomes = [], []
                for name, target, method, upload, expected, status in probes:
                    fields = [["x-trace", "first"], ["x-trace", "second"], ["x-forwarded-for", "spoofed"]]
                    if upload:
                        fields.append(["content-length", str(len(upload))])
                    response = downstream_client(directory, cell + "-" + name, started, downstream, target, method, upload, fields)
                    require(response["status"] == status and base64.b64decode(response["body64"]) == expected,
                            cell + "/" + name + " status/body mismatch")
                    request = peer.event("request")
                    require(request["target"] == target, "raw target was changed")
                    require([pair for pair in request["headers"] if pair[0] == "x-trace"] == fields[:2], "request duplicates reordered")
                    require([":authority", "localhost:" + str(ready["port"])] in request["headers"], "authority mismatch")
                    require(not any(pair[1] == "spoofed" for pair in request["headers"]), "untrusted forwarding header retained")
                    request_ids.append([request["connection"], request["stream"]])
                    if name == "upload":
                        end = peer.event("upload_end", predicate=lambda event:
                            (event.get("connection"), event.get("stream")) ==
                            (request["connection"], request["stream"]))
                        require(end["total_bytes"] == len(upload), "upstream upload truncation")
                    if name == "redirect":
                        require(["location", "http://unfollowed.invalid/never"] in response["headers"], "redirect location mismatch")
                    if name == "gzip":
                        require(["content-encoding", "gzip"] in response["headers"] and
                                ["content-length", str(len(expected))] in response["headers"], "raw compression framing changed")
                    if name == "trailers":
                        require(response["trailers"] == [["x-check", "first"], ["x-check", "second"]], "response trailer order mismatch")
                        require([pair for pair in response["headers"] if pair[0] == "set-cookie"] == [["set-cookie", "one=1"], ["set-cookie", "two=2"]], "response duplicates reordered")
                    host.send({"op": "clean"})
                    clean = host.event("clean")
                    require(len(clean["originals"]) == 1 and clean["originals"][0]["result"] == ":ok",
                            "missing original public request completion")
                    outcomes.append(dict(case=cell + "/" + name, status="PASS", request=request,
                                         response=response, cleanup=clean,
                                         upload_end=end if name == "upload" else None))
                    cases.append(outcomes[-1])
                require(len({pair[0] for pair in request_ids}) == 1 and len({tuple(pair) for pair in request_ids}) == len(probes), "sequential reuse/stream identity mismatch")
                if protocol == "tls":
                    tls = next(event for event in peer.seen if event.get("event") == "tls")
                    require(tls["alpn"] == "h2" and tls["sni"] == "localhost", "actual upstream ALPN/SNI mismatch")
                host.send({"op": "stop"})
                stopped = host.event("stopped")
                require(stopped["cleanup_confirmed"] and not stopped["forced_test_disposal"], "normal matrix cleanup unconfirmed")
                physical = peer.event(("eof", "connection_reset"))
                peer.send({"op": "stop"})
                joined = peer.event("joined")
                require(joined["forced"] == 0 and joined["live"] == 0 and not joined["failed"] and joined["requests"] == len(probes), "peer join/no-replay mismatch")
                peer.join()
                cells.append(dict(cell=cell, status="PASS", ready=ready, request_ids=request_ids,
                                  cleanup=stopped, physical_termination=physical, joined=joined))
                for kind in CONCURRENT:
                    cases.append(concurrent_cohort(directory, cell + "-" + kind, protocol,
                                                   downstream, host, actors, kind))
                for kind in CONTROLLED:
                    cases.append(upload_cohort(directory, cell + "-" + kind, protocol,
                                               downstream, host, actors, kind))
                for kind in BOUNDARIES:
                    cases.append(boundary_cohort(directory, cell + "-" + kind, protocol,
                                                 downstream, host, actors, kind))
        wrong_trust = directory / "wrong-trust"
        subprocess.run(["bash", str(ROOT / "scripts/generate-fixtures.sh"), str(wrong_trust)],
                       check=True, capture_output=True, text=True, timeout=25)
        for name in ("wrong-ca", "wrong-name", "no-alpn"):
            peer_command = [str(PYTHON), str(PEER), "--protocol", "tls"]
            if name == "no-alpn":
                peer_command += ["--alpn", "http/1.1"]
            peer = Process(peer_command, directory / (name + "-peer.log"))
            actors.append(peer)
            ready = peer.event("ready")
            host.send(dict(op="start", protocol="tls", port=ready["port"], downstream="h1",
                           ca=str(wrong_trust / "ca.pem") if name == "wrong-ca" else ready["ca"],
                           hostname="wrong.invalid" if name == "wrong-name" else "localhost"))
            started = host.event("started")
            response = downstream_client(directory, name, started, "h1", "/must-not-replay")
            require(response["status"] == 502, "TLS/protocol rejection did not produce bounded502")
            observed = rejection_observation(host)
            host.send({"op": "stop"})
            stopped = host.event("stopped")
            cleanup_proof = rejection_cleanup(observed, stopped)
            peer.send({"op": "stop"})
            joined = peer.event("joined")
            require(joined["requests"] == 0 and joined["forced"] == 0 and joined["live"] == 0 and not joined["failed"],
                    "TLS/protocol rejection replayed or did not join")
            require(any(event.get("event") in ("handshake_failed", "eof", "connection_reset") for event in peer.seen),
                    "TLS/protocol failure had no independent physical outcome")
            if name == "no-alpn":
                tls = next(event for event in peer.seen if event.get("event") == "tls")
                require(tls["alpn"] != "h2" and tls["sni"] == "localhost", "negative ALPN fixture mismatch")
            peer.join()
            cases.append(dict(case=name, status="PASS", behavior="BOUNDED_TLS_OR_PROTOCOL_REJECTION",
                              response=response, observed=observed, cleanup=stopped, joined=joined,
                              cleanup_proof=cleanup_proof, cleanup_status=cleanup_proof["cleanup_status"]))
        host.send({"op": "exit"})
        host.event("exited")
        host.join()
        identity_check(json.loads((directory / "host-loaded-before.json").read_text()),
                       json.loads((directory / "host-loaded-after.json").read_text()))
        candidate = candidate_identity_check(directory)
        require(before == inventory(), "source changed during qualification")
        require(cases and len(cells) == 4, "incomplete independent matrix")
        require(execution_manifest(cases)["complete"], "required independent cohort manifest incomplete")
        passed = True
    except Exception:
        failure = traceback.format_exc()
    finally:
        for actor in actors:
            actor.dispose()
        after = inventory()
        result = dict(status="PASS" if passed else "FAIL", command=command,
                      elapsed_ms=round((time.monotonic() - started_at) * 1000),
                      head=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                      source_before=before, source_after=after, source_stable=before == after,
                      cells=cells, cases=cases, executed=len(cases), failure=failure,
                      execution_manifest=execution_manifest(cases), wire_constraints=WIRE_CONSTRAINTS,
                      toolchain=tools_identity, candidate_identity=candidate,
                      exclusions=[], skips=[])
        (directory / "qualification.json").write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps({key: value for key, value in result.items() if key not in ("source_before", "source_after", "cells", "cases")}, indent=2))
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
