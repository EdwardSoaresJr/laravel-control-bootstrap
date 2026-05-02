#!/usr/bin/env bash
set -euo pipefail

export RELEASEPANEL_INSTALL_MODE=runner

BOOTSTRAP_URL="${RELEASEPANEL_BOOTSTRAP_URL:-https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh}"

curl -fsSL "${BOOTSTRAP_URL}" | bash
