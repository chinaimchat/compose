# compose

Docker Compose 编排：唐僧叨叨（`server` / `web` / `manager`）+ MySQL + Redis + MinIO + 悟空 IM（`wukongim`）。

**从零到可访问的总流程（线性教程）**：见 **[`docs/SETUP.zh.md`](docs/SETUP.zh.md)**。  
**近似一键（IP + 可选用户端 URL；`.env` 须已改强密码）**：`sh scripts/bootstrap-new-host.sh [--clone] <公网IP> [https://你的用户端域名]`。`--clone` 会从 **GitHub [`chinaimchat`](https://github.com/chinaimchat)** 拉 `wukongim`、`server`、`web`、`manager`（与 `docker-compose.yaml` 中 `build.context` 目录名一致）。详见 **`docs/SETUP.zh.md`** 第三节表格。

## 目录与克隆建议

`docker-compose.yaml` 中 `build.context` 使用**与 compose 目录同级的**源码目录，推荐本机目录结构：

```text
<工作区父目录>/
  compose/              # 本仓库
  wukongim/             # 悟空 IM 源码（`wukongim` 服务 `build.context` 指向此处）
  server/               # 业务后端
  web/                  # 用户端 Web
  manager/              # 管理后台
```

若路径不同，请修改 `docker-compose.yaml` 里各服务的 `build.context`。

主栈 `wukongim` 使用**本地镜像构建**（`image: wukongim:local`），不在 compose 里拉取阿里云 IM 镜像；构建逻辑与 `wukongim` 仓库根目录 `Dockerfile` 一致（容器内先打 `web/`、`demo/chatdemo/` 再 `go build`）。

### 表情商店贴纸（MinIO 种子，已进 Git）

矢量贴纸与封面在 **`seed/minio-file-bucket/preview/sticker/`**（桶 `file` 的对象前缀 `preview/sticker/`），与库里 `sticker_store` 路径一致（约 13MB 逻辑文件）。**整份 `miniodata/` 仍不提交**（含头像与业务上传）。

新环境在 **MinIO 已就绪**后执行一次种子（二选一）：

1. **推荐（与 compose 编排一致）**：使用带 **`profiles: ["seed"]`** 的服务 **`sticker-seed`**（同一 Docker 网络访问 `minio:9000`，无需再拉 `minio/mc` 到宿主机）：

   ```bash
   docker compose up -d minio
   docker compose --profile seed run --rm sticker-seed
   ```

   若与其它服务一并启动后再补种子，只要 MinIO 在跑即可再次执行上述 `run`（`mc cp` 可覆盖，幂等）。

2. **备选**：宿主机脚本（适合不便用 compose `run` 的环境）：

   ```bash
   sh scripts/seed-sticker-store-to-minio.sh
   ```

详见 **`seed/README.md`**。CI 在 **`.github/workflows/compose.yml`** 中对 `docker compose config` 与 **`sticker-seed` 冒烟**（仅 MinIO + seed）做校验。

## 环境变量（`.env`）

- 仓库提供 **`.env.example`** 为**脱敏模板**（敏感位为 `*`），仅说明变量含义与格式。
- 部署时：`cp .env.example .env` 后填入真实密码、公网 IP、JWT 密钥等（**`.env` 已列入 `.gitignore`，勿提交**）。
- **切勿**将含真实密码的 `.env` 推送到公开仓库；本地可自行保留 `.env.private` 备份（已在 `.gitignore` 中忽略）。

### 宿主机 Nginx 反代（可选）

若在生产或本机**宿主机**上再跑一层 Nginx，把公网域名指到 compose 已映射的端口（默认 API `8090`、用户 Web `82`、管理后台 `83`），可使用仓库中的示例配置：

| 文件 | 是否提交 Git | 说明 |
|------|----------------|------|
| **`http-reverse-proxy.conf.example`** | **是** | 占位域名 `im.example.com`、`admin.example.com`，上游为 `host.docker.internal`（与常见 Docker Desktop 一致）。 |
| **`docs/nginx-host-http-mb4au.conf`** | **是** | 示例：`mb4au.com`/`www`→本机 **82**、`houtai.mb4au.com`→**83**，上游 **127.0.0.1**；文件末注释含 App 常用 API/IM 地址。 |
| **`http-reverse-proxy.conf`** | **否**（`.gitignore`） | 由示例复制后本地修改，写入真实域名；**勿提交**，避免泄露生产域名与拓扑。 |

初始化命令：

```bash
cp http-reverse-proxy.conf.example http-reverse-proxy.conf
# 编辑 http-reverse-proxy.conf：替换 server_name、必要时将 host.docker.internal 改为 127.0.0.1
```

请与 `.env` 里的 **`WEB_SERVER_NAME`、`MANAGER_SERVER_NAME`**（容器内 Nginx 的 `server_name`）及 **`CLIENT_WEB_URL`** 使用**同一套域名策略**（HTTPS、证书、多域名等需在宿主机与容器两侧一致规划）。

### 迁移到新服务器时最少改动

原则：尽量只改 `.env`，不要改源码中的域名。

- 对外访问域名：
  - `CLIENT_WEB_URL`（用户端 Web 地址）
- 容器内反代设置：
  - `INTERNAL_API_URL`（默认 `http://server:8090/`，通常不改）
  - `WEB_SERVER_NAME`（web 容器 Nginx `server_name`）
  - `MANAGER_SERVER_NAME`（manager 容器 Nginx `server_name`）

改完 `.env` 后重建镜像并启动（在对应源码目录 `docker build`，再在 `compose/` 里 `up`）：

```bash
cd ../web && docker build -t web:v1 -f Dockerfile .
cd ../manager && docker build -t houtai:v1 -f Dockerfile .
cd ../compose && docker compose up -d web manager
```

**Web 镜像构建提速**：`web` 仓库的 `Dockerfile` 已将 `yarn install` 与源码分层，并启用 Yarn 缓存挂载；日常重建请用 **`docker build -t web:v1 -f Dockerfile .`（在 `web/` 目录）**，**避免习惯性加 `--no-cache`**，否则会整包重装依赖。若新增 `apps/*` / `packages/*` workspace，需在 `web/Dockerfile` 中补充对应 `COPY …/package.json` 行（详见 **`../web/README.md`** 中「Docker 镜像构建（提速与维护）」）。

### 发布前域名残留检查

```bash
sh compose/scripts/check-legacy-domains.sh
```

- 默认检查历史域名：`sdsf1.com`、`xh-gc.com`
- 可附加自定义待检查域名：

```bash
sh compose/scripts/check-legacy-domains.sh old-domain.com test.example.com
```

## 常用命令

本机约定：**先在各源码目录手动 `docker build` 出 `wukongim:local`、`server:v1`、`web:v1`、`houtai:v1`**（见 `docker-compose.yaml` 顶部注释），再在本仓库执行：

```bash
docker compose up -d
```

如需让 Compose 自动构建（旧习惯），可自行在 `docker-compose.yaml` 里为对应服务恢复 `build:` 段。

仅重建管理后台示例：

```bash
cd ../manager && docker build -t houtai:v1 -f Dockerfile . && cd ../compose && docker compose up -d manager
```

仅重建用户端 Web（依赖未改时通常较快）：

```bash
cd ../web && docker build -t web:v1 -f Dockerfile . && cd ../compose && docker compose up -d web
```

### ⚠️ 重新构建 / 重建 `server` 时必须连同 `web` `manager` 一起重启

`web`、`manager` 容器内 Nginx 的 `proxy_pass http://server:8090/` 在 worker
启动时会把 `server` 解析为静态 IP 并**永久缓存**。若单独 `--build` 或
`--force-recreate` 了 `server`，新容器会拿到新的 docker network IP，旧 IP
甚至可能被复用给别的容器，导致 `web/manager` 把 `/api/...` 反代到错误的
后端，出现 502（`connect() failed (111: Connection refused)`），表现为
**「后台/Web 接口全部失败、看起来什么数据都没有」**（数据库没事）。

**两种推荐做法（任选其一）：**

```bash
# 1) 先打 server 镜像，再连同 web、manager 一并强制重建，让它们重新解析 server 的 IP
cd ../server && docker build -t server:v1 -f Dockerfile .
cd ../compose && docker compose up -d --force-recreate server web manager

# 2) 分步骤：用仓库自带脚本（先 docker build server，等 healthy 后重启 web、manager）
sh scripts/rebuild-server.sh            # = build server 镜像 + recreate server，再 restart web manager
sh scripts/rebuild-server.sh --no-build # 仅 recreate server（不重新打镜像）
```

> 不要只 `docker compose up -d --force-recreate server` 而不重启 `web`/`manager`，否则其
> Nginx 仍会指向旧 IP。

## 管理后台「以此用户视角查看」

- `manager` 服务环境变量 `CLIENT_WEB_URL` 默认由 compose 写为 `http://${EXTERNAL_IP}:${TS_WEB_PORT}`，也可在 `.env` 中设置 `CLIENT_WEB_URL` 覆盖（例如 HTTPS 域名）。
- 镜像启动时会把该值写入 `tsdd-config.js` 供前端读取（见 [chinaimchat/manager](https://github.com/chinaimchat/manager) 仓库）。

## 后端对外 BaseURL（`TS_EXTERNAL_BASEURL`）

server 生成的「我的二维码 / 群二维码 / 扫码登录二维码 / 邀请链接」等 URL 都基于
`External.BaseURL` 拼接：`<BaseURL>/v1/qrcode/<code>`。**请务必显式配成对外可访问、
且能反代到 `server:8090` 的根地址**，否则会回退成 `http://<内网 IP>:8090/v1/...`：

- 既丑（暴露内网 IP+端口）；
- 又会让客户端「扫码后判断 host 是否可信」逻辑频繁误判，导致 token 不被附带、二维码登录走不通。

`.env` 已默认设置：

```env
# 与 web 容器内 nginx 的 `/api/ → server:8090/` 反代规则匹配
TS_EXTERNAL_BASEURL=http://web.example.com/api
# H5 域名不同的话再单独覆盖；不写默认跟随 BaseURL
# TS_EXTERNAL_H5BASEURL=http://web.example.com
```

切换部署形态时记得同步修改：

| 反代方式 | `TS_EXTERNAL_BASEURL` |
| --- | --- |
| 走 web 容器 nginx 的 `/api/`（推荐） | `http://<对外域名>/api` |
| 走宿主机 nginx 的 `/v1/` 直连 `:8090` | `http://<对外域名>` |
| 直接暴露 `:8090` 给客户端 | `http://<对外域名>:8090` |

> 改完 `TS_EXTERNAL_BASEURL` 必须重建/重启 `server`：环境变量是启动时读入的。

## 其他编排文件

- `docker-compose.cluster.yaml`、`docker-compose.gateway.yaml`、`docker-compose.monitor.yaml` 为扩展/参考用途，默认主栈以 `docker-compose.yaml` 为准。
- `docker-compose.cluster.yaml` 中 IM 节点同样 `build: ../wukongim`，需同级存在 `wukongim`；集群用到的 `./nginx.conf`、`./prometheus.yml` 等请自备（可参考 `wukongim/docker/cluster/`）。
