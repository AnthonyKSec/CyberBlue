# CyberBlue Module 09 — Persistent Velociraptor Routing

**Prepared scripts, not yet executed on the VMs.** These preserve the existing CyberForge default-deny segmentation.

- On DFIR-01 VM107, run `sudo bash dfir01-persist-route.sh`. Creates Netplan drop-in at `/etc/netplan/90-cyberblue-m09-win11-route.yaml`, adds only a /32 route to WIN11-01 via ROUTER-01, validates with netplan generate, and updates the current live route. No netplan apply or interface bounce.
- On ROUTER-01 VM104, run `sudo bash router01-persist-nft.sh`. Backs up `/etc/nftables.conf`, adds narrow TCP 8000 allow from WIN11-01 before final drop, tests with `nft -c -f`, and installs runtime rule only when absent. No nftables reload.

**Before running:** Verify actual interface/IPs match the scripts and keep the Proxmox serial console available. The scripts stop if expected conditions differ.

**After running:** Verify `ip -4 route get 10.10.30.10` on DFIR-01 and `sudo nft -a list chain inet cyberblue forward` on ROUTER-01. From WIN11-01 run `Test-NetConnection 10.10.20.13 -Port 8000`. Reboot hosts **sequentially** only when ready and recheck connectivity to prove persistence.

**Rollback:** DFIR-01—remove the script-owned Netplan drop-in and regenerate; remove only the added /32 live route. ROUTER-01—restore the timestamped `/etc/nftables.conf.pre-module09.*` backup and reload nftables from the local Proxmox serial console.

The scripts do not contain or require any Velociraptor secrets. Never publish MSI/enrollment configuration.
