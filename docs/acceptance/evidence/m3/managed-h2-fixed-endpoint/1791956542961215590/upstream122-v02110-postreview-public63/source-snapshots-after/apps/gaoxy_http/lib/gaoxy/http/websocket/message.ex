defmodule Gaoxy.HTTP.WebSocket.Message do
  @moduledoc "Bounded data-message assembly, preserving control frames between fragments."
  defstruct [:opcode, :max_bytes, :max_fragments, bytes: 0, fragments: 0, parts: []]

  def new(options \\ []) do
    %__MODULE__{
      max_bytes: Keyword.get(options, :max_message_bytes, 1_048_576),
      max_fragments: Keyword.get(options, :max_fragments, 128)
    }
  end

  def push(state, %{opcode: opcode, payload: payload}) when opcode in [:ping, :pong, :close],
    do: {:ok, {:control, opcode, payload}, state}

  def push(%{opcode: nil} = state, %{opcode: opcode} = frame) when opcode in [:text, :binary],
    do: append(%{state | opcode: opcode}, frame)

  def push(%{opcode: opcode} = state, %{opcode: :continuation} = frame) when not is_nil(opcode),
    do: append(state, frame)

  def push(_, _), do: {:error, 1002, :fragment_order}

  defp append(state, frame) do
    bytes = state.bytes + byte_size(frame.payload)
    fragments = state.fragments + 1

    cond do
      bytes > state.max_bytes ->
        {:error, 1009, :message_limit}

      fragments > state.max_fragments ->
        {:error, 1009, :fragment_limit}

      frame.fin ->
        payload = IO.iodata_to_binary(Enum.reverse([frame.payload | state.parts]))

        if state.opcode == :text and not String.valid?(payload) do
          {:error, 1007, :invalid_utf8}
        else
          {:ok, {:data, state.opcode, payload},
           %{state | opcode: nil, bytes: 0, fragments: 0, parts: []}}
        end

      true ->
        {:ok, nil,
         %{
           state
           | bytes: bytes,
             fragments: fragments,
             parts: [:binary.copy(frame.payload) | state.parts]
         }}
    end
  end
end
