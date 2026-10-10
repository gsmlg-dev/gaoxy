defmodule Gaoxy.HTTP.Request do
  @moduledoc "Protocol-neutral request metadata. Paths and queries retain their wire escaping."
  defstruct [
    :method,
    :target,
    :target_form,
    :version,
    :path,
    :query_string,
    :host,
    :port,
    :scheme,
    :peer,
    :local,
    head_bytes: 0,
    headers: [],
    body: :none,
    keep_alive: false,
    expect_continue: false
  ]

  @type t :: %__MODULE__{}
end
