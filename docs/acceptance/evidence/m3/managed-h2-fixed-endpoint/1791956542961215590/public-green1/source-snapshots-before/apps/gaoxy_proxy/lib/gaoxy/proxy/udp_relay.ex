defmodule Gaoxy.Proxy.UDPRelay do
  @moduledoc """
  Bounded UDP unicast associations to one policy-pinned literal upstream.

  Ingress CIDRs restrict network sources; UDP does not authenticate senders.
  Empty datagrams charge one item and one byte while keeping an empty payload.
  Return credits are earned by admitted input. Aggregate egress is bounded by
  admitted associations multiplied by each association's configured rate.
  Payload/copy reservations exclude BEAM process, kernel and OTP socket memory.
  """
  @behaviour Gaoxy.DatagramDispatcher
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.UDPRelay.{Controller, Options}
  @impl true
  def validate_options(options), do: Options.validate(options)
  @impl true
  def validate_service(options, spec), do: Options.service(options, spec)
  @impl true
  def prepare_service(options, spec), do: Options.prepare(options, spec.ip)
  @impl true
  def start_link(context, options), do: Controller.start_link(context, options)
  @impl true
  def control(owner, action, generation),
    do: Lifecycle.call(owner, {:control, action, generation}, Lifecycle.deadline(100))

  @impl true
  def drain(owner, deadline), do: Lifecycle.call(owner, {:drain, deadline}, deadline)
  def status(owner), do: GenServer.call(owner, :status, 100)

  @impl true
  def offer(owner, packet) do
    operation = make_ref()
    handoff_timeout = Map.get(packet, :handoff_timeout, 50)
    handoff_deadline = Lifecycle.deadline(handoff_timeout)
    # First read immutable policy using a control-only message. Neither this
    # request nor the reservation can carry a network binary into the mailbox.
    with {:ok, options, context, timeout} <-
           Lifecycle.call(owner, :offer_context, handoff_deadline) do
      deadline = handoff_deadline
      {ip, port} = packet.peer
      key = {packet.generation, packet.writer_generation, ip, port}
      size = max(1, byte_size(packet.data))

      result =
        with true <- timeout == handoff_timeout || {:error, :stale_configuration},
             true <- Options.source?(options, ip) || {:error, :source_denied},
             true <- (is_integer(port) and port in 1..65_535) || {:error, :source_denied},
             true <-
               byte_size(packet.data) <= options.reservation.max_packet ||
                 {:error, :packet_too_large},
             true <-
               (packet.generation == context.generation and
                  packet.writer_generation == context.writer_generation) ||
                 {:error, :stale_generation},
             {:ok, permit, _worker} <-
               Lifecycle.call(
                 owner,
                 {:reserve, operation, key, size, packet.generation, packet.writer_generation,
                  deadline},
                 deadline
               ),
             do: Lifecycle.call(owner, {:submit, operation, permit, packet}, deadline)

      if not match?({:ok, _}, result), do: send(owner, {:cancel, self(), operation})
      result
    end
  end
end
