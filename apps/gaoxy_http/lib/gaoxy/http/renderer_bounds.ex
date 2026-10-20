defmodule Gaoxy.HTTP.RendererBounds do
  @moduledoc false
  alias Gaoxy.HTTP.HTTP2.Frame
  @bytes 65_536
  @nodes 8_192
  @depth 16
  @hop ~w(connection proxy-connection keep-alive transfer-encoding upgrade)
  @forbidden ~w(content-length transfer-encoding host connection trailer te upgrade keep-alive
    proxy-connection authorization proxy-authorization proxy-authenticate www-authenticate
    content-encoding content-type content-range expect cache-control cookie set-cookie)

  # Count constructors before serialization. A list tail does not add nesting;
  # each cons and each byte/binary leaf counts once, and empty tails count zero.
  def iodata(data, external_limit)
      when (is_binary(data) or is_list(data)) and is_integer(external_limit) and
             external_limit in 1..131_072 do
    with {:ok, {_nodes, logical, _backing}} <- walk(data, 1, {0, 0, 0}),
         true <- :erlang.external_size(data) <= external_limit || {:error, :renderer_limit} do
      {:ok, logical}
    end
  end

  def iodata(_, _), do: {:error, :invalid_renderer_iodata}

  def fields(fields, max_count, max_bytes)
      when is_integer(max_count) and max_count > 0 and is_integer(max_bytes) and max_bytes > 0,
      do: pairs(fields, min(max_count, @nodes), min(max_bytes, @bytes), 0, 0)

  def fields(_, _, _), do: {:error, :invalid_renderer_fields}

  # Preserve H2's existing semantic overhead and grammar without constructing a
  # byte list or normalized copy during validation.
  def response_fields(fields, max_count, max_bytes) do
    with :ok <- fields(fields, max_count, max_bytes),
         true <- semantic_fields?(fields, max_bytes, false) do
      :ok
    else
      _ -> {:error, :invalid_response_headers}
    end
  end

  def trailer_fields(fields, max_count, max_bytes) do
    with :ok <- fields(fields, max_count, max_bytes),
         true <- semantic_fields?(fields, max_bytes, true) do
      :ok
    else
      _ -> {:error, :invalid_response_trailers}
    end
  end

  def lower_token?(<<first, rest::binary>>), do: token_byte?(first) and token_tail?(rest)
  def lower_token?(_), do: false
  def field_value?(<<>>), do: true

  def field_value?(<<byte, rest::binary>>),
    do: (byte == 9 or (byte >= 32 and byte != 127)) and field_value?(rest)

  def field_value?(_), do: false

  defp token_tail?(<<>>), do: true
  defp token_tail?(<<byte, rest::binary>>), do: token_byte?(byte) and token_tail?(rest)

  defp token_byte?(byte),
    do: byte in ?a..?z or byte in ?0..?9 or byte in ~c"!#$%&'*+-.^_`|~"

  defp semantic_fields?([], remaining, _), do: remaining >= 0

  defp semantic_fields?([{name, value} | tail], remaining, trailer) do
    remaining = remaining - byte_size(name) - byte_size(value) - 32

    remaining >= 0 and lower_token?(name) and name not in @hop and
      (name != "te" or value == "trailers") and
      (not trailer or name not in @forbidden) and field_value?(value) and
      (value == "" or (:binary.first(value) not in [32, 9] and :binary.last(value) not in [32, 9])) and
      semantic_fields?(tail, remaining, trailer)
  end

  def header_frames(bytes, id, ended, from, deadline)
      when is_binary(bytes) and is_integer(id) and id in 1..2_147_483_647 and
             is_boolean(ended) and is_integer(deadline) and
             deadline in -9_223_372_036_854_775_808..9_223_372_036_854_775_807 do
    cond do
      not caller?(from) ->
        {:error, :invalid_renderer_control}

      byte_size(bytes) > @bytes or :binary.referenced_byte_size(bytes) > @bytes ->
        {:error, :renderer_limit}

      :erlang.external_size(from) > 2_048 ->
        {:error, :renderer_limit}

      true ->
        frames = frames(bytes, id, ended, from, deadline, true, [])

        if :erlang.external_size(frames) <= 73_728 and
             :erlang.external_size({:queue.from_list(frames), id}) <= 73_728,
           do: {:ok, frames},
           else: {:error, :renderer_limit}
    end
  end

  def header_frames(_, _, _, _, _), do: {:error, :invalid_renderer_control}

  defp caller?({pid, ref}) when is_pid(pid) and is_reference(ref), do: true
  defp caller?({pid, [:alias | ref]}) when is_pid(pid) and is_reference(ref), do: true
  defp caller?(_), do: false

  defp frames(bytes, id, ended, from, deadline, first, accumulated) do
    count = min(byte_size(bytes), 16_384)
    <<piece::binary-size(^count), rest::binary>> = bytes
    flags = if(rest == "", do: 4, else: 0) + if(first and ended, do: 1, else: 0)
    callback = if rest == "", do: {:headers, id, from}, else: {:header_fragment, id}
    frame = IO.iodata_to_binary(Frame.encode(if(first, do: 1, else: 9), flags, id, piece))
    entry = {frame, callback, deadline}

    if rest == "",
      do: Enum.reverse([entry | accumulated]),
      else: frames(rest, id, ended, from, deadline, false, [entry | accumulated])
  end

  defp walk(_, _, {nodes, logical, backing})
       when nodes > @nodes or logical > @bytes or backing > @bytes,
       do: {:error, :renderer_limit}

  defp walk([], _, totals), do: {:ok, totals}

  defp walk([_ | _], depth, _) when depth > @depth, do: {:error, :renderer_limit}

  defp walk([head | tail], depth, {nodes, logical, backing}) do
    with {:ok, totals} <- walk(head, depth + 1, {nodes + 1, logical, backing}) do
      case tail do
        [] -> {:ok, totals}
        [_ | _] -> walk(tail, depth, totals)
        _ -> {:error, :invalid_renderer_iodata}
      end
    end
  end

  defp walk(bytes, _, {nodes, logical, backing}) when is_binary(bytes) do
    totals =
      {nodes + 1, logical + byte_size(bytes), backing + :binary.referenced_byte_size(bytes)}

    bounded(totals)
  end

  defp walk(byte, _, {nodes, logical, backing}) when is_integer(byte) and byte in 0..255,
    do: bounded({nodes + 1, logical + 1, backing})

  defp walk(_, _, _), do: {:error, :invalid_renderer_iodata}

  defp bounded({nodes, logical, backing} = totals)
       when nodes <= @nodes and logical <= @bytes and backing <= @bytes,
       do: {:ok, totals}

  defp bounded(_), do: {:error, :renderer_limit}

  defp pairs(_, _, limit, logical, backing) when logical > limit or backing > limit,
    do: {:error, :renderer_limit}

  defp pairs([], _, _, _, _), do: :ok

  defp pairs([{name, value} | tail], remaining, limit, logical, backing)
       when is_binary(name) and is_binary(value) do
    if remaining == 0 do
      {:error, :renderer_limit}
    else
      pairs(
        tail,
        remaining - 1,
        limit,
        logical + byte_size(name) + byte_size(value),
        backing + :binary.referenced_byte_size(name) + :binary.referenced_byte_size(value)
      )
    end
  end

  defp pairs(_, _, _, _, _), do: {:error, :invalid_renderer_fields}
end
