# ReleasePanel Runner Bundle

Public managed-server bundle for ReleasePanel.

This directory intentionally excludes the private `releasepanel-app` control UI/API. It contains only the runner agent, deploy CLI, systemd service template, and deployment scripts needed on a customer-managed VPS.

Install through the public bootstrap:

```bash
RELEASEPANEL_PANEL_URL='https://app.releasepanel.com' \
RELEASEPANEL_RUNNER_KEY='paste-generated-runner-key' \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/runner.sh)"
```
