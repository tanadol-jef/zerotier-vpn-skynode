#!/bin/sh
set -e

# Ensure TUN device is available
if [ ! -c /dev/net/tun ]; then
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200
    chmod 600 /dev/net/tun
fi

# Start ZeroTier daemon in foreground mode, writing logs to stdout
zerotier-one /var/lib/zerotier-one &
ZT_PID=$!

echo "[zerotier] Daemon started (PID $ZT_PID), waiting for initialization..."
sleep 5

# Join network if ZEROTIER_NETWORK_ID is set
if [ -n "$ZEROTIER_NETWORK_ID" ]; then
    echo "[zerotier] Joining network: $ZEROTIER_NETWORK_ID"
    zerotier-cli join "$ZEROTIER_NETWORK_ID"
else
    echo "[zerotier] WARNING: ZEROTIER_NETWORK_ID is not set."
    echo "[zerotier] Set it and run: zerotier-cli join <network-id>"
fi

# Show node info
sleep 2
echo "[zerotier] Node status:"
zerotier-cli status || true
echo "[zerotier] Networks:"
zerotier-cli listnetworks || true

# Forward signals to zerotier-one and keep container alive
trap "kill $ZT_PID 2>/dev/null; exit 0" TERM INT

# Periodic status + auto-rejoin if needed
while kill -0 $ZT_PID 2>/dev/null; do
    sleep 60
    if [ -n "$ZEROTIER_NETWORK_ID" ]; then
        # Re-join if the network dropped (no-op if already joined)
        STATUS=$(zerotier-cli listnetworks 2>/dev/null | grep "$ZEROTIER_NETWORK_ID" | awk '{print $6}' || true)
        if [ "$STATUS" != "OK" ]; then
            echo "[zerotier] Network not OK ($STATUS), re-joining..."
            zerotier-cli join "$ZEROTIER_NETWORK_ID" || true
        fi
    fi
done

echo "[zerotier] Daemon exited."
