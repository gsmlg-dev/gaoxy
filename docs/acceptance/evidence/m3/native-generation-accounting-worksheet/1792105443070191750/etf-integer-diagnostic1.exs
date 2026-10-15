values = [0, 255, 256, 2_144_725_072, 2_144_725_073, 2_147_483_647, 2_147_483_648, 4_294_967_295, 4_294_967_296, 18_446_744_073_709_551_615, 18_446_744_073_709_551_616]
Enum.each(values, fn value ->
  bytes = :erlang.term_to_binary(value)
  IO.inspect(%{integer: value, external_size: :erlang.external_size(value), encoded: :binary.bin_to_list(bytes)})
end)
