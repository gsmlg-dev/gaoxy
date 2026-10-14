defmodule Gaoxy.HTTP.HTTP2.Settings do
  @moduledoc false

  def defaults,
    do: %{
      table_size: 4_096,
      initial_window: 65_535,
      max_frame: 16_384,
      max_header_list: 4_294_967_295,
      enable_push: 1
    }

  def apply(settings, payload) when rem(byte_size(payload), 6) == 0 do
    with {:ok, next} <- parse(settings, payload),
         do: {:ok, next, next.initial_window - settings.initial_window}
  end

  def apply(_, _), do: {:error, :frame_size_error}

  defp parse(settings, <<>>), do: {:ok, settings}

  defp parse(settings, <<key::16, value::32, rest::binary>>) do
    case setting(settings, key, value) do
      {:ok, next} -> parse(next, rest)
      error -> error
    end
  end

  defp setting(settings, 1, value), do: {:ok, %{settings | table_size: value}}

  defp setting(settings, 2, value) when value in [0, 1],
    do: {:ok, %{settings | enable_push: value}}

  defp setting(_, 2, _), do: {:error, :protocol_error}

  defp setting(settings, 4, value) when value <= 2_147_483_647,
    do: {:ok, %{settings | initial_window: value}}

  defp setting(_, 4, _), do: {:error, :flow_control_error}

  defp setting(settings, 5, value) when value in 16_384..16_777_215,
    do: {:ok, %{settings | max_frame: value}}

  defp setting(_, 5, _), do: {:error, :protocol_error}
  defp setting(settings, 6, value), do: {:ok, %{settings | max_header_list: value}}
  defp setting(settings, _, _), do: {:ok, settings}
end
