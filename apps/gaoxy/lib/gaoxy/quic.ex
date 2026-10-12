defmodule Gaoxy.QUIC do
  @moduledoc """
  Bounded optional facade over opaque `Abyss.QUIC` handles; no protocol engine.

  Writes admit at most min(configured output, 16 KiB). Reads consume at most
  min(requested bytes, configured input, 16 KiB). A write receipt is admission,
  not local UDP completion or peer delivery. Resolve unknown references with
  `operation_status/2` on the connection; never automatically retry them.
  Only the attached callback owner can reserve application I/O bytes.
  """
  alias Gaoxy.Admission

  defmodule Connection do
    @moduledoc false
    @enforce_keys [:handle, :gate, :lease, :limits, :scope]
    defstruct @enforce_keys ++ [:service, :instance]
  end

  defmodule Stream do
    @moduledoc false
    @enforce_keys [:handle, :connection]
    defstruct @enforce_keys
  end

  def ready(%Connection{handle: handle}), do: Abyss.QUIC.ready(handle)
  def info(%Connection{handle: handle}), do: Abyss.QUIC.info(handle)

  def operation_status(%Connection{handle: handle}, reference),
    do: Abyss.QUIC.operation_status(handle, reference)

  def open_stream(%Connection{} = connection, kind, options \\ []) do
    with {:ok, options} <- options(options, connection),
         {:ok, handle} <- Abyss.QUIC.open_stream(connection.handle, kind, options),
         do: {:ok, %Stream{handle: handle, connection: connection}}
  end

  def read(%Stream{} = stream, maximum, options \\ []) do
    with true <- (is_integer(maximum) and maximum > 0) || {:error, :invalid_read_limit},
         {:ok, options} <- options(options, stream.connection) do
      limit = min(maximum, min(stream.connection.limits.max_packet, 16_384))
      Abyss.QUIC.read(stream.handle, limit, options)
    end
  end

  def send_stream(stream, bytes, fin \\ false, options \\ [])

  def send_stream(%Stream{connection: connection} = stream, bytes, fin, options)
      when is_binary(bytes) and is_boolean(fin) do
    size = byte_size(bytes)

    with true <- size <= min(connection.limits.max_output, 16_384) || {:error, :output_limit},
         {:ok, options} <- options(options, connection),
         :ok <- Admission.adjust_bytes(connection.gate, connection.lease, size) do
      try do
        with {:ok, operation} <- Admission.start_send(connection.gate, connection.lease, size) do
          result =
            Abyss.QUIC.send_stream(
              stream.handle,
              bytes,
              fin,
              Keyword.put(options, :ref, operation)
            )

          recorded =
            case result do
              {:ok, ^operation} -> {:admitted, operation}
              {:unknown, ^operation} -> {:unknown, operation}
              {:blocked, reason} -> {:blocked, reason}
              {:error, reason} when is_atom(reason) -> {:error, reason}
              _ -> {:error, :quic_send_failed}
            end

          :ok = Admission.finish_send(connection.gate, connection.lease, operation, recorded)
          result
        end
      after
        Admission.adjust_bytes(connection.gate, connection.lease, -size)
      end
    end
  end

  def send_stream(_, _, _, _), do: {:error, :invalid_write}

  def reset_stream(%Stream{} = stream, code, options \\ []) do
    with {:ok, options} <- options(options, stream.connection),
         do: Abyss.QUIC.reset_stream(stream.handle, code, options)
  end

  def stop_stream(%Stream{} = stream, code, options \\ []) do
    with {:ok, options} <- options(options, stream.connection),
         do: Abyss.QUIC.stop_stream(stream.handle, code, options)
  end

  def close(%Connection{} = connection, code \\ 0, reason \\ <<>>, options \\ []) do
    with {:ok, options} <- options(options, connection),
         do: Abyss.QUIC.close(connection.handle, code, reason, options)
  end

  defp options(options, connection) do
    if Keyword.keyword?(options) and
         Keyword.keys(options) -- [:timeout, :deadline] == [] and
         length(options) == map_size(Map.new(options)) and
         is_integer(Keyword.get(options, :timeout, 1)) and
         Keyword.get(options, :timeout, 1) in 1..connection.limits.callback_timeout and
         is_integer(Keyword.get(options, :deadline, 0)) do
      {:ok, Keyword.put_new(options, :timeout, min(1_000, connection.limits.callback_timeout))}
    else
      {:error, :invalid_operation_options}
    end
  end
end
