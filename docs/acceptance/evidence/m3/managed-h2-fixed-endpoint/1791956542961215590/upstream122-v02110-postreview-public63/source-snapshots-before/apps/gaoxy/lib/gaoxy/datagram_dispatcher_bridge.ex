defmodule Gaoxy.DatagramDispatcherBridge do
  @moduledoc false
  @behaviour Abyss.DatagramDispatcher

  @impl true
  def init(abyss, gaoxy: context) do
    context =
      Map.merge(context, %{
        dispatcher: self(),
        generation: context.scope.generation,
        writer_generation: abyss.generation,
        local_info: abyss.local_info,
        send: abyss.send
      })

    ancestors = [self() | Process.get(:"$ancestors", [])]

    result =
      Gaoxy.Lifecycle.bounded(
        fn ->
          Process.put(:"$ancestors", ancestors)

          try do
            with {:ok, owner} when is_pid(owner) <-
                   context.spec.handler.start_link(context, context.spec.handler_options) do
              send(
                context.service,
                {:gaoxy_dispatcher_ready, context.generation, context.startup_token, owner}
              )

              Process.unlink(owner)
              {:ok, owner}
            else
              {:error, _} = error -> error
              _ -> {:error, :invalid_dispatcher_owner}
            end
          after
            # The helper is linked only while startup is outstanding. Its normal
            # EXIT is not part of the dispatcher's public callback protocol.
            Process.unlink(context.dispatcher)
          end
        end,
        context.spec.limits.callback_timeout
      )

    with {:ok, owner} <- result,
         do: {:ok, %{owner: owner, module: context.spec.handler, context: context}}
  end

  @impl true
  def handle_datagram({ip, port} = peer, bytes, received_at, %{state: state} = abyss) do
    context = state.context

    packet = %{
      peer: peer,
      data: bytes,
      received_at: received_at,
      local: Map.get(abyss, :local_info, context.local_info),
      generation: context.generation,
      handoff_timeout: context.spec.dispatcher.handoff_timeout,
      writer_generation: abyss.generation,
      ancillary: bounded_ancillary(abyss[:ancillary])
    }

    key = {context.generation, abyss.generation, ip, port}

    case state.module.offer(state.owner, packet) do
      {:ok, worker} ->
        action = if Map.has_key?(abyss.routes, key), do: :route, else: :new
        {action, [key], worker, state}

      {:error, reason} ->
        Gaoxy.Telemetry.emit(
          :admission_rejected,
          %{count: 1, bytes: byte_size(bytes)},
          context.scope,
          %{reason: reason, source: :dispatcher}
        )

        {:drop, reason, state}
    end
  end

  @impl true
  def terminate(reason, state) do
    send(state.owner, {:gaoxy_dispatcher_terminated, self(), reason})
    :ok
  end

  defp bounded_ancillary(value) when is_list(value) do
    if length(value) <= 16 and :erlang.external_size(value) <= 1024, do: value, else: []
  end

  defp bounded_ancillary(_), do: []
end
