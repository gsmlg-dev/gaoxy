Code.require_file("support/managed_h1_matrix_fixture.exs", __DIR__)

defmodule Gaoxy.Proxy.UpstreamTransportH1MatrixTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH1MatrixFixture, as: Fixture

  @moduletag :capture_log
  # 35s driver watchdog + 40s composed accounting dispatch + 10s cleanup,
  # with 5s framework scheduling headroom; protocol phase budgets stay unchanged.
  @moduletag timeout: 90_000

  for mount <- ["fixed", "group"],
      downstream <- ["h1", "h2"],
      upstream <- ["tcp", "tls"],
      family <- ["temporal_and_declared_trailers", "representation_and_reuse"] do
    case_id = Enum.join([mount, downstream, upstream, family], "/")
    @case_id case_id
    test case_id do
      assert %{"event" => "case_result", "case" => @case_id, "status" => "PASS"} =
               Fixture.run_case(@case_id)
    end
  end
end
