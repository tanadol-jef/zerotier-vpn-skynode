# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Goal

Package ZeroTier VPN as an AuterionOS app so the Skynode S drone becomes a node on a ZeroTier overlay network, accessible remotely over the internet without port forwarding or static IPs.

## Prerequisites

- `auterion-cli` (`pip install auterion-cli`) — must run inside WSL2 on Windows
- Docker with buildx (cross-compilation to ARM64)
- A ZeroTier account with a network created
- Skynode S running AOS 3.5.3+ (compose-override merge support)
- `app-base-v2` installed on the Skynode S (required by `auterion-app-base: v2`)

## Configuration

Network ID is baked into the image at build time via `services/zerotier/networks.conf`:
```
60ee7c034ac89856
```

No `.env` file is needed.

## Critical manifest constraints

| Field | Value | Reason |
|---|---|---|
| `auterion-api-version` | `6` | api-version 7 causes install failure on Skynode S AOS 4.x |
| `auterion-app-base` | `v2` | Requires app-base-v2 on device |
| `target-platform` | `[skynode, skynode-s]` | Must be list form |
| `app-author` | `com.eosorbit.zerotier-vpn` | EOSOrbit branding |

## Build & Deploy (WSL2 only)

```bash
# Build for Skynode S (ARM64) — run inside WSL2
wsl -d Ubuntu-22.04 -e bash -c "cd /mnt/c/Users/jamba/Documents/Vibecode/zerotier-vpn && /home/pipo/.local/bin/auterion-cli app build"

# Install to Skynode S
wsl -d Ubuntu-22.04 -e bash -c "cd /mnt/c/Users/jamba/Documents/Vibecode/zerotier-vpn && /home/pipo/.local/bin/auterion-cli app install build/com.eosorbit.zerotier-vpn.zerotier-vpn-1.1.0.auterionos"
```

Use the `/rebuild-reinstall` slash command to run both steps automatically.

## Testing — Run in Stages

### Stage 1 — Local Docker

```bash
docker build --platform linux/amd64 -t zerotier-test services/zerotier

docker run --rm \
  --cap-add NET_ADMIN --cap-add SYS_ADMIN \
  --device /dev/net/tun \
  --network host \
  -v zerotier-test-data:/var/lib/zerotier-one \
  zerotier-test
```

Verify: logs show `200 join OK` and node appears at my.zerotier.com → Members.

### Stage 2 — Virtual Skynode

Build with `--simulation`, install via CLI or web UI at `http://10.41.200.2`.

### Stage 3 — Skynode S Hardware

SSH to `root@10.41.1.1` and verify:

```bash
zerotier-cli status          # → 200 info <node-id> <version> ONLINE
zerotier-cli listnetworks    # → network 60ee7c034ac89856 with status OK
ip addr show                 # → zt* interface present with a ZeroTier IP
```

After first deploy, authorize the node at my.zerotier.com → Networks → Members → tick Auth.

## Architecture

Single Docker service in `services/zerotier/`:

- **`auterion-app.yml`** — App manifest with `auterion-api-version: 6`, `auterion-app-base: v2`, compose-override (capabilities, devices, volumes, host network), and Auterion Suite parameters.
- **`Dockerfile`** — Extends the official `zerotier/zerotier` multi-arch image. Copies `networks.conf` and `entrypoint.sh`.
- **`networks.conf`** — ZeroTier network IDs to join (one per line), baked into the image at build time.
- **`entrypoint.sh`** — Starts `zerotier-one` daemon, joins all networks in `networks.conf`, loops every 60 s to auto-rejoin if status is not OK.

## What was done (session history)

### 2026-04-18 — Initial build & full setup session

**Discoveries & fixes (important for future work):**

1. **Build must run in WSL2** — `auterion-cli app build` fails from native Windows Git Bash because the packaging step uses Docker bind mounts with Linux paths. The fix: always call via `wsl -d Ubuntu-22.04 -e bash -c "..."` using the WSL binary at `/home/pipo/.local/bin/auterion-cli`.

2. **Windows encoding bug** — Running auterion-cli from Windows Python (not WSL) crashes with `UnicodeEncodeError: 'charmap' codec can't encode` when printing the pigz warning box. Workaround: `PYTHONIOENCODING=utf-8` or just use WSL.

3. **`auterion-api-version: 7` is broken on this device** — Every install with api-version 7 returned `Update module terminated abnormally: exit status 1`. Downgrading to `6` fixed it. Device is Skynode S running AOS v4.1.17, management API v2.2. The on-device Mender update module does not support api-version 7.

4. **`target-platform` must be a list** — `target-platform: skynode-s` (string) caused install failures. `target-platform: [skynode, skynode-s]` (list) works.

5. **`auterion-app-base: v2`** requires `app-base-v2` to be installed on the Skynode first (via Auterion Suite download). Using `none` skips this dependency but loses layer deduplication.

6. **Network ID moved from `.env` to `networks.conf`** — The original approach used `ZEROTIER_NETWORK_ID` env var. Refactored to bake the network ID into the image at build time via `services/zerotier/networks.conf`.

**Changes made:**
- `app-author` changed from `com.yourcompany.zerotier-vpn` → `com.eosorbit.zerotier-vpn`
- `auterion-api-version` fixed to `6`
- `auterion-app-base` set to `v2`
- `target-platform` changed to list `[skynode, skynode-s]`
- Added `parameters` block: `NETWORK_ID` (visible) and `REJOIN_INTERVAL_SEC` (advanced)
- Added `build-args.ZEROTIER_VERSION` and `ssh: false` to service
- Removed `.env`, `.env.example` (no longer needed)
- Created `CHANGELOG.md`
- Created GitHub release `v1.1.0` at https://github.com/tanadol-jef/zerotier-vpn-skynode/releases/tag/v1.1.0
- Added `/rebuild-reinstall` slash command at `.claude/commands/rebuild-reinstall.md`

**Device info:**
- Serial: `340816538`
- IP: `10.41.1.1`
- AOS: `v4.1.17`
- Management API: `v2.2`

---

## References

- [Auterion App Development](https://docs.auterion.com/app-development/app-development/application-development-1)
- [Compose Override](https://docs.auterion.com/app-development/app-framework/compose-override)
- [App Parameters](https://docs.auterion.com/app-development/app-framework/app-settings)
- [Virtual Skynode](https://docs.auterion.com/app-development/simulation/virtual-skynode)
- [ZeroTier Docker](https://docs.zerotier.com/docker/)
