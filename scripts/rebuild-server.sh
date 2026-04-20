#!/usr/bin/env sh
# 安全重建 server：避免 web / manager 内的 Nginx 缓存旧 server IP。
#
# 背景：web、manager 的 nginx 配置里 `proxy_pass http://server:8090/`
# 在 worker 启动时会把 `server` 解析为静态 IP 并缓存。重新构建/重建
# `server` 后新容器会拿到新的 docker network IP，旧 IP 可能已被复用
# 给其它容器，导致 502（connect refused）/ "后台没数据"。
#
# 本脚本按依赖顺序：
#   1) 重新构建并重建 server
#   2) 等待 server healthy
#   3) 重启 web / manager（让它们的 nginx 重新解析 server 的 IP）
#
# 用法：
#   sh scripts/rebuild-server.sh                    # 默认：build + recreate
#   sh scripts/rebuild-server.sh --no-build          # 仅重建（不重新打镜像）
#   sh scripts/rebuild-server.sh --pull              # 重新构建时拉取上游基础镜像
#
# 也可以一次到位（先打镜像再 up）：
#   docker build -t server:v1 -f ../server/Dockerfile ../server && docker compose up -d --force-recreate server web manager
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
PARENT="$(CDPATH= cd -- "$ROOT/.." && pwd)"
cd "$ROOT"

BUILD=1
PULL_FLAG=""
for a in "$@"; do
  case "$a" in
    --no-build) BUILD=0 ;;
    --pull) PULL_FLAG="--pull" ;;
    -h|--help)
      sed -n '1,30p' "$0"
      exit 0
      ;;
    *) echo "未知参数: $a" >&2; exit 2 ;;
  esac
done

echo "==> [1/3] 重新构建并重建 server"
if [ "$BUILD" = "1" ]; then
  docker build $PULL_FLAG -t server:v1 -f "$PARENT/server/Dockerfile" "$PARENT/server"
  docker compose up -d --no-build --force-recreate server
else
  # --no-build：明确禁用本次构建并跳过依赖（wukongim 等），只用既有镜像 recreate server。
  # 这样能确保仅是 .env / docker-compose.yaml 的环境变量调整也能让 server 重新读取，
  # 而不会因为某个依赖镜像不在本地（例如 wukongim:local）而中断。
  docker compose up -d --no-build --no-deps --force-recreate server
fi

echo "==> [2/3] 等待 server healthy（最多 60s）"
ok=0
i=0
while [ $i -lt 30 ]; do
  status="$(docker inspect -f '{{.State.Health.Status}}' compose-server-1 2>/dev/null || echo unknown)"
  if [ "$status" = "healthy" ]; then
    ok=1
    break
  fi
  i=$((i+1))
  sleep 2
done
if [ "$ok" != "1" ]; then
  echo "警告：server 未在预期时间内变为 healthy（当前: ${status:-unknown}）。继续重启 web/manager。" >&2
fi

echo "==> [3/3] 重启 web / manager（刷新 nginx 对 server 的 DNS 解析）"
docker compose restart web manager

echo "==> 当前状态:"
docker compose ps
