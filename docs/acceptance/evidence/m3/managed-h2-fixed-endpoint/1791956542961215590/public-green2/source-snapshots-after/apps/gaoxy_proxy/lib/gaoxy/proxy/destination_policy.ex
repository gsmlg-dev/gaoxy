defmodule Gaoxy.Proxy.DestinationPolicy do
  @moduledoc """
  Explicit authenticated destination policy for forward HTTP and CONNECT.

  Rules name principals, exact hosts (or `:any`), ports, operations, methods
  (or `:any`) and CIDRs. Reserved destinations are denied unless a matching rule
  explicitly opts in with an IPv4 /24-or-narrower or IPv6 /64-or-narrower CIDR.
  `deny_cidrs` always wins, including over reserved-address exceptions. Resolution
  checks every A/AAAA answer and returns one numeric address for a pinned dial;
  the caller must preserve the original authority and TLS identity.
  Credentials and payloads are never included in policy errors.
  """
  import Bitwise
  alias Gaoxy.Lifecycle
  defstruct [:authenticate, :rules, deny_cidrs: []]

  @reserved [
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
    {{224, 0, 0, 0}, 4},
    {{240, 0, 0, 0}, 4},
    {{0, 0, 0, 0, 0, 0, 0, 0}, 96},
    {{0x64, 0xFF9B, 0, 0, 0, 0, 0, 0}, 96},
    {{0x64, 0xFF9B, 1, 0, 0, 0, 0, 0}, 48},
    {{0x2001, 0, 0, 0, 0, 0, 0, 0}, 32},
    {{0x2001, 0xDB8, 0, 0, 0, 0, 0, 0}, 32},
    {{0x2002, 0, 0, 0, 0, 0, 0, 0}, 16},
    {{0xFC00, 0, 0, 0, 0, 0, 0, 0}, 7},
    {{0xFE80, 0, 0, 0, 0, 0, 0, 0}, 10},
    {{0xFEC0, 0, 0, 0, 0, 0, 0, 0}, 10},
    {{0xFF00, 0, 0, 0, 0, 0, 0, 0}, 8}
  ]
  @rule_keys [:principals, :hosts, :ports, :operations, :methods, :cidrs, :allow_reserved]
  @token ~r/\A[!#$%&'*+.^_`|~0-9A-Za-z-]+\z/

  def init(%{authenticate: authenticate, rules: rules} = options)
      when is_function(authenticate, 1) and is_list(rules) and length(rules) in 1..128 do
    with true <- Map.keys(options) -- [:authenticate, :rules, :deny_cidrs] == [],
         true <- :erlang.external_size(options) <= 65_536,
         {:ok, rules} <- traverse(rules, &rule/1),
         {:ok, deny} <- cidrs(Map.get(options, :deny_cidrs, []), true) do
      {:ok, %__MODULE__{authenticate: authenticate, rules: rules, deny_cidrs: deny}}
    else
      _ -> {:error, :invalid_destination_policy}
    end
  end

  def init(_), do: {:error, :invalid_destination_policy}

  def authenticate(%__MODULE__{authenticate: authenticate}, headers) do
    credentials =
      for {name, value} <- headers, String.downcase(name) == "proxy-authorization", do: value

    case credentials do
      [credential] when is_binary(credential) and byte_size(credential) in 1..8192 ->
        case authenticate.(credential) do
          {:ok, principal} when is_binary(principal) and byte_size(principal) in 1..128 ->
            {:ok, principal}

          _ ->
            {:error, :authentication_required}
        end

      _ ->
        {:error, :authentication_required}
    end
  rescue
    _ -> {:error, :authentication_required}
  catch
    _, _ -> {:error, :authentication_required}
  end

  def authorize(%__MODULE__{} = policy, principal, %{
        host: host,
        port: port,
        operation: operation,
        method: method
      })
      when is_integer(port) and port in 1..65_535 and operation in [:forward, :connect] do
    with {:ok, host} <- hostname(host) do
      rules =
        Enum.filter(policy.rules, fn rule ->
          principal in rule.principals and (rule.hosts == :any or host in rule.hosts) and
            port in rule.ports and operation in rule.operations and
            (rule.methods == :any or method in rule.methods)
        end)

      if rules == [],
        do: {:error, :destination_denied},
        else: {:ok, %{host: host, port: port, rules: rules, deny_cidrs: policy.deny_cidrs}}
    else
      _ -> {:error, :destination_denied}
    end
  end

  def authorize(_, _, _), do: {:error, :destination_denied}

  def pin(authorization, addresses) when is_list(addresses) and length(addresses) in 1..64 do
    with {:ok, addresses} <- traverse(addresses, &normalize_address/1),
         true <- Enum.all?(addresses, &permitted?(authorization, &1)) do
      {:ok, hd(addresses)}
    else
      _ -> {:error, :destination_denied}
    end
  end

  def pin(_, _), do: {:error, :destination_denied}

  def resolve(authorization, deadline) when is_integer(deadline) do
    if Lifecycle.remaining(deadline) == 0 do
      {:error, :deadline_exceeded}
    else
      case literal(authorization.host) do
        {:ok, address} -> pin(authorization, [address])
        _ -> resolve_name(authorization, deadline)
      end
    end
  end

  def normalize_address(address) when is_tuple(address) and tuple_size(address) in [4, 8] do
    maximum = if tuple_size(address) == 4, do: 255, else: 65_535

    if Enum.all?(Tuple.to_list(address), &(is_integer(&1) and &1 in 0..maximum)) do
      case address do
        {0, 0, 0, 0, 0, 0xFFFF, high, low} ->
          {:ok, {high >>> 8, high &&& 255, low >>> 8, low &&& 255}}

        _ ->
          {:ok, address}
      end
    else
      {:error, :invalid_address}
    end
  end

  def normalize_address(_), do: {:error, :invalid_address}

  defp resolve_name(authorization, deadline) do
    addresses =
      Enum.reduce([:inet, :inet6], [], fn family, acc ->
        if Lifecycle.remaining(deadline) > 0 do
          case :inet.getaddrs(
                 String.to_charlist(authorization.host),
                 family,
                 Lifecycle.remaining(deadline)
               ) do
            {:ok, values} -> acc ++ values
            _ -> acc
          end
        else
          acc
        end
      end)

    cond do
      Lifecycle.remaining(deadline) == 0 -> {:error, :deadline_exceeded}
      addresses == [] -> {:error, :resolution_failed}
      true -> pin(authorization, Enum.uniq(addresses))
    end
  end

  defp permitted?(authorization, address) do
    not Enum.any?(authorization.deny_cidrs, &contains?(&1, address)) and
      Enum.any?(authorization.rules, fn rule ->
        Enum.any?(rule.cidrs, &contains?(&1, address)) and
          (rule.allow_reserved or not reserved?(address))
      end)
  end

  defp reserved?(address),
    do:
      Enum.any?(@reserved, fn {network, prefix} ->
        contains?(cidr_value(network, prefix), address)
      end)

  defp rule(data) when is_map(data) do
    with true <- Map.keys(data) -- @rule_keys == [],
         true <- short_list?(data[:principals], &(is_binary(&1) and byte_size(&1) in 1..128)),
         {:ok, hosts} <- hosts(data[:hosts]),
         true <- short_list?(data[:ports], &(is_integer(&1) and &1 in 1..65_535)),
         true <- short_list?(data[:operations], &(&1 in [:forward, :connect])),
         true <-
           data[:methods] == :any or
             short_list?(
               data[:methods],
               &(is_binary(&1) and byte_size(&1) <= 32 and Regex.match?(@token, &1))
             ),
         {:ok, cidrs} <- cidrs(data[:cidrs], false),
         true <- is_boolean(Map.get(data, :allow_reserved, false)),
         true <-
           not Map.get(data, :allow_reserved, false) or
             Enum.all?(cidrs, fn {bits, _, prefix} ->
               prefix >= if(bits == 32, do: 24, else: 64)
             end) do
      {:ok,
       Map.merge(data, %{
         hosts: hosts,
         cidrs: cidrs,
         allow_reserved: Map.get(data, :allow_reserved, false)
       })}
    else
      _ -> {:error, :invalid_destination_policy}
    end
  end

  defp rule(_), do: {:error, :invalid_destination_policy}
  defp hosts(:any), do: {:ok, :any}

  defp hosts(values) when is_list(values) and length(values) in 1..128,
    do: traverse(values, &hostname/1)

  defp hosts(_), do: {:error, :invalid_host}

  defp hostname(host) when is_binary(host) and byte_size(host) in 1..253 do
    host = String.downcase(host)

    case literal(host) do
      {:ok, address} ->
        {:ok, address |> :inet.ntoa() |> to_string()}

      _ ->
        if Enum.all?(
             String.split(host, "."),
             &(byte_size(&1) in 1..63 and
                 Regex.match?(~r/\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/, &1))
           ),
           do: {:ok, host},
           else: {:error, :invalid_host}
    end
  end

  defp hostname(_), do: {:error, :invalid_host}

  defp literal(value) do
    parser =
      if String.contains?(value, ":"),
        do: :parse_ipv6strict_address,
        else: :parse_ipv4strict_address

    with {:ok, address} <- apply(:inet, parser, [String.to_charlist(value)]),
         do: normalize_address(address)
  end

  defp cidrs(values, empty?) when is_list(values) and length(values) <= 128 do
    if values == [] and not empty?, do: {:error, :invalid_cidr}, else: traverse(values, &cidr/1)
  end

  defp cidrs(_, _), do: {:error, :invalid_cidr}

  defp cidr(value) when is_binary(value) do
    with [address, prefix] <- String.split(value, "/"),
         {prefix, ""} <- Integer.parse(prefix),
         {:ok, address} <- literal(address),
         bits = tuple_size(address) * if(tuple_size(address) == 4, do: 8, else: 16),
         true <- prefix in 0..bits do
      {:ok, cidr_value(address, prefix)}
    else
      _ -> {:error, :invalid_cidr}
    end
  end

  defp cidr(_), do: {:error, :invalid_cidr}

  defp cidr_value(address, prefix) do
    word_bits = if tuple_size(address) == 4, do: 8, else: 16
    bits = tuple_size(address) * word_bits
    value = Enum.reduce(Tuple.to_list(address), 0, fn word, acc -> (acc <<< word_bits) + word end)
    {bits, value >>> (bits - prefix), prefix}
  end

  defp contains?({bits, network, prefix}, address) do
    address_bits = tuple_size(address) * if(tuple_size(address) == 4, do: 8, else: 16)
    bits == address_bits and elem(cidr_value(address, prefix), 1) == network
  end

  defp short_list?(values, predicate),
    do: is_list(values) and length(values) in 1..128 and Enum.all?(values, predicate)

  defp traverse(values, fun) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case fun.(value) do
        {:ok, result} -> {:cont, {:ok, [result | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end
end
