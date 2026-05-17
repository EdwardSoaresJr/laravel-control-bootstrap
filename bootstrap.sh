#!/usr/bin/env bash
# Back-compat entrypoint: control-plane installs delegate to install.sh.
# Customer / runner transport: INSTALL_MODE=runner (prefer runner.sh + releasepanel-runner).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "${RELEASEPANEL_INSTALL_MODE:-control}" = control ]; then
  exec "${SCRIPT_DIR}/install.sh" "$@"
fi

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export UCF_FORCE_CONFFOLD=1

readonly DEPLOY_ROOT="/opt"
readonly DEFAULT_RUNNER_BUNDLE_HTTPS="https://github.com/EdwardSoaresJr/releasepanel-runner.git"
readonly RUNNER_REPO_DIR="${DEPLOY_ROOT}/releasepanel-runner"
readonly RUNNER_REPO_HTTPS="${RELEASEPANEL_RUNNER_REPO_HTTPS:-${DEFAULT_RUNNER_BUNDLE_HTTPS}}"

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

clone_public_runner_bundle() {
  log "Cloning releasepanel-runner (public bundle + embedded toolkit)..."

  export GIT_TERMINAL_PROMPT=0

  mkdir -p "${DEPLOY_ROOT}"

  if [ -d "${RUNNER_REPO_DIR}/.git" ]; then
    log "releasepanel-runner already present; pulling."
    if ! git -c credential.helper= -C "${RUNNER_REPO_DIR}" pull --ff-only; then
      fail "git pull failed for ${RUNNER_REPO_DIR}."
    fi
  else
    if [ -e "${RUNNER_REPO_DIR}" ]; then
      fail "${RUNNER_REPO_DIR} exists but is not a git repository"
    fi
    if ! git -c credential.helper= clone "${RUNNER_REPO_HTTPS}" "${RUNNER_REPO_DIR}"; then
      fail "HTTPS clone failed. Use public ${DEFAULT_RUNNER_BUNDLE_HTTPS} or set RELEASEPANEL_RUNNER_REPO_HTTPS to a public mirror."
    fi
  fi

  if [ ! -f "${RUNNER_REPO_DIR}/toolkit/scripts/bootstrap-runner.sh" ]; then
    fail "Checkout is missing toolkit/ (expected toolkit/scripts/bootstrap-runner.sh). Use the official releasepanel-runner repository."
  fi
}

handoff_to_runner_toolkit() {
  log "Handing off to local toolkit: ${RUNNER_REPO_DIR}/toolkit/scripts/bootstrap-runner.sh"

  export RELEASEPANEL_TOOLKIT_DIR="${RUNNER_REPO_DIR}/toolkit"

  cd "${RUNNER_REPO_DIR}/toolkit"
  exec bash scripts/bootstrap-runner.sh
}

main() {
  log "INSTALL_MODE=runner — runner transport only (not the hosted panel)."

  require_root
  install_minimal_dependencies
  clone_public_runner_bundle
  handoff_to_runner_toolkit
}

main "$@"
