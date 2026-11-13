# 公共身份边界

## 当前用户

应用账号通过现有激活、登录、刷新和退出流程管理；`GET /api/v1/me` 保留 `id`、`display_name`、`timezone`，增加：

- `student_verified`：服务端是否已可信确认吉林大学学生身份。
- `college`：可信学院关联，包含稳定的 `id` 和展示用 `name`；缺失时明确为 `null`。

当前没有接入可信学生验证结果，所有生产账号均返回 `false` / `null`。邀请激活、账号登录、学校页面可访问和来源连接均不授予学生或学院资格。没有客户端自报资格的写接口，也没有新增数据库表。

后续可信验证接入应在服务端 `auth::session::authenticate` 构造公共身份时读取经服务端确认的结果，届时再按真实数据增加持久化。学院内部资料、文件和社区板块仍须在业务服务端根据当前账号及可信结果授权，不能相信客户端字段、学院名称或页面隐藏。

## Flutter 消费入口

B—E 的页面通过 `SessionScope.of(context)` 取得既有 `SessionController`，读取 `phase` 和 `currentUser`；该上下文只是同一控制器的访问入口，不维护第二份用户状态。非 Widget 调用方继续注入同一个控制器。

- `currentUser.id` 用于账号归属；`studentVerified` 和 `college` 用于状态与权限提示。
- 登录、恢复及令牌刷新均读取 `/me`。退出清空当前用户，切换账号替换完整用户模型并沿用既有个人缓存隔离。
- `phase` 非 `authenticated` 时不能把保留的用户快照视作当前在线确认。设置页此时显示无法确认学生及学院状态。
- 本地 `CachedIdentity.verifiedAtUtc` / `recordVerified` 的历史命名仅指应用账号曾经由 `/me` 确认，不代表学生验证；数据库字段保持兼容，缓存不保存学生或学院资格。
- 来源平台连接继续通过既有 `SourceContext` / `SourceSessionRegistry` 管理，各来源独立，不因应用登录或学生状态变化而全部变成已连接。

未验证学生仍可按现有规则使用本地工作台；离线缓存不是实时服务端授权证明。测试中的已验证身份及学院仅为夹具，不进入生产路径。
