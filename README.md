# releasepanel-bootstrap

**Public transport layer only.** This repo does **not** own ReleasePanel install semantics — it prepares the machine just enough to fetch the **authoritative toolkit** and execute **local scripts** from that checkout.

| Repo | Role |
|------|------|
| **`releasepanel-bootstrap`** (this) | Tiny, auditable **curl/bash transport**: deps → **clone** → **exec** scripts inside the checkout. |
| **`releasepanel-deploy`** | **Authoritative toolkit**: real bootstrap (`scripts/01-bootstrap.sh`), `self-update`, deploy/heal/runtime behavior — **inspect this repo for truth**. |
| **`releasepanel-runner`** | Public customer/agent bundle; **`runner.sh`** here delegates to **`install-managed-vps.sh`** there. |

**Legacy / history:** see **`legacy/`** and **`docs/legacy/`**.

---

## Hosted panel (control plane) — canonical one-liner

**Transport:** fetch **`install.sh`** → clone **`releasepanel-deploy`** → run **`scripts/01-bootstrap.sh`** from disk.

When **`bootstrap.releasepanel.com`** is wired (CDN → `install.sh`), preferred:

```bash
bash -c "$(curl -fsSL https://bootstrap.releasepanel.com/install.sh)"
```

Equivalent raw GitHub URL (always works if GitHub is reachable):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/install.sh)"
```

`wget` variant:

```bash
wget -qO- https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/install.sh | bash
```

**What `install.sh` does (and nothing else):**

1. Installs minimal packages: **`git`**, **`curl`**, **`ca-certificates`**, **`openssh-client`** (apt).
2. Clones or updates **[releasepanel-deploy](https://github.com/EdwardSoaresJr/releasepanel-deploy)** (SSH deploy key flow for private repo, or HTTPS if you set **`RELEASEPANEL_DEPLOY_REPO_HTTPS`**).
3. **`cd`** into that checkout and **`exec`** **`scripts/01-bootstrap.sh`** (all stack logic lives **there**).

It **does not** hide provisioning: PHP, nginx, MySQL wiring, migrations, and runners come from **`releasepanel-deploy`**.

**After the panel exists**, do **not** re-pipe `install.sh` for updates. Use the toolkit checkout:

```bash
cd /opt/releasepanel-deploy && git pull --ff-only origin main && sudo releasepanel self-update
```

**Repair / deliberate full re-bootstrap:** set **`RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN=true`** when invoking the transport or **`01-bootstrap.sh`** (see **`releasepanel-deploy`** docs).

### Options & env (`install.sh`)

| | |
|--|--|
| **`--dir PATH`** | Toolkit directory (default **`/opt/releasepanel-deploy`**). Must live under **`/opt/`**, no **`..`**. |
| **`--branch REF`** | Git branch (default **`main`**). |
| **`RELEASEPANEL_TOOLKIT_INSTALL_DIR`** / **`INSTALL_DIR`** | Same as **`--dir`**. |
| **`RELEASEPANEL_TOOLKIT_BRANCH`** | Same as **`--branch`**. |
| **`RELEASEPANEL_DEPLOY_REPO_SSH`** | SSH URL (default **`git@github.com:EdwardSoaresJr/releasepanel-deploy.git`**). |
| **`RELEASEPANEL_DEPLOY_REPO_HTTPS`** | If set, clone over HTTPS (credentials/token per **`git`**; no deploy key from this script). |
| **`RELEASEPANEL_DEPLOY_KEY_B64`** | Base64 private key for SSH clone (optional). |
| **`RELEASEPANEL_ASSUME_DEPLOY_KEY_ADDED=true`** | Skip “press Enter” after printing pubkey (non-interactive). |

Back-compat: **`bootstrap.sh`** with **`RELEASEPANEL_INSTALL_MODE=control`** (default) **`exec`**s **`install.sh`**. Older wrappers (**`control-install.sh`**, **`scripts/public-droplet-bootstrap.sh`**) download **`install.sh`**.

---

## Customer VPS (agent / workload host)

Canonical path is **`install-managed-vps.sh`** in **[releasepanel-runner](https://github.com/EdwardSoaresJr/releasepanel-runner)** (used by the panel UI). **`runner.sh`** here is a thin redirect:

```bash
RELEASEPANEL_PANEL_URL='https://your-panel.example.com' \
RELEASEPANEL_RUNNER_KEY='your-runner-key' \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/runner.sh)"
```

Override URL: **`RELEASEPANEL_MANAGED_VPS_INSTALL_URL`**.

Legacy: **`bootstrap.sh`** with **`RELEASEPANEL_INSTALL_MODE=runner`** still clones **`releasepanel-runner`** and runs **`toolkit/scripts/bootstrap-runner.sh`** locally (same idea: transport → local scripts).

---

## Private SSH clone (deploy key)

Without **`RELEASEPANEL_DEPLOY_KEY_B64`**, **`install.sh`** generates **`/root/.ssh/releasepanel_deploy`**, prints the **public** key, and waits for you to add it under the **`releasepanel-deploy`** repo → **Settings → Deploy keys** (read-only).

```text
https://github.com/EdwardSoaresJr/releasepanel-deploy/settings/keys
```

Non-interactive:

```bash
export RELEASEPANEL_DEPLOY_KEY_B64="$(base64 -i /path/to/private/key | tr -d '\n')"
curl -fsSL https://raw.githubusercontent.com/EdwardSoaresJr/releasepanel-bootstrap/main/install.sh | bash
```

---

## Idempotency & safety

- **`install.sh`** refuses to continue if **`/var/www/sites/releasepanel-app/production/current`** and **`shared/.env`** already exist (unless **`RELEASEPANEL_BOOTSTRAP_ALLOW_RERUN=true`**) — avoids mistaking transport for **`self-update`**.
- **`INSTALL_MODE=runner`** path updates **`releasepanel-runner`** and hands off to **`bootstrap-runner.sh`**; prefer **`runner.sh`** + **`install-managed-vps.sh`** for new servers.

---

## `bootstrap.releasepanel.com`

Host **`install.sh`** at this hostname (static hosting or redirect to raw GitHub) so operators have a short, stable URL. The file content must match this repo’s **`install.sh`** — **no** extra logic on the CDN beyond TLS + caching.
