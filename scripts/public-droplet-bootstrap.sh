#!/usr/bin/env bash
# Public droplet bootstrap — provisioning convenience only; NOT ReleasePanel Central (the platform).
#
# Canonical copy: https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/scripts/public-droplet-bootstrap.sh
# Invoked via ../control-install.sh or saved and run locally.
#
# Establishes Git read access (deploy key), clones private releasepanel-central, hands off to:
#   scripts/bootstrap-central.sh (and verify-central.sh) inside that repo when .env exists.
#
# Run on Ubuntu 24.04 as a sudo-capable user (e.g. ubuntu), not as root.
#
# One-liner (after setting CENTRAL_REPO_SSH):
#   curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/control-install.sh -o /tmp/rp-install.sh && bash /tmp/rp-install.sh
#
# Environment:
#   CENTRAL_REPO_SSH   Required. SSH clone URL, e.g. git@github.com:org/releasepanel-central.git
#   CENTRAL_APP_ROOT   App directory (default: /var/www/releasepanel-central)
#   CENTRAL_BRANCH     Branch to clone/track (default: main)
#   DEPLOY_KEY_PATH    Private key path (default: ~/.ssh/releasepanel_central_git_deploy)
#   CENTRAL_DEPLOY_KEY_B64 | INSTALL_DEPLOY_KEY_B64 | RELEASEPANEL_DEPLOY_KEY_B64  Optional. Base64 PEM private key
#   FORCE_NEW_DEPLOY_KEY  If 1: replace existing private key at DEPLOY_KEY_PATH
#   SKIP_SSH_PROMPT      If 1: do not wait for Enter after showing pubkey (for advanced automation)
#
# Does NOT print .env; does NOT install mysql-server/mariadb-server; does NOT embed GitHub tokens.
#
set -euo pipefail

log() {
  echo "[public-droplet-bootstrap] $*" >&2
}

if [[ "$(id -u)" -eq 0 ]]; then
  echo "ERROR: run as a sudo-capable user (e.g. ubuntu), not root." >&2
  exit 1
fi

CENTRAL_REPO_SSH="${CENTRAL_REPO_SSH:-${GITHUB_REPO_SSH:-}}"
if [[ -z "${CENTRAL_REPO_SSH}" ]]; then
  echo "ERROR: set CENTRAL_REPO_SSH (e.g. git@github.com:org/releasepanel-central.git)" >&2
  exit 1
fi

CENTRAL_APP_ROOT="${CENTRAL_APP_ROOT:-/var/www/releasepanel-central}"
CENTRAL_BRANCH="${CENTRAL_BRANCH:-main}"
DEPLOY_KEY_PATH="${DEPLOY_KEY_PATH:-${HOME}/.ssh/releasepanel_central_git_deploy}"
FORCE_NEW_DEPLOY_KEY="${FORCE_NEW_DEPLOY_KEY:-0}"
SKIP_SSH_PROMPT="${SKIP_SSH_PROMPT:-0}"

if [[ "${FORCE_NEW_DEPLOY_KEY}" == "1" ]] || [[ "${FORCE_NEW_DEPLOY_KEY}" == "true" ]]; then
  rm -f "${DEPLOY_KEY_PATH}" "${DEPLOY_KEY_PATH}.pub"
  log "Removed existing deploy key (FORCE_NEW_DEPLOY_KEY)."
fi

if ! command -v git >/dev/null 2>&1 || ! command -v ssh-keygen >/dev/null 2>&1; then
  log "Installing git and openssh-client"
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get install -y git openssh-client
fi

mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

DEPLOY_KEY_FROM_B64=0
KEY_B64="${CENTRAL_DEPLOY_KEY_B64:-${INSTALL_DEPLOY_KEY_B64:-${RELEASEPANEL_DEPLOY_KEY_B64:-}}}"

if [[ -n "${KEY_B64}" ]]; then
  log "Installing deploy private key from *DEPLOY_KEY_B64 env (CENTRAL_/INSTALL_/RELEASEPANEL_)"
  printf '%s' "${KEY_B64}" | tr -d '\n\r' | base64 -d > "${DEPLOY_KEY_PATH}"
  chmod 600 "${DEPLOY_KEY_PATH}"
  if ! ssh_key_pub="$(ssh-keygen -y -f "${DEPLOY_KEY_PATH}" 2>&1)"; then
    log "ERROR: deploy key B64 decoded to an invalid private key (${ssh_key_pub})." >&2
    rm -f "${DEPLOY_KEY_PATH}" "${DEPLOY_KEY_PATH}.pub"
    exit 1
  fi
  printf '%s\n' "${ssh_key_pub}" > "${DEPLOY_KEY_PATH}.pub"
  chmod 644 "${DEPLOY_KEY_PATH}.pub"
  DEPLOY_KEY_FROM_B64=1
elif [[ ! -f "${DEPLOY_KEY_PATH}" ]]; then
  log "Generating Ed25519 deploy key: ${DEPLOY_KEY_PATH}"
  ssh-keygen -t ed25519 -f "${DEPLOY_KEY_PATH}" -N "" -C "releasepanel-central-git-$(hostname -s 2>/dev/null || echo droplet)"
  chmod 600 "${DEPLOY_KEY_PATH}"
  chmod 644 "${DEPLOY_KEY_PATH}.pub"
else
  chmod 600 "${DEPLOY_KEY_PATH}"
  chmod 644 "${DEPLOY_KEY_PATH}.pub"
fi

if ! grep -qE '^github\.com[[:space:]]' "${HOME}/.ssh/known_hosts" 2>/dev/null; then
  log "Adding github.com host key to ${HOME}/.ssh/known_hosts"
  ssh-keyscan -t ed25519 github.com >> "${HOME}/.ssh/known_hosts" 2>/dev/null
  chmod 600 "${HOME}/.ssh/known_hosts"
fi

export GIT_SSH_COMMAND="ssh -i ${DEPLOY_KEY_PATH} -o IdentitiesOnly=yes"

if [[ "${DEPLOY_KEY_FROM_B64}" -eq 0 ]]; then
  log "----------------------------------------------------------------------"
  log 'Add this public key as a GitHub Deploy key (read-only) on releasepanel-central:'
  log '  Repo -> Settings -> Deploy keys -> Add deploy key -> paste -> Save'
  log ""
  cat "${DEPLOY_KEY_PATH}.pub" >&2
  log "----------------------------------------------------------------------"
  log "Repository: ${CENTRAL_REPO_SSH}  branch: ${CENTRAL_BRANCH}"
  log "----------------------------------------------------------------------"

  if [[ "${SKIP_SSH_PROMPT}" != "1" ]] && [[ "${SKIP_SSH_PROMPT}" != "true" ]]; then
    if [[ -r /dev/tty ]]; then
      read -r -p "Press Enter after the deploy key is saved on GitHub... " _ </dev/tty
    else
      log "ERROR: no interactive terminal (e.g. piping from curl)." >&2
      log "  Save this script and run: bash scripts/public-droplet-bootstrap.sh" >&2
      log "  Or use *_DEPLOY_KEY_B64, or set SKIP_SSH_PROMPT=1 after the key is on GitHub." >&2
      exit 1
    fi
  fi
else
  log "Using pre-supplied deploy key (B64); skipping GitHub paste prompt."
fi

log "Verifying read access (git ls-remote)..."
if ! git ls-remote "${CENTRAL_REPO_SSH}" "refs/heads/${CENTRAL_BRANCH}" >/dev/null; then
  log "ERROR: git ls-remote failed — check read-only deploy key, branch name, and repo URL." >&2
  exit 1
fi

sudo mkdir -p "${CENTRAL_APP_ROOT}"
sudo chown "$(id -u):$(id -gn)" "${CENTRAL_APP_ROOT}"

if [[ -d "${CENTRAL_APP_ROOT}/.git" ]]; then
  log "Updating existing clone at ${CENTRAL_APP_ROOT}"
  git -C "${CENTRAL_APP_ROOT}" remote set-url origin "${CENTRAL_REPO_SSH}"
  git -C "${CENTRAL_APP_ROOT}" fetch origin "${CENTRAL_BRANCH}"
  git -C "${CENTRAL_APP_ROOT}" checkout "${CENTRAL_BRANCH}"
  git -C "${CENTRAL_APP_ROOT}" pull --ff-only origin "${CENTRAL_BRANCH}"
elif [[ -f "${CENTRAL_APP_ROOT}/artisan" ]]; then
  log "ERROR: ${CENTRAL_APP_ROOT} has artisan but is not a git repo — fix manually." >&2
  exit 1
else
  if [[ -n "$(ls -A "${CENTRAL_APP_ROOT}" 2>/dev/null)" ]]; then
    log "ERROR: ${CENTRAL_APP_ROOT} is not empty and has no clone — fix path or empty directory." >&2
    exit 1
  fi
  log "Cloning ${CENTRAL_REPO_SSH} (branch ${CENTRAL_BRANCH}) → ${CENTRAL_APP_ROOT}"
  if ! git clone --branch "${CENTRAL_BRANCH}" --single-branch --depth 1 "${CENTRAL_REPO_SSH}" "${CENTRAL_APP_ROOT}"; then
    log "Shallow clone failed; trying full clone + checkout"
    git clone "${CENTRAL_REPO_SSH}" "${CENTRAL_APP_ROOT}"
    git -C "${CENTRAL_APP_ROOT}" checkout "${CENTRAL_BRANCH}"
  fi
fi

if [[ ! -f "${CENTRAL_APP_ROOT}/.env" ]]; then
  log "----------------------------------------------------------------------"
  log "Clone ready at ${CENTRAL_APP_ROOT}. No .env yet — create it before Central bootstrap:"
  log "  cd ${CENTRAL_APP_ROOT}"
  log "  cp .env.example .env && nano .env   # Managed MySQL, APP_KEY, etc."
  log "  chmod 600 .env"
  log "Then either re-run this script (idempotent) or:"
  log "  ./scripts/bootstrap-central.sh"
  log "----------------------------------------------------------------------"
  exit 2
fi

log ".env present — running bootstrap-central.sh"
exec bash "${CENTRAL_APP_ROOT}/scripts/bootstrap-central.sh"
