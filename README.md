# Laravel Control Bootstrap

Public bootstrap layer for initial Laravel control server setup.

This repository is intentionally small. It prepares a fresh Ubuntu server just enough to clone the private `arksms-server-deploy` repository, then hands off to that private deploy system.

## One-Line Install

Run this on a fresh Ubuntu VPS as `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/laravel-control-bootstrap/main/bootstrap.sh | \
  GITHUB_DEPLOY_KEY_B64="PASTE_BASE64_DEPLOY_KEY_HERE" bash
```

## Create The Base64 Deploy Key

From your local machine:

```bash
base64 -i ~/.ssh/arksms_deploy_key | pbcopy
```

Paste the copied value into `GITHUB_DEPLOY_KEY_B64`.

## What This Does

`bootstrap.sh` only:

- Installs minimal dependencies: `git`, `curl`, `ca-certificates`, `openssh-client`
- Writes the GitHub deploy key to `/root/.ssh/arksms_deploy`
- Configures `/root/.ssh/config`
- Adds `github.com` to `/root/.ssh/known_hosts` with `ssh-keyscan`
- Verifies access to the private deploy repository
- Clones `git@github.com:EdwardSoaresJr/arksms-server-deploy.git` into `/opt/arksms/arksms-server-deploy`
- Runs `bash scripts/01-bootstrap.sh`

## What This Does Not Do

This repo does not:

- Install nginx, PHP, Redis, Supervisor, MySQL, or app dependencies
- Deploy applications
- Configure sites
- Call ARK-SMS CLI commands
- Modify control panel logic
- Store or embed secrets
- Prompt interactively

All real server setup belongs in the private `arksms-server-deploy` repo.

## Idempotency

The script is safe to rerun:

- If `/root/.ssh/arksms_deploy` already exists, it is not overwritten.
- If `/opt/arksms/arksms-server-deploy` already exists as a git repo, it is not recloned.
- Existing `github.com` entries in `known_hosts` are reused.

## Expected Result

After bootstrap completes:

- SSH access to GitHub is configured.
- `/opt/arksms/arksms-server-deploy` is present.
- `scripts/01-bootstrap.sh` has run.

The server is then ready for runner install and control-panel-driven deploys.
