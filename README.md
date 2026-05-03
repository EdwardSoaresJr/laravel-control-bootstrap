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

```bash
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh | bash
```

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

## Idempotency

Safe to rerun: existing **releasepanel-runner** checkout is **pulled**; bootstrap re-runs from **`toolkit/scripts/bootstrap-runner.sh`**.
