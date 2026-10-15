defmodule FixedHPAXShapeDiagnostic do
  alias Gaoxy.HTTP.RendererBounds
  def stats(value), do: walk(value, 1, %{nodes: 0, depth: 0, logical: 0, backing: 0})
  defp walk([], _, totals), do: totals
  defp walk([head | tail], depth, totals) do
    totals = %{totals | nodes: totals.nodes + 1, depth: max(totals.depth, depth)}
    totals = walk(head, depth + 1, totals)
    walk(tail, depth, totals)
  end
  defp walk(bytes, _, totals) when is_binary(bytes) do
    %{totals | nodes: totals.nodes + 1, logical: totals.logical + byte_size(bytes),
      backing: totals.backing + :binary.referenced_byte_size(bytes)}
  end
  defp walk(byte, _, totals) when is_integer(byte) and byte in 0..255 do
    %{totals | nodes: totals.nodes + 1, logical: totals.logical + 1}
  end
  def fields([], encoder), do: {[], encoder}
  def fields([field | tail], encoder) do
    {chunk, encoder} = HPAX.encode(:never_store, [field], encoder)
    {rest, encoder} = fields(tail, encoder)
    {[chunk | rest], encoder}
  end
  def main do
    for count <- [15, 16, 128, 256] do
      values = [{":status", "200"} | for(i <- 1..(count - 1), do: {"x-check", Integer.to_string(i)})]
      :ok = RendererBounds.fields(values, 256, 65_536)
      table = HPAX.resize(HPAX.new(0), 0)
      {whole, _} = HPAX.encode(:never_store, values, table)
      {parts, _} = fields(values, table)
      {:ok, bytes} = RendererBounds.iodata(parts, 131_072)
      encoded = IO.iodata_to_binary(parts)
      true = byte_size(encoded) == bytes
      {:ok, ^values, _} = HPAX.decode(encoded, HPAX.new(0))
      # Exact bounded trusted fixture only. This diagnostic flatten establishes
      # public codec byte equality; production must retain preflight first.
      true = encoded == IO.iodata_to_binary(whole)
      {:ok, frames} = RendererBounds.header_frames(encoded, 1, false, {self(), make_ref()},
        System.monotonic_time(:millisecond) + 5000)
      IO.puts("HPAX_SHAPE_DIAGNOSTIC " <> JSON.encode!(%{fields: count,
        full: Map.merge(stats(whole), %{etf: :erlang.external_size(whole), guard: inspect(RendererBounds.iodata(whole, 131_072))}),
        per_field: Map.merge(stats(parts), %{etf: :erlang.external_size(parts), guard: inspect(RendererBounds.iodata(parts, 131_072))}),
        wire_bytes_equal: true, roundtrip_fields_equal: true, frame_count: length(frames),
        kind: "TRUSTED_PUBLIC_CODEC_DIAGNOSTIC_NOT_SERVER_ACCEPTANCE"}))
    end
  end
end
FixedHPAXShapeDiagnostic.main()
