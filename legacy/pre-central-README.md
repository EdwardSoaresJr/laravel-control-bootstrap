# Snapshot: README before releasepanel-central bootstrap (archival)

This is a copy of the **releasepanel-bootstrap** `README.md` from the **releasepanel-deploy** / **releasepanel-runner** era, preserved so historical links and operator notes stay understandable.

---

# ReleasePanel Bootstrap

Public bootstrap layer with two roles:

- **Master ReleasePanel server** — stand up the machine that **hosts** ReleasePanel for your customers (`INSTALL_MODE=control`).
- **Customer VPS** — connect a shop’s server to **their account** on your hosted ReleasePanel (**releasepanel-runner** `install-managed-vps.sh`, or legacy **`bootstrap.sh INSTALL_MODE=runner`**).

## Master server — ReleasePanel control plane (`INSTALL_MODE=control`, default)

Prepared Ubuntu to **SSH-clone** private **releasepanel-deploy** into `/opt/releasepanel-deploy`, then ran **`scripts/01-bootstrap.sh`**.

## Customer VPS — link to hosted ReleasePanel

Canonical installer: **`install-managed-vps.sh`** in **releasepanel-runner** (raw GitHub).

**`runner.sh`** in this repo curled **`install-managed-vps.sh`**.

(Full variable tables and one-liners were removed from the active README; see git history of **releasepanel-bootstrap** if needed.)

---

*End of archival snapshot.*
