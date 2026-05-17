#!/usr/bin/env bash
# COMPATIBILITY WRAPPER ONLY — no installer logic here.
# Canonical control-plane transport: install.sh (clone releasepanel-deploy + local 01-bootstrap.sh).
# Kept so deep links to .../scripts/public-droplet-bootstrap.sh still work.
#
set -euo pipefail

RELEASEPANEL_BOOTSTRAP_PUBLIC_BASE="${RELEASEPANEL_BOOTSTRAP_PUBLIC_BASE:-https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main}"

tmp="$( mktemp )"
trap 'rm -f "${tmp}"' EXIT

curl -fsSL "${RELEASEPANEL_BOOTSTRAP_PUBLIC_BASE%/}/install.sh" -o "${tmp}"
exec bash "${tmp}" "$@"
