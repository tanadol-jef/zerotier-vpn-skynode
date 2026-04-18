# Rebuild and reinstall the ZeroTier VPN app to Skynode S

Run these two commands sequentially via WSL2 Ubuntu from the project root.
The build MUST run inside WSL2 — auterion-cli uses Linux Docker bind mounts that fail from native Windows shells.

## Steps

1. Build the AuterionOS artifact:
```bash
wsl -d Ubuntu-22.04 -e bash -c "cd /mnt/c/Users/jamba/Documents/Vibecode/zerotier-vpn && /home/pipo/.local/bin/auterion-cli app build 2>&1"
```

2. Install to Skynode S (device at 10.41.1.1, serial 340816538):
```bash
wsl -d Ubuntu-22.04 -e bash -c "cd /mnt/c/Users/jamba/Documents/Vibecode/zerotier-vpn && /home/pipo/.local/bin/auterion-cli app install build/com.eosorbit.zerotier-vpn.zerotier-vpn-$APP_VERSION.auterionos 2>&1"
```

Replace `$APP_VERSION` with the current `app-version` value from `auterion-app.yml` (currently `1.1.0`).

## Expected success output
Build ends with the pigz/mender-artifact packaging lines.
Install ends with: `The device has been updated successfully`

## If install fails with "Update module terminated abnormally: exit status 1"
Check `auterion-api-version` in `auterion-app.yml` — must be `6`, not `7`.
API version 7 is not supported by the on-device Mender update module on Skynode S AOS 4.x.
