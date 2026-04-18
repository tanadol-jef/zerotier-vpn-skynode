# Changelog

All notable changes to this project will be documented in this file.

---

## [1.1.0] - 2026-04-18

### Changed
- `app-author` updated to `com.eosorbit.zerotier-vpn`
- `auterion-api-version` set to `6` (api-version 7 is not supported by Skynode S AOS 4.x on-device update module)
- `auterion-app-base` set to `v2` (requires `app-base-v2` installed on the device)
- `target-platform` changed to list form `[skynode, skynode-s]` for broader compatibility

### Added
- `parameters` block exposing two configurable fields in Auterion Suite UI:
  - `NETWORK_ID` — ZeroTier network ID (default: `60ee7c034ac89856`, visible)
  - `REJOIN_INTERVAL_SEC` — watchdog re-join interval in seconds (default: `60`, advanced)
- `build-args.ZEROTIER_VERSION` to allow pinning the base image version without editing the Dockerfile
- `ssh: false` explicitly declared on the service

### Fixed
- Installation failure (`Update module terminated abnormally: exit status 1`) caused by `auterion-api-version: 7` not being supported by the on-device Mender update module

---

## [1.0.0] - 2026-04-17

### Added
- Initial release: ZeroTier VPN packaged as an AuterionOS app for Skynode S
- `zerotier/zerotier` official Docker image as base (ARM64-native)
- `networks.conf` — bakes the ZeroTier network ID into the image at build time
- `entrypoint.sh` — starts `zerotier-one`, joins networks from `networks.conf`, auto-rejoins every 60 s if status is not OK, creates `/dev/net/tun` if missing
- `compose-override` with `NET_ADMIN`, `SYS_ADMIN` capabilities, `/dev/net/tun` device passthrough, `host` network mode, and a named volume for identity persistence across reboots
