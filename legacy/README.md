# Legacy bootstrap (pre–releasepanel-central)

Contents here are **archived** for history and **must not** be used for new **releasepanel-central** installs.

**`releasepanel-deploy`** (the private repo these scripts targeted) is **legacy architecture** — **replaced** by **`releasepanel-central`**. See **releasepanel-central** `docs/legacy/README.md` for terminology.

| File | Era |
|------|-----|
| `old-bootstrap.sh` | Cloned private **releasepanel-deploy** (legacy), ran `scripts/01-bootstrap.sh`, `INSTALL_MODE=control` or `runner`. Its **operational patterns** (root-first droplet, hardened apt, deploy-key + `~/.ssh/config`, rerun guard) are **ported** into **`../scripts/public-droplet-bootstrap.sh`** for **releasepanel-central**. |
| `runner.sh` | Fetched **releasepanel-runner** `install-managed-vps.sh` for customer VPS enrollment. |

New architecture:

- **Public:** `releasepanel-bootstrap` → `control-install.sh` → `scripts/public-droplet-bootstrap.sh`
- **Private:** `releasepanel-central` → `scripts/bootstrap-central.sh` → `verify-central.sh`

See **`old-runner-flow-notes.md`** and **`pre-central-README.md`** for the prior operator-facing documentation snapshot.
