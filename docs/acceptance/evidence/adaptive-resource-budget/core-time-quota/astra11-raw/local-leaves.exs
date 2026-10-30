slice = binary_part(:binary.copy(<<7>>,8192),0,65)
crypto = :crypto.hash_init(:sha256)
atomics = :atomics.new(1, [])
table = :ets.new(:local_leaves, [])
for {name, term} <- [binary: slice, crypto: crypto, atomics: atomics, table: table, closure_binary: fn -> slice end,
 closure_crypto: fn -> crypto end, closure_atomics: fn -> atomics end, closure_ets: fn -> table end,
 mixed: %{slice: slice, crypto: crypto, atomics: atomics, table: table}] do
  encoded = :erlang.term_to_binary(term, [:local])
  result = try do copy = :erlang.binary_to_term(encoded); {:ok, copy === term} rescue e -> {:error, Exception.message(e)} end
  IO.inspect({name,result,:erlang.external_size(term),byte_size(encoded)})
end
