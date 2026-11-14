# PostgreSQL 与文件配套备份恢复

## 范围与恢复点

2026-11-14 初查 `upstream/main=3de0d8f754b451debae1b48f4f80ecd9c0174146`，GitHub API 返回相同 SHA；最初 Git 拉取返回 403，之后访问恢复，实际 fetch 成功。期间上游合入笔记 PR #40，任务分支已 rebase 至最新 `c634c33d26d4722eda4e0b33aebbd239052078de`，未修改其 Flutter 代码。PR #42 的配套实现及 #41 已合并，本次在独立 `codex/paired-recovery-verification` worktree 补实际缺口，不重复开发，不改原工作区及 `AGENTS.md`。本次交付为 [Draft PR #44](https://github.com/goya4140/JLU-Dela/pull/44)，保持草稿，不合并、不部署。以下命令为当前流程，末节保留先前演练记录，不充当本次结果。

[`paired-backup.sh`](../../infra/paired-backup.sh) 在维护窗口停止 API，等待停止命令完成后导出 PostgreSQL 并归档对应文件，最后恢复 API。窗口内维护者须禁止其他写入进程、直接 SQL 和迁移；脚本不能保证外部写入者的一致性。原生 stop hook 必须等待请求及进程退出，失败须返回非零，不能只是发送一个异步停止信号。本轮没有新增在线备份、WAL/PITR、调度或同步系统。

每个新 bundle 包含：

- `database.dump`：现有 `pg_dump --format=custom --no-owner --no-privileges` 逻辑导出，包含账号、文件元信息、业务关联及迁移账本，但不含附件字节。
- `files.tar`：`FILE_STORAGE_DIR` 或 API 文件挂载中的全部 UUID 文件，包含可能尚无业务记录的内容，不自动 GC。
- `files.sha256`：逐文件 SHA-256。
- `manifest.env`：同一备份 ID、UTC 时间、应用 commit/build、schema、源数据库名与文件位置、上述三份文件的 SHA-256。新格式 `2` 另记录 PostgreSQL `server_version_num` 和 `pg_dump` 版本；仍支持旧格式 `1`，旧清单没有版本记录。不执行或 `source` 清单内容；缺项、重复项、校验不符即拒绝。

清单只在导出、文件检查及 API 启动命令成功后发布；失败目录没有成功清单，不可用于恢复。退出及 INT/TERM 后尝试恢复 API；若恢复命令失败，明确输出 `API RESTART FAILED`，维护者须手工启动并检查 `/health/ready`。SIGKILL、主机断电不能执行退出处理，须按相同方式人工恢复。启动命令成功不代表健康检查成功。

不包含客户端 SQLite、私人邮件与本机附件缓存、安全存储、第三方会话、`.env`、TLS 配置、数据库角色/权限或外部秘密。数据库本身包含账号哈希、会话摘要等敏感运行数据；dump/归档不是公开交接材料。`umask 077` 不代替加密、Windows ACL、异地副本和保留策略，后者仍由维护者确认。不要传连接 URL 作为数据库名，不启用 `set -x`，不把密码放进命令或日志。

## 执行

需要 Bash、GNU coreutils/tar、PostgreSQL 16 客户端；Compose 路径另需可用 daemon。所有目标父目录须已存在，脚本解析真实路径并拒绝已存在目标、源目录重叠和旧数据库；不清库、不执行 `--clean` 或删除卷。备份须放在源文件目录之外。

### 原生维护窗口

数据库使用 libpq 的 `PGHOST`、`PGPORT`、`PGUSER`、纯库名 `PGDATABASE`，凭据通过受控 `PGPASSFILE` 提供，不复制到清单。以与 API 相同的操作系统账号执行原生恢复，使新目录归该账号所有；Unix 目录/文件权限为 `700/600`。不同服务账号时先由维护者配置归属，Windows 须单独检查 ACL。

```sh
export PGHOST=127.0.0.1 PGPORT=55435 PGUSER=paired_test PGDATABASE=synthetic_source
bash infra/paired-backup.sh /isolated/backups/new-bundle \
  --app-build <实际运行的commit或build> --native /isolated/source-files \
  --stop-hook /isolated/stop-api --start-hook /isolated/start-api
# stop/start 为可执行文件；应使用已有服务管理命令，不用 eval 命令字符串
bash infra/paired-restore.sh /isolated/backups/new-bundle synthetic_restored \
  /isolated/restored-files --app-build <同一commit或build> --native
```

恢复先检查清单、三份校验和、归档条目、数据库及目录目标，并在目标父目录下新建私有临时目录解包，核对归档与逐文件清单；不匹配时不创建恢复库或目标目录，退出清理临时目录。预检需要额外一份文件快照的磁盘空间。随后恢复新库和新目录，再核对逐文件内容、schema 和数据库中非删除文件的大小。只接受 UUID 普通文件，不解包链接或越界路径。恢复阶段失败留下的新目标供排查，不自动删除，不得接流量或当作成功恢复复用；重新演练另取新名字。校验和用于识别缺失、损坏和错配，不是备份来源的密码学认证；只恢复受控可信备份。

最后用匹配版本的 API 配置新数据库及 `FILE_STORAGE_DIR`，仅监听隔离 loopback 端口，启动后检查 `/health/ready`、`/api/v1/meta`、账号、私人及业务文件权限。不启动原服务来冒充恢复后的服务。脚本不自动部署或切换业务流量。

### Compose（本轮仅静态检查）

备份在停止 API 前检查运行中 API 的 build 与纯数据库名，后者必须匹配 PostgreSQL helper 的实际默认库；不匹配则拒绝，不输出连接 URL。停止后通过只读 `--volumes-from` helper 取文件，不复制运行中的 PostgreSQL 数据目录：

```sh
bash infra/paired-backup.sh /isolated/backups/new-bundle \
  --app-build <实际APP_BUILD_ID> \
  --compose /isolated/source.env infra/compose.yaml
# 如有覆盖配置，放在 compose.yaml 后；--compose 参数组必须放最后
```

恢复必须另设独立 `COMPOSE_PROJECT_NAME`、受控 env 和 loopback 端口，只启动其 PostgreSQL。不要使用源 stack 的项目名，不执行 `down -v`。以下仅用于隔离本地环境，不叠加会开放公网端口的 staging 覆盖文件：

```sh
export COMPOSE_PROJECT_NAME=jlu-dela-recovery-test
# recovery.env 的 POSTGRES_DB 用独立 bootstrap 库（如 recovery_admin），
# 不得等于下面由恢复脚本创建的 synthetic_restored；另设隔离密码与未占用 CADDY_PORT
# API_IMAGE/APP_BUILD_ID 必须是备份对应的已构建版本

docker compose --env-file /isolated/recovery.env -f infra/compose.yaml up -d --wait postgres
bash infra/paired-restore.sh /isolated/backups/new-bundle synthetic_restored \
  /isolated/restored-files --app-build <备份APP_BUILD_ID> \
  --compose /isolated/recovery.env infra/compose.yaml
export RESTORE_DATABASE=synthetic_restored RESTORE_FILES_DIR=/isolated/restored-files
docker compose --env-file /isolated/recovery.env -f infra/compose.yaml \
  -f infra/compose.restore.yaml config --quiet
docker compose --env-file /isolated/recovery.env -f infra/compose.yaml \
  -f infra/compose.restore.yaml up -d --no-build api caddy
```

恢复栈再次备份前，须把其受控 env 的 `POSTGRES_DB` 改为实际恢复库，并在维护窗口内重建该隔离栈的 PostgreSQL 容器，使容器环境生效；保留 `pgdata`，不删除卷或数据库，仅修改 env 文件不足以生效。API、迁移、PostgreSQL helper 必须指向同一库，仍使用恢复覆盖文件挂载新文件目录。不要在源栈执行这些恢复栈操作。

[`compose.restore.yaml`](../../infra/compose.restore.yaml) 将 API 与迁移指向新库，API bind mount 新文件目录，不触碰原 `filesdata`。恢复完成时 helper 配置 `10001:10001` 与 `700/600`，失败即退出。仍须在有 daemon 的环境检查非 root 写入及同 ID 内容可读：正常栈重建 API 保留原命名卷，恢复栈重建 API 保留新的 bind 目录和挂载。静态配置不证明这些行为。

## 本次复验（2026-11-14，Asia/Shanghai）

- Windows x64 / Git Bash 5.3.15 / PostgreSQL 16.15；重新检查 Docker 29.9.3 与 Compose 5.7.1，`docker version` 因 `docker_engine` 管道不存在而失败。没有容器非 root 写卷或重建验收，未运行生产操作。
- 从空目录初始化 `C:/Users/ZincG/JLU-Dela-recovery-verify-pg`（`127.0.0.1:55437`）、脚本回归集群 `C:/Users/ZincG/JLU-Dela-recovery-regression-pg`（`127.0.0.1:55438`）及最终复跑集群 `C:/Users/ZincG/JLU-Dela-recovery-final-pg`（`127.0.0.1:55439`），仅合成账号 `recovery_test`，不连接旧数据库。
- 修复前复现：使 `files.sha256` 与归档内容不一致并更新其外层摘要，旧脚本恢复了 `paired_preflight_repro` 及目标目录后才拒绝；本次新增预检后，相同回归在建库/建目标前拒绝，临时目录已清理。
- `bash infra/test-paired-backup.sh` 在新回归集群通过：成功、停止/备份/启动失败、缺件、损坏 dump/归档、逐文件清单错配、错误 build、已存在或重叠目标，以及旧格式兼容。格式化及纳入最新 main 后再从空集群完整复跑通过，最终保留材料：Git Bash `/tmp/tmp.cr9mms52wX`。
- `bash infra/test-backup-compose.sh` 的 6 项纯桩测试通过：数据库错配或非法库名在维护前拒绝，匹配库可到达下一预检，无连接 URL/合成密码输出。它不是实际容器验收。
- 显式执行现有 `cargo test --locked --features integration --test paired_restore -- --ignored --nocapture`，1 项通过；最新基线复跑恢复库 `paired_restore_a53d9c9c566640d7a80846bc79bde2e4`，合成材料 `C:/Users/ZincG/AppData/Local/Temp/.tmpC6L1pZ`。覆盖三账号、私人及两类业务关联、元信息和全部字节一致、同院/异院边界、恢复后密码登录，以及源库/源文件不变。测试专用业务夹具不是生产业务接口。
- 本次相关文件/迁移/报告测试为 9 项通过，1 项真实报告外网测试忽略；未调用真实短信、报告或私人数据。没有修改 Rust、Flutter 或契约代码，未执行 Flutter/契约全量检查。
- `cargo build --locked --bins` 通过后，用当前源码构建的 API 二进制完成真实 HTTP 演练：源 `recovery_http_source` / `127.0.0.1:18087`，恢复目标 `recovery_http_restored` / `127.0.0.1:18088`。两个开发模式合成账号，停止并等待源 PID 退出、备份后重启源 API、恢复后另起 API；两端 ready 均为 schema 9，meta build 相同，账号及全部文件元信息相同，上传者内容 SHA-256 相同，其他账号的元信息/内容请求均 404。Windows 停止发生在无在途请求窗口，不冒称验证 Unix 优雅退出。
- HTTP 文件 ID：`38b69198-6dcc-480c-aa8d-33d3cbcc178d`，SHA-256：`97829eb27209069acb9a333b75f31353505f4cfd40a4a3485866849b9b66f007`；bundle ID：`20261114T051914Z-1446`，版本为 `160015` / `16.15`。合成材料保留于 `C:/Users/ZincG/JLU-Dela-recovery-http-evidence`，执行器为源码外的 `C:/Users/ZincG/JLU-Dela-recovery-tools/http-recovery.ps1`；不提交 dump、令牌或运行日志。
- 全部 shell `bash -n`、改动脚本 shfmt 3.12.0、Markdown Prettier 3.6.2、`git diff --check` 及改动文档本地链接检查通过。Compose base/dev/staging/restore 静态展开通过，并断言恢复 API 只挂新 bind 目录、API/migrate 指向新库。没有运行 shellcheck（未安装），也没有将静态展开当作容器验收。
- HTTP API 日志经令牌、开发码、合成手机号及连接 URL 扫描未发现泄露。结束时仅停止本次两个 API 和三个 PostgreSQL 集群，测试端口均已关闭，合成数据库、bundle 和文件保留；未删库、未删卷、未触碰原工作区。

## 历史实测（2026-11-13，Asia/Shanghai）

Windows x64、Git Bash 5.3.15、PostgreSQL 16.15；新集群为 `C:/Users/ZincG/JLU-Dela-paired-backup-pg`，只监听 `127.0.0.1:55435`，合成账号 `paired_test`，不连接已有业务库。Docker CLI / Compose v5.7.1 可用，`docker version` 连接 `docker_engine` 管道失败，daemon 不可用；没有执行容器重建、非 root 卷写入或部署。

可复现的核心命令（PowerShell；不含秘密）：

```powershell
$env:PATH='C:\Users\ZincG\.local-pg\pgsql\bin;C:\Program Files\Git\bin;'+$env:PATH
$env:BASH='C:\Program Files\Git\bin\bash.exe'
$env:DATABASE_URL='postgres://paired_test@127.0.0.1:55435/postgres?sslmode=disable'
cd server
cargo test --locked --features integration --test paired_restore -- --ignored --nocapture
cargo test --locked --features integration --test files --test migrations --test student_reports
cargo fmt --all -- --check
cargo clippy --locked --all-targets --all-features -- -D warnings
cargo build --locked --bins
cd ..
$env:PGHOST='127.0.0.1'; $env:PGPORT='55435'; $env:PGUSER='paired_test'
$env:PGDATABASE='paired_backup_script_test'
& $env:BASH infra/test-paired-backup.sh
```

脚本测试会创建专用库，不删除库或已有目录；重复执行须另建隔离集群，不清理共享库来重跑。Rust 配套演练默认忽略，需显式执行，并保留合成 bundle 和新恢复库用于检查；它不依赖生产演示路由。

| 检查                                                 | 本轮结果                                                                                                                                                                     |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [配套恢复集成](../../server/tests/paired_restore.rs) | 1 项通过：3 合成账号、私人 / material / community_image 三文件；生产 router 上传、数据库及文件真正导出恢复，新库新目录快照相同；文件 ID、全部元信息、内容及 SHA-256 清单一致 |
| 账号与私人权限                                       | 既有会话和恢复后密码登录通过；上传者私人读取成功、其他账号 404；关联后私人入口拒绝，不能绕过业务                                                                             |
| 关联和学院权限                                       | 测试专用业务记录与 attach 同事务；用途及业务 ID 保留；同院允许、异院拒绝、错误用途/ID拒绝，在恢复前后相同；无生产业务假接口                                                  |
| 源数据不变                                           | 比较源库 users / sessions / reports / files / business / schema / migrations 与源目录全部字节，恢复及恢复库活动未改源数据                                                    |
| [脚本行为](../../infra/test-paired-backup.sh)        | 成功路径；停止失败后恢复、备份阶段失败后恢复、启动失败明确告警且无成功清单；缺归档 / 不完整 / 校验损坏备份、错误 build、旧库、已有/重叠目录全部拒绝                          |
| 相关 Rust 检查                                       | 格式、全目标全特性 Clippy、二进制构建通过；文件 3、迁移 2、报告 4 项通过，1 项真实报告外网测试忽略；配套恢复显式执行 1 项通过                                                |
| Shell / Compose                                      | 全部 shell `bash -n`、local/dev/staging 及恢复覆盖配置展开通过；断言恢复 API 仅 bind 新目录，API/migrate 均指向新库；没有 shellcheck，未冒称执行                             |
| 文档                                                 | 检查改动文档本地链接、Markdown 结构及 `git diff --check`，无 AGENTS / 迁移 / OpenAPI / Flutter 代码改动                                                                      |

另用实际 debug API 二进制完成 HTTP 演练：隔离源库 `paired_http_source3`、源端口 `18085`，两个开发模式合成手机号账号；上传 50 字节人工文本后停止该 PID 并等待退出，脚本导出数据库及文件，再启动源 API。恢复到 `paired_http_restored` 与新目录后启动端口 `18086` 的匹配 API；两端 ready 为 schema 9、相同账号及文件元信息一致，上传者下载正确、另一账号 404。文件 ID 为 `6cde15d2-0bfe-4d13-a7e4-2c146822e532`，SHA-256 为 `893b327b39129d4028da59018b2b0446a0afced62e2ed1d6f3b1af9645c4cf8c`。测试结束只停止本轮两个 API 进程及本轮 PostgreSQL 集群，未删库或目录；集群可由维护者用 `pg_ctl -D C:/Users/ZincG/JLU-Dela-paired-backup-pg -l C:/Users/ZincG/JLU-Dela-paired-backup-pg.log -o "-h 127.0.0.1 -p 55435" -w start` 重新检查。原生 Windows stop hook 在无在途请求的窗口等待指定 PID 退出；不把强停止视作 Unix 优雅退出已验收。

本机额外演练命令为 `pwsh -File C:/Users/ZincG/JLU-Dela-paired-backup-evidence/http-recovery.ps1`（源码外测试材料，不纳入生产脚本）；合成 bundle、源/恢复文件及 API 日志保留于同一目录。2026-11-14 提交前重跑 Clippy、相关 9 项测试及配套恢复 1 项全部通过，真实报告外网 1 项仍忽略。最新保留的恢复库为 `paired_restore_bacd11be10c94a89a859597a5ed921fb`，合成材料位于 `C:/Users/ZincG/AppData/Local/Temp/.tmpi43ntw`；脚本行为材料位于 Git Bash `/tmp/tmp.8YuwhcDiEM`。这些本机路径是验收记录，不是异地备份位置，不提交其中的 dump、令牌或运行数据。

初次演练发现 Windows 系统 `bash.exe` 实际是 WSL 入口、原生 psql 输出 CRLF、GNU tar 将 `C:` 当远端地址；分别使用显式 `BASH`、只对 psql 文本去 CR 和 `--force-local` 修复后重跑通过。失败均没有被计为成功恢复，原 API/协议未为测试改动。

剩余依赖：B / D 各交付真实业务流程后再做发布、下架、改范围、资料引用的双账号联调；Docker daemon 环境补容器验收；部署主机、版本制品、异地备份位置、加密保留与责任人未提供。真实短信继续暂缓，未调用真实报告或私人数据；本流程不是个人多端同步。
