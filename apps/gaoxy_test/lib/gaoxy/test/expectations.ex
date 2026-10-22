defmodule Gaoxy.Test.Expectations do
  @moduledoc false

  def new do
    %{routes: %{}, active: %{}, failures: [], cursor: 0, admitted: 0, completed: 0}
  end

  def normalize_method(method) when is_atom(method), do: normalize_method(Atom.to_string(method))

  def normalize_method(method) when is_binary(method) and byte_size(method) > 0,
    do: String.upcase(method)

  def normalize_method(_), do: raise(ArgumentError, "method must be a nonempty string or atom")

  def normalize_path(path) when is_binary(path) do
    if String.starts_with?(path, "/") and not String.contains?(path, ["?", "#"]) do
      path
    else
      raise ArgumentError, "path must start with / and exclude query and fragment"
    end
  end

  def normalize_path(_), do: raise(ArgumentError, "path must be a string")

  def register(state, method, path, handler, requirement) when is_function(handler, 1) do
    route = {normalize_method(method), normalize_path(path)}

    cond do
      not valid_requirement?(requirement) ->
        {:error, "times must be a positive integer"}

      Map.has_key?(state.routes, route) ->
        {:error, "duplicate expectation for #{elem(route, 0)} #{elem(route, 1)}"}

      true ->
        definition = %{handler: handler, requirement: requirement, admitted: 0, received: 0}
        {:ok, put_in(state.routes[route], definition)}
    end
  end

  def register(_state, _method, _path, _handler, _requirement),
    do: {:error, "handler must be a unary function"}

  def reserve(state, method, path) do
    route = {normalize_method(method), normalize_path(path)}
    request_id = state.cursor + 1
    state = %{state | cursor: request_id}

    case Map.fetch(state.routes, route) do
      :error ->
        failure = %{type: :unexpected, request_id: request_id, route: route}
        {fail(state, failure), {:error, request_id, :unexpected}}

      {:ok, definition} ->
        definition = %{definition | received: definition.received + 1}
        state = put_in(state.routes[route], definition)

        if exhausted?(definition) do
          failure = %{type: :excessive, request_id: request_id, route: route}
          {fail(state, failure), {:error, request_id, :excessive}}
        else
          state = put_in(state.routes[route].admitted, definition.admitted + 1)

          active =
            Map.put(state.active, request_id, %{route: route, persistent: false, upgraded: false})

          state = %{state | active: active, admitted: state.admitted + 1}
          {state, {:ok, request_id, definition.handler}}
        end
    end
  end

  def establish(state, request_id) do
    case Map.fetch(state.active, request_id) do
      {:ok, request} ->
        state = put_in(state.active[request_id], %{request | persistent: true})
        {:ok, if(request.upgraded, do: complete(state, request_id, :ok), else: state)}

      :error ->
        {:error, :unknown_request}
    end
  end

  def complete(state, request_id, :upgraded) do
    case Map.fetch(state.active, request_id) do
      {:ok, %{persistent: true}} -> complete(state, request_id, :ok)
      {:ok, request} -> put_in(state.active[request_id], %{request | upgraded: true})
      :error -> state
    end
  end

  def complete(state, request_id, outcome) do
    case Map.pop(state.active, request_id) do
      {nil, _} ->
        state

      {request, active} ->
        state = %{state | active: active, completed: state.completed + 1}

        case outcome do
          :ok ->
            state

          {:cancelled, _reason} when request.persistent ->
            state

          {:failure, kind, reason, stacktrace} ->
            fail(state, %{
              type: :callback,
              request_id: request_id,
              route: request.route,
              kind: kind,
              reason: reason,
              stacktrace: stacktrace
            })

          reason ->
            fail(state, %{
              type: :terminated,
              request_id: request_id,
              route: request.route,
              reason: reason
            })
        end
    end
  end

  def fail(state, failure), do: %{state | failures: [failure | state.failures]}

  def ordinary_pending(state, cursor \\ nil) do
    for {request_id, %{persistent: false}} <- state.active,
        is_nil(cursor) or request_id <= cursor,
        do: request_id
  end

  def snapshot(state) do
    %{cursor: state.cursor, routes: state.routes, admitted: state.admitted}
  end

  def report(state, snapshot \\ nil) do
    snapshot = snapshot || snapshot(state)

    missing =
      for {route, definition} <- Enum.sort(snapshot.routes),
          missing?(definition),
          do: %{
            type: :missing,
            route: route,
            expected: definition.requirement,
            admitted: definition.admitted,
            received: definition.received
          }

    failures =
      state.failures
      |> Enum.reverse()
      |> Enum.filter(&(Map.get(&1, :request_id, 0) <= snapshot.cursor))

    pending = Enum.sort(ordinary_pending(state, snapshot.cursor))
    failures = missing ++ failures ++ Enum.map(pending, &%{type: :pending, request_id: &1})

    active_count =
      Enum.count(state.active, fn {request_id, _} -> request_id <= snapshot.cursor end)

    %{
      status: if(failures == [], do: :ok, else: :error),
      failures: failures,
      cursor: snapshot.cursor,
      observed: snapshot.cursor,
      admitted: snapshot.admitted,
      completed: snapshot.admitted - active_count,
      pending: pending,
      expectations:
        Map.new(snapshot.routes, fn {route, definition} ->
          {route, Map.drop(definition, [:handler])}
        end)
    }
  end

  defp valid_requirement?(:at_least_one), do: true
  defp valid_requirement?(:stub), do: true
  defp valid_requirement?({:exact, count}), do: is_integer(count) and count > 0
  defp valid_requirement?(_), do: false

  defp exhausted?(%{requirement: {:exact, count}, admitted: admitted}), do: admitted >= count
  defp exhausted?(_), do: false
  defp missing?(%{requirement: :stub}), do: false
  defp missing?(%{requirement: :at_least_one, admitted: admitted}), do: admitted < 1
  defp missing?(%{requirement: {:exact, count}, admitted: admitted}), do: admitted < count
end
