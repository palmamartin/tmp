#!/usr/bin/env bash
set -euo pipefail

# Start the repo's dev server and expose it to Amp's E2B Preview tab via
# Tailscale Serve. Amp's E2B base image handles Tailscale auth when
# TAILSCALE_AUTH_KEY is injected as a sandbox environment variable.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "${ROOT_DIR}"

HTTP_PROXY_PORT="${HTTP_PROXY_PORT:-3000}"
DEV_SERVER_LOG="${ROOT_DIR}/.amp/dev-server.log"
DEV_SERVER_PID="${ROOT_DIR}/.amp/dev-server.pid"
PREVIEW_JSON="${ROOT_DIR}/.amp/preview.json"

mkdir -p "${ROOT_DIR}/.amp"

if ! command -v pnpm >/dev/null 2>&1; then
  echo "pnpm is required. Run .agents/setup first." >&2
  exit 1
fi

if ! command -v tailscale >/dev/null 2>&1; then
  echo "tailscale is required. Amp's E2B sandbox should install/start it when TAILSCALE_AUTH_KEY is set." >&2
  exit 1
fi

if [[ ! -d node_modules ]]; then
  pnpm install --frozen-lockfile
fi

if [[ -f "${DEV_SERVER_PID}" ]] && kill -0 "$(cat "${DEV_SERVER_PID}")" >/dev/null 2>&1; then
  echo "Dev server already running on port ${HTTP_PROXY_PORT} (pid $(cat "${DEV_SERVER_PID}"))."
else
  echo "Starting dev server on localhost:${HTTP_PROXY_PORT}..."
  nohup pnpm dev --hostname 127.0.0.1 --port "${HTTP_PROXY_PORT}" >"${DEV_SERVER_LOG}" 2>&1 &
  echo "$!" >"${DEV_SERVER_PID}"
fi

for _ in $(seq 1 60); do
  if curl -fsS "http://localhost:${HTTP_PROXY_PORT}/" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -fsS "http://localhost:${HTTP_PROXY_PORT}/" >/dev/null 2>&1; then
  echo "Dev server did not become ready. Last log lines:" >&2
  tail -n 80 "${DEV_SERVER_LOG}" >&2 || true
  exit 1
fi

tailscale serve --bg --yes --https=443 "localhost:${HTTP_PROXY_PORT}"

tailscale_host="$(tailscale status --json 2>/dev/null \
  | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("Self", {}).get("DNSName", "").rstrip("."))' 2>/dev/null \
  || true)"

if [[ -z "${tailscale_host}" ]]; then
  tailscale_host="$(hostname)"
fi

cat >"${PREVIEW_JSON}" <<JSON
{
  "active": "web",
  "previews": [
    {
      "id": "web",
      "type": "web",
      "label": "Web",
      "url": "https://${tailscale_host}/",
      "localURL": "http://localhost:${HTTP_PROXY_PORT}/",
      "userInstructions": "Connect to the ampcode.com Tailscale tailnet first."
    }
  ]
}
JSON

echo "Dev server ready: http://localhost:${HTTP_PROXY_PORT}/"
echo "Tailscale preview: https://${tailscale_host}/"
echo "Wrote ${PREVIEW_JSON}"
