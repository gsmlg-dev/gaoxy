defmodule Gaoxy.HTTP.Diagnostics do
  @moduledoc false

  @event [:gaoxy, :http, :failure]
  @reasons ~w(header_timeout request_timeout malformed_request malformed_body plug_exception
    endpoint_error endpoint_throw endpoint_exit endpoint_failure response_not_sent peer_closed
    response_failed protocol_error ambiguous_framing authority authority_mismatch body_limit content_length expectation
    header header_bytes_limit header_count_limit host http_version line_ending method port
    request_line request_line_limit request_target transfer_encoding scheme_mismatch)a

  # One context per synchronous H1 owner. Registry removes it on owner death;
  # watchdog telemetry can observe it before killing a blocked endpoint.
  def start(protocol, stream_id \\ nil) do
    context = %{
      protocol: protocol,
      stream_id: stream_id,
      request_id: make_ref(),
      started: System.monotonic_time(),
      status: nil,
      response_committed: false,
      once: :atomics.new(1, []),
      stage: :headers
    }

    store(context)

    :ok
  end

  def stage(stage), do: change(&%{&1 | stage: stage})

  def response(status),
    do: change(&%{&1 | status: status, response_committed: true})

  def failure(stage, reason) do
    case context(self()) do
      context when is_map(context) ->
        emit_once(context, stage, reason)

      _ ->
        :ok
    end
  end

  def finish do
    Process.delete(__MODULE__)
    registry(fn -> Registry.unregister(Gaoxy.Registry, {__MODULE__, self()}) end)
  end

  def attach do
    case :telemetry.attach(__MODULE__, [:gaoxy, :timeout], &__MODULE__.timeout/4, nil) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end

  def timeout(_, _, %{owner: owner}, _) do
    case context(owner) do
      context when is_map(context) ->
        emit_once(context, context.stage, :request_timeout)

      _ ->
        :ok
    end
  end

  def timeout(_, _, _, _), do: :ok

  def reason_bytes, do: Enum.max(Enum.map(@reasons, &:erlang.external_size/1))

  def endpoint_reason({:plug_exception, _}), do: :plug_exception
  def endpoint_reason({:error, _}), do: :endpoint_error
  def endpoint_reason({:throw, _}), do: :endpoint_throw
  def endpoint_reason({:exit, _}), do: :endpoint_exit
  def endpoint_reason({:request_error, _, _}), do: :malformed_body
  def endpoint_reason(:timeout), do: :request_timeout
  def endpoint_reason(reason) when reason in [:closed, :einval, :enotconn], do: :peer_closed
  def endpoint_reason(:response_not_sent), do: :response_not_sent
  def endpoint_reason(_), do: :endpoint_failure

  def emit(protocol, stage, reason, status, committed, started, correlation) do
    metadata = %{
      protocol: if(protocol in [:http1, :http2], do: protocol, else: :unknown),
      stage: if(stage in [:headers, :request, :endpoint, :protocol], do: stage, else: :request),
      reason: if(reason in @reasons, do: reason, else: :protocol_error),
      status: if(committed == true and is_integer(status) and status in 100..599, do: status),
      response_committed: committed == true,
      request_id: if(is_reference(correlation[:request_id]), do: correlation[:request_id]),
      stream_id:
        if(is_integer(correlation[:stream_id]) and correlation[:stream_id] in 1..2_147_483_647,
          do: correlation[:stream_id]
        )
    }

    :telemetry.execute(
      @event,
      %{count: 1, duration: max(0, System.monotonic_time() - started)},
      metadata
    )
  end

  defp emit_once(context, stage, reason) do
    if :atomics.compare_exchange(context.once, 1, 0, 1) == :ok do
      emit_context(context, stage, reason)
    end
  end

  defp emit_context(context, stage, reason),
    do:
      emit(
        context.protocol,
        stage,
        reason,
        context.status,
        context.response_committed,
        context.started,
        context
      )

  defp context(owner) when owner == self(), do: Process.get(__MODULE__)

  defp context(owner) do
    case Gaoxy.RegistryPolicy.lookup({__MODULE__, owner}) do
      {:ok, [{^owner, context}]} -> context
      _ -> nil
    end
  end

  defp change(function) do
    case context(self()) do
      nil -> :ok
      context -> store(function.(context))
    end
  end

  defp store(context) do
    Process.put(__MODULE__, context)

    registry(fn ->
      case Registry.register(Gaoxy.Registry, {__MODULE__, self()}, context) do
        {:ok, _} ->
          :ok

        {:error, {:already_registered, _}} ->
          Registry.update_value(Gaoxy.Registry, {__MODULE__, self()}, fn _ -> context end)
      end
    end)
  end

  # Registry loss already has a service lifecycle recovery policy. Diagnostics
  # must neither interrupt a wire operation nor detach its watchdog handler.
  defp registry(operation) do
    operation.()
    :ok
  rescue
    ArgumentError -> :ok
  catch
    :exit, _ -> :ok
  end
end
