# PostgreSQL 与文件配套备份恢复

## 范围与恢复点

基线为 `upstream/main=8f4f829d79b83a30097c1e3d895ccac13713e0f7`，PR #37、#38、#39 均已合并。2026-11-14 提交前复查 main 未变化，E 新增待合并的 PR #40、#41；本轮不重复集成其代码。本轮使用独立 `codex/paired-backup-integration` worktree，未改根工作区或 `AGENTS.md`。本地验收完成后，按用户授权提交分支及面向 main 的 PR，不自动合并或部署。

[`paired-backup.sh`](../../infra/paired-backup.sh) 在维护窗口停止 API，等待停止命令完成后导出 PostgreSQL 并归档对应文件，最后恢复 API。窗口内维护者须禁止其他写入进程、直接 SQL 和迁移；脚本不能保证外部写入者的一致性。原生 stop hook 必须等待请求及进程退出，失败须返回非零，不能只是发送一个异步停止信号。本轮没有新增在线备份、WAL/PITR、调度或同步系统。

每个新 bundle 包含：

- `database.dump`：现有 `pg_dump --format=custom --no-owner --no-privileges` 逻辑导出，包含账号、文件元信息、业务关联及迁移账本，但不含附件字节。
- `files.tar`：`FILE_STORAGE_DIR` 或 API 文件挂载中的全部 UUID 文件，包含可能尚无业务记录的内容，不自动 GC。
- `files.sha256`：逐文件 SHA-256。
- `manifest.env`：同一备份 ID、UTC 时间、应用 commit/build、schema、源数据库名与文件位置、上述三份文件的 SHA-256。不执行或 `source` 清单内容；缺项、重复项、校验不符即拒绝。

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

恢复先检查清单、三份校验和、归档条目、数据库及目录目标，再恢复新库和新目录；核对逐文件内容、schema 和数据库中非删除文件的大小。只接受 UUID 普通文件，不解包链接或越界路径。失败留下的新目标供排查，不自动删除，不得接流量或当作成功恢复复用；重新演练另取新名字。

最后用匹配版本的 API 配置新数据库及 `FILE_STORAGE_DIR`，仅监听隔离 loopback 端口，启动后检查 `/health/ready`、`/api/v1/meta`、账号、私人及业务文件权限。不启动原服务来冒充恢复后的服务。脚本不自动部署或切换业务流量。

### Compose（本轮仅静态检查）

备份使用当前 stack 的 API 挂载，停止 API 后通过只读 `--volumes-from` helper 取文件，不复制运行中的 PostgreSQL 数据目录：

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

[`compose.restore.yaml`](../../infra/compose.restore.yaml) 将 API 与迁移指向新库，API bind mount 新文件目录，不触碰原 `filesdata`。恢复完成时 helper 配置 `10001:10001` 与 `700/600`，失败即退出。仍须在有 daemon 的环境检查非 root 写入及同 ID 内容可读：正常栈重建 API 保留原命名卷，恢复栈重建 API 保留新的 bind 目录和挂载。静态配置不证明这些行为。

## 本轮实测（2026-11-13，Asia/Shanghai）

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

| 检查 | 本轮结果 |
| --- | --- |
| [配套恢复集成](../../server/tests/paired_restore.rs) | 1 项通过：3 合成账号、私人 / material / community_image 三文件；生产 router 上传、数据库及文件真正导出恢复，新库新目录快照相同；文件 ID、全部元信息、内容及 SHA-256 清单一致 |
| 账号与私人权限 | 既有会话和恢复后密码登录通过；上传者私人读取成功、其他账号 404；关联后私人入口拒绝，不能绕过业务 |
| 关联和学院权限 | 测试专用业务记录与 attach 同事务；用途及业务 ID 保留；同院允许、异院拒绝、错误用途/ID拒绝，在恢复前后相同；无生产业务假接口 |
| 源数据不变 | 比较源库 users / sessions / reports / files / business / schema / migrations 与源目录全部字节，恢复及恢复库活动未改源数据 |
| [脚本行为](../../infra/test-paired-backup.sh) | 成功路径；停止失败后恢复、备份阶段失败后恢复、启动失败明确告警且无成功清单；缺归档 / 不完整 / 校验损坏备份、错误 build、旧库、已有/重叠目录全部拒绝 |
| 相关 Rust 检查 | 格式、全目标全特性 Clippy、二进制构建通过；文件 3、迁移 2、报告 4 项通过，1 项真实报告外网测试忽略；配套恢复显式执行 1 项通过 |
| Shell / Compose | 全部 shell `bash -n`、local/dev/staging 及恢复覆盖配置展开通过；断言恢复 API 仅 bind 新目录，API/migrate 均指向新库；没有 shellcheck，未冒称执行 |
| 文档 | 检查改动文档本地链接、Markdown 结构及 `git diff --check`，无 AGENTS / 迁移 / OpenAPI / Flutter 代码改动 |

另用实际 debug API 二进制完成 HTTP 演练：隔离源库 `paired_http_source3`、源端口 `18085`，两个开发模式合成手机号账号；上传 50 字节人工文本后停止该 PID 并等待退出，脚本导出数据库及文件，再启动源 API。恢复到 `paired_http_restored` 与新目录后启动端口 `18086` 的匹配 API；两端 ready 为 schema 9、相同账号及文件元信息一致，上传者下载正确、另一账号 404。文件 ID 为 `6cde15d2-0bfe-4d13-a7e4-2c146822e532`，SHA-256 为 `893b327b39129d4028da59018b2b0446a0afced62e2ed1d6f3b1af9645c4cf8c`。测试结束只停止本轮两个 API 进程及本轮 PostgreSQL 集群，未删库或目录；集群可由维护者用 `pg_ctl -D C:/Users/ZincG/JLU-Dela-paired-backup-pg -l C:/Users/ZincG/JLU-Dela-paired-backup-pg.log -o "-h 127.0.0.1 -p 55435" -w start` 重新检查。原生 Windows stop hook 在无在途请求的窗口等待指定 PID 退出；不把强停止视作 Unix 优雅退出已验收。

本机额外演练命令为 `pwsh -File C:/Users/ZincG/JLU-Dela-paired-backup-evidence/http-recovery.ps1`（源码外测试材料，不纳入生产脚本）；合成 bundle、源/恢复文件及 API 日志保留于同一目录。2026-11-14 提交前重跑 Clippy、相关 9 项测试及配套恢复 1 项全部通过，真实报告外网 1 项仍忽略。最新保留的恢复库为 `paired_restore_bacd11be10c94a89a859597a5ed921fb`，合成材料位于 `C:/Users/ZincG/AppData/Local/Temp/.tmpi43ntw`；脚本行为材料位于 Git Bash `/tmp/tmp.8YuwhcDiEM`。这些本机路径是验收记录，不是异地备份位置，不提交其中的 dump、令牌或运行数据。

初次演练发现 Windows 系统 `bash.exe` 实际是 WSL 入口、原生 psql 输出 CRLF、GNU tar 将 `C:` 当远端地址；分别使用显式 `BASH`、只对 psql 文本去 CR 和 `--force-local` 修复后重跑通过。失败均没有被计为成功恢复，原 API/协议未为测试改动。

剩余依赖：B / D 各交付真实业务流程后再做发布、下架、改范围、资料引用的双账号联调；Docker daemon 环境补容器验收；部署主机、版本制品、异地备份位置、加密保留与责任人未提供。真实短信继续暂缓，未调用真实报告或私人数据；本流程不是个人多端同步。
