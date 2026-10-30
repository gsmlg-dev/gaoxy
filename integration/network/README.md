# Isolated ingress, membership and addressed-send fixture

The fixture creates four uniquely named Linux network namespaces, two private
bridges and veth interfaces. Only fixture-owned namespaces receive routes and
addresses. An independent Python standard-library peer runs in each of two
endpoint namespaces; the Gaoxy endpoint uses custom handlers and public Gaoxy
startup/membership/pause APIs. No backend is started directly by the driver.

Build outside the namespaces, then explicitly opt into privileged setup:

```sh
mix deps.get --check-locked
mix compile --warnings-as-errors
python3 integration/network/fixture.py --allow-privileged
python3 integration/network/fixture.py --allow-privileged --ipv6
GAOXY_UDP_BACKEND=socket python3 integration/network/fixture.py --allow-privileged
GAOXY_UDP_BACKEND=socket python3 integration/network/fixture.py --allow-privileged --ipv6
```

Required prerequisites: Linux, `ip`, `nsenter`, `setpriv`, Python, Mix and locked compiled
dependencies, root or passwordless sudo for namespace setup. Participant processes
enter only their fixture-owned network namespace with `nsenter --net`, then drop
to the invoking UID/GID. Their original mount and cgroup namespaces remain intact
so Gaoxy can observe the actual memory-controller limits and usage. Using
`ip netns exec` would replace `/sys` and hide its cgroup mount, correctly causing
memory-safety admission to fail closed. Packet isolation still comes from the
private network namespaces and interfaces. Missing prerequisites, setup errors, packet failures
and zero executed gates cannot pass. Exit 77 reports unavailable privilege/platform,
and CI treats it as failure. Cleanup stops owned children and removes only the
namespaces created by this invocation, even when a packet assertion fails.

The suite covers limited/directed broadcast from two senders and original-port
unicast replies, two multicast groups and independent subscribers, duplicate
joins/absent leaves/rejoin delivery, membership ceilings and failed initialization
rollback, a second incoming interface, paused membership retention and empty packets.
Handler-directed sends additionally exercise limited/directed broadcast to two
independent observers, original endpoint source ports, multicast TTL/hops 7/9,
outgoing selection of each private interface and enabled/disabled local loopback.
Observer ports differ from service ports, preventing self-echo recursion. Empty
and nonempty multicast output must arrive. IPv6 destinations resolve their scope
from the actual fixture interface; the socket backend's scoped-send limitation
is an explicit negative gate. The IPv6 invocation also tests scoped peer ingress
and group/interface membership. Desired-state restart includes actual kept-group
delivery and absent removed-group delivery, stale handles and sibling isolation.
Blocked-send acceptance is in `apps/gaoxy/test/send_outcome_test.exs`.
A PASS for this named suite never certifies complete M1.

The separate production-release gate requires a built release:

```sh
MIX_ENV=prod mix release
python3 integration/network/release_gate.py --allow-privileged
```

It starts all five transports simultaneously, uses two independent namespace
clients with validating TLS and fragmented streams, exercises empty/nonempty
UDP/broadcast/multicast, and checks all five bindings can be reused after shutdown.

The pinned test-tooling image builds on s93 with `integration/network/Dockerfile`.
It adds complete iproute2/util-linux tools rather than relying on BusyBox `ip`.
Run it with `--network none --cap-add NET_ADMIN --cap-add SYS_ADMIN` and pass
`--allow-privileged` explicitly; never use the host network. Loopback IPv6 tests
also require IPv6 enabled inside the disposable container namespace. ExUnit needs
a writable application temporary directory, so copy mounted source into the
container when running the full test suite. Building/configuring
this image is not evidence that a network gate ran.

Topology and independent peer/control helpers are adapted from
`gsmlg-dev/abyss` commit `9b710e6480900e16e304f40e63623aff8c922e19`,
`scripts/udp/network_fixture.py`; its MIT copyright/license is retained in
`LICENSE.abyss`. Gaoxy traffic assertions and server driver are repository-local.
No upstream test count is used as Gaoxy evidence.
