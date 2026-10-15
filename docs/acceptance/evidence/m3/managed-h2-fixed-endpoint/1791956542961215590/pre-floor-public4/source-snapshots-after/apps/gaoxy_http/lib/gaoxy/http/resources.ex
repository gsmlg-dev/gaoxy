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
end
