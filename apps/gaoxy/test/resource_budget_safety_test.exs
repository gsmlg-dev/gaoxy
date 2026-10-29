defmodule Gaoxy.ResourceBudget.SafetyTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.ResourceBudget.Safety
  @mib 1_048_576

  defp check(projected, sample, options \\ []) do
    apply(Safety, :check, [
      projected,
      sample,
      1000 * @mib,
      Keyword.get(options, :now, 1000),
      Keyword.get(options, :processes, %{count: 10, limit: 1000})
    ])
  end

  defp sample(extra \\ %{}),
    do:
      Map.merge(
        %{
          available_bytes: 200 * @mib,
          cgroup_headroom_bytes: nil,
          sampled_at: 1000,
          retained_baseline: 0,
          high_pressure?: false
        },
        extra
      )

  defp usage(retained, temporary \\ 0, pending \\ 0),
    do: %{retained_bytes: retained, temporary_bytes: temporary, pending_processes: pending}

  test "reserves five percent headroom and admits the exact remaining boundary" do
    assert check(usage(150 * @mib), sample()) == :ok
    assert check(usage(150 * @mib + 1), sample()) == {:error, :system_memory_pressure}
  end

  test "minimum headroom is sixteen MiB" do
    assert apply(Safety, :headroom, [100 * @mib]) == 16 * @mib
  end

  test "uses the smallest physical or finite controller headroom" do
    assert check(usage(@mib), sample(%{cgroup_headroom_bytes: 50 * @mib})) ==
             {:error, :system_memory_pressure}
  end

  test "missing malformed and stale safety observations fail closed" do
    for data <- [nil, %{}, sample(%{available_bytes: -1}), sample(%{sampled_at: -2001})] do
      assert check(usage(1), data) == {:error, :safety_sample_unavailable}
    end

    assert check(usage(1), sample(), now: 4000) == :ok
    assert check(usage(1), sample(), now: 4001) == {:error, :safety_sample_unavailable}
  end

  test "resampling never erases unmaterialized temporary commitments" do
    assert check(usage(100 * @mib, 151 * @mib), sample(%{retained_baseline: 100 * @mib})) ==
             {:error, :system_memory_pressure}
  end

  test "confirmed releases reduce positive growth without granting negative usage" do
    assert check(usage(90 * @mib, 150 * @mib), sample(%{retained_baseline: 100 * @mib})) == :ok
  end

  test "live process guard includes pending spawn credits" do
    assert check(usage(0, 0, 1), sample(), processes: %{count: 871, limit: 1000}) == :ok

    assert check(usage(0, 0, 2), sample(), processes: %{count: 871, limit: 1000}) ==
             {:error, :process_capacity}
  end

  test "high is a pressure indicator rather than a physical capacity" do
    assert check(usage(1), sample(%{high_pressure?: true})) == {:error, :system_memory_pressure}
  end

  test "Linux safety reads available physical and finite controller headroom" do
    files = %{
      "/proc/meminfo" => "MemTotal: 1000000 kB\nMemAvailable: 500000 kB\n",
      "/proc/self/cgroup" => "0::/work\n",
      "/proc/self/mountinfo" => "1 0 0:1 / /cg rw - cgroup2 cgroup rw\n",
      "/cg/work/memory.max" => "800000000",
      "/cg/work/memory.current" => "300000000",
      "/cg/work/memory.high" => "400000000",
      "/cg/memory.max" => "max",
      "/cg/memory.current" => "0",
      "/cg/memory.high" => "max"
    }

    read = fn path ->
      case Map.fetch(files, path) do
        {:ok, x} -> {:ok, x}
        _ -> {:error, :enoent}
      end
    end

    assert {:ok, data} =
             apply(Safety, :detect, [
               %{
                 capacity: 800_000_000,
                 cgroup_limit_bytes: 800_000_000,
                 metadata: %{controller_locations: [{:v2, "/cg/work", "/cg"}]}
               },
               [platform: {:unix, :linux}, read_file: read, now: fn -> 1000 end]
             ])

    assert data.available_bytes == 512_000_000
    assert data.cgroup_headroom_bytes == 500_000_000
    refute data.high_pressure?
  end

  test "native available memory uses public memsup data and rejects missing physical metrics" do
    detect = fn query ->
      apply(Safety, :detect, [
        %{capacity: 1000},
        [platform: {:win32, :nt}, native: query, now: fn -> 1000 end]
      ])
    end

    assert {:ok, %{available_bytes: 400}} =
             detect.(fn -> [system_total_memory: 1000, available_memory: 400] end)

    assert {:ok, %{available_bytes: 300}} =
             detect.(fn -> [system_total_memory: 1000, free_memory: 300] end)

    assert {:error, :safety_sample_unavailable} = detect.(fn -> [system_total_memory: 1000] end)
  end

  test "finite v2 high pressure still applies when the hard maximum is unlimited" do
    files = %{
      "/proc/meminfo" => "MemAvailable: 500000 kB\n",
      "/cg/memory.max" => "max",
      "/cg/memory.current" => "300000000",
      "/cg/memory.high" => "200000000"
    }

    read = fn path -> Map.fetch(files, path) end

    assert {:ok, %{high_pressure?: true, cgroup_headroom_bytes: nil}} =
             apply(Safety, :detect, [
               %{
                 capacity: 1_000_000_000,
                 cgroup_limit_bytes: nil,
                 metadata: %{controller_locations: [{:v2, "/cg", "/cg"}]}
               },
               [platform: {:unix, :linux}, read_file: read]
             ])
  end

  test "hidden finite controller limits without observable enforcing current fail closed" do
    files = %{
      "/proc/meminfo" => "MemAvailable: 500000 kB\n",
      "/cg/memory.limit_in_bytes" => "800000000",
      "/cg/memory.usage_in_bytes" => "1"
    }

    assert {:error, :safety_sample_unavailable} =
             apply(Safety, :detect, [
               %{
                 capacity: 200_000_000,
                 cgroup_limit_bytes: 200_000_000,
                 metadata: %{controller_locations: [{:v1, "/cg", "/cg"}]}
               },
               [platform: {:unix, :linux}, read_file: fn p -> Map.fetch(files, p) end]
             ])
  end

  test "unreadable required controller current or high fails closed" do
    files = %{"/proc/meminfo" => "MemAvailable: 500000 kB\n", "/cg/memory.max" => "1000000"}

    assert {:error, :safety_sample_unavailable} =
             apply(Safety, :detect, [
               %{
                 capacity: 1_000_000,
                 cgroup_limit_bytes: 1_000_000,
                 metadata: %{controller_locations: [{:v2, "/cg", "/cg"}]}
               },
               [platform: {:unix, :linux}, read_file: fn p -> Map.fetch(files, p) end]
             ])
  end

  test "capacity detection publishes its validated controller locations without a second resolver" do
    files = %{
      "/proc/meminfo" => "MemTotal: 1000000 kB\n",
      "/proc/self/cgroup" => "0::/work\n",
      "/proc/self/mountinfo" => "1 0 0:1 / /cg rw - cgroup2 cgroup rw\n",
      "/cg/work/memory.max" => "800000000",
      "/cg/memory.max" => "max"
    }

    read = fn path ->
      case Map.fetch(files, path) do
        {:ok, value} -> {:ok, value}
        _ -> {:error, :enoent}
      end
    end

    snapshot =
      Gaoxy.ResourceBudget.SystemMemory.detect(platform: {:unix, :linux}, read_file: read)

    assert snapshot.capacity == 800_000_000
    assert snapshot.metadata.controller_locations == [{:v2, "/cg/work", "/cg"}]
    assert 800_000_000 in snapshot.metadata.controller_limits
  end

  test "missing root current cannot hide finite high pressure under an unlimited maximum" do
    files = %{
      "/proc/meminfo" => "MemAvailable: 500000 kB\n",
      "/cg/memory.max" => "max",
      "/cg/memory.high" => "1000000"
    }

    read = fn p ->
      case Map.fetch(files, p) do
        {:ok, x} -> {:ok, x}
        _ -> {:error, :enoent}
      end
    end

    assert {:error, :safety_sample_unavailable} =
             apply(Safety, :detect, [
               %{
                 capacity: 1_000_000_000,
                 cgroup_limit_bytes: nil,
                 metadata: %{controller_locations: [{:v2, "/cg", "/cg"}]}
               },
               [platform: {:unix, :linux}, read_file: read]
             ])
  end
end
