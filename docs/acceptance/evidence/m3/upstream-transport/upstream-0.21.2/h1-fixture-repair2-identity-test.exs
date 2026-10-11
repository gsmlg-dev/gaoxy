Code.require_file(
  Path.expand("../../integration/http_fetch_contract/managed_h1_accounting_fixture.exs", __DIR__)
)

ExUnit.start(autorun: false, max_cases: 1, seed: 21_112_026, timeout: 10_000)

defmodule H1FixtureRuntimeIdentityTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Qualification.ManagedH1AccountingFixture, as: Fixture

  test "fixture startup binds actual loaded modules to original disk bytes" do
    assert :ok = Fixture.configure!(["--baseline"])

    identity =
      JSON.decode!(File.read!(".audit/m3-transport/h1-slice-b-implementation/run-identity.json"))

    assert identity["cohort"] == "0.21.2"
    assert identity["runtime_sources_count"] == 175
    assert length(identity["beams"]) == 10
    assert identity["telemetry"] == %{"http_fetch" => false, "http_runtime" => false}
    assert Enum.all?(identity["versions"], fn {_app, version} -> version == "0.21.2" end)

    for row <- identity["beams"] do
      module = String.to_existing_atom(row["module"])
      assert row["origin"] == Path.expand(to_string(:code.which(module)))
      assert row["sha256"] == Fixture.sha256(File.read!(row["origin"]))
      assert row["loaded_md5"] == Base.encode16(module.module_info(:md5), case: :lower)
    end

    assert identity["native_origins"] != []

    for row <- identity["native_origins"] do
      assert File.regular?(row["origin"])
      assert row["sha256"] == Fixture.sha256(File.read!(row["origin"]))
    end
  end
end

totals = ExUnit.run()
IO.puts("H1_FIXTURE_IDENTITY_REGRESSION_SUMMARY " <> inspect(totals))

if totals.total != 1 or totals.failures != 0 or totals.skipped != 0 or totals.excluded != 0,
  do: raise("local fixture identity regression failed")
