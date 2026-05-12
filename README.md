# ReleasePanel Bootstrap

**Public trust and acquisition only:** this repo exists so you can install **ReleasePanel Central** on a **fresh Ubuntu VPS** without putting GitHub tokens in user-data. It is **not** the product, **not** orchestration, **not** runtime authority, and **not** how you update a host that already runs Central.

**Canonical target:** private **`releasepanel-central`** → hand off to **`scripts/bootstrap-central.sh`** → **`scripts/verify-central.sh`** (operational truth) when that flow runs.

---

## Install (only command you need)

Run as **root** (`sudo -i`).

```bash
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh | bash
```

That is the **only** primary install path. Everything else in this repo is **compatibility** or **history**.

**End-to-end flow:**

```text
Fresh VPS
  → bootstrap.sh
  → GitHub deploy-key trust + clone/pull private releasepanel-central
  → bootstrap-central.sh (when .env exists in the clone)
  → verify-central.sh (default inside that bootstrap)
  → operational Central
```

If **`.env`** is not in the clone yet, **`bootstrap.sh`** exits with instructions; create **`.env`** from **`.env.example`**, then re-run **`bootstrap.sh`** or run **`bootstrap-central.sh`** manually.

**Routine updates** (after Central exists): **not** `curl | bash` again.

```bash
cd /var/www/releasepanel-central   # or your CENTRAL_APP_ROOT
sudo git pull --ff-only origin main
sudo -u releasepanel ./scripts/deploy-central.sh
```

The installer **refuses** to act as a generic “repair” path once the tree looks fully converged (`.env`, `artisan`, `vendor`) unless you explicitly set **`RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN=true`** (break-glass only).

---

## What this repo is

| Piece | Role |
|------|------|
| **releasepanel-bootstrap** (this repo, **public**) | **One script:** establish SSH/Git trust, acquire **`releasepanel-central`**, hand off. No app logic. |
| **releasepanel-central** (**private**) | Control plane: Laravel, **`.env`**, Managed MySQL, **`bootstrap-central.sh`**, **`deploy-central.sh`**, **`verify-central.sh`**. |

Customer or agent nodes are **not** installed from here; that is **releasepanel-agent** and product enrollment elsewhere.

---

## Safety posture

- **Fresh disposable Ubuntu VPS** — cold bootstrap, not a shared workstation.
- **`bootstrap.sh`** may **replace `/root/.ssh/config`** with a minimal **`Host github.com`** block tied to the deploy key.
- **No** secrets committed in this repo.
- **No** **`.env`** generation here — you create **`.env`** in the private clone.
- **No** `mysql-server` / `mariadb-server` (Central uses **managed** MySQL off the VPS).
- **No** orchestration engine and **no** product runtime authority in this repo.
- **Primary updates** are **`git pull --ff-only`** + **`deploy-central.sh`**, not re-running the public installer.

---

## Advanced (optional)

Use these only when you already know you need them.

**Private fork / different GitHub org** — set SSH URL:

```bash
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh | \
  env CENTRAL_REPO_SSH='git@github.com:YOUR_ORG/releasepanel-central.git' bash
```

**Non-interactive** (deploy key already registered on the repo):

```bash
export CENTRAL_DEPLOY_KEY_B64="…"   # base64 PEM; see Central docs for tooling
export CENTRAL_REPO_SSH='git@github.com:YOUR_ORG/releasepanel-central.git'
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh | bash
```

**Repair-only** re-run of the public installer when Central already looks converged:

```bash
RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN=true bash bootstrap.sh
# (or pipe curl to bash with that env set)
```

Further options (**`CENTRAL_APP_ROOT`**, **`CENTRAL_BRANCH`**, Certbot, web hostname) live in **releasepanel-central** (`scripts/bootstrap-central.sh`, `docs/`).

### Environment (reference)

| Variable | Purpose |
|----------|---------|
| `CENTRAL_REPO_SSH` | SSH clone URL for **releasepanel-central** (sensible default in **`bootstrap.sh`**). Alias: `GITHUB_REPO_SSH`. |
| `CENTRAL_APP_ROOT` | Clone directory (default `/var/www/releasepanel-central`). |
| `CENTRAL_BRANCH` | Branch (default `main`). |
| `CENTRAL_DEPLOY_KEY_B64` / `INSTALL_DEPLOY_KEY_B64` / `RELEASEPANEL_DEPLOY_KEY_B64` | Pre-supplied deploy key; skips interactive key paste. |
| `SKIP_SSH_PROMPT` / `RELEASEPANEL_ASSUME_DEPLOY_KEY_ADDED` | Skip “press Enter” after adding key. |
| `RP_BOOTSTRAP_USER` | User for **`chown`** + **`sudo`** handoff to **`bootstrap-central.sh`** (default `ubuntu`). |
| `RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN` | `true` — bypass rerun guard (repair only). |
| `FORCE_NEW_DEPLOY_KEY` | `1` — regenerate key files. |
| `CENTRAL_PUBLIC_BASE` / `CENTRAL_BOOTSTRAP_SCRIPT_URL` | Pin raw URL for **compatibility wrappers** fetching **`bootstrap.sh`**. |

---

## Compatibility wrappers (bookmarks only)

These files contain **no installer logic**. They download **`bootstrap.sh`** and execute it so old links keep working:

- `control-install.sh`
- `scripts/public-droplet-bootstrap.sh`

**New automation and docs should use the `bootstrap.sh` URL only.**

---

## Legacy / history

Anything involving the old private monorepo, runner enrollment installers, or pre–Central “install modes” lives under **`legacy/`** and **`docs/legacy/`**. **Do not** use that material for new Central installs. Start here: **[`legacy/README.md`](legacy/README.md)**.

---

## Related

- **releasepanel-central** — [`README.md`](https://github.com/EdwardSoaresJr/releasepanel-central/blob/main/README.md), [`docs/FIRST-DEPLOY-SMOKE.md`](https://github.com/EdwardSoaresJr/releasepanel-central/blob/main/docs/FIRST-DEPLOY-SMOKE.md), [`docs/PRODUCTION-DEPLOYMENT.md`](https://github.com/EdwardSoaresJr/releasepanel-central/blob/main/docs/PRODUCTION-DEPLOYMENT.md).
- Optional: mirror **`bootstrap.sh`** from a stable URL you control (same bytes as this repo).
