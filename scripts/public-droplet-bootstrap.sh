#!/usr/bin/env bash
# COMPATIBILITY WRAPPER ONLY — no installer logic here.
# Canonical install: https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh
# Kept so deep links to .../scripts/public-droplet-bootstrap.sh still work.
#
set -euo pipefail

CENTRAL_PUBLIC_BASE="${CENTRAL_PUBLIC_BASE:-https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main}"

tmp="$( mktemp )"
trap 'rm -f "${tmp}"' EXIT

curl -fsSL "${CENTRAL_PUBLIC_BASE%/}/bootstrap.sh" -o "${tmp}"
exec bash "${tmp}" "$@"
