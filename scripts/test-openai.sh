#!/usr/bin/env bash
# Cheap OpenAI connectivity check (uses gpt-5.4-nano by default).
# Usage: bash scripts/test-openai.sh [model]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODEL="${1:-gpt-5.4-nano}"

if [[ -f .env.local ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

if [[ -z "${OPENAI_API_KEY:-}" || "$OPENAI_API_KEY" == *"<*" ]]; then
  echo "OPENAI_API_KEY is not set in .env.local"
  exit 1
fi

BASE_URL="${OPENAI_BASE_URL:-https://api.openai.com/v1}"
BASE_URL="${BASE_URL%/}"
if [[ "$BASE_URL" != */v1 ]]; then
  BASE_URL="${BASE_URL}/v1"
fi

# Keep outbound proxy if present; never proxy localhost.
export NO_PROXY="127.0.0.1,localhost,${NO_PROXY:-${no_proxy:-}}"
export no_proxy="$NO_PROXY"
if [[ -n "${HTTPS_PROXY:-${HTTP_PROXY:-${ALL_PROXY:-}}}" ]]; then
  export NODE_USE_ENV_PROXY=1
fi

echo "Base URL: $BASE_URL"
echo "Model:    $MODEL"
echo "Proxy:    ${HTTPS_PROXY:-${HTTP_PROXY:-${ALL_PROXY:-none}}}"
echo ""

# 1) DNS / reachability probe (no tokens spent)
echo "== DNS for api.openai.com =="
getent ahostsv4 api.openai.com 2>/dev/null | head -3 || true
echo ""

echo "== GET ${BASE_URL%/v1}/v1/models (auth check, no generation) =="
HTTP_CODE="$(
  curl -sS -o /tmp/cadam-openai-models.json -w "%{http_code}" --max-time 25 \
    -H "Authorization: Bearer ${OPENAI_API_KEY}" \
    "${BASE_URL}/models" || true
)"
echo "HTTP $HTTP_CODE"
if [[ "$HTTP_CODE" != "200" ]]; then
  echo "Body (truncated):"
  head -c 400 /tmp/cadam-openai-models.json 2>/dev/null || true
  echo ""
  echo ""
  echo "OpenAI is not reachable with the current network settings."
  echo "From China you typically need either:"
  echo "  1) A working HTTPS proxy that can complete TLS to OpenAI, or"
  echo "  2) OPENAI_BASE_URL pointing at an OpenAI-compatible gateway you can reach."
  echo "Example in .env.local:"
  echo '  OPENAI_BASE_URL="https://your-gateway.example.com/v1"'
  exit 1
fi
echo "Auth OK."
echo ""

# 2) Tiny chat completion with the cheapest model
echo "== POST chat/completions model=${MODEL} (tiny prompt) =="
HTTP_CODE="$(
  curl -sS -o /tmp/cadam-openai-chat.json -w "%{http_code}" --max-time 60 \
    -H "Authorization: Bearer ${OPENAI_API_KEY}" \
    -H "Content-Type: application/json" \
    "${BASE_URL}/chat/completions" \
    -d "{\"model\":\"${MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: ok\"}],\"max_completion_tokens\":8}" \
    || true
)"
echo "HTTP $HTTP_CODE"
python3 - <<'PY' 2>/dev/null || cat /tmp/cadam-openai-chat.json
import json
p="/tmp/cadam-openai-chat.json"
try:
  d=json.load(open(p))
except Exception as e:
  print(open(p).read()[:500]); raise SystemExit(1)
if "error" in d:
  print("ERROR:", d["error"])
  raise SystemExit(1)
msg=d["choices"][0]["message"]["content"]
usage=d.get("usage",{})
print("Reply:", repr(msg))
print("Usage:", usage)
PY
