prefix = "http://example.test:"
origin = prefix <> :binary.copy("0", 65_536 - byte_size(prefix) - 2) <> "80"
source = %{protocol: :h2c, origin: origin, connect_address: {127, 0, 0, 1}, trust: nil}
{:ok, policy, _} = Gaoxy.Proxy.ManagedH2Preparation.prepare_policy(%{source | origin: "http://example.test"})
IO.puts(JSON.encode!(%{
  logical_bytes: byte_size(origin),
  actual_backing_bytes: :binary.referenced_byte_size(origin),
  original_result: inspect(Gaoxy.Proxy.ManagedH2Preparation.prepare_policy(source)),
  copied_backing_bytes: :binary.referenced_byte_size(:binary.copy(origin)),
  copied_result: elem(Gaoxy.Proxy.ManagedH2Preparation.prepare_policy(%{source | origin: :binary.copy(origin)}), 0),
  struct_enumerable: inspect(Enumerable.impl_for(policy)),
  map_to_list_includes_struct: List.keymember?(Map.to_list(policy), :__struct__, 0)
}))
