# B—E 公共能力接入

认证与公共接入主线基线为 `9fcb1d6`（PR #38，包含 `b68bb86` 及会话修复 `96ab7b8`）。PR #35 提供可信身份边界，PR #36 只交付团队文档，PR #37 为 E 的邮箱本地能力；手机号及报告代码由 #38 交付，不依赖原工作区未提交文件。新成员从该提交或包含它的后续主线启动，按[工程说明](foundation.md#2-从新克隆到启动)迁移、运行 API 和 Flutter。各成员应确认运行环境与依赖，不把历史验收当作当前环境的成功。

## 身份

Widget 通过 [`SessionScope.of(context)`](../clients/flutter/lib/core/auth/session_scope.dart) 使用同一个 [`SessionController`](../clients/flutter/lib/core/auth/session_controller.dart)，非 Widget 注入该控制器。只有 `authenticated` 表示当前在线身份已确认；`currentUser.id` 用于个人数据归属，`studentVerified` 与 `college` 用于展示，不用离线快照代替在线授权。退出和切号通过 `registerPrivateCache` 清理模块私有缓存，异步结果遵守账号生命周期。来源平台状态继续使用 [`SourceContext`](../clients/flutter/lib/core/source/source_context.dart) / `SourceSessionRegistry`，与应用账号分开。

服务端从 [`AuthenticatedUser`](../server/src/auth/extractor.rs) 取得当前账号；全校学生内容调用 `require_student()`，学院内容调用 `require_college(业务对象的可信学院 ID)`。业务目录、详情、文件和社区引用都要在所属业务服务端判断权限，不信任请求体自报的学院或作者资格。[会话认证](../server/src/auth/session.rs) 检查令牌过期、会话撤销和账号禁用，再读取报告核验记录；报告核验不自动过期。

## 当前产品选择

手机号验证码建立或登录应用账号，手机号负责账号唯一性；同一学籍报告可用于多个手机号账号。[报告解析器](../server/src/auth/student.rs) 精确匹配学校“吉林大学”，学院只取真实“分院”字段，不猜测；不处理学生唯一标识、学号、姓名或生日，不限制学籍状态、不自动过期或要求重复核验。结果仅表示曾核验吉林大学学籍报告，不证明本人、报告持有人或实时在读。用户名、密码及范围见[共同决定](team/B/07-current-decisions.md)和[完整计划](sources/开发完整内容.md)。账号设置与报告核验由 A 主责，B—E 不重复实现，也不额外增加 CAS、校邮或本人比对流程。

客户端调用 `SessionController.updateAccount` / `verifyStudentReport`，成功后重新读取 `/me`。生成入口见 [Dart API](../contracts/generated/dart/lib/api.dart)：`AuthApi.sendPhoneCode`、`loginWithPhone`，`MeApi.updateAccount`、`verifyStudentReport`；端点和字段以 [OpenAPI](../contracts/openapi.yaml) 为准。可选请求字段用 `Optional` 表达省略，不用空字符串代替未修改；旧响应缺失 `username` / `passwordSet` 时按未设置处理。普通资料接口不能写入手机号、学生状态或学院资格。

[`SmsSender`](../server/src/auth/phone.rs) 尚无真实供应商实现，生产默认不可用。本地固定码 `114514` 仅允许显式 `DEV_SMS_FIXED_CODE_ENABLED=true`、debug 构建及 loopback 监听；release 或非 loopback 拒绝启动。`data.dev_mode` 可省略，缺失按 `false`；为 `true` 仅提示“本地开发验证码已准备好”，不表示短信已发送，响应不返回验证码。未配置/发送失败分别为 `503 SMS_UNAVAILABLE` / `SMS_SEND_FAILED`。

报告无效/非吉林大学分别为 `422 STUDENT_REPORT_INVALID` / `STUDENT_NOT_ELIGIBLE`；受限、解析失败或上游不可用分别为 `503 STUDENT_REPORT_RESTRICTED` / `STUDENT_REPORT_PARSE_FAILED` / `STUDENT_VERIFICATION_UNAVAILABLE`，不将来源故障当作应用退出，不绕过访问控制。报告码不作为学生 ID，不保存真实报告码、页面样本或个人数据到日志、仓库、夹具或普通备份。任务文档不能代替短信提供方、真实报告或目标设备的验收记录；公共接口缺失时向 A 提出具体需要，不在生产使用测试成功替身。

## 页面、来源与存储

沿用 [`AppDestination` / `AppPageBuilder`](../clients/flutter/lib/app/app_shell.dart)，通过 [`JluDelaApp.pages`](../clients/flutter/lib/app/app.dart) 注册页面。应用 API 复用 [`WorkbenchApi.apiClient`](../clients/flutter/lib/core/auth/workbench_api.dart) 及其令牌刷新；来源通过 `SourceContext` 接入，不复用应用令牌。[`buildWorkbenchData`](../clients/flutter/lib/app/local_workbench.dart) 和 [`LocalWorkspace`](../clients/flutter/lib/core/storage/local_workspace.dart) 提供账号作用域的数据入口，本地迁移在 [`local_migrations`](../clients/flutter/lib/app/local_migrations.dart) 集成。必要公共修改列出调用点，与 A 及直接消费者对齐，不新建全局认证、数据库或主题。

业务数据使用当前账号作用域；退出和切号后清理本模块私有内存状态。来源读取按现有已确认执行位置推进，来源失效不等于应用账号退出；失败保留上次成功内容。

业务路由接入现有 [Rust router](../server/src/http.rs)，复用状态、错误响应和中间件。业务负责人编写迁移，A 协调聚合；只新增迁移，不改已发布历史。上游 academic 迁移为 schema 6，[手机号迁移](../server/migrations/20261113000000_phone_accounts.sql) 推进到 7，[学生报告迁移](../server/migrations/20261113010000_student_reports.sql) 推进到 8；认证基线 `service_meta.schema_version=8`，本轮新增[文件迁移](../server/migrations/20261114000000_files.sql)推进到 `9`，不是客户端 SQLite 版本。OpenAPI 变更通过工具生成客户端，不手改生成结果。

## 成员协作

| 提供者 | 公共或业务能力                             | 消费者                            |
| ------ | ------------------------------------------ | --------------------------------- |
| A      | 身份、公共壳与网络存储、文件及后续授权备份 | B—E                               |
| B      | 课程引用及学期、共享资料与访问规则         | C、D、E                           |
| C      | 平台课程及映射、平台私人资料和作业         | 对应学习流程；共享需走 B 明确发布 |
| D      | 社区发布互动、地图与公共信息               | 对应用户流程                      |
| E      | 邮箱、回放、笔记及摘要输入边界             | 对应学习流程                      |

个人数据本地优先，授权备份不自动公开；社区发布、共享资料和地图在线保存与个人备份分开。公共文件已新增[最小接入说明](public-files.md)：B / D 先上传取得文件 ID，再在自己的业务事务中关联；权限在所属业务每次获取时检查，上传不等于发布。未接入业务不提供成功下载路由。备份机制继续按真实调用需要推进，不因文件可上传就宣称授权备份恢复已交付。

## 验证

按实际改动运行相关本地检查，分别记录单元、夹具、数据库、真实来源和设备结果。用隔离测试身份推进权限测试，不将其放入生产。公共依赖未就绪时继续模块独立部分，并在[交付模板](team/B/08-handoff-template.md)列出提供者及所需最小能力。

测试入口：[账号](../server/tests/phone_accounts.rs)、[报告与权限](../server/tests/student_reports.rs)、[迁移](../server/tests/migrations.rs)。使用 `integration` 特性与隔离 `DATABASE_URL`；数据库夹具不等于官方报告验收。契约先更新 OpenAPI，再运行 `contracts/tools` 的 `npm run verify`；其 Git 漂移检查以已提交产物为基准，应区分预期未提交生成差异与生成失败。

文件增量及最终全量检查见[本地验证记录](operations/public-files-verification.md)，历史记录不重复作为新验收。

### 本轮主线复验（2026-11-13）

基于干净 `9fcb1d6` worktree，Rust 格式、全目标全特性 Clippy 及隔离 PostgreSQL 16.15 全目标集成测试通过（124 项通过，1 项真实报告外网测试忽略）。测试数据库为本轮单独初始化的集群，不使用已有业务库。契约 lint、生成通过；Windows 生成清单仅 CRLF/索引状态导致首次漂移检查失败，确认无内容差异并刷新索引后漂移检查通过。依赖安装报告 7 项 npm 审计告警（2 moderate、5 high），未擅自升级锁定工具链。release 配置测试 7 项通过，确认生产构建拒绝开发固定码。Flutter 静态分析无问题，认证及账号隔离相关 13 个测试文件共 141 项通过。另修复在途刷新已轮换服务端令牌、客户端尚未收到响应时 `/me` 和账号设置误退出的问题；18 个确定性回归覆盖成功、网络失败、撤销和切号，修复前 12 个竞态用例复现失败，修复后相关 9 个文件 127 项通过，格式及静态分析通过。该增量未改变认证协议。真实报告及短信均未调用；下文历史报告验收不能代替本次结果。

### 已有验收记录（2026-11-13，原工作区）

以下均为 `C:/Users/ZincG/JLU-Dela` 先前 checkout 的真实结果，**不是本 PR 最新 upstream/main worktree 的通过记录**；合并上游 academic 迁移并调整为 schema 8 后，由集成负责人重跑，另记结果。

- Rust：格式、全目标全特性 Clippy 通过；隔离 PostgreSQL 16.15 上 `cargo test --all-targets --features integration` 110 项通过，1 项真实外网测试默认忽略；`cargo test --release --test config` 7 项通过，验证 release 拒绝开发固定码。覆盖旧数据迁移、旧凭据、短信消费/失败/超时、开发开关及学院权限，不含真实短信投递。
- 契约：lint、生成及连续生成 SHA256 一致性通过；`npm run verify` 的 Git 漂移阶段因未提交生成改动退出 1，不能记全绿。生成包 `dart analyze` 无 error，58 条模板 warnings，未手改生成代码。
- Flutter：格式、`flutter analyze` 通过；全量 `flutter test` 513 项通过，含受限提示、切号、开发模式及新报告规则。Windows Debug 实机集成 1 项通过，逻辑视口 1264×681，使用隔离身份及网络替身；不是全应用壳、真实短信/报告或人工多尺寸验收。此前 Windows Release 构建成功，不代表本 PR 重建。
- 真实报告：先由官方浏览器观察 DOM；Rust 显式透明应用 User-Agent 后，单独执行真实端到端测试 1 项通过。通过已认证 `POST /api/v1/me/student-verification` 完成查询、解析、保存，立即返回结果；同一令牌无需重登录即可从 `/me` 读到相同用户数据。使用 Rust 原生请求，无 shell 传输、浏览器 Cookie 或指纹伪装；不保证其他部署环境不受限。未保存真实报告码或页面样本。
### 最新上游 PR 基线复验

基于 upstream/main `04f9150` 保留校历与课程能力，新增迁移推进至 schema 8。Rust 格式、Clippy 及隔离数据库全量测试 124 项通过、1 项外网默认忽略；真实报告 HTTP 提交至 `/me` 单独执行 1 项通过，release 配置测试 7 项通过。Flutter 静态分析无问题，全量 580 项通过、1 项上游公开校历网络测试未配置而跳过，186 个 lib/test 文件格式检查无变化。契约 lint 与生成通过，生成内容保持标准工具输出。Windows 最新基线构建及平台测试结果在 PR 本地验证说明中单独记录，不沿用旧 checkout 结论。

- 待验收：真实短信供应商及投递、其他部署环境、业务方学院资料/社区授权与多人流程。短信仍需维护者确认供应商、接口区域、应用标识、签名、模板及密钥注入方式；密钥不进入仓库或聊天。
