defmodule Gaoxy.NativeStreamHandler do
  @moduledoc """
  Trusted native TCP/TLS handlers implement `ThousandIsland.Handler` directly.

  The initial handler state contains `spec`, `gate`, `scope`, and the owning
  `service` and `instance` PIDs. The scope retains stable telemetry identifiers.
  The pure
  `validate_options/1` callback normalizes `spec.handler_options` before binding.
  Validation must accept its own normalized result, as dynamic service additions
  validate the complete service plan again.
  Each connection acquires an admission lease with `drain_notify: true`, accounts
  for retained bytes, and admits each new request with `Gaoxy.Admission.begin_request/4`.
  Continuing callbacks use `Gaoxy.Admission.begin_callback/4` with the request's
  absolute monotonic deadline. `retain/3` ends the active callback watchdog.

  Drain sends exactly one `{:gaoxy_drain, gate, lease, absolute_deadline}` message
  per opted-in lease. The native handler finishes admitted work and closes its
  connection; the service continues to own the listener and final cleanup.
  """

  @callback validate_options(term()) :: {:ok, term()} | {:error, term()}
end
