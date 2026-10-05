#!/usr/bin/env bash
# Cyber Forge Module 06 — runtime Proxmox traffic mirror
#
# Mirrors ROUTER-01 vmbr20 traffic to the NSM-01 passive monitoring NIC.
#
# ROUTER-01 net0 / vmbr20: tap104i0
# NSM-01    net1 / vmbr20: tap105i1
#
# IMPORTANT:
# This is currently a runtime-only configuration.
# Revalidate/reapply after Proxmox reboot or relevant VM/tap recreation.

set -euo pipefail

tc qdisc add dev tap104i0 clsact

tc filter add dev tap104i0 ingress matchall \
  action mirred egress mirror dev tap105i1

tc filter add dev tap104i0 egress matchall \
  action mirred egress mirror dev tap105i1
