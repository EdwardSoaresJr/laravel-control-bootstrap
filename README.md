# ReleasePanel Bootstrap

Public bootstrap layer for initial ReleasePanel server setup.

This repository is intentionally small. It prepares a fresh Ubuntu server just enough to clone the private `releasepanel-deploy` repository, then hands off to that deploy system.

## One-Line Install

Run this on a fresh Ubuntu VPS as `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh | bash
```

The deploy repo is private. Bootstrap will generate an SSH deploy key, print the public key, and pause while you add it to the private `releasepanel-deploy` repo as a read-only deploy key.

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
- Clones `git@github.com:EdwardSoaresJr/releasepanel-deploy.git` into `/opt/releasepanel-deploy`
- Runs `bash scripts/01-bootstrap.sh`

## What This Does Not Do

This repo does not:

- Install nginx, PHP, Redis, Supervisor, MySQL, or app dependencies
- Deploy applications
- Configure sites
- Call ReleasePanel deploy CLI commands
- Modify ReleasePanel deploy logic
- Store or embed secrets
- Change GitHub repo visibility
- Manage app repository deploy keys

All real server setup belongs in the `releasepanel-deploy` repo.

## Idempotency

The script is safe to rerun:

- If `/opt/releasepanel-deploy` already exists as a git repo, it is not recloned.
- If `/root/.ssh/releasepanel_deploy` already exists, it is reused.

## Expected Result

After bootstrap completes:

- `/opt/releasepanel-deploy` is present.
- `scripts/01-bootstrap.sh` has run.

The server is then ready for runner install and ReleasePanel-driven deploys.
