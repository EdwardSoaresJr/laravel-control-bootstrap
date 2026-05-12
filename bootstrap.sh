#!/usr/bin/env bash
# releasepanel-bootstrap — Central control plane, OG installer mechanics (single file, curl | bash).
#
# Canonical: https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh
#
# Port of legacy/old-bootstrap.sh: same structure and operator ergonomics; targets releasepanel-central only.
# NOT preserved: monorepo, INSTALL_MODE/runner, 01-bootstrap.sh, old deploy paths.
#
# Flow: root → hardened apt → /root/.ssh deploy key + config → clone/pull private central → (.env?) → bootstrap-central.sh
#
# Intended: fresh disposable Ubuntu VPS. Overwrites /root/.ssh/config (Host github.com). See README.
#
# Required env for private forks: CENTRAL_REPO_SSH=git@github.com:you/releasepanel-central.git
# Default repo (upstream example): EdwardSoaresJr/releasepanel-central
#
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export UCF_FORCE_CONFFOLD=1

readonly CENTRAL_APP_ROOT="${CENTRAL_APP_ROOT:-/var/www/releasepanel-central}"
readonly DEPLOY_REPO_SSH="${CENTRAL_REPO_SSH:-${GITHUB_REPO_SSH:-git@github.com:EdwardSoaresJr/releasepanel-central.git}}"
readonly CENTRAL_BRANCH="${CENTRAL_BRANCH:-main}"
readonly SSH_DIR="/root/.ssh"
readonly DEPLOY_KEY_PATH="${DEPLOY_KEY_PATH:-${SSH_DIR}/releasepanel_central_git_deploy}"
readonly SSH_KNOWN_HOSTS="${SSH_DIR}/known_hosts"
readonly HANDOFF_USER="${RP_BOOTSTRAP_USER:-ubuntu}"

log() {
  echo "[releasepanel-bootstrap] $*" >&2
}

fail() {
  echo "[releasepanel-bootstrap] ERROR: $*" >&2
  exit 1
}

github_deploy_keys_url() {
  local ssh_url="$1"
  if [[ "${ssh_url}" =~ ^git@github\.com:([^/]+)/([^./]+)(\.git)?$ ]]; then
    echo "https://github.com/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/settings/keys"
  else
    echo "(GitHub repo → Settings → Deploy keys)"
  fi
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    fail "Run as root, for example: sudo -i"
  fi
}

install_minimal_dependencies() {
  log "Installing minimal dependencies..."
  apt-get -o Acquire::Retries=3 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 update -y
  apt-get install -y \
    -o Acquire::Retries=3 \
    -o Acquire::http::Timeout=30 \
    -o Acquire::https::Timeout=30 \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    git curl ca-certificates openssh-client
}

ensure_ssh_known_hosts() {
  mkdir -p "${SSH_DIR}"
  chmod 700 "${SSH_DIR}"
  touch "${SSH_KNOWN_HOSTS}"
  chmod 600 "${SSH_KNOWN_HOSTS}"

  if ! ssh-keygen -F github.com -f "${SSH_KNOWN_HOSTS}" >/dev/null 2>&1; then
    log "Adding github.com to SSH known_hosts..."
    ssh-keyscan github.com >>"${SSH_KNOWN_HOSTS}" 2>/dev/null
  fi
}

write_key_from_env() {
  local b64="${CENTRAL_DEPLOY_KEY_B64:-${INSTALL_DEPLOY_KEY_B64:-${RELEASEPANEL_DEPLOY_KEY_B64:-}}}"

  if [ -z "${b64}" ]; then
    return 1
  fi

  log "Using *_DEPLOY_KEY_B64 for private repo access."
  umask 077
  printf '%s' "${b64}" | tr -d '\n\r' | base64 -d >"${DEPLOY_KEY_PATH}" || fail "Invalid deploy key B64"
  chmod 600 "${DEPLOY_KEY_PATH}"
  ssh-keygen -y -f "${DEPLOY_KEY_PATH}" >/dev/null || fail "Decoded deploy key is not a valid SSH private key"

  return 0
}

generate_deploy_key() {
  if [ -f "${DEPLOY_KEY_PATH}" ]; then
    chmod 600 "${DEPLOY_KEY_PATH}"
    return
  fi

  log "Generating SSH deploy key for private releasepanel-central."
  ssh-keygen -t ed25519 -N "" -C "releasepanel-central@$(hostname)-$(date +%Y%m%d%H%M%S)" -f "${DEPLOY_KEY_PATH}" >/dev/null
  chmod 600 "${DEPLOY_KEY_PATH}"
}

print_public_key_instructions() {
  echo ""
  echo "============================================================"
  echo "Add this public key to the private releasepanel-central repo:"
  echo ""
  cat "${DEPLOY_KEY_PATH}.pub"
  echo ""
  echo "GitHub URL:"
  echo "  $(github_deploy_keys_url "${DEPLOY_REPO_SSH}")"
  echo ""
  echo "Use a read-only deploy key. Do not enable write access."
  echo "============================================================"
  echo ""
}

wait_for_key_install() {
  if [ -n "${CENTRAL_DEPLOY_KEY_B64:-${INSTALL_DEPLOY_KEY_B64:-${RELEASEPANEL_DEPLOY_KEY_B64:-}}}" ]; then
    return
  fi

  print_public_key_instructions

  if [ "${RELEASEPANEL_ASSUME_DEPLOY_KEY_ADDED:-false}" = "true" ]; then
    return
  fi
  if [ "${SKIP_SSH_PROMPT:-0}" = "1" ] || [ "${SKIP_SSH_PROMPT:-}" = "true" ]; then
    return
  fi

  if [ ! -r /dev/tty ]; then
    fail "No interactive terminal. Add the key, then rerun with RELEASEPANEL_ASSUME_DEPLOY_KEY_ADDED=true or SKIP_SSH_PROMPT=1."
  fi

  read -r -p "Press Enter after adding the deploy key to GitHub..." _ </dev/tty
}

git_ssh() {
  GIT_SSH_COMMAND="ssh -i ${DEPLOY_KEY_PATH} -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes" "$@"
}

write_ssh_config() {
  cat >"${SSH_DIR}/config" <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile ${DEPLOY_KEY_PATH}
  IdentitiesOnly yes
  StrictHostKeyChecking yes
EOF
  chmod 600 "${SSH_DIR}/config"
}

ensure_deploy_key() {
  ensure_ssh_known_hosts

  if ! write_key_from_env; then
    generate_deploy_key
    wait_for_key_install
  fi

  write_ssh_config
}

verify_git_read() {
  log "Verifying read access (git ls-remote)..."
  if ! git_ssh git ls-remote "${DEPLOY_REPO_SSH}" "refs/heads/${CENTRAL_BRANCH}" >/dev/null; then
    print_public_key_instructions
    fail "git ls-remote failed — check deploy key, branch (${CENTRAL_BRANCH}), and repo URL: ${DEPLOY_REPO_SSH}"
  fi
}

central_tree_looks_converged() {
  [ -f "${CENTRAL_APP_ROOT}/.env" ] && [ -f "${CENTRAL_APP_ROOT}/artisan" ] && [ -d "${CENTRAL_APP_ROOT}/vendor" ]
}

refuse_repeat_control_curl_bootstrap() {
  if [ "${RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN:-}" = "true" ]; then
    log "RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN=true — continuing (repair only; not for routine updates)."
    return 0
  fi
  if ! central_tree_looks_converged; then
    return 0
  fi
  echo "" >&2
  log "This host already has a converged Central tree at ${CENTRAL_APP_ROOT}."
  log "Re-running this curl installer is not the update path."
  log ""
  log "Update the app instead:"
  log "  cd ${CENTRAL_APP_ROOT} && git pull --ff-only origin ${CENTRAL_BRANCH} && sudo -u releasepanel ./scripts/deploy-central.sh"
  log ""
  log "Repair-only: RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN=true bash bootstrap.sh"
  echo "" >&2
  exit 1
}

clone_central_repo() {
  log "Ensuring releasepanel-central clone at ${CENTRAL_APP_ROOT}..."

  mkdir -p "$(dirname "${CENTRAL_APP_ROOT}")"

  if [ -d "${CENTRAL_APP_ROOT}/.git" ]; then
    ensure_deploy_key
    verify_git_read
    log "Repo already present; updating with deploy key."
    git_ssh git -C "${CENTRAL_APP_ROOT}" remote set-url origin "${DEPLOY_REPO_SSH}"
    git_ssh git -C "${CENTRAL_APP_ROOT}" fetch origin "${CENTRAL_BRANCH}"
    git_ssh git -C "${CENTRAL_APP_ROOT}" checkout "${CENTRAL_BRANCH}"
    git_ssh git -C "${CENTRAL_APP_ROOT}" pull --ff-only origin "${CENTRAL_BRANCH}"
    return
  fi

  if [ -e "${CENTRAL_APP_ROOT}" ] && [ -n "$(ls -A "${CENTRAL_APP_ROOT}" 2>/dev/null)" ]; then
    fail "${CENTRAL_APP_ROOT} exists and is not an empty git clone — fix or set CENTRAL_APP_ROOT"
  fi

  ensure_deploy_key
  verify_git_read

  mkdir -p "${CENTRAL_APP_ROOT}"
  rmdir "${CENTRAL_APP_ROOT}" 2>/dev/null || true

  log "Cloning private releasepanel-central via SSH."
  if ! git_ssh git clone --branch "${CENTRAL_BRANCH}" --single-branch --depth 1 "${DEPLOY_REPO_SSH}" "${CENTRAL_APP_ROOT}"; then
    rm -rf "${CENTRAL_APP_ROOT}"
    if [ -f "${DEPLOY_KEY_PATH}.pub" ]; then
      print_public_key_instructions
    fi
    if ! git_ssh git clone "${DEPLOY_REPO_SSH}" "${CENTRAL_APP_ROOT}"; then
      rm -rf "${CENTRAL_APP_ROOT}"
      fail "SSH clone failed: ${DEPLOY_REPO_SSH}"
    fi
    git_ssh git -C "${CENTRAL_APP_ROOT}" checkout "${CENTRAL_BRANCH}"
  fi
}

ensure_handoff_user() {
  if ! id "${HANDOFF_USER}" &>/dev/null; then
    fail "Handoff user ${HANDOFF_USER} does not exist. Create it or set RP_BOOTSTRAP_USER."
  fi
}

chown_clone_for_handoff() {
  chown -R "${HANDOFF_USER}:${HANDOFF_USER}" "${CENTRAL_APP_ROOT}"
}

handoff_to_bootstrap_central() {
  log "Handing off to bootstrap-central.sh..."

  if [ ! -f "${CENTRAL_APP_ROOT}/.env" ]; then
    echo ""
    log "----------------------------------------------------------------------"
    log "Clone ready at ${CENTRAL_APP_ROOT}. Create .env before converge:"
    log "  cd ${CENTRAL_APP_ROOT}"
    log "  cp .env.example .env && nano .env"
    log "  chmod 600 .env"
    log "Then: bash ${CENTRAL_APP_ROOT}/scripts/bootstrap-central.sh"
    log "  or re-run this script after .env exists."
    log "----------------------------------------------------------------------"
    exit 2
  fi

  ensure_handoff_user
  chown_clone_for_handoff

  exec sudo -u "${HANDOFF_USER}" -H env \
    CENTRAL_APP_ROOT="${CENTRAL_APP_ROOT}" \
    CENTRAL_WEB_HOSTNAME="${CENTRAL_WEB_HOSTNAME:-}" \
    CENTRAL_REPO_URL="${CENTRAL_REPO_URL:-}" \
    CENTRAL_BRANCH="${CENTRAL_BRANCH}" \
    SKIP_CERTBOT="${SKIP_CERTBOT:-}" \
    CERTBOT_EMAIL="${CERTBOT_EMAIL:-}" \
    RUN_VERIFY="${RUN_VERIFY:-}" \
    VERIFY_BASE_URL="${VERIFY_BASE_URL:-}" \
    bash "${CENTRAL_APP_ROOT}/scripts/bootstrap-central.sh"
}

main() {
  log "Starting (releasepanel-central OG-style bootstrap)..."

  require_root
  install_minimal_dependencies

  if [ "${FORCE_NEW_DEPLOY_KEY:-0}" = "1" ] || [ "${FORCE_NEW_DEPLOY_KEY:-}" = "true" ]; then
    rm -f "${DEPLOY_KEY_PATH}" "${DEPLOY_KEY_PATH}.pub"
    log "Regenerated deploy key path (FORCE_NEW_DEPLOY_KEY)."
  fi

  # Keys + clone refresh (matches old script: clone before refuse, so tree is current)
  clone_central_repo
  refuse_repeat_control_curl_bootstrap
  handoff_to_bootstrap_central
}

main "$@"
