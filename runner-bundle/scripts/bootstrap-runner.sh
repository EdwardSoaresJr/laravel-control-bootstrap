#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$(id -u)" -ne 0 ]; then
    echo "[bootstrap-runner] ERROR: Run this script as root." >&2
    exit 1
fi

echo "[bootstrap-runner] Installing managed-server runtime only."

RELEASEPANEL_SKIP_APP_BOOTSTRAP=true bash "${SCRIPT_DIR}/01-bootstrap.sh"
bash "${SCRIPT_DIR}/install-runner.sh"

echo "[bootstrap-runner] COMPLETE"
