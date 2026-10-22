defmodule Gaoxy.Test.Response do
  @moduledoc "Small Plug response helpers with journal observations for finite streams."

  import Plug.Conn

  def send(conn, status, body, headers \\ []) do
    conn |> merge_resp_headers(headers) |> send_resp(status, body)
  end

  def redirect(conn, location, status \\ 302) do
    conn |> put_resp_header("location", location) |> send_resp(status, "")
  end

  @doc "Sends a finite list of iodata chunks. Socket errors raise in the request callback."
  def stream(conn, status, chunks, options \\ []) when is_list(chunks) do
    conn = start_stream(conn, status, Keyword.get(options, :headers, []))
    conn = Enum.reduce(chunks, conn, &write_chunk(&2, &1))
    event(conn, %{type: :stream_complete})
    conn
  end

  @doc false
  def start_stream(conn, status, headers) do
    conn = conn |> merge_resp_headers(headers) |> send_chunked(status)
    event(conn, %{type: :stream_headers, status: status})
    conn
  end

  @doc false
  def write_chunk(conn, bytes) do
    case chunk(conn, bytes) do
      {:ok, conn} ->
        event(conn, %{type: :stream_chunk, bytes: IO.iodata_length(bytes)})
        conn

      {:error, reason} ->
        raise "fixture stream write failed: #{inspect(reason)}"
    end
  end

  @doc false
  def event(conn, event) do
    %{instance: instance, request_id: request_id} = Map.fetch!(conn.private, :gaoxy_test)
    Gaoxy.Test.Instance.event(instance, request_id, event)
  end

  @doc false
  def establish(conn) do
    %{instance: instance, request_id: request_id} = Map.fetch!(conn.private, :gaoxy_test)
    :ok = Gaoxy.Test.Instance.establish(instance, request_id, self())
  end
end
