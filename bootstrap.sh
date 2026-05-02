#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export UCF_FORCE_CONFFOLD=1

readonly DEPLOY_ROOT="/opt"
readonly DEPLOY_REPO_DIR="${DEPLOY_ROOT}/releasepanel-deploy"
readonly DEPLOY_REPO_SSH="git@github.com:EdwardSoaresJr/releasepanel-deploy.git"
readonly DEPLOY_REPO_HTTPS="https://github.com/EdwardSoaresJr/releasepanel-deploy.git"
readonly SSH_DIR="/root/.ssh"
readonly DEPLOY_KEY_PATH="${SSH_DIR}/releasepanel_bootstrap"
readonly SSH_CONFIG_PATH="${SSH_DIR}/config"
readonly KNOWN_HOSTS_PATH="${SSH_DIR}/known_hosts"

log() {
  echo "[releasepanel-bootstrap] $*"
}

fail() {
  echo "[releasepanel-bootstrap] ERROR: $*" >&2
  exit 1
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

validate_deploy_key_input() {
  if [ -z "${GITHUB_DEPLOY_KEY_B64:-}" ]; then
    log "No deploy key provided; public HTTPS clone will be used."
    return
  fi

  if ! printf '%s' "${GITHUB_DEPLOY_KEY_B64}" | base64 -d >/dev/null 2>&1; then
    fail "Invalid base64 deploy key"
  fi
}

configure_ssh() {
  if [ -z "${GITHUB_DEPLOY_KEY_B64:-}" ]; then
    return
  fi

  log "Configuring SSH access for GitHub..."

  mkdir -p "${SSH_DIR}"
  chmod 700 "${SSH_DIR}"

  install -m 600 /dev/null "${DEPLOY_KEY_PATH}"
  printf '%s' "${GITHUB_DEPLOY_KEY_B64}" | base64 -d > "${DEPLOY_KEY_PATH}"
  chmod 600 "${DEPLOY_KEY_PATH}"

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
  if [ -z "${GITHUB_DEPLOY_KEY_B64:-}" ]; then
    return
  fi

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

  if [ -n "${GITHUB_DEPLOY_KEY_B64:-}" ]; then
    log "Cloning deploy repo via SSH."
    GIT_SSH_COMMAND="ssh -i ${DEPLOY_KEY_PATH} -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes" \
      git clone "${DEPLOY_REPO_SSH}" "${DEPLOY_REPO_DIR}"
  else
    log "Cloning deploy repo via HTTPS."
    git clone "${DEPLOY_REPO_HTTPS}" "${DEPLOY_REPO_DIR}"
  fi
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
