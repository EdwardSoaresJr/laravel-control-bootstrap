#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUNNER_DIR="${TOOLKIT_DIR}/runner"
SERVICE_SOURCE="${TOOLKIT_DIR}/systemd/releasepanel-runner.service.example"
SERVICE_TARGET="/etc/systemd/system/releasepanel-runner.service"

log() {
    printf '\033[1;34m[releasepanel]\033[0m %s\n' "$*"
}

fail() {
    printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    fail "Run this script as root."
fi

command -v node >/dev/null 2>&1 || fail "node is not installed."
command -v npm >/dev/null 2>&1 || fail "npm is not installed."

cd "${RUNNER_DIR}"

log "Installing runner dependencies."
npm install --omit=dev

if [ ! -f "${RUNNER_DIR}/.env" ]; then
    log "Creating runner/.env from runner/.env.example."
    cp "${RUNNER_DIR}/.env.example" "${RUNNER_DIR}/.env"
fi

RUNNER_ENV_PATH="${RUNNER_DIR}/.env" python3 <<'PY'
import os
from pathlib import Path

env_path = Path(os.environ["RUNNER_ENV_PATH"])
updates = {
    "RELEASEPANEL_RUNNER_HOST": os.environ.get("RELEASEPANEL_RUNNER_HOST"),
    "RELEASEPANEL_RUNNER_PORT": os.environ.get("RELEASEPANEL_RUNNER_PORT"),
    "RELEASEPANEL_RUNNER_KEY": os.environ.get("RELEASEPANEL_RUNNER_KEY"),
    "RELEASEPANEL_RUNNER_LOG": os.environ.get("RELEASEPANEL_RUNNER_LOG"),
    "RELEASEPANEL_PANEL_URL": os.environ.get("RELEASEPANEL_PANEL_URL"),
    "RELEASEPANEL_RUNNER_PUBLIC_URL": os.environ.get("RELEASEPANEL_RUNNER_PUBLIC_URL"),
}
updates = {key: value for key, value in updates.items() if value}

if updates:
    lines = env_path.read_text().splitlines()
    seen = set()
    rewritten = []

    for line in lines:
        key = line.split("=", 1)[0] if "=" in line else ""

        if key in updates:
            rewritten.append(f"{key}={updates[key]}")
            seen.add(key)
        else:
            rewritten.append(line)

    for key, value in updates.items():
        if key not in seen:
            rewritten.append(f"{key}={value}")

    env_path.write_text("\n".join(rewritten).rstrip() + "\n")
PY

chmod 600 "${RUNNER_DIR}/.env"

log "Installing systemd service."
sed \
    -e "s#__RELEASEPANEL_TOOLKIT_DIR__#${TOOLKIT_DIR}#g" \
    "${SERVICE_SOURCE}" > "${SERVICE_TARGET}"

systemctl daemon-reload
systemctl enable releasepanel-runner

if grep -q '^RELEASEPANEL_RUNNER_KEY=CHANGE_ME$' "${RUNNER_DIR}/.env" || ! grep -q '^RELEASEPANEL_RUNNER_KEY=.' "${RUNNER_DIR}/.env"; then
    echo ""
    echo "[releasepanel] Runner service installed but not started."
    echo "Next steps:"
    echo "  nano ${RUNNER_DIR}/.env"
    echo "  set RELEASEPANEL_RUNNER_KEY to a strong secret"
    echo "  systemctl restart releasepanel-runner"
    echo ""
    exit 0
fi

systemctl restart releasepanel-runner

echo ""
echo "[releasepanel] Runner installed."
echo "Next steps:"
echo "  nano ${RUNNER_DIR}/.env"
echo "  confirm RELEASEPANEL_RUNNER_KEY is set"
echo "  systemctl status releasepanel-runner --no-pager"
echo ""
