#!/usr/bin/env bash
# Public droplet bootstrap — provisioning convenience only; NOT ReleasePanel Central (the platform).
#
# Canonical copy: https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/scripts/public-droplet-bootstrap.sh
# Invoked via ../control-install.sh or saved and run locally.
#
# Structural heritage: legacy releasepanel-bootstrap `legacy/old-bootstrap.sh` (root-first droplet install,
# hardened apt, deploy-key flow, SSH config for GitHub) adapted for **releasepanel-central** + bootstrap-central.sh.
#
# Establishes Git read access (deploy key), clones private releasepanel-central, hands off to:
#   scripts/bootstrap-central.sh (and verify-central.sh) inside that repo when .env exists.
#
# Run on Ubuntu 24.04 as **root** (OG-style, typical `curl | bash` on a new droplet) or as a **sudo-capable**
# user (e.g. ubuntu). As root, clone ownership is fixed for the handoff user (**ubuntu** or **RP_BOOTSTRAP_USER**).
#
# One-liner (after setting CENTRAL_REPO_SSH):
#   curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/control-install.sh -o /tmp/rp-install.sh && bash /tmp/rp-install.sh
#
# Environment:
#   CENTRAL_REPO_SSH   Required. SSH clone URL, e.g. git@github.com:EdwardSoaresJr/releasepanel-central.git (forks: your user/org)
#   CENTRAL_APP_ROOT   App directory (default: /var/www/releasepanel-central)
#   CENTRAL_BRANCH     Branch to clone/track (default: main)
#   DEPLOY_KEY_PATH    Private key path (default: /root/.ssh/... if root else ~/.ssh/... releasepanel_central_git_deploy)
#   CENTRAL_DEPLOY_KEY_B64 | INSTALL_DEPLOY_KEY_B64 | RELEASEPANEL_DEPLOY_KEY_B64  Optional. Base64 PEM private key
#   FORCE_NEW_DEPLOY_KEY  If 1: replace existing private key at DEPLOY_KEY_PATH
#   SKIP_SSH_PROMPT      If 1: do not wait for Enter after showing pubkey (for advanced automation)
#   RELEASEPANEL_ASSUME_DEPLOY_KEY_ADDED  Same as SKIP_SSH_PROMPT=1 (OG-era alias)
#   RP_BOOTSTRAP_USER    When invoked as root, chown clone + sudo handoff to this user (default: ubuntu if present)
#   RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN  If true: allow curl installer when vendor/ already exists (repair only)
#
# Does NOT print .env; does NOT install mysql-server/mariadb-server; does NOT embed GitHub tokens.
#
set -euo pipefail

log() {
  echo "[public-droplet-bootstrap] $*" >&2
}

fail() {
  log "ERROR: $*"
  exit 1
}

if [[ "${RELEASEPANEL_ASSUME_DEPLOY_KEY_ADDED:-}" == "true" ]]; then
  SKIP_SSH_PROMPT="${SKIP_SSH_PROMPT:-1}"
fi

CENTRAL_REPO_SSH="${CENTRAL_REPO_SSH:-${GITHUB_REPO_SSH:-}}"
if [[ -z "${CENTRAL_REPO_SSH}" ]]; then
  echo "ERROR: set CENTRAL_REPO_SSH (e.g. git@github.com:EdwardSoaresJr/releasepanel-central.git)" >&2
  exit 1
fi

CENTRAL_APP_ROOT="${CENTRAL_APP_ROOT:-/var/www/releasepanel-central}"
CENTRAL_BRANCH="${CENTRAL_BRANCH:-main}"
FORCE_NEW_DEPLOY_KEY="${FORCE_NEW_DEPLOY_KEY:-0}"
SKIP_SSH_PROMPT="${SKIP_SSH_PROMPT:-0}"

_as_root=0
[[ "$(id -u)" -eq 0 ]] && _as_root=1

HANDOFF_USER=""
_ssh_home=""
if [[ "${_as_root}" -eq 1 ]]; then
  HANDOFF_USER="${RP_BOOTSTRAP_USER:-}"
  if [[ -z "${HANDOFF_USER}" ]] && id ubuntu &>/dev/null; then
    HANDOFF_USER=ubuntu
  fi
  if [[ -z "${HANDOFF_USER}" ]] || ! id "${HANDOFF_USER}" &>/dev/null; then
    fail "running as root: set RP_BOOTSTRAP_USER to a sudo-capable account (e.g. ubuntu must exist on the image)."
  fi
  _ssh_home=/root
  DEPLOY_KEY_PATH="${DEPLOY_KEY_PATH:-/root/.ssh/releasepanel_central_git_deploy}"
else
  _ssh_home="${HOME}"
  DEPLOY_KEY_PATH="${DEPLOY_KEY_PATH:-${HOME}/.ssh/releasepanel_central_git_deploy}"
fi

github_deploy_keys_url() {
  local ssh_url="$1"
  if [[ "${ssh_url}" =~ ^git@github\.com:([^/]+)/([^./]+)(\.git)?$ ]]; then
    echo "https://github.com/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/settings/keys"
  else
    echo "(open repo on GitHub → Settings → Deploy keys)"
  fi
}

install_minimal_git_ssh() {
  if command -v git >/dev/null 2>&1 && command -v ssh-keygen >/dev/null 2>&1; then
    return 0
  fi
  log "Installing git, openssh-client, ca-certificates (minimal, OG-style apt options)"
  export DEBIAN_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a
  export UCF_FORCE_CONFFOLD=1
  local -a opts=( -o Acquire::Retries=3 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 )
  if [[ "${_as_root}" -eq 1 ]]; then
    apt-get "${opts[@]}" update -y
    apt-get "${opts[@]}" install -y \
      -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
      git openssh-client ca-certificates
  else
    sudo apt-get "${opts[@]}" update -qq
    sudo env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a UCF_FORCE_CONFFOLD=1 \
      apt-get "${opts[@]}" install -y \
      -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
      git openssh-client ca-certificates
  fi
}

ensure_github_known_hosts() {
  local known="$1"
  mkdir -p "$(dirname "${known}")"
  touch "${known}"
  chmod 600 "${known}"
  if ! ssh-keygen -F github.com -f "${known}" >/dev/null 2>&1; then
    log "Adding github.com to SSH known_hosts (${known})"
    ssh-keyscan github.com >>"${known}" 2>/dev/null
    chmod 600 "${known}"
  fi
}

write_github_ssh_config() {
  local ssh_dir="$1"
  local key_path="$2"
  cat >"${ssh_dir}/config" <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile ${key_path}
  IdentitiesOnly yes
  StrictHostKeyChecking yes
EOF
  chmod 600 "${ssh_dir}/config"
}

central_tree_looks_converged() {
  [[ -f "${CENTRAL_APP_ROOT}/.env" ]] && [[ -f "${CENTRAL_APP_ROOT}/artisan" ]] && [[ -d "${CENTRAL_APP_ROOT}/vendor" ]]
}

refuse_repeat_curl_when_converged() {
  if [[ "${RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN:-}" == "true" ]]; then
    log "RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN=true — continuing (repair / advanced only)."
    return 0
  fi
  if ! central_tree_looks_converged; then
    return 0
  fi
  log "This host already has a converged Central tree at ${CENTRAL_APP_ROOT} (.env, artisan, vendor)."
  log "Routine updates — not this curl installer:"
  log "  cd ${CENTRAL_APP_ROOT} && git pull --ff-only origin main && sudo -u releasepanel ./scripts/deploy-central.sh"
  log "Re-run this installer anyway: RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN=true bash ... "
  exit 1
}

prepare_app_root_ownership() {
  if [[ "${_as_root}" -eq 1 ]]; then
    mkdir -p "${CENTRAL_APP_ROOT}"
    chown "${HANDOFF_USER}:${HANDOFF_USER}" "${CENTRAL_APP_ROOT}"
  else
    sudo mkdir -p "${CENTRAL_APP_ROOT}"
    sudo chown "$(id -u):$(id -gn)" "${CENTRAL_APP_ROOT}"
  fi
}

fix_clone_ownership_for_handoff() {
  if [[ "${_as_root}" -eq 1 ]]; then
    chown -R "${HANDOFF_USER}:${HANDOFF_USER}" "${CENTRAL_APP_ROOT}"
  fi
}

install_minimal_git_ssh

if [[ "${FORCE_NEW_DEPLOY_KEY}" == "1" ]] || [[ "${FORCE_NEW_DEPLOY_KEY}" == "true" ]]; then
  rm -f "${DEPLOY_KEY_PATH}" "${DEPLOY_KEY_PATH}.pub"
  log "Removed existing deploy key (FORCE_NEW_DEPLOY_KEY)."
fi

mkdir -p "${_ssh_home}/.ssh"
chmod 700 "${_ssh_home}/.ssh"
ensure_github_known_hosts "${_ssh_home}/.ssh/known_hosts"

DEPLOY_KEY_FROM_B64=0
KEY_B64="${CENTRAL_DEPLOY_KEY_B64:-${INSTALL_DEPLOY_KEY_B64:-${RELEASEPANEL_DEPLOY_KEY_B64:-}}}"

if [[ -n "${KEY_B64}" ]]; then
  log "Installing deploy private key from *_DEPLOY_KEY_B64"
  printf '%s' "${KEY_B64}" | tr -d '\n\r' | base64 -d >"${DEPLOY_KEY_PATH}"
  chmod 600 "${DEPLOY_KEY_PATH}"
  if ! ssh_key_pub="$(ssh-keygen -y -f "${DEPLOY_KEY_PATH}" 2>&1)"; then
    log "ERROR: deploy key B64 decoded to an invalid private key (${ssh_key_pub})." >&2
    rm -f "${DEPLOY_KEY_PATH}" "${DEPLOY_KEY_PATH}.pub"
    exit 1
  fi
  printf '%s\n' "${ssh_key_pub}" >"${DEPLOY_KEY_PATH}.pub"
  chmod 644 "${DEPLOY_KEY_PATH}.pub"
  DEPLOY_KEY_FROM_B64=1
elif [[ ! -f "${DEPLOY_KEY_PATH}" ]]; then
  log "Generating Ed25519 deploy key: ${DEPLOY_KEY_PATH}"
  ssh-keygen -t ed25519 -f "${DEPLOY_KEY_PATH}" -N "" -C "releasepanel-central-git-$(hostname -s 2>/dev/null || echo droplet)-$(date +%Y%m%d%H%M%S)"
  chmod 600 "${DEPLOY_KEY_PATH}"
  chmod 644 "${DEPLOY_KEY_PATH}.pub"
else
  chmod 600 "${DEPLOY_KEY_PATH}"
  chmod 644 "${DEPLOY_KEY_PATH}.pub"
fi

write_github_ssh_config "${_ssh_home}/.ssh" "${DEPLOY_KEY_PATH}"

export GIT_SSH_COMMAND="ssh -i ${DEPLOY_KEY_PATH} -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes"

if [[ "${DEPLOY_KEY_FROM_B64}" -eq 0 ]]; then
  _keys_url="$(github_deploy_keys_url "${CENTRAL_REPO_SSH}")"
  log "----------------------------------------------------------------------"
  log "Add this public key as a GitHub Deploy key (read-only) on releasepanel-central:"
  log ""
  cat "${DEPLOY_KEY_PATH}.pub" >&2
  log ""
  log "GitHub (deploy keys): ${_keys_url}"
  log "Use read-only access. Do not enable write."
  log "----------------------------------------------------------------------"
  log "Repository: ${CENTRAL_REPO_SSH}  branch: ${CENTRAL_BRANCH}"
  log "----------------------------------------------------------------------"

  if [[ "${SKIP_SSH_PROMPT}" != "1" ]] && [[ "${SKIP_SSH_PROMPT}" != "true" ]]; then
    if [[ -r /dev/tty ]]; then
      read -r -p "Press Enter after the deploy key is saved on GitHub... " _ </dev/tty
    else
      log "ERROR: no interactive terminal (e.g. piping from curl)." >&2
      log "  Save this script and run it in an SSH session, or set RELEASEPANEL_ASSUME_DEPLOY_KEY_ADDED=true / SKIP_SSH_PROMPT=1 / *_DEPLOY_KEY_B64." >&2
      exit 1
    fi
  fi
else
  log "Using pre-supplied deploy key (B64); skipping GitHub paste prompt."
fi

log "Verifying read access (git ls-remote)..."
if ! git ls-remote "${CENTRAL_REPO_SSH}" "refs/heads/${CENTRAL_BRANCH}" >/dev/null; then
  log "ERROR: git ls-remote failed — check read-only deploy key, branch name, and repo URL." >&2
  [[ -f "${DEPLOY_KEY_PATH}.pub" ]] && cat "${DEPLOY_KEY_PATH}.pub" >&2
  exit 1
fi

refuse_repeat_curl_when_converged

prepare_app_root_ownership

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

fix_clone_ownership_for_handoff

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

if [[ "${_as_root}" -eq 1 ]]; then
  exec sudo -u "${HANDOFF_USER}" -H env \
    CENTRAL_APP_ROOT="${CENTRAL_APP_ROOT}" \
    CENTRAL_WEB_HOSTNAME="${CENTRAL_WEB_HOSTNAME:-}" \
    CENTRAL_REPO_URL="${CENTRAL_REPO_URL:-}" \
    CENTRAL_BRANCH="${CENTRAL_BRANCH:-}" \
    SKIP_CERTBOT="${SKIP_CERTBOT:-}" \
    CERTBOT_EMAIL="${CERTBOT_EMAIL:-}" \
    RUN_VERIFY="${RUN_VERIFY:-}" \
    VERIFY_BASE_URL="${VERIFY_BASE_URL:-}" \
    bash "${CENTRAL_APP_ROOT}/scripts/bootstrap-central.sh"
else
  exec bash "${CENTRAL_APP_ROOT}/scripts/bootstrap-central.sh"
fi
