#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export UCF_FORCE_CONFFOLD=1

readonly DEPLOY_ROOT="/opt"
readonly DEPLOY_REPO_DIR="${DEPLOY_ROOT}/releasepanel-deploy"
readonly DEPLOY_REPO_HTTPS="https://github.com/EdwardSoaresJr/releasepanel-deploy.git"

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
    git curl ca-certificates
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

  log "Cloning deploy repo via HTTPS."
  if ! GIT_TERMINAL_PROMPT=0 git clone "${DEPLOY_REPO_HTTPS}" "${DEPLOY_REPO_DIR}"; then
    rm -rf "${DEPLOY_REPO_DIR}"
    fail "HTTPS clone failed for public deploy repo: ${DEPLOY_REPO_HTTPS}"
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
  clone_deploy_repo
  handoff_to_private_bootstrap

  log "Complete."
}

main "$@"
