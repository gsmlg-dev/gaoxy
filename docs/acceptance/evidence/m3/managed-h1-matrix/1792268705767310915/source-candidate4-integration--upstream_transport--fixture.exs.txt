Code.require_file("../../apps/gaoxy_proxy/test/support/managed_h1_matrix_fixture.exs", __DIR__)

defmodule Gaoxy.ManagedH1MatrixAdapter do
  alias Gaoxy.Proxy.ManagedH1MatrixFixture, as: Fixture

  def run do
    {:ok, _} = Application.ensure_all_started(:gaoxy_proxy)
    Logger.configure_backend(:console, device: :standard_error)

    try do
      IO.puts(JSON.encode!(%{event: "fixture_ready"}))
      loop(nil)
    after
      if fixture = Process.delete(:managed_h1_matrix_fixture), do: Fixture.stop(fixture)
    end
  end

  defp loop(fixture) do
    Process.put(:managed_h1_matrix_fixture, fixture)

    case IO.gets("") do
      :eof ->
        raise "coordinator closed before finish"

      line ->
        case JSON.decode!(line) do
          %{"op" => "finish"} ->
            nil = fixture
            IO.puts(JSON.encode!(%{event: "finished", live: 0, forced: 0}))

          command ->
            {fixture, receipt} = Fixture.dispatch(fixture, command)
            Process.put(:managed_h1_matrix_fixture, fixture)
            IO.puts(JSON.encode!(receipt))
            loop(fixture)
        end
    end
  end
end

Gaoxy.ManagedH1MatrixAdapter.run()
