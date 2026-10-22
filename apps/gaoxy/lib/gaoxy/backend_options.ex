defmodule Gaoxy.BackendOptions do
  @moduledoc false

  @socket_max 2_147_483_647

  def normalize(spec) when is_map(spec) do
    hell = Map.get(spec, :hell_options, [])
    abyss = Map.get(spec, :abyss_options, [])

    with :ok <- keyword(hell, :hell_options),
         :ok <- keyword(abyss, :abyss_options),
         :ok <- applicable(spec, hell, abyss),
         :ok <- validate(hell, :hell_options, spec),
         :ok <- validate(abyss, :abyss_options, spec),
         {:ok, spec, abyss} <- poll_interval(spec, abyss) do
      {:ok,
       spec
       |> Map.put(:hell_options, canonical(hell))
       |> Map.put(:abyss_options, canonical(abyss))}
    end
  end

  def normalize(_), do: {:error, :invalid_service}

  defp keyword(options, key) do
    if Keyword.keyword?(options) and length(options) == length(Enum.uniq(Keyword.keys(options))),
      do: :ok,
      else: {:error, {:invalid_backend_options, key}}
  end

  defp applicable(spec, hell, abyss) do
    cond do
      hell != [] and Map.get(spec, :transport) not in [:tcp, :tls] ->
        {:error, {:inapplicable_backend_options, :hell_options}}

      abyss != [] and Map.get(spec, :transport) not in [:udp, :quic] ->
        {:error, {:inapplicable_backend_options, :abyss_options}}

      true ->
        :ok
    end
  end

  defp validate(options, entry, spec) do
    Enum.reduce_while(options, :ok, fn {key, value}, _ ->
      case option(entry, key, value, spec) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp option(:hell_options, :num_acceptors, value, spec) do
    limits = Map.get(spec, :limits, %{})
    ceiling = if is_map(limits), do: Map.get(limits, :max_active, 64), else: 0

    valid(
      value,
      is_integer(value) and is_integer(ceiling) and value > 0 and value <= ceiling,
      :hell_options,
      :num_acceptors
    )
  end

  defp option(:hell_options, :transport_options, options, spec),
    do:
      socket_options(options, :hell_options, spec, [
        :backlog,
        :nodelay,
        :keepalive,
        :recbuf,
        :sndbuf,
        :buffer,
        :tos
      ])

  defp option(:abyss_options, :udp_buffer_size, value, %{transport: :udp}),
    do: valid(value, positive?(value), :abyss_options, :udp_buffer_size)

  defp option(:abyss_options, :transport_options, options, %{transport: :udp} = spec),
    do: socket_options(options, :abyss_options, spec, [:tos, :ttl])

  defp option(:abyss_options, :event_batch, value, %{transport: :quic}),
    do: valid(value, is_integer(value) and value in 1..128, :abyss_options, :event_batch)

  defp option(:abyss_options, :poll_interval, value, %{transport: :quic}),
    do: valid(value, is_integer(value) and value in 1..1_000, :abyss_options, :poll_interval)

  defp option(entry, key, _value, _spec),
    do: {:error, {:unsupported_backend_option, entry, key}}

  defp socket_options(options, entry, spec, allowed) do
    with :ok <- keyword(options, {entry, :transport_options}) do
      Enum.reduce_while(options, :ok, fn {key, value}, _ ->
        result =
          cond do
            key not in allowed ->
              {:error, {:unsupported_backend_option, entry, {:transport_options, key}}}

            key in [:nodelay, :keepalive] ->
              valid(value, is_boolean(value), entry, {:transport_options, key})

            key in [:tos, :ttl] ->
              valid(
                value,
                ipv4?(spec) and is_integer(value) and value in 0..255,
                entry,
                {:transport_options, key}
              )

            true ->
              valid(value, positive?(value), entry, {:transport_options, key})
          end

        case result do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)
    end
  end

  defp positive?(value), do: is_integer(value) and value in 1..@socket_max

  defp ipv4?(spec) do
    ip = Map.get(spec, :ip, {127, 0, 0, 1})
    is_tuple(ip) and tuple_size(ip) == 4
  end

  defp valid(_value, true, _entry, _key), do: :ok
  defp valid(_value, false, entry, key), do: {:error, {:invalid_backend_option, entry, key}}

  defp poll_interval(%{transport: :quic} = spec, options) do
    quic = Map.get(spec, :quic, %{})

    case Keyword.fetch(options, :poll_interval) do
      {:ok, value} when is_map(quic) ->
        if Map.has_key?(quic, :poll_interval) and quic.poll_interval != value do
          {:error, {:backend_option_conflict, :poll_interval}}
        else
          {:ok, Map.put(spec, :quic, Map.put(quic, :poll_interval, value)),
           Keyword.delete(options, :poll_interval)}
        end

      {:ok, _} ->
        {:error, :invalid_options}

      :error ->
        {:ok, spec, options}
    end
  end

  defp poll_interval(spec, options), do: {:ok, spec, options}

  defp canonical(options) do
    options
    |> Enum.map(fn
      {:transport_options, value} -> {:transport_options, Enum.sort(value)}
      option -> option
    end)
    |> Enum.sort()
  end
end
