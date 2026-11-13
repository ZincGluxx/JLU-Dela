> 来源技术记录：下文保留记录时的观察、方案与验证边界，不重新决定本版功能范围。旧任务编号、执行顺序和契约提案仅供历史参考；现行需求见[开发完整计划](开发完整内容.md)。本次文档同步不进行接口复验。

# 吉林大学数据获取可行性研究

日期：2026-11-12（Asia/Shanghai）。状态：进行中。

## 判断口径

分别记录本次页面实测、仓库已有实现和待验证接口。页面出现数据不等于已验证 API；历史实现不等于当前会话复验成功。本记录不保存个人成绩、学号、姓名、Cookie、令牌和原始 HAR。

## 当前结论

用户完成人工认证后，本次成功复用浏览器会话打开教务首页、成绩、个人培养方案、学业完成及考试安排页面。四类业务页面可读，具备定向页面采集的基础；网络监听仅捕获部分学业详情请求，尚未完成响应解析及 fetch 重放。

未找到面向个人开发者自助申请密钥的官方开放 API 文档。学校公开的[数据管理办法](https://nic.jlu.edu.cn/info/1184/2238.htm)提到经部门申请和授权的数据共享平台接口；这不能证明个人项目可直接接入。

## 本次页面证据

| 来源         | 实际观察                                                                                                | 验证边界                                                                                 |
| ------------ | ------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| 教务首页     | `https://iedu.jlu.edu.cn/jwapp/sys/emaphome/portal/index.do` 登录后正常显示                             | 看到了成绩查询、我的课表、学业完成查询、个人方案查询、我的考试安排入口                   |
| 成绩查询     | 从首页点击后另开标签页，路径为 `/jwapp/sys/cjcx/*default/index.do?EMAP_LANG=zh#/cjcx`；本人记录实际显示 | 默认最近两学期；另有全部、GPA 查询；未验证后两者的数据及接口                             |
| 个人培养方案 | `/jwapp/sys/xsfacx/*default/index.do?EMAP_LANG=zh#/ckgrpyfa`；方案卡片与详情树实际加载                  | 可读主修方案、最低学分、分类层级、选项与学分范围；未逐个展开课程叶节点                   |
| 学业完成     | `/jwapp/sys/xywccx/*default/index.do?EMAP_LANG=zh#/xywccx`；概览及详情树实际加载                        | 可读要求学分、已修学分、选课学分、比例、要求门数、已修门数及上次计算时间；未点击重新计算 |
| 考试安排     | `/jwapp/sys/studentWdksapApp/*default/index.do?EMAP_LANG=zh#/wdksap`；当前学期实际有已排考试            | 可读课程、时间、地点、形式、教师、说明及排考分类数量；未切换历史学期、未操作缓考申请     |
| 电子校务     | `/defaultroot/login.jsp?access=oa` 直接显示通知首页，无需人工登录                                       | 当前浏览器会话可读；本次没有独立证明全新无 Cookie 会话可读                               |
| 教学日历     | [本科生院教学日历](https://jwc.jlu.edu.cn/jxrl.htm)列出 2026—2027 学年入口                              | 已确认公开列表，未解析日历附件                                                           |

成绩表显示课程、课程号、课序号、课程类别、课程性质、学分、学时、修读方式、是否主修、考试日期、绩点、重修重考、成绩类型、考试类型、开课单位、是否及格、是否有效等字段，并提供搜索、分页和导出入口。成绩包含数字与等级文本，不能统一强制转换为数字。导出格式尚未验证。表格存在固定列和普通列两套显示，DOM 采集需避免重复记录。

培养方案是带选择约束的树，存在“几选一”及学分范围，不能把所有子项相加。学业完成是学校已有的计算快照，需保留上次计算时间，不能标为实时毕业审核结论。考试页区分已排、安排中和已选课未安排；只有已排列表不足以说明所有课程均已安排考试。

## 本次捕获的学业详情请求

在学业完成概览点击“查看详情”后，通过浏览器 CDP 观察到以下 XHR，域为 `iedu.jlu.edu.cn`：

| 方法 | 路径                                           | 实际证据                         |
| ---- | ---------------------------------------------- | -------------------------------- |
| POST | `/jwapp/sys/xywccx/modules/xywccx/cxscfa.do`   | 捕获两次请求及对应 HTTP 200 响应 |
| POST | `/jwapp/sys/xywccx/modules/xywccx/cxscfakz.do` | 捕获请求；未取得对应响应         |

同时观察到详情树的 `jsmindFrameIndexPage.html` 加载，随后页面显示学业详情树。以上仅证明页面发出了请求；请求参数、Content-Type、响应体字段、业务成功标识、接口之间的职责、独立重放及分页均未确认。HTTP 200 本身不等于业务成功。尚不能据此提供可运行的 fetch 代码。

## 已有接口清单（本次未复验响应）

以下事实来自仓库代码和历史记录，不是本次网络抓包。

### 教务课表

来源：`app/src/main/timetable/jlu.ts`。基址为 `https://iedu.jlu.edu.cn/jwapp/sys/wdkb/modules/`，现有实现使用携带校园会话的表单 POST。

| 用途       | 相对路径              | 参数                     |
| ---------- | --------------------- | ------------------------ |
| 当前学期   | `jshkcb/dqxnxq.do`    | 无                       |
| 整学期课表 | `xskcb/cxxszhxqkb.do` | `XNXQDM`                 |
| 校历       | `xskcb/cxxljc.do`     | `XN`、`XQ`               |
| 节次       | `jshkcb/jc.do`        | 无                       |
| 调停课     | `xskcb/xsdkkc.do`     | `XNXQDM`、`*order=-SQSJ` |
| 未排定课程 | `xskcb/xswpkc.do`     | `XNXQDM`                 |

现有代码使用 `application/x-www-form-urlencoded`、`X-Requested-With: XMLHttpRequest` 和课表页 Referer。历史文档记录响应可能带 `totalSize: -1`、`pageSize: 0`，不能仅据此判定数据无效。

### 学在吉大

来源：`app/src/shared/jlu-collectors.ts`、`app/src/main/jlu/study.ts`。现有采集器在学校页面内使用 `credentials: 'include'`。

| 所在域                 | 用途     | 方法与路径                                                 | 参数                                       |
| ---------------------- | -------- | ---------------------------------------------------------- | ------------------------------------------ |
| `ilearntec.jlu.edu.cn` | 学期     | POST `/studycenter/platform/common/termList`               | 无                                         |
| 同上                   | 本人课程 | GET `/studycenter/platform/classroom/myClassroom`          | `termYear`、`term`                         |
| 同上                   | 回放目录 | GET `/coursecenter/liveAndRecord/getLiveAndRecordInfoList` | `roomType=0`、`identity=0`、`teachClassId` |
| `ilearnres.jlu.edu.cn` | 视频信息 | GET `/resource-center/videoclass/videoClassInfo`           | `resourceId`                               |
| 同上                   | 学校字幕 | GET `/resource-center/videoclass/videoPointInfo`           | `resourceId`                               |

课程和目录现有解析使用 `data.dataList`，视频使用 `data.videoList`，字幕使用 `data.textInfo`。不同域需分别建立业务会话；不能直接把资源请求移到课程域。

### 电子校务

来源：`app/src/main/jlu/api.ts`、`app/src/shared/jlu-collectors.ts`。现有实现解析 HTML，不依赖已确认的公开 JSON API。

| 用途     | 路径                                                   | 参数                                                 |
| -------- | ------------------------------------------------------ | ---------------------------------------------------- |
| 通知列表 | `/defaultroot/PortalInformation!jldxList.action`       | `channelId`、`startPage`                             |
| 搜索     | 同列表                                                 | `searchnr`、`searchlx`、`searchDate`，可选 `orgname` |
| 正文     | `/defaultroot/PortalInformation!getInformation.action` | `id`、`channelId`                                    |

当前代码中校内通知栏目为 `179577`；搜索类型为标题 `0`、部门 `1`、正文 `2`。附件可能由原页面脚本执行下载，不能把正文页面地址当成附件直链。

## 后续验证

1. 从已登录的本人页面观察实际 XHR/fetch，记录方法、路径、非敏感参数、状态码、响应字段及分页；先确认当前页面请求，再做单次只读重放。
2. 验证成绩全部视图、GPA 的统计口径、个人方案、学业完成、考试安排；不猜测 `.do` 路径，不进行选课、申请或其他业务写入。
3. 对照页面数量与分页响应，确认完整性；区分空结果、无权限、未登录和网络故障。
4. 分别验证校园网、公网与学校 WebVPN；目前未测定本次网络类别。

当前工具限制：浏览器页面读取成功；CDP 网络观察短暂可用并取得上述事件，但读取响应体和恢复连接多次超时，部分连接返回 `Debugger unattached`。尚未取得可据以编写成绩 fetch 的实测请求。这是工具阻塞，不是学校接口不可用的证据。

## 技术取舍

优先评估设备端保留来源会话、在用户权限内执行只读请求。JSON 接口便于校验和分页；页面采集可作补充，但受虚拟表格、重复列及页面改版影响。页面内 fetch 成功也不能单独证明独立网页端可跨域调用，或新 Flutter/Rust 客户端已具备同等会话能力。
