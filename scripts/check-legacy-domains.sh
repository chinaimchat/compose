#!/usr/bin/env sh

set -eu

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"

# 可通过命令行参数追加自定义历史域名：
#   sh compose/scripts/check-legacy-domains.sh old1.com old2.com
PATTERNS="sdsf1\\.com|xh-gc\\.com"
if [ "$#" -gt 0 ]; then
  EXTRA="$(printf '%s\n' "$@" | sed 's/[.[\*^$()+?{|]/\\&/g' | paste -sd'|' -)"
  PATTERNS="${PATTERNS}|${EXTRA}"
fi

echo "Scanning for legacy domains..."
echo "Pattern: ${PATTERNS}"
echo

if ! command -v rg >/dev/null 2>&1; then
  echo "Error: rg is required but not installed in this shell."
  exit 2
fi

if rg -n "${PATTERNS}" \
  "${BASE_DIR}/chinaim-web" \
  "${BASE_DIR}/chinaim-manager" \
  "${BASE_DIR}/chinaim-server" \
  --glob '!**/.git/**' \
  --glob '!**/node_modules/**' \
  --glob '!**/dist/**' \
  --glob '!**/build/**' \
  --glob '!**/.cursor/**' \
  --glob '!**/.cursor-server/**' \
  --glob '!**/agent-transcripts/**' \
  --glob '!**/agent-tools/**'
then
  echo
  echo "Found legacy domains. Please replace before release."
  exit 1
fi

echo "No legacy domains found."
