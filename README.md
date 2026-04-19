# compose

Docker Compose 编排：唐僧叨叨（`server` / `web` / `manager`）+ MySQL + Redis + MinIO + 悟空 IM（`wukongim`）。

## 目录与克隆建议

`docker-compose.yaml` 中 `build.context` 使用**与 compose 目录同级的**源码目录，推荐本机目录结构：

```text
<工作区父目录>/
  compose/              # 本仓库
  wukongim/             # 悟空 IM 源码（`wukongim` 服务 `build.context` 指向此处）
  chinaim-server/       # 业务后端
  chinaim-web/          # 用户端 Web
  chinaim-manager/      # 管理后台
```

若路径不同，请修改 `docker-compose.yaml` 里各服务的 `build.context`。

主栈 `wukongim` 使用**本地镜像构建**（`image: wukongim:local`），不在 compose 里拉取阿里云 IM 镜像；构建逻辑与 `wukongim` 仓库根目录 `Dockerfile` 一致（容器内先打 `web/`、`demo/chatdemo/` 再 `go build`）。

### 表情商店贴纸（MinIO 种子，已进 Git）

矢量贴纸与封面在 **`seed/minio-file-bucket/preview/sticker/`**（桶 `file` 的对象前缀 `preview/sticker/`），与库里 `sticker_store` 路径一致（约 13MB 逻辑文件）。**整份 `miniodata/` 仍不提交**（含头像与业务上传）。

新环境在 `docker compose up -d` 起 MinIO 后执行一次：

```bash
sh scripts/seed-sticker-store-to-minio.sh
```

详见 **`seed/README.md`**。

## 环境变量（`.env`）

- 仓库中的 `.env` 为**脱敏示例**（敏感位为 `*`），仅说明变量含义与格式。
- 部署时：复制为 `.env` 后填入真实密码、公网 IP、JWT 密钥等。
- **切勿**将含真实密码的 `.env` 推送到公开仓库；本地可自行保留 `.env.private` 备份（已在 `.gitignore` 中忽略）。

### 宿主机 Nginx 反代（可选）

若在生产或本机**宿主机**上再跑一层 Nginx，把公网域名指到 compose 已映射的端口（默认 API `8090`、用户 Web `82`、管理后台 `83`），可使用仓库中的示例配置：

| 文件 | 是否提交 Git | 说明 |
|------|----------------|------|
| **`http-reverse-proxy.conf.example`** | **是** | 占位域名 `im.example.com`、`admin.example.com`，上游为 `host.docker.internal`（与常见 Docker Desktop 一致）。 |
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

改完 `.env` 后重建：

```bash
docker compose build web manager
docker compose up -d web manager
```

**Web 镜像构建提速**：`chinaim-web` 的 `Dockerfile` 已将 `yarn install` 与源码分层，并启用 Yarn 缓存挂载；日常重建 **Web** 请用 `docker compose build web`，**避免习惯性加 `--no-cache`**，否则会整包重装依赖。若新增 `apps/*` / `packages/*` workspace，需在 `chinaim-web/Dockerfile` 中补充对应 `COPY …/package.json` 行（详见 **`../chinaim-web/README.md`** 中「Docker 镜像构建（提速与维护）」）。

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

在项目根目录（本仓库）执行：

```bash
docker compose build
docker compose up -d
```

仅重建管理后台示例：

```bash
docker compose build manager && docker compose up -d manager
```

仅重建用户端 Web（依赖未改时通常较快）：

```bash
docker compose build web && docker compose up -d web
```

## 管理后台「以此用户视角查看」

- `manager` 服务环境变量 `CLIENT_WEB_URL` 默认由 compose 写为 `http://${EXTERNAL_IP}:${TS_WEB_PORT}`，也可在 `.env` 中设置 `CLIENT_WEB_URL` 覆盖（例如 HTTPS 域名）。
- 镜像启动时会把该值写入 `tsdd-config.js` 供前端读取（见 [chinaimchat/manager](https://github.com/chinaimchat/manager) 仓库）。

## 其他编排文件

- `docker-compose.cluster.yaml`、`docker-compose.gateway.yaml`、`docker-compose.monitor.yaml` 为扩展/参考用途，默认主栈以 `docker-compose.yaml` 为准。
- `docker-compose.cluster.yaml` 中 IM 节点同样 `build: ../wukongim`，需同级存在 `wukongim`；集群用到的 `./nginx.conf`、`./prometheus.yml` 等请自备（可参考 `wukongim/docker/cluster/`）。
