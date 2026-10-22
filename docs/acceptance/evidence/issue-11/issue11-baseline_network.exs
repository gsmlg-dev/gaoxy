Code.compiler_options(ignore_module_conflict: true)
Code.compile_file(".audit/issue11/baseline_exchange.ex")
Code.require_file("apps/gaoxy_http/test/test_helper.exs")
Code.require_file("apps/gaoxy_http/test/http_network_test.exs")
