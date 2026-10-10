{:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, buffer: 16_384, recbuf: 16_384, exit_on_close: false])
{:ok, {_, port}} = :inet.sockname(listener)
owner = self()
spawn(fn ->
  {:ok, peer} = :gen_tcp.accept(listener, 1_000)
  :ok = :gen_tcp.send(peer, :binary.copy(<<1>>, 210_000))
  :ok = :gen_tcp.shutdown(peer, :write)
  send(owner, {:reverse, :gen_tcp.recv(peer, 0, 2_000)})
  :gen_tcp.close(peer)
end)
{:ok, client} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false, buffer: 16_384, recbuf: 16_384, exit_on_close: false], 1_000)
read = fn read, sizes ->
  case :gen_tcp.recv(client, 0, 5) do
    {:ok, bytes} -> read.(read, [byte_size(bytes) | sizes])
    {:error, :timeout} -> read.(read, sizes)
    {:error, :closed} -> sizes
  end
end
sizes = read.(read, [])
true = Enum.sum(sizes) == 210_000
true = Enum.max(sizes) <= 16_384
:ok = :gen_tcp.send(client, "reverse-after-fin")
receive do
  {:reverse, {:ok, "reverse-after-fin"}} -> :ok
  message -> raise inspect(message)
after
  2_000 -> raise "reverse probe timeout"
end
:gen_tcp.close(client)
:gen_tcp.close(listener)
IO.inspect(%{runtime: System.version(), otp: :erlang.system_info(:otp_release), sizes: Enum.reverse(sizes), maximum: Enum.max(sizes), total: Enum.sum(sizes), half_close: :pass})
