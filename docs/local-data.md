# 本地数据与离线工作台

状态：公共层及部分本地业务已落地，实际来源与设备验证范围见[工程说明](foundation.md)。PR #37 已加入 E 的邮箱本地数据与同步编排，尚无真实协议实现或邮箱页面；不因本地表和接口存在就宣称来源已连接。

## 数据归属

- 个人学习数据与未发布草稿本地优先。设置中的笔记备份默认关闭，用户明确选择 1–100 条笔记后，仅在手动同步时上传；读取、登录与恢复都不授权上传。共享资料、社区内容与公共地图按[完整计划](sources/开发完整内容.md)由服务端保存；[公共文件](public-files.md)不要求私人邮件附件先上传。
- 数据库唯一入口为 `lib/core/storage/local_database.dart`，文件位于 `getApplicationSupportDirectory()/jlu_dela/dela.db`。页面与功能模块不得自行打开数据库。
- 所有业务表带 `user_id`，查询必须同时带当前用户；退出或切换账号不删除磁盘数据，但不会把上一账号的数据显示给新账号。
- SQLite 不保存刷新令牌、访问令牌、学校 Cookie、学号或密码。

## 版本与迁移

- 每项迁移在单个事务内执行，已应用版本写入迁移账本，最高版本记在 `PRAGMA user_version`；该项失败回滚，不删库重来。
- 版本段：1 CORE；2–9 教务（已用 2–6）；10–19 学习通（已用 10）；20–29 内容缓存（已用 20–23）；30–39 由 E 协调邮箱、笔记与摘要。邮箱已用 [30、31](../clients/flutter/lib/features/mail/mail_migrations.dart)，并进入[聚合入口](../clients/flutter/lib/app/local_migrations.dart)，笔记已用 `32`，当前 SQLite 版本为 `32`，与服务端 schema `10` 分开管理。
- [E 的笔记 PR #40](https://github.com/goya4140/JLU-Dela/pull/40) 及[邮箱凭据键 PR #41](https://github.com/goya4140/JLU-Dela/pull/41) 已合并。后续笔记或摘要迁移按实际账本协调，不预建空迁移。笔记导出/导入适配保留在 E 的目录，由 E 维护字段含义；A 维护公共授权、状态及同步流程。各模块维护自己的 `*_migrations.dart`，不改写已发布迁移。
- 数据库版本高于应用支持版本时拒绝打开并提示升级；不降级、不删库。

## 个人笔记备份

[契约](../contracts/openapi.yaml)提供当前账号的 `GET/PUT/DELETE /api/v1/personal-backup/notes`。只传 ID、标题正文、课程/课次引用、回放来源/ID/显示名、时间位置与创建/更新时间，最多 100 条及 512 KiB；不传本地版本、用户自报归属、密码、令牌、来源会话或报告码。课程引用原样保留，不伪造第二客户端尚未获取的课程或可播放回放。

公共控制器复用账号作用域的本地草稿存储，保存授权范围、云版本、最近成功及失败、待重试请求；新笔记不会自动加入范围。整份选中快照以云版本做 CAS，两个设备即使修改不同笔记也可能冲突。冲突不写云、不覆盖本地；显式恢复把不同内容保存为确定性的独立副本，用户检查后重新选择范围并同步。重复恢复不重复创建相同副本。此首版不自动合并、不自动调度，也不同步来源凭据。

恢复无需先开启上传，完成后保持上传关闭。缩小范围会在下一次成功同步时移除未选云端内容；本地删除的已选 ID 需在范围中取消选择后再同步。关闭立即停止本机后续上传并丢弃旧异步结果，但不能撤回已发送请求；删除入口会重新核对云版本并清空在线副本，保留无正文版本标记以阻止旧设备静默复活。本地内容不删除，历史运维备份按维护者的保留策略管理。

失败保留本地笔记；不确定写入保存原请求与幂等键，重试不改写其正文。服务端幂等账本仅保存请求摘要与无正文回执；回执表示该次操作成功，不证明云端之后未被其他设备修改。切号/退出使旧控制器失效，恢复事务在异步边界检查生命周期并回滚；旧账号磁盘内容仍留在自己的命名空间。

## 本地数据语义

- 待办支持无截止、仅日期、精确时刻三态，颜色与日历开关为个人属性；写入以 `revision` 做乐观并发，冲突时返回当前行。三态不一致、跨用户更新在存储层直接拒绝。
- 待办排序按绝对时刻归一：精确时刻用自己的 UTC 时间，仅日期取 Asia/Shanghai 当天 00:00，无日期排最后；同一时刻按标题与 id 稳定排序，不按截止类型分组。
- 课程身份由 `(user_id, source, source_scope, source_id)` 唯一确定，绝不同名合并；来源快照完整时在同一事务内 upsert 并删除该 scope 下未出现的课程，部分读取不得标记为完整。课程备注由存储层统一 trim 并限制 1–100 字符。
- 草稿按 `(scope, key)` 保存表单状态；来源快照分别记录上次成功、上次尝试与错误，失败不清除旧成功时间，也不改业务表。
- 精确时刻以 UTC 毫秒存储，校园日期以 `YYYY-MM-DD` 存储；展示固定按 Asia/Shanghai（UTC+8，无夏令时）换算。只有日期或相对时间的值不推算为精确时刻。

## 离线模式

- 判定在 app 层完成，`SessionController` 状态机保持不变。
- `phase=authenticated` 正常进入工作台，并写入/刷新缓存身份；`unavailable` 且存在当前用户或本地缓存身份时进入本地模式，可读写本地数据，显示“离线 · 身份未验证”横幅与“重新验证”入口，不构造访问令牌。
- `signedOut` 只显示登录与激活入口，不显示任何业务数据；重新验证返回 401 时回到登录页并保留本地数据。
- 工作台用户变化时销毁旧 workspace、清空校园来源内存会话并切换到新的 `user_id` 命名空间。缓存身份只做本地数据命名空间，不是服务端授权凭据。
- `AppShell` 的页面 key 带用户作用域（`pageScopeKey`）；切换账号时同一目的地的页面 State 会重建，不保留上一账号的输入或选中状态；表单草稿应写入本地草稿存储。

## 来源会话

- 工作台身份与校园来源登录完全分开。教务与电子校务共用 `jluCampus` 来源组，学习通独立；组内 Cookie 在内存中共享，App 退出或切换用户时全部清空。
- Cookie 以 `SourceCookie` 保存 name/value/domain/path/secure/httpOnly/hostOnly/expiresAt，不支持持久化。`SourceSessionRegistry` 按 host、domain、path、secure 与过期时间过滤：host-only 只匹配本 host，父域 Cookie 可下发给子域，同名 Cookie 取 path 最长者，过期与 http 上的 secure Cookie 不返回。`cookieHeaderFor` 生成请求 Cookie 头，网络实现不得自行拼接。
- Cookie 只保存在内存，不写 SQLite、不写安全存储、不上传服务器、不写日志；重启后需要重新登录来源。这是第一批的安全取舍。
- `SourceContext` 打包 sessions/http/campusLogin/browser，由 workspace 构造一次并注入各业务 store；业务模块只通过 `hasSession` / `stateFor` 判断来源状态，刷新与打开原网页不各自持有依赖。
- `SourceHttpClient` 请求带默认 30 秒超时，响应携带重定向后的 `finalUri`；只向白名单主机附加 Cookie。未接入时使用不可用实现，不伪造连接。
- 学习通资料接口按学习通契约：`listMaterialChildren(courseOfferingId, parentSourceId?, page)` 返回 `MaterialChildrenPage`（entries、page、可空 totalPages、observedAt）；`accessMaterial` / `openAssignment` 返回 `SourceAccess`（uri、mode、可空 filename、requiresSourceSession、可空 expiresAt）。
- 来源失败只记录快照并保留旧业务数据；认证失效使用 `SOURCE_AUTH_REQUIRED`，不把工作台账号登出。真实登录、共享组失效与 Cookie 解绑影响仍待人工验证。

## 模块边界

| 模块               | 目录                                                                     | 说明                                                                |
| ------------------ | ------------------------------------------------------------------------ | ------------------------------------------------------------------- |
| CORE               | `lib/core/{models,storage,source}`、`lib/app`、`lib/main.dart`、迁移聚合 | 公共模型、存储、来源接口、页面注册、离线判定                        |
| 教务               | `lib/features/teaching`                                                  | 学期、课次与校历迁移（2–9）                                         |
| 学习通             | `lib/features/assignments`                                               | 作业与课程刷新范围迁移（10–19）                                     |
| 内容缓存           | `lib/features/content`                                                   | OA 通知、附件与学习通资料目录（已用 20–23），不是共享资料发布或社区 |
| 邮箱 / 笔记 / 摘要 | `lib/features/mail`、`lib/features/notes`；摘要按实际需要新增            | E 主责；邮箱 30–31、笔记 32 已合入，后续按账本与 A 协调             |
| 待办 / 日历        | `lib/features/planner`                                                   | 待办与日历视图                                                      |

- 功能目录只依赖 `lib/core`、`lib/app` 与生成客户端，不互相导入。
- 页面注册固定为：`TodoPage(workspace)`、`CalendarPage(workspace)`、`TeachingPage(workspace, store)`、`AssignmentsPage(workspace, store)`、`NoticesPage(workspace, store)`、`MaterialsPage(workspace, store)`；需要新依赖先向 CORE 提集成需求。
- 修改公共模型、数据库迁移入口或页面注册前，先与 CORE 和主控对齐。
