#!/usr/bin/env bash
# Customer / workload VPS transport only: fetches install-managed-vps.sh from
# releasepanel-runner and executes it. Authoritative scripts live in that repo + toolkit/.
# For the hosted panel control plane, use install.sh (clone releasepanel-deploy + 01-bootstrap.sh).

set -euo pipefail

INSTALL_URL="${RELEASEPANEL_MANAGED_VPS_INSTALL_URL:-https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-runner/main/scripts/install-managed-vps.sh}"

curl -fsSL "${INSTALL_URL}" | bash
