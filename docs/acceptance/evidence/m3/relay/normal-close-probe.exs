owner = self()
{:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, exit_on_close: false,
  ip: {127, 0, 0, 1}, recbuf: 1_024])
{:ok, {ip, port}} = :inet.sockname(listener)
{peer, peer_monitor} = spawn_monitor(fn ->
  {:ok, socket} = :gen_tcp.accept(listener, 2_000)
  :ok = :gen_tcp.shutdown(socket, :write)
  send(owner, {:fin_sent, self()})
  receive do
    {:read, expected} ->
      :ok = :inet.setopts(socket, recbuf: 1_048_576, buffer: 65_536)
      read = fn read, count ->
        case :gen_tcp.recv(socket, 0, 5_000) do
          {:ok, bytes} -> read.(read, count + byte_size(bytes))
          {:error, :closed} -> count
        end
      end
      ^expected = read.(read, 0)
      send(owner, {:peer_payload_preserved, expected})
  after
    2_000 -> raise "normal-close read barrier timed out"
  end
  :gen_tcp.close(socket)
end)
{sender, sender_monitor} = spawn_monitor(fn ->
  Process.flag(:trap_exit, true)
  {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false, exit_on_close: false,
    buffer: 16_384, recbuf: 16_384, send_timeout: 1_000, send_timeout_close: false], 2_000)
  {:error, :closed} = :gen_tcp.recv(socket, 0, 2_000)
  fill = fn fill, accepted ->
    true = accepted < 16_777_216
    :ok = :gen_tcp.send(socket, :binary.copy("x", 16_384))
    {:ok, stats} = :inet.getstat(socket, [:send_pend])
    if stats[:send_pend] > 0,
      do: {accepted + 16_384, stats[:send_pend]},
      else: fill.(fill, accepted + 16_384)
  end
  {accepted, pending} = fill.(fill, 0)
  :ok = :gen_tcp.shutdown(socket, :write)
  send(owner, {:normal_close_started, self(), accepted, pending})
  :ok = :gen_tcp.close(socket)
  send(owner, {:normal_close_returned, self()})
end)
receive do
  {:fin_sent, ^peer} -> :ok
after
  2_000 -> raise "peer FIN not confirmed"
end
{accepted, pending} = receive do
  {:normal_close_started, ^sender, accepted, pending} -> {accepted, pending}
  {:DOWN, ^sender_monitor, :process, ^sender, reason} -> raise inspect(reason)
after
  2_000 -> raise "normal-close pending-output state not reached"
end
started = System.monotonic_time(:millisecond)
early = receive do
  {:normal_close_returned, ^sender} -> :returned
after
  200 -> :still_waiting
end
stack = Process.info(sender, :current_stacktrace)
send(peer, {:read, accepted})
if early != :returned do
  receive do
    {:normal_close_returned, ^sender} -> :ok
  after
    5_000 -> raise "normal close did not return after read credit"
  end
end
receive do
  {:peer_payload_preserved, ^accepted} -> :ok
after
  5_000 -> raise "accepted payload was not preserved"
end
for {pid, monitor} <- [{peer, peer_monitor}, {sender, sender_monitor}] do
  receive do
    {:DOWN, ^monitor, :process, ^pid, :normal} -> :ok
  after
    5_000 -> raise "normal-close probe process DOWN not confirmed"
  end
end
:gen_tcp.close(listener)
IO.inspect(%{runtime: System.version(), otp: :erlang.system_info(:otp_release),
  accepted_bytes: accepted, pending_driver_bytes: pending, after200ms: early,
  owner_stack_before_read_credit: stack, elapsed: System.monotonic_time(:millisecond) - started,
  payload: :preserved, command_processes: :confirmed_down}, limit: :infinity)
