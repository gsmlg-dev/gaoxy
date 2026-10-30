parent = :binary.copy(<<7>>, 32_768)
slice = binary_part(parent, 0, 65)
crypto = :crypto.hash_init(:sha256)
atomics = :atomics.new(1, [])
table = :ets.new(:roundtrip_resource_proof, [])
app = %{slice: slice, nested: [{slice, [slice | :tail]}], function: fn -> {slice, crypto, atomics, table} end,
        pid: self(), ref: make_ref(), crypto: crypto, atomics: atomics, table: table,
        struct: %URI{path: slice}}
copy = :erlang.binary_to_term(:erlang.term_to_binary(app))
true = app === copy
true = :crypto.hash_final(:crypto.hash_update(copy.crypto, "fixture")) == :crypto.hash(:sha256, "fixture")
:ok = :atomics.put(copy.atomics, 1, 42)
42 = :atomics.get(atomics, 1)
true = :ets.insert(copy.table, {:fixture, 42})
[fixture: 42] = :ets.lookup(table, :fixture)
{copied_slice, copied_crypto, copied_atomics, copied_table} = copy.function.()
true = :crypto.hash_final(:crypto.hash_update(copied_crypto, "closure")) == :crypto.hash(:sha256, "closure")
42 = :atomics.get(copied_atomics, 1)
[fixture: 42] = :ets.lookup(copied_table, :fixture)
65 = :binary.referenced_byte_size(copied_slice)
65 = :binary.referenced_byte_size(copy.struct.path)
true = :ets.delete(table)
IO.inspect(%{logical_slice: byte_size(slice), original_backing: :binary.referenced_byte_size(slice),
  copied_backing: :binary.referenced_byte_size(copy.slice), value_preserved: app === copy,
  usable_crypto: true, usable_atomics: true, usable_ets: true, usable_closure_resources: true,
  same_vm_only: true}, label: "RESOURCE_PROOF_PASS")
