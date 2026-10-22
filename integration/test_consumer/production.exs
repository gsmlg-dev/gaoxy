for app <- [:gaoxy_test, :ex_unit, :gaoxy_http, :gaoxy_http3] do
  false = Enum.any?(Mix.Dep.load_and_cache(), &(&1.app == app))
  false = Enum.any?(Application.started_applications(), fn {running, _, _} -> running == app end)
end

{:error, :bad_name} = :code.lib_dir(:gaoxy_test)

IO.puts("GAOXY_TEST_PRODUCTION_PASS cases=1 helper_absent=true exunit_absent=true")
