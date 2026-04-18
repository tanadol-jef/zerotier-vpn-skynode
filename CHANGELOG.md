# Changelog

All notable changes to this project will be documented in this file.

---

## [1.1.0] - 2026-04-18

### Changed
- `app-author` updated to `com.eosorbit.zerotier-vpn`
- `app-version` bumped to `1.1.0`

### Added
- `parameters` block exposing two configurable fields in Auterion Suite UI:
  - `NETWORK_ID` — ZeroTier network ID (default: `60ee7c034ac89856`, visible)
  - `REJOIN_INTERVAL_SEC` — watchdog re-join interval in seconds (default: `60`, advanced)
- `build-args.ZEROTIER_VERSION` in service definition to allow pinning the base image version without editing the Dockerfile
- `ssh: false` explicitly declared on the service
- `environment: PYTHONUNBUFFERED=1` in `compose-override` for consistent log flushing
- `logging` config in `compose-override` — `json-file` driver capped at 10 MB × 3 files to prevent storage exhaustion on-device

---

## [1.0.0] - 2026-04-17

### Added
- Initial release: ZeroTier VPN packaged as an AuterionOS app for Skynode S
- `zerotier/zerotier` official Docker image as base (ARM64-native)
- `networks.conf` — bakes the ZeroTier network ID into the image at build time
- `entrypoint.sh` — starts `zerotier-one`, joins networks from `networks.conf`, auto-rejoins every 60 s if status is not OK, creates `/dev/net/tun` if missing
- `compose-override` with `NET_ADMIN`, `SYS_ADMIN` capabilities, `/dev/net/tun` device passthrough, `host` network mode, and a named volume for identity persistence across reboots
