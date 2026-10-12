# CyberBlue — Module 09 Evidence Manifest

**Status: IN PROGRESS — documented checkpoint through Step 09.38.**

These are original terminal/GUI screenshots captured during the live Cyber Forge build. The conceptual banner in `assets/` is illustrative and **not** forensic proof. Screenshots are linked by exact filename; failures and repairs are deliberately retained.

**Total curated screenshots: 30.** No screenshot is evidence of a client agent enrollment, endpoint artifact collection, or threat-hunting completion.

| Screenshot | What it proves / records |
|---|---|
| [`09a-module09-preflight-vm-capacity.png`](screenshots/09a-module09-preflight-vm-capacity.png) | Proxmox VM/CPU/RAM/local-lvm preflight; storage pool utilization identified |
| [`09aa-module09-linux-client-package-build-validation.png`](screenshots/09aa-module09-linux-client-package-build-validation.png) | GUI Linux package-builder flow reported Symbol Proxy not found (error state) |
| [`09ab-module09-linux-client-package-integrity-validation.png`](screenshots/09ab-module09-linux-client-package-integrity-validation.png) | Generated AMD64 Debian client package downloaded, inspected, SHA-256 recorded |
| [`09ac-module09-linux-client-configuration-validation.png`](screenshots/09ac-module09-linux-client-configuration-validation.png) | Embedded client URL https://10.10.20.13:8000/ and auto-start postinst verified |
| [`09ad-module09-linux-client-transfer-integrity-validation.png`](screenshots/09ad-module09-linux-client-transfer-integrity-validation.png) | Debian client staged on Linux-Mint VM101; SHA-256 matched workstation copy |
| [`09ae-module09-graceful-lab-shutdown-validation.png`](screenshots/09ae-module09-graceful-lab-shutdown-validation.png) | All eight VMs confirmed stopped; Proxmox host shutdown command issued |
| [`09b-module09-storage-device-inventory.png`](screenshots/09b-module09-storage-device-inventory.png) | 1 TB Seagate NTFS HDD and Ubuntu ISO inventory confirmed |
| [`09c-module09-hdd-readonly-inspection.png`](screenshots/09c-module09-hdd-readonly-inspection.png) | Read-only NTFS inspection found only Windows housekeeping directories and small Recycle Bin entries |
| [`09e-module09-dfir01-vm-provisioning.png`](screenshots/09e-module09-dfir01-vm-provisioning.png) | DFIR-01 VM107 created with 2 vCPU, 4 GiB RAM, 24 GiB SSD system disk |
| [`09f-module09-dfir01-ubuntu-install-validation.png`](screenshots/09f-module09-dfir01-ubuntu-install-validation.png) | Ubuntu 24.04.5 management 192.168.12.147, SSH and system disk validated |
| [`09g-module09-dfir01-root-volume-expansion.png`](screenshots/09g-module09-dfir01-root-volume-expansion.png) | Root LV expanded from ~11 GiB to ~22 GiB |
| [`09h-module09-dfir01-guest-agent-validation.png`](screenshots/09h-module09-dfir01-guest-agent-validation.png) | QEMU Guest Agent enabled and communication validated after VM restart |
| [`09i-module09-forensic-disk-attachment.png`](screenshots/09i-module09-forensic-disk-attachment.png) | Second 150 GiB HDD-backed virtual disk detected unformatted in DFIR-01 |
| [`09j-module09-forensic-disk-partition-validation.png`](screenshots/09j-module09-forensic-disk-partition-validation.png) | 150 GiB forensic disk partitioned separately from OS disk |
| [`09k-module09-forensic-filesystem-validation.png`](screenshots/09k-module09-forensic-filesystem-validation.png) | ext4 evidence volume mounted at /srv/velociraptor, ~147 GiB size |
| [`09l-module09-forensic-persistent-mount-validation.png`](screenshots/09l-module09-forensic-persistent-mount-validation.png) | Evidence mount persisted in fstab and passed manual unmount/remount test |
| [`09m-module09-forensic-storage-permissions-validation.png`](screenshots/09m-module09-forensic-storage-permissions-validation.png) | Dedicated Velociraptor account plus segregated datastore, filestore and cases permissions tested |
| [`09n-module09-velociraptor-binary-integrity-validation.png`](screenshots/09n-module09-velociraptor-binary-integrity-validation.png) | Velociraptor v0.77.3 downloaded and SHA-256 matched verified release value |
| [`09o-module09-dfir01-dual-nic-detection.png`](screenshots/09o-module09-dfir01-dual-nic-detection.png) | Second VirtIO NIC detected on vmbr20 (ens19) |
| [`09p-module09-dfir01-lab-nic-routing-validation.png`](screenshots/09p-module09-dfir01-lab-nic-routing-validation.png) | ens19 at 10.10.20.13/24; ens18 gateway unchanged; ROUTER-01 ping 4/4 |
| [`09q-module09-velociraptor-configuration-validation.png`](screenshots/09q-module09-velociraptor-configuration-validation.png) | Initial generated configuration captured without keys; showed permissive bind and filestore overlap |
| [`09r-module09-velociraptor-server-configuration-correction.png`](screenshots/09r-module09-velociraptor-server-configuration-correction.png) | Config merge failed due permission denied and output file replaced original with zero bytes |
| [`09s-module09-velociraptor-config-recovery-validation.png`](screenshots/09s-module09-velociraptor-config-recovery-validation.png) | Backup restored, targeted configuration corrected, frontend pinned to ens19 and filestore separated |
| [`09t-module09-velociraptor-debian-package-validation.png`](screenshots/09t-module09-velociraptor-debian-package-validation.png) | Server Debian package 0.77.3 amd64 built with embedded configuration and systemd unit |
| [`09u-module09-velociraptor-protected-startup-configuration.png`](screenshots/09u-module09-velociraptor-protected-startup-configuration.png) | systemd mount gate and startup authorization marker preinstalled ahead of package |
| [`09v-module09-velociraptor-protected-installation-validation.png`](screenshots/09v-module09-velociraptor-protected-installation-validation.png) | Server package installed, service skipped with gate absent, no listeners yet |
| [`09w-module09-velociraptor-server-startup-validation.png`](screenshots/09w-module09-velociraptor-server-startup-validation.png) | Missing /var/log/velociraptor repaired; frontend and GUI listeners verified |
| [`09x-module09-velociraptor-gui-access-validation.png`](screenshots/09x-module09-velociraptor-gui-access-validation.png) | GUI reached through RhinoRecon SSH tunnel and admin logged in |
| [`09y-module09-linuxmint-endpoint-readiness.png`](screenshots/09y-module09-linuxmint-endpoint-readiness.png) | Initial Linux-Mint reachability check failed because commands were run from Proxmox, not DFIR-01 |
| [`09z-module09-linuxmint-connectivity-validation.png`](screenshots/09z-module09-linuxmint-connectivity-validation.png) | Retest from DFIR-01: ICMP 4/4, frontend listener verified, SSH to Linux-Mint successful |

## Evidence interpretation and boundaries

- `09y` is a **failed source-location test** from PVE; `09z` is the successful connectivity proof from DFIR-01. Neither implies cross-zone Windows enrollment.
- `09r` records failed configuration merge and a zero-byte output; `09s` validates restoration and correction from an intact backup.
- `09aa` shows the **Linux package-builder collection errored** (`Symbol Proxy not found`); `09ab` and `09ac` separately verify the generated Debian client and embedded URL; `09ad` verifies transfer to VM101.
- `09v` confirms no listeners before authorized startup; `09w` confirms the corrected logging directory permits the server to start and bind only to intended interfaces.
- `09ae` confirms *all VMs stopped* and host shutdown was initiated, but not independently that the Proxmox machine completed hardware power-off.
- No `.deb` packages, private server/client YAML, credentials, or certificate/private-key material are included. `configs/` contains sanitized examples only.

## Evidence integrity policy

The repository preserves the screenshot bytes provided from the build session, with filenames normalized only for screenshots originally attached under generic image names (`09z`, `09ad`, `09ae`). An SHA-256 file inventory is included at `EVIDENCE-SHA256.txt` for reproducibility. For real client investigations, use an immutable/append-only case store, time synchronization checks, custody records, independent backups, and appropriate encryption.
