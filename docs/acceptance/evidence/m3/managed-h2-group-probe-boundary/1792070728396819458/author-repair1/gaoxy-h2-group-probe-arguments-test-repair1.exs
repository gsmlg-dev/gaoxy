defmodule Gaoxy.Proxy.ManagedH2GroupProbeArgumentsTest do
  use ExUnit.Case, async: true

  alias Gaoxy.Proxy.{HTTPFetchClient, ManagedH2Client, UpstreamGroups}
  @normal_keys [:owner, :token, :member, :deadline, :health, :url]
  @selected_keys [:id, :config, :max_inflight]
  @health_keys [
    :path,
    :interval,
    :timeout,
    :stale_after,
    :failure_threshold,
    :recovery_threshold,
    :jitter
  ]
  @group_keys [
    :provider,
    :owner,
    :owner_epoch,
    :group,
    :generation,
    :max_url_bytes,
    :transports,
    :execution_profile
  ]
  @recovery_keys [:owner, :recovery, :completion, :deadline]
  @signed_min -9_223_372_036_854_775_808
  @signed_max 9_223_372_036_854_775_807

  test "new owner-produced H1 has exactly six original arguments and a Selected3 member" do
    args = fixture(:http1)
    assert Enum.sort(Map.keys(args)) == Enum.sort(@normal_keys)
    assert Enum.sort(Map.keys(args.member)) == Enum.sort(@selected_keys)
    assert {:ok, returned} = start(args)
    assert returned === args
    assert returned.member.config.client === HTTPFetchClient
  end

  test "H1 preserves existing path query acceptance and binary backing rather than H2 compact restrictions" do
    args = fixture(:http1)
    path = slice("/health?query=%2f" <> :binary.copy("p", 80), 4_096)
    id = slice(:binary.copy("i", 100), 4_096)
    url = slice(root(args) <> path, 4_096)

    args = %{
      args
      | member: %{args.member | id: id},
        health: %{args.health | path: path},
        url: url
    }

    assert :binary.referenced_byte_size(path) > byte_size(path)
    assert :binary.referenced_byte_size(id) > byte_size(id)
    assert :binary.referenced_byte_size(url) > byte_size(url)
    assert {:ok, returned} = start(args)
    assert returned === args

    assert :binary.referenced_byte_size(returned.health.path) ==
             :binary.referenced_byte_size(path)

    assert :binary.referenced_byte_size(returned.url) == :binary.referenced_byte_size(url)
  end

  test "H1 retains supported limits and integer deadline outside new H2 finite caps" do
    args = fixture(:http1)

    config = %{
      args.member.config
      | limits: %{limits() | opening_timeout: 86_400_001, max_lifetime: 86_400_001}
    }

    for deadline <- [@signed_min - 1, @signed_max + 1, -1, 0] do
      input = %{args | member: %{args.member | config: config}, deadline: deadline}
      assert {:ok, returned} = start(input)
      assert returned === input
    end
  end

  test "H1 preserves supported dedicated and managed transport configurations" do
    args = fixture(:http1)

    for handle <- [nil, transport()] do
      input = %{args | member: %{args.member | config: %{args.member.config | transport: handle}}}
      assert {:ok, returned} = start(input)
      assert returned === input
    end
  end

  test "normal constructors reject nonmaps missing keys extra keys and struct payloads" do
    for protocol <- [:http1, :http2, :h2c] do
      args = fixture(protocol)

      for bad <- [
            nil,
            [],
            :args,
            %{},
            Map.put(args, :extra, fn -> :opaque end),
            Map.put(args, :__struct__, URI)
          ] do
        reject(bad)
      end

      for key <- Map.keys(args), do: reject(Map.delete(args, key))
      if protocol == :http1, do: reject(Map.put(args, :group, group(transport())))
    end
  end

  test "normal owner and token must be PID and reference originals" do
    for protocol <- [:http1, :http2, :h2c] do
      args = fixture(protocol)
      for owner <- [nil, make_ref(), :owner, 1], do: reject(%{args | owner: owner})
      for token <- [nil, self(), :token, 1], do: reject(%{args | token: token})
    end
  end

  test "strict owner constructor rejects expanded members without changing legacy direct-init contract" do
    for protocol <- [:http1, :http2, :h2c] do
      args = fixture(protocol)

      expanded =
        Map.merge(args.member, %{
          checked: nil,
          failures: 0,
          successes: 0,
          inflight: 0,
          probe: nil,
          due: 0,
          health: :unknown
        })

      for member <- [
            nil,
            [],
            %{},
            args.member.config,
            %{config: args.member.config},
            expanded,
            Map.put(args.member, :extra, fn -> :opaque end),
            Map.put(args.member, :__struct__, URI)
          ] do
        reject(%{args | member: member})
      end

      for key <- @selected_keys, do: reject(%{args | member: Map.delete(args.member, key)})
    end

    # These strict producer checks are not calls to legacy Probe.init/1. Its
    # member-only-config/health-only-timeout/optional-deadline compatibility is
    # independently preserved by the unchanged clause and Probe identity tests.
  end

  test "H1 strict owner input requires its existing HTTP config client and complete health" do
    args = fixture(:http1)

    for config <- [
          nil,
          [],
          Map.from_struct(args.member.config),
          %{args.member.config | client: ManagedH2Client},
          Map.put(args.member.config, :extra, [])
        ] do
      reject(%{args | member: %{args.member | config: config}})
    end

    for health <- [nil, [], %{timeout: 2_000}, Map.put(args.health, :extra, [])] do
      reject(%{args | health: health})
    end

    for deadline <- [nil, 1.0, :infinity], do: reject(%{args | deadline: deadline})
    for url <- [nil, [], :url], do: reject(%{args | url: url})
  end

  test "H1 strict owner input preserves existing member and health logical bounds" do
    args = fixture(:http1)

    for id <- ["i", :binary.copy("i", 128)], count <- [1, 1_024] do
      input = %{args | member: %{args.member | id: id, max_inflight: count}}
      assert {:ok, ^input} = start(input)
    end

    for id <- [nil, 1, "", :binary.copy("i", 129)],
        do: reject(%{args | member: %{args.member | id: id}})

    for count <- [nil, 0, 1_025, 1.0, :infinity],
        do: reject(%{args | member: %{args.member | max_inflight: count}})

    for health <- [
          %{args.health | timeout: 5_001},
          %{args.health | interval: 0},
          %{args.health | jitter: -1},
          %{args.health | failure_threshold: 101},
          %{args.health | recovery_threshold: 101},
          %{args.health | stale_after: args.health.interval - 1}
        ] do
      reject(%{args | health: health})
    end

    for path <- ["", "health", "/a#", "/a\\", "/a b", "/%zz", "/" <> :binary.copy("p", 8_192)],
        do: reject(with_path(args, path))
  end

  test "both managed H2 protocols preserve exact seven-key arguments and supplied identities" do
    for protocol <- [:http2, :h2c] do
      args = fixture(protocol)
      assert Enum.sort(Map.keys(args)) == Enum.sort([:group | @normal_keys])
      assert Enum.sort(Map.keys(args.group)) == Enum.sort(@group_keys)
      assert Enum.sort(Map.keys(args.health)) == Enum.sort(@health_keys)
      assert :ok == Gaoxy.Proxy.ManagedH2Envelope.validate_config(args.member.config)
      assert {:ok, returned} = start(args)
      assert returned === args
      assert returned.owner === args.group.owner
      assert returned.member.config.transport === hd(args.group.transports)
    end
  end

  test "H2 intent cannot fall through to H1 compatibility when profile protocol or client disagrees" do
    args = fixture(:http2)
    legacy = fixture(:http1)

    for input <- [
          Map.delete(args, :group),
          %{args | group: %{args.group | execution_profile: :managed_h1}},
          %{
            args
            | member: %{args.member | config: %{args.member.config | upstream_protocol: :http1}}
          },
          %{
            args
            | member: %{args.member | config: %{args.member.config | client: HTTPFetchClient}}
          },
          Map.put(legacy, :group, args.group),
          %{
            legacy
            | member: %{legacy.member | config: %{legacy.member.config | client: ManagedH2Client}}
          }
        ] do
      reject(input)
    end
  end

  test "H2 Selected id and inflight bounds are inclusive compact and exact" do
    args = fixture(:http2)

    for id <- ["i", :binary.copy("i", 128)], count <- [1, 1_024] do
      input = %{args | member: %{args.member | id: id, max_inflight: count}}
      assert {:ok, ^input} = start(input)
    end

    for id <- [nil, 1, "", :binary.copy("i", 129), slice(:binary.copy("i", 100), 4_096)],
        do: reject(%{args | member: %{args.member | id: id}})

    for count <- [nil, 0, 1_025, 1.0, :infinity],
        do: reject(%{args | member: %{args.member | max_inflight: count}})
  end

  test "H2 configs require the complete accepted managed envelope including nonnil exact transport" do
    args = fixture(:http2)

    for config <- [
          nil,
          [],
          Map.from_struct(args.member.config),
          Map.put(args.member.config, :extra, []),
          %{args.member.config | transport: nil},
          %{args.member.config | transport: Map.put(args.member.config.transport, :extra, [])},
          %{args.member.config | cacertfile: "/tmp/ca"},
          %{args.member.config | connect_address: {127, 0, 0, 1}},
          %{args.member.config | uri: compact_uri("https://user@upstream.test")},
          %{args.member.config | uri: compact_uri("https://upstream.test/path")},
          %{args.member.config | upstream_protocol: :h2c}
        ] do
      reject(%{args | member: %{args.member | config: config}})
    end
  end

  test "H2 group is the exact finite profile shell coherent with owner" do
    args = fixture(:http2)

    for group <- [
          nil,
          [],
          %{},
          Map.put(args.group, :extra, []),
          Map.put(args.group, :__struct__, URI)
        ],
        do: reject(%{args | group: group})

    for key <- @group_keys, do: reject(%{args | group: Map.delete(args.group, key)})

    for change <- [
          %{provider: Gaoxy.Proxy.UpstreamTransports},
          %{owner: make_ref()},
          %{owner_epoch: self()},
          %{generation: nil},
          %{execution_profile: :managed_h1},
          %{execution_profile: "managed_h2"},
          %{group: ""},
          %{group: :group},
          %{group: :binary.copy("g", 129)},
          %{group: slice(:binary.copy("g", 100), 4_096)},
          %{max_url_bytes: 0},
          %{max_url_bytes: 8_193},
          %{max_url_bytes: 1.0}
        ] do
      reject(%{args | group: Map.merge(args.group, change)})
    end

    # PID-shaped but different owner is a coherence error; no process is spawned.
    alien_owner = :erlang.list_to_pid(~c"<0.32767.0>")
    refute alien_owner === self()
    reject(%{args | group: %{args.group | owner: alien_owner}})

    for id <- ["g", :binary.copy("g", 128)] do
      input = %{args | group: %{args.group | group: id}}
      assert {:ok, ^input} = start(input)
    end
  end

  test "H2 membership validates every exact transport and rejects duplicates improper and nonmember lists" do
    args = fixture(:http2)
    selected = args.member.config.transport

    for transports <- [
          nil,
          [],
          [selected | :improper],
          [selected, selected],
          [selected, nil],
          [selected, Map.put(selected, :extra, [])],
          [selected, %{selected | provider: UpstreamGroups}],
          [selected, %{selected | owner: make_ref()}],
          [selected, %{selected | owner_epoch: nil}],
          [selected, %{selected | resource: self()}],
          [transport()]
        ] do
      reject(%{args | group: %{args.group | transports: transports}})
    end

    for key <- Map.keys(selected) do
      reject(%{args | group: %{args.group | transports: [selected, Map.delete(selected, key)]}})
    end

    changed = %{
      args
      | member: %{
          args.member
          | config: %{args.member.config | transport: %{selected | owner_epoch: make_ref()}}
        }
    }

    reject(changed)
  end

  test "H2 accepts both unique supplied orders without sorting or authority inference" do
    args = fixture(:http2)
    selected = args.member.config.transport
    other = transport()

    for handles <- [[selected, other], [other, selected]] do
      input = %{args | group: %{args.group | transports: handles}}
      assert {:ok, returned} = start(input)
      assert returned === input
      assert returned.group.transports === handles
    end
  end

  test "H2 maximal transport manifest satisfies full flattened resource caps" do
    args = fixture(:http2)
    handles = [args.member.config.transport | Enum.map(1..31, fn _ -> transport() end)]
    input = %{args | group: %{args.group | group: :binary.copy("g", 128), transports: handles}}
    flattened = [input.group | handles]
    assert length(flattened) == 33
    assert :erlang.external_size(flattened) <= 65_536
    assert {:ok, ^flattened} = Gaoxy.HTTP.Resources.validate(flattened)
    assert {:ok, ^input} = start(input)
    reject(%{input | group: %{input.group | transports: handles ++ [transport()]}})
  end

  test "H2 health requires exactly seven scalar fields before retaining inputs" do
    args = fixture(:http2)

    for health <- [
          nil,
          [],
          %{},
          %{timeout: 2_000},
          Map.put(args.health, :extra, fn -> :opaque end),
          Map.put(args.health, :__struct__, URI)
        ],
        do: reject(%{args | health: health})

    for key <- @health_keys, do: reject(%{args | health: Map.delete(args.health, key)})

    for key <- @health_keys -- [:path],
        value <- [nil, 1.0, :infinity, fn -> :opaque end, [], 3_600_001] do
      reject(%{args | health: Map.put(args.health, key, value)})
    end
  end

  test "H2 health finite bounds timeout thresholds and staleness relation are inclusive" do
    args = fixture(:http2)

    for health <- [
          %{
            args.health
            | interval: 1,
              timeout: 1,
              stale_after: 1,
              failure_threshold: 1,
              recovery_threshold: 1,
              jitter: 0
          },
          %{
            args.health
            | interval: 3_600_000,
              stale_after: 3_600_000,
              timeout: 5_000,
              failure_threshold: 100,
              recovery_threshold: 100,
              jitter: 3_600_000
          }
        ] do
      input = %{args | health: health}
      assert {:ok, ^input} = start(input)
    end

    for key <- @health_keys -- [:path, :jitter],
        do: reject(%{args | health: Map.put(args.health, key, 0)})

    for change <- [
          %{jitter: -1},
          %{timeout: 5_001},
          %{failure_threshold: 101},
          %{recovery_threshold: 101},
          %{stale_after: args.health.interval - 1}
        ] do
      reject(%{args | health: Map.merge(args.health, change)})
    end
  end

  test "H2 compact health path accepts raw escaped bytes and rejects query fragment whitespace invalid escapes" do
    args = fixture(:http2)

    for path <- [
          "/",
          "/a%2fb%2F",
          "//health",
          "/a!$&'()*+,;=:@",
          :binary.copy("/" <> :binary.copy("p", 8_191))
        ] do
      input = with_path(args, path)
      assert {:ok, ^input} = start(input)
    end

    for path <- [
          nil,
          1,
          "",
          "health",
          "/?",
          "/a?x=1",
          "/a#",
          "/a\\",
          "/a b",
          "/a\t",
          "/a\n",
          "/a" <> <<127>>,
          "/a" <> <<128>>,
          "/%",
          "/%a",
          "/%zz",
          "/" <> :binary.copy("p", 8_192),
          slice("/" <> :binary.copy("p", 99), 4_096)
        ] do
      reject(with_path(args, path))
    end
  end

  test "H2 URL is compact exact original raw root plus path without canonicalization" do
    for protocol <- [:http2, :h2c] do
      args = fixture(protocol)
      scheme = if protocol == :http2, do: "https", else: "http"
      port = if protocol == :http2, do: "443", else: "80"
      config = %{args.member.config | uri: compact_uri(scheme <> "://UPSTREAM.test:000" <> port)}
      args = %{args | member: %{args.member | config: config}}
      input = with_path(args, "/a%2fb%2F")
      assert {:ok, returned} = start(input)
      assert returned === input
      reject(%{input | url: scheme <> "://upstream.test" <> input.health.path})
      backed = with_path(input, :binary.copy("/" <> :binary.copy("p", 99)))
      backed_url = slice(backed.url, 4_096)
      assert :binary.referenced_byte_size(backed_url) > byte_size(backed_url)
      reject(%{backed | url: backed_url})

      for url <- [
            nil,
            [],
            :url,
            input.url <> "/",
            root(input),
            "https://other.test" <> input.health.path
          ],
          do: reject(%{input | url: url})
    end
  end

  test "H2 root actual advertised and joined URL bounds are checked independently" do
    args = fixture(:http2)
    bytes = byte_size(root(args))
    exact = %{args | group: %{args.group | max_url_bytes: bytes}}
    assert {:ok, ^exact} = start(exact)
    reject(%{args | group: %{args.group | max_url_bytes: bytes - 1}})
    config = %{args.member.config | uri: compact_uri(raw_port_origin(8_192))}

    maximal =
      with_path(
        %{args | member: %{args.member | config: config}},
        :binary.copy("/" <> :binary.copy("p", 8_191))
      )

    assert byte_size(maximal.url) == 16_384
    assert byte_size(maximal.url) <= 65_536
    assert maximal.group.max_url_bytes + byte_size(maximal.health.path) <= 65_536
    assert {:ok, ^maximal} = start(maximal)
    reject(%{maximal | group: %{maximal.group | max_url_bytes: 8_191}})

    over =
      with_path(
        %{
          args
          | member: %{args.member | config: %{config | uri: compact_uri(raw_port_origin(8_193))}}
        },
        "/"
      )

    assert :ok == Gaoxy.Proxy.ManagedH2Envelope.validate_config(over.member.config)
    reject(over)
    # Health/root each cap at8192; no valid constructor can reach65536.
    # Exceeding joined/advertised65536 necessarily also violates a tighter cap.
    reject(%{args | url: :binary.copy("u", 65_537)})
  end

  test "H2 config finite limits retain exact accepted caps and reject missing extra or unbounded values" do
    args = fixture(:http2)

    for key <- Map.keys(limits()) do
      cap = if key == :max_chunk_bytes, do: 65_536, else: 86_400_000

      for value <- [1, cap] do
        input = %{
          args
          | member: %{
              args.member
              | config: %{args.member.config | limits: Map.put(limits(), key, value)}
            }
        }

        assert {:ok, ^input} = start(input)
      end

      for value <- [0, cap + 1, nil, 1.0, :infinity],
          do:
            reject(%{
              args
              | member: %{
                  args.member
                  | config: %{args.member.config | limits: Map.put(limits(), key, value)}
                }
            })

      reject(%{
        args
        | member: %{
            args.member
            | config: %{args.member.config | limits: Map.delete(limits(), key)}
          }
      })
    end

    for bad <- [nil, [], Map.put(limits(), :extra, 1)],
        do: reject(%{args | member: %{args.member | config: %{args.member.config | limits: bad}}})
  end

  test "H2 deadline is signed64 with cleanup headroom and retains valid expired originals" do
    args = fixture(:http2)

    for deadline <- [@signed_min, -1, 0, 1, @signed_max - 1_000] do
      input = %{args | deadline: deadline}
      assert {:ok, returned} = start(input)
      assert returned === input
      assert returned.deadline === deadline
    end

    for deadline <- [
          nil,
          1.0,
          :infinity,
          @signed_min - 1,
          @signed_max + 1,
          @signed_max - 999,
          @signed_max
        ] do
      reject(%{args | deadline: deadline})
    end
  end

  test "recovery preserves exactly four keys both kinds and supported original opaque completion" do
    for kind <- [:selection, :probe] do
      args = recovery(kind)
      assert Enum.sort(Map.keys(args)) == Enum.sort(@recovery_keys)
      assert {:ok, returned} = recover(args)
      assert returned === args
      assert returned.completion === args.completion
      assert returned.recovery === args.recovery
      assert returned.deadline === args.deadline
    end
  end

  test "recovery exact shell does not inspect serialize or reconstruct completion interiors" do
    opaque = fn -> raise "opaque completion interiors must never be evaluated" end

    original = %HTTP.RequestCompletion{
      tracker: opaque,
      latch: [make_ref() | :opaque_tail],
      unsupported: %{opaque: opaque}
    }

    args = %{recovery(:probe) | completion: original}
    assert {:ok, returned} = recover(args)
    assert returned === args
    assert returned.completion === original
    # This establishes shell transfer only; it makes no claim that await/abort
    # accepts or successfully completes such an opaque capability.
  end

  test "recovery rejects omitted extra and normal H2 client URL health payloads" do
    args = recovery(:probe)
    for bad <- [nil, [], :args, %{}, Map.put(args, :__struct__, URI)], do: reject_recovery(bad)
    for key <- @recovery_keys, do: reject_recovery(Map.delete(args, key))

    for {key, payload} <- [
          extra: fn -> :opaque end,
          member: fixture(:http2).member,
          group: fixture(:http2).group,
          client: ManagedH2Client,
          url: "https://upstream.test/",
          health: health(),
          request: %{}
        ] do
      reject_recovery(Map.put(args, key, payload))
    end
  end

  test "recovery rejects invalid owner kind token and completion shell without traversing payloads" do
    args = recovery(:probe)
    for owner <- [nil, make_ref(), :owner, 1], do: reject_recovery(%{args | owner: owner})

    for value <- [
          nil,
          [],
          :probe,
          {:other, make_ref()},
          {:probe, nil},
          {:selection, self()},
          {:probe, make_ref(), :extra}
        ],
        do: reject_recovery(%{args | recovery: value})

    completion = args.completion

    for bad <- [
          nil,
          [],
          %{},
          Map.from_struct(completion),
          Map.put(completion, :extra, fn -> :opaque end),
          %{completion | __struct__: HTTP.Promise}
        ],
        do: reject_recovery(%{args | completion: bad})

    for key <- Map.keys(completion),
        do: reject_recovery(%{args | completion: Map.delete(completion, key)})
  end

  test "recovery signed64 deadline preserves expired values and does not add normal cleanup headroom" do
    args = recovery(:selection)

    for deadline <- [@signed_min, -1, 0, 1, @signed_max] do
      input = %{args | deadline: deadline}
      assert {:ok, returned} = recover(input)
      assert returned === input
      assert returned.deadline === deadline
    end

    for deadline <- [nil, 1.0, :infinity, @signed_min - 1, @signed_max + 1],
        do: reject_recovery(%{args | deadline: deadline})
  end

  defp start(args), do: apply(UpstreamGroups, :probe_start_arguments, [args])
  defp recover(args), do: apply(UpstreamGroups, :probe_recovery_arguments, [args])
  defp reject(args), do: assert({:error, :invalid_probe_arguments} == start(args))
  defp reject_recovery(args), do: assert({:error, :invalid_probe_arguments} == recover(args))

  defp fixture(protocol) do
    transport = if protocol == :http1, do: nil, else: transport()
    scheme = if protocol == :http2, do: "https", else: "http"

    config = %Gaoxy.Proxy.HTTP{
      uri: compact_uri(scheme <> "://upstream.test"),
      upstream_protocol: protocol,
      client: if(protocol == :http1, do: HTTPFetchClient, else: ManagedH2Client),
      transport: transport,
      limits: limits(),
      cacertfile: nil,
      connect_address: nil
    }

    args = %{
      owner: self(),
      token: make_ref(),
      member: %{id: "member", config: config, max_inflight: 1},
      deadline: 12_000,
      health: health(),
      url: :binary.copy(scheme <> "://upstream.test/health")
    }

    if protocol == :http1, do: args, else: Map.put(args, :group, group(transport))
  end

  defp health,
    do: %{
      path: "/health",
      interval: 5_000,
      timeout: 2_000,
      stale_after: 15_000,
      failure_threshold: 3,
      recovery_threshold: 2,
      jitter: 500
    }

  defp limits,
    do: %{
      max_chunk_bytes: 65_536,
      opening_timeout: 5_000,
      idle_timeout: 60_000,
      write_timeout: 3_000,
      max_lifetime: 30_000
    }

  defp transport,
    do: %{
      provider: Gaoxy.Proxy.UpstreamTransports,
      owner: self(),
      owner_epoch: make_ref(),
      resource: make_ref()
    }

  defp group(transport),
    do: %{
      provider: UpstreamGroups,
      owner: self(),
      owner_epoch: make_ref(),
      group: "group",
      generation: make_ref(),
      max_url_bytes: 8_192,
      transports: [transport],
      execution_profile: :managed_h2
    }

  defp recovery(kind),
    do: %{
      owner: self(),
      recovery: {kind, make_ref()},
      completion: %HTTP.RequestCompletion{tracker: self(), latch: make_ref(), unsupported: nil},
      deadline: -1
    }

  defp root(args), do: args.member.config.uri.scheme <> "://" <> args.member.config.uri.authority

  defp with_path(args, path) when is_binary(path),
    do: %{args | health: %{args.health | path: path}, url: :binary.copy(root(args) <> path)}

  defp with_path(args, path), do: %{args | health: %{args.health | path: path}}

  defp compact_uri(value),
    do:
      Map.new(Map.to_list(URI.parse(value)), fn
        {key, value} when is_binary(value) -> {key, :binary.copy(value)}
        pair -> pair
      end)

  defp raw_port_origin(bytes) do
    prefix = "https://upstream.test:"
    :binary.copy(prefix <> :binary.copy("0", bytes - byte_size(prefix) - 3) <> "443")
  end

  defp slice(value, backing_bytes) do
    backing = :binary.copy(value <> :binary.copy("p", backing_bytes - byte_size(value)))
    binary_part(backing, 0, byte_size(value))
  end
end
