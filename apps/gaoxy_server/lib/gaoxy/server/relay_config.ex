defmodule Gaoxy.Server.RelayConfig do
  @moduledoc false
  alias Gaoxy.Proxy.{StreamRelay, UDPRelay}

  @stream_keys ~w(upstream mode max_chunk_bytes connect_timeout idle_timeout max_lifetime write_timeout upstream_tls)a
  @udp_keys ~w(upstream ingress destination limits)a
  @udp_limits ~w(max_associations queue_items queue_bytes max_packet idle_timeout lifetime reservation_timeout send_timeout drain_grace rate_packets rate_bytes packet_ratio byte_ratio)a
  @modes %{
    "tcp" => :tcp,
    "tls_termination" => :tls_termination,
    "tls_upstream" => :tls_upstream,
    "tls_passthrough" => :tls_passthrough
  }

  def decode(StreamRelay, data) do
    with {:ok, options} <- named(data, @stream_keys),
         {:ok, upstream} <- upstream(options[:upstream]),
         {:ok, mode} <- mode(Map.get(options, :mode, "tcp")),
         {:ok, tls} <- named(Map.get(options, :upstream_tls, %{}), [:server_name, :cacertfile]) do
      options
      |> Map.merge(%{upstream: upstream, mode: mode, upstream_tls: tls})
      |> StreamRelay.validate_options()
    end
  end

  def decode(UDPRelay, data) do
    with {:ok, options} <- named(data, @udp_keys),
         {:ok, upstream} <- upstream(options[:upstream]),
         :ok <- cidrs(options[:ingress]),
         {:ok, destination} <- destination(options[:destination]),
         {:ok, limits} <- named(Map.get(options, :limits, %{}), @udp_limits) do
      options
      |> Map.merge(%{upstream: upstream, destination: destination, limits: limits})
      |> UDPRelay.validate_options()
    end
  end

  def decode(_, _), do: {:error, :unsupported_relay_handler}

  defp upstream(data) do
    with {:ok, %{address: address, port: port}} <- named(data, [:address, :port]),
         true <- is_binary(address),
         {:ok, address} <- :inet.parse_address(String.to_charlist(address)) do
      {:ok, {address, port}}
    else
      {:error, _} = error -> error
      _ -> {:error, :invalid_relay_upstream}
    end
  end

  defp destination(data) do
    with {:ok, options} <- named(data, [:allow, :deny, :allow_reserved]),
         :ok <- cidrs(options[:allow]),
         :ok <- cidrs(Map.get(options, :deny, [])) do
      {:ok, options}
    end
  end

  defp cidrs(values) when is_list(values) do
    if Enum.all?(values, &is_binary/1), do: :ok, else: {:error, :invalid_relay_cidrs}
  end

  defp cidrs(_), do: {:error, :invalid_relay_cidrs}

  defp mode(value) do
    case Map.fetch(@modes, value) do
      {:ok, mode} -> {:ok, mode}
      :error -> {:error, :unsupported_value}
    end
  end

  defp named(data, keys) when is_map(data) do
    allowed = Map.new(keys, &{Atom.to_string(&1), &1})

    if Map.keys(data) -- Map.keys(allowed) == [],
      do: {:ok, Map.new(data, fn {key, value} -> {allowed[key], value} end)},
      else: {:error, :unknown_configuration_keys}
  end

  defp named(_, _), do: {:error, :invalid_options}
end
