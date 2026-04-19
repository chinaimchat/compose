#!/usr/bin/env sh
# 新机器「尽量一键」：可选自动克隆同级仓库（GitHub chinaimchat 组织），写公网 IP / 可选 CLIENT_WEB_URL，再 build / up / 贴纸种子。
# 默认克隆地址见下方 CHINAIM_*_URL；可用环境变量覆盖（自建镜像站时）。
# 不能代替：强密码、HTTPS、宿主机 Nginx、阿里云镜像可达性等，见 docs/SETUP.zh.md。
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
PARENT="$(CDPATH= cd -- "$ROOT/.." && pwd)"

# 与 docker-compose.yaml 中 build.context 目录名一致（GitHub 仓库名未必同名）
CHINAIM_ORG="${CHINAIM_ORG:-chinaimchat}"
CHINAIM_WUKONGIM_URL="${CHINAIM_WUKONGIM_URL:-https://github.com/${CHINAIM_ORG}/wukongim.git}"
CHINAIM_SERVER_URL="${CHINAIM_SERVER_URL:-https://github.com/${CHINAIM_ORG}/server.git}"
CHINAIM_WEB_URL="${CHINAIM_WEB_URL:-https://github.com/${CHINAIM_ORG}/web.git}"
CHINAIM_MANAGER_URL="${CHINAIM_MANAGER_URL:-https://github.com/${CHINAIM_ORG}/manager.git}"

usage() {
  echo "用法: $0 [--clone] [--skip-build] [--skip-seed] <公网IPv4> [用户端Web根地址，可选]" >&2
  echo "示例:" >&2
  echo "  $0 --clone 203.0.113.10" >&2
  echo "  $0 203.0.113.10 https://im.example.com" >&2
  echo "说明:" >&2
  echo "  --clone  若缺少同级 wukongim / chinaim-server / chinaim-web / chinaim-manager，则从 GitHub 克隆（默认组织 ${CHINAIM_ORG}）。" >&2
  echo "  仓库对应: wukongim、server→chinaim-server、web→chinaim-web、manager→chinaim-manager（目录名与 compose 一致）。" >&2
  echo "  可用 CHINAIM_ORG / CHINAIM_*_URL 覆盖克隆地址。" >&2
  exit 1
}

SKIP_BUILD=0
SKIP_SEED=0
DO_CLONE=0
POSITIONAL=""
for a in "$@"; do
  case "$a" in
    --skip-build) SKIP_BUILD=1 ;;
    --skip-seed) SKIP_SEED=1 ;;
    --clone) DO_CLONE=1 ;;
    -h|--help) usage ;;
    *) POSITIONAL="$POSITIONAL $a" ;;
  esac
done
# shellcheck disable=SC2086
set -- $POSITIONAL

[ "${1:-}" != "" ] || usage
PUBLIC_IP="$1"
CLIENT_WEB_URL_OPT="${2:-}"

case "$PUBLIC_IP" in
  *[!0-9.]*|'') echo "第一个参数须为公网 IPv4，例如 203.0.113.10（不要用域名填这里）" >&2; exit 1 ;;
esac

clone_if_missing() {
  _dir="$1"
  _url="$2"
  if [ -d "$PARENT/$_dir/.git" ] || [ -d "$PARENT/$_dir" ]; then
    echo "已存在: $PARENT/$_dir"
    return 0
  fi
  echo "克隆 $_url -> $PARENT/$_dir"
  git -C "$PARENT" clone --depth 1 "$_url" "$_dir"
}

if [ "$DO_CLONE" = 1 ]; then
  command -v git >/dev/null 2>&1 || { echo "需要 git（--clone）" >&2; exit 1; }
  clone_if_missing wukongim "$CHINAIM_WUKONGIM_URL"
  clone_if_missing chinaim-server "$CHINAIM_SERVER_URL"
  clone_if_missing chinaim-web "$CHINAIM_WEB_URL"
  clone_if_missing chinaim-manager "$CHINAIM_MANAGER_URL"
  echo
fi

for d in wukongim chinaim-server chinaim-web chinaim-manager; do
  if [ ! -d "$PARENT/$d" ]; then
    echo "缺少同级目录: $PARENT/$d" >&2
    echo "请先克隆，或带上 --clone（默认从 https://github.com/${CHINAIM_ORG}/ 拉 server/web/manager/wukongim）。" >&2
    exit 1
  fi
done

cd "$ROOT"

[ -f "$ROOT/.env" ] || { echo "缺少 $ROOT/.env（compose 仓库内应有一份模板）" >&2; exit 1; }

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
