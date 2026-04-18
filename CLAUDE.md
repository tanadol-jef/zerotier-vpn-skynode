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

## References

- [Auterion App Development](https://docs.auterion.com/app-development/app-development/application-development-1)
- [Compose Override](https://docs.auterion.com/app-development/app-framework/compose-override)
- [App Parameters](https://docs.auterion.com/app-development/app-framework/app-settings)
- [Virtual Skynode](https://docs.auterion.com/app-development/simulation/virtual-skynode)
- [ZeroTier Docker](https://docs.zerotier.com/docker/)
