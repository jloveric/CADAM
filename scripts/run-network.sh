#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

HOST="${DEV_HOST:-0.0.0.0}"
PORT="${DEV_PORT:-3001}"
NODE_VERSION="${DEV_NODE_VERSION:-24.18.0}"
SKIP_BUILD="${SKIP_BUILD:-0}"
SKIP_STOP="${SKIP_STOP:-0}"

# Keep outbound proxy for OpenAI/etc (needed from China), but never send
# local/LAN traffic through it. Node fetch honors these when
# NODE_USE_ENV_PROXY=1 (Node 22.21+ / 24+).
SAVED_ALL_PROXY="${ALL_PROXY:-${all_proxy:-}}"
SAVED_HTTP_PROXY="${HTTP_PROXY:-${http_proxy:-$SAVED_ALL_PROXY}}"
SAVED_HTTPS_PROXY="${HTTPS_PROXY:-${https_proxy:-$SAVED_HTTP_PROXY}}"

LOCAL_IPS="$(hostname -I 2>/dev/null | tr ' ' ',' | sed 's/,$//' || true)"
export no_proxy="127.0.0.1,localhost,${HOST}${LOCAL_IPS:+,${LOCAL_IPS}},.local"
export NO_PROXY="$no_proxy"

if [[ -n "$SAVED_HTTPS_PROXY" ]]; then
  export ALL_PROXY="$SAVED_ALL_PROXY"
  export HTTP_PROXY="$SAVED_HTTP_PROXY"
  export HTTPS_PROXY="$SAVED_HTTPS_PROXY"
  export http_proxy="$SAVED_HTTP_PROXY"
  export https_proxy="$SAVED_HTTPS_PROXY"
  export NODE_USE_ENV_PROXY=1
  echo "Outbound proxy enabled for API calls: $SAVED_HTTPS_PROXY"
  echo "Local/LAN hosts bypass proxy via NO_PROXY."
else
  unset ALL_PROXY HTTP_PROXY HTTPS_PROXY http_proxy https_proxy all_proxy || true
  echo "No HTTP(S)_PROXY set — OpenAI must be reachable directly or via OPENAI_BASE_URL."
fi

stop_existing() {
  if [[ "$SKIP_STOP" == "1" ]]; then
    return
  fi

  echo "Stopping any existing CADAM vite servers..."
  pkill -f "${ROOT}/node_modules/.bin/vite" 2>/dev/null || true
  sleep 1
  pkill -9 -f "${ROOT}/node_modules/.bin/vite" 2>/dev/null || true

  if command -v fuser >/dev/null 2>&1 && fuser "${PORT}/tcp" >/dev/null 2>&1; then
    echo "Port ${PORT} still in use — releasing..."
    fuser -k "${PORT}/tcp" >/dev/null 2>&1 || true
    sleep 1
  fi
}

stop_existing

if [[ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]]; then
  # shellcheck disable=SC1091
  source "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
  nvm use "$NODE_VERSION"
fi

node -e '
const [major, minor, patch] = process.versions.node.split(".").map(Number);
const ok =
  (major === 20 && (minor > 19 || (minor === 19 && patch >= 0))) ||
  (major === 22 && minor >= 12) ||
  major > 22;
if (!ok) {
  console.error(
    `Node ${process.versions.node} is too old. Need ^20.19.0 or >=22.12.0 (nvm: DEV_NODE_VERSION=${process.env.DEV_NODE_VERSION ?? "24.18.0"}).`,
  );
  process.exit(1);
}
'

VITE="./node_modules/.bin/vite"

if [[ "$SKIP_BUILD" != "1" ]]; then
  echo "Building CADAM..."
  npm run build
else
  echo "Skipping build (SKIP_BUILD=1)."
fi

echo ""
echo "CADAM will be available at:"
echo "  http://127.0.0.1:${PORT}/cadam/"
if [[ -n "$LOCAL_IPS" ]]; then
  echo "  http://${LOCAL_IPS%%,*}:${PORT}/cadam/  (first local IP — see vite output for all)"
fi
echo ""

exec "$VITE" preview --host "$HOST" --port "$PORT" --strictPort
