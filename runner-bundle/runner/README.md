# ReleasePanel Runner Agent

Local-only Node.js service that lets ReleasePanel trigger safe, whitelisted platform operations without SSH.

The runner is not a public shell executor. It never accepts command strings from request bodies.

## Install

```bash
bash scripts/install-runner.sh
```

## Configure

```bash
nano /opt/releasepanel-runner/runner-bundle/runner/.env
```

Set a strong `RELEASEPANEL_RUNNER_KEY`.
Set `RELEASEPANEL_PANEL_URL` when this runner should heartbeat back to a ReleasePanel server.

## Test

```bash
curl -H "X-RELEASEPANEL-KEY: key" http://127.0.0.1:9000/health
curl -H "X-RELEASEPANEL-KEY: key" http://127.0.0.1:9000/status/demo-app/staging
curl -X POST -H "X-RELEASEPANEL-KEY: key" http://127.0.0.1:9000/runs/demo-app/staging/deploy
```

## Routes

- `GET /health`
- `GET /health/:site/:env`
- `GET /status/:site/:env`
- `POST /runs/:site/:env/:action`
- `POST /promote/:site/:fromEnv/:toEnv`
- `GET /ops/:site/:env/status`
- `GET /runs/:runId`
- `POST /api/runner-heartbeat` on the ReleasePanel app receives the runner heartbeat every `RELEASEPANEL_RUNNER_HEARTBEAT_MS`.

Allowed environments are discovered from `/opt/releasepanel-runner/runner-bundle/sites/{site}/{environment}.env`.

## Safety

- Binds only to `127.0.0.1`.
- Requires `X-RELEASEPANEL-KEY`.
- Uses a fixed command map only.
- Uses `child_process.spawn`.
- Does not use `shell: true`.
- Prevents simultaneous deploy/rollback actions per environment.
- Logs requests to `/var/log/releasepanel-runner.log`.

ReleasePanel will call this service from the same server or through a private network later. Do not expose this port publicly.
