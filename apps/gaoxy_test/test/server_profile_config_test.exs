defmodule Gaoxy.Test.ServerProfileConfigTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.Test.Server

  test "unsupported profiles fail before creating a server process" do
    assert {:error, {:unsupported_profile, :invalid}} =
             Server.start_link(self(), profile: :invalid, fixture_id: make_ref())
  end

  test "omitted budgets preserve protocol defaults and administrator cap provenance" do
    for {profile, bytes} <- [
          http1: 1_048_576,
          https: 1_048_576,
          h2c: 268_435_456,
          http2: 268_435_456,
          http3: 16_777_216
        ] do
      assert {:ok, spec} = specification(profile)
      assert spec.limits.max_bytes == bytes
      assert spec.budget_policy.max_bytes == nil
      assert spec.budget_policy.provenance.max_bytes == :omitted
      assert spec.handler_options.http_limits.max_body_bytes == 8_388_608
      assert spec.handler_options.http_limits.stream_timeout == :request
    end
  end

  test "explicit budgets reach every profile's public service constructor" do
    for profile <- [:http1, :https, :h2c, :http2, :http3] do
      assert {:ok, spec} =
               specification(profile,
                 limits: %{max_bytes: 536_870_912},
                 http_limits: %{max_body_bytes: 1_048_576, read_timeout: 2_000}
               )

      assert spec.limits.max_bytes == 536_870_912
      assert spec.budget_policy.max_bytes == 536_870_912
      assert spec.budget_policy.provenance.max_bytes == :explicit
      assert spec.handler_options.http_limits.max_body_bytes == 1_048_576
      assert spec.handler_options.http_limits.read_timeout == 2_000
      assert spec.handler_options.http_limits.max_buffer_bytes == 65_536
    end
  end

  test "invalid service budgets fail service specification" do
    for limits <- [
          %{unknown: 1},
          %{max_bytes: 0},
          %{max_bytes: -1},
          %{max_bytes: :infinity},
          %{max_bytes: 9_223_372_036_854_775_808}
        ] do
      assert {:error, _} = specification(:http1, limits: limits)
      assert {:error, _} = Server.start_link(self(), fixture_id: make_ref(), limits: limits)
    end
  end

  test "invalid HTTP budgets fail service specification" do
    for http_limits <- [
          %{unknown: 1},
          %{max_body_bytes: 0},
          %{max_body_bytes: -1},
          %{max_read_chunk: 65_537, max_buffer_bytes: 65_536}
        ] do
      assert {:error, _} = specification(:http1, http_limits: http_limits)

      assert {:error, _} =
               Server.start_link(self(), fixture_id: make_ref(), http_limits: http_limits)
    end
  end

  test "profile budget reservations remain enforced" do
    assert {:error, :http2_byte_budget} = specification(:h2c, limits: %{max_bytes: 1})
    assert {:error, :http3_byte_budget} = specification(:http3, limits: %{max_bytes: 1})
  end

  test "public options reject malformed or explicitly infinite budget maps" do
    for options <- [
          [limits: []],
          [http_limits: []],
          [limits: nil],
          [http_limits: nil],
          [limits: %{max_bytes: :infinity}],
          [http_limits: %{request_timeout: :infinity}],
          [http_limits: %{stream_timeout: :infinity}]
        ] do
      assert_raise ArgumentError, ~r/(limits|http_limits)/, fn -> Gaoxy.Test.open(options) end
    end
  end

  defp specification(profile, budgets \\ []) do
    Server.service_spec(self(), [profile: profile, fixture_id: make_ref()] ++ budgets)
  end
end
