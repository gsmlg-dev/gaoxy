defmodule Gaoxy.Proxy.UDPRelay.Options do
  @moduledoc false
  import Bitwise
  alias Gaoxy.Proxy.DestinationPolicy

  @limits %{
    max_associations: 256,
    queue_items: 8,
    queue_bytes: 65_536,
    max_packet: 65_507,
    idle_timeout: 30_000,
    lifetime: 300_000,
    reservation_timeout: 100,
    send_timeout: 1_000,
    drain_grace: 200,
    rate_packets: 64,
    rate_bytes: 65_536,
    packet_ratio: 1,
    byte_ratio: 1
  }
  defstruct [
    :upstream,
    :ingress,
    :destination,
    limits: @limits,
    reservation: nil,
    local_networks: []
  ]

  def validate(%__MODULE__{} = options),
    do: options |> Map.from_struct() |> Map.drop([:reservation, :local_networks]) |> validate()

  def validate(options) when is_map(options) do
    with true <-
           Map.keys(options) -- [:upstream, :ingress, :destination, :limits] == [],
         true <- :erlang.external_size(options) <= 65_536,
         {address, port} when is_integer(port) and port in 1..65_535 <- options[:upstream],
         {:ok, address} <- DestinationPolicy.normalize_address(address),
         true <- unicast?(address),
         {:ok, ingress} <- cidrs(options[:ingress]),
         %{allow: allow} = destination <- options[:destination],
         true <- Map.keys(destination) -- [:allow, :deny, :allow_reserved] == [],
         {:ok, allow} <- cidrs(allow),
         {:ok, deny} <- cidrs(Map.get(destination, :deny, []), true),
         reserved = Map.get(destination, :allow_reserved, false),
         true <- is_boolean(reserved),
         true <-
           not reserved or
             Enum.all?(allow, fn {network, prefix} ->
               prefix >= if(tuple_size(network) == 4, do: 24, else: 64)
             end),
         true <-
           Enum.any?(allow, &contains?(&1, address)) and
             not Enum.any?(deny, &contains?(&1, address)),
         true <- reserved or not reserved?(address),
         limits when is_map(limits) <- Map.get(options, :limits, %{}),
         true <- Map.keys(limits) -- Map.keys(@limits) == [],
         limits = Map.merge(@limits, limits),
         true <- Enum.all?(limits, fn {_, n} -> is_integer(n) and n > 0 end),
         true <-
           limits.max_associations <= 256 and limits.queue_items <= 64 and
             limits.queue_bytes <= 1_048_576 and limits.max_packet <= 65_507 and
             limits.packet_ratio <= 16 and limits.byte_ratio <= 16 and
             limits.reservation_timeout <= 1_000 and limits.send_timeout <= 5_000 and
             limits.idle_timeout <= limits.lifetime and limits.lifetime <= 3_600_000 and
             limits.rate_packets <= 65_536 and limits.rate_bytes <= 16_777_216 do
      {:ok,
       %__MODULE__{
         upstream: {address, port},
         ingress: ingress,
         destination: %{allow: allow, deny: deny, allow_reserved: reserved},
         limits: limits
       }}
    else
      _ -> {:error, :invalid_udp_relay_options}
    end
  end

  def validate(_), do: {:error, :invalid_udp_relay_options}

  def service(options, spec) do
    packet = min(options.limits.max_packet, min(spec.limits.max_packet, spec.limits.max_output))
    infrastructure = 4 * packet + 2 * (spec.dispatcher.max_bytes + packet) + 4096
    worker = 3 * packet + 4096
    metadata = options.limits.queue_items * 512 + 1024

    supported =
      Enum.min([
        options.limits.max_associations,
        spec.limits.max_active - 1,
        div(max(0, spec.limits.max_state - :erlang.external_size(options) - 4096), metadata),
        div(max(0, spec.limits.max_bytes - infrastructure - packet), worker + metadata)
      ])

    cond do
      not unicast?(spec.ip) ->
        {:error, :udp_relay_requires_concrete_unicast_bind}

      tuple_size(spec.ip) != tuple_size(elem(options.upstream, 0)) ->
        {:error, :upstream_family_mismatch}

      supported < 1 or options.limits.queue_bytes < packet ->
        {:error, :udp_relay_budget_too_small}

      true ->
        {:ok,
         %{
           options
           | reservation: %{
               infrastructure: infrastructure + supported * metadata,
               worker: worker,
               max_associations: supported,
               max_packet: packet
             }
         }}
    end
  end

  def source?(options, address) do
    with {:ok, address} <- DestinationPolicy.normalize_address(address),
         do:
           unicast?(address) and not directed_broadcast?(address, options.local_networks) and
             Enum.any?(options.ingress, &contains?(&1, address))
  end

  # Runtime preflight is deliberately separate from pure Config validation.
  # Service invokes it with a finite deadline before any listener is bound.
  def prepare(options, bind) do
    case :inet.getifaddrs() do
      {:ok, interfaces} ->
        networks =
          Enum.flat_map(interfaces, fn {_name, values} ->
            {_address, networks} =
              Enum.reduce(values, {nil, []}, fn
                {:addr, address}, {_, networks} ->
                  {address, networks}

                {:netmask, mask}, {address, networks}
                when is_tuple(address) and tuple_size(address) == 4 and tuple_size(mask) == 4 ->
                  {nil, [{address, mask} | networks]}

                _, acc ->
                  acc
              end)

            networks
          end)
          |> Enum.uniq()

        cond do
          length(networks) > 64 ->
            {:error, :interface_limit}

          directed_broadcast?(bind, networks) or
              directed_broadcast?(elem(options.upstream, 0), networks) ->
            {:error, :directed_broadcast}

          true ->
            {:ok, %{options | local_networks: networks}}
        end

      {:error, reason} ->
        {:error, {:interface_query, reason}}
    end
  end

  def directed_broadcast?(address, networks) when tuple_size(address) == 4 do
    Enum.any?(networks, fn {interface, mask} ->
      host = bxor(integer(mask), 0xFFFFFFFF)
      host > 1 and integer(address) == ((integer(interface) &&& integer(mask)) ||| host)
    end)
  end

  def directed_broadcast?(_, _), do: false

  def cidrs(values, empty \\ false)

  def cidrs(values, empty) when is_list(values) and length(values) <= 128 do
    if values == [] and not empty do
      {:error, :invalid_cidr}
    else
      Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
        case cidr(value) do
          {:ok, parsed} -> {:cont, {:ok, [parsed | acc]}}
          _ -> {:halt, {:error, :invalid_cidr}}
        end
      end)
      |> case do
        {:ok, values} -> {:ok, Enum.reverse(values)}
        error -> error
      end
    end
  end

  def cidrs(_, _), do: {:error, :invalid_cidr}

  defp cidr({address, prefix}) when is_integer(prefix) do
    with {:ok, address} <- DestinationPolicy.normalize_address(address),
         true <- prefix in 0..bits(address),
         do: {:ok, {address, prefix}}
  end

  defp cidr(value) when is_binary(value) do
    with [address, prefix] <- String.split(value, "/"),
         {prefix, ""} <- Integer.parse(prefix),
         {:ok, address} <- :inet.parse_address(String.to_charlist(address)),
         do: cidr({address, prefix})
  end

  defp cidr(_), do: {:error, :invalid_cidr}
  defp bits(address), do: if(tuple_size(address) == 4, do: 32, else: 128)

  defp integer(address) do
    width = if tuple_size(address) == 4, do: 8, else: 16
    Enum.reduce(Tuple.to_list(address), 0, fn word, acc -> (acc <<< width) + word end)
  end

  defp contains?({network, prefix}, address),
    do:
      bits(network) == bits(address) and
        integer(network) >>> (bits(network) - prefix) ==
          integer(address) >>> (bits(address) - prefix)

  defp unicast?({a, _, _, _}), do: a > 0 and a < 224

  defp unicast?({a, _, _, _, _, _, _, _} = address),
    do:
      address != {0, 0, 0, 0, 0, 0, 0, 0} and (a &&& 0xFF00) != 0xFF00 and
        (a &&& 0xFFC0) != 0xFE80

  defp unicast?(_), do: false

  defp reserved?(address) do
    Enum.any?(
      [
        {{0, 0, 0, 0}, 8},
        {{10, 0, 0, 0}, 8},
        {{100, 64, 0, 0}, 10},
        {{127, 0, 0, 0}, 8},
        {{169, 254, 0, 0}, 16},
        {{172, 16, 0, 0}, 12},
        {{192, 0, 0, 0}, 24},
        {{192, 0, 2, 0}, 24},
        {{192, 168, 0, 0}, 16},
        {{198, 18, 0, 0}, 15},
        {{198, 51, 100, 0}, 24},
        {{203, 0, 113, 0}, 24},
        {{0, 0, 0, 0, 0, 0, 0, 0}, 96},
        {{0x64, 0xFF9B, 0, 0, 0, 0, 0, 0}, 96},
        {{0x64, 0xFF9B, 1, 0, 0, 0, 0, 0}, 48},
        {{0x2001, 0, 0, 0, 0, 0, 0, 0}, 32},
        {{0x2001, 0xDB8, 0, 0, 0, 0, 0, 0}, 32},
        {{0x2002, 0, 0, 0, 0, 0, 0, 0}, 16},
        {{0xFC00, 0, 0, 0, 0, 0, 0, 0}, 7},
        {{0xFEC0, 0, 0, 0, 0, 0, 0, 0}, 10}
      ],
      &contains?(&1, address)
    )
  end
end
