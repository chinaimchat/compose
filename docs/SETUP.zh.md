# 从零搭建总教程（compose 全栈）

本文把 **compose + 唐僧叨叨三端 + 悟空 IM** 在一台新机器上的推荐顺序串成一条线；细节分散在仓库各处时，这里只写「先做什么、再做什么」。

---

## 一、你要得到什么

跑起来后，典型端口（可在 `.env` 改）：

| 能力 | 宿主机端口（默认） |
|------|---------------------|
| 业务 API（server） | 8090 |
| 用户 Web | 82 |
| 管理后台 | 83 |
| 悟空 IM TCP / WS / 内置监控 | 5100 / 5200 / 5300 |
| MySQL / Redis / MinIO | 容器内网为主；MinIO 控制台常映射 9001 |

---

## 二、前置条件

- 已安装 **Docker** 与 **Docker Compose V2**（支持 `profiles`、无 `version` 字段的 compose 文件）。
- 新机能 **拉镜像**：主栈里 MySQL / Redis / MinIO 仍使用 **阿里云 registry**；若拉不动，需自行改 `docker-compose.yaml` 中的镜像地址（例如换 Docker Hub 官方镜像）并自测。
- 磁盘：数据库与 MinIO 数据在 **`./mysqldata`、`./miniodata`** 等目录增长，预留空间。

---

## 三、目录怎么摆（必须）

与 **`docker-compose.yaml` 里 `build.context` 一致**，在**同一父目录**下克隆：

```text
<父目录>/
  compose/
  wukongim/
  chinaim-server/
  chinaim-web/
  chinaim-manager/
```

路径不对就改 compose 里各服务的 `context`，否则 `docker compose build` 会失败。

---

## 四、推荐搭建顺序（照着做）

### 1. 准备环境变量

- 使用仓库里的 **`.env` 模板**（占位符、脱敏），复制后改成你的 **公网 IP/域名、强密码、JWT** 等。
- **不要**把含真实密码的 `.env` 推 Git；本地备份可用 **`.env.private`**（已在 `.gitignore`）。
- 与头像、表情商店相关的常用项：
  - **`TS_AVATAR_DEFAULTBASEURL`**：注册时默认头像图片来源（不配则用程序内置 Dicebear）；与现网一致就填同一套。
  - **`WEB_SERVER_NAME` / `MANAGER_SERVER_NAME` / `CLIENT_WEB_URL`**：与域名、反代一致（见下文）。

### 2. 构建并启动全栈

在 **`compose/`** 目录：

```bash
docker compose build
docker compose up -d
```

首次构建会编 **wukongim**（Dockerfile 内含前端 `yarn build` + Go）、**server / web / manager** 等，耗时正常偏长。

#### 近似「一键」（已克隆五仓库、`.env` 已改好强密码后）

在 **`compose/`** 下执行（**第一个参数必须是公网 IPv4**，不要用域名代替；域名可选写在第二参数作为用户端根地址）：

```bash
sh scripts/bootstrap-new-host.sh 你的公网IP
# 若用户端用 HTTPS 域名访问 Web，可同时写入 CLIENT_WEB_URL：
sh scripts/bootstrap-new-host.sh 你的公网IP https://im.example.com
```

脚本会：检查同级 `wukongim` 等目录 → 写 **`EXTERNAL_IP`**、**`TS_MINIO_DOWNLOADURL`**（`http://IP:9000`）→（可选）**`CLIENT_WEB_URL`** → **`docker compose build` + `up -d`** → 等 MinIO 健康后跑 **`sticker-seed`**。  
**不会**替你生成强密码；若 `.env` 里仍是仓库模板那种纯 `*` 密码会直接退出。可选 `--skip-build` / `--skip-seed` 见脚本内 `usage`。

### 3. 表情商店贴纸种子（只做一次即可，可重复执行）

MinIO 里 **`file/preview/sticker/`** 的矢量贴纸**不在**整库 `miniodata` 的 Git 里；仓库带了 **`seed/`**。

MinIO 健康后执行（二选一）：

```bash
docker compose --profile seed run --rm sticker-seed
```

或：`sh scripts/seed-sticker-store-to-minio.sh`（见根目录 `README.md` / `seed/README.md`）。

### 4.（可选）宿主机 Nginx 反代

若要用 80/443 域名访问：

```bash
cp http-reverse-proxy.conf.example http-reverse-proxy.conf
# 编辑真实域名；真实文件已被 .gitignore，勿提交
```

并与 `.env` 里 **`WEB_SERVER_NAME`、`MANAGER_SERVER_NAME`、`CLIENT_WEB_URL`** 对齐。

### 5. 验证

- API：`curl -sS http://127.0.0.1:8090/v1/ping`（端口以 `.env` 为准）。
- Web / 管理后台：浏览器打开对应端口。
- 注册新用户：若外网能访问 Dicebear（或你配置的 `TS_AVATAR_DEFAULTBASEURL`），头像应能自动拉取并写入 MinIO；否则检查网络或 MinIO 默认头像是否预置。

---

## 五、和「现网同一套」要对齐什么

| 项目 | 说明 |
|------|------|
| `.env` | 密码、域名、`TS_AVATAR_DEFAULTBASEURL`、IM JWT 等与现网策略一致。 |
| **贴纸** | 执行一次 **sticker-seed**（或脚本）；与现网同一套 `seed/` 即一致。 |
| **业务数据** | `mysqldata/`、`miniodata/` 下除种子外的数据**不**在 Git；迁机需自行备份/恢复。 |

---

## 六、相关文档与仓库

| 内容 | 位置 |
|------|------|
| compose 常用说明、反代、贴纸索引 | 仓库根 **`README.md`** |
| 贴纸种子说明 | **`seed/README.md`** |
| 悟空 IM 本地构建（非 Docker 时） | **`wukongim` 仓库** `README_CN.md` / `Makefile`（`make build-native`） |
| Web 镜像分层与提速 | **`chinaim-web` 仓库** `README.md` |
| 业务配置示例 | **`chinaim-server`** 下 `docker/tsdd/configs/tsdd.yaml`、`/.env.example` |
| CI | **`compose`** `.github/workflows/compose.yml`（compose 校验 + MinIO 冒烟种子） |

---

## 七、常见问题（一句话）

- **只 clone 了 compose 起不来**：缺同级 **`wukongim` / `chinaim-server` / `chinaim-web` / `chinaim-manager`**。  
- **表情商店空白**：未跑 **sticker-seed** 或 MinIO 未就绪。  
- **拉镜像失败**：检查到 **阿里云 registry** 的网络；或改公共镜像。  
- **注册后头像异常**：检查 **`TS_AVATAR_DEFAULTBASEURL`** 与出网；失败时会走 MinIO 默认图路径，需自行预置或修网络。

---

若你希望把某一步（例如「仅阿里云换官方镜像」）单独拆成补丁文档，可在 issue 里说明场景再补一篇。
