# ReleasePanel Bootstrap

Public bootstrap layer for initial Laravel control server setup.

This repository is intentionally small. It prepares a fresh Ubuntu server just enough to clone the private `releasepanel-deploy` repository, then hands off to that private deploy system.

## One-Line Install

Run this on a fresh Ubuntu VPS as `root`:

```bash
export GITHUB_DEPLOY_KEY_B64="PASTE_BASE64_DEPLOY_KEY_HERE"

curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh | bash

unset GITHUB_DEPLOY_KEY_B64
```

## Create The Deploy Key

From your local machine:

```bash
ssh-keygen -t ed25519 -C "releasepanel-bootstrap" -f ~/.ssh/releasepanel_bootstrap -N ""
```

Copy the public key:

```bash
pbcopy < ~/.ssh/releasepanel_bootstrap.pub
```

Add it to the private deploy repo:

`releasepanel-deploy` > Settings > Deploy keys > Add deploy key

Use:

- Title: `releasepanel-bootstrap`
- Key: paste the public key
- Allow write access: unchecked

Then copy the base64-encoded private key:

```bash
base64 ~/.ssh/releasepanel_bootstrap | pbcopy
```

Paste the copied value into `GITHUB_DEPLOY_KEY_B64`.

## What This Does

`bootstrap.sh` only:

- Installs minimal dependencies: `git`, `curl`, `ca-certificates`, `openssh-client`
- Writes the GitHub deploy key to `/root/.ssh/releasepanel_bootstrap`
- Configures `/root/.ssh/config`
- Adds `github.com` to `/root/.ssh/known_hosts` with `ssh-keyscan`
- Verifies access to the private deploy repository
- Clones `git@github.com:EdwardSoaresJr/releasepanel-deploy.git` into `/opt/releasepanel-deploy`
- Runs `bash scripts/01-bootstrap.sh`

## What This Does Not Do

This repo does not:

- Install nginx, PHP, Redis, Supervisor, MySQL, or app dependencies
- Deploy applications
- Configure sites
- Call Laravel control CLI commands
- Modify control panel logic
- Store or embed secrets
- Prompt interactively

All real server setup belongs in the private `releasepanel-deploy` repo.

## Idempotency

The script is safe to rerun:

- If `/root/.ssh/releasepanel_bootstrap` already exists, it is not overwritten.
- If `/opt/releasepanel-deploy` already exists as a git repo, it is not recloned.
- Existing `github.com` entries in `known_hosts` are reused.

## Expected Result

After bootstrap completes:

- SSH access to GitHub is configured.
- `/opt/releasepanel-deploy` is present.
- `scripts/01-bootstrap.sh` has run.

The server is then ready for runner install and control-panel-driven deploys.
