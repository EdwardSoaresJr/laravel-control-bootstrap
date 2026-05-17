#!/usr/bin/env bash
# ReleasePanel control-plane transport only.
#
# This script does NOT provision PHP, nginx, MySQL, or the panel — it only:
#   1) installs minimal OS packages if needed (git, curl, ssh client),
#   2) clones the authoritative toolkit repo (releasepanel-deploy),
#   3) runs scripts/01-bootstrap.sh from THAT checkout.
#
# All install semantics live in releasepanel-deploy — inspect that repo for truth.
#
# Canonical (when hosted):
#   bash -c "$(curl -fsSL https://bootstrap.releasepanel.com/install.sh)"
# Raw GitHub equivalent:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/install.sh)"
#
# Options:
#   --dir PATH     toolkit checkout directory (default: /opt/releasepanel-deploy)
#                  env: RELEASEPANEL_TOOLKIT_INSTALL_DIR or INSTALL_DIR
#   --branch REF   git branch to clone/checkout (default: main)
#                  env: RELEASEPANEL_TOOLKIT_BRANCH
#
# Private repo SSH: deploy key flow uses RELEASEPANEL_DEPLOY_KEY_B64 or generates a key (same as before).

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export UCF_FORCE_CONFFOLD=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly DEPLOY_ROOT="/opt"
readonly DEPLOY_REPO_SSH_DEFAULT="git@github.com:EdwardSoaresJr/releasepanel-deploy.git"
readonly GITHUB_DEPLOY_KEYS_HINT_URL="https://github.com/EdwardSoaresJr/releasepanel-deploy/settings/keys"
readonly SSH_DIR="/root/.ssh"
readonly DEPLOY_KEY_PATH="${SSH_DIR}/releasepanel_deploy"

INSTALL_DIR="${RELEASEPANEL_TOOLKIT_INSTALL_DIR:-${INSTALL_DIR:-/opt/releasepanel-deploy}}"
BRANCH="${RELEASEPANEL_TOOLKIT_BRANCH:-main}"

usage() {
  cat <<'EOF'
ReleasePanel control-plane transport — clones releasepanel-deploy, runs scripts/01-bootstrap.sh locally.

Usage: install.sh [--dir PATH] [--branch REF] [--help]

Environment:
  RELEASEPANEL_TOOLKIT_INSTALL_DIR / INSTALL_DIR   default /opt/releasepanel-deploy
  RELEASEPANEL_TOOLKIT_BRANCH                     default main
  RELEASEPANEL_DEPLOY_REPO_SSH                    default git@github.com:EdwardSoaresJr/releasepanel-deploy.git
  RELEASEPANEL_DEPLOY_REPO_HTTPS                  if set, HTTPS clone (no deploy key from this script)
  RELEASEPANEL_DEPLOY_KEY_B64                   optional pre-supplied private key (base64)
  RELEASEPANEL_ASSUME_DEPLOY_KEY_ADDED=true       non-interactive after adding deploy key
  RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN=true        allow transport when panel tree already exists
EOF
  exit 0
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dir)
      INSTALL_DIR="${2:?}"
      shift 2
      ;;
    --branch)
      BRANCH="${2:?}"
      shift 2
      ;;
    -h | --help)
      usage
      ;;
    *)
      echo "[releasepanel-bootstrap/install] ERROR: unknown argument: $1 (try --help)" >&2
      exit 2
      ;;
  esac
done

INSTALL_DIR="${INSTALL_DIR%/}"

log() {
  echo "[releasepanel-bootstrap/install] $*"
}

fail() {
  echo "[releasepanel-bootstrap/install] ERROR: $*" >&2
  exit 1
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    fail "Run as root, for example: sudo -i"
  fi
}

validate_install_dir() {
  local d="$1"
  case "${d}" in
    "" | /opt | ../* | */.. | */../* | *..*)
      fail "Refusing INSTALL_DIR=${d} (must be a subdirectory of /opt, no ..)."
      ;;
  esac
  case "${d}" in
    /opt/*)
      ;;
    *)
      fail "INSTALL_DIR must be under /opt/ (got: ${d}). Example: /opt/releasepanel-deploy"
      ;;
  esac
}

install_minimal_dependencies() {
  log "Installing minimal dependencies (git, curl, ca-certificates, openssh-client)..."
  apt-get -o Acquire::Retries=3 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 update -y
  apt-get install -y \
    -o Acquire::Retries=3 \
    -o Acquire::http::Timeout=30 \
    -o Acquire::https::Timeout=30 \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    git curl ca-certificates openssh-client
}

ensure_ssh_known_hosts_github() {
  mkdir -p "${SSH_DIR}"
  chmod 700 "${SSH_DIR}"
  local kh="${SSH_DIR}/known_hosts"
  touch "${kh}"
  chmod 600 "${kh}"
  if ! ssh-keygen -F github.com -f "${kh}" >/dev/null 2>&1; then
    log "Recording github.com host keys in ${kh}..."
    ssh-keyscan github.com >>"${kh}" 2>/dev/null || true
  fi
}

write_key_from_env() {
  if [ -z "${RELEASEPANEL_DEPLOY_KEY_B64:-}" ]; then
    return 1
  fi
  log "Using RELEASEPANEL_DEPLOY_KEY_B64 for private repo SSH access."
  umask 077
  printf '%s' "${RELEASEPANEL_DEPLOY_KEY_B64}" | base64 -d >"${DEPLOY_KEY_PATH}" || fail "Invalid RELEASEPANEL_DEPLOY_KEY_B64"
  chmod 600 "${DEPLOY_KEY_PATH}"
  ssh-keygen -y -f "${DEPLOY_KEY_PATH}" >/dev/null || fail "Decoded deploy key is not a valid SSH private key"
  return 0
}

generate_deploy_key() {
  if [ -f "${DEPLOY_KEY_PATH}" ]; then
    chmod 600 "${DEPLOY_KEY_PATH}"
    return 0
  fi
  log "Generating SSH deploy key for releasepanel-deploy clone (${DEPLOY_KEY_PATH})."
  ssh-keygen -t ed25519 -N "" -C "releasepanel-deploy@$(hostname)-$(date +%Y%m%d%H%M%S)" -f "${DEPLOY_KEY_PATH}" >/dev/null
  chmod 600 "${DEPLOY_KEY_PATH}"
}

print_public_key_instructions() {
  echo ""
  echo "============================================================"
  echo "Add this public key as a read-only Deploy key on GitHub:"
  echo ""
  cat "${DEPLOY_KEY_PATH}.pub"
  echo ""
  echo "Repo settings:"
  echo "  ${GITHUB_DEPLOY_KEYS_HINT_URL}"
  echo ""
  echo "Use read-only access unless this host must push to the toolkit repo."
  echo "============================================================"
  echo ""
}

wait_for_key_install() {
  if [ -n "${RELEASEPANEL_DEPLOY_KEY_B64:-}" ]; then
    return 0
  fi
  print_public_key_instructions
  if [ "${RELEASEPANEL_ASSUME_DEPLOY_KEY_ADDED:-false}" = "true" ]; then
    return 0
  fi
  if [ ! -r /dev/tty ]; then
    fail "No interactive terminal. Add the printed key, then rerun with RELEASEPANEL_ASSUME_DEPLOY_KEY_ADDED=true."
  fi
  read -r -p "Press Enter after adding the deploy key to GitHub..." _ </dev/tty
}

git_ssh() {
  GIT_SSH_COMMAND="ssh -F /dev/null -i ${DEPLOY_KEY_PATH} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" "$@"
}

ensure_deploy_key_for_ssh_clone() {
  ensure_ssh_known_hosts_github
  if ! write_key_from_env; then
    generate_deploy_key
    wait_for_key_install
  fi
}

DEPLOY_REPO_SSH="${RELEASEPANEL_DEPLOY_REPO_SSH:-${DEPLOY_REPO_SSH_DEFAULT}}"
DEPLOY_REPO_HTTPS="${RELEASEPANEL_DEPLOY_REPO_HTTPS:-}"

clone_or_update_toolkit() {
  mkdir -p "${DEPLOY_ROOT}"

  if [ -n "${DEPLOY_REPO_HTTPS}" ]; then
    log "Using HTTPS clone (RELEASEPANEL_DEPLOY_REPO_HTTPS) — no deploy key from this script."
    export GIT_TERMINAL_PROMPT=0
    if [ -d "${INSTALL_DIR}/.git" ]; then
      log "Toolkit checkout exists; updating (${BRANCH})."
      git -C "${INSTALL_DIR}" fetch origin
      git -C "${INSTALL_DIR}" checkout --force "${BRANCH}"
      git -C "${INSTALL_DIR}" pull --ff-only origin "${BRANCH}"
    else
      [ ! -e "${INSTALL_DIR}" ] || fail "${INSTALL_DIR} exists but is not a git repo — remove or pick another --dir."
      log "Cloning via HTTPS into ${INSTALL_DIR} (branch ${BRANCH})."
      git -c credential.helper= clone --branch "${BRANCH}" --single-branch "${DEPLOY_REPO_HTTPS}" "${INSTALL_DIR}"
    fi
    return 0
  fi

  ensure_deploy_key_for_ssh_clone

  if [ -d "${INSTALL_DIR}/.git" ]; then
    log "Toolkit checkout exists at ${INSTALL_DIR}; updating (${BRANCH})."
    git_ssh git -C "${INSTALL_DIR}" fetch origin
    git_ssh git -C "${INSTALL_DIR}" checkout --force "${BRANCH}"
    git_ssh git -C "${INSTALL_DIR}" pull --ff-only origin "${BRANCH}"
    return 0
  fi

  [ ! -e "${INSTALL_DIR}" ] || fail "${INSTALL_DIR} exists but is not a git repository."

  log "Cloning via SSH into ${INSTALL_DIR} (branch ${BRANCH})."
  if ! git_ssh git clone --branch "${BRANCH}" --single-branch "${DEPLOY_REPO_SSH}" "${INSTALL_DIR}"; then
    rm -rf "${INSTALL_DIR}"
    if [ -f "${DEPLOY_KEY_PATH}.pub" ]; then
      print_public_key_instructions
    fi
    fail "SSH clone failed: ${DEPLOY_REPO_SSH}"
  fi
}

control_plane_appears_installed() {
  local base="/var/www/sites/releasepanel-app/production"
  [ -L "${base}/current" ] && [ -f "${base}/shared/.env" ]
}

refuse_repeat_install_transport() {
  if [ "${RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN:-}" = "true" ]; then
    log "RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN=true — continuing to local scripts/01-bootstrap.sh (repair / deliberate re-run)."
    return 0
  fi
  if ! control_plane_appears_installed; then
    return 0
  fi
  echo "" >&2
  log "This host already has a panel layout under /var/www/sites/releasepanel-app/production."
  log "Do not re-run the curl transport for routine updates — use the authoritative toolkit checkout:"
  log "  cd ${INSTALL_DIR} && git pull --ff-only origin ${BRANCH} && sudo releasepanel self-update"
  echo "" >&2
  exit 1
}

handoff_to_toolkit_bootstrap() {
  log "Handing off to local toolkit: ${INSTALL_DIR}/scripts/01-bootstrap.sh"
  cd "${INSTALL_DIR}"
  exec bash scripts/01-bootstrap.sh
}

main() {
  log "ReleasePanel install transport — cloning authoritative toolkit, then local 01-bootstrap.sh."
  log "INSTALL_DIR=${INSTALL_DIR} BRANCH=${BRANCH}"

  require_root
  validate_install_dir "${INSTALL_DIR}"
  install_minimal_dependencies
  clone_or_update_toolkit
  refuse_repeat_install_transport
  handoff_to_toolkit_bootstrap
}

main "$@"
