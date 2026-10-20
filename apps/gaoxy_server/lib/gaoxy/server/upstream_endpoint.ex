defmodule Gaoxy.Server.UpstreamEndpoint do
  @moduledoc false
  @behaviour Gaoxy.HTTP.Endpoint
  alias Gaoxy.Proxy.{HTTP, ManagedH1Preparation, ManagedH2Preparation}

  @limits ~w(max_chunk_bytes opening_timeout idle_timeout write_timeout max_lifetime)a
  @health ~w(path interval timeout stale_after failure_threshold recovery_threshold jitter)a
  defstruct [:kind, :options]

  def fixed(data) do
    with {:ok, source} <- source(Map.delete(data, "type")),
         do: {:ok, {__MODULE__, %__MODULE__{kind: :fixed, options: source}}}
  end

  def group(data) do
    with :ok <- keys(data, ~w(type id members health max_inflight) ++ names(@limits)),
         true <- identity?(data["id"]),
         members when is_list(members) and length(members) in 1..32 <- data["members"],
         {:ok, members} <- traverse(members, &member/1),
         true <- length(Enum.uniq_by(members, & &1.id)) == length(members),
         [_] <- Enum.uniq_by(members, & &1.endpoint.upstream_protocol),
         {:ok, health} <- health(Map.get(data, "health", %{})),
         true <-
           hd(members).endpoint.upstream_protocol == :http1 or
             not String.contains?(health.path, "?"),
         max = Map.get(data, "max_inflight", 64),
         true <- is_integer(max) and max in 1..1024,
         {:ok, limits} <- HTTP.group_limits(named(Map.take(data, names(@limits)), @limits)) do
      options = %{
        id: :binary.copy(data["id"]),
        members: members,
        health: health,
        max_inflight: max,
        limits: limits
      }

      {:ok, {__MODULE__, %__MODULE__{kind: :group, options: options}}}
    else
      _ -> {:error, :invalid_upstream_group}
    end
  end

  @impl true
  def init(%__MODULE__{} = config), do: {:ok, config}
  def init(_), do: {:error, :invalid_upstream_configuration}

  # A declaration must be resolved before it is exposed by a listener.
  @impl true
  def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 503, [], "")

  defp member(data) when is_map(data) do
    max = Map.get(data, "max_inflight", 16)

    with true <- identity?(data["id"]) and is_integer(max) and max in 1..1024,
         {:ok, source} <- source(Map.drop(data, ["id", "max_inflight"])) do
      {:ok, Map.merge(source, %{id: :binary.copy(data["id"]), max_inflight: max})}
    else
      _ -> {:error, :invalid_group_member}
    end
  end

  defp member(_), do: {:error, :invalid_group_member}

  defp source(data) do
    with :ok <-
           keys(
             data,
             ~w(upstream upstream_protocol managed cacertfile connect_address) ++ names(@limits)
           ),
         true <- Map.get(data, "managed", true) == true,
         {:ok, protocol} <- protocol(Map.get(data, "upstream_protocol", "http1")),
         origin when is_binary(origin) <- data["upstream"],
         {:ok, address} <- address(Map.get(data, "connect_address", URI.parse(origin).host)),
         {:ok, trust} <- trust(data["cacertfile"]),
         source = %{origin: :binary.copy(origin), connect_address: address, trust: trust},
         source = if(protocol == :http1, do: source, else: Map.put(source, :protocol, protocol)),
         module = if(protocol == :http1, do: ManagedH1Preparation, else: ManagedH2Preparation),
         {:ok, _, _} <- module.prepare_policy(source),
         true <- byte_size(origin) <= 8192,
         {:ok, limits} <- HTTP.group_limits(named(Map.take(data, names(@limits)), @limits)) do
      endpoint = Map.merge(limits, %{upstream: source.origin, upstream_protocol: protocol})
      {:ok, %{source: source, endpoint: endpoint}}
    else
      _ -> {:error, :invalid_upstream_configuration}
    end
  end

  defp health(data) when is_map(data) do
    defaults = %{
      path: "/",
      interval: 5000,
      timeout: 2000,
      stale_after: 15_000,
      failure_threshold: 3,
      recovery_threshold: 2,
      jitter: 500
    }

    with :ok <- keys(data, names(@health)),
         health = Map.merge(defaults, named(data, @health)),
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
      {:ok, %{health | path: :binary.copy(health.path)}}
    else
      _ -> {:error, :invalid_health_policy}
    end
  end

  defp health(_), do: {:error, :invalid_health_policy}

  defp trust(nil), do: {:ok, nil}

  defp trust(path) when is_binary(path) do
    with {:ok, bytes} <- Gaoxy.Server.Config.read_file(path),
         certs =
           for({:Certificate, der, :not_encrypted} <- :public_key.pem_decode(bytes), do: der),
         true <- certs != [] do
      {:ok, certs}
    else
      _ -> {:error, :invalid_trust}
    end
  rescue
    _ -> {:error, :invalid_trust}
  end

  defp trust(_), do: {:error, :invalid_trust}
  defp address(value) when is_binary(value), do: :inet.parse_address(String.to_charlist(value))
  defp address(_), do: {:error, :invalid_address}
  defp protocol("http1"), do: {:ok, :http1}
  defp protocol("http2"), do: {:ok, :http2}
  defp protocol("h2c"), do: {:ok, :h2c}
  defp protocol(_), do: {:error, :invalid_upstream_protocol}
  defp identity?(id), do: is_binary(id) and byte_size(id) in 1..128
  defp names(atoms), do: Enum.map(atoms, &Atom.to_string/1)

  defp named(data, atoms),
    do:
      Map.new(atoms, &{Atom.to_string(&1), &1})
      |> then(fn allowed -> Map.new(data, fn {k, v} -> {allowed[k], v} end) end)

  defp keys(data, allowed),
    do:
      if(Map.keys(data) -- allowed == [],
        do: :ok,
        else: {:error, :invalid_upstream_configuration}
      )

  defp traverse(values, fun) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case fun.(value) do
        {:ok, parsed} -> {:cont, {:ok, [parsed | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end
end
