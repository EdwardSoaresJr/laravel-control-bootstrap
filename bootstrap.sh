#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export UCF_FORCE_CONFFOLD=1

readonly DEPLOY_ROOT="/opt"
readonly DEPLOY_REPO_DIR="${DEPLOY_ROOT}/releasepanel-deploy"
readonly DEPLOY_REPO_SSH="git@github.com:EdwardSoaresJr/releasepanel-deploy.git"
# Managed servers: single public clone — releasepanel-runner (includes toolkit/).
readonly DEFAULT_RUNNER_BUNDLE_HTTPS="https://github.com/EdwardSoaresJr/releasepanel-runner.git"
readonly RUNNER_REPO_DIR="${DEPLOY_ROOT}/releasepanel-runner"
readonly RUNNER_REPO_HTTPS="${RELEASEPANEL_RUNNER_REPO_HTTPS:-${DEFAULT_RUNNER_BUNDLE_HTTPS}}"
readonly GITHUB_REPO_URL="https://github.com/EdwardSoaresJr/releasepanel-deploy/settings/keys"
readonly SSH_DIR="/root/.ssh"
readonly DEPLOY_KEY_PATH="${SSH_DIR}/releasepanel_deploy"
readonly SSH_KNOWN_HOSTS="${SSH_DIR}/known_hosts"
readonly INSTALL_MODE="${RELEASEPANEL_INSTALL_MODE:-control}"

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

ensure_ssh_known_hosts() {
  mkdir -p "${SSH_DIR}"
  chmod 700 "${SSH_DIR}"
  touch "${SSH_KNOWN_HOSTS}"
  chmod 600 "${SSH_KNOWN_HOSTS}"

  if ! ssh-keygen -F github.com -f "${SSH_KNOWN_HOSTS}" >/dev/null 2>&1; then
    log "Adding github.com to SSH known_hosts..."
    ssh-keyscan github.com >> "${SSH_KNOWN_HOSTS}" 2>/dev/null
  fi
}

write_key_from_env() {
  if [ -z "${RELEASEPANEL_DEPLOY_KEY_B64:-}" ]; then
    return 1
  fi

  log "Using RELEASEPANEL_DEPLOY_KEY_B64 for private deploy repo access."
  umask 077
  printf '%s' "${RELEASEPANEL_DEPLOY_KEY_B64}" | base64 -d > "${DEPLOY_KEY_PATH}" || fail "Invalid RELEASEPANEL_DEPLOY_KEY_B64"
  chmod 600 "${DEPLOY_KEY_PATH}"
  ssh-keygen -y -f "${DEPLOY_KEY_PATH}" >/dev/null || fail "Decoded deploy key is not a valid SSH private key"

  return 0
}

generate_deploy_key() {
  if [ -f "${DEPLOY_KEY_PATH}" ]; then
    chmod 600 "${DEPLOY_KEY_PATH}"
    return
  fi

  log "Generating SSH deploy key for private releasepanel-deploy repo."
  ssh-keygen -t ed25519 -N "" -C "releasepanel-deploy@$(hostname)-$(date +%Y%m%d%H%M%S)" -f "${DEPLOY_KEY_PATH}" >/dev/null
  chmod 600 "${DEPLOY_KEY_PATH}"
}

print_public_key_instructions() {
  echo ""
  echo "============================================================"
  echo "Add this public key to the private releasepanel-deploy repo:"
  echo ""
  cat "${DEPLOY_KEY_PATH}.pub"
  echo ""
  echo "GitHub URL:"
  echo "  ${GITHUB_REPO_URL}"
  echo ""
  echo "Use a read-only deploy key. Do not enable write access."
  echo "============================================================"
  echo ""
}

wait_for_key_install() {
  if [ -n "${RELEASEPANEL_DEPLOY_KEY_B64:-}" ]; then
    return
  fi

  print_public_key_instructions

  if [ "${RELEASEPANEL_ASSUME_DEPLOY_KEY_ADDED:-false}" = "true" ]; then
    return
  fi

  if [ ! -r /dev/tty ]; then
    fail "No interactive terminal available. Add the printed key, then rerun with RELEASEPANEL_ASSUME_DEPLOY_KEY_ADDED=true."
  fi

  read -r -p "Press Enter after adding the deploy key to GitHub..." _ < /dev/tty
}

git_ssh() {
  GIT_SSH_COMMAND="ssh -i ${DEPLOY_KEY_PATH} -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes" "$@"
}

write_ssh_config() {
  cat > "${SSH_DIR}/config" <<EOF
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

clone_deploy_repo() {
  log "Ensuring deploy repo is present..."

  mkdir -p "${DEPLOY_ROOT}"

  if [ -d "${DEPLOY_REPO_DIR}/.git" ]; then
    ensure_deploy_key
    log "Deploy repo already exists; updating with deploy key."
    git_ssh git -C "${DEPLOY_REPO_DIR}" pull --ff-only
    return
  fi

  if [ -e "${DEPLOY_REPO_DIR}" ]; then
    fail "${DEPLOY_REPO_DIR} exists but is not a git repository"
  fi

  ensure_deploy_key

  log "Cloning private deploy repo via SSH."
  if ! git_ssh git clone "${DEPLOY_REPO_SSH}" "${DEPLOY_REPO_DIR}"; then
    rm -rf "${DEPLOY_REPO_DIR}"
    if [ -f "${DEPLOY_KEY_PATH}.pub" ]; then
      print_public_key_instructions
    fi
    fail "SSH clone failed for private deploy repo: ${DEPLOY_REPO_SSH}"
  fi
}

clone_public_runner_bundle() {
  log "Cloning releasepanel-runner (Node agent + embedded toolkit)..."

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

handoff_to_private_bootstrap() {
  log "Handing off to private bootstrap (${INSTALL_MODE} mode)..."

  cd "${DEPLOY_REPO_DIR}"

  bash scripts/01-bootstrap.sh
}

handoff_to_public_runner_bootstrap() {
  log "Managed server: public releasepanel-runner only (toolkit embedded) + bootstrap-runner.sh"

  clone_public_runner_bundle

  export RELEASEPANEL_TOOLKIT_DIR="${RUNNER_REPO_DIR}/toolkit"

  cd "${RUNNER_REPO_DIR}/toolkit"
  bash scripts/bootstrap-runner.sh
}

main() {
  log "Starting..."

  require_root
  install_minimal_dependencies

  case "${INSTALL_MODE}" in
    control)
      clone_deploy_repo
      handoff_to_private_bootstrap
      ;;
    runner)
      handoff_to_public_runner_bootstrap
      ;;
    *)
      fail "Invalid RELEASEPANEL_INSTALL_MODE=${INSTALL_MODE}. Use control or runner."
      ;;
  esac

  log "Complete."
}

main "$@"
