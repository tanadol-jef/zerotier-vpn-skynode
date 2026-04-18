# ZeroTier VPN — Auterion OS App for Skynode S

## Project Goal
Package ZeroTier VPN as an AuterionOS app so the Skynode S drone becomes a node on a ZeroTier overlay network, accessible remotely over the internet.

## App Structure
```
zerotier-vpn/
├── auterion-app.yml          # App manifest (name, version, services, compose-override)
├── .env.example              # ZEROTIER_NETWORK_ID template
└── services/zerotier/
    ├── Dockerfile            # Based on official zerotier/zerotier (ARM64-compatible)
    └── entrypoint.sh         # Starts daemon, joins network, auto-rejoins on drop
```

## Key Design Decisions

### Runtime permissions (compose-override)
ZeroTier requires elevated Linux capabilities to create virtual TUN interfaces:
- `cap_add: [NET_ADMIN, SYS_ADMIN]` — create/manage TUN interfaces
- `devices: /dev/net/tun` — kernel TUN device access
- `network_mode: host` — ZeroTier interface is on the drone's host network stack, not isolated inside the container
- `volumes: zerotier-data` — persists ZeroTier node identity (`/var/lib/zerotier-one`) across reboots so the drone keeps the same ZeroTier IP

### Base image
Uses the official `zerotier/zerotier` Docker image which is multi-arch and supports `linux/arm64` (Skynode S).

### Network ID injection
`ZEROTIER_NETWORK_ID` is passed as an environment variable at build and runtime. Set it in `.env` before building.

### Auto-rejoin logic
`entrypoint.sh` checks `zerotier-cli listnetworks` every 60 seconds and re-runs `join` if the network status is not `OK`.

## Configuration
```bash
cp .env.example .env
# Edit .env and set your 16-character ZeroTier network ID:
# ZEROTIER_NETWORK_ID=<from https://my.zerotier.com -> Networks>
```

Network ID in use: `60ee7c034ac89856`

## Build & Deploy

### Build for Skynode S (ARM64)
```bash
export $(cat .env | xargs)
auterion-cli app build
# Output: build/*.auterionos
```

### Deploy to device
```bash
auterion-cli app install build/*.auterionos
```

### Build for Virtual Skynode (amd64)
```bash
auterion-cli app build --simulation
auterion-cli app install build/*-simulation.auterionos
```

## Testing Strategy

### Stage 1 — Local Docker (fastest, no Auterion tooling needed)
```bash
docker build --platform linux/amd64 -t zerotier-test services/zerotier

docker run --rm \
  --cap-add NET_ADMIN \
  --cap-add SYS_ADMIN \
  --device /dev/net/tun \
  --network host \
  -v zerotier-test-data:/var/lib/zerotier-one \
  -e ZEROTIER_NETWORK_ID=60ee7c034ac89856 \
  zerotier-test
```
Verify: node appears in https://my.zerotier.com and logs show `200 join OK`.

### Stage 2 — Virtual Skynode (full AuterionOS, amd64 via QEMU)
- Build with `--simulation` flag
- Install via `auterion-cli app install` or web UI at `http://10.41.200.2`
- Confirm app survives reboot and `network_mode: host` exposes the ZeroTier interface to the host

### Stage 3 — Skynode S hardware (final)
- Build normally (ARM64 target)
- Install via CLI or Auterion Suite
- Authorize the node at https://my.zerotier.com (Members tab → tick the auth checkbox)

## Post-Deploy Verification
```bash
# SSH into Skynode S, then:
zerotier-cli status          # should show: 200 info <node-id> <version> ONLINE
zerotier-cli listnetworks    # should show network 60ee7c034ac89856 with status OK
ip addr show                 # should list a zt* interface with a ZeroTier IP
```

## Auterion OS App Conventions
- Manifest file: `auterion-app.yml` at project root
- Services are Docker containers; `build:` points to directory containing `Dockerfile`
- `compose-override` supports all standard Docker Compose service properties
- On AOS >= 3.5.3, compose-override properties are merged (not overwritten)
- `auterion-cli` wraps `docker build` under the hood; can debug with `docker build --platform=linux/arm64` directly

## References
- [Auterion App Development](https://docs.auterion.com/app-development/app-development/application-development-1)
- [Compose Override](https://docs.auterion.com/app-development/app-framework/compose-override)
- [Virtual Skynode](https://docs.auterion.com/app-development/simulation/virtual-skynode)
- [ZeroTier Docker](https://docs.zerotier.com/docker/)
- [ZeroTier Networks](https://my.zerotier.com)
