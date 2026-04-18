# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Goal

Package ZeroTier VPN as an AuterionOS app so the Skynode S drone becomes a node on a ZeroTier overlay network, accessible remotely over the internet without port forwarding or static IPs.

## Prerequisites

- `auterion-cli` (`pip install auterion-cli`)
- Docker with buildx (cross-compilation to ARM64)
- A ZeroTier account with a network created
- Skynode S running AOS 3.5.3+ (required for compose-override merge support)

## Configuration

```bash
cp .env.example .env
# Set ZEROTIER_NETWORK_ID=<16-char id from my.zerotier.com -> Networks>
```

Network ID in use: `60ee7c034ac89856`

## Build & Deploy Commands

```bash
# Load env vars before any auterion-cli command
export $(cat .env | xargs)

# Build for Skynode S (ARM64)
auterion-cli app build
auterion-cli app install build/*.auterionos

# Build for Virtual Skynode (amd64 simulation)
auterion-cli app build --simulation
auterion-cli app install build/*-simulation.auterionos
```

## Testing — Run in Stages

### Stage 1 — Local Docker (fastest, no Auterion tooling)

```bash
docker build --platform linux/amd64 -t zerotier-test services/zerotier

docker run --rm \
  --cap-add NET_ADMIN --cap-add SYS_ADMIN \
  --device /dev/net/tun \
  --network host \
  -v zerotier-test-data:/var/lib/zerotier-one \
  -e ZEROTIER_NETWORK_ID=60ee7c034ac89856 \
  zerotier-test
```

Verify: logs show `200 join OK` and node appears at my.zerotier.com → Members.

### Stage 2 — Virtual Skynode

Build with `--simulation`, install via CLI or web UI at `http://10.41.200.2`. Confirm app survives reboot.

### Stage 3 — Skynode S Hardware

Build normally, install, then SSH in to verify:

```bash
zerotier-cli status          # → 200 info <node-id> <version> ONLINE
zerotier-cli listnetworks    # → network 60ee7c034ac89856 with status OK
ip addr show                 # → zt* interface present with a ZeroTier IP
```

After first deploy, authorize the node at my.zerotier.com → Networks → Members → tick Auth.

## Architecture

The entire app is a single Docker service (`services/zerotier/`):

- **`auterion-app.yml`** — App manifest; defines the service, build args, and `compose-override` (capabilities, devices, volumes, network mode). `compose-override` properties are merged (not replaced) on AOS 3.5.3+.
- **`Dockerfile`** — Extends the official `zerotier/zerotier` multi-arch image (ARM64-native). Copies `entrypoint.sh` and declares the identity volume.
- **`entrypoint.sh`** — Starts `zerotier-one` daemon, joins the network from `ZEROTIER_NETWORK_ID`, and loops every 60 seconds to auto-rejoin if status is not `OK`. Falls back to creating `/dev/net/tun` manually if the device is missing.

### Critical runtime permissions (compose-override)

| Setting | Reason |
|---|---|
| `cap_add: NET_ADMIN, SYS_ADMIN` | Create/manage TUN interfaces |
| `devices: /dev/net/tun` | Kernel TUN device access |
| `network_mode: host` | ZeroTier interface is on the drone's host network stack |
| `volumes: zerotier-data` | Persists node identity across reboots (same ZeroTier IP) |

## References

- [Auterion App Development](https://docs.auterion.com/app-development/app-development/application-development-1)
- [Compose Override](https://docs.auterion.com/app-development/app-framework/compose-override)
- [Virtual Skynode](https://docs.auterion.com/app-development/simulation/virtual-skynode)
- [ZeroTier Docker](https://docs.zerotier.com/docker/)
