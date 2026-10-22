defmodule Gaoxy.Test.SSE do
  @moduledoc """
  Finite and explicitly persistent server-sent events over ordinary Plug streams.

  `stream/3` finishes a finite event list. `open/3` emits its initial list, then
  establishes a cancellable session in the request process. Send events with
  `send_event/2`, or finish with `finish/1`. Its total lifetime is bounded by
  `:timeout` (30 seconds by default), including when used outside finalization.
  """
  alias Gaoxy.Test.Response

  def stream(conn, events, options \\ []) when is_list(events) do
    conn = start(conn, options)
    conn = Enum.reduce(events, conn, &emit(&2, &1))
    Response.event(conn, %{type: :stream_complete})
    conn
  end

  def open(conn, events \\ [], options \\ []) when is_list(events) do
    timeout = Keyword.get(options, :timeout, 30_000)
    unless is_integer(timeout) and timeout > 0, do: raise(ArgumentError, "invalid SSE timeout")
    conn = conn |> start(options) |> Response.write_chunk(": established\n\n")
    conn = Enum.reduce(events, conn, &emit(&2, &1))
    :ok = Response.establish(conn)
    Response.event(conn, %{type: :sse_established, session: self()})
    loop(conn, System.monotonic_time(:millisecond) + timeout)
  end

  def send_event(session, event) when is_pid(session) do
    encoded = encode(event)
    send(session, {:gaoxy_test_sse, event, encoded})
    :ok
  end

  def finish(session) when is_pid(session) do
    send(session, :gaoxy_test_sse_finish)
    :ok
  end

  @doc "Encodes text or a map with :data and optional :event, :id and :retry."
  def encode(data) when is_binary(data), do: encode(%{data: data})

  def encode(%{data: data} = event) when is_binary(data) do
    fields =
      Enum.map([:event, :id], fn key ->
        case Map.get(event, key) do
          nil ->
            []

          value when is_binary(value) ->
            if String.contains?(value, ["\r", "\n", <<0>>]),
              do: raise(ArgumentError, "SSE #{key} must be one line")

            [Atom.to_string(key), ": ", value, "\n"]

          _ ->
            raise ArgumentError, "SSE #{key} must be a string"
        end
      end)

    retry =
      case Map.get(event, :retry) do
        nil -> []
        value when is_integer(value) and value >= 0 -> ["retry: ", Integer.to_string(value), "\n"]
        _ -> raise ArgumentError, "SSE retry must be a nonnegative integer"
      end

    data = data |> String.replace("\r\n", "\n") |> String.replace("\r", "\n")
    [fields, retry, Enum.map(String.split(data, "\n"), &["data: ", &1, "\n"]), "\n"]
  end

  def encode(_), do: raise(ArgumentError, "SSE event requires string data")

  defp start(conn, options) do
    headers = Keyword.get(options, :headers, [])

    conn
    |> Plug.Conn.put_resp_content_type("text/event-stream")
    |> Plug.Conn.put_resp_header("cache-control", "no-cache")
    |> Response.start_stream(Keyword.get(options, :status, 200), headers)
  end

  defp emit(conn, event) do
    conn = Response.write_chunk(conn, encode(event))
    Response.event(conn, %{type: :sse_event, event: event})
    conn
  end

  defp loop(conn, deadline) do
    message =
      receive do
        {:gaoxy_test_sse, _, _} = event -> event
        {:gaoxy_test_cancel, _} = event -> event
        event when event in [:gaoxy_test_sse_finish, :gaoxy_test_cancel] -> event
      after
        max(0, deadline - System.monotonic_time(:millisecond)) ->
          raise "persistent SSE session exceeded its timeout"
      end

    if System.monotonic_time(:millisecond) >= deadline,
      do: raise("persistent SSE session exceeded its timeout")

    case message do
      {:gaoxy_test_sse, event, encoded} ->
        conn = Response.write_chunk(conn, encoded)
        Response.event(conn, %{type: :sse_event, event: event})
        loop(conn, deadline)

      :gaoxy_test_sse_finish ->
        Response.event(conn, %{type: :stream_complete})
        conn

      {:gaoxy_test_cancel, reason} ->
        Response.event(conn, %{type: :session_cancelled, reason: reason})
        conn

      :gaoxy_test_cancel ->
        Response.event(conn, %{type: :session_cancelled, reason: :shutdown})
        conn
    end
  end
end
