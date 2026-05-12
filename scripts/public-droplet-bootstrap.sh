#!/usr/bin/env bash
# Deprecated path — use repo root bootstrap.sh (curl | bash) or control-install.sh (fetches bootstrap.sh).
# Kept so deep links to this path still work.
#
set -euo pipefail

CENTRAL_PUBLIC_BASE="${CENTRAL_PUBLIC_BASE:-https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main}"

tmp="$( mktemp )"
trap 'rm -f "${tmp}"' EXIT

curl -fsSL "${CENTRAL_PUBLIC_BASE%/}/bootstrap.sh" -o "${tmp}"
exec bash "${tmp}" "$@"
