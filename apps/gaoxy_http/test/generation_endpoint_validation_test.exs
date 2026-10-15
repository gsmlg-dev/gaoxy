defmodule Gaoxy.HTTP.GenerationEndpointValidationTest do
  use ExUnit.Case, async: true

  alias Gaoxy.HTTP.{Generation, Router}
  alias Gaoxy.HTTP.Generation.Store

  defmodule Legacy do
    def init(value), do: {:ok, value}
    def call(exchange, _), do: {:ok, exchange}
  end

  defmodule Checked do
    def init(value), do: {:ok, value}
    def call(exchange, _), do: {:ok, exchange}
    def generation_validate(:accept), do: :ok
    def generation_validate(:deny), do: {:error, :unsupported_generation_endpoint}
    def generation_validate(:raise), do: raise("test-owned generation validation exception")
    def generation_validate(:throw), do: throw(:test_owned_validation_throw)
    def generation_validate(:exit), do: exit(:test_owned_validation_exit)

    def generation_validate({:observed, owner, marker}) do
      send(owner, {:generation_validated, marker})
      :ok
    end

    def generation_validate(value), do: value
  end

  test "the generation validation callback is optional and legacy endpoints still prepare and activate" do
    callbacks = Gaoxy.HTTP.Endpoint.behaviour_info(:callbacks)
    optional = Gaoxy.HTTP.Endpoint.behaviour_info(:optional_callbacks)
    assert {:generation_validate, 1} in callbacks
    assert {:generation_validate, 1} in optional
    store = start_supervised!({Generation, routes: routes(Legacy, :old)})
    assert {:ok, current, _} = Generation.snapshot(store)
    assert {:ok, prepared} = Generation.prepare(store, routes(Legacy, :new))
    assert {:ok, next} = Generation.activate(store, current, prepared)
    assert next == prepared.generation
  end

  test "every compiled route is validated at preparation and activation" do
    store = start_supervised!({Generation, routes: routes(Legacy, :old)})
    assert {:ok, current, _} = Generation.snapshot(store)
    first = make_ref()
    second = make_ref()

    inputs =
      routes(Checked, {:observed, self(), first}) ++
        routes(Checked, {:observed, self(), second})

    assert {:ok, prepared} = Generation.prepare(store, inputs)
    assert_receive {:generation_validated, ^first}, 1000
    assert_receive {:generation_validated, ^second}, 1000
    assert {:ok, _} = Generation.activate(store, current, prepared)
    assert_receive {:generation_validated, ^first}, 1000
    assert_receive {:generation_validated, ^second}, 1000
  end

  test "static compilation allows a denied endpoint but preparation and activation preserve snapshot" do
    store = start_supervised!({Generation, routes: routes(Legacy, :old)})
    assert {:ok, current, original} = Generation.snapshot(store)
    assert {:ok, denied} = Router.compile(routes(Checked, :deny))

    assert {:error, :unsupported_generation_endpoint} =
             Generation.prepare(store, routes(Checked, :deny))

    assert {:error, :unsupported_generation_endpoint} =
             Generation.activate(store, current, denied)

    assert {:ok, ^current, ^original} = Generation.snapshot(store)
    assert Process.alive?(store)
  end

  test "direct Store activation also validates forged prepared routers" do
    store = start_supervised!({Generation, routes: routes(Legacy, :old)})
    assert {:ok, current, original} = Generation.snapshot(store)

    forged = %{
      original
      | generation: make_ref(),
        routes: [%{host: :any, path: :any, methods: :any, target: {Checked, :deny}}]
    }

    assert {:error, :unsupported_generation_endpoint} =
             GenServer.call(
               store,
               {:activate, current, forged, Gaoxy.Lifecycle.deadline(1000)},
               2000
             )

    assert {:error, :unsupported_generation_endpoint} =
             Generation.activate(store, current, forged)

    assert {:ok, ^current, ^original} = Generation.snapshot(store)
  end

  test "invalid return values and all exception classes have one finite error on both Store paths" do
    store = start_supervised!({Generation, routes: routes(Legacy, :old)})
    assert {:ok, current, original} = Generation.snapshot(store)

    for invalid <- [
          nil,
          true,
          :unexpected,
          {:ok, :value},
          {:error, "unbounded reason"},
          {:error, :reason, :extra},
          :raise,
          :throw,
          :exit
        ] do
      assert {:ok, prepared} = Router.compile(routes(Checked, invalid))

      assert {:error, :invalid_generation_endpoint} =
               Generation.prepare(store, routes(Checked, invalid))

      assert {:error, :invalid_generation_endpoint} =
               Generation.activate(store, current, prepared)

      assert {:error, :invalid_generation_endpoint} =
               GenServer.call(
                 store,
                 {:activate, current, prepared, Gaoxy.Lifecycle.deadline(1000)},
                 2000
               )

      assert {:ok, ^current, ^original} = Generation.snapshot(store)
      assert Process.alive?(store)
    end

    assert {:ok, prepared} = Generation.prepare(store, routes(Checked, :accept))
    assert {:ok, _} = Generation.activate(store, current, prepared)
  end

  test "compiled_bound enforces the hook without knowing endpoint configuration shape" do
    assert {:ok, accepted} = Router.compile(routes(Checked, :accept))
    assert {:ok, legacy} = Router.compile(routes(Legacy, %{upstream_protocol: :h2c}))
    assert {:ok, denied} = Router.compile(routes(Checked, :deny))
    limits = %{max_routes: 1024, max_config_bytes: 1_048_576}
    assert :ok = Store.compiled_bound(accepted, limits)
    assert :ok = Store.compiled_bound(legacy, limits)
    assert {:error, :unsupported_generation_endpoint} = Store.compiled_bound(denied, limits)
  end

  test "initial routes and initial compiled routers cannot bypass validation" do
    assert {:ok, denied} = Router.compile(routes(Checked, :deny))

    assert {:error, :unsupported_generation_endpoint} =
             Generation.start_link(routes: routes(Checked, :deny))

    assert {:error, :unsupported_generation_endpoint} = Generation.start_link(router: denied)
  end

  defp routes(module, config), do: [%{target: {module, config}}]
end
