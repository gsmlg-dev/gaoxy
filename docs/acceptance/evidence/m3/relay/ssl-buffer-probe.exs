:ok = :ssl.start()
ssl_root = :ssl |> :code.lib_dir() |> to_string()
source_files = ~w(ssl_gen_statem.erl tls_gen_connection.erl ssl_internal.hrl ssl_record.hrl)
source = Map.new(source_files, fn name ->
  path = Path.join([ssl_root, "src", name])
  bytes = File.read!(path)
  {name, %{path: path, sha256: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)}}
end)
active = Application.get_env(:ssl, :internal_active_n, 100)
true = is_integer(active) and active in 1..100
buffer = 16_384
bound = 100 * buffer + 18_437
dir = Path.join(System.tmp_dir!(), "gaoxy-relay-ssl-#{System.unique_integer([:positive])}")
script = Path.expand("scripts/generate-fixtures.sh")
{_, 0} = System.cmd("bash", [script, dir], stderr_to_stdout: true)
payload = :binary.copy(<<0, 255, 1, 2>>, 786_432)
size = byte_size(payload)
options = [:binary, active: false, packet: :raw, buffer: buffer, recbuf: buffer]
{:ok, listener} = :ssl.listen(0, options ++ [ip: {127, 0, 0, 1},
  certfile: String.to_charlist(Path.join(dir, "cert.pem")),
  keyfile: String.to_charlist(Path.join(dir, "key.pem"))])
{:ok, {ip, port}} = :ssl.sockname(listener)
read = fn read, socket, remaining, sizes ->
  if remaining == 0 do
    sizes
  else
    {:ok, bytes} = :ssl.recv(socket, 0, 2_000)
    true = byte_size(bytes) <= bound
    read.(read, socket, remaining - byte_size(bytes), [byte_size(bytes) | sizes])
  end
end
owner = self()
{peer, monitor} = spawn_monitor(fn ->
  {:ok, raw} = :ssl.transport_accept(listener, 2_000)
  {:ok, socket} = :ssl.handshake(raw, 2_000)
  sizes = read.(read, socket, size, [])
  :ok = :ssl.send(socket, payload)
  {:ok, "done"} = :ssl.recv(socket, 4, 2_000)
  send(owner, {:server_sizes, sizes})
  :ssl.close(socket, 0)
end)
{:ok, socket} = :ssl.connect(ip, port, options ++ [verify: :verify_peer,
  cacertfile: String.to_charlist(Path.join(dir, "ca.pem")),
  server_name_indication: ~c"localhost"], 2_000)
:ok = :ssl.send(socket, payload)
client_sizes = read.(read, socket, size, [])
:ok = :ssl.send(socket, "done")
server_sizes = receive do
  {:server_sizes, sizes} -> sizes
  {:DOWN, ^monitor, :process, ^peer, reason} -> raise inspect(reason)
after
  2_000 -> raise "SSL burst probe timed out"
end
receive do
  {:DOWN, ^monitor, :process, ^peer, :normal} -> :ok
after
  2_000 -> raise "SSL peer shutdown unconfirmed"
end
:ssl.close(socket, 0)
:ssl.close(listener, 0)
File.rm_rf!(dir)
IO.inspect(%{runtime: System.version(), otp: :erlang.system_info(:otp_release),
  ssl_root: ssl_root, source: source, active: active, transport_buffer: buffer,
  conservative_delivery_bound: bound, client_recv0_max: Enum.max(client_sizes),
  server_recv0_max: Enum.max(server_sizes), bytes_each_direction: size}, limit: :infinity)
