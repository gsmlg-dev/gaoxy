ExUnit.start(autorun: false, seed: 33015, max_cases: 1)
path = Path.expand("apps/gaoxy_proxy/test/managed_h2_group_native_tls_ownership_test.exs")
source = File.read!(path)
needle = "assert :ok = :ssl.close(socket)\n\n      for {pid, monitor} <- joins do"
replacement = """
snapshot = try do
  {_, state} = :sys.get_state(owner)
  {Map.keys(state.streams), Process.info(worker, [:status, :current_function]), Process.info(native.writer, :status)}
catch
  kind, reason -> {kind, reason}
end
IO.inspect({:native_tls_before_peer_close, unquote(protocol), owner, native.writer, worker, snapshot}, limit: :infinity)
assert :ok = :ssl.close(socket)

for {pid, monitor} <- joins do
"""
true = String.contains?(source, needle)
source = String.replace(source, needle, replacement, global: false)
needle2 = "assert_receive {:DOWN, ^monitor, :process, ^pid, reason}, @timeout"
replacement2 = """
assert_receive {:DOWN, ^monitor, :process, ^pid, reason}, @timeout
role = cond do
  pid === owner -> :owner
  pid === native.writer -> :writer
  pid === worker -> :original_worker
end
IO.inspect({:native_tls_original_join, unquote(protocol), role, pid, reason})
"""
true = String.contains?(source, needle2)
Code.compile_string(String.replace(source, needle2, replacement2, global: false), path)
result = ExUnit.run()
System.halt(if result.failures == 0, do: 0, else: 2)
