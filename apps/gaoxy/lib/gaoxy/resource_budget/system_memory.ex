defmodule Gaoxy.ResourceBudget.SystemMemory do
  @moduledoc """
  Detects physical capacity and applicable Linux memory-controller ceilings.

  This is a startup/refresh probe, never a per-request operation. Capacity is
  independent of currently free memory. `detect/1` accepts `:platform`,
  `:read_file` and `:native` injections for deterministic testing.
  """
  @maximum 9_223_372_036_854_775_807
  @v1_unlimited 9_223_372_036_854_771_712
  @unsigned_maximum 18_446_744_073_709_551_615
  @max_file 1_048_576
  @max_native 65_536

  @doc "Returns a structured capacity snapshot; unreliable detection has nil capacity."
  def detect(options \\ []) do
    case Keyword.get_lazy(options, :platform, &:os.type/0) do
      {:unix, :linux} -> linux(Keyword.get(options, :read_file, &File.read/1))
      {:unix, :darwin} -> native(:darwin, Keyword.get(options, :native, &native/1))
      {:win32, _} -> native(:windows, Keyword.get(options, :native, &native/1))
      _ -> select(nil, [], %{reasons: [:unsupported_platform]})
    end
  end

  @doc "Selects the lowest reliable physical/controller capacity without performing IO."
  def select(physical, limits, metadata \\ %{}) do
    physical = if capacity?(physical), do: physical
    valid_limits = is_list(limits) and Enum.all?(limits, &(&1 == :unlimited or capacity?(&1)))

    finite =
      if is_list(limits), do: Enum.filter(limits, &capacity?/1), else: []

    cgroup = Enum.min(finite, fn -> nil end)

    reasons =
      Map.get(metadata, :reasons, [])
      |> then(fn reasons ->
        if physical == nil and :unsupported_platform not in reasons,
          do: [:physical_memory_unavailable | reasons],
          else: reasons
      end)
      |> then(fn reasons ->
        if valid_limits, do: reasons, else: [:invalid_cgroup_limit | reasons]
      end)
      |> Enum.uniq()

    fallback = physical == nil or reasons != []

    %{
      capacity: if(fallback, do: nil, else: min(physical, cgroup || physical)),
      physical_bytes: physical,
      cgroup_limit_bytes: cgroup,
      source: if(fallback, do: :fallback, else: Map.get(metadata, :source, :linux)),
      fallback?: fallback,
      reasons: reasons,
      metadata: Map.drop(metadata, [:source, :reasons])
    }
  end

  defp capacity?(value), do: is_integer(value) and value in 2..@maximum

  defp linux(read_file) do
    physical =
      with {:ok, bytes} <- read(read_file, "/proc/meminfo"),
           [[kilobytes]] <-
             Regex.scan(~r/^MemTotal:\s+([0-9]+)\s+kB\s*$/m, bytes, capture: :all_but_first),
           {:ok, kb} <- decimal(kilobytes, div(@maximum, 1_024)),
           true <- kb > 0 do
        kb * 1_024
      else
        _ -> nil
      end

    {limits, reasons, metadata} = cgroups(read_file)
    select(physical, limits, Map.merge(metadata, %{source: :linux, reasons: reasons}))
  end

  defp cgroups(read_file) do
    with {:ok, bytes} <- read(read_file, "/proc/self/cgroup"),
         {:ok, memberships} <- memberships(bytes) do
      if memberships == [] do
        {[], [], %{controllers: [], controller_locations: [], controller_limits: []}}
      else
        with {:ok, bytes} <- read(read_file, "/proc/self/mountinfo"),
             {:ok, mounts} <- mounts(bytes),
             {:ok, locations} <- locations(memberships, mounts),
             {:ok, limits} <- controller_limits(locations, read_file) do
          {limits, [],
           %{
             controllers: Enum.uniq(Enum.map(memberships, &elem(&1, 0))),
             controller_locations: Enum.uniq(locations),
             controller_limits: limits
           }}
        else
          {:error, reason} -> {[], [reason], %{}}
        end
      end
    else
      {:error, reason} -> {[], [reason], %{}}
    end
  end

  defp memberships(bytes) do
    Enum.reduce_while(lines(bytes), {:ok, []}, fn line, {:ok, acc} ->
      case String.split(line, ":", parts: 3) do
        [hierarchy, controllers, path] ->
          with {:ok, _} <- decimal(hierarchy, @maximum),
               true <- valid_path?(path) do
            version =
              cond do
                hierarchy == "0" and controllers == "" -> :v2
                "memory" in String.split(controllers, ",") -> :v1
                true -> nil
              end

            {:cont, {:ok, if(version, do: [{version, path} | acc], else: acc)}}
          else
            _ -> {:halt, {:error, :invalid_cgroup_membership}}
          end

        _ ->
          {:halt, {:error, :invalid_cgroup_membership}}
      end
    end)
  end

  defp mounts(bytes) do
    Enum.reduce_while(lines(bytes), {:ok, []}, fn line, {:ok, acc} ->
      case String.split(line, " - ") do
        [before, after_separator] ->
          case {String.split(before), String.split(after_separator)} do
            {[_id, _parent, _device, root, mount, _options | _], [type, _source, options | _]} ->
              version =
                cond do
                  type == "cgroup2" -> :v2
                  type == "cgroup" and "memory" in String.split(options, ",") -> :v1
                  true -> nil
                end

              if version do
                root = unescape(root)
                mount = unescape(mount)

                if valid_path?(root) and valid_path?(mount),
                  do: {:cont, {:ok, [{version, root, mount} | acc]}},
                  else: {:halt, {:error, :invalid_cgroup_mount}}
              else
                {:cont, {:ok, acc}}
              end

            _ ->
              {:halt, {:error, :invalid_cgroup_mount}}
          end

        _ ->
          {:halt, {:error, :invalid_cgroup_mount}}
      end
    end)
  end

  defp locations(memberships, mounts) do
    Enum.reduce_while(memberships, {:ok, []}, fn {version, path}, {:ok, acc} ->
      matching =
        for {^version, root, mount} <- mounts,
            path == "/" or beneath?(path, root) do
          # A cgroup namespace reports its own root as `/`, while mountinfo
          # can retain the host-side controller root. Only this unambiguous
          # root case bypasses the ordinary host-path prefix requirement.
          relative =
            if path == "/", do: [], else: Enum.drop(segments(path), length(segments(root)))

          leaf = Path.join([mount | relative])
          {version, leaf, mount}
        end

      if matching == [],
        do: {:halt, {:error, :cgroup_mount_unavailable}},
        else: {:cont, {:ok, matching ++ acc}}
    end)
  end

  defp controller_limits(locations, read_file) do
    Enum.reduce_while(Enum.uniq(locations), {:ok, []}, fn location, {:ok, limits} ->
      case location_limits(location, read_file) do
        {:ok, effective} -> {:cont, {:ok, effective ++ limits}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp location_limits({:v1, leaf, _root}, read_file) do
    # memory.stat reports the effective enforcing hierarchy, including ancestors
    # hidden above a bind/namespace mount. Walking visible own limits is wrong
    # both for hidden parents and for legacy memory.use_hierarchy=0 parents.
    with {:ok, local} <- read_controller(read_file, leaf, :v1),
         {:ok, bytes} <- read_hierarchy(read_file, leaf),
         {:ok, hierarchical} <- hierarchical_limit(bytes) do
      {:ok, [local, hierarchical]}
    end
  end

  defp location_limits({:v2, leaf, root}, read_file) do
    Enum.reduce_while(ancestors(leaf, root), {:ok, []}, fn directory, {:ok, limits} ->
      case read_controller(read_file, directory, :v2) do
        {:ok, limit} -> {:cont, {:ok, [limit | limits]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp read_controller(read_file, directory, version) do
    filename = if version == :v2, do: "memory.max", else: "memory.limit_in_bytes"

    case read(read_file, Path.join(directory, filename)) do
      {:ok, bytes} -> controller_limit(String.trim(bytes), version)
      {:error, :enoent} when version == :v2 -> {:ok, :unlimited}
      {:error, _} -> {:error, :cgroup_limit_unavailable}
    end
  end

  defp read_hierarchy(read_file, directory) do
    case read(read_file, Path.join(directory, "memory.stat")) do
      {:ok, bytes} -> {:ok, bytes}
      {:error, _} -> {:error, :cgroup_hierarchy_unavailable}
    end
  end

  defp hierarchical_limit(bytes) do
    entries =
      for line <- lines(bytes),
          [key | _] = fields <- [String.split(line, ~r/[ \t]+/, trim: true)],
          key == "hierarchical_memory_limit",
          do: fields

    with [["hierarchical_memory_limit", value]] <- entries,
         {:ok, limit} <- controller_limit(value, :v1) do
      {:ok, limit}
    else
      _ -> {:error, :invalid_cgroup_hierarchy}
    end
  end

  defp controller_limit("max", :v2), do: {:ok, :unlimited}

  defp controller_limit(bytes, :v1) do
    case decimal(bytes, @unsigned_maximum) do
      {:ok, limit} when limit >= @v1_unlimited -> {:ok, :unlimited}
      {:ok, limit} when limit >= 2 and limit <= @maximum -> {:ok, limit}
      _ -> {:error, :invalid_cgroup_limit}
    end
  end

  defp controller_limit(bytes, :v2) do
    case decimal(bytes, @maximum) do
      {:ok, limit} when limit >= 2 -> {:ok, limit}
      _ -> {:error, :invalid_cgroup_limit}
    end
  end

  defp ancestors(root, root), do: [root]
  defp ancestors(path, root), do: [path | ancestors(Path.dirname(path), root)]

  defp beneath?(path, root),
    do: Enum.take(segments(path), length(segments(root))) == segments(root)

  defp segments(path), do: String.split(path, "/", trim: true)

  defp valid_path?("/" <> _ = path) do
    byte_size(path) <= 4_096 and not String.contains?(path, <<0>>) and
      Enum.all?(segments(path), &(&1 not in [".", ".."])) and
      not String.contains?(path, "//")
  end

  defp valid_path?(_), do: false

  defp unescape(path) do
    Regex.replace(~r/\\(040|011|012|134)/, path, fn
      _, "040" -> " "
      _, "011" -> "\t"
      _, "012" -> "\n"
      _, "134" -> "\\"
    end)
  end

  defp lines(bytes), do: String.split(bytes, "\n", trim: true)

  defp read(read_file, path) do
    case safe(fn -> read_file.(path) end) do
      {:ok, bytes} when is_binary(bytes) and byte_size(bytes) <= @max_file -> {:ok, bytes}
      {:error, reason} when is_atom(reason) -> {:error, reason}
      _ -> {:error, :unreliable_memory_data}
    end
  end

  defp decimal(bytes, maximum)
       when is_binary(bytes) and byte_size(bytes) in 1..20 do
    if Regex.match?(~r/\A[0-9]+\z/, bytes) do
      case Integer.parse(bytes) do
        {value, ""} when value <= maximum -> {:ok, value}
        _ -> {:error, :invalid_memory_value}
      end
    else
      {:error, :invalid_memory_value}
    end
  end

  defp decimal(_, _), do: {:error, :invalid_memory_value}

  defp native(platform, probe) do
    physical =
      case safe(fn -> probe.(platform) end) do
        {:ok, value} when is_integer(value) ->
          value

        {:ok, bytes} when is_binary(bytes) and byte_size(bytes) <= @max_native ->
          case decimal(String.trim(bytes), @maximum) do
            {:ok, value} -> value
            _ -> nil
          end

        _ ->
          nil
      end

    select(physical, [], %{source: platform, facility: :otp_memsup})
  end

  defp native(platform), do: Gaoxy.ResourceBudget.SystemMemory.Native.capacity(platform)

  defp safe(function) do
    function.()
  rescue
    _ -> {:error, :memory_probe_failed}
  catch
    _, _ -> {:error, :memory_probe_failed}
  end
end
