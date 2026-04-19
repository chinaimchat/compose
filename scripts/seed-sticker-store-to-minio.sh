#!/usr/bin/env sh
# 将仓库内 seed/minio-file-bucket/preview/sticker/ 导入运行中的 MinIO（桶 file）。
# 用法：在 compose 仓库根目录执行；需已 docker compose up -d minio（或全栈）。
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SEED="$ROOT/seed/minio-file-bucket/preview/sticker"

if [ ! -d "$SEED" ]; then
  echo "缺少种子目录: $SEED" >&2
  exit 1
fi

# 仅从 .env 读取 MinIO 变量（避免 source 整文件时因未加引号的空格行报错）
read_env_kv() {
  _k="$1"
  _line="$(grep -E "^${_k}=" "$ROOT/.env" 2>/dev/null | tail -n1)"
  printf '%s\n' "${_line#*=}"
}

if [ -f "$ROOT/.env" ]; then
  MINIO_ROOT_USER="$(read_env_kv MINIO_ROOT_USER)"
  MINIO_ROOT_PASSWORD="$(read_env_kv MINIO_ROOT_PASSWORD)"
fi

if [ -z "${MINIO_ROOT_USER:-}" ] || [ -z "${MINIO_ROOT_PASSWORD:-}" ]; then
  echo "请在 .env 中配置 MINIO_ROOT_USER 与 MINIO_ROOT_PASSWORD，或事先 export 这两个变量。" >&2
  exit 1
fi

MINIO_CID="$(docker compose ps -q minio 2>/dev/null | head -n1)"
if [ -z "$MINIO_CID" ]; then
  echo "未找到运行中的 minio 容器。请先: docker compose up -d minio" >&2
  exit 1
fi

echo "使用容器 $MINIO_CID 网络，导入贴纸到桶 file ..."

docker run --rm \
  --network "container:${MINIO_CID}" \
  -v "${ROOT}/seed/minio-file-bucket:/seed:ro" \
  -e "MINIO_ROOT_USER=${MINIO_ROOT_USER}" \
  -e "MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}" \
  minio/mc:latest \
  sh -ec '
    mc alias set local http://127.0.0.1:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
    mc mb -p local/file 2>/dev/null || true
    mc cp --recursive /seed/preview/sticker/ local/file/preview/sticker/
    echo "完成：已写入 local/file/preview/sticker/"
  '
