# A01 工程底座启动与交接

状态：本地服务、迁移、契约生成、Flutter Windows 构建与真实诊断页已验证。Compose 启动冒烟在 CI 执行，本机没有 Docker daemon。公共应用壳已按暂定视觉基线交接；设备端校园可见登录仍在验证，真实学校认证需授权用户人工完成。

A02 已实现工作台会话生命周期（刷新、退出、当前用户、令牌轮换与撤销、认证上下文）。登录与激活入口尚未实现：工作台身份方案仍需人工确认，客户端不得假设邀请账号或学校统一认证。同步任务公共机制已落地（持久化、活跃任务复用、租约恢复与失败状态）；校园来源连接与真实来源适配尚未实现，未注册来源由创建接口明确拒绝。

本文对应规划 A01。新架构以 Flutter + Rust 为目标；`app/` 保留为旧 Electron 实现与行为参考。`AGENTS.md` 仍只由人类维护。

## 1. 工具链基线

| 工具              | 版本                                            | 位置                                    |
| ----------------- | ----------------------------------------------- | --------------------------------------- |
| Rust              | 1.98.1（`server/rust-toolchain.toml`）          | `server/`                               |
| Axum / SQLx       | 0.8 / 0.9                                       | `server/Cargo.lock`                     |
| Flutter / Dart    | 3.44.8 / 3.12.2                                 | `clients/flutter/`                      |
| Node.js           | 24.22.1（CI 与 `contracts/tools/package.json`） | 契约工具                                |
| OpenAPI Generator | 7.27.0                                          | `contracts/tools/openapitools.json`     |
| Redocly CLI       | 2.77.0                                          | `contracts/tools/package.json`          |
| PostgreSQL        | 16.15                                           | `infra/compose.yaml`                    |
| Redis             | 7.4.12                                          | 仅 Compose 提供，API 尚未使用           |
| Caddy             | 2.11.9                                          | 本地与 staging 入口                     |
| Docker Compose    | 2.24+                                           | staging 配置使用 `!override` / `!reset` |

## 2. 从新克隆到启动

### Compose（本地完整栈）

```sh
cd infra
cp .env.example .env
# 编辑 .env，替换两个密码占位值
docker compose --env-file .env -f compose.yaml up -d --build
curl http://127.0.0.1:8080/health/ready
curl http://127.0.0.1:8080/api/v1/meta
```

只暴露 Caddy 的回环端口。PostgreSQL 与 Redis 只在内部网络；需要本机调试时叠加 `compose.dev.yaml`，端口也只绑定 `127.0.0.1`。

```sh
docker compose --env-file .env -f compose.yaml -f compose.dev.yaml up -d
```

### 原生 Rust 服务

需要一个 PostgreSQL 16 数据库。API 不会自动执行迁移。

```sh
cd server
export DATABASE_URL='postgres://user:password@127.0.0.1:5432/jlu_dela?sslmode=disable'
export APP_BUILD_ID='local-dev'
cargo run --bin migrate
cargo run --bin jlu-dela-api
curl http://127.0.0.1:8080/health/live
```

### Flutter 客户端

服务默认地址为 `http://127.0.0.1:8080`，可用 `--dart-define=API_BASE_URL=...` 覆盖。

```sh
cd clients/flutter
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

Android 模拟器访问宿主机时使用 `http://10.0.2.2:8080`，真机使用局域网地址。客户端地址必须是 `http(s)://host[:port]`，不能带路径。

### 契约工具

```sh
cd contracts/tools
npm ci
npm run lint       # Redocly 校验 OpenAPI 3.0.3
npm run generate   # 生成 contracts/generated/dart
npm run drift      # 检查生成结果是否与提交一致
npm run verify     # lint + generate + drift
```

生成器与校验器版本已锁定；不要手改 `contracts/generated/dart`。

## 3. 环境变量

| 变量                               | 默认             | 说明                                    |
| ---------------------------------- | ---------------- | --------------------------------------- |
| `HTTP_HOST`                        | `127.0.0.1`      | 监听地址；容器内设为 `0.0.0.0`          |
| `HTTP_PORT`                        | `8080`           | 监听端口                                |
| `DATABASE_URL`                     | 必填             | PostgreSQL URL；配置错误不会回显口令    |
| `DATABASE_MAX_CONNECTIONS`         | `10`             | 1–100                                   |
| `DATABASE_ACQUIRE_TIMEOUT_SECONDS` | `5`              | 1–60                                    |
| `REQUEST_TIMEOUT_SECONDS`          | `15`             | 1–120；超时返回统一错误结构             |
| `MAX_BODY_BYTES`                   | `1048576`        | 1 KiB–16 MiB                            |
| `CORS_ALLOWED_ORIGINS`             | 空               | 逗号分隔的明确来源；拒绝 `*`            |
| `APP_BUILD_ID`                     | `dev`            | 镜像构建 commit 或发布标识，出现在 meta |
| `LOG_FORMAT`                       | `pretty`         | `pretty` 或 `json`；Compose 用 json     |
| `RUST_LOG`                         | `info,sqlx=warn` | tracing 过滤                            |

启动时配置错误会一次性列出变量名与原因。Rust 日志只记录 request_id、方法、路径、状态与耗时；不记录 Authorization、Cookie、请求体或完整数据库 URL。数据库 Debug 输出仅包含 host/port/database。Caddy 默认将 Cookie、Set-Cookie、Authorization、Proxy-Authorization 记为 REDACTED，Compose CI 会对该行为做回归检查。不要把令牌放进查询字符串。

## 4. 数据库迁移

- 迁移文件：`server/migrations/`，由 SQLx 顺序执行并记录在 `_sqlx_migrations`。
- `20261110000000_create_service_meta.sql` 创建 `service_meta`；`20261111000000_create_identity.sql` 创建 `users`、`sessions`；`20261111010000_create_todos.sql` 创建 `todos`、`idempotency_keys`；`20261111020000_create_sync_jobs.sql` 创建 `sync_jobs`。`schema_version` 依次推进到 `4`，`GET /health/ready` 依赖该行。
- `sync_jobs` 先落库再返回 202；同一用户、来源、资源和规范化 scope 的 queued/running 任务通过部分唯一索引复用。运行中的任务有 120 秒租约，进程中断后租约过期会重新排队，达到三次尝试上限后标记 `SYNC_INTERRUPTED`。
- 会话只保存访问令牌与刷新令牌的 SHA-256 摘要。访问令牌 15 分钟，刷新令牌 30 天；刷新时两者同时轮换，旧值立即失效；退出按会话撤销。
- 独立命令：`cargo run --bin migrate`；Compose 使用一次性 `migrate` 服务。
- API 进程不执行迁移。发布时先跑迁移，再滚动 API；回滚前确认旧版本兼容当前 schema。
- 新迁移由领域作者提出，A 审核；不要在已发布迁移上直接改 SQL。

## 5. 目录与 owner

| 目录                                                                                                                                                                                                                              | Owner   | 边界                                     |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ---------------------------------------- |
| `server/src/{config,db,error,http,health,json,meta,state,response,logging,auth}`、`server/src/{connections,sync}`（connections 计划；sync 已实现）、`migrations/`、`infra/`、`.github/workflows/foundation-ci.yml`、`contracts/`、`docs/foundation.md` | A       | 公共契约、身份权限、发布与合并           |
| `server/src/connectors/{iedu,chaoxing,oa}`、`server/src/{teaching,assignments,notices,materials}`                                                                                                                                 | B/C/D   | 各自校园来源与业务模块                   |
| `clients/flutter/lib/features/{teaching,assignments,content,planner}`                                                                                                                                                             | B/C/D/E | 各自业务页面，先消费契约夹具             |
| `clients/flutter/lib/{app,core,features/auth}`、`contracts/openapi.yaml`                                                                                                                                                          | A       | 公共主题、路由入口、API 客户端与契约总审 |
| `server/src/{todos,calendar}`、`clients/flutter/lib/features/planner`                                                                                                                                                             | E       | 待办、幂等、冲突与日历聚合               |

具体任务映射见工作区的 `output/planning/JLU-Dela-Development-Plan.md`。该规划文档由用户维护，当前未纳入本 PR。

## 6. 新模块如何接入

### 路由与状态

1. 在 `server/src/` 新建实际使用的领域模块，例如 `todos/`，不要预建空目录或通用 Repository/Service 基类。
2. Handler 使用 `State<AppState>` 获取 `PgPool`；需要当前用户时加入 `AuthenticatedUser`，JSON 请求体用 `ApiJson<T>`（拒绝未知字段，映射 415/422）。成功返回 `Json(ApiResponse::new(data, request_id))`，失败调用 `error.response(&request_id)`；不要另写错误包装。
3. 在 `server/src/http.rs` 注册路由，统一挂到 `/api/v1` 下；HTTP 契约先改 `contracts/openapi.yaml` 并生成客户端。
4. 需要新配置时在 `config.rs` 增加带默认值的变量并校验；不要把秘密写进代码或日志。
5. 需要新错误码时扩展 `AppError`，保持 `{error:{code,message,request_id,retryable,fields}}` 结构。401 只表示工作台身份问题（`AUTH_REQUIRED`、`INVALID_TOKEN`、`TOKEN_EXPIRED`、`SESSION_REVOKED`）；校园来源失效必须用 409 `SOURCE_AUTH_REQUIRED`，不能把用户登出工作台。
6. 需要迁移时新增 `server/migrations/<timestamp>_<name>.sql`，同步更新 `service_meta.schema_version`（由迁移负责）并补集成测试。

认证上下文的最小用法：

```rust
pub async fn list_example(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(request_id_value): Extension<RequestId>,
) -> Response {
    let request_id = request_id(&request_id_value);
    match example::list(&state.pool, user.user_id).await {
        Ok(data) => Json(ApiResponse::new(data, request_id)).into_response(),
        Err(error) => error.response(&request_id),
    }
}
```

测试或运维需要创建会话时使用 `auth::session::issue_for_user(&pool, user_id)`。该函数只签发会话，不创建用户；用户创建随身份方案确定后接入。

来源同步通过 `SyncRegistry` 注册：`AppState::with_sync(pool, build_id, registry)` 注册来源与受支持资源，`SyncHandler` 返回 `SyncOutcome` 或 `SyncFailure`（稳定错误码与是否可重试）。`SyncContext` 只携带任务数据，handler 需要的连接池等依赖在注册时由 handler 自己持有。只有已验证的来源能力才注册；未注册来源的 `POST /api/v1/sync-jobs` 返回 422 `UNSUPPORTED_SOURCE`，未注册资源返回 422 `UNSUPPORTED_RESOURCE`，都不会创建任务。worker 在 registry 为空时不启动；真实来源注册时需在 `main` 中改用 `AppState::with_sync`，并确认 worker 生命周期与优雅退出。handler 不保存上游原文、URL、Cookie 或学号。

### Flutter

1. 业务页面放在 `lib/features/<domain>/`，公共主题、`AppShell` 与玻璃表面从 `lib/app/` 复用。业务目录只依赖 `lib/app/`、`lib/core/` 与生成客户端，不互相导入其他业务目录。
2. `AppShell` 负责桌面侧栏、顶部工具栏、手机底部导航与手机端「更多」入口。宽度 `>= 768` 使用侧栏（1280 以上 224，以下 184），更窄使用底部导航；未注册的 `AppDestination` 显示「此功能尚未开放」，不展示示例业务数字。
3. 页面接入通过 `AppDestination -> AppPageBuilder` 注册：在 `lib/app/app.dart` 的 `pages` map 中增加一行 `AppDestination.<入口>: (context) => const <页面>()`。业务页面只新增自己的 `lib/features/<domain>/` 文件；公共注册行随页面小 PR 一起提交，由 A 审核，不在业务目录另建导航或主题。
4. 导航、工具栏与底部栏使用 `GlassSurface`（`glassEnabled=false` 切换为实色，布局不变）；手机业务页的日期选择条等窄条也可复用 `GlassSurface`。课程、作业与正文等内容面使用实色 `AppTheme.surfaceDecoration` 或白色 `Material`，不要用 `GlassSurface` 包裹正文。颜色、圆角与间距取 `AppTheme` / `AppSpacing`，不要在新页面另建 token 表。
5. 新接口必须先进入 `contracts/openapi.yaml`，再生成 `jlu_dela_api`；不要在客户端手写重复 DTO。
6. 统一错误映射在 `lib/core/api/api_failure.dart`；新错误码在展示层给出可读文案。
7. 当前没有引入路由/状态管理库：`MaterialApp` + `StatefulWidget` 管理当前入口与玻璃开关。页面注册不是路由器，没有深链、多标签或 URL 还原需求；出现第三个独立应用级状态域或 B–E 多页导航时再选型。
8. 客户端令牌计划存入平台安全存储（例如 `flutter_secure_storage`），SQLite 不保存刷新令牌。本次未引入该依赖，也未实现登录/恢复页面。
9. 设备端校园登录尚在验证，公共层不保存 Cookie；未获人工决定前不把来源会话上传服务端，也不开放无认证的私有业务 API。

## 7. 一次完整请求路径

```text
Flutter DiagnosticsPage
  -> DiagnosticsService
  -> 生成客户端 MetaApi / HealthApi
  -> package:http
  -> Caddy (本地 127.0.0.1:8080)
  -> Axum Router
       - CORS
       - X-Request-Id 生成/透传
       - request 日志（无 header/body）
       - 统一超时与错误规范化
  -> handler
  -> SQLx PgPool
  -> PostgreSQL service_meta
  -> {data, meta.request_id} 或 {error, ...}
  -> Dart 模型 / ApiFailure
  -> 诊断页展示加载、成功、数据库未就绪、失败与重试
```

`/health/live` 不访问数据库；`/health/ready` 查询 `service_meta.schema_version`。数据库不可用时 ready 返回 503，live 仍为 200。

## 8. 当前能力与限制

已实现并验证：

- Rust 配置校验、PostgreSQL 连接池、独立迁移命令与优雅退出信号处理（退出日志由 Compose CI 验证）。
- `GET /health/live`、`GET /health/ready`、`GET /api/v1/meta`。
- request_id、统一 JSON 错误、CORS 白名单、请求体限制、请求超时、结构化日志与敏感值过滤。
- 工作台会话：`users`/`sessions` 迁移、访问与刷新令牌签发及轮换、退出撤销、Bearer 认证上下文、`GET /api/v1/me`、`POST /api/v1/auth/refresh`、`POST /api/v1/auth/logout`。双用户隔离、令牌过期、刷新复用拒绝与退出撤销由 8 个真实 PostgreSQL 集成测试覆盖。
- 待办：`todos`/`idempotency_keys` 迁移、CRUD、幂等创建、`revision` 乐观并发与分页（E01）。`GET /api/v1/calendar` 契约已固定，聚合仍是等待 B/C 来源的骨架。
- 同步任务公共入口：`sync_jobs` 迁移、`POST /api/v1/sync-jobs`、`GET /api/v1/sync-jobs/{id}`、scope 规范化与活跃任务复用、120 秒租约恢复、失败状态与 `SYNC_INTERRUPTED`。复用、跨用户 404、worker 成功/失败、租约重排与三次上限由 7 个真实 PostgreSQL 集成测试覆盖。当前没有注册任何来源适配器，创建任务返回 422。
- OpenAPI 3.0.3 契约、Redocly 校验、锁定版本的 Dart 客户端与漂移检查。
- Flutter Windows 构建、桌面/平板/窄屏布局、真实健康接口诊断、失败重试。
- 公共应用壳：桌面玻璃侧栏与顶部工具栏、手机玻璃底栏与「更多」入口、`AppDestination -> AppPageBuilder` 页面注册、玻璃/实色同布局切换、未接入页面明确显示尚未开放。窗口缩放、文字缩放（2.0）与 390/820/1280 宽度由 widget 测试覆盖；Windows release 构建通过。Android 未构建、未真机验证。

当前壳截图：[桌面 1280×720](client/app-shell-desktop.png) · [手机 390×844](client/app-shell-mobile.png)。两张图来自 Windows release 构建，页面显示「此功能尚未开放」，不含业务数据。
- Compose 本地栈、Caddy 入口、内部 PG/Redis、健康检查、持久卷、staging 覆盖模板；配置已在本机校验，启动冒烟由 CI 执行。

尚未实现，不能标记为完成：

- 激活与登录入口、用户创建/邀请流程：工作台身份方案尚未获人工批准，当前只交付与方案无关的会话生命周期。
- 校园来源连接 challenge/action 与来源会话托管；`sync-jobs` 机制已存在，但没有来源适配器，不能宣称任何来源已接入。
- 客户端会话安全存储与登录页面；Flutter 当前有公共应用壳、设置与诊断页，业务页面和登录页尚未接入。
- Redis 会话/限流/缓存；Compose 中的 Redis 当前未被 API 使用。
- 课表、作业、通知、资料、日历聚合、笔记、邮箱、AI、社区等业务接口。
- 对象存储、备份恢复演练、监控告警、生产发布。
- 自动更新与六端签名/分发。

平台状态：

| 平台                | 状态                                                              |
| ------------------- | ----------------------------------------------------------------- |
| Windows x64         | 已真实构建并连接本地服务运行                                      |
| Android             | 本机有 SDK，部分 license 未接受；未构建 APK，未真机验证           |
| macOS / Linux / iOS | 未在当前环境构建或运行                                            |
| HarmonyOS           | 未安装 Flutter 鸿蒙工具链；未验证 HAP、插件或签名，不能称为已适配 |

## 9. staging 需要补齐的信息

以下信息未提供，文档不猜测地址或凭据：

- 服务器主机、SSH/部署账号、CPU/内存/磁盘与备份位置。
- staging 域名、DNS 控制权、TLS 证书方式（Caddy 自动签发或已有证书）。
- 镜像仓库地址与推送凭据；固定镜像 digest 与 commit SHA 的登记方式。
- PostgreSQL/Redis 的连接、账号、备份与恢复责任。
- S3 兼容对象存储 endpoint、bucket、region、凭据与访问策略（后续任务）。
- 监控、日志收集、告警接收人、发布审批人与回滚窗口。

未获明确授权前不部署生产，不运行会破坏现有数据库或卷的命令。本机 Compose 启动冒烟因缺少 Docker daemon 未执行；CI 的 `Infra (Compose)` 会执行构建、启动、健康检查、内部端口检查与优雅退出检查。

A03 的缺项清单、发布顺序、备份/恢复与回滚命令见 [operations/release-readiness.md](operations/release-readiness.md)。

## 10. 验证命令

```sh
# Rust
cd server
cargo fmt --all -- --check
cargo clippy --all-targets --all-features -- -D warnings
DATABASE_URL='postgres://.../jlu_dela_test' cargo test --all-targets --features integration
DATABASE_URL='postgres://.../jlu_dela_test' cargo test --test auth --features integration
DATABASE_URL='postgres://.../jlu_dela_test' cargo test --test sync --features integration
cargo build --locked --release --bins

# Flutter
cd clients/flutter
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build windows --release

# 契约
cd contracts/tools
npm ci
npm run verify

# Compose
cd infra
cp .env.example .env
docker compose --env-file .env -f compose.yaml config
docker compose --env-file .env -f compose.yaml up -d --build
bash smoke.sh
```

## 11. 五人下一步

- **B（教务/课表）**：先提交学期与课表 OpenAPI 草案和脱敏夹具；复用 `AppState.pool`、`AppError`、`ApiResponse`，在 `http.rs` 注册 teaching 路由；Flutter 页面先用夹具跑通。
- **C（学习通/作业）**：先定义课程偏好、作业状态与截止时间契约；接入来源前先补认证/连接公共机制（A02），不要把开发者 Cookie 写入服务。
- **D（通知/资料）**：先提交通知列表/详情与资料目录契约；附件访问必须做用户可见范围检查，后续再接对象存储。
- **E（待办/日历）**：先定义 Todo revision/幂等键与日历判别联合；复用 A01 的请求超时、错误结构和 Flutter 错误映射。
- **A**：A02 会话核心与 `sync-jobs` 公共机制已交付；激活/登录等待身份方案确认，来源连接与真实来源适配在人工决定执行位置后推进。A03 部署/备份/恢复另开任务，不混入身份 PR。
- **B/C/D**：2026-11-11 已提交来源授权的只读证据与契约需求；B01/C01/D01 仍阻塞于来源授权执行位置与人工实测条件，先用夹具推进允许的部分。

## 12. 分支与 CI

- A01 合并提交：`8d590f4`（`upstream/main`），A01 分支提交 `c17f8ec`。
- A02 身份分支 `codex/a02-auth-session` 已由 PR #11 合并；同步机制由 `codex/a02-sync-jobs-integration` 基于 `upstream/main` 单独提 PR，来源连接在决策后另开分支。
- 开发分支不得直接推送 `main`，禁止自动合并。
- PR 合并检查使用 `Foundation required`。只有 `Server (Rust)`、`Contracts (OpenAPI)`、`Flutter (Windows)` 和 `Infra (Compose)` 均成功时才通过。旧 Electron macOS 检查按需手动运行。
- 分支保护、必需检查、CODEOWNERS 与人工审批需要主开发在仓库设置中落实；本 PR 不修改远程保护设置。

## 13. A02 待人类决定与验收缺口

以下问题在 2026-11-11 仍没有仓库内证据表明已获批准，不能把提案当作实现依据：

| 决策             | 现状与证据                                                                                                                                                                           | 影响                                                                 |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------- |
| 工作台身份       | `API-Contract.md` 的“受控邀请账号”是提案；仓库没有学校 OAuth/OIDC 证据                                                                                                               | 激活、登录与用户创建未实现；刷新、退出、`/me` 与会话撤销已实现       |
| 来源授权执行位置 | 旧 Electron 只证明“可见学校窗口 + 用户手工完成 CAS/登录”的客户端会话；没有服务器可达或无人交互登录证据；Flutter 当前没有 webview 依赖                                                | connections/challenge、来源会话托管与 B/C/D 来源实现阻塞；sync-jobs 公共机制已实现但未注册 adapter |
| 正式应用壳与视觉 | 诊断页品牌侧栏明确不是正式业务导航；没有批准稿                                                                                                                                       | 登录页、导航与主题基线不落地                                         |
| 来源实测条件     | 教务：文档自述本人会话可用，缺新用户、自然过期与换账号；学习通：发起人账号 33 门课程，缺第二账号与过期；电子校务：匿名列表与 6 篇正文可读，网络位置未核实，附件必须由学校页面执行 JS | 来源只能标记“未验证/未接入”，不能宣称已连接                          |

已确认的来源边界：

- 教务、电子校务、学在吉大共享 `jlu.edu.cn` Cookie；学习通独立认证。断开某一来源若清空共享会话，会影响其他来源，契约必须写清影响范围。
- 来源失效与网络失败必须分开。旧实现对 403、结构变化和超时的分类不完整，不能直接当作新契约语义。
- 电子校务附件要在学校页面内执行两段 POST；学习通资料需要 C 的会话与受权入口。两者都不能用开发者 Cookie 代填新用户流程。

人工设置缺口：

- `GET /repos/goya4140/JLU-Dela/branches/main/protection` 在本次检查中返回 404；主分支保护未由 AI 修改。
- PR 模板要求的人类前置四问尚未回答；身份 PR 与 sync-jobs 集成 PR 均保持 draft，等待人类补充与批准。

A02 验收缺口：

- 没有已批准的来源接入，sync-jobs 只能验证持久化、复用、恢复与失败状态；真实来源的 scope 粒度、完整性判定、退避数值与错误映射仍未验证，不得用固定成功响应替代。设备端领取/完成任务（`executor=device`）属于后续契约，需需求确认后另开 PR。
- `sync-jobs` 的 worker 尚无 handler 超时、panic 捕获与监督；接入真实来源前需补齐，否则挂起或 panic 的 handler 会阻塞单 worker。
- 校园来源连接、Flutter 登录与连接页在决策后另开 PR；本文不把诊断页当作正式产品设计。
