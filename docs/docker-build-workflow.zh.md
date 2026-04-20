# 镜像构建与启动约定

与 `docker-compose.yaml` 顶部注释一致：**不在 `docker compose up` 时自动构建业务镜像**，先在各源码目录打固定 tag，再在 `compose/` 执行 `up`。

```bash
cd ../wukongim && docker build -t wukongim:local -f Dockerfile .
cd ../server   && docker build -t server:v1   -f Dockerfile .
cd ../web      && docker build -t web:v1      -f Dockerfile .
cd ../manager  && docker build -t houtai:v1   -f Dockerfile .
cd ../compose  && docker compose up -d
```

安全重建 `server` 并刷新 web/manager 内 Nginx 对后端的解析：`sh scripts/rebuild-server.sh`。
