# A03 发布基础：缺项、备份恢复与回滚

状态：staging 与生产均未部署。本机没有 `docker` 命令与 Docker daemon，没有 PostgreSQL 服务、`psql`/`pg_ctl`/`pg_dump`/`pg_restore`，也没有 staging 或生产主机访问权限。`infra/` 新增的三个脚本只做了本机语法检查与不依赖 Docker/PG 的参数分支冒烟，**没有连接任何真实服务器，也没有对真实 PostgreSQL 执行过备份或恢复**。缺失信息一律标为“未提供/待人工确认”，本文不猜测地址、容量或凭据。

依据：`docs/foundation.md` §4（迁移顺序）、§8（当前限制）、§9（staging 缺项）、§10（验证命令）；规划文档 §8（部署、迁移与运维交接，位于工作区 `output/planning/`，未纳入本仓库）。

## 公共文件增量

公共文件现采用服务端目录，不依赖对象存储。配置、业务关联与[文件备份恢复边界](../public-files.md#存储限制与运维)见公共接入说明；本轮增加 `filesdata` 命名卷及 schema `9` 迁移。数据库记录和目录内容须作为同一恢复点保存，现有 PostgreSQL 备份脚本不会备份附件；不能只恢复数据库或运行 `down -v` 后继续承诺文件可读。目录可写权限为 API 的 UID/GID `10001:10001`。

本轮已在本机另建 PostgreSQL 16.15 隔离测试集群；与本文早期“本机无 PostgreSQL”记录分开，不涉及真实业务库。Docker CLI 可用但 daemon 不可用，Compose 静态展开可检查，实际容器重建仍待有 daemon 的环境验证。未部署 staging / 生产，也未执行真实数据备份恢复。

## 1. staging / 生产缺失信息

| 类别 | 需要提供的信息 | 现状 |
| --- | --- | --- |
| 主机与磁盘 | 主机名、SSH/部署账号与权限、CPU/内存、系统盘与数据盘容量、宿主机故障边界 | 未提供 |
| 环境隔离 | staging 与生产是否分开数据库、凭据、域名与卷；只有一台硬件时的资源与数据划分 | 未提供 |
| 域名与 DNS | staging/生产域名、DNS 控制权与变更窗口 | 未提供 |
| TLS | 证书方式（Caddy 自动签发或已有证书）、证书存放与续期责任人、80/443 可达性 | 未提供 |
| 镜像仓库 | 仓库地址、命名空间、推送凭据、保留策略 | 未提供 |
| digest/commit 登记 | 固定镜像 digest 与源码 commit 的登记位置与责任人（本仓库只有登记脚本） | 未提供 |
| PostgreSQL | 托管或容器、版本、连接串来源、账号与权限、磁盘容量与增长、连接数上限 | 未提供 |
| Redis | 是否有独立实例、用途与持久化要求（API 当前未使用 Redis） | 未提供 |
| 对象存储 | endpoint、bucket、region、凭据与访问策略（对象存储尚未实现） | 未提供 |
| 备份位置与保留 | 宿主机之外的存放位置、保留周期、加密、访问控制、异地副本 | 未提供 |
| 恢复目标 | RPO/RTO、恢复演练频率（规划建议 15 分钟数据损失、2 小时恢复，属待演练目标） | 未提供 |
| 监控/日志/告警 | 指标与日志收集、告警接收人、值班安排 | 未提供（仓库无监控实现） |
| 发布审批人 | staging 验收人、生产发布批准人、代理批准人与审批记录位置 | 未提供 |
| 回滚窗口 | 允许回滚的时间窗、决策人、数据修复与恢复授权的边界 | 未提供 |
| 备份/恢复责任 | 谁执行备份、谁核对行数、谁批准恢复与销毁演练环境 | 未提供 |

未获明确授权前不部署生产，不运行会破坏现有数据库或卷的命令。本机没有 Docker daemon，Compose 启动冒烟只在 CI 的 `Infra (Compose)` 执行。

## 2. 脚本与执行状态

| 文件 | 用途 | 前置条件 | 本机执行状态 |
| --- | --- | --- | --- |
| `infra/postgres-backup.sh` | 在 `postgres` 容器内用 `pg_dump --format=custom` 做逻辑备份，写出后立即用 `pg_restore --list` 校验 | staging/生产宿主机、Docker 与 Compose v2.24+、stack 已启动、真实 `.env`、输出目录可写 | 仅 `bash -n` 与无 Docker 分支；未真实备份 |
| `infra/postgres-restore.sh` | 只恢复到**新库**：拒绝已存在库名、`--single-transaction` 恢复、恢复后抽查 `service_meta.schema_version` 与 `users`/`sessions` 计数 | 同上，另需一份可读 dump | 仅 `bash -n`、缺文件/非法库名/无 Docker 分支；未真实恢复 |
| `infra/release-manifest.sh` | `record` 登记镜像 digest、commit 与 schema version；`check` 在回滚前比较当前 schema 是否与目标发布一致 | 无需 Docker/PG，离线可用 | 已用 `.invalid` 测试值在临时目录执行 `record`/`check`（见 §7） |
| `infra/smoke.sh`（现有） | 发布后健康检查、request_id、404 结构 | 服务可达 | 未执行（无运行中的服务） |
| `infra/assert-no-credentials.sh`（现有） | 检查日志中是否出现凭据 | 日志文件 | 未执行（无运行中的服务） |

备份方案选择逻辑导出（`pg_dump`），原因：仓库没有 WAL 归档目录、备份卷或归档命令配置，物理基础备份 + 持续 WAL 归档（规划 §8 的目标方案）无法在本任务内落地；逻辑备份不依赖额外配置，恢复只需 `pg_restore`。物理备份是否本期需要，待人工决定。

脚本约定：`set -euo pipefail`；路径、env 文件、compose 文件与可选的 compose 覆盖文件均可用参数指定（staging 传 `compose.yaml compose.staging.yaml`）；口令只从容器环境读取，不打印、不写入日志；`umask 077` 写出备份文件。

## 3. 发布顺序（先迁移，后 API）

顺序由代码与 Compose 依赖保证，不靠人工记忆：

- `migrate` 与 `api` 使用同一镜像，`migrate` 是一次性服务，入口为 `/usr/local/bin/migrate`。
- `infra/compose.yaml` 中 `api.depends_on.migrate.condition: service_completed_successfully`；API 进程本身不执行迁移。
- 迁移由 SQLx 顺序执行并记录在 `_sqlx_migrations`；`/health/ready` 读取 `service_meta.schema_version`，schema 元数据缺失时返回 503。

在 staging 宿主机执行（本机未执行，原因见 §7）：

```sh
cd infra
cp .env.staging.example .env   # 首次；填入受控密钥存储里的真实值，不提交
docker compose --env-file .env -f compose.yaml -f compose.staging.yaml config > /dev/null
docker compose --env-file .env -f compose.yaml -f compose.staging.yaml pull
docker compose --env-file .env -f compose.yaml -f compose.staging.yaml up -d --no-build
docker compose --env-file .env -f compose.yaml -f compose.staging.yaml ps -a
curl --fail --silent --show-error https://<staging-domain>/health/ready
curl --fail --silent --show-error https://<staging-domain>/api/v1/meta
bash smoke.sh https://<staging-domain>
```

部署后必须确认：

1. `ps -a` 中 `migrate` 退出码为 0，`api` 与 `caddy` 为 running/healthy。
2. `/health/ready` 返回 `"status":"ready"`，其 `data.schema_version` 与本次发布预期一致。
3. `/api/v1/meta` 的 `data.build_id` 等于本次 `APP_BUILD_ID`（即源码 commit）。

登记本次发布（在 staging 宿主机、`infra/` 目录）：将下方占位符替换为本次已部署 `.env` 中的 `API_IMAGE`（完整镜像名与 digest）、`APP_BUILD_ID`（完整源码 commit）及 ready 返回的 schema version。Compose 的 `--env-file` 不会设置当前 shell 的变量；此命令直接传值，新开 shell 也可执行，无需加载或导出 `.env`。

```sh
bash release-manifest.sh record \
  --image "<与 .env 的 API_IMAGE 相同的镜像名>@sha256:<64 位十六进制 digest>" \
  --commit "<与 .env 的 APP_BUILD_ID 相同的完整源码 commit>" \
  --schema-version "<ready 返回的 schema_version>"
```

- `--image` 必须是 `@sha256:<64 位十六进制>` 摘要，可变 tag 会被拒绝。
- 记录默认写到 `$HOME/jlu-dela-release-records/release-<UTC 时间>.env`，避免把实例信息提交进仓库；可用 `--records-dir` 或 `RELEASE_RECORDS_DIR` 改到受控运维位置（位置未提供）。
- 记录内容只有 `recorded_at`、`image`、`commit`、`schema_version`，不含口令。

`docker compose config` 是客户端静态展开，不需要 Docker daemon；但需要 docker CLI、Compose v2.24+（staging 覆盖文件使用 `!override`/`!reset`）、真实 `.env` 与 `API_IMAGE`/`APP_BUILD_ID`/`SITE_ADDRESS`。

## 4. 回滚

回滚镜像必须是已登记的 digest，不能用 tag。回滚窗口、决策人与恢复授权未提供。

1. 记录当前 `/health/ready` 的 `schema_version`、当前时间与受影响的写操作，通知渠道未提供。
2. 选定目标 release 记录，执行兼容性检查：

```sh
bash infra/release-manifest.sh check --manifest <target-release.env> --current-schema <当前 schema_version>
```

3. 检查通过（schema 相等）时：把 `.env` 中 `API_IMAGE` 改回目标 digest、`APP_BUILD_ID` 改回目标 commit，然后

```sh
docker compose --env-file .env -f compose.yaml -f compose.staging.yaml up -d --no-build
docker compose --env-file .env -f compose.yaml -f compose.staging.yaml ps
bash smoke.sh https://<staging-domain>
curl --fail --silent --show-error https://<staging-domain>/api/v1/meta   # 确认 build_id 为目标 commit
```

4. 检查未通过（schema 已前进）时**不自动回滚**：先由发布负责人确认旧应用兼容当前 schema（只允许新增表/列/索引，不得删除或改变语义），否则前向修复；禁止破坏性的 down migration。需要恢复备份时按 §5 执行，且必须人工批准，因为恢复会替换数据。
5. 记录回滚结果：受影响数据、起止时间、版本变化、未修复项。

脚本只比较 `schema_version` 是否相等，宁可阻断；当前四个迁移均为新增表和索引，但“旧版本是否兼容新 schema”必须由发布负责人按实际迁移判断，不能由脚本代替。

## 5. 备份与恢复演练

### 备份

```sh
cd infra
bash postgres-backup.sh /path/to/backup-dir
# 可选：已有其它 env/compose 路径
bash postgres-backup.sh /path/to/backup-dir /path/to/.env /path/to/compose.yaml
# staging：追加 compose.staging.yaml 覆盖文件
bash postgres-backup.sh /path/to/backup-dir .env.staging compose.yaml compose.staging.yaml
```

输出 `jlu-dela-postgres-<UTC 时间>.dump` 与字节数。脚本先写临时文件，`pg_restore --list` 校验通过后才改名；失败不会留下可被误认为有效的备份。容器内命令使用 `127.0.0.1` 与容器自带的 `POSTGRES_PASSWORD` 认证，和 API 的 TCP 连接路径一致；宿主脚本不读取、不打印口令。备份文件含用户数据，权限由 `umask 077` 收紧，需转移到宿主机之外（位置未提供）。

### 恢复到新库（不覆盖现有库）

```sh
cd infra
bash postgres-restore.sh /path/to/jlu-dela-postgres-<时间>.dump jlu_dela_restore_20261111
# staging：第 5 个参数追加 compose.staging.yaml
bash postgres-restore.sh /path/to/dump jlu_dela_restore_20261111 .env.staging compose.yaml compose.staging.yaml
```

脚本行为：库名必须匹配 `[a-z][a-z0-9_]*`；容器内先查 `pg_database`，已存在则拒绝；`createdb` 新库后以 `--single-transaction` 恢复，失败不留半成品数据；恢复后打印 `schema_version`、`users`、`sessions` 计数。脚本不会 `DROP`、不会 `--clean`、不会指向现有库。若已存在同名库，需人工确认它是上次失败留下的空库后再手动删除并重试。

### 演练步骤（独立环境；生产演练需人工批准）

1. 记录源库 `/health/ready` 的 `schema_version`，备份开始/结束时间、字节数与耗时。
2. 在独立环境或新库执行恢复，确认退出码为 0。
3. 行数抽查：`users`、`sessions`、`service_meta`，与源库计数对比；抽查命令与结果写入 §6 的模板。
4. 如需整链路验证，让 API 指向恢复后的库启动，检查 `/health/ready` 与 `/api/v1/meta`；不要把恢复库接回生产流量。
5. 记录结果，销毁或隔离演练环境（销毁需要批准）。
6. 附件目录存储已实现，但上述数据库恢复步骤不覆盖附件；需按[公共文件说明](../public-files.md#存储限制与运维)配套保存和恢复目录。对象存储尚未实现；Redis 未被 API 使用，未定义备份与恢复要求。

## 6. 验收记录模板

```text
演练/发布类型：备份恢复演练 | staging 发布 | 生产发布 | 回滚
日期与时间（Asia/Shanghai）：
环境：staging | 生产 | 独立恢复环境
操作人 / 复核人 / 批准人：
源 commit：
镜像 digest：
schema_version：迁移前 → 迁移后
备份文件路径 / 字节数 / 完成时间：
恢复目标库或实例（不得是现有业务库）：
行数抽查：users= / sessions= / service_meta=
发布或回滚命令及退出码：
smoke 结果（命令与退出码）：
结论与遗留问题：
```

## 7. 本机实际执行与结果

环境：Windows，Git Bash 5.3.15，工作树 `C:\Users\ZincG\JLU-Dela-release`（分支 `codex/a03-release-readiness`，基线 `5dbb098`），2026-11-11。本机没有 `docker` 命令或 Docker daemon，也没有 PostgreSQL 服务与 `psql`/`pg_ctl`/`pg_dump`/`pg_restore`；以下检查未连接任何真实服务器或数据库。

| 命令 | 退出码 | 结果 |
| --- | --- | --- |
| `bash -n infra/postgres-backup.sh` | 0 | 通过 |
| `bash -n infra/postgres-restore.sh` | 0 | 通过 |
| `bash -n infra/release-manifest.sh` | 0 | 通过 |
| `bash -n infra/smoke.sh` | 0 | 现有脚本，通过 |
| `bash -n infra/assert-no-credentials.sh` | 0 | 现有脚本，通过 |
| `shellcheck` | 未执行 | 本机未安装（`command -v shellcheck` 无结果） |
| `docker compose ... config` | 未执行 | 本机没有 `docker` 命令，也没有 Docker daemon；`infra/.env` 不存在（只有占位模板）。该命令不需要 daemon，但需要 CLI、Compose v2.24+ 与真实 env，因此不能标记为通过 |
| `postgres-backup.sh` 对真实 PostgreSQL | 未执行 | 无 Docker、无 PostgreSQL、无服务器访问权限；只验证到“docker 未安装”分支（退出码 1） |
| `postgres-restore.sh` 对真实 PostgreSQL | 未执行 | 同上；验证到缺 dump（1）、非法库名（2）、无 Docker（1）分支 |

离线冒烟（测试值，写入临时目录后已删除，不是发布记录）：

| 操作 | 退出码 | 结果 |
| --- | --- | --- |
| `release-manifest.sh record --image registry.example.invalid/...@sha256:aaaa…（64 位） --commit 0123…（40 位） --schema-version 2` | 0 | 生成记录文件 |
| `release-manifest.sh check --manifest <记录> --current-schema 2` | 0 | 通过，schema 一致 |
| `release-manifest.sh check --manifest <记录> --current-schema 3` | 1 | 预期阻断：schema 已前进 |
| `release-manifest.sh record --image ...:latest` | 1 | 预期拒绝可变 tag |
| `postgres-restore.sh <缺失文件> newdb` | 1 | 预期：dump 不存在 |
| `postgres-restore.sh <文件> Bad-Name` | 2 | 预期：库名不合法 |
| `postgres-restore.sh <文件> ok_name` | 1 | 预期：docker 未安装，未进入恢复流程 |
| `postgres-backup.sh`（无参数） | 2 | 预期：打印用法 |
| `postgres-backup.sh <目录>` | 1 | 预期：docker 未安装，未执行 pg_dump |

## 8. 未验证项与需要人工决定

未验证：

- 三个脚本均未在真实 Docker/PostgreSQL 上执行；备份文件未做过真实恢复。
- 发布顺序只有 Compose 静态依赖保证，未在真实 `docker compose config`/启动中验证。
- 无真实域名、TLS、镜像仓库、监控、告警、对象存储与备份存储位置。
- 规划建议的 RPO ≤15 分钟、RTO ≤2 小时没有演练证据。

需要人工决定或提供：

1. 备份存储位置、保留周期、加密与访问控制；是否本期实现物理基础备份 + WAL 归档。
2. 采纳或修改 RPO/RTO；安排首次恢复演练的时间、环境、执行人与复核人。
3. staging/生产是否共用宿主机；生产发布审批人与回滚窗口。
4. 镜像 digest/commit 的登记位置：本仓库脚本写本地记录目录，还是接入外部运维系统。
5. 生产发布与破坏性恢复的人工批准流程与记录位置。

本分支未 push、未合并、未部署、未创建 PR，不含凭据，`AGENTS.md` 未修改。
