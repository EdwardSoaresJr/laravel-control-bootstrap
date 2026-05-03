# ReleasePanel Bootstrap

Public bootstrap layer for **control-server** and **managed runner** installs.

## Control server (`INSTALL_MODE=control`, default)

Prepares Ubuntu just enough to **SSH-clone** private **[releasepanel-deploy](https://github.com/EdwardSoaresJr/releasepanel-deploy)** into `/opt/releasepanel-deploy`, then runs **`scripts/01-bootstrap.sh`** (full panel stack).

Generates a deploy key unless you pass **`RELEASEPANEL_DEPLOY_KEY_B64`**.

## Managed runner (`INSTALL_MODE=runner`)

Used by the ReleasePanel UI **Bootstrap command** (sets this mode). **No** deploy key:

1. **`git clone`** **[releasepanel-deploy](https://github.com/EdwardSoaresJr/releasepanel-deploy)** via **anonymous HTTPS** → `/opt/releasepanel-deploy` (repo **must** be public or use **`RELEASEPANEL_RUNNER_PUBLIC_TOOLKIT_URL`** pointing at another **publicly** cloneable mirror — no passwords, no prompts).
2. **`git clone`** **[releasepanel-runner](https://github.com/EdwardSoaresJr/releasepanel-runner)** → `/opt/releasepanel-runner` (same rules: public HTTPS only unless you set **`RELEASEPANEL_RUNNER_REPO_HTTPS`** to another public URL).
3. **`runner/`** in the toolkit is replaced with a **symlink** to `/opt/releasepanel-runner`.
4. Runs **`/opt/releasepanel-deploy/scripts/bootstrap-runner.sh`** (system packages via **`01-bootstrap.sh`** with **`RELEASEPANEL_SKIP_APP_BOOTSTRAP`**, **`install-runner.sh`**, optional **`register-server.sh`**).

## One-line control server

```bash
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh | bash
```

## One-line runner-only (paste panel URL + key)

```bash
RELEASEPANEL_PANEL_URL='https://app.releasepanel.com' \
RELEASEPANEL_RUNNER_KEY='paste-generated-runner-key' \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/runner.sh)"
```

`runner.sh` forces **`RELEASEPANEL_INSTALL_MODE=runner`**.

## Deploy key (control mode only)

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
| `RELEASEPANEL_INSTALL_MODE` | `control` (default) or `runner` |
| `RELEASEPANEL_RUNNER_PUBLIC_TOOLKIT_URL` | Optional **public** HTTPS URL for the deploy toolkit (default: `EdwardSoaresJr/releasepanel-deploy`). **`RELEASEPANEL_DEPLOY_REPO_HTTPS` is ignored in runner mode** — runner installs never use authenticated git URLs. |
| `RELEASEPANEL_RUNNER_REPO_HTTPS` | Runner agent git URL (default: public `releasepanel-runner`) |
| `RELEASEPANEL_BOOTSTRAP_URL` | Used by `runner.sh` to fetch `bootstrap.sh` |

## Idempotency

Safe to rerun: existing git checkouts are **pulled**; **`runner/`** symlink is recreated.
