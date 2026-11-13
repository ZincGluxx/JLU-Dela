# B 开发包：IEDU、课程与共享资料

版本：2026-11-13，v1。可独立分发，全部文件均为 Markdown。该包给出本角色的内容与边界，不表示代码已完成，也不提供真实凭据。

## 阅读顺序

1. [最新共同决定](07-current-decisions.md)：先确认手机号、账号和报告核验方案。
2. [开发内容与交付顺序](01-development-scope.md)。
3. [职责及文件边界](02-boundaries.md)。
4. [接口与依赖](03-interfaces-and-dependencies.md)。
5. [行为约束](04-working-rules.md)。
6. [测试与验收](05-acceptance.md)。
7. [开工提示词](06-start-prompt.md)：可用于本角色的开发会话。
8. [交付记录模板](08-handoff-template.md)。

进入仓库后以实际代码和已合入契约确认接入点。本包中的现有路径只帮助定位；建议目录、业务字段和交接语义不等于新增文件或端点已存在。

仓库内还应阅读 `AGENTS.md`、`README.md`、`docs/sources/开发完整内容.md`、`docs/foundation.md`、`docs/local-data.md` 和 `docs/design/README.md`。本包总结了独立开工所需信息，不携带旧任务书、旧提示词或它们的排期。

## 简短认领入口

在本仓库开发会话中发送“我是B”即按本角色开始工作。先阅读[统一开工规则](../README.md)，再按本页阅读顺序执行；不必等待用户重新粘贴长提示词。已完成内容从实际基线确认，接续未完成任务，不重复实现。

公共代码入口和当前外部限制见[公共能力接入](../../public-integration.md)及[身份说明](../../public-identity.md)。这些文件的当前实现记录优先于本包制作时的进度描述；功能目标仍按完整计划和用户最新决定。
