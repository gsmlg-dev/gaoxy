defmodule Gaoxy.Proxy.UpstreamGroups.Options do
  @moduledoc false
  alias Gaoxy.Proxy.HTTP

  @health %{
    path: "/",
    interval: 5_000,
    timeout: 2_000,
    stale_after: 15_000,
    failure_threshold: 3,
    recovery_threshold: 2,
    jitter: 500
  }
  @owner %{
    max_groups: 64,
    max_config_bytes: 16_777_216,
    max_pins: 1024,
    max_tokens: 1024,
    max_probes: 4,
    probe_bytes: 67_108_864
  }
  defstruct [:id, :members, :health, max_inflight: 64]

  def compile(%__MODULE__{} = group) do
    members =
      for member <- group.members do
        Map.merge(member.config.limits, %{
          id: member.id,
          upstream: URI.to_string(member.config.uri),
          cacertfile: member.config.cacertfile,
          connect_address: member.config.connect_address,
          max_inflight: member.max_inflight
        })
      end

    compile(%{
      id: group.id,
      members: members,
      health: group.health,
      max_inflight: group.max_inflight
    })
  rescue
    _ -> {:error, :invalid_upstream_group}
  end

  def compile(options) when is_map(options) do
    with true <- Map.keys(options) -- [:id, :members, :health, :max_inflight] == [],
         true <- :erlang.external_size(options) <= 1_048_576,
         true <- id?(options[:id]),
         members when is_list(members) and length(members) in 1..32 <- options[:members],
         {:ok, members} <- members(members),
         true <- length(Enum.uniq_by(members, & &1.id)) == length(members),
         max = Map.get(options, :max_inflight, 64),
         true <- is_integer(max) and max in 1..1024,
         health when is_map(health) <- Map.get(options, :health, %{}),
         true <- Map.keys(health) -- Map.keys(@health) == [],
         health = Map.merge(@health, health),
         true <- path?(health.path),
         true <-
           Enum.all?(Map.delete(health, :path), fn {key, value} ->
             is_integer(value) and value >= if(key == :jitter, do: 0, else: 1) and
               value <= 3_600_000
           end),
         true <-
           health.timeout <= 5_000 and health.failure_threshold <= 100 and
             health.recovery_threshold <= 100 and health.stale_after >= health.interval do
      {:ok, %__MODULE__{id: options.id, members: members, health: health, max_inflight: max}}
    else
      _ -> {:error, :invalid_upstream_group}
    end
  end

  def compile(_), do: {:error, :invalid_upstream_group}

  def owner(options) when is_list(options) do
    limits = if Keyword.keyword?(options), do: Keyword.get(options, :limits, %{}), else: :invalid

    with true <- Keyword.keyword?(options) and length(options) == map_size(Map.new(options)),
         true <- Keyword.keys(options) -- [:instance, :name, :limits] == [],
         true <- is_pid(options[:instance]),
         true <- not Keyword.has_key?(options, :name) or name?(options[:name]),
         true <- is_map(limits) and Map.keys(limits) -- Map.keys(@owner) == [],
         limits = Map.merge(@owner, limits),
         true <- Enum.all?(limits, fn {_, n} -> is_integer(n) and n > 0 end),
         true <-
           limits.max_groups <= 1024 and limits.max_pins <= 16_384 and limits.max_tokens <= 16_384 and
             limits.max_probes <= 32 and limits.max_config_bytes <= 67_108_864 and
             limits.probe_bytes <= 536_870_912 do
      {:ok, limits}
    else
      _ -> {:error, :invalid_group_owner_options}
    end
  end

  def owner(_), do: {:error, :invalid_group_owner_options}

  defp members(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      with true <- is_map(value) and id?(value[:id]),
           max = Map.get(value, :max_inflight, 16),
           true <- is_integer(max) and max in 1..1024,
           {:ok, config} <- HTTP.init(Map.drop(value, [:id, :max_inflight])),
           true <- byte_size(URI.to_string(config.uri)) <= 8192 do
        {:cont, {:ok, acc ++ [%{id: value.id, config: config, max_inflight: max}]}}
      else
        _ -> {:halt, {:error, :invalid_group_member}}
      end
    end)
  end

  defp name?(name) when is_atom(name), do: name != nil
  defp name?({:global, _}), do: true

  defp name?({:via, module, _}) when is_atom(module),
    do:
      Code.ensure_loaded?(module) and
        function_exported?(module, :register_name, 2) and
        function_exported?(module, :whereis_name, 1)

  defp name?(_), do: false
  defp id?(value), do: is_binary(value) and byte_size(value) in 1..128

  defp path?("/" <> _ = value),
    do:
      byte_size(value) <= 8192 and
        Enum.all?(:binary.bin_to_list(value), &(&1 in 33..126 and &1 not in [?#, ?\\])) and
        not Regex.match?(~r/%(?![0-9a-fA-F]{2})/, value)

  defp path?(_), do: false
end
