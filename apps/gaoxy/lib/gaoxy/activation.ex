defmodule Gaoxy.Activation do
  @moduledoc false
  alias Gaoxy.Lifecycle

  @fixed [
    :id,
    :transport,
    :ip,
    :port,
    :mode,
    :tls,
    :udp,
    :quic,
    :handler_mode,
    :handler,
    :capabilities
  ]

  def run(owner, caller, operation, deadline, services, planned, context, start) do
    # A caller or owner disappearing cannot abandon a startup already executing
    # inside the service supervisor. Retain its completion before rolling back.
    Process.flag(:trap_exit, true)

    result =
      with {:ok, plan} <- Lifecycle.protect(fn -> Gaoxy.Config.validate(services: services) end),
           :ok <- match_plan(plan.services, planned),
           :ok <- pending(context.control, operation, owner, caller, deadline) do
        Enum.reduce_while(plan.services, {:ok, []}, fn spec, {:ok, handles} ->
          with :ok <- pending(context.control, operation, owner, caller, deadline),
               {:ok, handle} <- Lifecycle.protect(fn -> start.(spec) end) do
            {:cont, {:ok, [handle | handles]}}
          else
            error -> {:halt, error}
          end
        end)
      end

    result =
      with {:ok, handles} <- result,
           :ok <- pending(context.control, operation, owner, caller, deadline) do
        send(owner, {:activation_ready, operation, self(), Enum.reverse(handles)})

        receive do
          {:activation_commit, ^operation} -> :committed
          {:activation_cancel, ^operation, reason} -> {:error, reason}
          {:EXIT, ^owner, _} -> {:error, :owner_down}
        end
      end

    unless result == :committed do
      cleanup = rollback(context)
      send(owner, {:activation_done, operation, self(), result, cleanup})
    end
  end

  def rollback(context) do
    result =
      Lifecycle.protect(fn ->
        context.supervisor
        |> Supervisor.which_children()
        |> Enum.reduce(:ok, fn {_, pid, _, _}, outcome ->
          case DynamicSupervisor.terminate_child(context.supervisor, pid) do
            :ok -> outcome
            {:error, :not_found} -> outcome
            error -> error
          end
        end)
      end)

    if result == :ok do
      :ets.delete_all_objects(context.table)
      :ets.delete_all_objects(context.live)
      :complete
    else
      :pending
    end
  catch
    :error, :badarg -> :pending
  end

  def wait(control, operation) do
    case :ets.lookup(control, operation) do
      [{^operation, status}] when status in [:committed, :complete] ->
        :ok

      [] ->
        :ok

      _ ->
        receive do
        after
          2 -> wait(control, operation)
        end
    end
  catch
    :error, :badarg -> :ok
  end

  defp pending(control, operation, owner, caller, deadline) do
    cond do
      not Process.alive?(owner) -> {:error, :owner_down}
      not Process.alive?(caller) -> {:error, :caller_down}
      Lifecycle.remaining(deadline) == 0 -> {:error, :deadline_exceeded}
      true -> control_status(control, operation)
    end
  end

  defp control_status(control, operation) do
    case :ets.lookup(control, operation) do
      [{^operation, :pending}] -> :ok
      [{^operation, {:cancelled, reason}}] -> {:error, reason}
      _ -> {:error, :cancelled}
    end
  catch
    :error, :badarg -> {:error, :owner_down}
  end

  defp match_plan(services, planned) do
    expected = Map.new(planned, &{&1.id, &1})
    actual = Map.new(services, &{&1.id, &1})

    if MapSet.new(Map.keys(expected)) == MapSet.new(Map.keys(actual)) do
      Enum.reduce_while(services, :ok, fn service, _ ->
        original = Map.fetch!(expected, service.id)

        cond do
          Map.take(service, @fixed) != Map.take(original, @fixed) ->
            {:halt, {:error, {:planned_service_changed, service.id}}}

          not within?(service.limits, original.limits) or
              not within?(service.dispatcher, original.dispatcher) ->
            {:halt, {:error, {:planned_service_ceiling, service.id}}}

          true ->
            {:cont, :ok}
        end
      end)
    else
      {:error, {:planned_services_mismatch, Enum.sort(Map.keys(expected))}}
    end
  end

  defp within?(actual, planned),
    do: Enum.all?(actual, fn {key, value} -> value <= Map.fetch!(planned, key) end)
end
