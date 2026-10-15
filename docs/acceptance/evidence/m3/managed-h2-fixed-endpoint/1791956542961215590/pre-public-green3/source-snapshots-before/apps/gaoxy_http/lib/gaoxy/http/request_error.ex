defmodule Gaoxy.HTTP.RequestError do
  @moduledoc false
  defexception message: "invalid HTTP request body", plug_status: 400
end
