# ZeroTier VPN — Auterion OS App for Skynode S

An [AuterionOS](https://auterion.com) app that connects your [Skynode S](https://auterion.com/product/skynode-s/) drone to a [ZeroTier](https://www.zerotier.com) overlay network, enabling secure remote access over any internet connection without port forwarding or static IPs.

---

## How it works

The app runs the ZeroTier One daemon as a Docker service on AuterionOS. Using `network_mode: host`, the ZeroTier virtual interface (`ztXXXXXX`) is created directly on the drone's host network stack — so any service on the drone (MAVLink, video stream, SSH, etc.) becomes reachable via its ZeroTier IP.

---

## Prerequisites

- [Auterion CLI](https://docs.auterion.com/app-development/resources/auterion-cli) (`pip install auterion-cli`)
- Docker with buildx (for cross-compilation to ARM64)
- A [ZeroTier account](https://my.zerotier.com) with a network created
- Skynode S running AOS 3.5.3 or later (for compose-override merge support)

---

## Configuration

Edit `services/zerotier/networks.conf` and add your ZeroTier Network ID (one per line):

```
60ee7c034ac89856
```

Find your Network ID at [my.zerotier.com](https://my.zerotier.com) → Networks.

The network ID is baked into the Docker image at build time — no environment variables are required.

To join multiple networks, add each ID on its own line:

```
60ee7c034ac89856
8056c2e21c000001
```

---

## Build & Deploy

### On Linux / WSL (recommended)

```bash
# Build for Skynode S (ARM64)
auterion-cli app build
auterion-cli app install build/*.auterionos
```

> **Windows note:** Run these commands inside WSL2. The `auterion-cli` packaging step uses Docker bind mounts with Linux paths and will fail if run from a native Windows shell.

---

## Testing

Always test in stages before deploying to hardware.

### Stage 1 — Local Docker (no Auterion tooling required)

The fastest way to verify the ZeroTier daemon starts and joins your network:

```bash
docker build --platform linux/amd64 -t zerotier-test services/zerotier

docker run --rm \
  --cap-add NET_ADMIN \
  --cap-add SYS_ADMIN \
  --device /dev/net/tun \
  --network host \
  -v zerotier-test-data:/var/lib/zerotier-one \
  zerotier-test
```

**What to check:**
- Logs show `200 join OK`
- The node appears in [my.zerotier.com](https://my.zerotier.com) → Members

### Stage 2 — Virtual Skynode (full AuterionOS environment)

[Virtual Skynode](https://docs.auterion.com/app-development/simulation/virtual-skynode) runs AuterionOS in a VM, giving you the closest experience to real hardware without the physical device.

```bash
# Build a simulation artifact (targets amd64)
auterion-cli app build --simulation

# Install on Virtual Skynode
auterion-cli app install build/*-simulation.auterionos
```

Or open the Virtual Skynode web UI at `http://10.41.200.2` → Dashboard → Install Software.

**What to check:**
- App shows as running in the web UI
- App survives a Virtual Skynode reboot
- ZeroTier node appears online at [my.zerotier.com](https://my.zerotier.com)

### Stage 3 — Skynode S hardware (final)

```bash
auterion-cli app build
auterion-cli app install build/*.auterionos
```

**Post-deploy verification** (SSH into Skynode S at `root@10.41.1.1`):
```bash
zerotier-cli status          # → 200 info <node-id> <version> ONLINE
zerotier-cli listnetworks    # → shows your network with status OK
ip addr show                 # → lists a zt* interface with a ZeroTier IP
```

---

## Authorizing the drone on your ZeroTier network

After the app starts, the drone will appear as a new member in your ZeroTier network but traffic will be blocked until you authorize it:

1. Go to [my.zerotier.com](https://my.zerotier.com) → your network → **Members**
2. Find the new node (matched by Node ID shown in `zerotier-cli status`)
3. Tick the **Auth** checkbox

The drone will receive a ZeroTier IP and become reachable from any other authorized device on the network.

---

## Project structure

```
zerotier-vpn/
├── auterion-app.yml          # App manifest: services, capabilities, volumes
└── services/zerotier/
    ├── Dockerfile            # Built from official zerotier/zerotier (ARM64-compatible)
    ├── networks.conf         # ZeroTier network IDs to join (one per line)
    └── entrypoint.sh         # Starts daemon, joins networks, auto-rejoins on drop
```

---

## Key runtime permissions

| Setting | Reason |
|---|---|
| `cap_add: NET_ADMIN, SYS_ADMIN` | Required to create and manage TUN interfaces |
| `devices: /dev/net/tun` | Exposes the kernel TUN device to the container |
| `network_mode: host` | ZeroTier interface is visible to the whole drone, not just the container |
| `volumes: zerotier-data` | Persists node identity so the drone keeps the same ZeroTier IP after reboot |

---

## References

- [Auterion App Development](https://docs.auterion.com/app-development/app-development/application-development-1)
- [Auterion Compose Override](https://docs.auterion.com/app-development/app-framework/compose-override)
- [Virtual Skynode](https://docs.auterion.com/app-development/simulation/virtual-skynode)
- [ZeroTier Docker](https://docs.zerotier.com/docker/)
- [ZeroTier Official Docker Image](https://hub.docker.com/r/zerotier/zerotier)
