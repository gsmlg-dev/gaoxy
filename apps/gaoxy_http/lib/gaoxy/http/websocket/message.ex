defmodule Gaoxy.HTTP.WebSocket.Message do
  @moduledoc "Data-message assembly with optional policies and interleaved control frames."
  defstruct [:opcode, :frame_fin, :max_bytes, :max_fragments, bytes: 0, fragments: 0, parts: []]

  def new(options \\ []) do
    %__MODULE__{
      max_bytes: Keyword.get(options, :max_message_bytes, :infinity),
      max_fragments: Keyword.get(options, :max_fragments, :infinity)
    }
  end

  def push(state, %{opcode: opcode, payload: payload}) when opcode in [:ping, :pong, :close],
    do: {:ok, {:control, opcode, payload}, state}

  def push(state, %{opcode: opcode, fin: fin, payload: payload}) do
    with {:ok, nil, state} <- consume(state, {:start, opcode, fin, byte_size(payload)}),
         {:ok, nil, state} <- consume(state, {:payload, payload}) do
      consume(state, :end)
    end
  end

  def push(_, _), do: {:error, 1002, :fragment_order}

  @doc false
  def consume(state, {:control, opcode, payload}) when opcode in [:ping, :pong, :close],
    do: {:ok, {:control, opcode, payload}, state}

  def consume(%{frame_fin: nil, opcode: nil} = state, {:start, opcode, fin, _size})
      when opcode in [:text, :binary],
      do: begin_frame(%{state | opcode: opcode}, fin)

  def consume(%{frame_fin: nil, opcode: opcode} = state, {:start, :continuation, fin, _size})
      when not is_nil(opcode),
      do: begin_frame(state, fin)

  def consume(%{frame_fin: fin} = state, {:payload, payload}) when is_boolean(fin) do
    bytes = state.bytes + byte_size(payload)

    if exceeds?(bytes, state.max_bytes) do
      {:error, 1009, :message_limit}
    else
      parts = if payload == "", do: state.parts, else: [:binary.copy(payload) | state.parts]
      {:ok, nil, %{state | bytes: bytes, parts: parts}}
    end
  end

  def consume(%{frame_fin: true} = state, :end) do
    payload = IO.iodata_to_binary(Enum.reverse(state.parts))

    if state.opcode == :text and not String.valid?(payload) do
      {:error, 1007, :invalid_utf8}
    else
      {:ok, {:data, state.opcode, payload},
       %{state | opcode: nil, frame_fin: nil, bytes: 0, fragments: 0, parts: []}}
    end
  end

  def consume(%{frame_fin: false} = state, :end),
    do: {:ok, nil, %{state | frame_fin: nil}}

  def consume(_, _), do: {:error, 1002, :fragment_order}

  defp begin_frame(state, fin) do
    fragments = state.fragments + 1

    if exceeds?(fragments, state.max_fragments) do
      {:error, 1009, :fragment_limit}
    else
      {:ok, nil, %{state | fragments: fragments, frame_fin: fin}}
    end
  end

  defp exceeds?(_, :infinity), do: false
  defp exceeds?(value, limit), do: value > limit
end
