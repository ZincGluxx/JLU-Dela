# 公共身份边界

## 当前用户

应用账号通过手机号验证码登录、兼容的邀请激活及密码登录、刷新和退出流程管理；`GET /api/v1/me` 保留 `id`、`display_name`、`timezone`，提供：

- `username`：可空的应用用户名；旧响应可省略。
- `password_set`：是否已设置密码；旧响应可省略，消费者按 `false` 处理。
- `student_verified`：服务端是否曾核验吉林大学学籍报告；不代表实时在读、本人或报告持有人核对。
- `college`：可信学院关联，包含稳定的 `id` 和展示用 `name`；缺失时明确为 `null`。

`PATCH /api/v1/me/account` 仅接受用户名、昵称和新密码，不接受手机号、学生状态或学院字段。`POST /api/v1/me/student-verification` 只接受 `report_code`；报告学校和学院核验由服务端完成；手机号负责账号唯一性，同一报告可以用于多个手机号账号。邀请激活、手机号或密码登录、学校页面可访问和来源连接均不授予学生或学院资格。

已通过真实官方浏览器查询观察报告结构，服务端解析按学校为吉林大学及学院字段核验；本机已通过 Rust 真实端到端核验：显式设置透明应用 User-Agent 后，官方查询、解析、保存、会话读取及 `/me` 测试通过。此前默认请求标识返回 HTTP 403；若后续仍遇受限响应，保留 `STUDENT_REPORT_RESTRICTED`，不绕过访问控制。不要求学生唯一标识、报告有效截止时间或特定学籍状态，不自动过期或要求重复核验。不处理姓名、生日，不保存真实报告码、页面样本或个人数据；报告码不能作为学生 ID。接口和夹具不能替代真实端到端验收。

真实短信提供方尚未实现。显式开启 `DEV_SMS_FIXED_CODE_ENABLED=true` 仅允许 debug 构建绑定 loopback 时使用本地固定码；release 或非 loopback 启动拒绝此配置。响应 `dev_mode=true` 仅说明本地开发验证码已准备好，不代表已发短信；生产不能展示开发固定值。

学院内部资料、文件和社区板块仍须在业务服务端根据当前账号及可信结果授权，不能相信客户端字段、学院名称或页面隐藏。公共入口与 B—E 接入职责见[公共能力接入](public-integration.md)。

## Flutter 消费入口

B—E 的页面通过 `SessionScope.of(context)` 取得既有 `SessionController`，读取 `phase` 和 `currentUser`；该上下文只是同一控制器的访问入口，不维护第二份用户状态。非 Widget 调用方继续注入同一个控制器。

- `currentUser.id` 用于账号归属；`studentVerified` 和 `college` 用于状态与权限提示。
- 登录、恢复及令牌刷新均读取 `/me`。退出清空当前用户，切换账号替换完整用户模型并沿用既有个人缓存隔离。
- `phase` 非 `authenticated` 时不能把保留的用户快照视作当前在线确认。设置页此时显示无法确认学生及学院状态。
- 本地 `CachedIdentity.verifiedAtUtc` / `recordVerified` 的历史命名仅指应用账号曾经由 `/me` 确认，不代表学生验证；数据库字段保持兼容，缓存不保存学生或学院资格。
- 来源平台连接继续通过既有 `SourceContext` / `SourceSessionRegistry` 管理，各来源独立，不因应用登录或学生状态变化而全部变成已连接。

未验证学生仍可按现有规则使用本地工作台；离线缓存不是实时服务端授权证明。测试中的已验证身份及学院仅为夹具，不进入生产路径。
