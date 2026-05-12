#!/usr/bin/env bash
set -euo pipefail

INSTALL_URL="${RELEASEPANEL_MANAGED_VPS_INSTALL_URL:-https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-runner/main/scripts/install-managed-vps.sh}"

curl -fsSL "${INSTALL_URL}" | bash
