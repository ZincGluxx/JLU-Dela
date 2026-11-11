# 设备端校园可见登录：证据与来源连接契约草案

状态：草案，供人工评审。本文没有实现任何服务端、契约或 Flutter 代码。
日期：2026-11-11（Asia/Shanghai）。
范围：校园来源的“用户设备上可见登录、用户手工完成学校认证”的最小验证，以及 `connections / challenge / action` 契约提案。
非范围：工作台身份方案、邀请注册、学校 OAuth/OIDC、来源业务字段、Flutter 页面实现、服务端托管来源会话。

工作树：`C:\Users\ZincG\JLU-Dela-source`，分支 `codex/a04-device-campus-login`，基线 `upstream/main` = `5dbb098`。本文只写 `docs/sources/`，未提交、未推送、未建 PR。

## 0. 结论摘要

- **选择学习通（`chaoxing`）做首个设备端可见登录最小验证。** 它是仓库内唯一同时满足以下条件的来源：有已提交的旧 Electron 证据；认证与会话可按来源独立确认；已有真实账号的受权读记录；当前 Flutter 客户端没有 webview 依赖，先用独立来源验证可以把首个实验的影响面限制在一个来源内。
- **教务（`jlu_iedu`）的校园统一认证登录链证据最强，但排在第二位。** 它的登录链、受保护接口、退出重开后的再次同步都有已提交记录；问题是 `jlu.edu.cn` 会话与电子校务、学在吉大共享，首个实验无法在不影响其他来源的情况下验证“解绑”。这属于契约必须正面处理的组会话问题，不适合作为第一个来源级验证。
- **电子校务（`jlu_oa`）不适合做登录验证。** 实测路径中入口页直接匿名呈现首页和通知列表，没有登录表单或扫码入口；旧文档也明确“路径名 `login.jsp` 不是登录失效证据”。它更适合作为“共享组内只读来源”的第二个验证对象。
- 本次只完成**页面层**实测：全新浏览器会话打开学校登录页，记录最终 URL、标题、表单/扫码入口、时间、网络类别。**人工认证、真实受权数据、失效重连、换账号、共享 Cookie 解绑影响均未验证**，原因见 §3。
- 推荐 **方案 D：设备持有来源会话，设备执行受权读；服务端不接收 Cookie，也不为设备来源注册 sync-job adapter**。服务端托管会话的方案 S 仅作为对照，未获批准，不能按已实现描述。

## 1. 证据盘点

### 1.1 仓库内已提交的证据

旧 Electron 实现仍是唯一已提交的来源接入证据，`app/` 保留为行为参考：

| 证据 | 位置 | 能证明什么 | 不能证明什么 |
| --- | --- | --- | --- |
| 校园会话存储 | `app/src/main/campus-session.ts` | `persist:jlu-campus` 分区；会话 Cookie 按域保存，另用 `safeStorage` 加密；清理会清整个分区 | 新 Flutter 客户端能复现；服务端能持有会话 |
| 可见登录窗口 | `app/src/main/campus.ts`（`createCampusLoginWindow`、`openCampusLoginWindow`） | 用户在学校窗口内手工登录；到目标站点后用真实受保护请求探测；关闭窗口可取消 | 新实现已实现登录窗；不过是“用户可见登录”的旧证据 |
| 统一认证恢复 | `app/src/main/timetable/auth.ts` | 复用一个校园分区；只在 CAS 页出现登录/二次验证表单时要求人工操作；失败保留缓存 | 自然过期、换账号、系统重启已验收 |
| 教务接口探测 | `app/src/main/timetable/jlu.ts` | `cas.jlu.edu.cn/tpass/login` 是登录失效证据；401/登录表单/跳转区分；用真实学期接口探测 | 其他来源的失效语义；新契约已实现 |
| 学习通独立会话 | `app/src/main/chaoxing/session.ts` | `persist:chaoxing` 独立分区；`passport2.chaoxing.com` 登录 URL 判定 | 新客户端已具备同等隔离能力 |
| 页面内受权读 | `app/src/main/jlu/reader.ts`、`app/src/main/chaoxing/api.ts` | 隐藏窗口复用来源会话；仅在需要人工认证时显示；页面结构/网络/认证错误分开处理 | 服务端可自行执行；Flutter 已实现 |
| 文档证据 | `app/docs/jlu-integration.md` 第 9、47、66、68、76–79、109、123、125 行 | 教务 CAS 跳转与本人会话同步；退出重开再同步；共享校园会话的清理影响；电子校务匿名可读；学习通独立认证、真实账号 33 门课程与作业列表 | 新用户、自然过期、换账号、第二账号均已验收 |

本次核对到的事实：

- `app/docs/jlu-integration.md` 第 66 行明确：教务结论“仅覆盖本机本次会话，不代表系统重启、会话过期、换账号或正式签名升级已经验收”。
- 第 68 行明确：只有模拟测试覆盖“静默恢复、人工认证、失败保留缓存、恢复上限”，真实过期仍待自然发生。
- 第 79 行明确：断开某个平台与清除全部校园登录应是两个操作；清除共享校园会话会影响其他站点。
- 第 109 行明确：电子校务通知在当时的本机网络环境无需登录即可访问；不能把 `login.jsp` 当失效证据。
- 第 123 行明确：学习通与吉大 CAS 分开，独立 `persist:chaoxing`，真实账号验证退出重开后的课程同步，加载 33 门课程。
- `docs/foundation.md` §13（A02 待人类决定与验收缺口）把“来源授权执行位置”“来源实测条件”列为未获批准的决定；“已确认的来源边界”明确教务、电子校务、学在吉大共享 `jlu.edu.cn` Cookie，学习通独立认证。

### 1.2 B/C/D 未提交证据

**仓库内未找到。** 三个工作树共用同一组 refs，没有 B/C/D 来源证据分支；本工作树、主工作区 `C:\Users\ZincG\JLU-Dela`、发布工作树 `C:\Users\ZincG\JLU-Dela-release` 的工作区里也没有 B/C/D 已提交的授权证据文件。主工作区未跟踪的 `output/planning/roles/` 下只有角色任务书，`output/planning/prompts/` 是任务提示，不是来源实测证据。Lead 的检查结论相同。

`docs/foundation.md` §11 有一句“B/C/D：2026-11-11 已提交来源授权的只读证据与契约需求”，但仓库内没有对应文件或分支可核对；本文不把这句当作证据，也不据此补写 B/C/D 的实测结论。

因此本文只使用旧 Electron 实现、`app/docs/jlu-integration.md`、本次与 Lead 的页面层实测；**不编造** B/C/D 的响应、状态码、过期时间或第二账号证据。

### 1.3 三来源证据强弱

判断口径分两种，避免把“SSO 证据强”和“来源级连接证据强”混为一谈。

| 来源 | 已提交登录链证据 | 已提交受权数据证据 | 会话范围 | 作为首个来源级验证的结论 |
| --- | --- | --- | --- | --- |
| 学习通 `chaoxing` | 独立 `passport2.chaoxing.com` 登录；旧实现有登录 URL 判定、登录表单探测、可见/隐藏窗口 | 真实账号课程列表（33 门）、退出重开后再同步、一门课程作业列表、一份课程 PDF 导入 | 独立 `persist:chaoxing` / `chaoxing.com`，与吉大 CAS 不共享 | **选中。** 认证、会话、受权读都能按来源独立确认，且不会波及共享校园会话 |
| 教务 `jlu_iedu` | `iedu` → `cas.jlu.edu.cn/tpass/login` 已确认；旧实现有可见登录窗、探测、恢复 | 本人会话真实课表同步、退出重开后再同步；受保护接口读取 | 共享 `persist:jlu-campus` / `jlu.edu.cn`，与 OA、学在吉大共用 | **第二。** 登录链证据最强，但会话是组会话，首个实验无法独立解绑；解绑会牵动其他来源 |
| 电子校务 `jlu_oa` | 入口 `oa.jlu.edu.cn/defaultroot/login.jsp?access=oa` 在实测中直接匿名呈现首页；无登录表单/扫码 | 旧文档记录匿名通知列表与 6 篇正文可读（foundation §13）；附件必须在学校页面执行 JS | 共享 `jlu.edu.cn` | **不作为登录验证。** 实测路径不需要登录，无法验证“人工认证”；更适合作为共享组内只读来源 |

结论：按“来源级连接证据”排序，学习通最充分；按“校园统一认证登录链证据”排序，教务更充分。本任务验证的单位是**来源连接**，不是校园 SSO 本身，所以选学习通。教务紧随其后，必须在共享组会话契约明确后验证。

## 2. 浏览器实测记录

### 2.1 条件与方法

- 每个来源使用**全新浏览器会话**：进入前关闭该任务的全部标签/会话，确保没有先前来源的 Cookie；每个来源测完再次重置会话。
- 工具：DSH `browser_reset_session` → `browser_open` → `browser_a11y` / `browser_content`；没有用 `curl`，没有保存文件，没有截图。
- 只用浏览器地址栏打开入口；**未输入任何账号、密码、验证码；未点击登录/提交；未保存 Cookie、令牌、二维码或截图；未导出浏览器存储。**
- 只读取页面标题、最终 URL、可见文案、表单字段名称和可访问性角色；不读取个人数据。
- 本次测试时间：2026-11-11 13:19–13:24（Asia/Shanghai）。Lead 独立测试时间：同日 13:1x。两批都是页面层证据，不是 Flutter 设备验收。

### 2.2 记录

| # | 来源 | 执行人 / 时间 | 入口 | 最终 URL | 页面标题 | 登录表单 / 扫码入口 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 学习通 | Lead，13:1x | `https://i.chaoxing.com/base` | `https://passport2.chaoxing.com/login?fid=12&refer=...&space=2` | 用户登录 | 手机号/超星号、学习通密码、登录按钮、验证码登录、其他登录方式 | 未输入账号，未保存 Cookie |
| 2 | 学习通 | 本次，约 13:22 | `https://i.chaoxing.com/base` | `https://passport2.chaoxing.com/login?fid=12&refer=http%3A%2F%2Fi.chaoxing.com%2Fbase%3Fnull&space=2` | 用户登录 | 同上；页面另有可见“使用学习通APP扫码登录”和二维码图片 | 二维码 URL 含一次性参数，**未记录、未截图、未保存** |
| 3 | 教务 | Lead，13:1x | `https://iedu.jlu.edu.cn/jwapp/sys/emaphome/portal/index.do` | `https://cas.jlu.edu.cn/tpass/login?service=https%3A%2F%2Fiedu.jlu.edu.cn%2Fjwapp%2Fsys%2Femaphome%2Fportal%2Findex.do` | 智慧校园 | 扫码登录 / 密码登录 / 手机登录三个入口 | 未登录 |
| 4 | 教务 | 本次，约 13:19 | 同上 | 同上 | 智慧校园 | 默认“扫码登录”有二维码图片（“Scan me!”）；切到“密码登录”后出现账号/邮箱、密码和登录按钮 | 只切换标签，未输入任何内容 |
| 5 | 电子校务 | 本次，约 13:21 | `https://oa.jlu.edu.cn/defaultroot/login.jsp?access=oa` | 同入口，未跳转 | 吉林大学电子校务平台 | **没有登录表单，没有扫码入口**；直接呈现首页、通知列表与导航 | 与旧文档一致：路径含 `login.jsp` 不代表登录失效；匿名可见范围未逐一验证 |
| 6 | 学在吉大（补充，不选） | 本次，约 13:23 | `https://ilearntec.jlu.edu.cn/studycenter-web/index#/` | `https://cas.jlu.edu.cn/tpass/login?service=https%3A%2F%2Fjwcidentity.jlu.edu.cn%2Fiplat-pass-jlu%2FthirdLogin%2Fjlu%2Flogin` | 智慧校园 | 扫码 / 密码 / 手机 | 补充观察共享 CAS 链；不作为本次选定来源 |

### 2.3 网络环境类别

- 本次测试浏览器出口不是校园网：对 `https://ipinfo.io/json` 的匿名读取显示出口在**日本东京**，ASN 为非校园网络；本机同时存在 `https_proxy=http://127.0.0.1:7890` 的代理配置。故记录为：**公网 + 本机代理出口（境外），非校园网，未启用学校 WebVPN**。
- 含义：这些页面在公网代理出口下可以打开，不能证明校园网内专属资源、IP 绑定或 WebVPN 路径的行为。来源连接验收必须在校园网或学校 VPN 下另测。
- Lead 的测试没有单独记录网络类别；结论只按“全新会话页面可达”使用。

### 2.4 明确未做

- 没有登录，没有账号、密码、验证码、扫码确认。
- 没有打开登录后的任何受保护页面，没有读取课表、课程、作业、通知正文或附件。
- 本次测试没有保存 Cookie、`Set-Cookie`、令牌、学号、姓名、二维码、HAR 或截图。
- 没有验证“保持登录”“关闭重开”“自然过期”“换账号”“解绑”，也没有验证 Flutter 设备。

## 3. 七条验收状态

| # | 验收项 | 状态 | 依据 / 阻塞原因 |
| --- | --- | --- | --- |
| 1 | 全新会话打开学校登录页 | **页面层已验证；设备层未验证** | Lead 与本次各自用全新浏览器会话复现：学习通落到 `passport2` 登录页，教务落到 `cas.jlu.edu.cn/tpass/login`，电子校务直接匿名首页。Flutter 当前无 webview 依赖，不能称为设备端已验收 |
| 2 | 由用户手工完成学校认证 | **未验证 / 阻塞** | 需要授权账号与真人输入；本次与 Lead 均未输入账号、密码、验证码，未扫码。旧 Electron 有本人会话证据，但不是新实现验收 |
| 3 | 读取真实受权数据 | **未验证 / 阻塞** | 需要已完成认证的会话。旧文档记录真实课表、33 门课程、作业列表等，但属旧实现；新 Flutter/Rust 没有来源读取代码。不得用模拟数据宣称已验证 |
| 4 | 失效重连 | **未验证 / 阻塞** | 需要自然过期或主动注销真实会话。旧实现只有模拟测试覆盖恢复路径；真实过期“待自然发生时复验”。本次没有会话，无法复验 |
| 5 | 换账号 | **未验证 / 阻塞** | 需要第二个已授权的校园账号，并需要先定义旧账号缓存保留/删除。仓库内没有第二账号证据；旧文档明确换账号未验收 |
| 6 | 共享 Cookie 解绑影响 | **未验证；设计上已识别** | `jlu.edu.cn` 的教务/电子校务/学在吉大共享会话，清除会影响其他站点；学习通独立。当前 Windows webview 候选无法按域分区（见 §5），无法安全实测“只解绑一个来源”；不能在实测中清掉用户其他来源的会话 |
| 7 | 网络失败 vs 授权失效 | **未验证（实现层）** | 旧实现有分类代码与模拟测试；新实现没有代码，无法验收。页面层只能证明现在网络可达，不能证明应用能区分断网、超时、5xx、403、登录跳转和结构变化 |

状态用语：**已验证**只用于已经实际执行的页面层事实；**未验证 / 阻塞**表示缺少凭据、第二账号、自然过期、真实数据或实现，不能写成完成。

## 4. `connections / challenge / action` 最小契约提案

以下是提案，**不是已实现接口**。字段命名沿用主工作区未跟踪的规划稿 `output/planning/API-Contract.md` §2 与 `contracts/openapi.yaml` 的 `{data, meta}` 包装；本文不新增依赖，也不改现有契约文件。

### 4.1 谁确认状态

- **设备确认，服务端记录。** 本文默认来源会话由设备持有，服务端只保存连接状态、challenge 记录和规范化快照；服务端没有来源 Cookie，无法独立发起来源请求，因此不能自行证明“已连接”。
- `Connection.status` 是**设备最近一次观察**，不是服务端验证结论。响应必须带 `observed_by: "device"`、`last_observed_at`、`stale`，客户端不得显示为“服务端已验证”。
- 服务端可以根据新鲜度把状态标成 `stale`，但不能把 `stale` 自动提升为 `connected`；`connected` 只能由设备完成 challenge 或受权读成功后上报。
- 工作台身份仍由服务器从令牌确定；`user_id` 不接受请求体指定。来源失效不是 401，沿用 `SOURCE_AUTH_REQUIRED` / 409 语义（`docs/foundation.md` §6 的错误约定）。

### 4.2 资源模型

```
Connection {
  source: "chaoxing" | "jlu_iedu" | "jlu_oa" | "jlu_ilearn"
  session_group: "chaoxing" | "jlu_campus" | "device_default"
  status: "connected" | "auth_required" | "disconnected"
  stale: boolean
  observed_by: "device"
  last_observed_at: string?
  last_success_at: string?
  last_error_code: string?
}
```

- `session_group` 表达“哪些来源共用同一个设备 Cookie 存储”。`chaoxing` 独立；`jlu_campus` 为教务/电子校务/学在吉大共享；如果平台只能全量清理，则所有来源归入 `device_default`。
- `status` 保持 API-Contract §2 的三值，不新造“网络错误”状态；网络错误用 `last_error_code` + `stale` 表达，避免把断网误报成需要重新登录。
- `stale` 由服务端按 `last_observed_at` + 可配置 TTL 计算（建议初值 24 小时，待人工定）；业务快照自己的 `last_success_at` 另算。
- 多设备尚未决定：若一个用户多台设备各自持有会话，建议 `Connection` 增加不透明 `client_instance_id`，按设备记录；不能只按用户覆盖。

### 4.3 端点

| 方法与路径 | 输入 | 输出 / 行为 |
| --- | --- | --- |
| `GET /connections` | 无 | 当前用户（按设备时另加实例）的各来源连接状态；无凭据 |
| `POST /connections/{source}/challenges` | 可选 `{purpose: connect 或 reconnect 或 switch}` | 201；创建 challenge。返回 `challenge_id`、`source`、`session_group`、`action`、`state`、`expires_at` |
| `POST /connections/challenges/{id}/complete` | `{outcome, evidence?, error_code?}` | 200；设备上报结果。`outcome` 为 `succeeded`/`failed`/`cancelled`；`evidence` 只含 `authorized_read: boolean`、`final_host`、`observed_at`，**不含 Cookie、HTML、学号或原始响应** |
| `GET /connections/challenges/{id}` | 无 | 200；`pending`/`connected`/`expired`/`failed`/`cancelled`；供客户端轮询或恢复页面 |
| `DELETE /connections/{source}` | 无 | 200；只解绑该来源：服务端删除该来源连接记录与业务缓存，设备清该来源本地缓存，**默认不清除共享 Cookie**；返回 `session_cleared`、`session_group`、`shared_group_retained`、`affected_sources` |
| `POST /connections/session-groups/{group}/sign-out` | 无 | 200；显式清除一个设备会话组；`affected_sources` 列出同组来源。设备先执行本地清理，再调用此端点记录状态 |

`Challenge.action` 只允许受控类型：

```
action: {
  type: "open_source_login",
  url: "https://cas.jlu.edu.cn/tpass/login?..." | "https://passport2.chaoxing.com/login?...",
  allowed_hosts: ["cas.jlu.edu.cn", "passport2.chaoxing.com"]
}
```

- 服务器只返回白名单登录地址，不接受客户端传入任意 URL；不在服务端拼开放重定向。
- `state` 是随机不透明值，只用于把本地登录窗口与 challenge 关联，不是凭据，不发给学校，不写日志。
- challenge 绑定 `user_id`、`source`、`session_group`、有效期（建议 10 分钟）；同一用户/来源/会话组已有未过期 challenge 时，复用或返回冲突，不并发开多个。
- `complete` 的 `authorized_read=true` 才能把连接置为 `connected`；只有导航到成功 URL 不算，必须真实受权读成功。这与旧实现“到达后探测受权接口”一致。
- 所有端点需要工作台 Bearer 身份；`user_id` 来自会话。

### 4.4 设备持有会话时，受权请求如何执行

1. 设备在隔离的 webview / 平台浏览器环境中打开 `action.url`，用户手工完成登录；Cookie 留在设备存储，**不上传、不进入 Dart 业务层、不进日志**。
2. 登录成功后，设备在同一个会话环境内执行一个最小受权读（学习通：课程列表；教务：当前学期/课表探测），把结果规范化后交给本地业务层或后续上传接口。
3. 设备把“是否成功、最终主机、时间”上报给 `complete`；服务器只记录状态，不接收原始 HTML 或 Cookie。
4. 服务端后续只读取设备上传的**规范化快照**（业务接口另定）；没有设备上报时，服务端保留旧快照并显示 `last_success_at`，不把来源标成 `auth_required`。
5. 设备侧的 Cookie 读写需要平台通道；Flutter 当前没有该依赖，不能假设 Dart 层可以直接读取 Cookie。

### 4.5 与现有 `sync-jobs` 的衔接

现状：`POST /api/v1/sync-jobs`、`GET /api/v1/sync-jobs/{id}` 在 `codex/a02-sync-jobs` 分支（`da8bece`）实现；本工作树基线 `5dbb098` 的 `contracts/openapi.yaml` 还没有这两个端点。服务端 worker 通过 `SyncHandler` 执行，`SyncContext` 只有 `user_id/source/resource/scope`，**没有来源会话**；该分支当前没有注册任何 adapter，所以任何来源都会返回 `422 UNSUPPORTED_SOURCE`。

提案分两层：

- **M1（本次建议）：sync-jobs 保持服务端执行，不为设备来源注册 adapter。** 设备来源连接只做 challenge + 设备本地受权读；`POST /sync-jobs` 对这类来源继续返回 `422 UNSUPPORTED_SOURCE`，不创建一个服务端永远跑不了的任务。连接状态与同步任务状态分开：`connected` 不等于服务端能同步。
- **M2（需单独批准）：给 job 增加执行者。** `CreateSyncJobRequest` 增加 `executor: "server" | "device"`（默认 `server`）；设备通过 `POST /sync-jobs/{id}/claim` 领取 queued 的 device job，通过 `POST /sync-jobs/{id}/complete` 上报 `succeeded`/`failed`、`snapshot_ref`、`attempts`。复用现有 `queued → running → succeeded/failed`、租约、三次尝试和复用语义；服务端只在校验归属、来源、资源、scope 后入队，不接触 Cookie。该改动属于新的契约和迁移，必须另开 PR，不混进本文。
- **方案 S（服务端托管会话）**：如果将来批准服务端保存来源会话，worker 可直接从服务端会话存储取 Cookie 执行；现有 sync-jobs 语义不变。但这需要凭据托管、加密、轮换、学校 IP/UA 绑定和泄露响应的完整设计，当前未批准。

### 4.6 失败语义

下表错误码是**提案命名**，不是现有代码；现有服务端只有 `UNSUPPORTED_SOURCE`、`SYNC_JOB_NOT_FOUND` 等 sync 相关错误，来源错误码尚未实现。

| 设备观察 | 连接状态 | 任务错误码（若将来有 device job） | 用户界面 |
| --- | --- | --- | --- |
| DNS/连接失败/TLS/断网 | 不改；无近期成功则 `stale=true` | `SOURCE_NETWORK_ERROR`，`retryable=true` | 检查网络/校园网/VPN，不要求重新登录 |
| 超时、5xx、429 | 不改 | `SOURCE_UNAVAILABLE` / `SOURCE_RATE_LIMITED`，按上限退避 | 稍后重试，不清缓存 |
| 跳转到白名单登录页、401、登录表单 | `auth_required` | `SOURCE_AUTH_REQUIRED`，`retryable=false` | 创建 reconnect challenge，保留旧缓存 |
| 已登录但 403 | 不改 | `SOURCE_FORBIDDEN` | 权限不足，不重新登录 |
| 解析失败/字段变化 | 不改 | `SOURCE_CONTRACT_CHANGED` | 提示适配问题，不清会话、不反复登录 |
| 用户关闭登录窗 | 不改 | `CHALLENGE_CANCELLED` | 显示已取消，可重试 |
| 工作台令牌失效 | 不涉及来源 | 401 `AUTH_REQUIRED` 等 | 回工作台登录，不动来源连接 |
| 本地会话保存失败 | 不改 | `LOCAL_SESSION_WRITE_FAILED` | 本机存储问题，不是学校失效 |

关键规则：**断网、超时、5xx、403、结构变化都不得升级为 `auth_required`**；只有来源明确的登录信号才触发重连。服务端 401 只表示工作台身份问题，不能把用户登出工作台。

### 4.7 换账号

- 每个连接/会话组引入 `connection_epoch`（整数或 UUID），由服务端在 challenge 成功时分配/递增；设备不决定编号。
- 换账号必须显式发起 `purpose: switch` 的 challenge（或单独的切换动作），不能仅凭“登录成功”推断，因为同一账号重连也会成功。设备先清空该组会话，再走新 challenge；成功后服务端把连接切到新 epoch，旧 epoch 缓存不再用于当前账号。
- 服务端按 `(user_id, source, connection_epoch)` 或连接 id 隔离缓存；旧 epoch 的数据在当前账号视图里不可见，是否保留由用户选择。不能把前一个账号的缓存当当前数据。
- 共享 `jlu_campus` 组换账号会同时影响教务/电子校务/学在吉大；UI 必须在操作前列出受影响来源，并要求明确确认。
- 如果换账号过程中取消，旧连接已断开，不能回退显示旧账号数据；重新登录后再恢复。

### 4.8 解绑与共享 Cookie 影响

- **来源解绑**（`DELETE /connections/{source}`）：删除该来源的连接记录和该来源缓存，**默认不删除设备 Cookie**。这样不会因为解绑一个来源而让其他共享站点掉线。
- **组退出**（`POST /connections/session-groups/{group}/sign-out`）：这是唯一允许清除共享会话的操作；设备清空该组 Cookie 存储，服务端把同组所有来源标记 `disconnected`，并删除/失效对应缓存。UI 必须列出 `affected_sources`。
- `jlu_campus` 组：教务、电子校务、学在吉大共用 `jlu.edu.cn` Cookie。解绑教务不清 OA/iLearn；组退出会让三者都需要重新认证。
- `chaoxing`：独立认证，不受 `jlu_campus` 组退出影响。
- 当前 Windows webview 候选无法按域分区（见 §5）：如果设备只能全量清理 Cookie，则所有来源实际归入 `device_default`；此时“来源解绑”不能清 Cookie，只有“清除全部设备会话”；契约和 UI 不能声称能按来源清。
- 设备丢失/离线时，服务端无法替设备清除 Cookie；这是设备持有方案的已知限制，必须在隐私说明和连接页写清。

### 4.9 安全与数据最小化

- 请求/响应、日志、数据库、夹具、文档、PR **不得包含** Cookie、`Set-Cookie`、令牌、密码、学号、姓名、个人信息截图、原始 HTML、未脱敏个人正文。
- 所有连接、challenge、解绑端点必须要求工作台 Bearer 身份；不得为了调试开放无认证的私有业务接口。
- `complete` 只收布尔证据、最终主机名、时间；不收 Cookie 或原始响应。
- `action.url` 必须服务器白名单；`state` 不得含凭据；challenge 一次性、短有效期、绑定用户与来源。
- 设备业务层不直接读 Cookie；受权读通过窄接口执行。旧实现“不给学校页面加载应用 preload”的边界应保留。
- 服务端只存规范化字段和状态，不存学校页面全文；附件/媒体仍按来源页面或受权代理处理。

### 4.10 与 API-Contract §2 草案的差异（需评审）

- `DELETE /connections/{source}` 由原提案的 `204` 改为 `200`，因为需要返回 `session_cleared`、`session_group`、`shared_group_retained`、`affected_sources`；原 204 无法表达共享组影响。
- 新增 `POST /connections/challenges/{id}/complete`：原提案只有创建和查询 challenge，没有设备上报完成态的端点；会话在设备上时必须由设备上报。
- 新增 `POST /connections/session-groups/{group}/sign-out`：原提案只有来源级解绑，无法表达“清除共享 `jlu.edu.cn` 会话会影响其他来源”。
- `Connection` 增加 `session_group`、`stale`、`observed_by`、`last_observed_at`；状态枚举仍是 `connected/auth_required/disconnected`。
- 所有新增字段和端点都只是提案，尚未写入 `contracts/openapi.yaml`，也没有服务端实现。

## 5. 未解决问题

1. **来源会话位置**：设备持有（推荐）还是服务端托管（未批准）。这决定 sync-jobs 能否后台执行，也决定凭据风险。
2. **同步位置**：M1 只做设备本地受权读，还是马上做“设备执行 + 服务端任务/快照”？推荐先做前者；后者要单独的契约与迁移。
3. **Flutter webview 依赖未选定。** Lead 的临时工程探测结果：`flutter_inappwebview 6.1.5` 在当前 VS Community 2026 Insiders / MSVC 14.51 上编译失败（experimental coroutine deprecation），需要项目级 workaround；`webview_windows 0.4.0` 加项目级 define 后可构建，但 `initializeEnvironment` 的 `userDataPath` 是全局单例，`clearCookies` 只能清全部，不能像旧 Electron 那样给 `jlu.edu.cn` 与 `chaoxing.com` 分 partition。**这只是候选探测，不是已选依赖，也不代表已加入主工程。**
4. **共享组解绑语义**：来源解绑是否允许保留 Cookie（本文建议允许），组退出是否要有独立确认页；如果平台不能分区，是否接受“清全部”并在 UI 明示。
5. **换账号的数据保留**：旧账号缓存默认删除还是隐藏保留；是否需要多账号档案。本文只提出 epoch 隔离，未定产品行为。
6. **服务端能否把设备上报称为“已连接”**：本文建议 `observed_by: "device"` + `stale`，不声称服务端已验证；需要产品/安全确认措辞。
7. **多设备**：同一用户多台设备各自有会话时，按设备记录还是最后写入覆盖；若要按设备，`Connection` 需要 `client_instance_id`。
8. **`SOURCE_AUTH_REQUIRED` 在设备持有 M1 的使用范围**：服务端没有会话，业务接口主要是读缓存；是否只在设备上报后才暴露 409，还是客户端只按 `Connection.status` 处理。本文建议 M1 不靠服务端 409 触发重连。
9. **真实测试条件**：第二个授权账号、自然过期窗口、校园网/学校 VPN、Windows 设备、是否允许在测试中主动注销学校会话。缺少这些条件时，第 2–7 条验收不能完成。
10. **门户/学在吉大的共享 CAS 链**：本次补充观察到 `ilearntec` 跳到 `cas.jlu.edu.cn` 的 `jwcidentity` 服务；它与教务共享会话，但业务探测必须分别做。是否把 `jlu_ilearn` 放进首批来源，未定。

## 6. 两个方案与推荐

### 方案 D：设备持有来源会话，设备执行受权读（推荐）

- 设备用隔离的 webview/平台浏览器完成人工登录，Cookie 留在设备；服务端只保存连接状态、challenge 记录和规范化快照。
- 受权请求由设备在同一个会话环境内执行；服务端不接触来源 Cookie。
- 与 sync-jobs：M1 服务端 job 不注册来源 adapter；M2 如批准，再给 job 加 `executor=device` 的领取/完成语义。
- 影响：不能在校外/关掉 App 后由服务端后台同步；数据新鲜度取决于设备；多设备要按设备记录；服务端不能独立验证来源；需要 webview 依赖和平台通道（尚未选定）。优点是不上传 Cookie、共享会话留在用户设备、与最新人工决定一致。
- 风险：设备丢失时无法远程清除来源会话；当前 Windows webview 候选不能分区，需要产品接受“清全部”或换集成方式。

### 方案 S：服务端保管来源会话，服务端执行同步

- 设备完成可见登录后，把来源 Cookie 通过受控通道交给服务端；服务端加密保存、绑定用户+来源，worker 用现有 sync-jobs 执行。
- 影响：服务端可离线/后台同步；一套 sync-jobs 直接可用；多设备共享同一来源状态。代价是服务端成为高价值凭据保管者，需要加密、轮换、审计、泄露响应；学校可能按 IP/UA/设备绑定会话，服务器出口未必可用；共享 `jlu.edu.cn` Cookie 的解绑影响会扩大到所有用户来源；与“设备端可见登录不等于上传 Cookie”的当前决定冲突。
- 结论：**当前不推荐，不能写成已批准或已实现。** 如果未来选择 S，需要单独的安全评审、凭据托管契约和用户明确同意，不得把任意 Cookie 上传当作连接完成。

推荐：**D + M1 最小范围**。先用学习通验证“设备可见登录 → 设备受权读 → 连接状态/断网/失效”的闭环；教务作为第二个来源，先解决共享组会话和解绑语义，再验证。S 只作为未来对照，不进入本轮实现。

## 7. 真人操作步骤与条件

### 7.1 前置条件

- 一个已获授权的测试校园账号；换账号测试需要**第二个**已授权账号。
- 测试设备：Windows x64（当前 Flutter 只有 `windows/` 运行目录；Android/iOS 未构建）；校园网或学校 VPN；不接受用开发者 Cookie 代替新用户登录。
- 测试前清空应用数据/全新浏览器 profile，确认没有旧 Cookie；测试后重置会话。
- 允许在测试账号上等待自然过期，或明确允许主动注销该测试账号的学校会话；不得拿主账号做破坏性解绑。
- 记录模板：时间、来源、入口 URL、最终主机、页面标题、表单/扫码入口、状态码/错误码、网络类别、是否保留缓存；**不记录 Cookie、令牌、学号、姓名、二维码、原始 HTML**。

### 7.2 步骤

1. **全新会话（页面层，已完成一部分）**：清空会话 → 打开来源入口 → 记录最终 URL、标题、登录表单/扫码入口、时间、网络类别。
2. **人工认证**：在设备上的学校登录窗口由真人输入/扫码；应用不做自动填表；认证完成后记录是否进入目标页，不保存凭据。
3. **真实受权数据**：在学习通读取课程列表和一门课程作业；在教务读取当前学期和课表。只记录数量级/状态/时间，不记录课程名、作业正文、学号等个人内容。
4. **失效重连**：用测试账号自然过期，或经允许后注销该账号会话；触发一次读取；确认跳转到白名单登录页、连接变 `auth_required`、旧缓存仍可见、重新登录后可恢复。
5. **换账号**：清除会话组 → 用第二个账号登录 → 确认旧账号缓存不可见、新账号数据独立；切回第一个账号重复一次。共享组要确认三个来源同时切换。
6. **共享 Cookie 解绑**：先只解绑学习通，确认教务/OA 不受影响；再在测试账号上验证 `jlu_campus` 组退出，确认教务、OA、学在吉大同时断开，且 UI 事先列出影响。若平台不能分区，记录“只能清全部”，不要伪装成来源级清除。
7. **网络失败 vs 授权失效**：断开网络/用防火墙阻断，触发读取，确认是 `SOURCE_NETWORK_ERROR` 而非 `auth_required`；恢复网络后重试。再制造一次真实的登录失效，确认是 `SOURCE_AUTH_REQUIRED`。两次都要保留旧缓存。
8. **记录与清理**：只把脱敏状态写进验收记录；删除测试截图/日志中的个人信息；重置浏览器会话。

### 7.3 当前无法执行的条件

- 没有第二个授权账号 → 换账号不能验收。
- 没有真实凭据/未获准登录 → 人工认证、受权数据不能验收。
- 没有自然过期窗口或不允许注销测试账号 → 失效重连不能验收。
- 没有选定的 webview 依赖且 Windows 候选不能分区 → 共享组解绑和来源级清除不能验收。
- 测试浏览器出口是境外代理而非校园网 → 校园网内行为不能据此验收。

## 8. 证据边界

- 本文的“已验证”仅指 2026-11-11 的**页面层**事实；不包含任何登录后数据、Flutter 设备运行或服务端实现。
- 本次浏览器测试没有保存 Cookie、令牌、学号、截图或原始响应；浏览器会话在每个来源后重置；仓库内没有本文的截图或凭据。
- Lead 的页面层实测按 Lead 提供的信息引用；本次实测独立复现，两者都不等于 Flutter 设备验收。
- 仓库内没有 B/C/D 已提交的来源授权证据；本文没有用未提交的响应、字段或账号补全事实。
- 本文不新增依赖，不改 `server/`、`contracts/`、`clients/flutter/` 代码，不提交、不推送、不建 PR。
