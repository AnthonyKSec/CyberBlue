# Module 07 Screenshot Index

| Evidence | What it validates |
|---|---|
| `01a-module07-forensic-observation-point-validation.webp` | Passive third-party visibility on NSM-01 `ens19` |
| `02a-module07-first-pcap-session-capture.webp` | Preserved TCP/22 PCAP and successful handshake |
| `03a-module07-tshark-session-reconstruction.webp` | 5-tuple, timing, flags, and payload length |
| `04a-module07-ssh-stream-reconstruction.webp` | SSH service identified from stream payload |
| `05a-module07-zeek-session-metadata-incomplete.webp` | Initial incomplete Zeek interpretation |
| `05b-module07-zeek-checksum-offload-correction.webp` | Corrected Zeek session with checksum validation disabled |
| `06a-module07-zeek-ssh-protocol-analysis.webp` | SSH protocol metadata and negotiated crypto |
| `07a-module07-reconnaissance-session-analysis.webp` | One source probing ports 1–50 and Zeek connection states |
| `07b-module07-reconnaissance-pcap-capture.webp` | 107 packets captured with zero drops |
| `08a-module07-zeek-suricata-reconnaissance-correlation.webp` | Suricata alert falls inside PCAP time window |
| `09a-module07-wazuh-reconnaissance-correlation.webp` | Matching scan alert in Wazuh Threat Hunting |
| `09b-module07-wazuh-reconnaissance-event-details.webp` | SID/source/destination evidence for SIEM event |
| `10a-module07-http-transaction-metadata.webp` | HTTP request/response metadata in Zeek |
| `10b-module07-http-stream-reconstruction.webp` | Clear-text HTTP request, response, and body |
| `11a-module07-http-object-recovery.webp` | Object extraction and SHA-256 from network evidence |
| `11b-module07-recovered-object-integrity-validation.webp` | Source/recovered object hashes match |
| `12a-module07-controlled-evidence-gap.webp` | Deliberate removal of the HTTP payload packet |
| `12b-module07-forensic-evidence-gap-impact.webp` | Lost content/object recovery while metadata survives |
| `12c-module07-forensic-evidence-recovery.webp` | Complete evidence restores the object and hash |
| `13a-module07-live-zeek-session-monitoring.webp` | Live Zeek packet intake and SSH session metadata |
| `14a-module07-zeek-managed-sensor-deployment.webp` | ZeekControl-managed standalone sensor |
| `14b-module07-zeek-managed-json-telemetry.webp` | Managed JSON telemetry for `conn.log` / `ssh.log` |
| `15a-module07-zeek-systemd-persistence.webp` | systemd wrapper enabled and Zeek running |
| `15b1-module07-post-reboot-zeek-visibility-failure.webp` | Post-reboot process health did not guarantee telemetry health |
| `15b2-module07-mirror-rebind-recovery.webp` | Manual service restart rebound mirror to current tap |
| `15b3-module07-post-recovery-zeek-validation.webp` | Full bidirectional SSH visibility restored |
| `15c1-module07-vm-hook-not-triggered.webp` | No hook existed/fired during first lifecycle test |
| `15c2-module07-vm-lifecycle-hook-configured.webp` | Hookscript prepared and attached to VM 105 |


## Final lifecycle qualification

The final VM 105 lifecycle qualification was completed after the 28-image screenshot set above. The qualifying terminal evidence is documented in the module README and EVIDENCE manifest: the corrected non-blocking hook executed, the mirror rebound automatically to `tap105i1`, a fresh SSH session produced 26 captured packets with zero drops, and Zeek recorded a complete `SF` SSH session with zero missed bytes. A separate final screenshot has not been added to this index.
