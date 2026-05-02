# Laravel Control Bootstrap

Public bootstrap layer for initial Laravel control server setup.

This repository is intentionally small. It prepares a fresh Ubuntu server just enough to clone the private `laravel-control-deploy` repository, then hands off to that private deploy system.

## One-Line Install

Run this on a fresh Ubuntu VPS as `root`:

```bash
export GITHUB_DEPLOY_KEY_B64="PASTE_BASE64_DEPLOY_KEY_HERE"

curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/laravel-control-bootstrap/main/bootstrap.sh | bash

unset GITHUB_DEPLOY_KEY_B64
```

## Create The Deploy Key

From your local machine:

```bash
ssh-keygen -t ed25519 -C "laravel-control-bootstrap" -f ~/.ssh/laravel_control_bootstrap -N ""
```

Copy the public key:

```bash
pbcopy < ~/.ssh/laravel_control_bootstrap.pub
```

Add it to the private deploy repo:

`laravel-control-deploy` > Settings > Deploy keys > Add deploy key

Use:

- Title: `laravel-control-bootstrap`
- Key: paste the public key
- Allow write access: unchecked

Then copy the base64-encoded private key:

```bash
base64 ~/.ssh/laravel_control_bootstrap | pbcopy
```

Paste the copied value into `GITHUB_DEPLOY_KEY_B64`.

## What This Does

`bootstrap.sh` only:

- Installs minimal dependencies: `git`, `curl`, `ca-certificates`, `openssh-client`
- Writes the GitHub deploy key to `/root/.ssh/laravel_control_bootstrap`
- Configures `/root/.ssh/config`
- Adds `github.com` to `/root/.ssh/known_hosts` with `ssh-keyscan`
- Verifies access to the private deploy repository
- Clones `git@github.com:EdwardSoaresJr/laravel-control-deploy.git` into `/opt/laravel-control/laravel-control-deploy`
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

All real server setup belongs in the private `laravel-control-deploy` repo.

## Idempotency

The script is safe to rerun:

- If `/root/.ssh/laravel_control_bootstrap` already exists, it is not overwritten.
- If `/opt/laravel-control/laravel-control-deploy` already exists as a git repo, it is not recloned.
- Existing `github.com` entries in `known_hosts` are reused.

## Expected Result

After bootstrap completes:

- SSH access to GitHub is configured.
- `/opt/laravel-control/laravel-control-deploy` is present.
- `scripts/01-bootstrap.sh` has run.

The server is then ready for runner install and control-panel-driven deploys.
