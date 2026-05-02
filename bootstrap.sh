#!/usr/bin/env bash
set -euo pipefail

readonly DEPLOY_ROOT="/opt/arksms"
readonly DEPLOY_REPO_DIR="${DEPLOY_ROOT}/laravel-control-deploy"
readonly DEPLOY_REPO_SSH="git@github.com:EdwardSoaresJr/laravel-control-deploy.git"
readonly SSH_DIR="/root/.ssh"
readonly DEPLOY_KEY_PATH="${SSH_DIR}/arksms_deploy"
readonly SSH_CONFIG_PATH="${SSH_DIR}/config"
readonly KNOWN_HOSTS_PATH="${SSH_DIR}/known_hosts"

log() {
  echo "[ark-sms-bootstrap] $*"
}

fail() {
  echo "[ark-sms-bootstrap] ERROR: $*" >&2
  exit 1
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    fail "Run as root, for example: sudo -i"
  fi
}

install_minimal_dependencies() {
  log "Installing minimal dependencies..."
  apt-get update -y
  apt-get install -y git curl ca-certificates openssh-client
}

validate_deploy_key_input() {
  if [ -z "${GITHUB_DEPLOY_KEY_B64:-}" ]; then
    if [ -f "${DEPLOY_KEY_PATH}" ]; then
      log "Deploy key already exists; continuing without rewriting it."
      return
    fi

    fail "Missing GITHUB_DEPLOY_KEY_B64"
  fi

  if ! printf '%s' "${GITHUB_DEPLOY_KEY_B64}" | base64 -d >/dev/null 2>&1; then
    fail "Invalid base64 deploy key"
  fi
}

configure_ssh() {
  log "Configuring SSH access for GitHub..."

  mkdir -p "${SSH_DIR}"
  chmod 700 "${SSH_DIR}"

  if [ ! -f "${DEPLOY_KEY_PATH}" ]; then
    printf '%s' "${GITHUB_DEPLOY_KEY_B64}" | base64 -d > "${DEPLOY_KEY_PATH}"
    chmod 600 "${DEPLOY_KEY_PATH}"
  else
    log "Deploy key already present; not overwriting."
  fi

  touch "${KNOWN_HOSTS_PATH}"
  chmod 600 "${KNOWN_HOSTS_PATH}"

  if ! ssh-keygen -F github.com -f "${KNOWN_HOSTS_PATH}" >/dev/null 2>&1; then
    ssh-keyscan github.com >> "${KNOWN_HOSTS_PATH}" 2>/dev/null
  fi

  cat > "${SSH_CONFIG_PATH}" <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile ${DEPLOY_KEY_PATH}
  IdentitiesOnly yes
  StrictHostKeyChecking yes
EOF

  chmod 600 "${SSH_CONFIG_PATH}"
}

verify_github_access() {
  log "Verifying private repo access..."
  git ls-remote "${DEPLOY_REPO_SSH}" >/dev/null
}

clone_deploy_repo() {
  log "Ensuring deploy repo is present..."

  mkdir -p "${DEPLOY_ROOT}"

  if [ -d "${DEPLOY_REPO_DIR}/.git" ]; then
    log "Deploy repo already exists; not recloning."
    return
  fi

  if [ -e "${DEPLOY_REPO_DIR}" ]; then
    fail "${DEPLOY_REPO_DIR} exists but is not a git repository"
  fi

  git clone "${DEPLOY_REPO_SSH}" "${DEPLOY_REPO_DIR}"
}

handoff_to_private_bootstrap() {
  log "Handing off to private bootstrap..."

  cd "${DEPLOY_REPO_DIR}"
  bash scripts/01-bootstrap.sh
}

main() {
  log "Starting..."

  require_root
  install_minimal_dependencies
  validate_deploy_key_input
  configure_ssh
  verify_github_access
  clone_deploy_repo
  handoff_to_private_bootstrap

  log "Complete."
}

main "$@"
