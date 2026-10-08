defmodule Gaoxy.StreamHandler do
  @moduledoc "Callbacks execute in an isolated connection owner. Input is an ordered byte stream, not messages."
  @callback init(map(), term()) :: {:ok, term()} | {:error, term()}
  @callback handle_data(binary(), term()) ::
              {:continue, term()}
              | {:send, iodata(), term()}
              | {:close, term()}
              | {:error, term(), term()}
  @callback terminate(term(), term()) :: term()
  @optional_callbacks terminate: 2
end
