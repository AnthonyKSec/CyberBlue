#!/usr/bin/env bash
# Cyber Forge Module 06 — persistent Proxmox vmbr20 traffic mirror
#
# Source:      ROUTER-01 net0 / vmbr20 -> tap104i0
# Destination: NSM-01 net1 / vmbr20    -> tap105i1
#
# The script waits for both tap devices, removes stale clsact state,
# and recreates ingress and egress mirroring. It is intended to run
# under cyberforge-vmbr20-mirror.service.

set -euo pipefail

SRC="tap104i0"
DST="tap105i1"

IP="/usr/sbin/ip"
TC="/usr/sbin/tc"

echo "Waiting for $SRC and $DST..."

for i in $(seq 1 60); do
    if $IP link show "$SRC" >/dev/null 2>&1 &&
       $IP link show "$DST" >/dev/null 2>&1; then
        break
    fi
    sleep 2
done

$IP link show "$SRC" >/dev/null 2>&1 || {
    echo "$SRC not found"
    exit 1
}

$IP link show "$DST" >/dev/null 2>&1 || {
    echo "$DST not found"
    exit 1
}

$TC qdisc del dev "$SRC" clsact 2>/dev/null || true
$TC qdisc add dev "$SRC" clsact

$TC filter add dev "$SRC" ingress pref 10 matchall \
    action mirred egress mirror dev "$DST"

$TC filter add dev "$SRC" egress pref 10 matchall \
    action mirred egress mirror dev "$DST"

echo "Cyber Forge vmbr20 mirror active: $SRC -> $DST"
