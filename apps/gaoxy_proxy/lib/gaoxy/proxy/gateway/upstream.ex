defmodule Gaoxy.Proxy.Gateway.Upstream do
  @moduledoc """
  Owner-independent managed upstream declarations for Gateway routes.

  `fixed/1` accepts `:upstream`, an explicit literal `:connect_address`,
  `:upstream_protocol` (`:http1`, `:http2`, `:h2c`), and `:cacertfile` or
  immutable DER `:trust`. Files are read only during bounded preparation.
  `group/1` accepts the same members plus the existing finite health policy.
  """
  @behaviour Gaoxy.HTTP.Endpoint
  alias Gaoxy.Proxy.{HTTP, ManagedH1Preparation, ManagedH2Preparation}
  defstruct [:kind, :options]
  @limits ~w(max_chunk_bytes opening_timeout idle_timeout write_timeout max_lifetime)a
  @health %{
    path: "/",
    interval: 5000,
    timeout: 2000,
    stale_after: 15_000,
    failure_threshold: 3,
    recovery_threshold: 2,
    jitter: 500
  }

  def fixed(input) when is_map(input) do
    with {:ok, source} <- source(input),
         do: {:ok, {__MODULE__, %__MODULE__{kind: :fixed, options: source}}}
  end

  def fixed(_), do: {:error, :invalid_upstream_configuration}

  def group(input) when is_map(input) do
    with true <- Map.keys(input) -- [:id, :members, :health, :max_inflight | @limits] == [],
         true <- identity?(input[:id]),
         members when is_list(members) and length(members) in 1..32 <- input[:members],
         {:ok, members} <- traverse(members, &member/1),
         true <- length(Enum.uniq_by(members, & &1.id)) == length(members),
         [_] <- Enum.uniq_by(members, & &1.endpoint.upstream_protocol),
         {:ok, health} <- health(Map.get(input, :health, %{})),
         true <-
           hd(members).endpoint.upstream_protocol == :http1 or
             not String.contains?(health.path, "?"),
         max = Map.get(input, :max_inflight, 64),
         true <- is_integer(max) and max in 1..1024,
         {:ok, limits} <- HTTP.group_limits(Map.take(input, @limits)) do
      {:ok,
       {__MODULE__,
        %__MODULE__{
          kind: :group,
          options: %{
            id: input.id,
            members: members,
            health: health,
            max_inflight: max,
            limits: limits
          }
        }}}
    else
      _ -> {:error, :invalid_upstream_group}
    end
  end

  def group(_), do: {:error, :invalid_upstream_group}

  @impl true
  def init(%__MODULE__{} = config), do: {:ok, config}
  def init(_), do: {:error, :invalid_upstream_configuration}
  @impl true
  def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 503, [], "")

  @doc false
  def materialize(%__MODULE__{kind: :fixed, options: member} = declaration) do
    with {:ok, member} <- materialize_member(member), do: {:ok, %{declaration | options: member}}
  end

  def materialize(%__MODULE__{kind: :group, options: options} = declaration) do
    with {:ok, members} <- traverse(options.members, &materialize_member/1),
         do: {:ok, %{declaration | options: %{options | members: members}}}
  end

  defp source(input) do
    with true <-
           Map.keys(input) --
             [:upstream, :upstream_protocol, :connect_address, :cacertfile, :trust | @limits] ==
             [],
         origin when is_binary(origin) and byte_size(origin) <= 8192 <- input[:upstream],
         protocol = Map.get(input, :upstream_protocol, :http1),
         true <- protocol in [:http1, :http2, :h2c],
         {:ok, address} <- address(Map.get(input, :connect_address, URI.parse(origin).host)),
         true <- not (Map.has_key?(input, :trust) and Map.has_key?(input, :cacertfile)),
         trust =
           if(Map.has_key?(input, :cacertfile),
             do: {:file, input.cacertfile},
             else: input[:trust]
           ),
         true <- valid_trust_declaration?(trust),
         source = %{origin: origin, connect_address: address, trust: trust},
         source = if(protocol == :http1, do: source, else: Map.put(source, :protocol, protocol)),
         :ok <- validate_source(source),
         {:ok, limits} <- HTTP.group_limits(Map.take(input, @limits)) do
      {:ok,
       %{
         source: source,
         endpoint: Map.merge(limits, %{upstream: origin, upstream_protocol: protocol})
       }}
    else
      _ -> {:error, :invalid_upstream_configuration}
    end
  end

  defp member(input) when is_map(input) do
    max = Map.get(input, :max_inflight, 16)

    with true <- identity?(input[:id]) and is_integer(max) and max in 1..1024,
         {:ok, member} <- source(Map.drop(input, [:id, :max_inflight])),
         do: {:ok, Map.merge(member, %{id: input.id, max_inflight: max})}
  end

  defp member(_), do: {:error, :invalid_group_member}

  defp materialize_member(%{source: source} = member) do
    with {:ok, trust} <- trust(source.trust),
         source = %{source | trust: trust},
         :ok <- validate_source(source),
         do: {:ok, %{member | source: source}}
  end

  defp validate_source(%{trust: {:file, _}} = source) do
    # Validate the declaration without substituting for unread trust material.
    # The complete managed policy is checked after the bounded file snapshot.
    uri = URI.parse(source.origin)
    address = source.connect_address

    valid =
      uri.scheme == "https" and source[:protocol] != :h2c and
        is_binary(uri.host) and byte_size(uri.host) in 1..253 and uri.userinfo == nil and
        uri.fragment == nil and uri.query == nil and uri.path in [nil, "", "/"] and
        is_integer(uri.port) and uri.port in 1..65_535 and
        is_tuple(address) and tuple_size(address) in [4, 8] and
        Enum.all?(
          Tuple.to_list(address),
          &(is_integer(&1) and &1 in 0..if(tuple_size(address) == 4, do: 255, else: 65_535))
        ) and
        Enum.all?(:binary.bin_to_list(source.origin), &(&1 in 33..126 and &1 not in [?#, ?\\])) and
        not Regex.match?(~r/%(?![0-9a-fA-F]{2})/, source.origin)

    if valid, do: :ok, else: {:error, :invalid_policy}
  end

  defp validate_source(source) do
    module =
      if source[:protocol] in [:http2, :h2c], do: ManagedH2Preparation, else: ManagedH1Preparation

    with {:ok, _, _} <- module.prepare_policy(source), do: :ok
  end

  defp valid_trust_declaration?(nil), do: true
  defp valid_trust_declaration?({:file, path}), do: is_binary(path) and byte_size(path) in 1..4096

  defp valid_trust_declaration?(certs) when is_list(certs),
    do: certs != [] and Enum.all?(certs, &is_binary/1)

  defp valid_trust_declaration?(_), do: false

  defp trust({:file, path}) do
    with {:ok, %{type: :regular, size: size}} <- File.stat(path),
         true <- size <= 1_048_576,
         {:ok, file} <- :file.open(path, [:read, :binary, :raw]) do
      try do
        with {:ok, bytes} when byte_size(bytes) <= 1_048_576 <- :file.read(file, 1_048_577),
             certs =
               for({:Certificate, der, :not_encrypted} <- :public_key.pem_decode(bytes), do: der),
             true <- certs != [] do
          {:ok, certs}
        else
          _ -> {:error, :invalid_trust}
        end
      after
        :file.close(file)
      end
    else
      _ -> {:error, :invalid_trust}
    end
  rescue
    _ -> {:error, :invalid_trust}
  end

  defp trust(trust), do: {:ok, trust}

  defp address(value) when is_binary(value), do: :inet.parse_address(String.to_charlist(value))
  defp address(value) when is_tuple(value) and tuple_size(value) in [4, 8], do: {:ok, value}
  defp address(_), do: {:error, :invalid_address}
  defp identity?(id), do: is_binary(id) and byte_size(id) in 1..128

  defp health(input) when is_map(input) do
    health = Map.merge(@health, input)

    with true <- Map.keys(input) -- Map.keys(@health) == [],
         "/" <> _ <- health.path,
         true <- byte_size(health.path) <= 8192,
         true <-
           Enum.all?(:binary.bin_to_list(health.path), &(&1 in 33..126 and &1 not in [?#, ?\\])),
         true <- not Regex.match?(~r/%(?![0-9a-fA-F]{2})/, health.path),
         true <-
           Enum.all?(Map.delete(health, :path), fn {key, n} ->
             is_integer(n) and n >= if(key == :jitter, do: 0, else: 1) and n <= 3_600_000
           end),
         true <-
           health.timeout <= 5000 and health.failure_threshold <= 100 and
             health.recovery_threshold <= 100 and health.stale_after >= health.interval do
      {:ok, health}
    else
      _ -> {:error, :invalid_health_policy}
    end
  end

  defp health(_), do: {:error, :invalid_health_policy}

  defp traverse(values, fun) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case fun.(value) do
        {:ok, parsed} -> {:cont, {:ok, [parsed | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, parsed} -> {:ok, Enum.reverse(parsed)}
      error -> error
    end
  end
end
