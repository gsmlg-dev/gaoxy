defmodule Gaoxy.HTTP.Resources do
  @moduledoc "Bounded metadata pins for immutable endpoint resources."
  alias Gaoxy.Lifecycle

  @callback pin_many(list(), pid(), atom(), reference(), integer()) ::
              {:ok, map()} | {:error, term()}
  @callback release(map()) :: :ok | {:error, term()}
  @callback cancel(pid(), reference()) :: :ok

  def validate(handles) when is_list(handles) and length(handles) <= 64 do
    if :erlang.external_size(handles) <= 65_536 and
         Enum.all?(handles, fn
           %{provider: provider, owner: owner, owner_epoch: epoch} ->
             is_atom(provider) and is_pid(owner) and is_reference(epoch) and
               Code.ensure_loaded?(provider) and function_exported?(provider, :pin_many, 5) and
               function_exported?(provider, :release, 1) and
               function_exported?(provider, :cancel, 2)

           _ ->
             false
         end),
       do: {:ok, Enum.uniq(handles)},
       else: {:error, :invalid_endpoint_resources}
  end

  def validate(_), do: {:error, :invalid_endpoint_resources}

  def pin_many(handles, holder, kind, deadline) do
    with {:ok, handles} <- validate(handles),
         true <-
           (is_integer(deadline) and Lifecycle.remaining(deadline) > 0 and is_pid(holder) and
              kind in [:baseline, :preparation, :request]) || {:error, :invalid_resource_pin} do
      batches = Enum.group_by(handles, &{&1.provider, &1.owner})

      Enum.reduce_while(batches, {:ok, []}, fn {{provider, owner}, batch}, {:ok, pins} ->
        operation = make_ref()

        result =
          Lifecycle.protect(fn -> provider.pin_many(batch, holder, kind, operation, deadline) end)

        case result do
          {:ok, pin} ->
            {:cont, {:ok, [pin | pins]}}

          {:error, reason} ->
            Lifecycle.protect(fn -> provider.cancel(owner, operation) end)

            Enum.each(pins, fn pin ->
              Lifecycle.protect(fn -> pin.provider.cancel(pin.owner, pin.operation) end)
            end)

            {:halt, {:error, reason}}
        end
      end)
    end
  end

  def release(pins) when is_list(pins) do
    Enum.reduce(pins, :ok, fn pin, result ->
      case release(pin) do
        :ok -> result
        error -> error
      end
    end)
  end

  def release(%{provider: provider} = pin), do: Lifecycle.protect(fn -> provider.release(pin) end)
  def release(_), do: {:error, :invalid_resource_pin}

  @checked_reasons ~w(invalid_generation_capture generation_capture_capacity generation_unavailable
    generation_pin_release_failed cleanup_unconfirmed invalid_resource_holder byte_limit
    stale_generation deadline_exceeded cleanup_pending)a
  @checked_min -9_223_372_036_854_775_808
  @checked_max 9_223_372_036_854_775_807

  def pin_many_checked(handles, holder, deadline, accounting) do
    with :ok <- checked_ready(holder, deadline),
         {:ok, handles} <- checked_handles(handles),
         :ok <- checked_manifest(accounting, handles) do
      batches = Enum.group_by(handles, &{&1.provider, &1.owner})

      Enum.reduce_while(batches, {[], []}, fn {{provider, owner}, batch}, {pins, ledger} ->
        case checked_ready(holder, deadline) do
          :ok ->
            operation = make_ref()
            entry = {provider, owner, operation, batch}
            # Keep original authority BEFORE even the failing provider effect.
            ledger = [entry | ledger]

            with {:ok, pin} <-
                   checked_pin(provider, batch, holder, operation, deadline, accounting),
                 :ok <- checked_correlation(accounting, pin, entry, holder),
                 :ok <- checked_cons(accounting, pin, pins) do
              {:cont, {[pin | pins], ledger}}
            else
              {:error, reason} -> {:halt, checked_rollback(ledger, reason)}
            end

          {:error, reason} ->
            {:halt, checked_rollback(ledger, reason)}
        end
      end)
      |> case do
        {pins, ledger} ->
          # This synchronous check runs in Store, on its publication path. The
          # original ledger stays alive until the final deadline/holder check.
          case checked_ready(holder, deadline) do
            :ok -> {:ok, pins}
            {:error, reason} -> checked_rollback(ledger, reason)
          end

        {:error, _, _} = error ->
          error
      end
    else
      {:error, reason} -> {:error, reason, :clean}
    end
  end

  def release_checked(pins, deadline, accounting)
      when is_list(pins) and length(pins) <= 64 do
    if :erlang.external_size(pins) <= 65_536 and checked_deadline?(deadline) do
      Enum.reduce(pins, :ok, fn pin, result ->
        if checked_remaining(deadline) > 0 and checked_release(accounting, pin, deadline) == :ok,
          do: result,
          else: {:error, :generation_pin_release_failed}
      end)
    else
      {:error, :generation_pin_release_failed}
    end
  end

  def release_checked(_, _, _), do: {:error, :generation_pin_release_failed}

  defp checked_handles(handles) do
    case validate(handles) do
      {:ok, handles} -> {:ok, handles}
      _ -> {:error, :invalid_generation_capture}
    end
  end

  defp checked_deadline?(deadline),
    do: is_integer(deadline) and deadline >= @checked_min and deadline <= @checked_max

  defp checked_remaining(deadline) do
    now = Lifecycle.now()
    remaining = deadline - now

    if now >= @checked_min and now <= @checked_max and remaining in 1..@checked_max,
      do: remaining,
      else: 0
  end

  defp checked_alive?(holder) do
    Process.alive?(holder)
  catch
    _, _ -> false
  end

  defp checked_ready(holder, deadline) do
    cond do
      not is_pid(holder) ->
        {:error, :invalid_resource_holder}

      not checked_alive?(holder) ->
        {:error, :invalid_resource_holder}

      not checked_deadline?(deadline) or deadline > @checked_max - 1_000 ->
        {:error, :invalid_generation_capture}

      checked_remaining(deadline) == 0 ->
        {:error, :deadline_exceeded}

      true ->
        :ok
    end
  end

  defp checked_manifest(accounting, handles) do
    case accounting.validate_manifest(handles) do
      :ok -> :ok
      {:error, reason} -> {:error, checked_reason(accounting, reason)}
      _ -> {:error, :generation_unavailable}
    end
  catch
    _, _ -> {:error, :generation_unavailable}
  end

  defp checked_pin(provider, batch, holder, operation, deadline, accounting) do
    case provider.pin_many(batch, holder, :request, operation, deadline) do
      {:ok, pin} -> {:ok, pin}
      {:error, reason} -> {:error, checked_reason(accounting, reason)}
      _ -> {:error, :generation_unavailable}
    end
  catch
    _, _ -> {:error, :generation_unavailable}
  end

  defp checked_correlation(accounting, pin, entry, holder) do
    case accounting.correlate(pin, entry, holder) do
      :ok -> :ok
      {:error, reason} -> {:error, checked_reason(accounting, reason)}
      _ -> {:error, :generation_unavailable}
    end
  catch
    _, _ -> {:error, :generation_unavailable}
  end

  defp checked_cons(accounting, pin, pins) do
    case accounting.preflight_cons(pin, pins) do
      {:ok, %{count: count, bytes: bytes} = summary}
      when map_size(summary) == 2 and count in 1..64 and bytes in 2..65_536 ->
        :ok

      {:error, reason} ->
        {:error, checked_reason(accounting, reason)}

      _ ->
        {:error, :generation_unavailable}
    end
  catch
    _, _ -> {:error, :generation_unavailable}
  end

  defp checked_reason(accounting, raw) do
    case accounting.finite_checked_reason(raw) do
      reason when reason in @checked_reasons -> reason
      _ -> :generation_unavailable
    end
  catch
    _, _ -> :generation_unavailable
  end

  defp checked_rollback(ledger, reason) do
    Enum.each(ledger, fn {provider, owner, operation, _batch} ->
      checked_cancel(provider, owner, operation)
    end)

    {:error, reason, if(ledger == [], do: :clean, else: :cleanup_unconfirmed)}
  end

  defp checked_cancel(provider, owner, operation) do
    provider.cancel(owner, operation)
    :ok
  catch
    _, _ -> :ok
  end

  defp checked_release(accounting, pin, deadline) do
    case accounting.release(pin, deadline) do
      :ok -> :ok
      _ -> {:error, :generation_pin_release_failed}
    end
  catch
    _, _ -> {:error, :generation_pin_release_failed}
  end
end
