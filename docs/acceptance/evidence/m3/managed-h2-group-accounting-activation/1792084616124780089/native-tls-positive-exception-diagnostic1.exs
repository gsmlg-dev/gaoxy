ExUnit.start(autorun: false, seed: 33015, max_cases: 1)
path = Path.expand("apps/gaoxy_proxy/test/managed_h2_group_native_tls_ownership_test.exs")
source = File.read!(path)
original = "Plug.Conn.get_ssl_data(Exchange.plug_conn(exchange)),"
replacement = """
(try do
  Plug.Conn.get_ssl_data(Exchange.plug_conn(exchange))
rescue
  error ->
    send(observer, {:native_tls_get_ssl_data_error, self(), error.__struct__, Exception.message(error), :code.is_loaded(Gaoxy.PlugAdapter)})
    reraise error, __STACKTRACE__
end),
"""
true = String.contains?(source, original)
Code.compile_string(String.replace(source, original, replacement, global: false), path)
result = ExUnit.run()
System.halt(if result.failures == 0, do: 0, else: 2)
