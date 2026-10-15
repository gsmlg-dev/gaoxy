defmodule Gaoxy.QUICHandler do
  @moduledoc """
  Opt-in connection/stream callbacks hosted by public `Abyss.QUIC`.

  Callbacks run in the engine-attached connection owner. Use `Gaoxy.QUIC` with
  the supplied connection/stream capabilities. FIN, reset, stop, blocked and
  unknown operation receipts retain their native directional meanings. No
  listener socket or listener-close capability is given to an application.
  """
  @callback init(term(), map(), term()) :: {:ok, term()} | {:error, term()}
  @callback handle_event(term(), term()) :: {:ok, term()} | {:stop, term(), term()}
  @callback terminate(term(), term()) :: term()
  @optional_callbacks terminate: 2
end
