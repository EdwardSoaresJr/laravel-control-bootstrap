# ReleasePanel Bootstrap

Public bootstrap layer with two roles:

- **Master ReleasePanel server** — stand up the machine that **hosts** ReleasePanel for your customers (`INSTALL_MODE=control`).
- **Customer VPS** — connect a shop’s server to **their account** on your hosted ReleasePanel (**[releasepanel-runner](https://github.com/EdwardSoaresJr/releasepanel-runner)** `install-managed-vps.sh`, or legacy **`bootstrap.sh INSTALL_MODE=runner`**).

## Master server — ReleasePanel control plane (`INSTALL_MODE=control`, default)

Prepares Ubuntu just enough to **SSH-clone** private **[releasepanel-deploy](https://github.com/EdwardSoaresJr/releasepanel-deploy)** into `/opt/releasepanel-deploy`, then runs **`scripts/01-bootstrap.sh`** (full panel stack). **releasepanel-deploy** is **your** toolkit to provision the **master** server, not something customers run on their app VPSes.

Generates a deploy key unless you pass **`RELEASEPANEL_DEPLOY_KEY_B64`**.

## Customer VPS — link to hosted ReleasePanel

Canonical installer: **`install-managed-vps.sh`** in **[releasepanel-runner](https://github.com/EdwardSoaresJr/releasepanel-runner)** (raw GitHub). **No** deploy key.

1. Installs `git` / `curl`, then **`git clone`** public **releasepanel-runner** → `/opt/releasepanel-runner`.
2. Runs **`toolkit/scripts/bootstrap-runner.sh`**.

The ReleasePanel UI **Bootstrap command** uses that raw URL with env vars (`RELEASEPANEL_PANEL_URL`, `RELEASEPANEL_SERVER_ID`, `RELEASEPANEL_RUNNER_KEY`).

**`runner.sh`** in this repo is optional: it `curl`s **`install-managed-vps.sh`** (override with **`RELEASEPANEL_MANAGED_VPS_INSTALL_URL`**).

**`bootstrap.sh` with `INSTALL_MODE=runner`** remains supported as an alternate entrypoint (same clone + handoff).

Anonymous HTTPS only; use **`RELEASEPANEL_RUNNER_REPO_HTTPS`** only for a **public** mirror of **releasepanel-runner**.

## One-line master server (your ReleasePanel host)

**First install only.** After ReleasePanel exists under `/var/www/sites/releasepanel-app/production`, **do not** re-pipe this script for updates — it is **not** `self-update` and will re-run the full stack bootstrap.

```bash
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh | bash
```

**Updates (already installed):**

```bash
cd /opt/releasepanel-deploy && git pull --ff-only origin main && sudo releasepanel self-update
```

**Intentional repair re-bootstrap:** `RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN=true` with the same curl (rare; expect stack scripts to run again).

## One-line customer VPS (paste panel URL + runner key)

```bash
RELEASEPANEL_PANEL_URL='https://app.releasepanel.com' \
RELEASEPANEL_RUNNER_KEY='paste-generated-runner-key' \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/runner.sh)"
```

`runner.sh` downloads **`install-managed-vps.sh`** from **releasepanel-runner** (not **`bootstrap.sh`**).

## Deploy key (master server / `control` mode only)

```text
https://github.com/EdwardSoaresJr/releasepanel-deploy/settings/keys
```

```bash
export RELEASEPANEL_DEPLOY_KEY_B64="$(base64 -i /path/to/private/key | tr -d '\n')"
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh | bash
```

## Overrides

| Variable | Purpose |
|----------|---------|
| `RELEASEPANEL_INSTALL_MODE` | `control` = **your** master ReleasePanel host; `runner` = legacy customer path inside **`bootstrap.sh`** (prefer **`install-managed-vps.sh`** from **releasepanel-runner**) |
| `RELEASEPANEL_RUNNER_REPO_HTTPS` | **releasepanel-runner** git URL (default: public `EdwardSoaresJr/releasepanel-runner`) |
| `RELEASEPANEL_MANAGED_VPS_INSTALL_URL` | Used by **`runner.sh`** to fetch **`install-managed-vps.sh`** (default: **releasepanel-runner** raw URL) |
| `RELEASEPANEL_BOOTSTRAP_URL` | Legacy; **`control`** mode one-liner only |
| `RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN` | Set `true` so **`control`** one-liner, **`01-bootstrap.sh`**, or **`bootstrap-releasepanel.sh`** may run again after the panel exists (repair / you accept a full stack re-run) |
| `RELEASEPANEL_BOOTSTRAP_APT_UPGRADE` | On the server: set `true` with **`01-bootstrap.sh`** to run **`apt upgrade`** even when the stack was provisioned before (default skips repeat full upgrades) |
| `RELEASEPANEL_BOOTSTRAP_SKIP_APT_UPGRADE` | Set `true` to skip **`apt upgrade`** even on first bootstrap (advanced) |

## Idempotency

- **`INSTALL_MODE=runner`:** Pulling **releasepanel-runner** and re-running **`bootstrap-runner.sh`** is the intended path; still prefer **`install-managed-vps.sh`** from the panel for new servers.
- **`INSTALL_MODE=control`:** The one-liner **refuses** to continue if the panel tree already exists, so you don’t accidentally full-stack bootstrap on every update. On the server, **`01-bootstrap.sh`** and **`bootstrap-releasepanel.sh`** also refuse a second full install unless **`RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN=true`** (or **`RELEASEPANEL_BOOTSTRAP_FORCE_FRESH=true`** for advanced reprovision); a marker is written to **`/var/lib/releasepanel/bootstrap-complete`** when the installer finishes. Use **`releasepanel self-update`** for routine code sync.
