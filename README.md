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
Fresh VPS
  → curl control-install.sh
  → generate or supply deploy key (B64 optional)
  → git ls-remote + clone private releasepanel-central
  → ./scripts/bootstrap-central.sh (authoritative converge)
  → verify-central.sh (operational truth)
  → operational Central
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

**Set** `CENTRAL_REPO_SSH` to your **private** `git@github.com:…/releasepanel-central.git`. If you **SSH as root** (common on new droplets), the script **re-runs as `ubuntu`** so deploy keys and `/var/www` ownership stay consistent; override with **`RP_BOOTSTRAP_USER`** if needed.

```bash
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/control-install.sh -o /tmp/rp-install.sh \
  && env CENTRAL_REPO_SSH='git@github.com:EdwardSoaresJr/releasepanel-central.git' bash /tmp/rp-install.sh
```

*(Forks or private mirrors: substitute your GitHub user or org for `EdwardSoaresJr` in the URL above.)*

**Interactive path:** run from an **SSH session** so the script can pause after printing the **Deploy key** (or use **B64** / **`SKIP_SSH_PROMPT=1`** per below).

**Non-interactive / CI / DR** (key **already** a Deploy key on GitHub):

```bash
export CENTRAL_DEPLOY_KEY_B64="$(base64 -w0 < /path/to/deploy_key_ed25519)"   # GNU base64; macOS: base64 -i ... | tr -d '\n'
export CENTRAL_REPO_SSH='git@github.com:EdwardSoaresJr/releasepanel-central.git'
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/control-install.sh -o /tmp/rp-install.sh \
  && bash /tmp/rp-install.sh
```

Aliases for the same B64 value: **`INSTALL_DEPLOY_KEY_B64`**, **`RELEASEPANEL_DEPLOY_KEY_B64`**.

---

## Repo layout

| Path | Purpose |
|------|---------|
| `control-install.sh` | Downloads `scripts/public-droplet-bootstrap.sh` to a temp file and `exec`s it. |
| `scripts/public-droplet-bootstrap.sh` | Deploy key, `git ls-remote`, clone/ff-only pull, **`exec bootstrap-central.sh`** if **`.env`** exists; else exit **2** with instructions. |
| `legacy/` | **Archived** installers aimed at the old **`releasepanel-deploy`** monorepo (and runner paths). **`releasepanel-deploy` is legacy** — replaced by **`releasepanel-central`**. **Do not use for new installs.** |

---

## Environment (summary)

| Variable | Purpose |
|----------|---------|
| `CENTRAL_REPO_SSH` | **Required.** SSH URL for private **releasepanel-central**. Alias: `GITHUB_REPO_SSH`. |
| `CENTRAL_APP_ROOT` | Clone target (default `/var/www/releasepanel-central`). |
| `CENTRAL_BRANCH` | Git branch (default `main`). |
| `CENTRAL_PUBLIC_BASE` | Override raw URL root for this repo’s `main` tree (advanced). |
| `CENTRAL_BOOTSTRAP_SCRIPT_URL` | Pin full raw URL of `public-droplet-bootstrap.sh` (tags/releases). |
| `CENTRAL_DEPLOY_KEY_B64` / `INSTALL_DEPLOY_KEY_B64` / `RELEASEPANEL_DEPLOY_KEY_B64` | Optional PEM private key, base64; skips interactive deploy-key step. |
| `SKIP_SSH_PROMPT` | `1` if Deploy key is **already** on GitHub (no TTY). |
| `RP_BOOTSTRAP_USER` | When **root** runs the bootstrap script, sudo to this user (default **`ubuntu`** if the account exists). |
| `FORCE_NEW_DEPLOY_KEY` | `1` to regenerate key files. |

Further Central bootstrap options (**`CENTRAL_WEB_HOSTNAME`**, Certbot, verify URL, …) are documented in **releasepanel-central** (`scripts/bootstrap-central.sh`, docs).

---

## Safety posture (explicit)

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
- Optional stable URL: serve the same `control-install.sh` from your own static host; content should match this repo.
