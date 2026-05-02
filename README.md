# ReleasePanel Bootstrap

Public bootstrap layer for initial Laravel control server setup.

This repository is intentionally small. It prepares a fresh Ubuntu server just enough to clone the public `releasepanel-deploy` repository, then hands off to that deploy system.

## One-Line Install

Run this on a fresh Ubuntu VPS as `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh | bash
```

The deploy repo is public, so bootstrap has no GitHub auth, deploy key, base64, or token requirements.

## What This Does

`bootstrap.sh` only:

- Installs minimal dependencies: `git`, `curl`, `ca-certificates`
- Clones `https://github.com/EdwardSoaresJr/releasepanel-deploy.git` into `/opt/releasepanel-deploy`
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
- Manage app repository deploy keys

All real server setup belongs in the `releasepanel-deploy` repo.

## Idempotency

The script is safe to rerun:

- If `/opt/releasepanel-deploy` already exists as a git repo, it is not recloned.

## Expected Result

After bootstrap completes:

- `/opt/releasepanel-deploy` is present.
- `scripts/01-bootstrap.sh` has run.

The server is then ready for runner install and control-panel-driven deploys.
