# A01 工程底座启动与交接

状态：本地服务、迁移、契约生成、Flutter Windows 构建与真实诊断页已验证。Compose 启动冒烟在 CI 执行，本机没有 Docker daemon。

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
- 当前迁移创建 `service_meta`，写入 `schema_version=1`；`GET /health/ready` 依赖该行。
- 独立命令：`cargo run --bin migrate`；Compose 使用一次性 `migrate` 服务。
- API 进程不执行迁移。发布时先跑迁移，再滚动 API；回滚前确认旧版本兼容当前 schema。
- 新迁移由领域作者提出，A 审核；不要在已发布迁移上直接改 SQL。

## 5. 目录与 owner

| 目录                                                                                                                                                                       | Owner   | 边界                                     |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ---------------------------------------- |
| `server/src/{config,db,error,http,health,meta,state,response,logging}`、`migrations/`、`infra/`、`.github/workflows/foundation-ci.yml`、`contracts/`、`docs/foundation.md` | A       | 公共契约、身份权限、发布与合并           |
| `server/src/connectors/{iedu,chaoxing,oa}`、`server/src/{teaching,assignments,notices,materials}`                                                                          | B/C/D   | 各自校园来源与业务模块                   |
| `clients/flutter/lib/features/{teaching,assignments,content,planner}`                                                                                                      | B/C/D/E | 各自业务页面，先消费契约夹具             |
| `clients/flutter/lib/{app,core}`、`contracts/openapi.yaml`                                                                                                                 | A       | 公共主题、路由入口、API 客户端与契约总审 |
| `server/src/{todos,calendar}`、`clients/flutter/lib/features/planner`                                                                                                      | E       | 待办、幂等、冲突与日历聚合               |

具体任务映射见工作区的 `output/planning/JLU-Dela-Development-Plan.md`。该规划文档由用户维护，当前未纳入本 PR。

## 6. 新模块如何接入

### 路由与状态

1. 在 `server/src/` 新建实际使用的领域模块，例如 `todos/`，不要预建空目录或通用 Repository/Service 基类。
2. Handler 使用 `State<AppState>` 获取 `PgPool`；返回 `Result<Json<ApiResponse<T>>, AppError>` 时沿用统一包装与错误响应。
3. 在 `server/src/http.rs` 注册路由，统一挂到 `/api/v1` 下；HTTP 契约先改 `contracts/openapi.yaml` 并生成客户端。
4. 需要新配置时在 `config.rs` 增加带默认值的变量并校验；不要把秘密写进代码或日志。
5. 需要新错误码时扩展 `AppError`，保持 `{error:{code,message,request_id,retryable,fields}}` 结构。
6. 需要迁移时新增 `server/migrations/<timestamp>_<name>.sql`，同步更新 `service_meta.schema_version`（由迁移负责）并补集成测试。

### Flutter

1. 业务页面放在 `lib/features/<domain>/`，公共主题与 `AppShell` 从 `lib/app/` 复用。
2. 新接口必须先进入 `contracts/openapi.yaml`，再生成 `jlu_dela_api`；不要在客户端手写重复 DTO。
3. 统一错误映射在 `lib/core/api/api_failure.dart`；新错误码在展示层给出可读文案。
4. 当前没有引入路由/状态管理库：单页诊断骨架使用 `StatefulWidget + FutureBuilder`。出现第二个真实页面时再选型并记录理由，不为简单页面预建层级。

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
- OpenAPI 3.0.3 契约、Redocly 校验、锁定版本的 Dart 客户端与漂移检查。
- Flutter Windows 构建、桌面/窄屏布局、真实健康接口诊断、失败重试。
- Compose 本地栈、Caddy 入口、内部 PG/Redis、健康检查、持久卷、staging 覆盖模板；配置已在本机校验，启动冒烟由 CI 执行。

尚未实现，不能标记为完成：

- 应用身份、登录、权限、校园来源连接。
- Redis 会话/限流/缓存；Compose 中的 Redis 当前未被 API 使用。
- 课表、作业、通知、资料、待办、日历、笔记、邮箱、AI、社区等业务接口。
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

## 10. 验证命令

```sh
# Rust
cd server
cargo fmt --all -- --check
cargo clippy --all-targets --all-features -- -D warnings
DATABASE_URL='postgres://.../jlu_dela_test' cargo test --all-targets --features integration
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
- **A**：A02 身份与连接/同步公共机制、A03 部署/备份门禁；A01 PR 合并前补齐人工评审与分支保护。

## 12. 分支与 CI

- 开发分支：`codex/a01-foundation`；禁止直接推送 `main`，禁止自动合并。
- 新增检查名称：`Server (Rust)`、`Contracts (OpenAPI)`、`Flutter (Windows)`、`Infra (Compose)`、`Foundation required`。
- 旧工程检查保留在现有 workflow 中；两者都应作为必需检查配置。
- 分支保护、必需检查、CODEOWNERS 与人工审批需要主开发在仓库设置中落实；本 PR 不修改远程保护设置。
