Code.compiler_options(ignore_module_conflict: true)
Code.compile_file(".audit/issue11/baseline_exchange.ex")
Code.require_file("apps/gaoxy_proxy/test/test_helper.exs")
Code.require_file("apps/gaoxy_proxy/test/websocket_tls_test.exs")
