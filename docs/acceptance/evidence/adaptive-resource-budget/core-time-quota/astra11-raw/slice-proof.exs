parent = :binary.copy(<<7>>, 32_768)
slice = binary_part(parent, 0, 65)
true = :binary.referenced_byte_size(slice) == 32_768
app = %{slice: slice, nested: [{slice, [slice | :tail]}], function: fn -> slice end, pid: self(), ref: make_ref()}
encoded = :erlang.term_to_binary(app)
copy = :erlang.binary_to_term(encoded)
true = app === copy
true = :binary.referenced_byte_size(copy.slice) == 65
true = :binary.referenced_byte_size(copy.function.()) == 65
IO.inspect(%{logical_slice: byte_size(slice), original_backing: :binary.referenced_byte_size(slice),
  copied_backing: :binary.referenced_byte_size(copy.slice), closure_backing: :binary.referenced_byte_size(copy.function.()),
  value_preserved: app === copy, state_bytes: :erlang.external_size(app), encoded_bytes: byte_size(encoded)}, label: "SLICE_PROOF_PASS")
