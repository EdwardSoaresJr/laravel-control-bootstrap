# Legacy bootstrap (pre–releasepanel-central)

Contents here are **archived** for history and **must not** be used for new **releasepanel-central** installs.

**`releasepanel-deploy`** (the private repo these scripts targeted) is **legacy architecture** — **replaced** by **`releasepanel-central`**. See **releasepanel-central** `docs/legacy/README.md` for terminology.

| File | Era |
|------|-----|
| `old-bootstrap.sh` | Cloned **releasepanel-deploy** (legacy). **Operational mechanics** are ported literally into repo-root **`bootstrap.sh`** for **releasepanel-central** (root, apt, SSH config, deploy key, clone, rerun guard, **`bootstrap-central.sh`** handoff). |
| `runner.sh` | Fetched **releasepanel-runner** `install-managed-vps.sh` for customer VPS enrollment. |

New architecture:

- **Public:** `releasepanel-bootstrap` → **`bootstrap.sh`** (self-contained). **`control-install.sh`** / **`scripts/public-droplet-bootstrap.sh`** fetch **`bootstrap.sh`** for old URLs.
- **Private:** `releasepanel-central` → `scripts/bootstrap-central.sh` → `verify-central.sh`

See **`old-runner-flow-notes.md`** and **`pre-central-README.md`** for the prior operator-facing documentation snapshot.
