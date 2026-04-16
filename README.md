# compose

Docker Compose 编排：唐僧叨叨（`server` / `web` / `manager`）+ MySQL + Redis + MinIO + 悟空 IM（`wukongim`）。

## 目录与克隆建议

`docker-compose.yaml` 中 `build.context` 使用**与 compose 目录同级的**源码目录，推荐本机目录结构：

```text
<工作区父目录>/
  compose/              # 本仓库
  chinaim-server/       # 业务后端
  chinaim-web/          # 用户端 Web
  chinaim-manager/      # 管理后台
```

若路径不同，请修改 `docker-compose.yaml` 里各服务的 `build.context`。

## 环境变量（`.env`）

- 仓库中的 `.env` 为**脱敏示例**（敏感位为 `*`），仅说明变量含义与格式。
- 部署时：复制为 `.env` 后填入真实密码、公网 IP、JWT 密钥等。
- **切勿**将含真实密码的 `.env` 推送到公开仓库；本地可自行保留 `.env.private` 备份（已在 `.gitignore` 中忽略）。

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

## 管理后台「以此用户视角查看」

- `manager` 服务环境变量 `CLIENT_WEB_URL` 默认由 compose 写为 `http://${EXTERNAL_IP}:${TS_WEB_PORT}`，也可在 `.env` 中设置 `CLIENT_WEB_URL` 覆盖（例如 HTTPS 域名）。
- 镜像启动时会把该值写入 `tsdd-config.js` 供前端读取（见 [chinaimchat/manager](https://github.com/chinaimchat/manager) 仓库）。

## 其他编排文件

- `docker-compose.cluster.yaml`、`docker-compose.gateway.yaml`、`docker-compose.monitor.yaml` 为扩展/参考用途，默认主栈以 `docker-compose.yaml` 为准。
