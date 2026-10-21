defmodule Gaoxy.Server.UpstreamEndpoint do
  @moduledoc false
  @behaviour Gaoxy.HTTP.Endpoint
  alias Gaoxy.Proxy.Gateway.Upstream

  @limits ~w(max_chunk_bytes opening_timeout idle_timeout write_timeout max_lifetime)a
  @health ~w(path interval timeout stale_after failure_threshold recovery_threshold jitter)a

  def fixed(data) when is_map(data) do
    with {:ok, input} <- source(Map.delete(data, "type")),
         {:ok, {Upstream, declaration}} <- Upstream.fixed(input),
         do: {:ok, {__MODULE__, declaration}}
  end

  def fixed(_), do: {:error, :invalid_upstream_configuration}

  def group(data) when is_map(data) do
    with :ok <- keys(data, ~w(type id members health max_inflight) ++ names(@limits)),
         members when is_list(members) <- data["members"],
         {:ok, members} <- traverse(members, &member/1),
         {:ok, health} <- health(Map.get(data, "health", %{})),
         input =
           named(Map.drop(data, ["type", "members", "health"]), [:id, :max_inflight | @limits]),
         {:ok, {Upstream, declaration}} <-
           Upstream.group(Map.merge(input, %{members: members, health: health})) do
      {:ok, {__MODULE__, declaration}}
    else
      _ -> {:error, :invalid_upstream_group}
    end
  end

  def group(_), do: {:error, :invalid_upstream_group}

  @impl true
  def init(%Upstream{} = config), do: {:ok, config}
  def init(_), do: {:error, :invalid_upstream_configuration}

  # A declaration must be resolved before it is exposed by a listener.
  @impl true
  def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 503, [], "")

  defp member(data) when is_map(data) do
    with {:ok, input} <- source(Map.drop(data, ["id", "max_inflight"])),
         do:
           {:ok,
            Map.merge(input, named(Map.take(data, ["id", "max_inflight"]), [:id, :max_inflight]))}
  end

  defp member(_), do: {:error, :invalid_group_member}

  # JSON names, enums and file decoding remain at this boundary. Semantic
  # upstream/group policy is shared with embedded Gateway declarations.
  defp source(data) when is_map(data) do
    with :ok <-
           keys(
             data,
             ~w(upstream upstream_protocol managed cacertfile connect_address) ++ names(@limits)
           ),
         true <- Map.get(data, "managed", true) == true,
         {:ok, protocol} <- protocol(Map.get(data, "upstream_protocol", "http1")),
         {:ok, trust} <- trust(data["cacertfile"]),
         {:ok, address} <- address(data) do
      input =
        named(Map.drop(data, ["managed", "cacertfile", "upstream_protocol", "connect_address"]), [
          :upstream | @limits
        ])

      {:ok, Map.merge(input, Map.merge(address, %{upstream_protocol: protocol, trust: trust}))}
    else
      _ -> {:error, :invalid_upstream_configuration}
    end
  end

  defp source(_), do: {:error, :invalid_upstream_configuration}

  defp health(data) when is_map(data) do
    with :ok <- keys(data, names(@health)), do: {:ok, named(data, @health)}
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

  defp address(%{"connect_address" => value}) when is_binary(value) do
    with {:ok, address} <- :inet.parse_address(String.to_charlist(value)),
         do: {:ok, %{connect_address: address}}
  end

  defp address(%{"connect_address" => _}), do: {:error, :invalid_address}
  defp address(_), do: {:ok, %{}}
  defp protocol("http1"), do: {:ok, :http1}
  defp protocol("http2"), do: {:ok, :http2}
  defp protocol("h2c"), do: {:ok, :h2c}
  defp protocol(_), do: {:error, :invalid_upstream_protocol}
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
