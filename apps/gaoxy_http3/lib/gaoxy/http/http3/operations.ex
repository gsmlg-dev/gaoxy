defmodule Gaoxy.HTTP.HTTP3.Operations do
  @moduledoc false
  alias Gaoxy.Lifecycle

  def new, do: :ets.new(__MODULE__, [:set, :public, read_concurrency: true])

  @metadata_defaults %{
    max_headers: 100,
    max_header_bytes: 32_768,
    max_trailers: 32,
    max_trailer_bytes: 8_192
  }

  def register(table, key, token, deadline, limits \\ @metadata_defaults) do
    limits =
      Map.take(limits, Map.keys(@metadata_defaults))
      |> Map.merge(%{websocket: :http, demand: nil, last_demand: nil})

    cond do
      :ets.info(table, :owner) != self() -> {:error, :closed}
      Lifecycle.remaining(deadline) == 0 -> {:error, :timeout}
      :ets.info(table, :size) >= 8 -> {:error, :slot_limit}
      :ets.insert_new(table, {key, token, nil, nil, deadline, :starting, limits}) -> :ok
      true -> {:error, :closed}
    end
  rescue
    ArgumentError -> {:error, :closed}
  end

  def bind(table, key, token, worker) when is_pid(worker) do
    change(table, key, token, :owner, fn
      {_, _, nil, _, _, :starting, _} = row -> {:ok, put_elem(row, 2, worker), :ok}
      _ -> {:error, :closed}
    end)
  end

  # Lookup is bounded by the existing eight operation rows. An admitted worker
  # resolves the opaque transport capability only after its owner binds it.
  def resolve(table, token) when is_reference(token) do
    case :ets.match_object(table, {:_, token, self(), :_, :_, :starting, :_}) do
      [{key, ^token, _, _, deadline, :starting, _}] -> {:ok, key, deadline}
      _ -> {:error, :closed}
    end
  rescue
    ArgumentError -> {:error, :closed}
  end

  def ready(table, key, token, lease) when is_reference(lease) do
    change(table, key, token, :worker, fn
      {_, _, _, nil, _, :starting, _} = row ->
        {:ok, row |> put_elem(3, lease) |> put_elem(5, :ready), :ok}

      _ ->
        {:error, :closed}
    end)
  end

  def activate(table, key, token, worker) do
    change(table, key, token, :owner, fn
      {_, _, ^worker, _, _, :ready, _} = row -> {:ok, put_elem(row, 5, :idle), :ok}
      _ -> {:error, :closed}
    end)
  end

  def status(table, key, token) do
    with {:ok, {_, _, worker, lease, deadline, state, metadata}} <- row(table, key, token),
         do:
           {:ok,
            %{
              worker: worker,
              lease: lease,
              deadline: deadline,
              status: state,
              websocket: metadata.websocket,
              demand: metadata.demand
            }}
  end

  def upgrade(table, key, token, reference, lifetime) do
    change(table, key, token, :owner, fn
      {_, _, _, lease, original, {:claimed, ^reference, {:websocket_open, _, ^lifetime}, _},
       metadata} = row
      when is_reference(lease) and (is_integer(lifetime) or lifetime == :infinity) ->
        if metadata.websocket == :http and Lifecycle.remaining(original) != 0 and
             Lifecycle.remaining(lifetime) != 0 do
          {:ok, row |> put_elem(4, lifetime) |> put_elem(6, %{metadata | websocket: :opening}),
           :ok}
        else
          {:error, :closed}
        end

      _ ->
        {:error, :closed}
    end)
  end

  # Independent of the single output/HTTP operation slot: an idle receive
  # demand cannot prevent the same worker from submitting an application push.
  def demand(table, key, token, credit, ref)
      when is_integer(credit) and credit in 0..16_384 and is_reference(ref) do
    change(table, key, token, :worker, fn {_, _, _, _, deadline, status, metadata} = row ->
      cond do
        metadata.websocket != :open or terminal?(status) ->
          {:error, :closed}

        Lifecycle.remaining(deadline) == 0 ->
          {:error, :timeout}

        match?({:pending, _, _}, metadata.demand) ->
          {:error, :pending_read}

        credit == 0 and not match?({:delivered, ^ref, _}, metadata.demand) ->
          {:error, :stale_demand}

        credit > 0 and metadata.last_demand == ref ->
          {:error, :stale_demand}

        true ->
          next = %{
            metadata
            | demand: if(credit == 0, do: nil, else: {:pending, ref, credit}),
              last_demand: ref
          }

          {:ok, put_elem(row, 6, next), :ok}
      end
    end)
  end

  def demand(_, _, _, _, _), do: {:error, :operation_limit}

  def deliver(table, key, token, ref, bytes, ended) when is_binary(bytes) and is_boolean(ended) do
    result =
      change(table, key, token, :owner, fn
        {_, _, worker, _, deadline, status, %{demand: {:pending, ^ref, credit}} = metadata} = row ->
          if metadata.websocket == :open and not terminal?(status) and
               Lifecycle.remaining(deadline) != 0 and byte_size(bytes) <= credit do
            {:ok, put_elem(row, 6, %{metadata | demand: {:delivered, ref, byte_size(bytes)}}),
             {:notify, worker}}
          else
            {:error, :closed}
          end

        _ ->
          {:error, :closed}
      end)

    case result do
      {:notify, worker} ->
        send(worker, {:gaoxy_websocket_data, token, ref, bytes, ended})
        :ok

      error ->
        error
    end
  end

  def close_demand(table, key, token) do
    change(table, key, token, :worker, fn {_, _, _, _, _, status, metadata} = row ->
      if metadata.websocket == :open and not terminal?(status),
        do: {:ok, put_elem(row, 6, %{metadata | websocket: :closing, demand: nil}), :ok},
        else: {:error, :closed}
    end)
  end

  def submit(table, key, token, {operation, deadline}) do
    change(table, key, token, :worker, fn {_, _, _, _, original, state, limits} = row ->
      cond do
        match?({:websocket_open, _, _}, operation) and limits.websocket != :http ->
          {:error, :closed}

        not is_integer(deadline) or Lifecycle.earlier(deadline, original) != deadline or
            Lifecycle.remaining(deadline) == 0 ->
          {:error, :timeout}

        state != :idle ->
          if terminal?(state), do: {:error, :closed}, else: {:error, :busy}

        not valid_operation?(operation, deadline, limits) ->
          {:error, :operation_limit}

        true ->
          reference = make_ref()
          {:ok, put_elem(row, 5, {:submitted, reference, operation, deadline}), {:ok, reference}}
      end
    end)
  end

  def claim(table, key, token) do
    result =
      change(table, key, token, :owner, fn
        {_, _, worker, _, _, {:submitted, ref, operation, deadline}, _} = row ->
          if Lifecycle.remaining(deadline) == 0 do
            {:ok, put_elem(row, 5, {:cancelled, ref, :timeout}),
             {:notify, worker, ref, {:error, :timeout}}}
          else
            {:ok, put_elem(row, 5, {:claimed, ref, operation, deadline}),
             {:ok, worker, ref, operation, deadline}}
          end

        _ ->
          :idle
      end)

    case result do
      {:notify, worker, ref, reply} ->
        send(worker, {:http3_operation, token, ref, reply})
        {:error, :timeout}

      result ->
        result
    end
  end

  def reply(table, key, token, reference, result) do
    case change(table, key, token, :owner, fn
           {_, _, worker, _, _, {:claimed, ^reference, operation, deadline}, metadata} = row ->
             if Lifecycle.remaining(deadline) == 0,
               do: {:ok, put_elem(row, 5, {:cancelled, reference, :timeout}), {:error, :timeout}},
               else: begin_reply(row, metadata, operation, reference, result, deadline, worker)

           _ ->
             {:error, :closed}
         end) do
      {:notify, worker} ->
        send(worker, {:http3_operation, token, reference, result})
        :ok

      error ->
        error
    end
  end

  defp begin_reply(row, metadata, operation, reference, result, deadline, worker) do
    metadata =
      if match?({:websocket_open, _, _}, operation) and result == :ok,
        do: %{metadata | websocket: :open},
        else: metadata

    {:ok, row |> put_elem(5, {:completed, reference, result, deadline}) |> put_elem(6, metadata),
     {:notify, worker}}
  end

  def ack(table, key, token, reference) do
    change(table, key, token, :worker, fn
      {_, _, _, _, _, {:completed, ^reference, _, deadline}, _} = row ->
        if Lifecycle.remaining(deadline) == 0,
          do: {:ok, put_elem(row, 5, {:cancelled, reference, :timeout}), {:error, :timeout}},
          else: {:ok, put_elem(row, 5, :idle), :ok}

      _ ->
        {:error, :closed}
    end)
  end

  def timeout(table, key, token, reference) do
    change(table, key, token, :worker, fn
      {_, _, _, _, _, {kind, ^reference, _, _}, _} = row
      when kind in [:submitted, :claimed, :completed] ->
        {:ok, put_elem(row, 5, {:cancelled, reference, :timeout}), :ok}

      {_, _, _, _, _, {:cancelled, ^reference, :timeout}, _} ->
        :ok

      _ ->
        {:error, :closed}
    end)
  end

  def cancel(table, key, token, reason) do
    result =
      change(table, key, token, :owner, fn
        {_, _, worker, _, _, {kind, ref, _, _}, _} = row when kind in [:submitted, :claimed] ->
          {:ok, put_elem(row, 5, {:cancelled, ref, reason}), {:notify, worker, ref}}

        {_, _, _, _, _, {:cancelled, _, _}, _} ->
          :ok

        row ->
          {:ok, put_elem(row, 5, {:cancelled, nil, reason}), :ok}
      end)

    case result do
      {:notify, worker, reference} ->
        send(worker, {:http3_operation, token, reference, {:error, reason}})
        :ok

      result ->
        result
    end
  end

  def finish(table, key, token, result) do
    change(table, key, token, :worker, fn
      {_, _, _, _, _, :idle, _} = row ->
        if :erlang.external_size(result) <= 1_024,
          do: {:ok, put_elem(row, 5, {:finished, result}), :ok},
          else: {:error, :operation_limit}

      _ ->
        {:error, :closed}
    end)
  end

  def finish(table, key, token, result, gate, accounting, deadline) do
    with {:ok, %{worker: worker, lease: lease, status: :idle}} when worker == self() <-
           status(table, key, token),
         :ok <- Gaoxy.Admission.end_request(gate, lease, accounting, deadline) do
      finish(table, key, token, result)
    end
  end

  def remove(table, key, token) do
    with true <- :ets.info(table, :owner) == self(),
         {:ok, row} <- row(table, key, token),
         true <- :ets.delete_object(table, row) do
      :ok
    else
      _ -> {:error, :closed}
    end
  rescue
    ArgumentError -> {:error, :closed}
  end

  defp row(table, key, token) do
    case :ets.lookup(table, key) do
      [{^key, ^token, _, _, _, _, _} = row] -> {:ok, row}
      _ -> {:error, :closed}
    end
  rescue
    ArgumentError -> {:error, :closed}
  end

  defp change(table, key, token, side, fun, attempts \\ 8) do
    with {:ok, row} <- row(table, key, token),
         true <-
           if(side == :owner,
             do: :ets.info(table, :owner) == self(),
             else: elem(row, 2) == self()
           ) do
      case fun.(row) do
        {:ok, next, result} ->
          # Map/struct keys are opaque values, not partial match-spec patterns.
          # Retaining the bound key also proves select_replace preserves the key.
          variables = {:"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7"}

          guards =
            for index <- 0..6, do: {:"=:=", elem(variables, index), {:const, elem(row, index)}}

          replacement = put_elem(next, 0, :"$1")

          body =
            replacement
            |> Tuple.to_list()
            |> Enum.with_index()
            |> Enum.map(fn
              {key, 0} -> key
              {value, _} -> {:const, value}
            end)
            |> List.to_tuple()

          cond do
            :ets.select_replace(table, [{variables, guards, [{body}]}]) == 1 -> result
            attempts > 0 -> change(table, key, token, side, fun, attempts - 1)
            true -> {:error, :busy}
          end

        result ->
          result
      end
    else
      _ -> {:error, :closed}
    end
  rescue
    ArgumentError -> {:error, :closed}
  end

  defp terminal?({:cancelled, _, _}), do: true
  defp terminal?({:finished, _}), do: true
  defp terminal?(_), do: false

  defp valid_operation?({:read, credit, {:until, io_deadline}}, deadline, _),
    do:
      is_integer(credit) and credit in 1..16_384 and is_integer(io_deadline) and
        io_deadline <= deadline

  defp valid_operation?({:poll, {:until, io_deadline}}, deadline, _),
    do: is_integer(io_deadline) and io_deadline <= deadline

  defp valid_operation?({:head, status, fields, ended}, _, limits),
    do:
      status in 100..599 and fields?(fields, limits.max_headers, limits.max_header_bytes) and
        is_boolean(ended)

  defp valid_operation?({:websocket_open, fields, lifetime}, _, limits),
    do:
      (is_integer(lifetime) or lifetime == :infinity) and Lifecycle.remaining(lifetime) != 0 and
        fields?(fields, limits.max_headers, limits.max_header_bytes)

  defp valid_operation?({:websocket_finish}, _, limits), do: limits.websocket == :closing

  defp valid_operation?({:trailers, fields}, _, limits),
    do: fields?(fields, limits.max_trailers, limits.max_trailer_bytes)

  defp valid_operation?(operation, _, _), do: valid_operation?(operation)

  defp valid_operation?({:data, bytes, ended}),
    do: is_binary(bytes) and byte_size(bytes) <= 16_384 and is_boolean(ended)

  defp valid_operation?({:abort, reason}), do: :erlang.external_size(reason) <= 1_024
  defp valid_operation?(_), do: false

  defp fields?(fields, count, maximum) when is_list(fields) do
    length(fields) <= count and
      Enum.all?(fields, fn
        {name, value} -> is_binary(name) and is_binary(value)
        _ -> false
      end) and Gaoxy.HTTP.HTTP2.Headers.bytes(fields) <= maximum
  end

  defp fields?(_, _, _), do: false
end
