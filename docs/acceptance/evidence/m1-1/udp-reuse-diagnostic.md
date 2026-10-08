# CI4 UDP endpoint reuse diagnosis and repair

Repository/worktree: /home/gao/Workspace/gsmlg-opt/gaoxy, ORIGINAL checkout.
Main baseline: adafa668937ed9a919cc82fcae14ae50863b5ac6.
Inspected candidate4: fe0e382850c0e6285c649b9ef78f87a1f144371d.
Production implementation remains 5a77e0629a94e271ae74d28dcc2de9452d54e571.
Environment: Linux x86_64, Elixir 1.18.5, Erlang/OTP 28, ERTS 16.4.0.5.

## Evidence and boundary

/tmp/gaoxy-ci-r4-job-113470199782.log:735-744 reports one failure: immediate exclusive UDP bind returned {:error, :eaddrinuse} in the two-stalled-services parent-shutdown test at its former line 98, seed 67737.
The log does not identify the endpoint, original socket status, or conflicting owner. The exact CI cause remains UNPROVEN.

Confirmed fixture isolation gap: LifecycleFaultTest ran async with other modules allocating ephemeral UDP sockets. A freed server port can be allocated by another fixture before the strict reuse assertion. eaddrinuse alone is not evidence that the original socket leaked.
The previous ownership assertion checked the service root, backend root, gate, and one worker but did not directly check the original socket or full backend-owned descendant set.

A raw OTP ownership probe killed 2,000 independently spawned UDP socket owners, waited for their DOWN messages, inspected each original port, and immediately rebound each endpoint. Actual result: 0 pending ports, 0 bind failures. This is scoped local evidence, not proof of the unlogged CI owner.

The controlled actual-Gaoxy probe below forced a blocked UDP handler through real parent-supervisor shutdown. All owned processes were dead and the original socket was closed. Binding an unrelated competitor to the freed port then produced the identical eaddrinuse failure. Closing that competitor allowed immediate exclusive reuse, without sleep or retry.

## Controlled competitor probe command

```sh
elixir -e '
Code.prepend_paths(Path.wildcard("_build/test/lib/*/ebin"))
{:ok, _} = Application.ensure_all_started(:gaoxy)
defmodule GaoxyUDPReuseProbe do
  def handle_datagram(packet, owner) do
    send(owner, {:admitted, self(), packet.data})
    receive do :release -> {:reply, packet.data} end
  end
end
spec = %{id: "probe", transport: :udp, handler: GaoxyUDPReuseProbe, handler_options: self(), limits: %{drain_timeout: 300, callback_timeout: 5_000}}
{:ok, parent} = Supervisor.start_link([{Gaoxy, services: [spec]}], strategy: :one_for_one)
[{_, instance, _, _}] = Supervisor.which_children(parent)
{:ok, service, _} = GenServer.call(instance, {:lookup, "probe"})
state = :sys.get_state(service)
resources = Gaoxy.Lifecycle.resources(state.backend, service)
[listener] = Abyss.Listener.for_server(state.backend)
{original, _} = Abyss.Listener.socket_info(listener)
{ip, port} = Gaoxy.info(instance, "probe").local
{:ok, client} = :gen_udp.open(0, active: false)
:ok = :gen_udp.send(client, ip, port, "hold")
receive do {:admitted, worker, "hold"} ->
  IO.inspect(Supervisor.stop(parent), label: "parent_stop")
  IO.inspect(Enum.filter([service, state.gate, worker | resources], &Process.alive?/1), label: "owned_alive")
  IO.inspect(:erlang.port_info(original), label: "original_socket")
  {:ok, competitor} = :gen_udp.open(port, ip: ip, active: false)
  IO.inspect(:gen_udp.open(port, ip: ip, active: false), label: "bind_with_unrelated_competitor")
  :gen_udp.close(competitor)
  {:ok, replacement} = :gen_udp.open(port, ip: ip, active: false)
  IO.inspect(:inet.sockname(replacement), label: "bind_after_competitor_closed")
  :gen_udp.close(replacement)
end
:gen_udp.close(client)
IO.inspect(Process.alive?(parent), label: "parent_alive")
'
```

Actual output, exit 0:

```text
parent_stop: :ok
owned_alive: []
original_socket: :undefined
bind_with_unrelated_competitor: {:error, :eaddrinuse}
bind_after_competitor_closed: {:ok, {{127, 0, 0, 1}, 35883}}
parent_alive: false
```

## Test repair

Only apps/gaoxy/test/lifecycle_fault_test.exs changed.
The module now runs synchronously against other async ExUnit modules, isolating its strict ephemeral-port reuse gate from their allocation.
The two-service test captures the original socket through exported Abyss.Listener.for_server/1 and socket_info/1 APIs; no private dependency state is inspected.
It records backend-owned resources with the existing Gaoxy.Lifecycle.resources/2 ownership helper.
After confirmed parent shutdown, it checks every captured owned PID and the original socket's port_info == :undefined, then retains immediate exclusive bind reuse.
No delay, bind retry, reuseaddr option, skipped gate, relaxed deadline, or production change was added.
The controlled competitor demonstration is diagnostic evidence, not a test merely asserting operating-system binding behavior.

## Validation

```sh
mix format apps/gaoxy/test/lifecycle_fault_test.exs
ELIXIR_ERL_OPTIONS='+S 2:2' python3 scripts/check-tests.py apps/gaoxy/test/lifecycle_fault_test.exs --seed 67737
mix format --check-formatted apps/gaoxy/test/lifecycle_fault_test.exs
git diff --check -- apps/gaoxy/test/lifecycle_fault_test.exs
```

All exited 0. Scoped suite: 14 tests, 0 failures, 2.5 seconds, no excluded/skipped tests; max_cases 4. Log: /tmp/gaoxy-ci4-udp-reuse-focused.log.
Original production bytes in Gaoxy, Service, and Lifecycle were compared to implementation commit 5a77e06 and are unchanged.

Only changed executable/test source-manifest input relative to candidate4:

```text
apps/gaoxy/test/lifecycle_fault_test.exs
sha256=b7c0e9c88afed395154351e4c6c93a55ba6e871ef49b79f90b25309c8f4cdc2e
```

The probe confirmed parent termination and closed both diagnostic sockets. The
exact historical CI conflicting owner remains unknown. Final candidate validation
is recorded in the main acceptance ledger.
