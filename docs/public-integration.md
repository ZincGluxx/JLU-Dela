# B—E 公共能力接入

本次 A 收口从 `4713408`（已合并 #44）建立独立 worktree；#37 邮箱本地、#38 身份、#39 文件、#40 笔记、#41 凭据键及 #42/#44 配套恢复均已在主线。新成员从包含这些结果的最新主线启动，按[工程说明](foundation.md#2-从新克隆到启动)迁移、运行 API 和 Flutter；确认当前环境与依赖，不把历史验收当作当前环境的成功。

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

业务路由接入现有 [Rust router](../server/src/http.rs)，复用状态、错误响应和中间件。业务负责人编写迁移，A 协调聚合；只新增迁移，不改已发布历史。上游 academic 迁移为 schema 6，[手机号迁移](../server/migrations/20261113000000_phone_accounts.sql) 推进到 7，[学生报告迁移](../server/migrations/20261113010000_student_reports.sql) 推进到 8；已合入的[文件迁移](../server/migrations/20261114000000_files.sql)将 `service_meta.schema_version` 从 `8` 推进到 `9`；本次[个人快照迁移](../server/migrations/20261114010000_personal_backups.sql)推进至 `10`，与客户端 SQLite 当前版本 `32` 分开管理。OpenAPI 变更通过工具生成客户端，不手改生成结果。

## 成员协作

| 提供者 | 公共或业务能力                             | 消费者                            |
| ------ | ------------------------------------------ | --------------------------------- |
| A      | 身份、公共壳与网络存储、文件及后续授权备份 | B—E                               |
| B      | 课程引用及学期、共享资料与访问规则         | C、D、E                           |
| C      | 平台课程及映射、平台私人资料和作业         | 对应学习流程；共享需走 B 明确发布 |
| D      | 社区发布互动、地图与公共信息               | 对应用户流程                      |
| E      | 邮箱、回放、笔记及摘要输入边界             | 对应学习流程                      |

2026-11-14 核对代码及 GitHub PR：B 尚无共享资料发布及学院授权业务，D 尚无多人社区，也没有对应开放 PR；现有教务、电子校务及来源资料缓存不等于这些共享业务。E 的笔记与凭据键已合并；[IMAP/SMTP PR #43](https://github.com/goya4140/JLU-Dela/pull/43)仍开放，尚无已合并的邮箱页面、应用装配或真实收发验收。本次不复制其改动。旧 Electron 原型不能作为多人社区或新版邮件完成证据。

个人数据本地优先，授权备份不自动公开；社区发布、共享资料和地图在线保存与个人备份分开。B / D 复用已合入的[公共文件能力](public-files.md)，在自己的业务事务中关联并逐次授权读取，上传不等于发布。E 的 owner、迁移占用与后续笔记/摘要协调见[本地数据](local-data.md#版本与迁移)，`MailAttachmentSource` 的本地字节及受控读取边界见[邮件附件](public-files.md#e-邮件附件)。本次笔记备份独立使用类型化 JSON 快照，不要求邮件或笔记先变为公共文件；[授权与冲突行为](local-data.md#个人笔记备份)由公共控制器提供，E 维护笔记适配。

### 收口交接

| 负责人 | 当前可复用入口                                                    | 仍由业务方交付并验证                                                                              |
| ------ | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| B      | 当前身份、`files::attach/read_for_business`、`WorkbenchApi.files` | 真实资料发布、撤销/改范围、目录及文件学院授权；交付后与 A 双账号联调                              |
| D      | 同一身份和文件入口；B 的资料 ID 引用边界                          | 多人帖子/评论、板块授权及资料引用；资料仍由 B 检查，不能复制受限文件扩大范围                      |
| E      | 本地邮箱/笔记、账号作用域；本次 `NoteBackupAdapter` 与设置备份    | 笔记/回放页面、来源课程缺失提示、适配字段评审；邮箱页面/装配/真实收发；本机附件不因复用文件而上传 |
| C      | 来源会话、课程模型及本地存储                                      | 确认自己的可导出字段与授权范围后接入；本次不创建空备份类型                                        |

只协调实际已合入的迁移：服务端 schema 10、SQLite 32。本次无 B/D 生产业务流程可联调，公共权限夹具不能代替业务验收。A 在该主题完成后转入集成评审、公共缺陷修复与发布协调；容器验收、业务接入及真实短信等必要项保留，不因收口标记完成。

## 验证

按实际改动运行相关本地检查，分别记录单元、夹具、数据库、真实来源和设备结果。用隔离测试身份推进权限测试，不将其放入生产。公共依赖未就绪时继续模块独立部分，并在[交付模板](team/B/08-handoff-template.md)列出提供者及所需最小能力。

测试入口：[账号](../server/tests/phone_accounts.rs)、[报告与权限](../server/tests/student_reports.rs)、[迁移](../server/tests/migrations.rs)。使用 `integration` 特性与隔离 `DATABASE_URL`；数据库夹具不等于官方报告验收。契约先更新 OpenAPI，再运行 `contracts/tools` 的 `npm run verify`；其 Git 漂移检查以已提交产物为基准，应区分预期未提交生成差异与生成失败。

文件交付历史见[本地验证记录](operations/public-files-verification.md)，本轮数据库及文件[配套恢复记录](operations/paired-backup-verification.md)提供可执行的隔离公共测试命令。业务尚未落地时验证关联、学院授权及恢复一致性，不增加生产授权替身；历史结果不重复计作新验收。

### 本次笔记接入验收（2026-11-14）

基线 `4713408`，独立任务分支 [Draft PR #45](https://github.com/goya4140/JLU-Dela/pull/45)。本次只用合成数据、全新 PostgreSQL 16.15 loopback 集群 `127.0.0.1:55440` 和新库 `closeout_http`；真实 API 在 `127.0.0.1:18089`。Rust 全目标集成测试 143 项通过、2 项条件忽略（#44 未变化的配套恢复、真实官方报告），格式、Clippy 与二进制构建通过；契约 `npm run verify` 的 lint、生成、漂移检查通过。

显式执行 [`notes_backup_http_test.dart`](../clients/flutter/test/notes_backup_http_test.dart) 1 项通过：独立磁盘目录 `client-a`、`client-b` 同账号，`client-other` 另一账号，均在本机 `C:/Users/ZincG/JLU-Dela-closeout-evidence` 下，不使用应用默认目录。同账号通过真实 HTTP 恢复 E 的 NoteStore 创建数据、保留课程/课次/回放/754000ms 时间位置、再次修改同步、并发冲突保留双方、再选合并内容上传、关闭及删除云副本；另一账号只读自己的空快照，旧端不能静默复活删除内容。在线删除后数据库检查正文为零、幂等回执无正文。此为真实存储/API 接入，不是实际学校回放来源或笔记编辑页面验收。

复现需先新建隔离库、迁移并启动 debug loopback API（显式开发验证码开关），再在 Flutter 目录设置 `BACKUP_TEST_API` 和全新的 `BACKUP_TEST_DATA_DIR`，执行 `flutter test test/notes_backup_http_test.dart`。测试只创建合成账号与笔记，不删库；重复验收另取新库和目录。控制器、导入事务及界面回归分别覆盖未授权零上传、磁盘重开、不确定请求精确重试、网络失败保本地、旧回执确认、冲突副本再次编辑恢复、退出/切号/在途结果与弹窗文字隔离；Windows x64 真实设备测试另行通过 1 项，逻辑视口 1264×681，使用同一隔离 HTTP API 和 `windows-a` / `windows-b` 独立目录，实际点击授权、手动同步与确认恢复；非学校来源验收。界面分别在 375/800/1100/1920 宽及 1.4 倍字体下通过布局回归，[设置截图](client/notes-backup-settings.png)与[授权截图](client/notes-backup-consent.png)仅含合成笔记。最终全量数量以 PR 实际记录为准。

Docker daemon 再次检查仍无管道，未执行容器验收，见[环境核对](operations/paired-backup-verification.md#a-收口环境核对44-合并后)。真实短信供应商继续暂缓，正式开放手机号注册前须由维护者补齐供应商与投递验收；没有新增身份要求或测试资格生产接口。

### 历史主线复验（2026-11-13）

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
