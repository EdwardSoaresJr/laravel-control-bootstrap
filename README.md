# ReleasePanel Bootstrap

Public bootstrap layer for initial ReleasePanel server setup and customer runner installs.

This repository is intentionally small. Control-server mode prepares a fresh Ubuntu server just enough to clone the private `releasepanel-deploy` repository, then hands off to that deploy system. Runner-only mode uses the public `runner-bundle/` in this repo and never requires private repository access.

## One-Line Control Server Install

Run this on a fresh Ubuntu VPS as `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh | bash
```

This installs the ReleasePanel control server: system packages, runner, and the `releasepanel-app` UI/API.

## One-Line Runner-Only Install

Run this on a managed VPS that should be controlled by ReleasePanel but should not host the ReleasePanel UI:

```bash
RELEASEPANEL_PANEL_URL='https://app.releasepanel.com' \
RELEASEPANEL_RUNNER_KEY='paste-generated-runner-key' \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/runner.sh)"
```

Runner-only mode clones this public repo into `/opt/releasepanel-runner`, runs `runner-bundle/scripts/bootstrap-runner.sh`, writes `runner/.env` when `RELEASEPANEL_RUNNER_KEY` is provided, and skips the hosted `releasepanel-app` deployment entirely.

The deploy repo is private only for control-server installs. Bootstrap will generate an SSH deploy key, print the public key, and pause while you add it to the private `releasepanel-deploy` repo as a read-only deploy key.

GitHub deploy key page:

```text
https://github.com/EdwardSoaresJr/releasepanel-deploy/settings/keys
```

If you already have a private deploy key, pass it as base64:

```bash
export RELEASEPANEL_DEPLOY_KEY_B64="$(base64 -i /path/to/private/key | tr -d '\n')"
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh | bash
```

## What This Does

`bootstrap.sh` only:

- Installs minimal dependencies: `git`, `curl`, `ca-certificates`
- Installs `openssh-client`
- Creates or uses `/root/.ssh/releasepanel_deploy`
- Clones `git@github.com:EdwardSoaresJr/releasepanel-deploy.git` into `/opt/releasepanel-deploy` for control mode
- Clones this public repo into `/opt/releasepanel-runner` for runner-only mode
- Runs `bash scripts/01-bootstrap.sh` for control mode
- Runs `bash runner-bundle/scripts/bootstrap-runner.sh` for runner-only mode

## What This Does Not Do

This repo does not:

- Deploy the private ReleasePanel control app in runner-only mode
- Configure sites
- Store or embed secrets
- Change GitHub repo visibility
- Manage app repository deploy keys

The private `releasepanel-deploy` repo is only needed for the control server.

## Idempotency

The script is safe to rerun:

- If `/opt/releasepanel-deploy` already exists as a git repo, it is not recloned.
- If `/opt/releasepanel-runner` already exists as a git repo, it is not recloned.
- If `/root/.ssh/releasepanel_deploy` already exists, it is reused.

## Expected Result

After bootstrap completes:

- Control mode has `/opt/releasepanel-deploy` present.
- Runner-only mode has `/opt/releasepanel-runner` present.
- Control mode has run `scripts/01-bootstrap.sh`.
- Runner-only mode has run `runner-bundle/scripts/bootstrap-runner.sh`.

The server is then ready for runner install and ReleasePanel-driven deploys.
