# Module 07 Evidence Manifest

CyberBlue Module 07 — **Network Forensics & Session Investigation** is currently **IN PROGRESS**.

## Evidence captured

1. `01a-module07-forensic-observation-point-validation.webp` — passive `ens19` sees third-party traffic.
2. `02a-module07-first-pcap-session-capture.webp` — first preserved TCP/22 PCAP.
3. `03a-module07-tshark-session-reconstruction.webp` — structured TCP conversation reconstruction.
4. `04a-module07-ssh-stream-reconstruction.webp` — SSH banner recovered from stream evidence.
5. `05a-module07-zeek-session-metadata-incomplete.webp` — initial Zeek interpretation before checksum correction.
6. `05b-module07-zeek-checksum-offload-correction.webp` — coherent session after `-C` processing.
7. `06a-module07-zeek-ssh-protocol-analysis.webp` — Zeek `ssh.log` protocol metadata.
8. `07a-module07-reconnaissance-session-analysis.webp` — 50-port reconnaissance reconstructed in Zeek.
9. `07b-module07-reconnaissance-pcap-capture.webp` — 107-packet scan capture with zero drops.
10. `08a-module07-zeek-suricata-reconnaissance-correlation.webp` — Suricata alert timestamp inside the PCAP window.
11. `09a-module07-wazuh-reconnaissance-correlation.webp` — matching event visible in Wazuh Threat Hunting.
12. `09b-module07-wazuh-reconnaissance-event-details.webp` — matching SID/source/destination details.
13. `10a-module07-http-transaction-metadata.webp` — Zeek HTTP metadata for `/evidence.txt`.
14. `10b-module07-http-stream-reconstruction.webp` — clear-text request/response/body reconstruction.
15. `11a-module07-http-object-recovery.webp` — HTTP object exported from PCAP and hashed.
16. `11b-module07-recovered-object-integrity-validation.webp` — source/recovered SHA-256 match.
17. `12a-module07-controlled-evidence-gap.webp` — critical payload packet removed from a copy of the capture.
18. `12b-module07-forensic-evidence-gap-impact.webp` — metadata survives while object recovery fails.
19. `12c-module07-forensic-evidence-recovery.webp` — complete capture restores the object and expected hash.
20. `13a-module07-live-zeek-session-monitoring.webp` — live Zeek analysis on `ens19`.
21. `14a-module07-zeek-managed-sensor-deployment.webp` — ZeekControl standalone sensor running.
22. `14b-module07-zeek-managed-json-telemetry.webp` — managed `conn.log` and `ssh.log` in JSON.
23. `15a-module07-zeek-systemd-persistence.webp` — systemd-managed Zeek startup.
24. `15b1-module07-post-reboot-zeek-visibility-failure.webp` — Zeek running after reboot while live visibility was incomplete/absent.
25. `15b2-module07-mirror-rebind-recovery.webp` — Proxmox mirror rebound to the recreated `tap105i1`.
26. `15b3-module07-post-recovery-zeek-validation.webp` — full bidirectional SSH session restored in Zeek.
27. `15c1-module07-vm-hook-not-triggered.webp` — stale `device *` and no lifecycle-hook journal entry.
28. `15c2-module07-vm-lifecycle-hook-configured.webp` — Proxmox snippet storage, hookscript attachment, and current mirror state.

## Current evidence story

The module has progressed from packet preservation to session reconstruction, protocol metadata, IDS/SIEM correlation, object recovery, integrity validation, and controlled evidence degradation. Live Zeek monitoring is operational and systemd-managed. Testing an NSM-01-only reboot exposed a separate virtual-tap lifecycle failure that was not covered by the full-host reboot validation in Module 06. A Proxmox VM hook is now configured to rebuild the mirror after VM 105 starts, but its final automatic restart qualification remains pending.
