#!/usr/bin/env bash
set -euo pipefail

# Start the current app's dev server. With --amp, also expose it to Amp's
# Sandbox Preview tab via Tailscale Serve. Amp's Sandbox handles Tailscale
# auth when TAILSCALE_AUTH_KEY is injected as a sandbox environment variable.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
APP_DIR="$(pwd)"
AMP_MODE=false

usage() {
  cat <<'EOF'
Usage: ensure-dev-server.sh [--amp]

Run this helper from the app directory that contains package.json.

Options:
  --amp       Publish Amp preview metadata via Tailscale Serve.
  -h, --help  Show this help message.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --amp)
      AMP_MODE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

HTTP_PROXY_PORT="${HTTP_PROXY_PORT:-3000}"
AMP_DIR="${APP_DIR}/.amp"
ROOT_AMP_DIR="${ROOT_DIR}/.amp"
DEV_SERVER_LOG="${AMP_DIR}/dev-server.log"
DEV_SERVER_PID="${AMP_DIR}/dev-server.pid"
DEV_SERVER_PORT="${AMP_DIR}/dev-server.port"
PREVIEW_JSON="${ROOT_DIR}/.amp/preview.json"

mkdir -p "${AMP_DIR}"

if [[ "${AMP_MODE}" == true ]]; then
  mkdir -p "${ROOT_AMP_DIR}"
fi

cd "${APP_DIR}"

detect_package_manager() {
  if [[ ! -f package.json ]]; then
    echo "No package.json found in ${APP_DIR}. Run this helper from the app directory." >&2
    exit 1
  fi

  local dir package_manager
  dir="${APP_DIR}"

  while true; do
    if [[ -f "${dir}/package.json" ]]; then
      package_manager="$(python3 - "${dir}/package.json" <<'PY' 2>/dev/null || true
import json
import sys
try:
    with open(sys.argv[1], encoding='utf-8') as f:
        value = json.load(f).get('packageManager', '')
except Exception:
    value = ''
print(value.split('@', 1)[0] if value else '')
PY
)"

      case "${package_manager}" in
        pnpm|npm|yarn|bun)
          printf '%s\t%s\n' "${package_manager}" "${dir}"
          return
          ;;
        "") ;;
        *)
          echo "Unsupported packageManager '${package_manager}' in ${dir}/package.json." >&2
          exit 1
          ;;
      esac
    fi

    if [[ -f "${dir}/pnpm-lock.yaml" ]]; then
      printf '%s\t%s\n' "pnpm" "${dir}"
      return
    elif [[ -f "${dir}/package-lock.json" || -f "${dir}/npm-shrinkwrap.json" ]]; then
      printf '%s\t%s\n' "npm" "${dir}"
      return
    elif [[ -f "${dir}/yarn.lock" ]]; then
      printf '%s\t%s\n' "yarn" "${dir}"
      return
    elif [[ -f "${dir}/bun.lock" || -f "${dir}/bun.lockb" ]]; then
      printf '%s\t%s\n' "bun" "${dir}"
      return
    fi

    if [[ "${dir}" == "${ROOT_DIR}" || "${dir}" == "/" ]]; then
      break
    fi

    dir="$(dirname "${dir}")"
  done

  echo "Unable to determine package manager for ${APP_DIR}. Add packageManager to package.json or a lockfile in the app or workspace root." >&2
  exit 1
}

IFS=$'\t' read -r PACKAGE_MANAGER PACKAGE_MANAGER_DIR < <(detect_package_manager)

if ! command -v "${PACKAGE_MANAGER}" >/dev/null 2>&1; then
  echo "${PACKAGE_MANAGER} is required for ${APP_DIR}. Run .agents/setup first or install it." >&2
  exit 1
fi

if [[ ! -d "${PACKAGE_MANAGER_DIR}/node_modules" ]]; then
  case "${PACKAGE_MANAGER}" in
    pnpm)
      (cd "${PACKAGE_MANAGER_DIR}" && pnpm install --frozen-lockfile)
      ;;
    npm)
      if [[ -f "${PACKAGE_MANAGER_DIR}/package-lock.json" || -f "${PACKAGE_MANAGER_DIR}/npm-shrinkwrap.json" ]]; then
        (cd "${PACKAGE_MANAGER_DIR}" && npm ci)
      else
        (cd "${PACKAGE_MANAGER_DIR}" && npm install --no-package-lock)
      fi
      ;;
    yarn)
      if ! (cd "${PACKAGE_MANAGER_DIR}" && yarn install --immutable); then
        (cd "${PACKAGE_MANAGER_DIR}" && yarn install --frozen-lockfile)
      fi
      ;;
    bun)
      (cd "${PACKAGE_MANAGER_DIR}" && bun install --frozen-lockfile)
      ;;
  esac
fi

pid_matches_app() {
  local pid="$1"
  local pid_cwd

  if [[ -e "/proc/${pid}/cwd" ]]; then
    pid_cwd="$(readlink "/proc/${pid}/cwd" 2>/dev/null || true)"
  elif command -v lsof >/dev/null 2>&1; then
    pid_cwd="$(lsof -a -p "${pid}" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1)"
  else
    return 0
  fi

  [[ "${pid_cwd}" == "${APP_DIR}" ]]
}

existing_pid=""
if [[ -f "${DEV_SERVER_PID}" ]]; then
  existing_pid="$(cat "${DEV_SERVER_PID}")"
fi

existing_port=""
if [[ -f "${DEV_SERVER_PORT}" ]]; then
  existing_port="$(cat "${DEV_SERVER_PORT}")"
fi

port_matches=false
if [[ "${existing_port}" == "${HTTP_PROXY_PORT}" ]] || [[ -z "${existing_port}" && "${HTTP_PROXY_PORT}" == "3000" ]]; then
  port_matches=true
fi

if [[ -n "${existing_pid}" ]] \
  && [[ "${port_matches}" == true ]] \
  && kill -0 "${existing_pid}" >/dev/null 2>&1 \
  && pid_matches_app "${existing_pid}" \
  && curl -fsS "http://localhost:${HTTP_PROXY_PORT}/" >/dev/null 2>&1; then
  echo "${HTTP_PROXY_PORT}" >"${DEV_SERVER_PORT}"
  echo "Dev server already running on port ${HTTP_PROXY_PORT} (pid ${existing_pid})."
else
  if curl -fsS "http://localhost:${HTTP_PROXY_PORT}/" >/dev/null 2>&1; then
    echo "Port ${HTTP_PROXY_PORT} is already serving a different process, and no matching live PID was found for ${APP_DIR}." >&2
    echo "Set HTTP_PROXY_PORT to a free port or stop the existing server before starting this app." >&2
    exit 1
  fi

  echo "Starting dev server in ${APP_DIR} on localhost:${HTTP_PROXY_PORT} with ${PACKAGE_MANAGER}..."
  case "${PACKAGE_MANAGER}" in
    pnpm)
      nohup pnpm dev --hostname 127.0.0.1 --port "${HTTP_PROXY_PORT}" >"${DEV_SERVER_LOG}" 2>&1 &
      ;;
    npm)
      nohup npm run dev -- --hostname 127.0.0.1 --port "${HTTP_PROXY_PORT}" >"${DEV_SERVER_LOG}" 2>&1 &
      ;;
    yarn)
      nohup yarn dev --hostname 127.0.0.1 --port "${HTTP_PROXY_PORT}" >"${DEV_SERVER_LOG}" 2>&1 &
      ;;
    bun)
      nohup bun run dev --hostname 127.0.0.1 --port "${HTTP_PROXY_PORT}" >"${DEV_SERVER_LOG}" 2>&1 &
      ;;
  esac
  echo "$!" >"${DEV_SERVER_PID}"
  echo "${HTTP_PROXY_PORT}" >"${DEV_SERVER_PORT}"
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

echo "Dev server ready: http://localhost:${HTTP_PROXY_PORT}/"

if [[ "${AMP_MODE}" != true ]]; then
  exit 0
fi

if ! command -v tailscale >/dev/null 2>&1; then
  echo "Dev server is running locally, but tailscale is unavailable so Amp preview metadata was not written." >&2
  echo "Amp's Sandbox should install/start tailscale when TAILSCALE_AUTH_KEY is set." >&2
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

echo "Tailscale preview: https://${tailscale_host}/"
echo "Wrote ${PREVIEW_JSON}"
