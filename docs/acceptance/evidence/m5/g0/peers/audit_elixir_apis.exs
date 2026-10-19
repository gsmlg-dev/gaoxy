root = System.fetch_env!("M5_PEER_DEP_ROOT")
{lock, _} = Code.eval_file("mix.lock")

for package <- [:http_core, :elixir_quic_http3, :elixir_quic] do
  name = Atom.to_string(package)
  {{:hex, _, _}, metadata} =
    File.read!(Path.join([root, "deps", name, ".hex"])) |> :erlang.binary_to_term()
  IO.inspect({package, metadata}, label: "SOURCE_METADATA")
  {:hex, ^package, version, checksum, _, _, _, outer_checksum} = Map.fetch!(lock, package)
  ^version = metadata.version
  ^checksum = metadata.inner_checksum
  ^outer_checksum = metadata.outer_checksum
end

alias QuicHttp3.{Control, Settings}
8 = Settings.enable_connect_protocol()

if Code.ensure_loaded(Abyss.QUIC) == {:error, :nofile} do
  Code.require_file(Path.join(root, "deps/abyss/lib/abyss/quic.ex"))
end

for value <- [0, 1] do
  settings = [{1, 0}, {6, 65_536}, {7, 0}, {8, value}]
  {:ok, bytes} = Settings.encode(settings)
  {:ok, ^settings} = Settings.decode(bytes)
  {:ok, server} = Control.new(:server, settings)
  {:ok, client} = Control.new(:client)
  {:ok, _client, [{:settings, ^settings}]} =
    Control.receive_peer(client, {:control, value}, Control.local_payload(server))
  IO.puts("PASS setting 8=#{value}: encode/decode + Control.new(:server)/local_payload/receive_peer")
end

{:error, reason} = Control.new(:server, [{8, 2}])
IO.inspect(reason, label: "PASS invalid setting 8=2 rejected")

for {module, function, arity} <- [
      {Quic, :send_stream, 4}, {Quic, :read, 3}, {Quic, :events, 3},
      {Quic, :operation_status, 2}, {Abyss.QUIC, :send_stream, 4}
    ] do
  {:module, ^module} = Code.ensure_loaded(module)
  true = function_exported?(module, function, arity)
  IO.puts("PASS public export #{inspect(module)}.#{function}/#{arity}")
end

IO.puts("API_CASES=8 EXIT=0; no network DATA/FIN execution or Gaoxy WebSocket acceptance")
