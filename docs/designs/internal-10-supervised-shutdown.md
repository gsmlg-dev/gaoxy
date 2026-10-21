# Supervised HTTP shutdown budget

Issue: gsmlg-dev/gaoxy#10. Native HTTP returns a Gaoxy instance from its
`start_link/1`, but its child spec omits `shutdown`. OTP therefore allows only
5000ms, the same as the default drain alone, and kills the instance before its
cleanup acknowledgement. HTTP/3 has the same wrapper omission.

Both wrappers retain their original child identity, start tuple and transient
restart policy, and set `shutdown` through the pure internal
`Gaoxy.Config.shutdown_timeout/1` helper. This helper validates raw service limits
using Config's existing defaults and limit validation, then adds the existing
runtime cleanup headroom. Invalid limits select the finite default allowance.
The core child spec retains full service validation and delegates its selected
maximum drain to the same helper. No endpoint initialization is invoked while
constructing wrapper child specs; startup retains its existing initialization
and error boundary. No drain formula or default is duplicated.

Regression tests use an actual OTP supervisor, an idle listener and progressing
incomplete HTTP uploads across default 5000ms and configured 5500ms drains.
They monitor instance, service, gate and owned backend processes; require normal
supervised instance shutdown, closed client sockets and successful port rebind.
HTTP/3 coverage proves the same child-spec budget contract without claiming a
network QUIC drain qualification. No drain algorithms or specialist slices change.

Independent review found that the first implementation called `service_spec/1`
while constructing the child spec and therefore initialized user Plug/endpoints
too early and twice. The pure Config helper replaces that approach. Counting
and raising-init regressions cover both wrappers, including exactly one Plug
initialization at actual supervised HTTP startup.
