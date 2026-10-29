defmodule Gaoxy.ResourceBudget.Safety do
  @moduledoc "Independent physical/OOM headroom and process safety observations."
  @maximum 9_223_372_036_854_775_807
  @mib 1_048_576

  def headroom(capacity), do: max(16 * @mib, div(capacity, 20))

  # Temporary bytes are promises, including promises made before this sample.
  # A sample can reset only materialized retained growth, never those promises.
  def check(usage, sample, capacity, now, processes) do
    with :ok <- process_check(usage.pending_processes, processes),
         true <- fresh?(sample, now) || {:error, :safety_sample_unavailable} do
      available =
        min(sample.available_bytes, sample.cgroup_headroom_bytes || sample.available_bytes)

      debit = usage.temporary_bytes + max(0, usage.retained_bytes - sample.retained_baseline)

      if Map.get(sample, :high_pressure?, false) or debit > available - headroom(capacity),
        do: {:error, :system_memory_pressure},
        else: :ok
    end
  end

  def process_check(0, _), do: :ok

  def process_check(pending, %{count: count, limit: limit})
      when is_integer(pending) and pending > 0 and is_integer(count) and count >= 0 and
             is_integer(limit) and limit > 0 do
    if count + pending <= limit - max(128, div(limit, 20)),
      do: :ok,
      else: {:error, :process_capacity}
  end

  def process_check(_, _), do: {:error, :process_capacity}

  def fresh?(
        %{
          available_bytes: available,
          cgroup_headroom_bytes: cgroup,
          sampled_at: at,
          retained_baseline: baseline
        },
        now
      ) do
    valid_bytes?(available) and (is_nil(cgroup) or valid_bytes?(cgroup)) and
      is_integer(at) and is_integer(baseline) and baseline >= 0 and at <= now and now - at <= 3000
  end

  def fresh?(_, _), do: false
  defp valid_bytes?(n), do: is_integer(n) and n >= 0 and n <= @maximum

  def detect(detection, options \\ []) do
    now = Keyword.get(options, :now, fn -> System.monotonic_time(:millisecond) end)

    result =
      case Keyword.get_lazy(options, :platform, &:os.type/0) do
        {:unix, :linux} ->
          linux(detection, Keyword.get(options, :read_file, &File.read/1))

        {:unix, :darwin} ->
          native(Keyword.get(options, :native, &:memsup.get_system_memory_data/0))

        {:win32, _} ->
          native(Keyword.get(options, :native, &:memsup.get_system_memory_data/0))

        _ ->
          {:error, :safety_sample_unavailable}
      end

    case result do
      {:ok, data} -> {:ok, Map.put(data, :sampled_at, now.())}
      _ -> {:error, :safety_sample_unavailable}
    end
  rescue
    _ -> {:error, :safety_sample_unavailable}
  catch
    _, _ -> {:error, :safety_sample_unavailable}
  end

  defp native(query) do
    data = query.()

    with true <- Keyword.keyword?(data) and length(data) <= 64,
         [total] when is_integer(total) and total > 0 <-
           Keyword.get_values(data, :system_total_memory),
         available = Keyword.get(data, :available_memory, Keyword.get(data, :free_memory)),
         true <- valid_bytes?(available) and available <= total do
      {:ok, %{available_bytes: available, cgroup_headroom_bytes: nil, high_pressure?: false}}
    else
      _ -> {:error, :safety_sample_unavailable}
    end
  end

  defp linux(detection, read) do
    with {:ok, info} <- read.("/proc/meminfo"),
         [_, available] <- Regex.run(~r/^MemAvailable:\s+(\d+)\s+kB\s*$/m, info),
         {:ok, bytes} <- integer(available, 1024),
         {:ok, headroom, high?} <- controllers(detection, read) do
      {:ok, %{available_bytes: bytes, cgroup_headroom_bytes: headroom, high_pressure?: high?}}
    else
      _ -> {:error, :safety_sample_unavailable}
    end
  end

  defp controllers(detection, read) do
    with metadata when is_map(metadata) <- Map.get(detection, :metadata, %{}),
         locations when is_list(locations) <- Map.get(metadata, :controller_locations),
         {:ok, observations} <- observations(locations, read) do
      finite = Enum.filter(observations, &is_integer(&1.limit))
      detected = Map.get(detection, :cgroup_limit_bytes)
      visible = Enum.min(Enum.map(finite, & &1.limit), fn -> nil end)
      # A hidden enforcing parent has no observable current usage. Do not spend
      # its siblings' headroom using only the visible child's current value.
      if is_integer(detected) and (is_nil(visible) or visible > detected) do
        {:error, :safety_sample_unavailable}
      else
        remaining = Enum.map(finite, &max(0, &1.limit - &1.current))
        {:ok, Enum.min(remaining, fn -> nil end), Enum.any?(observations, & &1.high?)}
      end
    end
  end

  defp observations(locations, read) do
    Enum.reduce_while(locations, {:ok, []}, fn {type, leaf, root}, {:ok, acc} ->
      result =
        Enum.reduce_while(ancestors(leaf, root), {:ok, acc}, fn path, {:ok, acc} ->
          # v1 parents without hierarchical accounting do not constrain children.
          case applies?(type, path, leaf, read) do
            {:ok, true} ->
              case observation(type, path, read) do
                {:ok, row} ->
                  {:cont, {:ok, [row | acc]}}

                {:error, :controller_not_present} when path == root and type == :v2 ->
                  {:cont, {:ok, acc}}

                _ ->
                  {:halt, {:error, :safety_sample_unavailable}}
              end

            {:ok, false} ->
              {:cont, {:ok, acc}}

            _ ->
              {:halt, {:error, :safety_sample_unavailable}}
          end
        end)

      case result do
        {:ok, _} -> {:cont, result}
        _ -> {:halt, result}
      end
    end)
  end

  defp applies?(:v2, _, _, _), do: {:ok, true}
  defp applies?(_, leaf, leaf, _), do: {:ok, true}

  defp applies?(:v1, path, _, read) do
    case read.(Path.join(path, "memory.use_hierarchy")) do
      {:ok, raw} ->
        case String.trim(raw) do
          "1" -> {:ok, true}
          "0" -> {:ok, false}
          _ -> {:error, :safety_sample_unavailable}
        end

      _ ->
        {:error, :safety_sample_unavailable}
    end
  end

  defp observation(type, path, read) do
    max_file = if type == :v2, do: "memory.max", else: "memory.limit_in_bytes"
    current_file = if type == :v2, do: "memory.current", else: "memory.usage_in_bytes"

    case read.(Path.join(path, max_file)) do
      {:error, :enoent} ->
        {:error, :controller_not_present}

      {:ok, raw} ->
        with {:ok, limit} <- limit(raw, type) do
          if is_nil(limit) and type == :v1 do
            {:ok, %{limit: nil, current: 0, high?: false}}
          else
            with {:ok, raw_current} <- read.(Path.join(path, current_file)),
                 {:ok, current} <- integer(raw_current),
                 {:ok, high?} <- high(type, path, current, read) do
              {:ok, %{limit: limit, current: current, high?: high?}}
            else
              _ -> {:error, :safety_sample_unavailable}
            end
          end
        end

      _ ->
        {:error, :safety_sample_unavailable}
    end
  end

  defp high(:v1, _, _, _), do: {:ok, false}

  defp high(_, path, current, read) do
    case read.(Path.join(path, "memory.high")) do
      {:ok, raw} ->
        case limit(raw, :v2) do
          {:ok, nil} -> {:ok, false}
          {:ok, n} -> {:ok, current >= n}
          other -> other
        end

      _ ->
        {:error, :safety_sample_unavailable}
    end
  end

  defp limit(raw, type) do
    case String.trim(raw) do
      "max" when type == :v2 ->
        {:ok, nil}

      text ->
        case integer(text) do
          {:ok, n} when type == :v1 and n >= 9_223_372_036_854_771_712 -> {:ok, nil}
          {:ok, n} when n > 0 -> {:ok, n}
          _ -> {:error, :safety_sample_unavailable}
        end
    end
  end

  defp integer(raw, multiplier \\ 1) do
    case Integer.parse(String.trim(raw)) do
      {n, ""} when n >= 0 and n <= div(@maximum, multiplier) -> {:ok, n * multiplier}
      _ -> {:error, :safety_sample_unavailable}
    end
  end

  defp ancestors(root, root), do: [root]
  defp ancestors(path, root), do: [path | ancestors(Path.dirname(path), root)]
end
