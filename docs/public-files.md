# 公共文件接入（B / D / E）

公共上传只保存文件，不发布资料或帖子。A 提供文件 ID、存储、私人访问及业务授权后的读取；B 维护资料、课程与学院范围，D 维护帖子、图片与板块范围。二者继续使用现有应用会话，不发送学校 Cookie、报告码或来源平台凭据。

## HTTP 与客户端

接口以 [OpenAPI](../contracts/openapi.yaml) 为准，均需应用 Bearer 令牌：

| 操作 | 入口 | 结果 |
| --- | --- | --- |
| 上传 | `POST /api/v1/files`，`multipart/form-data` 的单个 `file` 字段 | `201`，`data` 返回文件元信息与稳定 `id` |
| 私人元信息 | `GET /api/v1/files/{id}` | `200`，仅未关联文件的上传者可读 |
| 私人内容 | `GET /api/v1/files/{id}/content` | `200`，仅未关联文件的上传者可读 |
| 删除私人上传 | `DELETE /api/v1/files/{id}` | `204`，仅上传者；已关联时 `409 FILE_IN_USE` |

元信息为 `id`、`uploader_id`、`original_name`、`size_bytes`、`media_type`、`created_at`。上传者来自服务端认证，不接受自报归属；没有客户端可写的公开或学院范围。物理路径和内部关联不返回客户端。`original_name` 仅供显示，B / D 下载落盘时也不能直接用它拼接本地路径。`media_type` 为上传时声明值，不保证内容真实类型；下载强制 `application/octet-stream`、`attachment`、`nosniff`、`private, no-store`，图片由业务客户端按字节解码，不依赖永久公开 URL。

未登录返回 `401`；其他账号或不存在文件返回 `404 FILE_NOT_FOUND`。内容不存在同样返回文件不存在；大小超限为 `413 PAYLOAD_TOO_LARGE`，非法 multipart、空文件或名称等按现有校验信封返回，目录存储不可用为 `503 FILE_STORAGE_UNAVAILABLE`，数据库操作失败为 `503 DATABASE_UNAVAILABLE`。保存失败不返回成功记录。上传非幂等：网络结果不确定时不要自动重传；由业务 UI 提示后重试，不声称已发布。

Flutter 复用 [WorkbenchApi](../clients/flutter/lib/core/auth/workbench_api.dart) 的 `files` 类型化入口和唯一 `ApiClient` / `SessionHttpClient`。`upload(http.MultipartFile.fromBytes('file', bytes, filename: originalName))` 返回生成模型 `StoredFile`；`metadata(id)`、`download(id)`、`delete(id)` 分别返回元信息、`Uint8List`、`void`，错误映射为现有 `ApiFailure`。完整用法见[消费示例](../contracts/files.md)。二进制读取使用 gateway，不调用生成器不支持二进制反序列化的 convenience 方法。

不另建认证客户端。文件选择、进度、失败和重试 UI 由 B / D 在各自页面实现，不新增文件中心。异步调用方遵循当前用户作用域，每次 `await` 后检查 `sessionRevision`、Widget 的 `mounted`，切号后丢弃旧账号结果，私有缓存注册到现有清理入口。

## 业务关联与每次读取

[服务端文件模块](../server/src/files.rs) 提供最小 Rust 接入点；没有对客户端开放关联、公开或授权成功接口：

1. B / D 从当前服务端身份取得作者，检查发布权限及业务字段；图片格式、资料类型等业务限制由业务检查。
2. 在创建业务记录的同一数据库事务中调用 `files::attach(&mut *tx, file_id, user.user_id, FileUse::Material 或 CommunityImage, business_id)`。只接受该作者的未关联文件；一个文件仅属于一个业务对象，不跨业务复用同一附件。重复发布失败时事务回滚，文件仍为私人上传。
3. 业务保存文件 ID，不保存物理路径。业务路由根据可信资料 / 帖子 ID 找到文件关联，调用 `read_for_business` 并提供执行当前业务授权的异步闭包；返回内容前检查真实业务对象存在、当前状态及访问范围。全校或学院资格使用现有 `require_student` / `require_college`，学院来自业务记录而非请求中的自报值。
4. 文件一旦关联，公共私人读取入口对上传者也拒绝；作者通过业务自己的编辑 / 预览入口读取。撤销、下架或改范围立即由业务检查生效，不缓存授权、不签发永久地址。未接入业务时，没有可读这些文件的生产业务路由。

`read_for_business` 只校验文件关联并在读取前执行授权闭包；资料 / 帖子是否存在、是否撤销及当前访问权限仍由 B / D 检查，不能用无条件成功闭包代替。D 的资料引用只保存 B 的资料 ID，标题、摘要、详情和文件按 B 的权限决定是否返回；帖子可见不等于资料可见，不复制受限内容或把资料文件重新关联为社区图片。B / D 尚未接入这些业务路由，现有文件测试不代替业务发布、撤销与引用权限验收。

## 删除、失败与撤销责任

- 用户取消发布或确定放弃重试：B / D 客户端调用私人删除；发布失败保留草稿和私人文件 ID 可供重试。A 不将失败自动变成公开，也不自动扫描删除未关联内容。
- 业务删除 / 替换附件：B / D 先检查当前用户的编辑 / 删除权限，再在业务事务中解除引用并调用 `files::detach`；该函数只匹配原用途和业务 ID，不代替业务授权。提交后文件回到上传者私人状态；仍需删除内容时，由上传者调用私人删除。业务不得留下可见记录指向已解除关联的文件。
- 仅撤销可见范围或下架但保留记录：保留关联，业务授权拒绝访问；不要为了隐藏内容解除关联后留下旧公开地址。
- 关联文件不能直接物理删除。私人删除先持久化删除标记，再移除内容及记录；中途失败不再可读，上传者重试 `DELETE` 完成清理。数据库记录与文件内容不属于同一事务，失败时以 API 结果为准；运维应对照数据库与内容恢复，不直接在目录中修改单个文件。请求超时取消或进程被强制终止时可能遗留无记录文件，本轮不实现后台清理调度，不能以目录文件数当作已发布记录数。

## E 邮件附件

E 维护 [`MailAttachmentSource`](../clients/flutter/lib/features/mail/mail_gateway.dart) 与业务适配，当前签名为 `Future<Uint8List?> read(String attachmentId)`；`null` 表示附件已不存在，发送编排会在 SMTP 前保留草稿并报缺失。草稿只存引用，本机字节读取不强制先上传公共文件，也不把邮件收发等同应用备份。当前尚无真实附件来源实现，A 只协调所需公共存储与文件入口，不替 E 重写邮件业务。

仅在用户明确选择复用已有服务器文件的场景，才接入受控读取：当前上传者的未关联文件可用 `WorkbenchApi.files.download(id)`；已关联资料 / 图片必须走相应业务授权入口，不能用私人入口绕过权限，也不能在该入口尚未实现时伪造成功。不要将附件 ID 默认解释为公共文件 ID，不新建第二套文件服务或认证客户端。

## 存储、限制与运维

当前仅支持单实例服务端目录，不支持多副本独立磁盘、对象存储、分片、秒传、转码或病毒扫描。服务端用内部 UUID 决定路径，原始文件名仅作显示。文件内容不进入数据库。

| 配置 | 默认 | 约束 |
| --- | --- | --- |
| `FILE_STORAGE_DIR` | `./data/files`（相对 API 工作目录） | 运行账号可写的私有目录，不挂到静态 Web 目录 |
| `FILE_MAX_BYTES` | `10485760`（10 MiB） | 1 字节至 64 MiB，单文件内容上限 |
| `MAX_BODY_BYTES` | `1048576` | 原 JSON 请求限制不变；上传路由单独允许文件上限外加 64 KiB multipart 开销 |

上传采用有界内存接收，不适合大文件或高并发传输；不要提高限制来模拟完整对象存储。现有请求超时同样生效。反向代理若另设请求上限，须至少容纳文件上限加 64 KiB。

新增迁移 [20261114000000_files.sql](../server/migrations/20261114000000_files.sql) 推进 schema 至 `9`，不改历史迁移、不清库。先执行迁移，再启动 API；原有用户和业务数据保留。

[Compose](../infra/compose.yaml) 将 `filesdata` 命名卷挂到 `/var/lib/jlu-dela/files`，API 以 UID/GID `10001:10001` 写入；镜像创建目录并设置归属。重建 API 容器保留卷，`down -v` 会删除文件及数据库卷，不能用于正常发布。自定义 bind mount 时维护者须预先配置该账号的目录写权限。

发布、备份与恢复必须同时保存 PostgreSQL（文件元信息、账号及业务关联）和文件目录 / `filesdata` 的完整内容。单独 PostgreSQL 脚本**不包含文件**；现有[配套流程与实测](operations/paired-backup-verification.md)在维护窗口暂停 API、导出数据库及归档文件、记录同一备份标识，再恢复到新库和新目录核对账号、内容与业务权限。卷不是异地备份；备份位置、加密保留及运维责任人仍需维护者确认。原生隔离演练不代表容器卷验收，也不代表个人授权备份或多端同步已交付。
