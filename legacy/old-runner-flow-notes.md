# Legacy runner / managed VPS flow (archival)

The former **customer VPS** path used:

1. **`legacy/runner.sh`** in **releasepanel-bootstrap** — thin `curl` of **`install-managed-vps.sh`** from **[releasepanel-runner](https://github.com/EdwardSoaresJr/releasepanel-runner)** (URL overridable via **`RELEASEPANEL_MANAGED_VPS_INSTALL_URL`**).
2. **`bootstrap.sh` with `INSTALL_MODE=runner`** — cloned public **releasepanel-runner** and ran **`toolkit/services/... bootstrap-runner.sh`** (exact path varied by runner repo layout).

Environment examples from that era: **`RELEASEPANEL_PANEL_URL`**, **`RELEASEPANEL_SERVER_ID`**, **`RELEASEPANEL_RUNNER_KEY`**.

**Current** ReleasePanel separates:

- **Central control plane** — provisioned only via **releasepanel-central** + this repo’s public acquisition scripts.
- **Agent runtime** — **releasepanel-agent** (private for now); enrollment is **not** defined in **releasepanel-bootstrap** anymore.

Do not treat this document as an install guide for new infrastructure.
