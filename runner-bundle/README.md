# ReleasePanel Runner Bundle

Public managed-server bundle for ReleasePanel.

This directory intentionally excludes the private `releasepanel-app` control UI/API. It contains only the runner agent, deploy CLI, systemd service template, and deployment scripts needed on a customer-managed VPS.

Install through the public bootstrap:

```bash
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/bootstrap.sh | \
  RELEASEPANEL_INSTALL_MODE=runner \
  RELEASEPANEL_RUNNER_KEY='paste-generated-runner-key' \
  bash
```
