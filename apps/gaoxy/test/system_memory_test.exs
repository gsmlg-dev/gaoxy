defmodule Gaoxy.ResourceBudget.SystemMemoryTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.ResourceBudget.SystemMemory

  @gib 1_073_741_824
  @maximum 9_223_372_036_854_775_807
  @mount "/sys/fs/cgroup"

  test "Linux uses physical MemTotal rather than temporarily free memory" do
    snapshot = linux(%{"/proc/meminfo" => "MemTotal: 8388608 kB\nMemFree: 1 kB\n"})

    assert %{capacity: capacity, physical_bytes: capacity, source: :linux, fallback?: false} =
             snapshot

    assert capacity == 8 * @gib
  end

  test "cgroup v2 finite leaf limit bounds physical memory" do
    snapshot = v2("/app", %{"/app/memory.max" => "2147483648\n"})
    assert snapshot.capacity == 2 * @gib
    assert snapshot.cgroup_limit_bytes == 2 * @gib
  end

  test "cgroup v2 checks every ancestor up to its mounted root" do
    snapshot =
      v2("/team/app", %{
        "/team/app/memory.max" => "max\n",
        "/team/memory.max" => "1073741824\n",
        "/memory.max" => "2147483648\n"
      })

    assert snapshot.capacity == @gib
    assert snapshot.cgroup_limit_bytes == @gib
  end

  test "v2 mount root is removed from the membership before walking ancestors" do
    files = %{
      "/proc/self/cgroup" => "0::/tenant/app\n",
      "/proc/self/mountinfo" => mountinfo("/tenant", "/budget", "cgroup2", "rw"),
      "/budget/app/memory.max" => "max",
      "/budget/memory.max" => Integer.to_string(@gib)
    }

    assert linux(files).capacity == @gib
  end

  test "a namespace-relative root membership maps to a non-root controller mount" do
    snapshot =
      linux(%{
        "/proc/self/cgroup" => "0::/\n",
        "/proc/self/mountinfo" => mountinfo("/docker/container", "/budget", "cgroup2", "rw"),
        "/budget/memory.max" => Integer.to_string(@gib)
      })

    assert snapshot.capacity == @gib
    refute snapshot.fallback?
  end

  test "a v1 namespace-relative root membership preserves its mounted memory limit" do
    snapshot =
      linux(%{
        "/proc/self/cgroup" => "3:memory:/\n",
        "/proc/self/mountinfo" =>
          mountinfo("/docker/container", "/budget", "cgroup", "rw,memory"),
        "/budget/memory.limit_in_bytes" => Integer.to_string(@gib),
        "/budget/memory.stat" => "hierarchical_memory_limit #{@gib}\n"
      })

    assert snapshot.capacity == @gib
    refute snapshot.fallback?
  end

  test "Podman overmounts retain the visible finite capacity and safety headroom" do
    {snapshot, sample} = mounted_memory(podman_mounts())

    assert %{capacity: @gib, cgroup_limit_bytes: @gib, fallback?: false} = snapshot
    assert snapshot.metadata.controller_locations == [{:v2, @mount, @mount}]
    assert {:ok, %{available_bytes: available, cgroup_headroom_bytes: headroom} = safety} = sample
    assert available == 4 * @gib
    assert headroom == div(3 * @gib, 4)

    assert :ok =
             Gaoxy.ResourceBudget.Safety.check(
               %{retained_bytes: 0, temporary_bytes: 1, pending_processes: 0},
               Map.put(safety, :retained_baseline, 0),
               snapshot.capacity,
               1000,
               %{}
             )
  end

  test "Podman overmounts retain physical capacity and safety with an unlimited controller" do
    {snapshot, sample} = mounted_memory(podman_mounts(), %{(@mount <> "/memory.max") => "max"})

    assert %{capacity: capacity, cgroup_limit_bytes: nil, fallback?: false} = snapshot
    assert capacity == 8 * @gib
    assert {:ok, %{cgroup_headroom_bytes: nil, high_pressure?: false}} = sample
  end

  test "mount visibility follows attachments rather than row order or numeric ID priority" do
    rows = [
      "2 40 0:124 / #{@mount} rw - tmpfs tmpfs rw",
      "3 2 0:21 / #{@mount} ro - cgroup2 cgroup2 rw",
      "40 1 0:21 /../../../../../.. #{@mount} rw - cgroup2 cgroup2 rw"
    ]

    for rows <- [rows, Enum.reverse(rows)] do
      {snapshot, sample} = mounted_memory(rows)
      assert %{capacity: @gib, fallback?: false} = snapshot
      assert {:ok, %{cgroup_headroom_bytes: headroom}} = sample
      assert headroom == div(3 * @gib, 4)
    end
  end

  test "an overmount hides descendants attached to the old controller mount" do
    rows =
      podman_mounts() ++
        ["1500 1488 0:21 /../hidden #{@mount}/child rw - cgroup2 cgroup2 rw"]

    {snapshot, sample} = mounted_memory(rows)
    assert %{capacity: @gib, fallback?: false} = snapshot
    assert snapshot.metadata.controller_locations == [{:v2, @mount, @mount}]
    assert {:ok, _} = sample
  end

  test "a controller attached below the covering mount remains visible" do
    rows = [
      "1488 1486 0:21 /../../../../../.. #{@mount} rw - cgroup2 cgroup2 rw",
      "1500 1488 0:21 /../hidden #{@mount}/child rw - cgroup2 cgroup2 rw",
      "1507 1488 0:124 / #{@mount} rw - tmpfs tmpfs rw",
      "1508 1507 0:21 / #{@mount}/child ro - cgroup2 cgroup2 rw"
    ]

    {snapshot, sample} =
      mounted_memory(rows, %{
        (@mount <> "/child/memory.max") => Integer.to_string(@gib),
        (@mount <> "/child/memory.current") => Integer.to_string(div(@gib, 4)),
        (@mount <> "/child/memory.high") => "max"
      })

    assert %{capacity: @gib, fallback?: false} = snapshot

    assert snapshot.metadata.controller_locations == [
             {:v2, @mount <> "/child", @mount <> "/child"}
           ]

    assert {:ok, _} = sample
  end

  test "a final non-controller overmount leaves memory observations unavailable" do
    {snapshot, sample} = mounted_memory(Enum.take(podman_mounts(), 2))

    assert %{capacity: nil, fallback?: true} = snapshot
    assert :cgroup_mount_unavailable in snapshot.reasons
    assert {:error, :safety_sample_unavailable} = sample
  end

  test "a nested overmount cannot turn an inaccessible controller leaf into unlimited capacity" do
    rows = podman_mounts() ++ ["1510 1508 0:124 / #{@mount}/app rw - tmpfs tmpfs rw"]

    {snapshot, sample} = mounted_memory(rows, %{"/proc/self/cgroup" => "0::/app\n"})

    assert %{capacity: nil, fallback?: true} = snapshot
    assert :cgroup_mount_unavailable in snapshot.reasons
    assert {:error, :safety_sample_unavailable} = sample
  end

  test "an overmounted controller file cannot conceal an enforcing limit" do
    rows =
      podman_mounts() ++
        ["1510 1508 254:0 /fake #{@mount}/memory.max rw - ext4 /dev/root rw"]

    {snapshot, sample} = mounted_memory(rows, %{(@mount <> "/memory.max") => "max"})

    assert %{capacity: nil, fallback?: true} = snapshot
    assert :cgroup_mount_unavailable in snapshot.reasons
    assert {:error, :safety_sample_unavailable} = sample
  end

  test "visible controller roots still reject traversal after hiding older mounts" do
    rows =
      List.replace_at(
        podman_mounts(),
        2,
        "1508 1507 0:21 /../escape #{@mount} ro - cgroup2 cgroup2 rw"
      )

    {snapshot, sample} = mounted_memory(rows)

    assert %{capacity: nil, fallback?: true} = snapshot
    assert :invalid_cgroup_mount in snapshot.reasons
    assert {:error, :safety_sample_unavailable} = sample
  end

  test "ambiguous duplicate cyclic and inconsistent mount attachments fail closed" do
    malformed = [
      podman_mounts() ++ ["1510 1507 0:21 / #{@mount} ro - cgroup2 cgroup2 rw"],
      podman_mounts() ++ ["1508 1508 0:21 / #{@mount} ro - cgroup2 cgroup2 rw"],
      List.replace_at(podman_mounts(), 0, "1488 1508 0:21 / #{@mount} rw - cgroup2 cgroup2 rw"),
      podman_mounts() ++ ["1510 1508 0:124 / /outside rw - tmpfs tmpfs rw"]
    ]

    for rows <- malformed do
      {snapshot, sample} = mounted_memory(rows)
      assert %{capacity: nil, fallback?: true} = snapshot
      assert :invalid_cgroup_mount in snapshot.reasons
      assert {:error, :safety_sample_unavailable} = sample
    end
  end

  test "independently visible controller aliases retain the smallest limit and headroom" do
    rows = podman_mounts() ++ ["80 20 0:21 / /budget ro - cgroup2 cgroup2 rw"]

    {snapshot, sample} =
      mounted_memory(rows, %{
        "/budget/memory.max" => Integer.to_string(div(@gib, 2)),
        "/budget/memory.current" => Integer.to_string(div(@gib, 4)),
        "/budget/memory.high" => "max"
      })

    assert %{capacity: capacity, fallback?: false} = snapshot
    assert capacity == div(@gib, 2)
    assert [_, _] = snapshot.metadata.controller_locations
    assert {:ok, %{cgroup_headroom_bytes: headroom}} = sample
    assert headroom == div(@gib, 4)
  end

  test "visible controller current and high observations remain required behind overmounts" do
    for file <- ["memory.current", "memory.high"] do
      {snapshot, sample} = mounted_memory(podman_mounts(), %{(@mount <> "/" <> file) => nil})
      assert %{capacity: @gib, fallback?: false} = snapshot
      assert {:error, :safety_sample_unavailable} = sample
    end
  end

  test "v2 root does not need to expose memory.max" do
    snapshot = v2("/", %{})
    assert snapshot.capacity == 8 * @gib
    assert snapshot.cgroup_limit_bytes == nil
    refute snapshot.fallback?
  end

  test "a missing v2 child controller still checks an enabled ancestor" do
    snapshot = v2("/team/app", %{"/team/memory.max" => Integer.to_string(@gib)})
    assert snapshot.capacity == @gib
  end

  test "unlimited v2 values do not replace physical capacity" do
    snapshot = v2("/app", %{"/app/memory.max" => "max", "/memory.max" => "max"})
    assert snapshot.capacity == 8 * @gib
    assert snapshot.cgroup_limit_bytes == nil
  end

  test "v1 memory controller follows nested limits and ignores other controllers" do
    snapshot =
      linux(%{
        "/proc/self/cgroup" => "2:cpu,cpuacct:/unrelated\n3:memory:/team/app\n",
        "/proc/self/mountinfo" => mountinfo("/", @mount, "cgroup", "rw,memory"),
        (@mount <> "/team/app/memory.limit_in_bytes") => "2147483648",
        (@mount <> "/team/memory.limit_in_bytes") => "1073741824",
        (@mount <> "/memory.limit_in_bytes") => "9223372036854771712",
        (@mount <> "/team/app/memory.stat") => "hierarchical_memory_limit #{@gib}\n"
      })

    assert snapshot.capacity == @gib
    assert snapshot.cgroup_limit_bytes == @gib
  end

  test "v1 kernel unlimited sentinels do not become capacity" do
    for sentinel <- ["9223372036854771712", "18446744073709551615"] do
      snapshot = v1(sentinel)
      assert snapshot.capacity == 8 * @gib
      assert snapshot.cgroup_limit_bytes == nil
    end
  end

  test "limits above physical memory preserve the physical ceiling" do
    snapshot = v2("/app", %{"/app/memory.max" => Integer.to_string(16 * @gib)})
    assert snapshot.capacity == 8 * @gib
    assert snapshot.cgroup_limit_bytes == 16 * @gib
  end

  test "malformed finite cgroup values cannot silently disable the limit" do
    for value <- ["", "oops", "-1", "1.5", "0", "1", "10 MB", "max\n4096"] do
      snapshot = v2("/app", %{"/app/memory.max" => value})
      assert %{capacity: nil, source: :fallback, fallback?: true} = snapshot
      assert :invalid_cgroup_limit in snapshot.reasons
    end
  end

  test "cgroup v2 rejects signed integer overflow and oversized decimal input" do
    for value <- [Integer.to_string(@maximum + 1), String.duplicate("9", 2000)] do
      snapshot = v2("/app", %{"/app/memory.max" => value})
      assert snapshot.fallback?
      assert :invalid_cgroup_limit in snapshot.reasons
    end
  end

  test "unreadable applicable cgroup limits select fallback" do
    snapshot = v2("/app", %{"/app/memory.max" => {:error, :eacces}})
    assert snapshot.fallback?
    assert :cgroup_limit_unavailable in snapshot.reasons
    assert snapshot.physical_bytes == 8 * @gib
  end

  test "missing applicable v1 memory controller is not assumed unlimited" do
    snapshot = v1(nil)
    assert snapshot.fallback?
    assert :cgroup_limit_unavailable in snapshot.reasons
  end

  test "v1 kernel hierarchy metric includes an enforcing parent hidden above the mount root" do
    snapshot =
      linux(%{
        "/proc/self/cgroup" => "3:memory:/parent/container/app\n",
        "/proc/self/mountinfo" =>
          mountinfo("/parent/container", "/budget", "cgroup", "rw,memory"),
        "/budget/app/memory.limit_in_bytes" => "2147483648",
        "/budget/memory.limit_in_bytes" => "2147483648",
        "/budget/app/memory.stat" =>
          "cache 512\nhierarchical_memory_limit 134217728\ntotal_rss 512\n"
      })

    assert snapshot.capacity == 134_217_728
    assert snapshot.cgroup_limit_bytes == 134_217_728
    refute snapshot.fallback?
  end

  test "v1 does not apply a visible parent limit when hierarchy accounting is disabled" do
    snapshot =
      linux(%{
        "/proc/self/cgroup" => "3:memory:/team/app\n",
        "/proc/self/mountinfo" => mountinfo("/", @mount, "cgroup", "rw,memory"),
        (@mount <> "/team/app/memory.limit_in_bytes") => "2147483648",
        (@mount <> "/team/app/memory.stat") => "hierarchical_memory_limit 2147483648\n",
        (@mount <> "/team/memory.limit_in_bytes") => "134217728",
        (@mount <> "/team/memory.use_hierarchy") => "0",
        (@mount <> "/memory.limit_in_bytes") => "9223372036854771712"
      })

    assert snapshot.capacity == 2 * @gib
    refute snapshot.fallback?
  end

  test "missing or denied v1 hierarchy data falls back instead of overlooking hidden limits" do
    for value <- [nil, {:error, :eacces}] do
      snapshot = v1("2147483648", value)
      assert snapshot.fallback?
      assert :cgroup_hierarchy_unavailable in snapshot.reasons
    end
  end

  test "malformed duplicate and overflow v1 hierarchical limits fall back" do
    for value <- [
          "",
          "cache 512\n",
          "hierarchical_memory_limit -1\n",
          "hierarchical_memory_limit 0\n",
          "hierarchical_memory_limit 1\n",
          "hierarchical_memory_limit 18446744073709551616\n",
          "hierarchical_memory_limit 2048 extra\n",
          "hierarchical_memory_limit 2048\nhierarchical_memory_limit 4096\n",
          "hierarchical_memory_limit 2048\nhierarchical_memory_limit invalid\n"
        ] do
      snapshot = v1("2147483648", value)
      assert snapshot.fallback?
      assert :invalid_cgroup_hierarchy in snapshot.reasons
    end
  end

  test "unlimited v1 hierarchy still preserves the finite local limit" do
    snapshot = v1("2147483648", "hierarchical_memory_limit 9223372036854771712\n")
    assert snapshot.capacity == 2 * @gib
    assert snapshot.cgroup_limit_bytes == 2 * @gib
  end

  test "unavailable or malformed membership cannot hide container limits" do
    for input <- [{:error, :eacces}, "0::relative\n", "not-a-membership\n"] do
      snapshot = linux(%{"/proc/self/cgroup" => input})
      assert snapshot.fallback?
    end
  end

  test "relevant membership without a matching controller mount falls back" do
    snapshot = linux(%{"/proc/self/cgroup" => "0::/app\n"})
    assert snapshot.fallback?
    assert :cgroup_mount_unavailable in snapshot.reasons
  end

  test "malformed or denied mount metadata falls back" do
    for value <- ["invalid", {:error, :eacces}] do
      snapshot =
        linux(%{"/proc/self/cgroup" => "0::/app\n", "/proc/self/mountinfo" => value})

      assert snapshot.fallback?
    end
  end

  test "membership traversal is rejected without reading an escaped file" do
    parent = self()

    snapshot =
      SystemMemory.detect(
        platform: {:unix, :linux},
        read_file: fn path ->
          send(parent, {:read, path})

          case path do
            "/proc/meminfo" -> {:ok, "MemTotal: 8388608 kB\n"}
            "/proc/self/cgroup" -> {:ok, "0::/../../etc\n"}
            "/proc/self/mountinfo" -> {:ok, mountinfo("/", @mount, "cgroup2", "rw")}
            _ -> flunk("unexpected path: #{path}")
          end
        end
      )

    assert snapshot.fallback?
    assert_receive {:read, "/proc/meminfo"}
    assert_receive {:read, "/proc/self/cgroup"}
    refute_receive {:read, "/etc/memory.max"}
  end

  test "mount traversal and mismatched roots are rejected" do
    for {root, mount} <- [{"/", "/sys/../etc"}, {"/another", @mount}] do
      snapshot =
        linux(%{
          "/proc/self/cgroup" => "0::/app\n",
          "/proc/self/mountinfo" => mountinfo(root, mount, "cgroup2", "rw")
        })

      assert snapshot.fallback?
    end
  end

  test "mountinfo escaped whitespace is decoded without escaping its root" do
    snapshot =
      linux(%{
        "/proc/self/cgroup" => "0::/app\n",
        "/proc/self/mountinfo" => mountinfo("/", "/budget\\040space", "cgroup2", "rw"),
        "/budget space/app/memory.max" => Integer.to_string(@gib)
      })

    assert snapshot.capacity == @gib
  end

  test "bad physical memory including overflow selects fallback" do
    for value <- [
          "",
          "MemFree: 8388608 kB",
          "MemTotal: -2 kB",
          "MemTotal: 0 kB",
          "MemTotal: 18446744073709551615 kB"
        ] do
      snapshot = linux(%{"/proc/meminfo" => value})
      assert snapshot.fallback?
      assert snapshot.capacity == nil
      assert :physical_memory_unavailable in snapshot.reasons
    end
  end

  test "physical read failure does not turn a cgroup limit into invented host capacity" do
    snapshot =
      v2("/app", %{
        "/proc/meminfo" => {:error, :enoent},
        "/app/memory.max" => Integer.to_string(@gib)
      })

    assert snapshot.fallback?
    assert snapshot.physical_bytes == nil
  end

  test "macOS uses an injected physical hw.memsize result" do
    assert %{capacity: capacity, source: :darwin, fallback?: false} =
             SystemMemory.detect(
               platform: {:unix, :darwin},
               native: fn :darwin -> {:ok, "17179869184\n"} end
             )

    assert capacity == 16 * @gib
  end

  test "Windows uses an injected physical capacity result" do
    assert %{capacity: capacity, source: :windows, fallback?: false} =
             SystemMemory.detect(
               platform: {:win32, :nt},
               native: fn :windows -> {:ok, 32 * @gib} end
             )

    assert capacity == 32 * @gib
  end

  test "native detection failures and malformed output select fallback" do
    for result <- [{:error, :timeout}, {:ok, "total=4096"}, {:ok, @maximum + 1}, {:ok, 1}] do
      snapshot = SystemMemory.detect(platform: {:unix, :darwin}, native: fn :darwin -> result end)
      assert snapshot.fallback?
      assert :physical_memory_unavailable in snapshot.reasons
    end
  end

  test "unsupported platforms use a structured fallback" do
    snapshot = SystemMemory.detect(platform: {:unix, :unknown})

    assert %{
             capacity: nil,
             physical_bytes: nil,
             cgroup_limit_bytes: nil,
             source: :fallback,
             fallback?: true,
             metadata: %{}
           } = snapshot

    assert :unsupported_platform in snapshot.reasons
  end

  test "pure selection uses the smallest reliable capacity and retains metadata" do
    snapshot =
      SystemMemory.select(8 * @gib, [:unlimited, 2 * @gib, 4 * @gib], %{
        source: :linux,
        controller: :v2
      })

    assert snapshot.capacity == 2 * @gib
    assert snapshot.physical_bytes == 8 * @gib
    assert snapshot.metadata.controller == :v2
  end

  test "pure selection refuses invalid values and accepts the finite domain boundaries" do
    for invalid <- [nil, 0, 1, -1, @maximum + 1, :infinity] do
      assert SystemMemory.select(invalid, []).fallback?
      assert SystemMemory.select(8 * @gib, [invalid]).fallback?
    end

    assert SystemMemory.select(2, []).capacity == 2
    assert SystemMemory.select(@maximum, []).capacity == @maximum
  end

  defp podman_mounts do
    [
      "1488 1486 0:21 /../../../../../.. #{@mount} rw,nosuid,nodev,noexec,relatime - cgroup2 cgroup2 rw,nsdelegate,memory_recursiveprot,memory_hugetlb_accounting",
      "1507 1488 0:124 / #{@mount} rw,relatime - tmpfs tmpfs rw,size=4k,nr_inodes=1,uid=1000,gid=100",
      "1508 1507 0:21 / #{@mount} ro,nosuid,nodev,noexec,relatime - cgroup2 cgroup2 rw,nsdelegate,memory_recursiveprot,memory_hugetlb_accounting"
    ]
  end

  defp mounted_memory(rows, extra \\ %{}) do
    files =
      Map.merge(
        %{
          "/proc/meminfo" => "MemTotal: 8388608 kB\nMemAvailable: 4194304 kB\n",
          "/proc/self/cgroup" => "0::/\n",
          "/proc/self/mountinfo" => Enum.join(rows, "\n") <> "\n",
          (@mount <> "/memory.max") => Integer.to_string(@gib),
          (@mount <> "/memory.current") => Integer.to_string(div(@gib, 4)),
          (@mount <> "/memory.high") => "max"
        },
        extra
      )

    read = fn path ->
      case Map.get(files, path) do
        value when is_binary(value) -> {:ok, value}
        _ -> {:error, :enoent}
      end
    end

    detection = SystemMemory.detect(platform: {:unix, :linux}, read_file: read)

    {detection,
     Gaoxy.ResourceBudget.Safety.detect(detection,
       platform: {:unix, :linux},
       read_file: read,
       now: fn -> 1000 end
     )}
  end

  defp linux(files) do
    files =
      Map.merge(
        %{
          "/proc/meminfo" => "MemTotal: 8388608 kB\nMemAvailable: 1 kB\n",
          "/proc/self/cgroup" => "",
          "/proc/self/mountinfo" => ""
        },
        files
      )

    SystemMemory.detect(
      platform: {:unix, :linux},
      read_file: fn path ->
        case Map.get(files, path) do
          value when is_binary(value) -> {:ok, value}
          {:error, _} = error -> error
          nil -> {:error, :enoent}
        end
      end
    )
  end

  defp v2(path, entries) do
    files =
      Map.new(entries, fn
        {"/proc/" <> _ = key, value} -> {key, value}
        {key, value} -> {@mount <> key, value}
      end)
      |> Map.put("/proc/self/cgroup", "0::#{path}\n")
      |> Map.put("/proc/self/mountinfo", mountinfo("/", @mount, "cgroup2", "rw"))

    linux(files)
  end

  defp v1(value), do: v1(value, if(is_binary(value), do: "hierarchical_memory_limit #{value}\n"))

  defp v1(value, stat) do
    linux(%{
      "/proc/self/cgroup" => "3:memory:/\n",
      "/proc/self/mountinfo" => mountinfo("/", @mount, "cgroup", "rw,memory"),
      (@mount <> "/memory.limit_in_bytes") => value,
      (@mount <> "/memory.stat") => stat
    })
  end

  defp mountinfo(root, mount, type, options),
    do: "30 20 0:26 #{root} #{mount} rw,nosuid,nodev - #{type} cgroup #{options}\n"
end
