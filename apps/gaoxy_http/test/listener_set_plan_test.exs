defmodule Gaoxy.HTTP.ListenerSetPlanTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.ListenerSet

  defmodule Endpoint do
    def init(options) do
      if options[:observer], do: send(options[:observer], :initialized)
      {:ok, options}
    end

    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "listener-set")
  end

  test "planning is stable, preserves the target declaration and performs no initialization" do
    declaration = [id: :site, endpoint: {Endpoint, []}, listeners: [http: [port: 0]]]
    assert {:ok, first} = ListenerSet.plan(declaration)
    assert {:ok, ^first} = ListenerSet.plan(declaration)
    assert first.target == {:endpoint, Endpoint, []}
    assert first.service_ids == %{http: "site:http"}
    refute_received :initialized
  end

  test "pure declarations reject runtime capabilities and field errors identify the listener" do
    assert {:error, {:field, [:target], :runtime_value}} =
             ListenerSet.plan(
               id: :site,
               endpoint: {Endpoint, [observer: self()]},
               listeners: [http: []]
             )

    assert {:error, {:field, [:listeners, :http, :port], :invalid_port}} =
             ListenerSet.plan(id: :site, endpoint: {Endpoint, []}, listeners: [http: [port: -1]])

    assert {:error, {:field, [:listeners, :http, :initialized], :unknown_option}} =
             ListenerSet.plan(
               id: :site,
               endpoint: {Endpoint, []},
               listeners: [http: [initialized: true]]
             )

    assert {:error, {:field, [:listeners, :http, :limits], :invalid_limits}} =
             ListenerSet.plan(
               id: :site,
               endpoint: {Endpoint, []},
               listeners: [http: [limits: []]]
             )

    assert {:error, {:field, [:listeners, :http, :protocols], :invalid_http_protocols}} =
             ListenerSet.plan(
               id: :site,
               endpoint: {Endpoint, []},
               listeners: [http: [protocols: :http2]]
             )
  end

  test "same-family conflicts and duplicate physical IDs fail before any preparation" do
    assert {:error, {:binding_conflict, "site:https", "site:http"}} =
             ListenerSet.plan(
               id: :site,
               endpoint: {Endpoint, []},
               listeners: [
                 http: [port: 8443],
                 https: [port: 8443, certfile: "missing", keyfile: "missing"]
               ]
             )

    assert {:error, {:duplicate_service, :same}} =
             ListenerSet.plan(
               id: :site,
               endpoint: {Endpoint, []},
               listeners: [http: [], https: []],
               service_ids: %{http: :same, https: :same}
             )
  end

  test "preparation initializes the real target once and repeated service validation reuses it" do
    {:ok, plan} =
      ListenerSet.plan(id: :prepared, endpoint: {Endpoint, []}, listeners: [http: [port: 0]])

    assert {:ok, [_]} = ListenerSet.planned_services(plan)
    refute_received :initialized
    assert {:ok, [service]} = ListenerSet.prepare(plan, target: {Endpoint, [observer: self()]})
    assert_receive :initialized
    assert {:ok, _} = Gaoxy.Config.service(service)
    refute_received :initialized
  end

  test "all disabled Phoenix roles preserve the empty child list and true H3 is rejected" do
    assert [] = Gaoxy.PhoenixAdapter.child_specs(Endpoint, http: false, https: nil, http3: false)
    assert_raise ArgumentError, fn -> Gaoxy.PhoenixAdapter.child_specs(Endpoint, http3: true) end

    assert_raise ArgumentError, fn ->
      Gaoxy.PhoenixAdapter.child_specs(Endpoint, http3: [port: 0])
    end
  end

  test "generation snapshot reservation is preflighted together with H1 and H2 worker budgets" do
    alias Gaoxy.HTTP.ListenerSet.PreparedTarget
    provider = Gaoxy.HTTP.ListenerProvider.HTTP
    target = %PreparedTarget{endpoint: {Gaoxy.HTTP.Generation, %{snapshot_bytes: 4_096}}}

    for protocols <- [[:http1], [:http2]] do
      options = [id: :budget, ip: {127, 0, 0, 1}, port: 0, protocols: protocols]

      options =
        if protocols == [:http2], do: Keyword.put(options, :h2c, :prior_knowledge), else: options

      assert {:ok, base} = provider.materialize(:http, options, :planned)
      http = base.handler_options.http_limits

      floor =
        if protocols == [:http2] do
          reserve = Gaoxy.HTTP.HTTP2.Limits.reservation(http, base.handler_options.h2_limits)
          reserve.connection + reserve.decode + reserve.stream + reserve.writer
        else
          2 * http.max_header_bytes + http.max_buffer_bytes + 4 * http.max_read_chunk
        end

      insufficient = Keyword.put(options, :limits, %{max_bytes: floor + 4_095})
      assert {:error, :generation_byte_budget} = provider.materialize(:http, insufficient, target)
      sufficient = Keyword.put(options, :limits, %{max_bytes: floor + 4_096})
      assert {:ok, _} = provider.materialize(:http, sufficient, target)
    end
  end
end
