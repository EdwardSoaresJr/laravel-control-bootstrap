#!/usr/bin/env bash
# Legacy entry name — canonical installer is bootstrap.sh (single self-contained script, OG structure).
# This wrapper exists so old bookmarks to control-install.sh still work.
# Canonical: https://github.com/EdwardSoaresJr/releasepanel-bootstrap
#
set -euo pipefail

CENTRAL_PUBLIC_BASE="${CENTRAL_PUBLIC_BASE:-https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main}"

tmp="$( mktemp )"
trap 'rm -f "${tmp}"' EXIT

curl -fsSL "${CENTRAL_PUBLIC_BASE%/}/bootstrap.sh" -o "${tmp}"
exec bash "${tmp}" "$@"
