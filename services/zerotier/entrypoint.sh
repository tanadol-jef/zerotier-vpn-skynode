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

# Join networks listed in config file
NETWORKS_CONF=/etc/zerotier/networks.conf
if [ -f "$NETWORKS_CONF" ]; then
    while IFS= read -r NETWORK_ID || [ -n "$NETWORK_ID" ]; do
        [ -z "$NETWORK_ID" ] && continue
        echo "[zerotier] Joining network: $NETWORK_ID"
        zerotier-cli join "$NETWORK_ID"
    done < "$NETWORKS_CONF"
else
    echo "[zerotier] WARNING: $NETWORKS_CONF not found. No networks to join."
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
    if [ -f "$NETWORKS_CONF" ]; then
        while IFS= read -r NETWORK_ID || [ -n "$NETWORK_ID" ]; do
            [ -z "$NETWORK_ID" ] && continue
            STATUS=$(zerotier-cli listnetworks 2>/dev/null | grep "$NETWORK_ID" | awk '{print $6}' || true)
            if [ "$STATUS" != "OK" ]; then
                echo "[zerotier] Network $NETWORK_ID not OK ($STATUS), re-joining..."
                zerotier-cli join "$NETWORK_ID" || true
            fi
        done < "$NETWORKS_CONF"
    fi
done

echo "[zerotier] Daemon exited."
