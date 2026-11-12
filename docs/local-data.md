# 本地数据与离线工作台

状态：公共层已落地。业务页面由各功能模块填充；设备端真实校园登录尚未实现，需要授权用户在学校网络下人工验证，当前不宣称任何来源已连接。

## 数据归属

- 业务数据只写本机 SQLite，服务器只负责工作台身份与后续云备份；第一批没有同步协议，业务页面不以服务器 API 作为正常读写路径。
- 数据库唯一入口为 `lib/core/storage/local_database.dart`，文件位于 `getApplicationSupportDirectory()/jlu_dela/dela.db`。页面与功能模块不得自行打开数据库。
- 所有业务表带 `user_id`，查询必须同时带当前用户；退出或切换账号不删除磁盘数据，但不会把上一账号的数据显示给新账号。
- SQLite 不保存刷新令牌、访问令牌、学校 Cookie、学号或密码。

## 版本与迁移

- 迁移在单个事务内执行，数据库版本记在 `PRAGMA user_version`；中途失败回滚，不留下半套 schema。
- 版本区间：1 CORE（`app_meta`、`local_identity`、`todos`、`course_offerings`、`source_snapshots`、`local_drafts`）；2–9 教务；10–19 学习通；20–29 内容；30–39 预留。
- 聚合入口为 `lib/app/local_migrations.dart`，各模块只维护自己的 `*_migrations.dart`。迁移只新增表、列和索引，不改写已发布迁移。
- 数据库版本高于应用支持版本时拒绝打开并提示升级；不降级、不删库。

## 本地数据语义

- 待办支持无截止、仅日期、精确时刻三态，颜色与日历开关为个人属性；写入以 `revision` 做乐观并发，冲突时返回当前行。
- 课程身份由 `(user_id, source, source_scope, source_id)` 唯一确定，绝不同名合并；来源快照完整时在同一事务内 upsert 并删除该 scope 下未出现的课程，部分读取不得标记为完整。
- 草稿按 `(scope, key)` 保存表单状态；来源快照分别记录上次成功、上次尝试与错误，失败不清除旧成功时间，也不改业务表。
- 精确时刻以 UTC 毫秒存储，校园日期以 `YYYY-MM-DD` 存储；展示固定按 Asia/Shanghai（UTC+8，无夏令时）换算。只有日期或相对时间的值不推算为精确时刻。

## 离线模式

- 判定在 app 层完成，`SessionController` 状态机保持不变。
- `phase=authenticated` 正常进入工作台，并写入/刷新缓存身份；`unavailable` 且存在当前用户或本地缓存身份时进入本地模式，可读写本地数据，显示“离线 · 身份未验证”横幅与“重新验证”入口，不构造访问令牌。
- `signedOut` 只显示登录与激活入口，不显示任何业务数据；重新验证返回 401 时回到登录页并保留本地数据。
- 工作台用户变化时销毁旧 workspace、清空校园来源内存会话并切换到新的 `user_id` 命名空间。缓存身份只做本地数据命名空间，不是服务端授权凭据。

## 来源会话

- 工作台身份与校园来源登录完全分开。教务与电子校务共用 `jluCampus` 来源组，学习通独立；组内 Cookie 在内存中共享，App 退出或切换用户时全部清空。
- Cookie 只保存在内存 `SourceSessionRegistry`，不写 SQLite、不写安全存储、不上传服务器、不写日志；重启后需要重新登录来源。这是第一批的安全取舍。
- `SourceHttpClient` 是来源网络唯一出口，只向白名单主机附加 Cookie 并设置超时；未接入时使用不可用实现，不伪造连接。
- 来源失败只记录快照并保留旧业务数据；认证失效使用 `SOURCE_AUTH_REQUIRED`，不把工作台账号登出。真实登录、共享组失效与 Cookie 解绑影响仍待人工验证。

## 模块边界

| 模块 | 目录 | 说明 |
| --- | --- | --- |
| CORE | `lib/core/{models,storage,source}`、`lib/app`、`lib/main.dart`、迁移聚合 | 公共模型、存储、来源接口、页面注册、离线判定 |
| 教务 | `lib/features/teaching` | 学期、课次与校历迁移（2–9） |
| 学习通 | `lib/features/assignments` | 作业与课程刷新范围迁移（10–19） |
| 内容 | `lib/features/content` | 通知、附件与资料目录迁移（20–29） |
| 待办 / 日历 | `lib/features/planner` | 待办与日历视图 |

- 功能目录只依赖 `lib/core`、`lib/app` 与生成客户端，不互相导入。
- 页面注册固定为：`TodoPage(workspace)`、`CalendarPage(workspace)`、`TeachingPage(workspace, store)`、`AssignmentsPage(workspace, store)`、`NoticesPage(workspace, store)`、`MaterialsPage(workspace, store)`；需要新依赖先向 CORE 提集成需求。
- 修改公共模型、数据库迁移入口或页面注册前，先与 CORE 和主控对齐。
