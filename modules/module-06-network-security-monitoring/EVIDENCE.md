# Module 06 Evidence Manifest

Portfolio evidence captured during **CyberBlue Module 06 — Network Security Monitoring**:

- `01a-module06-proxmox-capacity-preflight.webp`
- `02a-module06-first-suricata-detection.webp`
- `02b-module06-passive-mirrored-detection.webp`
- `03a-module06-tcp-syn-threshold-detection.webp`
- `03b-module06-tuned-syn-detection.webp`
- `04a-module06-wazuh-agent-validation.webp`
- `04b-module06-suricata-wazuh-integration.webp`
- `04c-module06-wazuh-alert-details.webp`
- `04d-module06-wazuh-rule-classification.webp`
- `05a-module06-post-reboot-monitoring-path-failure.webp`
- `05b-module06-blind-spot-validation.webp`
- `05c-module06-monitoring-path-recovery.webp`
- `05d-module06-post-reboot-persistence-validation.webp`
- `05e-module06-post-reboot-detection-validation.webp`
- `05f-module06-post-reboot-wazuh-validation.webp`

## Evidence story

1. Capacity and host readiness verified before deploying NSM-01.
2. First controlled local Suricata detection validated.
3. Passive third-party monitoring validated through Proxmox traffic mirroring.
4. Behavior-based TCP SYN detection reproduced with noisy alerting.
5. Detection logic tuned and the same behavior replayed.
6. Wazuh agent configuration and Suricata EVE JSON collection validated.
7. Suricata alert successfully ingested into Wazuh Threat Hunting.
8. Alert fields and Wazuh IDS/Suricata rule classification investigated.
9. Host reboot removed the passive monitoring path while security services remained healthy.
10. The same SYN behavior produced no new alert, proving a real monitoring blind spot.
11. Netplan and the Proxmox mirror were repaired and the same behavior was detected again.
12. Persistence was implemented for the passive NIC, mirror service, and infrastructure VM startup order.
13. A full host reboot restored the monitoring path automatically.
14. The same SYN test produced a fresh Suricata alert after reboot.
15. Wazuh displayed the corresponding fresh post-reboot event.

**Module 06 Technical Build Gate: PASS ✓**
