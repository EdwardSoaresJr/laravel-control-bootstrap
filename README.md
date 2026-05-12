# ReleasePanel Bootstrap

**Public trust and acquisition layer** for the **current** ReleasePanel architecture — **not** the platform, **not** orchestration, **not** runtime authority.

This repository stays **tiny**, **shell-only**, **auditable**, and **boring by design**. At first boot, **no trusted Central runtime exists yet**, so the only thing that can be public is a **minimal** script surface: **establish Git trust → clone private code → hand off**.

| Repository | Role |
|------------|------|
| **releasepanel-bootstrap** (this repo, **public**) | Deploy key + clone private **`releasepanel-central`**; hand off to **`bootstrap-central.sh`**. No secrets here. No product logic. |
| **releasepanel-central** (**private**) | Operational control plane: Laravel app, converge scripts, **`.env`**, Managed MySQL, real deployment behavior. |
| **releasepanel-agent** (**private**, agent runtime) | Execution / enrollment on managed nodes — **not** installed from this repo. |
| **releasepanel-deploy** (**legacy**) | **Former** private monorepo — **replaced by `releasepanel-central`**. **Not** an install or bootstrap target; historical docs live in **releasepanel-central** under **`docs/legacy/`**. |

**Flow:**

```text
Fresh VPS (root)
  → curl bootstrap.sh | bash
  → hardened apt + /root/.ssh deploy key + ssh config
  → git ls-remote + clone/pull private releasepanel-central
  → bootstrap-central.sh when .env exists (verify via bootstrap flow)
  → operational Central

Routine updates: git pull --ff-only + deploy-central.sh (not this installer).
```

---

## Why this repo is public

Bootstrap runs **before** you have Central, agents, private runtime, or existing SSH trust to that stack. The public script is **low-trust**: no secrets committed, no orchestration engine — only enough to **clone** the private repo after you register a **read-only GitHub Deploy key**.

## Why the platform repo is private

**releasepanel-central** holds application code, **`.env`**/secrets policy, provisioning logic, and operational behavior. That is **platform authority**, not acquisition.

## Why this repo stays intentionally small

Bootstrap repos **drift** into shadow platforms (extra provisioning, env engines, “temporary” orchestration). Guardrail: **establish trust → acquire repo → hand off**. For routine **application** updates after the host exists, use **`git pull --ff-only`** + **`deploy-central.sh`** inside the clone — not a second helping of `curl | bash` for every deploy.

---

## Canonical one-line (control plane host)

Installer is **`bootstrap.sh`** — **one self-contained file**, mechanically aligned with **`legacy/old-bootstrap.sh`**, pointed at **releasepanel-central** and **`bootstrap-central.sh`**. **Must run as root** (`sudo -i`). Forks: set **`CENTRAL_REPO_SSH`**.

```bash
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh | bash
```

With explicit repo (recommended for private forks):

```bash
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh | \
  env CENTRAL_REPO_SSH='git@github.com:EdwardSoaresJr/releasepanel-central.git' bash
```

**Interactive path:** SSH session with TTY for deploy-key paste, or **`RELEASEPANEL_ASSUME_DEPLOY_KEY_ADDED=true`** / **`SKIP_SSH_PROMPT=1`** / **`*_DEPLOY_KEY_B64`**.

**Non-interactive** (key already on GitHub):

```bash
export CENTRAL_DEPLOY_KEY_B64="$(base64 -w0 < /path/to/deploy_key_ed25519)"
export CENTRAL_REPO_SSH='git@github.com:EdwardSoaresJr/releasepanel-central.git'
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh | bash
```

**Legacy URLs:** **`control-install.sh`** and **`scripts/public-droplet-bootstrap.sh`** only fetch **`bootstrap.sh`** — prefer **`bootstrap.sh`** for new bookmarks.

*(Forks: set `CENTRAL_REPO_SSH` to your clone URL.)*

---

## Repo layout

| Path | Purpose |
|------|---------|
| **`bootstrap.sh`** | **Canonical.** Single-file installer (OG **`old-bootstrap.sh`** mechanics → Central + **`bootstrap-central.sh`**). |
| `control-install.sh` | Legacy name: **downloads `bootstrap.sh`** and execs. |
| `scripts/public-droplet-bootstrap.sh` | Legacy path: same as **`control-install.sh`**. |
| `legacy/` | **Archived** installers (`releasepanel-deploy` / runner). **Do not use** for new installs. |

---

## Environment (summary)

| Variable | Purpose |
|----------|---------|
| `CENTRAL_REPO_SSH` | SSH URL for private **releasepanel-central** (default upstream example in **`bootstrap.sh`**). Alias: `GITHUB_REPO_SSH`. |
| `CENTRAL_APP_ROOT` | Clone target (default `/var/www/releasepanel-central`). |
| `CENTRAL_BRANCH` | Git branch (default `main`). |
| `CENTRAL_PUBLIC_BASE` | Override raw URL root for this repo’s `main` tree (wrappers only). |
| `CENTRAL_BOOTSTRAP_SCRIPT_URL` | Pin full raw URL of **`bootstrap.sh`** (tags/releases). |
| `CENTRAL_DEPLOY_KEY_B64` / `INSTALL_DEPLOY_KEY_B64` / `RELEASEPANEL_DEPLOY_KEY_B64` | Optional PEM private key, base64; skips interactive deploy-key step. |
| `SKIP_SSH_PROMPT` | `1` if Deploy key is **already** on GitHub (no TTY). |
| `RELEASEPANEL_ASSUME_DEPLOY_KEY_ADDED` | `true` — same as **`SKIP_SSH_PROMPT=1`** (OG-era name). |
| `RP_BOOTSTRAP_USER` | When **root** runs the installer: **`chown`** clone to this user and **`sudo`** handoff to **`bootstrap-central.sh`** (default **`ubuntu`**). |
| `RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN` | `true` — allow the curl installer when **`.env` + `vendor/`** already exist (repair only). |
| `FORCE_NEW_DEPLOY_KEY` | `1` to regenerate key files. |

Further Central bootstrap options (**`CENTRAL_WEB_HOSTNAME`**, Certbot, verify URL, …) are documented in **releasepanel-central** (`scripts/bootstrap-central.sh`, docs).

---

## Safety posture (explicit)

- **Designed for** a **fresh Ubuntu cloud VPS** (cold bootstrap). **Not** for laptops or servers where **`~/.ssh/config`** already encodes other identities — this installer **replaces** that file with a minimal **`Host github.com`** block.
- **No** secrets committed in this repo.
- **No** `.env` generation — operator creates **`.env`** in the private clone from **`.env.example`**.
- **No** `mysql-server` / `mariadb-server` install from these scripts (Central uses **DigitalOcean Managed MySQL**).
- **No** orchestration / browser runtime coupling here.
- **Loud failures**, **`git pull --ff-only`** on re-run, **`git ls-remote`** before clone.

---

## Legacy (pre–Central architecture)

**Older** scripts that cloned **releasepanel-deploy** (legacy private monorepo, **not** current — use **releasepanel-central** instead) and/or **releasepanel-runner** (`INSTALL_MODE=control|runner`) live under **`legacy/`** for historical context only.

- **`legacy/old-bootstrap.sh`** — root + `01-bootstrap.sh` era.
- **`legacy/runner.sh`** — `curl` entry to **releasepanel-runner** `install-managed-vps.sh`.

See **`legacy/README.md`** and **`legacy/old-runner-flow-notes.md`**.

**Do not** use legacy paths for new **releasepanel-central** installs.

---

## Related

- Private app: **releasepanel-central** — `README.md`, `docs/FIRST-DEPLOY-SMOKE.md`, `docs/PRODUCTION-DEPLOYMENT.md`.
- Optional stable URL: serve **`bootstrap.sh`** (or a thin wrapper that fetches it) from your own static host.
