# Gaoxy 项目审查建议

- 审查对象:`main` @ `47187fc6`(v0.16.2),2026-11-13
- 范围:`apps/*/lib`(约 46,600 行)、测试结构、CI 工作流、脚本、文档与仓库卫生
- 方法:只读审查。所有结论来自阅读代码路径,**没有运行测试、没有在运行时复现任何一条**。标 ✔ 的条目我另外逐行核对过所引用的代码;其余条目由分模块审查得出,修复前建议先写复现用例。性能数字均为按代码推算,未实测。
- 未覆盖:`listener_set*`、`router.ex`、Phoenix 适配器、`gateway/coordinator.ex` 与 `gateway/supervisor.ex`、`managed_h2_envelope.ex` / `managed_h2_preparation.ex` / `managed_h2_client.ex` 的细节、`system_memory.ex` 的 cgroup 逻辑、`integration/` 与 `examples/`。

## 修复进度

| 项 | 状态 | 说明 |
| --- | --- | --- |
| D2 | 已完成 | AGENTS.md 重写,旧文件归档到 `docs/history/agents-instructions-2026-10.md` |
| D3 | 已完成 | `docs/acceptance` 不再追踪,已加入 `.gitignore`(历史提交中仍保留) |
| P5 | 等待上游 | [gsmlg-dev/http_fetch#170](https://github.com/gsmlg-dev/http_fetch/issues/170) |
| C6 | 已修复 | 完成一帧(或一个 CONTINUATION 头块)即清除 partial 定时器;新增 `http2_partial_frame_progress_test.exs`(修复前 300 ms 后连接被关闭) |
| C9 | 已修复 | 未注册状态码用空 reason phrase;实测修复前原生 endpoint 返回 599/499 时连接被直接关闭、无任何响应;新增 `http1_unregistered_status_network_test.exs` |
| C8 | 不成立 | 实测 drain 后 last-stream-id 之上的流既不被应答也不被 endpoint 执行(5 轮,执行数恒等于应答数);未改产品代码,`http2_drain_goaway_test.exs` 留作不变量守护 |
| S2 | 已修复 | forward 代理路径不再追加 `X-Forwarded-*`(仍剥离入站的);`forward_http_test.exs` 增加断言 |
| T1(第 1 步) | 已完成 | `forward_http_test.exs`(protocol,8 例)与 `destination_policy_test.exs`(component,8 例)纳入门禁;前者有一个过期用例(TLS listener 默认启用 H2 后 32 MB 预算不足),已将该用例固定为 `protocols: [:http1]` |
| C10 | 暂不处理 | 复核后发现 `QUICBridge` 在 gate 无法为回调提供资金时同样跳过 `terminate/2`,这是既定设计;StreamBridge 的差别只是以 MatchError 崩溃而不是静默返回 |
| C1 | 已修复 | 终结重试改为 single-flight;复现测试中 5 个终结项在 150 ms 内触发 155 次全量 sweep,修复后在上限内 |
| S1 | 已修复 | 对端在存活流上诱发的重置计入 `control_rate`;新增 `http2_peer_reset_rate_test.exs`(protocol 套件,2 例) |

以上已修复的条目随 0.16.3 发布(见 `docs/releases/0.16.3.md`);修复经过一次独立只读复核,复核提出的 C1 残余放大和四处测试弱点已处理。

## 先看这些

| # | 问题 | 类别 | 优先级 | 工作量 |
| --- | --- | --- | --- | --- |
| [S1](#s1) | H2 服务端代发的 RST 不计入速率限制(MadeYouReset 类) | 安全 | High | S |
| [C1](#c1) | 预算挂起期间终结重试 sweep 成倍增长 | 正确性 | High | S |
| [C2](#c2) | 一次 50 ms gate 超时会永久摘掉 listener | 正确性 | High | M |
| [C4](#c4) | 未 bind 的 transport checkout 会永久 retire 整个 transport | 正确性 | High | 1–2 天 |
| [C5](#c5) | guardian/探针在 bind 前退出会让整个 group 永久失败并耗尽探针名额 | 正确性 | High | 1–2 天 |
| [C6](#c6) | H2 partial-frame 定时器在有进展时不重置 | 正确性 | High | S |
| [P1](#p1) | StreamRelay 轮流 5 ms 阻塞 recv,单向吞吐被封顶 | 性能 | High | 1–2 天 |
| [A1](#a1) | `ManagedH2GroupAccounting` 是运行时断言而不是账本 | 架构 | High | 3–5 天 |
| [T1](#t1) | 269 个测试文件中 143 个不在任何自动门禁里 | 测试 | High | 1–2 天起 |

贯穿多条发现的三个共同模式:

1. **fail-closed 的隔离状态是终态、且不可见。** C2、C3、C4、C5、C11 都是"遇到不确定就永久关闭",但没有恢复路径,也没有日志或 telemetry。
2. **用毫秒级轮询代替事件。** P1、P5、P7、P9、P13 都是 1–10 ms 定时轮询,既限制吞吐也空耗 CPU。
3. **单进程串行枢纽。** 每个 service 一个 Admission gate、全 VM 一个 Authority/Ledger、一个 `Generation.Store`、两个 upstream owner;热路径上每个 chunk/frame 都要同步调用它们(P2、P3、P4、P6、P8)。它们变慢又正是 C1、C2、C12 的触发条件。

---

## 1. 代码质量与正确性

### 正确性缺陷

<a id="c1"></a>
#### C1 ✔ 终结重试 sweep 没有 single-flight,预算挂起时成倍增长 — High / S

[admission.ex:1258-1263](apps/gaoxy/lib/gaoxy/admission.ex#L1258-L1263)、[admission.ex:1773-1776](apps/gaoxy/lib/gaoxy/admission.ex#L1773-L1776)、[budget.ex:33-34](apps/gaoxy/lib/gaoxy/admission/budget.ex#L33-L34)

```elixir
def handle_info(:budget_retry_terminals, state) do
  state = Enum.reduce(Map.keys(state.spawns), state, &settle_spawn(&2, &1))
  state = Enum.reduce(Map.keys(state.leases), state, &settle_lease(&2, &1))
  ...
defp terminal_result({:error, :budget_pending, state}) do
  Process.send_after(self(), :budget_retry_terminals, 10)
```

`state.budget.pending` 存在时,一次 sweep 里每个终结项都拿到 `:budget_pending` 并各自再排一次全量 sweep。K 个终结项 → K 次 sweep → 每次又排 K 次。Authority 调用持续超时(50 ms 上限、10 ms 重试)时积压呈指数增长,pending 清除后积压仍在。

**建议**:加 `retry_scheduled` 标志保证最多一个待处理 sweep;更好的做法是维护"等待释放的 ref 集合",在 `Budget.finish/4` 清除 pending 时只结算这些。

<a id="c2"></a>
#### C2 ✔ 一次 50 ms gate 超时或一个 guardian 崩溃会永久摘掉 listener — High / M

[service.ex:1060-1066](apps/gaoxy/lib/gaoxy/service.ex#L1060-L1066),另见 261-262、309-311、323-326、839-862

```elixir
defp fail_gate(state) do
  state = if state.drain, do: state, else: start_drain(state, Lifecycle.now(), [])
  state |> force_drain({:cleanup_failed, :admission_unavailable}) |> transition(:failed)
end
defp gate_mode(state, mode),
  do: Lifecycle.protect(fn -> GenServer.call(state.gate, {:mode, mode}, 50) end)
```

`attach_cleanup` / `complete_cleanup` / `pause` / `resume` 都是 50 ms 超时的 `GenServer.call`,且 proxy 每个会话都会调用 `Service.attach_cleanup`([http.ex:660](apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex#L660))。gate 回复慢一次 → `fail_gate` → `force_drain` 杀掉所有连接 → `finish_drain` 以 `:normal` 停止;子进程是 `restart: :transient`,**不会重启**。唯一信号是一条 telemetry。ADR 004 说明了 pause/resume 不确定时 fail-closed,但看不出本意是"一次请求的记账超时让整个服务下线"。

**建议**:调用超时只视为该 cleanup 的不确定状态,按 token 对账;`fail_gate` 仅用于 gate 真正死亡;guardian 失败只失败所属连接。若确实要整服务拆除,用非 normal 原因停止让 supervisor 重启,并打 error 日志。

<a id="c3"></a>
#### C3 ✔ 孤儿 ledger charge 永不回收 — High/Medium / M–L

[reconciler.ex:93-130](apps/gaoxy/lib/gaoxy/admission/reconciler.ex#L93-L130)、[ledger.ex:113-116](apps/gaoxy/lib/gaoxy/resource_budget/ledger.ex#L113-L116)、[ledger.ex:1052](apps/gaoxy/lib/gaoxy/resource_budget/ledger.ex#L1052)

`Reconciler.finish` 只在 `Service.terminate` 或 init 失败时跑一次(1 秒期限),遇到第一个无法确认的行就中止,后面的行和 service/gate 注册都保持扣费。Service 被 kill 时 `terminate` 根本不执行。Ledger 的 `state.dead` 集合只有写入(114、1052 行),全仓库没有读取点,尽管 Authority 的注释说它用于"之后对账孤儿"。泄漏的行会计入 VM 级硬上限,直到 VM 重启。

**建议**:加一个由 owner `DOWN` 驱动的孤儿回收器(用上 `dead` 集合);`finish` 跳过无法确认的行而不是中止;`terminate` 显式处理 `pid == self()` 的行。

<a id="c4"></a>
#### C4 ✔ 未 bind 的 transport checkout 会永久 retire 整个 transport — High / 1–2 天

[upstream_transports.ex:444-447](apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex#L444-L447)

```elixir
def handle_call({:finish, handle, token}, {caller, _}, state) do
  case request_hold(state, handle, token, caller) do
    {:ok, %{completion: nil} = hold} ->
      {:reply, {:error, :cleanup_unconfirmed}, retire_resource(state, hold.resource)}
```

这是测试钉住的预期行为,但普通时序就能触达,而且此时连接根本没建立:

- **Session deadline 竞争**:`open_selected` 在 checkout 返回之后才判断 `options.timeout <= 0`([session.ex:1203-1236](apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex#L1203-L1236));owner 过载时 checkout 回复落在 deadline 最后一毫秒即可触发。
- **同步 open 失败**:`ManagedH1Preparation.pairs_source` 每个字段计 32 字节,而前置的 `Headers.header_limit` 每字段只计 4 字节,两个公式不一致;`max_header_bytes` 调大后一个多头部请求就够。
- **探针取消窗口**:每次 reload 都会向探针发 `Probe.cancel`,落在 checkout 之后即走到同一分支([probe.ex:158-176](apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/probe.ex#L158-L176))。
- **回复丢失**:`checkout` 没有 operation ref(`pin_many` / `cancel` 有),调用方超时后 token 成为孤儿。

后果:custodian 把 retire 当 `:abort`,该 transport 上其他在途请求被中止,之后的 checkout 返回 `:resource_unavailable` 直到 reload。

**建议**:增加由 guardian 证明的 `UpstreamTransports.abandon(handle, token)`(仅当 `completion == nil` 且调用方是 guardian 时接受),只移除 token 不 retire;给 `checkout` 加 operation ref;把超时判断和 `prepare_request` 移到 checkout 之前,或统一两个头部大小公式。

<a id="c5"></a>
#### C5 ✔ guardian/探针在 bind 前退出会让整个 group 永久失败,并耗尽全局探针名额 — High / 1–2 天

[upstream_groups.ex:1279-1303](apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex#L1279-L1303)、[upstream_groups.ex:1162](apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex#L1162)

```elixir
defp recover_h1(state, kind, token, held) do
  if held.completion != nil do
    ...
  else
    put_in(state.groups[held.key].lifecycle, :failed)
```

- `:failed` 的 group 对 checkout 返回 `:unavailable`,`launch_probes` 只访问 `:active` group,所以一次 Session 或 Probe 退出就让整个 group generation 下线直到 reload。
- 死条目留在 `state.tokens` / `state.probes` 中(`monitor: nil`),没有定时器、sweep 或 reload 会清理它,连带泄漏 `max_groups` 名额。
- 死探针条目计入 `max_probes`(默认 4,[options.ex:19](apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/options.ex#L19))。四次这样的事件后**所有 group** 都不再发探针,15 秒后所有成员 stale,group 路由全部 503。owner 是 `restart: :temporary` 且跨 reload 存活,reload 也救不回来。
- 这几个模块里 Logger 和 telemetry 调用数为 0。

**建议**:group 失败时移除 token/probe 条目及其计数,只保留 `failed_reason`;死条目不计入 `max_probes`;每次 `:failed` / `:draining` 转换发 telemetry;考虑只让该成员失败并重新探测,而不是整代失败。

<a id="c6"></a>
#### C6 ✔ H2 partial-frame 定时器在有进展时不重置 — High / S

[http2/connection.ex:1954-1970](apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex#L1954-L1970)

```elixir
partial = not state.preface or state.continuation != nil or state.buffer != ""
cond do
  partial and state.partial_timer == nil -> ...arm frame_timeout...
  not partial and state.partial_timer != nil -> ...cancel...
  true -> state
end
```

定时器在某次投递首次停在帧中间时启动,只有当之后某次投递**恰好**停在帧边界时才取消;挂起的帧完成后紧跟另一个不完整帧时不会重置。连续 5 秒每次投递都停在帧中间的连接会被 `GOAWAY PROTOCOL_ERROR`,即使每一帧都及时到达。把帧合并到任意 socket 写入的 h2c 对端/代理、慢链路上传、或 owner 进程落后于 socket(即负载下)都可能命中。没有测试覆盖持续的帧中间投递。

**建议**:把定时器绑定到"当前挂起的那一帧"——`parse/2` 本轮只要消费了至少一个完整帧就取消并重新启动。

#### C7 H2 over TLS:一次投递超过 `max_buffer_bytes` 就静默关闭连接 — Medium / S–M

[http2/connection.ex:283-284](apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex#L283-L284)、[http2/limits.ex:4-7](apps/gaoxy_http/lib/gaoxy/http/http2/limits.ex#L4-L7)

TLS 引擎是 ex_ssl,它会缓冲最多 1 MiB 明文并一次性投递;默认上限是 65,536。合规对端把 65,535 字节窗口拆成四个 DATA 帧就是 65,571 字节。owner 忙时累积超限,连接不发 GOAWAY 直接断开。`Limits.validate_host/1` 和 `@max_delivery` 是按 OTP `:ssl` 的 `internal_active_n` 推导的,对 ex_ssl 不适用;`Limits.reservation/3` 却按 1.65 MB 投递预留,两处自相矛盾。

**建议**:增量解析投递,把上限施加在未解析的残留部分(小于 `max_frame + 9`);按 ex_ssl 的实际上界重新推导 `@max_delivery`。

#### C8 ~~H2 优雅 drain~~(2026-11-13 实测不成立,见修复进度)原文:H2 优雅 drain:GOAWAY 的 last-stream-id 不包含已接纳但未 dispatch 的流 — Medium / S

[http2/connection.ex:1528-1538](apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex#L1528-L1538),`accepted` 只在 [1624 行](apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex#L1624) 的 dispatch 中推进

已在 `state.streams` 但尚未 dispatch 的流 id 大于 `accepted`,GOAWAY 之后它们仍会被执行。按 RFC 9113 §6.8 客户端可以认为它们未被处理并在别处重试,所以**滚动重启期间一个 POST 可能执行两次**。

**建议**:通告 `max(accepted, state.streams 中最大 id)`,或 drain 时用 `REFUSED_STREAM` 重置未 dispatch 的流。

#### C9 ✔ H1 遇到未注册的状态码会抛异常变成 500 — Low–Medium / S

[http1/response.ex:351-353](apps/gaoxy_http/lib/gaoxy/http/http1/response.ex#L351-L353)

```elixir
reason = Plug.Conn.Status.reason_phrase(status)
```

`reason_phrase/1` 对 Plug 未编译进去的状态码抛 `ArgumentError`。Plug 或上游返回 299、499、520–530、599 时能通过 `validate_status`(200..599)但在 `head/3` 抛异常,客户端收到 500。同样的响应在 H2/H3 上正常。对反向代理来说这是实际会遇到的(Cloudflare 52x、nginx 499)。

**建议**:用带回退的 phrase 查找,未知码用空 reason phrase(RFC 9112 允许)。

#### C10 `StreamBridge.terminate_app` 在 gate 不健康时跳过用户的 `terminate/2` — Medium–Low / S

[stream_bridge.ex:231-236](apps/gaoxy/lib/gaoxy/stream_bridge.ex#L231-L236):`:ok = Admission.begin(...)` 在 gate 有挂起预算操作时匹配失败而抛异常,用户钩子恰好在系统降级时被跳过。`QUICBridge.terminate`([quic_bridge.ex:93-104](apps/gaoxy/lib/gaoxy/quic_bridge.ex#L93-L104))已经正确处理了这种情况,照它改即可。

#### C11 失败的 transport 和 custodian 累积到 reload 被拒绝 — Low–Medium / 1 天

[upstream_transports.ex:552-564](apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex#L552-L564):`:failed` 记录永不结算,custodian 存活且无定时器,各占一个 `max_resources`(64)名额;累积够多后 `prepare` 返回 `{:capacity, :resources}`,reload 失败直到网关重启。**建议**:`custodian_failed` 发 telemetry;加有界的慢速重查,或显式的运维"忘记失败资源"操作。

#### C12 group 调用的 100 ms 硬期限把 owner 延迟变成失败请求 — Medium / 0.5–1 天

[upstream_groups.ex:357-358](apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex#L357-L358):`bind_completion` / `finish` 用 `Lifecycle.deadline(100)`,而 transport owner 对同类操作用 1000 ms。owner 内的 `prepare` 重编译、P8 的线性扫描或一次 GC 暂停都足以超时;bind 超时会失败一个已经发出的上游请求。**建议**:finish/release 改为 cast + monitor 兜底,或使用请求自己的 cleanup deadline;把 `compile` 移出 owner。

#### C13 节点本地单例用了以 `node()` 为键的 `:global` 名称 — Low / S

[resource_budget/supervisor.ex:20](apps/gaoxy/lib/gaoxy/resource_budget/supervisor.ex#L20):如果宿主在应用启动后才 `Node.start/2`,`node()` 变化,`ResourceBudget.server()` 算出的名字从未注册,新实例得到 `:budget_unavailable`。`:global` 注册还会在每次重启时取集群级锁。**建议**:改用本地注册名或现有的 `Gaoxy.Registry`。(取决于宿主如何启动分布式,未验证实际影响。)

### 重复代码

| 重复内容 | 位置 | 已出现的分歧 |
| --- | --- | --- |
| hop-by-hop / 转发头策略 | [websocket.ex:30-32](apps/gaoxy_proxy/lib/gaoxy/proxy/websocket.ex#L30-L32) 对 [http/headers.ex:5-6](apps/gaoxy_proxy/lib/gaoxy/proxy/http/headers.ex#L5-L6) | WebSocket 副本缺少数量/大小预检和 token 校验;判定 scheme 的方式也不同 |
| 保留地址段表与 CIDR 运算 | [destination_policy.ex:17-42](apps/gaoxy_proxy/lib/gaoxy/proxy/destination_policy.ex#L17-L42) 对 [udp_relay/options.ex:197-259](apps/gaoxy_proxy/lib/gaoxy/proxy/udp_relay/options.ex#L197-L259) | UDP 副本缺 `224.0.0.0/4`、`240.0.0.0/4`、`fe80::/10`、`ff00::/8`,目前仅因另一处 `unicast?/1` 检查而安全。这是安全相关数据 |
| 禁止的 trailer 列表(4 处) | `http1/body.ex`、`http1/response.ex`、`renderer_bounds.ex`、`http2/headers.ex` | H1 请求副本更短:`cookie`、`set-cookie`、`cache-control` 等在 H1 被接受为请求 trailer,在 H2/H3 被拒绝 |
| H2 与 H3 请求头校验 | [http2/headers.ex](apps/gaoxy_http/lib/gaoxy/http/http2/headers.ex) 对 [http3/headers.ex](apps/gaoxy_http3/lib/gaoxy/http/http3/headers.ex) | 近乎逐行复制,只差错误元组形状和 scheme |
| H1 与 framed 响应的 content-length / 文件循环 | [http1/response.ex:185-216](apps/gaoxy_http/lib/gaoxy/http/http1/response.ex#L185-L216) 对 [framed_response.ex:124-164](apps/gaoxy_http/lib/gaoxy/http/framed_response.ex#L124-L164) | — |
| Session 与 Probe 各自实现一套 managed-open 流程 | `pin_group_transport`、`finish_transport`、`release_transport_pins`、`staged_group_options`、`finite_reason` 等在 `http/session.ex` 和 `upstream_groups/probe.ex` 各一份 | C4 的缺陷同时存在于两份副本 |
| `upstream_groups.ex` 内 H1/H2 成对函数 | `select_h1`/`select_h2`、`finish_h1_token`/`finish_h2_token`、`failed_health`/`failed_h2_health` 等 | H2 用 `min/2` 钳制计数器,H1 没有 |
| H1/H2 preparation | `managed_h1_preparation.ex` 对 `managed_h2_preparation.ex`(`canonical_policy`、`pairs_source`、`trust_source`、`parse_url` 等) | — |
| group handle 形状校验(5 处) | `upstream_groups.ex`、`managed_h2_group_boundary.ex`、`managed_h2_group_accounting.ex`、`managed_generation_accounting.ex` | — |
| 有界 receipt 环(4 处) | `ledger.ex` 的 `receipt/5`、`put_control_receipt/4`、`remember_retired/3`,以及 `admission.ex` 的 `remember_update/3` | — |
| `gaoxy_server` 配置解码辅助函数 | `traverse/2`、`keys/2`、`named/2` 在 `server/config.ex`、`route_config.ex`、`relay_config.ex`、`upstream_endpoint.ex` 各一份 | 静态头校验严格度不同:`route_config.ex` 只拒 CR/LF/NUL,`static_endpoint.ex` 拒所有控制字符 |

**建议**(Medium,增量进行):

- `Gaoxy.HTTP.Fields`:token、字段值语法、禁止 trailer、content-length 解析各一份;H2/H3 共用一个 `Headers.request(fields, scheme, limits, error_fun)`。
- `Gaoxy.Proxy.Net`:`reserved?/1`、`parse_cidr/1`、`contains?/2`,UDP options 调用它。
- 导出 `Headers.hop_by_hop/1` 和 `Headers.forwarding/1`,WebSocket 只追加自己的 `sec-websocket-*`。
- 抽出 `ManagedOpen`(校验 endpoint → pin → checkout → prepare → open → bind → finish → release)供 Session 和 Probe 共用。
- `Gaoxy.Server.Decode` 统一配置解码,并保留更严格的那份头校验。

### 死代码与放错位置的代码

- **约 1,100 行 lib 代码生产不可达**(Medium / 0.5–1 天)✔:`ManagedGenerationAccounting`(746 行)在 `apps/*/lib` 中没有任何其他文件引用;`ManagedH1Accounting` 是写死 OTP 版本号的静态事实;`ManagedH2Reservation` 只有返回常量的 `reservation_bytes/3` 被使用;`ManagedH2GroupBoundary.activation/0` 恒返回 `:ok` 却通过 `apply/3` 当作门禁调用。另有约 2,600 行测试钉着它们。建议把这些"工作表"移到 `docs/` 或 `test/support`,删掉常量门禁。
- **生产代码里带着测试夹具**(Low)✔:[http3/connection.ex:13](apps/gaoxy_http3/lib/gaoxy/http/http3/connection.ex#L13) 对 `Gaoxy.HTTP3Fixture.Endpoint` 做模式匹配,并有十二处 `operations: nil` 分支实现内置的 `/ok` 和 `/echo` 响应。建议移到由 `integration/http3/fixture.exs` 提供的 handler 模块后面。
- **两套 reload 实现**(Low):`RouteConfig.reload/4` 只被测试引用,真实路径是 `Gaoxy.Server.reload_routes/3`。
- **无预算的"legacy" lease 形状**(Low):`Service.init` 总是提供 budget,只有直接 `Admission.start_link` 的测试会走到无预算分支,它迫使 `admission.ex` 到处用 `Map.get` / `Map.has_key?` 探测。给测试一个假 budget client 并删掉该分支。

### 其他代码气味

- **宽泛的异常捕获**:`apps/*/lib` 中有 49 处 `rescue`、96 处 `catch`,其中 39 处是 `_, _ ->` 全捕获,集中在 `managed_h2_client.ex`、`upstream_transports*`。fail-closed 是合理的,但全捕获会把编程错误也变成"不可用",再加上没有日志(见 A2),真实 bug 会被吞掉。建议全捕获分支至少带上 kind/reason 发一次 telemetry。
- **潜在的返回形状错误**(Low):[forward_http.ex:104](apps/gaoxy_proxy/lib/gaoxy/proxy/forward_http.ex#L104) 的 `with` 在 `HTTPProxy.init` 失败时返回二元组 `{:error, reason}`,而 endpoint 约定是 `{:error, reason, exchange}`。目前没找到能触发的输入。

---

## 2. 性能优化

<a id="p1"></a>
#### P1 ✔ StreamRelay 轮流 5 ms 阻塞 recv,单向吞吐被封顶 — High / 1–2 天

[stream_relay.ex:288-294](apps/gaoxy_proxy/lib/gaoxy/proxy/stream_relay.ex#L288-L294)、[stream_relay.ex:333-353](apps/gaoxy_proxy/lib/gaoxy/proxy/stream_relay.ex#L333-L353)

```elixir
state = poll(state, :up)
state = messages(state)
state = if state.cancelled, do: state, else: poll(state, :down)
...
timeout = min(5, min(Lifecycle.remaining(state.deadline), ...))
result = if name == :up, do: Socket.recv(state.socket, 0, timeout),
         else: Upstream.recv(state.upstream, timeout)
```

一个进程轮流轮询两个 socket。单向传输时空闲一侧每轮白等满 5 ms,每轮最多 dispatch 一个 `max_chunk_bytes`(上限 16,384)的块,推算约 16 KiB / 5 ms ≈ 3 MB/s 每条隧道,与链路速度无关;完全空闲的隧道每秒唤醒约 100 次。影响所有 ForwardHTTP 的 CONNECT 隧道和独立 TCP/TLS relay。**先实测确认再动手。**

**建议**:读改为事件驱动(两端 `active: :once`,接到现有的"一次一个未确认写"闸门),或每个方向一个阻塞 reader。最小改动:另一侧有数据或 carry 时跳过对空闲侧的阻塞 recv。

#### P2 Admission 每次变更都是 O(n) 甚至 O(n·m) 扫描 — High / M

[admission.ex:478-480](apps/gaoxy/lib/gaoxy/admission.ex#L478-L480)、[admission.ex:1814-1823](apps/gaoxy/lib/gaoxy/admission.ex#L1814-L1823)、[accounting.ex:67-79](apps/gaoxy/lib/gaoxy/admission/accounting.ex#L67-L79)

每次提交的变更对全部 lease 和 cleanup 折叠两遍(`validate_accounting` 一遍、`sample` 一遍;budget 模式下第一遍只是和 max-int 比较)。每次连接关闭在 `DOWN` 和 `EXIT` 处理器里各线性扫描一遍;每个 H2/H3 流结束触发全量 sweep,其中 `settle_lease` 对每个 lease 跑 `Enum.any?(state.spawns, …)`。这些都在每个 service 唯一的 gate 进程里,默认 `max_connections` 是 16,384。

**建议**:五个总量改为增量维护(`state.bytes` 已经是这样);加 `monitor => ref`、`pid => refs`、`{kind, {parent, id}} => ref`、`lease_ref => spawn_token` 索引。

#### P3 每次 gate 变更都同步走 gate → Authority → Ledger,即使什么都没变 — High/Medium / S(短路)到 M–L(协议)

[admission.ex:1566-1609](apps/gaoxy/lib/gaoxy/admission.ex#L1566-L1609)、[stream_bridge.ex:128-175](apps/gaoxy/lib/gaoxy/stream_bridge.ex#L128-L175)

一次产生回复的原始 TCP 投递要 8 次 gate 调用,其中 6 次是 ledger 变更,每次再经过全 VM 唯一的 Authority 和 Ledger 两跳。`commit_lease` 即使 `begin`/`retain` 只是切换 watchdog、记账完全相同,也照样调用 `Budget.run(:replace …)`。很多调用点用默认 5 秒超时。

**建议**:`replacement.accounting == lease.accounting` 时在 `commit_lease` 里短路,用已有 receipt 本地提交;把 begin+account、account+retain 合并为单条 gate 消息。

#### P4 H2 每个事件都遍历整个连接状态并同步调用 gate — Medium / M–L

[http2/connection.ex:239-251](apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex#L239-L251)

```elixir
defp retained_connection(state) do
  :erlang.external_size(Map.drop(state, [:decode_reservation])) + ...
```

`progress/1` 在每次 socket 投递、worker 调用、writer 回执、定时器之后运行,每次对 streams、HPACK 表、输出队列做一遍 `external_size`,外加一次 50 ms 超时的 gate 调用。一个 16 KiB 的响应 DATA 帧约 7 次 gate 往返和 3 次状态遍历。gate 回复慢于 50 ms 会被转成 `GOAWAY ENHANCE_YOUR_CALM`——**一次短暂的 gate 卡顿会同时拆掉所有活跃 H2 连接**。

**建议**:用增量字节计数替代 `external_size`;只在状态转换(流增删、高水位变化)时更新 gate;记账超时当作可重试而不是连接致命。

#### P5 H3 worker 操作只在 10 ms 宿主轮询时推进 — Medium / M + 上游

[http3/transport.ex:47-58](apps/gaoxy_http3/lib/gaoxy/http/http3/transport.ex#L47-L58):`submit/4` 只写一行 ETS,没有东西唤醒 owner;owner 只在 Abyss 每 10 ms 的 `:poll` 时运行。每个 head、每个最多 16 KiB 的 DATA 块都要等下一个 tick,推算每条响应流约 1.6 MB/s,一个简单 GET 有 30–50 ms 延迟。[docs/http3.md](docs/http3.md) 已注明只验证过 1 ms 轮询的负载。

**建议**:这需要 Abyss 提供受支持的"立即 poll"唤醒,已提上游 issue [gsmlg-dev/http_fetch#170](https://github.com/gsmlg-dev/http_fetch/issues/170)(severity `needed`),调用点已加 `TODO(upstream)`。上游提供接口并升级依赖之前不在本地绕过;缩小轮询间隔只是权宜之计。

#### P6 带路由的请求串行经过 `Generation.Store` 并复制整个 router — Medium / M

[generation.ex:193-243](apps/gaoxy_http/lib/gaoxy/http/generation.ex#L193-L243):每个请求都调用唯一的 Store 进程,Store 在自己的 `handle_call` 里为每个资源 provider 跑 `pin_many`,再把完整的 `%Router{}` 复制回调用方。一个慢 provider 会队头阻塞所有路由,每请求成本随路由表增大。

**建议**:活跃 router 通过 `:persistent_term` 或读并发 ETS 行发布(按 generation 为键);请求进程直接 pin 并复查 generation;Store 只负责激活和退役。

#### P7 HTTP 代理 pump 每个在途请求每 5 ms 唤醒一次 — Medium / 1–2 天

[http.ex:42](apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex#L42)(`@poll_ms 5`)、[http.ex:817-854](apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex#L817-L854)

等待上游期间每请求每秒唤醒 200 次,H1 上每次是两次 socket `recv` 加一条 telemetry。5,000 个慢请求或长轮询就是每秒约一百万次空唤醒。Session 还另外每 5 ms 轮询 `Task.yield/2` 直到 header 到达,而 task 回复本来就会作为消息到达。关联缺陷:非 H2 客户端的 `schedule/1` 不保存 timer ref(H2 分支保存了),header 之前处理任何其他消息都会多起一条永久轮询链。

**建议**:下游关闭改为事件检测;至少在上传结束后退避到 50–100 ms。去掉 Session 对 HTTPFetchClient 的 pre-header 轮询,或像 H2 分支那样跟踪并取消定时器。

#### P8 两个 upstream owner 是单进程,请求路径上做 O(n) 扫描 — Medium / 2–3 天

[upstream_transports.ex:1342-1362](apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex#L1342-L1362):每次 pin / delegate / checkout 遍历全部 pin(上限 4096)并各算一次 `external_size`,外加线性 `Enum.find` 做幂等查找;每次 release、每次 DOWN 再扫一遍。一个代理请求对这两个进程做大约十次同步调用,所有上游的吞吐被串行化。探针 tick 每 50 ms 为每个到期成员构造完参数后才检查 `max_probes`。

**建议**:维护运行计数器(pin 数、payload 字节、每资源 token 数);按 `{acquirer, operation}` 和 monitor ref 建索引;先查探针容量再构造参数。长期可把选择状态放进 owner 监控的 ETS,让 checkout 变成一次读。

#### P9 H3 客户端每 5 ms 忙轮询,并来回复制 Session 结构 — Medium/Low / 2–3 天

[http3_session_client.ex:562-580](apps/gaoxy_proxy/lib/gaoxy/proxy/http3_session_client.ex#L562-L580):`arguments` 总带着 `handle.session`,结果又带回更新后的结构,完整的 `QuicHttp3.Session`(含 QPACK 状态和保留缓冲)每次操作复制两遍;空闲的流式请求每 5 ms 重新轮询;传输层已经投递的 `{:quic_ready, _, _}` 被 `drain_hints` 丢弃。**建议**:让调用方进程拥有 Session,只交换命令和事件;把 `quic_ready` 转成唤醒。

#### P10 telemetry handler 和 Logger 在全局 Authority 和各 gate 进程内同步执行 — Medium / S–M

[authority.ex:150-166](apps/gaoxy/lib/gaoxy/resource_budget/authority.ex#L150-L166):`:telemetry.execute` 在调用方进程里同步跑 handler。宿主挂的慢 handler 或同步模式的 Logger 后端会卡住全 VM 的 Authority;`:resource_budget_rejected` 每次拒绝都触发,过载时最忙;超过 50 ms 就产生 `:budget_timeout`,进而触发 C1 和 C2。**建议**:Authority 回复之后再由调用方发 effect,或交给专门的 emitter 进程;对 `:work` 做限速或聚合。

#### 较小的性能项

- **P11 每请求校验分配字节列表**(Low / S):[http1/parser.ex:114-117](apps/gaoxy_http/lib/gaoxy/http/http1/parser.ex#L114-L117) 把每个头部值变成布尔列表,H2/H3 用 `:binary.bin_to_list`,每个头部名再跑一次 `Regex.match?`;`parse_head/2` 每次投递都对整个缓冲重跑匹配(慢速滴入的 head 是二次方,受 32 KiB 和 5 秒头部超时约束)。复用 `RendererBounds.field_value?/1` 式的无分配递归,并记住扫描偏移。
- **P12 UDP relay 每个数据报三次 Controller 调用**(Low / 0.5 天):`:offer_context` 把整个 `%Options{}` 复制给 dispatcher,每个 ack 线性扫描最多 256 个 association。把不可变 options 发布一次,合并 reserve 和 submit,维护 `pid => key` 映射。
- **P13 已有 monitor 的地方仍用 1 ms 轮询**(Low / S):[service.ex:570-572](apps/gaoxy/lib/gaoxy/service.ex#L570-L572) drain 期间每 1 ms 对全部资源 `Process.alive?`;[quic_cleanup.ex:85-87](apps/gaoxy/lib/gaoxy/quic_cleanup.ex#L85-L87) 每个关闭中的 QUIC 连接以 1 kHz 调 `QUIC.info`。改为由已有的 `DOWN` 消息加一个 deadline 定时器驱动,QUIC 探测做指数退避。
- **P14 ForwardHTTP 每请求重建并重新校验代理配置**(Low / 1–2 小时)✔:[forward_http.ex:100-105](apps/gaoxy_proxy/lib/gaoxy/proxy/forward_http.ex#L100-L105)。保留 `init/1` 校验过的 `%HTTPProxy{}` 模板,每请求只改 `uri` 和 `connect_address`。
- **P15 目标解析:每请求两次串行阻塞 DNS,只用第一个地址**(Low–Medium / 0.5 天):[destination_policy.ex:108-115](apps/gaoxy_proxy/lib/gaoxy/proxy/destination_policy.ex#L108-L115)。慢的 AAAA 解析会吃掉拨号预算;首个地址不通而其他已批准地址健康时直接 502。返回整个已批准列表并依次尝试,两个地址族并发解析。
- **P16 gate 全局的 64 槽 receipt 环**(Low / S–M):[admission.ex:1613-1631](apps/gaoxy/lib/gaoxy/admission.ex#L1613-L1631)。多数调用方传内联 `make_ref()` 且从不重试,却每次在 gate 里算一次 SHA-256 并占一个槽;繁忙的 gate 上真正的重试会发现 receipt 已被淘汰。为不重试的调用方提供非幂等快速路径,receipt 按 lease 划分。

---

## 3. 架构建议

<a id="a1"></a>
#### A1 ✔ `ManagedH2GroupAccounting` 是运行时断言,不是账本 — High / 3–5 天

[managed_h2_group_accounting.ex:40-49](apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_accounting.ex#L40-L49)、[probe.ex:601](apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/probe.ex#L601)

```elixir
# managed_h2_group_accounting.ex
@session_keys @session_args ++ ...
@probe_keys @probe_args ++ ...
# upstream_groups/probe.ex
when map_size(state) == 23 do
```

- 测量出来的字节数被丢弃:请求的收费恒为常量 `reservation_bytes/0`(16,478,862)。
- `account_state(state)` 在几乎每一步之前和之后对整个进程状态做深度校验并跑 `external_size`,包括每个 5 ms 轮询 tick 和每个数据块(`http/session.ex` 里有 104 处调用)。
- 私有 state 的键列表靠手工同步:accounting 里的 `@probe_keys`、probe.ex 里的 `@state_keys`、`map_size(state) == 23`,以及 `@session_keys` 与 Session 结构。
- **给 Session 或 Probe 加一个字段,所有 managed-H2 group 请求就会在运行时 fail-closed,而不是编译失败。** 这很可能是这块反复修复、以及最近那次"realign fixtures with current accounting"提交的根源。

**建议**:只在无界数据进入的地方做强制(Envelope 和 Preparation 校验器已经在做),加上那一个常量预留;把投影检查移成仅测试的不变量,让形状漂移在 CI 失败而不是在生产失败。如果仍要运行时检查,键列表从单一来源派生,且只在阶段转换时跑一次。

<a id="a2"></a>
#### A2 给所有终态隔离加上可见性和恢复路径 — High / 2–3 天

C2、C3、C4、C5、C11 的共同点是"永久关闭 + 没人知道"。`upstream_groups.ex`、`upstream_transports.ex`、`custodian.ex` 里 Logger 和 telemetry 调用数为 0 ✔;`UpstreamGroups.status/1` 和 `UpstreamTransports.status/1` 在 `lib/` 中没有调用方。

**建议**:

- 每次进入终态(`:failed`、`mode: :draining`、`retire_resource`、`fail_gate`、`custodian_failed`)都发一条带原因的 telemetry 事件,并打一条 warning/error 日志。
- 为每种终态定义明确的恢复途径:有界的后台重查、或运维可调用的显式重置;把 `status/1` 做成受支持的观测面(同时解决 T2)。
- 在 [docs/gateway.md](docs/gateway.md) 和 [docs/resource-budget.md](docs/resource-budget.md) 里写清每种终态的含义和处置方法。

#### A3 减少对单进程枢纽的同步依赖 — Medium / L

P2、P3、P4、P6、P8 是同一个结构问题。按收益排序的方向:

1. **读路径走 ETS / `persistent_term`**:活跃 router(P6)、upstream 选择状态(P8)。
2. **记账只在转换时同步**:连接/流建立与结束、高水位变化时更新 gate;每 chunk 的 begin/retain/start_send/finish_send 合并或本地化(P3、P4,以及 StreamRelay writer 每块四次 gate 调用——[stream_relay/writer.ex:27-36](apps/gaoxy_proxy/lib/gaoxy/proxy/stream_relay/writer.ex#L27-L36))。
3. **记账超时不等于拆连接**:目前 50 ms 超时在 H2 里变成 GOAWAY,在 Service 里变成整服务 drain。

#### A4 reload 后健康状态不继承,group 路由每次都有 503 窗口 — Medium / 1–2 天

[upstream_groups.ex:968-977](apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex#L968-L977):新 generation 的每个成员从 `:unknown` 开始,coordinator 不等探针就激活。文档里写了,但即使成员没变,每次 reload 也都会发生。探针全局并发上限 4,黑洞成员每个最多 2 秒,32 成员的 group 需要好几轮。jitter 是固定的 `phash2({key, member.id})`,起不到分散作用。

**建议**:origin、transport 策略和 health 配置都相同的成员从上一代继承健康状态;或在 reload 期限内等第一轮探针再激活。`max_probes` 随成员数伸缩。

#### A5 大模块的拆分接缝 — Low–Medium(为后续修复铺路),各 M

| 模块 | 行数 | 可抽出的职责 |
| --- | --- | --- |
| [http2/connection.ex](apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex) | 2104 | 帧接收状态机(364-628)做成返回 action 的纯模块,H3 的 `Protocol.feed/3` 已经是这种形式;输出调度;准入与退役记账;worker 操作分发。纯接收器能让 S1 和 C6 不用 socket 就做单元测试 |
| [http/session.ex](apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex) | 1946 | 一个 GenServer 里跑着 plain/fixed 和 managed-H2 group 两套状态机。纯谓词 `Session.GroupGuard`(约 450 行)、`Session.Selection`、`Session.Cleanup`;`group_intent?/1` 每条消息多次从五种 state 形状重新推导模式,应在 `init` 决定一次 |
| [upstream_groups.ex](apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex) | 1872 | pin 账本;纯的健康/选择模块(对 group 记录的函数);探针调度器;handle 校验器 |
| [admission.ex](apps/gaoxy/lib/gaoxy/admission.ex) | 1856 | `Admission.Spawns`、`Admission.Cleanups`、纯的 receipt 环 |
| [ledger.ex](apps/gaoxy/lib/gaoxy/resource_budget/ledger.ex) | 1504 | 注册生命周期;策略校验(纯);转换/telemetry effect |
| [service.ex](apps/gaoxy/lib/gaoxy/service.ex) | 1447 | 纯的后端选项构造 `Service.Backend`(1243-1446);drain 状态机;原生 QUIC 预留握手 |
| [http.ex](apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex) | 1225 | `HTTP.Config`、`HTTP.RequestOptions`、`HTTP.Startup`、`HTTP.Pump`;接缝是已有的 `pump_state/8` map |

项目自己的规则是"配置和策略用纯模块,进程只用于可变运行时状态"——上面这些拆分基本都是把纯逻辑从进程模块里拿出来,和这条规则一致。

---

## 4. 安全问题

### 已确认的安全基线(审查后认为处理得当)

- **开放代理规则成立。** `ForwardHTTP.init` 拒绝缺失策略或空规则;每个请求先认证、再授权、再解析,只拨号通过检查的已固定地址。StreamRelay、UDPRelay、WebSocket、`Proxy.HTTP`、网关上游都使用运维固定的目标。
- **SSRF / DNS rebinding**:策略对每个 A/AAAA 应答求值并拨同一个地址;IPv4-mapped IPv6 已归一化;0.0.0.0/8、loopback、169.254/16、NAT64、6to4、Teredo、ULA、link-local 默认保留。
- **头部**:`Proxy-Authorization` 和 Connection 指名的头双向剥离;入站 `X-Forwarded-*`、`Forwarded`、`X-Real-IP` 被剥离并重新生成。
- **H1 走私**:CL/TE 冲突、重复或非数字 Content-Length、obs-fold、裸 LF/CR、冒号前空白、chunk-size 溢出均有防护。
- **H2**:客户端 RST/SETTINGS/PING/PRIORITY/WINDOW_UPDATE 洪泛、CONTINUATION 块大小、窗口溢出、`max_streams`、伪头部规则、`:authority` 对 Host 均有防护。
- **配置**:不从输入创建 atom;仅有的两处 `binary_to_term` 都是对自产 term 做往返;上游 TLS 默认 `verify_peer`;未发现凭据进日志或 telemetry。

### 发现

<a id="s1"></a>
#### S1 ✔ H2:服务端代发的流重置绕过控制帧速率限制(MadeYouReset 类,CVE-2025-8671) — High / S

[http2/connection.ex:364-374](apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex#L364-L374)、[http2/connection.ex:1729-1738](apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex#L1729-L1738)

```elixir
defp rate(state, %{type: type}) when type in [2, 3, 4, 6, 7, 8] do
  ...
  if state.rate > state.h2.control_rate, do: failure(state, :enhance_your_calm), else: state
end
defp rate(state, _), do: state
```

客户端发的 RST_STREAM 被限制在 256/s,但服务端因对端行为而发出的重置(`reset/4`)从不计数。攻击者循环 `HEADERS(END_STREAM)` + 同一流上的 DATA(→ `reset(:stream_closed)`),或 HEADERS 后再发一个不带 END_STREAM 的 HEADERS(→ `reset(:protocol_error)`)。每轮约 40 字节攻击流量,服务端付出 HPACK 解码、头部校验、`Admission.spawn_request`、一次 worker spawn 加 kill。没有 `:instance` 预算的服务上流槽位立即释放,`max_streams` 永远不会生效。

**建议**:在 `reset/4` 内把对端诱发的重置计入同一个 `control_rate` 窗口,超限则 GOAWAY `ENHANCE_YOUR_CALM`;无预算路径下也保持流槽位占用直到确认 worker 已退出。

#### S2 ✔ Forward 代理把客户端 IP 泄露给每个目标站 — Medium / 2–3 小时

[forward_http.ex:100-105](apps/gaoxy_proxy/lib/gaoxy/proxy/forward_http.ex#L100-L105) 调用 [http/headers.ex:130-146](apps/gaoxy_proxy/lib/gaoxy/proxy/http/headers.ex#L130-L146)

```elixir
fields =
  [{"x-forwarded-for", address |> :inet.ntoa() |> to_string()}] ++
    host_fields ++ [{"x-forwarded-proto", scheme}]
```

ForwardHTTP 复用反向代理的头部构造,所以每个转发到第三方源站的 `http://` 请求都带着 `X-Forwarded-For: <客户端地址>`。对认证的出口代理来说这泄露了内网地址。没有 forward 代理测试断言这一行为。

**建议**:给 `Headers.request` 加模式参数:仍剥离入站转发头,但不追加新的;需要的话做成显式开启。补一个线路级测试。

#### S3 UDP relay:单个源地址可占满所有 association 槽位 — Medium / 0.5 天

[udp_relay/controller.ex:107-109](apps/gaoxy_proxy/lib/gaoxy/proxy/udp_relay/controller.ex#L107-L109):association 键是 `{generation, writer_generation, ip, port}`,唯一上限是全局的(最多 256)。入口 CIDR 内的一台主机(或能伪造该源地址的人)从不同端口发 256 个单字节数据报即可填满表;每个槽位保持 `idle_timeout`(默认 30 秒),约 9 包/秒就能让其他对端一直被拒。放大本身是有界的(回程 credit 默认 1:1)。

**建议**:加按源 IP 的上限(如 `max_associations_per_source`),在同一个 `cond` 里计数;对从未收到回复的 association 缩短空闲时间。

#### S4 H2 HPACK:解码器上限和解码预留比实际执行的头部限制大几个数量级 — Medium / S–M

[http2/limits.ex:61-76](apps/gaoxy_http/lib/gaoxy/http/http2/limits.ex#L61-L76)

```elixir
def decode_reservation(h2, block_bytes) do
  t = h2.table_size
  2 * block_bytes * (max(t, 128) + 2) + 512 * block_bytes + 2 * t
end
```

默认下解码器接受 16,384 个字段和约 67 MB 的逻辑展开,之后 `Headers.validate/3` 才拒绝超过 100 个字段或 32 KiB 的。每次解码先从共享预算预留约 8.7 KB / 压缩字节:16 KiB 的块预留 142.7 MB。预留被拒时整条连接 `ENHANCE_YOUR_CALM`。在显式 `max_bytes` 上限下,几条攻击连接循环发最大尺寸的纯索引块就能占住大部分预算,无关连接在普通 HEADERS 上被杀。这也是 H2 至少需要约 157 MB `max_bytes` 才能启动的原因。真实内存占用其实很小。(跨连接饿死是推断,未实测。)

**建议**:传 `max_fields: max_headers + 5`、`max_decoded_bytes` / `max_field_bytes: max_header_bytes`,并据此计算预留。注意行为变化:超限列表会变成连接错误,因为中止的解码会让动态表失步。

#### S5 Forward 代理凭据校验没有提供常数时间路径 — Low / 2 小时

[destination_policy.ex:60-81](apps/gaoxy_proxy/lib/gaoxy/proxy/destination_policy.ex#L60-L81):认证完全交给宿主回调(合理,且 raise/throw 时 fail-closed),但文档和 API 都没提常数时间比较,测试夹具用的是字面量匹配 `"Bearer secret" -> ...`,用户会照抄。407 的 challenge 写死为 `Bearer`。

**建议**:提供基于 `Plug.Crypto.secure_compare/2` 的 `DestinationPolicy.static_bearer/1`(`plug_crypto` 已在依赖中),在文档中写明要求,让策略声明自己的 challenge 字符串。

#### S8 代理在客户端未发送 User-Agent 时添加自己的标识 — Low(2026-11-13 修 S2 时观察到,未处理)

`forward_http_test.exs` 里上游收到的请求头包含 `user-agent: mozilla/5.0 (linux; ...) otp/28 beam/... elixir/1.18.5 http_fetch/1.0.0-rc.16`,而客户端并没有发送 User-Agent。代理不应替客户端添加 User-Agent,更不应暴露自身的 OTP/Elixir/依赖版本。需要确认这是 http_fetch 的默认行为还是 Gaoxy 的配置,再决定是本地关闭还是走上游 issue。

#### S6 没有 trusted-proxy 选项 — Low(设计缺口)

HTTP 和 WebSocket 两条路径都总是用 socket 对端地址替换 `X-Forwarded-For`。这能防伪造,但 Gaoxy 部署在另一层负载均衡后面时真实客户端地址会丢失。考虑加 `trusted_proxies` CIDR 列表来决定追加还是替换。

#### S7 供应链与 CI 加固 — Low–Medium / 0.5 天

- **Actions 用 tag 而非 commit SHA 固定** ✔:`actions/checkout@v7.0.1`、`erlef/setup-beam@v1.24.1` 等;`dtolnay/rust-toolchain@stable` 是浮动分支,出现 8 次。[release.yml](.github/workflows/release.yml) 拥有 `contents: write` 并使用 `HEX_API_KEY`,至少发布工作流里应固定到 SHA。
- **没有依赖漏洞扫描**:CI 中没有 `mix hex.audit` / `mix deps.audit`,也没有 Sobelow。
- **运行时依赖全部是预发布版** ✔:hell、abyss、http_core、http_fetch、http_web_socket、elixir_quic、elixir_quic_http3、ex_ssl、http_pool、http_runtime 都锁在 `1.0.0-rc.16`。TLS 栈(ex_ssl)和 QUIC 栈都是自研 rc。这是产品决策,但应在 README 的"生产就绪度"里明确写出,并说明 ex_ssl 的审计状态。

---

## 5. 测试改进

<a id="t1"></a>
#### T1 ✔ 超过一半的测试文件不在任何自动门禁里 — High / 1–2 天起

[scripts/check-repairs.py](scripts/check-repairs.py) 调度了 126 个文件;[scripts/test-inventory.json](scripts/test-inventory.json) 把其余 143 个标为 `retained`,其中 141 个的处置是 `existing_not_scheduled`。按 app:proxy 80、http 30、core 14、server 10、http3 9。

不在门禁里的包括:

- `destination_policy_test.exs`、`forward_http_test.exs`——直接守护"不得成为开放代理"规则的测试;
- `upstream_groups_test.exs`、`upstream_transport_generation_test.exs`;
- `managed_h2_group_generation_test.exs`(5,033 行)、`managed_h2_fixed_generation_test.exs`(3,792 行)。

也就是说,改坏目标策略或 managed H2 记账,CI 不会报错。

**2026-11-13 补充(实测,core)**:`apps/gaoxy` 整套一起跑(453 例)在未改动的代码上有 4–5 例失败:`DatagramDispatcherTest`(1)、`SendOutcomeTest`(2)、`QUICContextTest`(2,单独按门禁方式运行时通过),以及负载下偶发的 `AdmittedSpawnTest`(1,单独运行稳定通过)。说明这些测试对并发运行或共享状态敏感。

**2026-11-13 补充(实测)**:修 S1 时跑了 `apps/gaoxy_http` 的全部 H2 测试文件(含未调度的),在未改动的 `main` 上 163 例中已有 30 例失败,集中在 `http2_integration_test.exs`、`http2_worker_startup_extended_test.exs`、`http2_network_test.exs`、`http2_capacity_test.exs`。未调度的测试确实已经在腐烂;这些失败尚未诊断,不清楚是测试过期还是产品缺陷。

**建议**:

1. 先把 `destination_policy_test.exs`、`forward_http_test.exs` 以及其他不开真实 socket 的安全相关测试归入 `unit` 或 `component`。
2. 加一个每日或手动触发的 job 跑全部 `existing_not_scheduled` 文件,不作为合并门禁,只为让它们不腐烂;失败的要么修、要么明确删除。
3. `existing_not_scheduled` 应是带期限的过渡状态,而不是永久分类。

<a id="t2"></a>
#### T2 ✔ 测试钉住内部状态而不是行为 — Medium / 2–4 天

`apps/*/test` 中有 952 处 `:sys.get_state` / `:sys.replace_state`,最集中在 `managed_h2_group_generation_test.exs`(118)、`managed_h2_fixed_generation_test.exs`(71)、`upstream_transport_generation_test.exs`(66)。

```elixir
after_t = :sys.get_state(f.owner)
after_g = :sys.get_state(f.groups)
assert after_t.pins === before_t.pins and after_t.tokens === before_t.tokens
...
assert c.fixed_bytes == 9_444_956
assert c.reservation_bytes == 16_478_862
```

任何账本重构(包括 C5、P8 建议的那些)都会在行为不变的情况下打断几百条断言。这和 A1 是同一个问题的两面:实现细节被当成了契约。

**建议**:把 `UpstreamGroups.status/1` / `UpstreamTransports.status/1` 扩展为受支持的观测面(按类型的 pin 数、token 数、失败计数、每 group 的 lifecycle),测试通过它断言;字节常量集中在一个契约测试里。

#### T3 没有静态分析 — Medium / 1–2 天

✔ `apps/*/lib` 中 `@spec` 数量为 0;没有 Dialyzer、Credo;[ci.yml](.github/workflows/ci.yml) 只有 `mix format --check-formatted` 和 `mix compile --warnings-as-errors`。对一个大量依赖 tagged tuple 形状(`{:error, reason, state}` 对 `{:error, reason}`)的代码库,Dialyzer 能直接抓到 [forward_http.ex:104](apps/gaoxy_proxy/lib/gaoxy/proxy/forward_http.ex#L104) 那类返回形状错误。

**建议**:先给各 app 的公共 API 模块(`Gaoxy`、`Gaoxy.HTTP`、`Gaoxy.Proxy.*` 的入口)加 `@spec`,接入 Dialyzer 并在 CI 里跑;Credo 只开少量有价值的检查(复杂度、未使用的返回值)。

#### T4 精确用例数清单维护成本高 — Low–Medium

`check-repairs.py` 为 126 个文件各硬编码一个精确用例数。它的目的(用例不能悄悄消失)是对的,但每加一个测试都要手改数字。**建议**:保留"数量不得减少、且必须为正"的检查,把精确数字改为由脚本生成并提交的清单(`--update` 模式),评审时看 diff 即可。

#### T5 没有覆盖率度量 — Low

`.gitignore` 里有 `/coverage/`,但没有任何工作流或脚本使用 `--cover`。在 T1 的每日 job 里加上 `mix test --cover` 并导出报告,至少能回答"哪些 lib 模块完全没被调度的测试触达"。

#### T6 针对本次发现应补的测试

| 发现 | 需要的测试 |
| --- | --- |
| S1 | H2:循环 `HEADERS(END_STREAM)` + DATA,断言超过 `control_rate` 后 GOAWAY |
| C6 | H2:持续 > `frame_timeout` 的帧中间投递(每帧都及时完成),断言连接存活 |
| C9 | H1:Plug 返回 599 / 499,断言状态码原样到达 |
| S2 | Forward 代理:断言上游请求不含 `X-Forwarded-For` |
| S3 | UDP:单源多端口,断言按源上限生效 |
| C4 | checkout 后在 bind 前失败,断言 transport 仍可用 |
| C5 | 探针在 claim 与 bind 之间退出,断言 group 可恢复且 `max_probes` 名额被归还 |
| C1 | pending 期间多个终结项,断言只有一个待处理的 sweep |

#### T7 82 个测试文件是 `async: false` — Low

269 个文件中 82 个串行。部分是真实网络测试所必需,但值得抽查:依赖全局状态(`Application.put_env` 有 6 处、VM 级 Ledger)的可以通过给每个测试独立的 budget identity 来解耦。

---

## 6. 文档缺口

#### D1 ✔ `implementation-status.md` 严重过期 — High / 0.5 天

[docs/implementation-status.md](docs/implementation-status.md) 的最新条目是 v0.5.0(2026-10-20),代码是 0.16.2,`docs/releases/` 已到 0.16.2。文件名叫"当前实现状态",但内容差了 11 个次版本。另外该文件链接到 `github.com/gsmlg-opt/gaoxy`,而 README 和 git remote 指向 `gsmlg-dev/gaoxy`。

**建议**:要么改成一页当前状态(链接到最新 release notes 和 [capabilities.md](docs/capabilities.md)),历史部分移到 `docs/history/`;要么改名为历史文件并从 README 移除"当前状态"式的引用。

#### D2 ✔ `AGENTS.md` 包含已过期的授权并层层覆盖 — High / 1–2 小时

[AGENTS.md](AGENTS.md) 开头两节是时间窗口授权,截止 2026-10-31 10:09 Asia/Shanghai,已过期两周;后面是多层"supersedes"和"historical instructions — retained below",一些段落互相覆盖(例如"不得 push/release"与之后的条件性发布授权)。读它的 agent 需要自己推断哪些仍有效,这本身就是出错来源。

**建议**:只保留当前有效的规则(工作区与实现、依赖 issue 路由、验证与验收、测试边界);过期的授权和历史处置移到 `docs/history/agents-authorizations.md`。这是你的授权记录,具体删哪些需要你来定。

#### D3 仓库里的验收证据体量 — Medium / 1 天

✔ `docs/acceptance` 追踪了约 24,100 个文件(全仓库 25,109 个),磁盘上 1.8 GB:7,166 个 json、7,091 个 log、4,488 个 `.ex`(其中 3,381 个路径含 `deps/`,是依赖源码快照)、117 个 `.pem`、约 50 份 `implement-plan.md` 的历史副本。它们压缩得很好(`.git` 只有 80 MB),但:

- 每次 checkout、全文搜索、编辑器索引都要处理 2.4 万个无关文件;`.formatter.exs` 的 `subdirectories` 不包含它们,但 grep 和 LSP 会;
- 证据里的 `.ex` / `.exs` 副本会出现在代码搜索结果里,和真实源码混淆;
- 117 个 `.pem` 即使是测试夹具,也会持续触发密钥扫描告警,建议确认其中没有非测试材料。

**建议**:把证据打包成 release 附件或放到独立的 evidence 仓库 / 分支,主仓库只留每个里程碑的摘要 md 和校验和。至少加一个 `.ignore` / `.rgignore` 把 `docs/acceptance/evidence` 排除出搜索。

#### D4 运维文档缺少故障状态说明 — Medium / 1 天

配合 A2:[docs/gateway.md](docs/gateway.md)、[docs/resource-budget.md](docs/resource-budget.md) 没有说明 `:failed` group、retired transport、failed custodian、`fail_gate` 之后的 service 分别意味着什么、如何观测、如何恢复。目前恢复手段实际上是"reload 或重启",应明确写出。

#### D5 代码内文档 — Medium / 持续

✔ `apps/*/lib` 中 167 个 `@moduledoc` 里有 107 个是 `@moduledoc false`,`@spec` 为 0。内部模块用 `@moduledoc false` 没问题,但下面这些不变量目前只存在于代码形状里,应当写成注释:

- [upstream_transports.ex:444-447](apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex#L444-L447):为什么未 bind 的 finish 必须 retire 整个资源(C4);
- [managed_h2_group_accounting.ex](apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_accounting.ex) 的键列表必须与 Session / Probe 的 state 同步(A1)——在 Session 和 Probe 的 state 定义旁边加一句提醒;
- [http2/limits.ex](apps/gaoxy_http/lib/gaoxy/http/http2/limits.ex) 的 `@max_delivery` 推导依据(C7,目前依据的是错误的 TLS 实现);
- [service.ex](apps/gaoxy/lib/gaoxy/service.ex) 的 `fail_gate` 何时可以调用(C2)。

#### D6 README 与根目录杂项 — Low / 1–2 小时

- [README.md](README.md) 开头混入了按版本的变更说明("Version 0.12.0 preserves …"),这属于 release notes;README 开头应只描述当前能力。
- 没有 `CHANGELOG.md`;`docs/releases/*.md` 承担了这个角色,建议在根目录放一个索引式 CHANGELOG 指过去,方便 Hex 用户。
- 根目录的 [codex-prompt.md](codex-prompt.md)(18 KB)和 [implement-plan.md](implement-plan.md)(125 KB)是过程文档,建议移到 `docs/plans/` 或 `docs/history/`。
- README 没有"生产就绪度"小节:哪些依赖是 rc、WebSocket 默认没有帧/消息上限且引擎不做 Origin 检查([docs/websocket-limits.md](docs/websocket-limits.md))、H3 没有 GOAWAY drain、specialist 压力/慢对端测试尚未执行——这些目前分散在各文档里,新用户看不到。

#### 本地环境(不属于仓库,但顺带一提)

工作目录下被忽略的 `.audit/` 占 27 GB,另有一个 8.3 MB 的 `erl_crash.dump`(2026-11-12)。前者可以按需清理;后者值得看一眼是哪次运行崩的。

---

## 建议的处理顺序

1. **小而高价值的修复**(各 S,可独立提交并配测试):S1、C6、C1、C8、C9、C10、S2。
2. **让测试门禁可信**:T1 第 1 步(把安全相关的未调度测试纳入门禁),然后 T6。
3. **可见性先行**:A2——在动 C2/C4/C5 的语义之前先加 telemetry,这样能知道这些终态在真实运行里出现得多频繁。
4. **终态隔离的恢复路径**:C4、C5、C2、C3、C11。
5. **性能**:先实测 P1(CONNECT 隧道吞吐)和 P4/P3(H2 下 gate 调用数),再决定投入;P5 走上游 issue。
6. **结构性清理**:A1(连同 T2)、死代码、重复代码、A5。
7. **文档**:D1、D2 可以随时做,成本很低。
