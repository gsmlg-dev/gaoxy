defmodule Gaoxy.DatagramDispatcher do
  @moduledoc """
  Opt-in persistent UDP dispatcher. The owner manages application admission and
  associations; Abyss retains the listener socket and its send capability.
  Validators are pure and must accept their own normalized output.
  """
  @callback validate_options(term()) :: {:ok, term()} | {:error, term()}
  @callback validate_service(term(), map()) :: {:ok, term()} | {:error, term()}
  @callback prepare_service(term(), map()) :: {:ok, term()} | {:error, term()}
  @optional_callbacks prepare_service: 2
  @callback start_link(map(), term()) :: {:ok, pid()} | {:error, term()}
  @callback offer(pid(), map()) :: {:ok, pid()} | {:error, term()}
  @callback control(pid(), :pause | :resume, reference()) :: :ok | {:error, term()}
  @callback drain(pid(), integer()) :: :ok | {:error, term()}
end
