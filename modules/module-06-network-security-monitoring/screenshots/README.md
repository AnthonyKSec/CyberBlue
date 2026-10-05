# Module 06 — Evidence Screenshots

This directory contains the captured evidence for **CyberBlue Module 06 — Network Security Monitoring**.

The Module 06 README embeds each screenshot at the build step it validates.

| Evidence | Validation |
|---|---|
| `01a-module06-proxmox-capacity-preflight.webp` | Proxmox capacity preflight before NSM deployment |
| `02a-module06-first-suricata-detection.webp` | First controlled Suricata ICMP signature detection |
| `02b-module06-passive-mirrored-detection.webp` | Passive third-party traffic detection through the Proxmox mirror |
| `03a-module06-tcp-syn-threshold-detection.webp` | Initial TCP SYN threshold detection showing duplicate/noisy alerts |
| `03b-module06-tuned-syn-detection.webp` | Same behavior after tuning, producing a clean alert |
| `04a-module06-wazuh-agent-validation.webp` | Wazuh agent and Suricata EVE JSON collection configuration validation |
| `04b-module06-suricata-wazuh-integration.webp` | Suricata alert successfully ingested into Wazuh Threat Hunting |
| `04c-module06-wazuh-alert-details.webp` | Field-level investigation of the Suricata event in Wazuh |
| `04d-module06-wazuh-rule-classification.webp` | Wazuh rule classification confirming `ids, suricata`, rule `86601`, level `3` |

These files are portfolio evidence. They should remain paired with the explanation in the main Module 06 README so that each image documents **what was tested, what passed, and what the result proves**.
