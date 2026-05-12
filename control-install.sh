#!/usr/bin/env bash
# COMPATIBILITY WRAPPER ONLY — no installer logic here.
# Canonical (primary) command — use this in new docs and automation:
#   curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh | bash
# This file exists so old bookmarks to .../control-install.sh still work.
#
set -euo pipefail

CENTRAL_PUBLIC_BASE="${CENTRAL_PUBLIC_BASE:-https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main}"

tmp="$( mktemp )"
trap 'rm -f "${tmp}"' EXIT

curl -fsSL "${CENTRAL_PUBLIC_BASE%/}/bootstrap.sh" -o "${tmp}"
exec bash "${tmp}" "$@"
