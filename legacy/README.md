# Legacy (pre–releasepanel-central)

**Quarantine:** everything below is **historical**. **Do not** use for new **releasepanel-central** installs.

The **only** supported acquisition path for Central is the repository root **`README.md`**: **`bootstrap.sh`** (`curl` one-liner there).

---

## What is in this folder

| File | What it was (historical) |
|------|---------------------------|
| `old-bootstrap.sh` | Installed the **former** private **`releasepanel-deploy`** monorepo and called **`scripts/01-bootstrap.sh`**. The **mechanics** (root, apt, deploy key, SSH config, clone, handoff) were ported into repo-root **`bootstrap.sh`**, which targets **`releasepanel-central`** and **`bootstrap-central.sh`** instead. |
| `runner.sh` | Old entry to **`releasepanel-runner`** customer-VPS enrollment. **Not** the Central control-plane install. |
| `pre-central-README.md`, `old-runner-flow-notes.md` | Operator doc snapshots from before Central. |

Terminology for the old monorepo: see **releasepanel-central** [`docs/legacy/`](https://github.com/EdwardSoaresJr/releasepanel-central/tree/main/docs/legacy).

---

## Where to go instead

| Goal | Where |
|------|--------|
| Install Central today | Root [**`../README.md`**](../README.md) |
| Central operations | **releasepanel-central** repo |

**Compatibility only** (same as **`bootstrap.sh`**, no separate logic): `control-install.sh`, `scripts/public-droplet-bootstrap.sh` at repo root.
