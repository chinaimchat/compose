#!/usr/bin/env sh
# 新机器「尽量一键」：写入公网 IP（及可选用户端 Web 根地址），检查同级仓库，再 build / up / 贴纸种子。
# 不能代替：强密码、HTTPS 证书、宿主机 Nginx、阿里云镜像可达性等，见 docs/SETUP.zh.md。
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

usage() {
  echo "用法: $0 <公网IP> [用户端Web根地址，可选]" >&2
  echo "示例:" >&2
  echo "  $0 203.0.113.10" >&2
  echo "  $0 203.0.113.10 https://im.example.com" >&2
  echo "选项:" >&2
  echo "  --skip-build   跳过 docker compose build" >&2
  echo "  --skip-seed    跳过贴纸种子" >&2
  exit 1
}

SKIP_BUILD=0
SKIP_SEED=0
ARGS=""
for a in "$@"; do
  case "$a" in
    --skip-build) SKIP_BUILD=1 ;;
    --skip-seed) SKIP_SEED=1 ;;
    *) ARGS="$ARGS ${a}" ;;
  esac
done
# shellcheck disable=SC2086
set -- $ARGS

[ "${1:-}" != "" ] || usage
PUBLIC_IP="$1"
CLIENT_WEB_URL_OPT="${2:-}"

case "$PUBLIC_IP" in
  *[!0-9.]*|'') echo "第一个参数须为公网 IPv4，例如 203.0.113.10（不要用域名填这里）" >&2; exit 1 ;;
esac

for d in wukongim chinaim-server chinaim-web chinaim-manager; do
  if [ ! -d "$ROOT/../$d" ]; then
    echo "缺少同级目录: $ROOT/../$d（请先按 README 克隆五个仓库）" >&2
    exit 1
  fi
done

[ -f "$ROOT/.env" ] || { echo "缺少 $ROOT/.env" >&2; exit 1; }

# 若示例密码仍为 *，避免误部署弱口令（可手工改 .env 后再跑）
if grep -E '^MYSQL_ROOT_PASSWORD=\*+$' "$ROOT/.env" >/dev/null 2>&1 \
  || grep -E '^MINIO_ROOT_PASSWORD=\*+$' "$ROOT/.env" >/dev/null 2>&1 \
  || grep -E '^WK_JWT_SECRET=\*+$' "$ROOT/.env" >/dev/null 2>&1 \
  || grep -E '^TS_ADMINPWD=\*+$' "$ROOT/.env" >/dev/null 2>&1; then
  echo "请先编辑 .env：MYSQL / MinIO / WK_JWT / TS_ADMINPWD 等不能仍为仓库里的纯 * 占位。" >&2
  exit 1
fi

TS_WEB_PORT="$(grep -E '^TS_WEB_PORT=' "$ROOT/.env" | tail -n1 | sed 's/^TS_WEB_PORT=//')"
TS_WEB_PORT="${TS_WEB_PORT:-82}"
TS_API_PORT="$(grep -E '^TS_API_PORT=' "$ROOT/.env" | tail -n1 | sed 's/^TS_API_PORT=//')"
TS_API_PORT="${TS_API_PORT:-8090}"

# 就地更新 EXTERNAL_IP 与 MinIO 下载地址（与模板 *** 或旧值兼容）
if command -v sed >/dev/null 2>&1; then
  sed -i.bak "s|^EXTERNAL_IP=.*|EXTERNAL_IP=${PUBLIC_IP}|" "$ROOT/.env"
  sed -i.bak "s|^TS_MINIO_DOWNLOADURL=.*|TS_MINIO_DOWNLOADURL=http://${PUBLIC_IP}:9000|" "$ROOT/.env"
  rm -f "$ROOT/.env.bak"
else
  echo "需要 sed" >&2
  exit 1
fi

if [ -n "$CLIENT_WEB_URL_OPT" ]; then
  if grep -q '^CLIENT_WEB_URL=' "$ROOT/.env"; then
    sed -i.bak "s|^CLIENT_WEB_URL=.*|CLIENT_WEB_URL=${CLIENT_WEB_URL_OPT}|" "$ROOT/.env"
    rm -f "$ROOT/.env.bak"
  else
    printf '\n# bootstrap-new-host 写入\nCLIENT_WEB_URL=%s\n' "$CLIENT_WEB_URL_OPT" >>"$ROOT/.env"
  fi
fi

echo "已写入 EXTERNAL_IP=$PUBLIC_IP 与 TS_MINIO_DOWNLOADURL=http://${PUBLIC_IP}:9000"
[ -n "$CLIENT_WEB_URL_OPT" ] && echo "已写入 CLIENT_WEB_URL=$CLIENT_WEB_URL_OPT"
echo "若使用域名访问 Web，请仍检查 .env 中 WEB_SERVER_NAME / MANAGER_SERVER_NAME 与宿主机 Nginx（见 README）。"
echo

if [ "$SKIP_BUILD" = 0 ]; then
  docker compose build
else
  echo "[--skip-build] 跳过 build"
fi

docker compose up -d

if [ "$SKIP_SEED" = 0 ]; then
  echo "等待 MinIO 健康…"
  i=0
  while [ "$i" -lt 90 ]; do
    if docker compose exec -T minio curl -sf "http://127.0.0.1:9000/minio/health/live" >/dev/null 2>&1; then
      break
    fi
    i=$((i + 1))
    sleep 2
  done
  docker compose --profile seed run --rm sticker-seed
else
  echo "[--skip-seed] 跳过贴纸种子；可稍后: docker compose --profile seed run --rm sticker-seed"
fi

echo
echo "完成。建议验收: curl -sS http://127.0.0.1:${TS_API_PORT}/v1/ping （若在远端请把 127.0.0.1 换成服务器 IP）"
