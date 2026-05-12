#!/usr/bin/env bash
# ReleasePanel — public one-line entry (trust / acquisition layer only).
# Canonical copy: https://github.com/EdwardSoaresJr/releasepanel-bootstrap
#
# Downloads scripts/public-droplet-bootstrap.sh and execs it. No secrets embedded.
# Hands off to private releasepanel-central: scripts/bootstrap-central.sh → verify-central.sh.
#
set -euo pipefail

CENTRAL_PUBLIC_BASE="${CENTRAL_PUBLIC_BASE:-https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main}"

CENTRAL_BOOTSTRAP_SCRIPT_URL="${CENTRAL_BOOTSTRAP_SCRIPT_URL:-${CENTRAL_PUBLIC_BASE%/}/scripts/public-droplet-bootstrap.sh}"

tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

curl -fsSL "${CENTRAL_BOOTSTRAP_SCRIPT_URL}" -o "${tmp}"
exec bash "${tmp}"
