defmodule Gaoxy.Test.DispatchPlug do
  @moduledoc false
  @behaviour Plug
  alias Gaoxy.Test.Instance

  def init(options), do: options

  def call(conn, {coordinator, fixture_id}) do
    metadata = %{
      method: conn.method,
      path: conn.request_path,
      headers: conn.req_headers,
      protocol: Plug.Conn.get_http_protocol(conn)
    }

    case Instance.admit(coordinator, fixture_id, metadata) do
      {:ok, request_id, handler, capture_limit} ->
        conn =
          Plug.Conn.put_private(conn, :gaoxy_test, %{
            instance: coordinator,
            request_id: request_id
          })

        conn =
          if capture_limit,
            do: capture_adapter(conn, coordinator, request_id, capture_limit),
            else: conn

        try do
          result = handler.(conn)

          unless match?(%Plug.Conn{}, result) and
                   result.state in [:set, :sent, :chunked, :file, :upgraded],
                 do:
                   raise(Gaoxy.Test.InvalidHandlerError,
                     message: "handler must return a responding Plug.Conn"
                   )

          result = if result.state == :set, do: Plug.Conn.send_resp(result), else: result
          outcome = if result.state == :upgraded, do: :upgraded, else: :ok
          Instance.complete(coordinator, request_id, outcome)
          unwrap(result)
        catch
          kind, reason ->
            stacktrace = __STACKTRACE__
            Instance.complete(coordinator, request_id, {:failure, kind, reason, stacktrace})
            :erlang.raise(kind, reason, stacktrace)
        end

      {:error, _reason} ->
        Plug.Conn.send_resp(conn, 500, "Gaoxy.Test rejected request")
    end
  end

  defp capture_adapter(conn, coordinator, request_id, limit) do
    {adapter, payload} = conn.adapter

    %{
      conn
      | adapter:
          {Gaoxy.Test.DispatchPlug.CaptureAdapter,
           {adapter, payload, coordinator, request_id, limit, 0}}
    }
  end

  defp unwrap(
         %{adapter: {Gaoxy.Test.DispatchPlug.CaptureAdapter, {adapter, payload, _, _, _, _}}} =
           conn
       ),
       do: %{conn | adapter: {adapter, payload}}

  defp unwrap(conn), do: conn
end

defmodule Gaoxy.Test.DispatchPlug.CaptureAdapter do
  @moduledoc false
  @behaviour Plug.Conn.Adapter

  def read_req_body({adapter, payload, coordinator, request_id, limit, seen}, options) do
    case adapter.read_req_body(payload, options) do
      {status, data, next} when status in [:ok, :more] ->
        available = max(limit - seen, 0)
        capture = binary_part(data, 0, min(byte_size(data), available))

        Gaoxy.Test.Instance.capture(
          coordinator,
          request_id,
          capture,
          status == :ok,
          seen + byte_size(data) > limit
        )

        {status, data, {adapter, next, coordinator, request_id, limit, seen + byte_size(data)}}

      error ->
        error
    end
  end

  for {function, arity} <- [
        send_resp: 4,
        send_file: 6,
        send_chunked: 3,
        chunk: 2,
        inform: 3,
        upgrade: 3
      ] do
    arguments = Macro.generate_arguments(arity - 1, __MODULE__)

    def unquote(function)(
          {adapter, payload, coordinator, request_id, limit, seen},
          unquote_splicing(arguments)
        ) do
      result = apply(adapter, unquote(function), [payload, unquote_splicing(arguments)])

      case result do
        {:ok, body, next} -> {:ok, body, {adapter, next, coordinator, request_id, limit, seen}}
        {:ok, next} -> {:ok, {adapter, next, coordinator, request_id, limit, seen}}
        other -> other
      end
    end
  end

  for function <- [:get_peer_data, :get_sock_data, :get_ssl_data, :get_http_protocol] do
    def unquote(function)({adapter, payload, _, _, _, _}),
      do: apply(adapter, unquote(function), [payload])
  end
end
