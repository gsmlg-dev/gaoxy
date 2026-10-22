true = is_nil(Process.whereis(ExUnit.Server))
false = Enum.any?(Application.started_applications(), fn {app, _, _} -> app == :ex_unit end)
fixture = Gaoxy.Test.open(mode: :manual)
:ok = Gaoxy.Test.expect_once(fixture, :get, "/", &Plug.Conn.send_resp(&1, 200, "manual"))

{:ok, {{_, 200, _}, _, "manual"}} =
  :httpc.request(:get, {String.to_charlist(Gaoxy.Test.url(fixture)), []}, [],
    body_format: :binary
  )

:ok = Gaoxy.Test.verify!(fixture)
%{status: :ok} = Gaoxy.Test.close(fixture)
true = is_nil(Process.whereis(ExUnit.Server))
IO.puts("GAOXY_TEST_MANUAL_PASS cases=1 exunit_started=false")
