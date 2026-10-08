defmodule Gaoxy.Server.Config do
  @moduledoc "Version 1 JSON configuration. Handlers and keys use explicit allowlists; input creates no atoms."
  @handlers %{
    "stream_echo" => Gaoxy.Server.StreamEcho,
    "datagram_echo" => Gaoxy.Server.DatagramEcho
  }
  @service_keys %{"id" => :id, "port" => :port, "handler_options" => :handler_options}
  @limits ~w(max_active max_bytes max_packet max_output max_state callback_timeout idle_timeout drain_timeout max_memberships)a

  def load(path) do
    with {:ok, bytes} <- File.read(path),
         true <- byte_size(bytes) <= 1_048_576 || {:error, :configuration_too_large},
         {:ok, data} <- JSON.decode(bytes),
         {:ok, options} <- decode(data),
         {:ok, _} <- Gaoxy.Config.validate(options) do
      {:ok, options}
    end
  end

  def decode(%{"version" => 1, "services" => services} = data) when is_list(services) do
    with :ok <- keys(data, ["version", "services"]),
         {:ok, specs} <- traverse(services, &service/1) do
      {:ok, [services: specs]}
    end
  end

  def decode(_), do: {:error, :invalid_configuration_version_or_shape}

  defp service(data) when is_map(data) do
    with :ok <-
           keys(data, [
             "id",
             "transport",
             "handler",
             "handler_options",
             "ip",
             "port",
             "mode",
             "limits",
             "tls",
             "udp"
           ]),
         {:ok, transport} <-
           enum(data["transport"], %{"tcp" => :tcp, "tls" => :tls, "udp" => :udp, "quic" => :quic}),
         {:ok, handler} <- enum(data["handler"], @handlers),
         {:ok, ip} <- address(Map.get(data, "ip", "127.0.0.1")),
         {:ok, mode} <-
           enum(Map.get(data, "mode", "unicast"), %{
             "unicast" => :unicast,
             "broadcast" => :broadcast,
             "multicast" => :multicast
           }),
         {:ok, limits} <-
           named(Map.get(data, "limits", %{}), Map.new(@limits, &{Atom.to_string(&1), &1})),
         {:ok, tls} <- tls(Map.get(data, "tls", %{})),
         {:ok, udp} <- udp(Map.get(data, "udp", %{})) do
      base =
        Map.new(Map.take(data, Map.keys(@service_keys)), fn {key, value} ->
          {@service_keys[key], value}
        end)

      {:ok,
       Map.merge(base, %{
         transport: transport,
         handler: handler,
         ip: ip,
         mode: mode,
         limits: limits,
         tls: tls,
         udp: udp
       })}
    end
  end

  defp service(_), do: {:error, :invalid_service}

  defp tls(data) do
    with {:ok, options} <-
           named(data, %{
             "certfile" => :certfile,
             "keyfile" => :keyfile,
             "alpn" => :alpn,
             "provider" => :provider
           }) do
      case Map.fetch(options, :provider) do
        {:ok, provider} ->
          with {:ok, provider} <- enum(provider, %{"otp" => :otp, "ex_ssl" => :ex_ssl}),
               do: {:ok, Map.put(options, :provider, provider)}

        :error ->
          {:ok, options}
      end
    end
  end

  defp udp(data) do
    with {:ok, options} <-
           named(data, %{
             "memberships" => :memberships,
             "multicast_if" => :multicast_if,
             "multicast_ttl" => :multicast_ttl,
             "multicast_loop" => :multicast_loop,
             "strict_group_filter" => :strict_group_filter
           }),
         {:ok, memberships} <- traverse(Map.get(options, :memberships, []), &membership/1) do
      {:ok,
       if(Map.has_key?(options, :memberships),
         do: Map.put(options, :memberships, memberships),
         else: options
       )}
    end
  end

  defp membership(%{"group" => group, "interface" => interface} = data) do
    with :ok <- keys(data, ["group", "interface"]), {:ok, group} <- address(group) do
      selector =
        case address(interface) do
          {:ok, ip} -> ip
          _ -> interface
        end

      {:ok, {group, selector}}
    end
  end

  defp membership(_), do: {:error, :invalid_membership}
  defp address(value) when is_binary(value), do: :inet.parse_address(String.to_charlist(value))
  defp address(_), do: {:error, :invalid_address}

  defp enum(value, allowed) do
    case Map.fetch(allowed, value) do
      {:ok, result} -> {:ok, result}
      :error -> {:error, :unsupported_value}
    end
  end

  defp named(data, allowed) when is_map(data) do
    with :ok <- keys(data, Map.keys(allowed)),
         do: {:ok, Map.new(data, fn {key, value} -> {allowed[key], value} end)}
  end

  defp named(_, _), do: {:error, :invalid_options}

  defp keys(data, allowed) do
    case Map.keys(data) -- allowed do
      [] -> :ok
      _ -> {:error, :unknown_configuration_keys}
    end
  end

  defp traverse(values, fun) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case fun.(value) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp traverse(_, _), do: {:error, :invalid_list}
end
