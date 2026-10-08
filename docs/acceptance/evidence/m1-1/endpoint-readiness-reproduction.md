# Endpoint readiness diagnosis and repair

Task: f2_registry. Direct assignment. Repository: /home/gao/Workspace/gsmlg-opt/gaoxy.
Main baseline: adafa668937ed9a919cc82fcae14ae50863b5ac6.
Inspected candidate2: 69c7a79b0e0e76d15d2321f3cea391c0e2e6a194.
Candidate2 and main source bytes matched for Gaoxy, Service, Lifecycle, and RuntimeTest before this repair.
Environment: Elixir 1.18.5, Erlang/OTP 28, ERTS 16.4.0.5, Linux x86_64.

## Root cause

Service.info bounds its local endpoint query at 50 ms (service.ex:89).
Lifecycle.bounded returns {:error, :outcome_unknown} on expiration (lifecycle.ex:45).
UDP local queries call Abyss.Listener.listener_info/1, a GenServer call.
RuntimeTest.endpoint returned every unwrapped local value unchanged, including error tuples.
Thus {ip, port} accepted {:error, :outcome_unknown}; gen_udp.send resolved the atom :error as a hostname and returned {:error, :nxdomain}.
The readiness helper polled status, then queried the endpoint only once, allowing this failure after status became ready.
The public service_call budget in both inspected checkouts is 5,000 ms, separate from the internal 50 ms bound.

Hosted evidence: /tmp/gaoxy-ci-r2-job-113458790950.log:691-700 records the exact runtime failure.
The TLS handshake timeout at lines 711-727 is separate; runner-load correlation is unproven.

## Controlled reproduction command

This command used existing compiled BEAMs and an exclusively owned ephemeral runtime.
It did not compile or modify repository files and resumed the suspended listener before confirmed shutdown.

```sh
elixir -e '
Code.prepend_paths(Path.wildcard("_build/test/lib/*/ebin"))
{:ok, _} = Application.ensure_all_started(:gaoxy)
defmodule GaoxyInfoReadOnlyProbe do
  def handle_datagram(packet, _), do: {:reply, packet.data}
end
{:ok, runtime} = Gaoxy.start_link(services: [%{id: "probe", transport: :udp, handler: GaoxyInfoReadOnlyProbe}])
{:ok, service, _} = GenServer.call(runtime, {:lookup, "probe"})
backend = :sys.get_state(service).backend
[listener] = Abyss.Listener.for_server(backend)
{:ok, client} = :gen_udp.open(0, [:binary, active: false])
try do
  IO.inspect(Gaoxy.info(runtime, "probe").local, label: "initial_local")
  :ok = :sys.suspend(listener)
  started = System.monotonic_time(:millisecond)
  info = Gaoxy.info(runtime, "probe")
  IO.inspect(info.local, label: "suspended_local")
  IO.inspect(System.monotonic_time(:millisecond) - started, label: "elapsed_ms")
  decoded = case info.local do
    {:ok, address} -> address
    address -> address
  end
  {ip, port} = decoded
  IO.inspect(:gen_udp.send(client, ip, port, "wait"), label: "send_decoded_error")
  :ok = :sys.resume(listener)
  IO.inspect(Gaoxy.info(runtime, "probe").local, label: "resumed_local")
after
  :sys.resume(listener)
  :gen_udp.close(client)
  IO.inspect(Gaoxy.stop(runtime, 1_000), label: "probe_stop")
  IO.inspect(Process.alive?(runtime), label: "probe_runtime_alive")
end
'
```

Actual output, exit 0:

```text
initial_local: {{127, 0, 0, 1}, 48232}
suspended_local: {:error, :outcome_unknown}
elapsed_ms: 53
send_decoded_error: {:error, :nxdomain}
resumed_local: {{127, 0, 0, 1}, 48232}
probe_stop: :ok
probe_runtime_alive: false
```

## Authorized repair

Only apps/gaoxy/test/runtime_test.exs was edited.
endpoint/2 now reuses eventually/1 and its existing 2,000 ms readiness budget.
It accepts raw or {:ok, address} endpoints only when the port is an integer in 1..65_535 and :inet.is_ip_address/1 accepts the IP.
Temporary local query errors now produce another bounded readiness attempt, never a fake endpoint.
Existing cleanup assertion changes from the parent are preserved.
No production budget changes, TLS edits, dependency changes, or upstream issue.
No helper-mirroring test was added; existing scoped tests exercise real TCP/UDP wire behavior.

## Verification

All authorized checks passed:

- `python3 scripts/check-tests.py apps/gaoxy/test/runtime_test.exs`: exit 0, 8 tests, 0 failures, 1.2 seconds. Log: /tmp/gaoxy-endpoint-readiness-tests.log. The existing intentional fixture-crash log was observed; all wire/cleanup assertions passed.
- `mix format --check-formatted apps/gaoxy/test/runtime_test.exs`: exit 0. Log: /tmp/gaoxy-endpoint-readiness-format.log.
- `git diff --check -- apps/gaoxy/test/runtime_test.exs`: exit 0.
- Final diff inspection: only the endpoint helper changed in this assignment; the parent's pre-existing cleanup assertions remain intact.

Status: DONE. Direct assignment. Own unsuccessful repair rounds: 0; no Astra counter received, parent cumulative counter not supplied.
All commands have finished. The controlled probe listener was resumed, its client closed, and its runtime termination confirmed.
No commit, push, repository-wide autofix, production change, or unrelated file edit was performed.
Evidence boundary: scoped Linux runtime suite only; hosted macOS revalidation belongs to the parent.
Remaining decisions: none for this assignment. Parent owns separate TLS peer handling and CI publication.
