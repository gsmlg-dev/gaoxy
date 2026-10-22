defmodule Gaoxy.Test.ServerProfileConfigTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.Test.Server

  test "unsupported profiles fail before creating a server process" do
    assert {:error, {:unsupported_profile, :invalid}} =
             Server.start_link(self(), profile: :invalid, fixture_id: make_ref())
  end
end
