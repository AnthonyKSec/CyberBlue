# Module 09 — Sanitized deployment / validation notes

These are lab-specific excerpts, **not** a complete deploy script. Always verify the targeted device and VM identity before executing disk commands. Never commit `server.config.yaml`, extracted client config, .deb packages containing embedded secrets, passwords, or private keys.

## Storage and accounts

- Proxmox: `/dev/sdb1` ext4, storage ID `cyberforge-hdd`, directory `/mnt/pve/cyberforge-hdd`, `is_mountpoint 1`. Host mount by filesystem UUID `c58c58db-4041-4c8d-a9ca-b01c68267aee` (lab-specific).
- DFIR-01: 150 GiB virtual disk `/dev/sdb1`, mounted at `/srv/velociraptor` (UUID on **guest** is distinct from physical host disk UUID).
- `datastore/` and `filestore/` owned by `velociraptor:velociraptor`, mode 0700; `cases/` owned by root:root, mode 0700.
- The service account is non-login; GUI authentication is separate from Linux accounts.

## Configuration expectations (inspect selectively — never commit the secret YAML)

```text
Frontend.hostname          10.10.20.13
Frontend.bind_address      10.10.20.13
Frontend.bind_port         8000
GUI.bind_address           127.0.0.1
GUI.bind_port              8889
Datastore.location         /srv/velociraptor/datastore
Datastore.filestore_directory /srv/velociraptor/filestore
Client.server_urls         https://10.10.20.13:8000/
Logging.output_directory   /var/log/velociraptor
```

On DFIR-01, create `/var/log/velociraptor` as owner/group `velociraptor`, mode 0750. Then validate the server listeners with `ss -lntp` and the evidence disk with `findmnt /srv/velociraptor`.

Access GUI **only** via RhinoRecon SSH tunnel:

```bash
ssh -N -L 18889:127.0.0.1:8889 rhinoadmin@192.168.12.147
```

Then browse `https://127.0.0.1:18889` and verify the local lab certificate policy; do not expose the GUI broadly.

## Service safeguards

See `velociraptor-server-guard.conf`. A missing `/etc/velociraptor/.cyberblue-start-authorized` marker intentionally blocks startup, including the initial package post-install auto-start. Add marker only after confirming the evidence mount, logging directory, read/write permissions, and corrected server configuration. This was validated with the marker absent; full missing-mount runtime failure/recovery not yet tested.

## Client package review and staging

`Server.Utils.CreateLinuxPackages` uploaded the generated Debian `.deb` and RPM despite returning an overall `Symbol Proxy not found` error. On RhinoRecon, inspect the downloaded Debian package **without installing** it:

```bash
PKG=velociraptor_client_0.77.3_amd64.deb
dpkg-deb -f "$PKG" Package Version Architecture
dpkg-deb --contents "$PKG" | grep -E 'client.config.yaml|velociraptor_client.service'
sha256sum "$PKG"
```

It was transferred to VM101 via `scp -o ProxyJump=rhinoadmin@192.168.12.147 ... cyberadmin@10.10.20.11:~/` and the checksum matched. The `.deb` package automatically starts its client service on install; **installation/enrollment still pending** at this checkpoint.

## Safety/qualification reminders

- Avoid cross-segment policy changes unless explicitly scoped, tested, documented and reverted when finished.
- No real client data may be collected without written authorization and data-handling agreements.
- The 1 TB HDD is an aging single disk, not a backup. Use independently stored copies of irreplaceable evidence.
- Compare host and guest timestamps before building event timelines; synchronize time sources.
- Snapshot clean target state before intentional exploitation, then reset and replay investigations.
