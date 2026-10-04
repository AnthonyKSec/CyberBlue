# CyberBlue — Module 05
## Centralized Logging & SIEM Foundations

**Status:** TECHNICAL BUILD COMPLETE ✓  
**Platform:** Proxmox VE 9.2.2  
**SIEM implementation:** Wazuh 4.14.8 single-node Docker deployment  
**Primary SIEM host:** VM100 — Ubuntu-SOC  
**Training method:** Principle → Architecture → Build → Validate → Break/Test → Troubleshoot → Restore → Explain → Document → Qualify

> Module 05 moves Cyber Forge from endpoint-local telemetry into centralized security monitoring. The build now includes a hardened Wazuh platform, Linux and Windows agent enrollment, Sysmon ingestion, known-event correlation, least-privilege cross-segment transport, and a controlled ingestion outage/recovery exercise.

---

## Core Principle

A SIEM is not valuable because it has a dashboard. It is valuable because it can reliably:

```text
COLLECT
   ↓
TRANSPORT
   ↓
NORMALIZE / ANALYZE
   ↓
INDEX
   ↓
SEARCH
   ↓
CORRELATE
   ↓
INVESTIGATE
```

Module 05 therefore focuses on the complete telemetry path rather than simply installing Wazuh.

---

## Final Architecture

```text
                         MANAGEMENT LAN
                        192.168.12.0/24
                               |
                               |
                    Ubuntu-SOC ens18
                     192.168.12.227
                               |
                         HTTPS :443
                               |
                        Wazuh Dashboard
                               |
                    Docker internal network
                       /               \
                      /                 \
             Wazuh Manager         Wazuh Indexer
                                      :9200
                                 internal only

                         SOC NETWORK
                        10.10.20.0/24
                               |
                            vmbr20
                      +--------+--------+
                      |                 |
               Ubuntu-SOC          Linux-Mint
               10.10.20.10         10.10.20.11
                Wazuh Manager       Wazuh Agent 001
                      |
                      |
                  ROUTER-01
             10.10.20.1 / 10.10.30.1
                      |
            least-privilege nftables
        WIN11-01 → Ubuntu-SOC TCP 1514/1515
                      |
                    vmbr30
                      |
                  WIN11-01
                 10.10.30.10
                 Wazuh Agent 002
                 Sysmon telemetry
```

### Trust-boundary rule

The Victim network was **not** broadly opened to the SOC network.

Only this permanent exception was added:

```text
Source:      10.10.30.10
Destination: 10.10.20.10
Protocol:    TCP
Ports:       1514, 1515
Action:      ACCEPT
```

Everything else continues to fall through to the router's default drop policy.

---

## Technical Build Progress

```text
[✓] Proxmox capacity baseline captured
[✓] Ubuntu-SOC resized to 4 vCPU / 8 GB RAM / 64 GB disk
[✓] Linux LVM/root filesystem expanded
[✓] Docker / Docker Compose / Git prerequisites validated
[✓] vm.max_map_count validated
[✓] Pre-Wazuh snapshot created
[✓] Wazuh Docker v4.14.8 repository staged
[✓] Wazuh indexer certificates generated
[✓] Compose configuration validated
[✓] Dashboard bound to management address only
[✓] Wazuh single-node stack deployed
[✓] Transient Docker image-pull TLS failure recovered
[✓] Wazuh admin credential rotated
[✓] OpenSearch security configuration reapplied
[✓] Direct indexer authentication validated with HTTP 200
[✓] New dashboard admin login validated
[✓] External host exposure of indexer port 9200 removed
[✓] Dashboard validated after indexer hardening
[✓] Linux-Mint Wazuh agent installed and enrolled
[✓] Linux-Mint shown active as Agent 001
[✓] Known Linux sudo event correlated centrally
[✓] WIN11-01 baseline segmentation block demonstrated
[✓] Least-privilege TCP 1514/1515 router exception implemented
[✓] Router rule counters validated
[✓] Router rule made persistent and reloaded successfully
[✓] Windows Wazuh package transferred through temporary controlled path
[✓] Temporary TCP 8080 staging path removed
[✓] WIN11-01 Wazuh agent installed and enrolled
[✓] WIN11-01 shown active as Agent 002
[✓] Sysmon Operational channel added to Wazuh collection
[✓] Known Sysmon Event ID 1 correlated centrally
[✓] Controlled Wazuh ingestion outage created
[✓] Endpoint remained healthy during transport outage
[✓] Local Sysmon telemetry continued during outage
[✓] Central visibility gap demonstrated
[✓] Transport path restored
[✓] Agent reconnection validated
[✓] Buffered outage event backfilled after reconnect
[✓] New post-recovery telemetry validated
[✓] Temporary test rules and staging services removed
[✓] Final router policy validated
[✓] Final Wazuh stack health validated
[✓] Both agents active in Wazuh
[✓] Final post-Module-05 snapshots captured
[✓] Temporary installation/test artifacts removed
[✓] Module 05 Technical Build Gate completed
[ ] Knowledge Review — deferred until wider range build-out
[ ] Independent Qualification — deferred until wider range build-out
```

---

## 1. Capacity and Host Preparation

The Wazuh deployment started with capacity validation rather than immediately installing software.

### Original Ubuntu-SOC allocation

```text
2 vCPU
4 GB RAM
32 GB disk
```

### Final allocation

```text
4 vCPU
8 GB RAM
64 GB disk
```

The Linux storage stack was expanded through the full path:

```text
Virtual disk
   ↓
Partition
   ↓
LVM physical volume
   ↓
Logical volume
   ↓
ext4 filesystem
```

Commands included:

```bash
sudo growpart /dev/sda 3
sudo pvresize /dev/sda3
sudo lvextend -l +100%FREE -r /dev/mapper/ubuntu--vg-ubuntu--lv
```

Final root filesystem state was approximately:

```text
61 GB total
52 GB available
12% used
```

A Proxmox thin-provisioning overcommit warning remains an infrastructure item to address separately. The pool was not physically full during Module 05, but additional snapshot growth should be monitored.

---

## 2. Wazuh Platform Deployment

The Wazuh Docker repository was staged at:

```text
v4.14.8
```

Deployment path:

```text
~/Wazuh-docker/single-node
```

The platform consists of:

```text
wazuh.manager
wazuh.indexer
wazuh.dashboard
```

The dashboard is published only through the Ubuntu-SOC management interface:

```text
192.168.12.227:443 → dashboard:5601
```

The indexer remains reachable internally on Docker port 9200 but is no longer published on the Ubuntu-SOC host.

### Security principle

> **Expose only the services that must cross a trust boundary.**

Final validation:

```text
wazuh.manager      UP
wazuh.indexer      UP
wazuh.dashboard    UP
host :9200         NOT LISTENING
```

---

## 3. Administrative Credential Hardening

The default indexer administrative credential was rotated.

This required coordination between:

```text
docker-compose.yml
        +
internal_users.yml
        +
OpenSearch securityadmin.sh
```

An initial direct authentication test returned:

```text
HTTP 401
Unauthorized
```

The root cause was a password/hash mismatch caused during manual hash transcription through the console.

The recovery path was:

```text
Dashboard authentication failure
        ↓
Direct indexer authentication test
        ↓
HTTP 401 confirmed
        ↓
Credential/hash mismatch isolated
        ↓
SSH used for reliable copy/paste
        ↓
Configuration restored from backups
        ↓
Fresh hash generated
        ↓
OpenSearch security configuration reapplied
        ↓
Direct authentication retested
        ↓
HTTP 200
```

The corrected security update reported:

```text
Clusterstate: GREEN
Configuration for 'internalusers' created or updated
Done with success
```

### Security principle

> A successful configuration load does not prove the intended credential works. Authentication must be tested directly.

---

## 4. Linux-Mint Agent Enrollment

Linux-Mint remained isolated on the SOC network:

```text
Linux-Mint
10.10.20.11/24
   |
 vmbr20
   |
Ubuntu-SOC
10.10.20.10/24
```

No default route was required.

Connectivity to the Wazuh services was validated:

```text
10.10.20.10:1514   reachable
10.10.20.10:1515   reachable
```

To preserve endpoint isolation, the Linux agent package was downloaded on Ubuntu-SOC, temporarily served only on:

```text
10.10.20.10:8080
```

and pulled by Linux-Mint across the SOC network.

SHA-256 hashes were compared before installation to verify transfer integrity.

The agent then enrolled successfully:

```text
Requesting a key from server: 10.10.20.10
Valid key received
Trying to connect to server ([10.10.20.10]:1514/tcp)
Connected to the server ([10.10.20.10]:1514/tcp)
```

Dashboard state:

```text
Agent ID: 001
Name:     linux-mint
IP:       10.10.20.11
Version:  v4.14.8
Status:   Active
```

---

## 5. Linux Known-Event Correlation

A known privileged command was generated:

```bash
sudo /usr/bin/id
```

Wazuh Threat Hunting showed the corresponding sudo alert.

The exact event detail confirmed:

```text
agent.name      linux-mint
agent.ip        10.10.20.11
data.command    /usr/bin/id
data.srcuser    cyberadmin
data.dstuser    root
data.pwd        /home/cyberadmin
decoder.name    sudo
full_log        ... COMMAND=/usr/bin/id
```

### Capability demonstrated

> Generated a known privileged Linux event and correlated the exact command, source user, destination user, working directory, endpoint identity, and raw log centrally in Wazuh.

---

## 6. WIN11-01 Least-Privilege SIEM Routing

Before changing the router policy, Windows could not reach the Wazuh manager:

```text
WIN11-01 10.10.30.10 → 10.10.20.10:1514   BLOCKED
WIN11-01 10.10.30.10 → 10.10.20.10:1515   BLOCKED
```

This validated that Module 03 segmentation was still working.

A narrow nftables rule was added:

```nft
iifname "ens19" oifname "ens18" ip saddr 10.10.30.10 ip daddr 10.10.20.10 tcp dport { 1514, 1515 } counter accept
```

The rule was placed above the final drop and made persistent in:

```text
/etc/nftables.conf
```

After reloading the persistent ruleset, Windows connectivity tests still passed.

The rule counter confirmed that traffic traversed the intended security policy rather than another path.

---

## 7. Windows Agent Enrollment

The Wazuh MSI was downloaded to Ubuntu-SOC.

A temporary nftables rule allowed only:

```text
10.10.30.10 → 10.10.20.10 TCP 8080
```

for package staging.

The MSI was transferred to:

```text
C:\Temp\wazuh-agent.msi
```

SHA-256 hashes were compared between Ubuntu-SOC and WIN11-01 before installation.

After transfer:

- the temporary HTTP server was stopped;
- the temporary TCP 8080 nftables rule was removed;
- only the permanent TCP 1514/1515 Wazuh rule remained.

The Windows agent was installed with manager address:

```text
10.10.20.10
```

Runtime logs confirmed:

```text
Valid key received
Connected to the server ([10.10.20.10]:1514/tcp)
Agent is now online
```

Dashboard state:

```text
Agent ID: 002
Name:     WIN11-01
IP:       10.10.30.10
OS:       Microsoft Windows 11 Pro
Version:  v4.14.8
Status:   Active
```

---

## 8. Sysmon Centralization

WIN11-01 already had Sysmon installed from Module 04.

The local channel was verified:

```text
Microsoft-Windows-Sysmon/Operational
Enabled: True
```

The Wazuh agent initially collected:

```text
Application
Security
System
```

but not the Sysmon Operational channel.

The following block was added to the Windows Wazuh agent configuration:

```xml
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

After restart, the Wazuh agent log confirmed:

```text
Analyzing event log: 'Microsoft-Windows-Sysmon/Operational'
```

---

## 9. Windows Known-Event Correlation

A unique process marker was generated:

```text
CYBERBLUE_MODULE05_SYSMON_TEST
```

using `cmd.exe`.

Wazuh Threat Hunting returned exactly one matching Sysmon Event ID 1.

The event detail confirmed:

```text
agent.id                           002
agent.ip                           10.10.30.10
agent.name                         WIN11-01
data.win.system.eventID            1
data.win.eventdata.image           C:\Windows\System32\cmd.exe
data.win.eventdata.commandLine     ...CYBERBLUE_MODULE05_SYSMON_TEST...
data.win.eventdata.user            WIN11-01\cyberadmin
```

### Capability demonstrated

> Generated a known Windows process event and correlated its exact command line centrally through Sysmon and Wazuh.

---

## 10. Controlled Ingestion Failure / Recovery

A controlled network-path failure was created without stopping the endpoint agent.

A temporary nftables drop rule was inserted **before** the established/related rule so it could interrupt an already-established Wazuh session:

```text
WIN11-01 10.10.30.10
        ↓
TCP 1514/1515
        ↓
DROP
```

The router counter confirmed packets were actively being dropped.

At the endpoint:

```text
WazuhSvc            Running
TCP 1514 test       Failed
```

This established:

```text
Endpoint agent healthy      ✓
Local logging operational   ✓
SIEM transport unavailable  ✓
```

A unique event was then generated:

```text
CYBERBLUE_MODULE05_INGESTION_GAP_TEST
```

Local Sysmon Event ID 1 confirmed the event existed on WIN11-01.

A Wazuh search during the outage returned:

```text
No results match your search criteria
```

This demonstrated a real central visibility gap while local telemetry continued.

### Recovery

The temporary drop rule was removed.

The permanent TCP 1514/1515 allow rule remained intact.

WIN11-01 logs then showed:

```text
Trying to connect to server ([10.10.20.10]:1514/tcp)
Connected to the server ([10.10.20.10]:1514/tcp)
Agent is now online
```

After reconnection, Wazuh received the event that had been generated during the outage.

The exact command line containing:

```text
CYBERBLUE_MODULE05_INGESTION_GAP_TEST
```

was visible centrally.

A second post-recovery event was generated:

```text
CYBERBLUE_MODULE05_RECOVERY_TEST
```

and was also correlated centrally.

### Operational lesson

```text
ENDPOINT ACTIVITY
      ↓
LOCAL TELEMETRY CONTINUES
      ↓
SIEM TRANSPORT FAILS
      ↓
CENTRAL VISIBILITY GAP
      ↓
TRANSPORT RESTORED
      ↓
AGENT RECONNECTS
      ↓
BUFFERED EVENT FORWARDED
      ↓
NORMAL TELEMETRY RESUMES
```

This exercise demonstrated both **temporary loss of central visibility** and **buffered-event recovery after connectivity returned**.

---

## 11. Final Cleanup and Recovery State

Temporary items were removed:

- Ubuntu-SOC staged Linux agent package;
- Ubuntu-SOC staged Windows MSI;
- temporary Python HTTP staging service;
- temporary router TCP 8080 rule;
- temporary ingestion-test drop rule;
- Linux-Mint copied installer;
- WIN11-01 copied MSI;
- WIN11-01 Module 05 test files.

Persistent configuration retained:

- Wazuh Manager / Indexer / Dashboard;
- hardened Wazuh administrative credential;
- dashboard management binding;
- indexer internal-only port 9200 exposure;
- Linux-Mint Wazuh agent;
- WIN11-01 Wazuh agent;
- Windows Sysmon event-channel subscription;
- permanent least-privilege TCP 1514/1515 router rule.

Final Proxmox recovery snapshots were captured for:

```text
VM100  Ubuntu-SOC
VM101  Linux-Mint
VM102  WIN11-01
VM104  ROUTER-01
```

using the Module 05 completion checkpoint.

---

## Troubleshooting Highlights

### Docker image-pull TLS failure

The first image pull failed with:

```text
tls: bad record MAC
```

Compose validation remained clean. Retrying the pull/start sequence recovered the deployment.

### Password/hash mismatch

A manually transcribed password hash produced:

```text
HTTP 401
Unauthorized
```

Direct indexer authentication testing isolated the problem. SSH copy/paste was then used for reliable credential configuration, the security configuration was reapplied, and the direct test returned:

```text
HTTP 200
```

### Duplicate nftables insertion

During the Windows Wazuh rule addition, duplicate rules were accidentally inserted. Rule handles were inspected, duplicates were removed, and the clean policy was revalidated before persistence.

### Windows configuration-test command mismatch

A Unix-style `wazuh-logcollector -t` validation approach was not available at the attempted Windows path. The Windows validation method was corrected to:

```text
XML well-formedness
      ↓
WazuhSvc restart
      ↓
runtime ossec.log verification
```

The runtime log confirmed the Sysmon event channel was being analyzed.

### Time-window search issue

One Threat Hunting search initially returned no result because the known event had aged outside a 15-minute window. Expanding the search window exposed the expected event.

This reinforced that SIEM investigations must account for time range, timezone display, indexing delay, and active filters.

---

## Evidence Ledger

Evidence is captured under the following checkpoint sequence:

```text
01a-module05-proxmox-capacity-baseline.png
01b-module05-ubuntu-soc-resource-baseline.png
01c-module05-ubuntu-soc-resource-resize.png
01d-module05-ubuntu-soc-storage-expanded.png

02a-module05-wazuh-host-prerequisites.png
02b-module05-wazuh-prerequisites-passed.png

03a-module05-pre-wazuh-snapshot.png
03b-module05-wazuh-repository-staged.png

04a-module05-wazuh-certificates-generated.png

05x-module05-wazuh-image-pull-tls-error.png
05a-module05-wazuh-stack-started.png
05b-module05-wazuh-dashboard-initial-login.png

06a-module05-wazuh-credential-backup.png
06b-module05-wazuh-admin-credential-updated.png
06x-module05-admin-auth-401.png
06c-module05-wazuh-security-config-applied.png
06c2-module05-wazuh-security-config-reapplied.png
06c3-module05-wazuh-indexer-auth-validated.png
06c4-module05-wazuh-stack-restarted.png
06d-module05-wazuh-new-admin-login-validated.png

07a-module05-wazuh-indexer-port-hardened.png
07b-module05-dashboard-after-indexer-hardening.png

08a-module05-linux-mint-pre-agent-network-validation.png
08b-module05-linux-mint-wazuh-port-validation.png
08c-module05-linux-agent-package-staged.png
08d-module05-wazuh-agent-staging-server.png
08e-module05-linux-mint-agent-package-received.png
08f-module05-linux-agent-package-integrity.png
08g-module05-agent-staging-service-removed.png
08h-module05-linux-mint-wazuh-agent-installed.png
08i-module05-linux-mint-agent-config-validated.png
08j-module05-linux-mint-agent-started.png
08k-module05-linux-mint-agent-enrollment-validated.png
08l-module05-linux-mint-dashboard-enrolled.png

09a-module05-linux-known-sudo-event-generated.png
09b-module05-linux-centralized-sudo-event.png
09c-module05-linux-known-event-correlated.png

10a-module05-win11-pre-wazuh-segmentation-baseline.png
10b-module05-router-pre-wazuh-policy.png
10x-module05-router-duplicate-wazuh-rules.png
10c-module05-router-wazuh-policy-added.png
10d-module05-win11-wazuh-ports-allowed.png
10e-module05-router-wazuh-rule-counter-validation.png
10f-module05-router-wazuh-policy-persistent-config.png
10g-module05-router-persistent-policy-reloaded.png
10h-module05-win11-wazuh-policy-persistence-validated.png

11a-module05-win11-agent-package-staged.png
11b-module05-router-temporary-win11-staging-rule.png
11c-module05-win11-staging-server.png
11d-module05-win11-agent-package-received.png
11e-module05-win11-agent-package-integrity.png
11f-module05-win11-staging-path-removed.png
11g-module05-win11-wazuh-agent-installed-configured.png
11h-module05-win11-agent-started-enrollment.png
11i-module05-win11-agent-post-reload-validated.png
11j-module05-win11-dashboard-enrolled.png

12a-module05-win11-wazuh-eventchannel-baseline.png
12b-module05-win11-sysmon-channel-validated.png
12c-module05-win11-wazuh-sysmon-subscription-added.png
12d-module05-win11-wazuh-sysmon-config-validated.png
12e-module05-win11-known-sysmon-event-generated.png
12f-module05-win11-sysmon-event-correlated.png

13a-module05-win11-ingestion-failure-rule-added.png
13b-module05-win11-ingestion-path-failure-validated.png
13c-module05-win11-local-event-during-ingestion-failure.png
13d-module05-win11-central-ingestion-gap-confirmed.png
13e-module05-win11-ingestion-path-restored.png
13f-module05-win11-agent-reconnected.png
13g-module05-outage-event-not-yet-ingested.png
13h-module05-win11-post-recovery-event-generated.png
13i-module05-buffered-outage-event-backfilled.png
13j-module05-post-recovery-telemetry-validated.png

14a-module05-router-final-policy-validation.png
14b-module05-wazuh-final-stack-validation.png
14c-module05-final-agent-status.png

15a-module05-final-snapshots.png
15b-module05-win11-cleanup-complete.png
15c-module05-ubuntu-soc-cleanup-complete.png
15d-module05-linux-mint-cleanup-complete.png
```

---

## Skills Demonstrated

- SIEM architecture planning;
- Proxmox capacity analysis and VM resizing;
- Linux partition/LVM/filesystem expansion;
- Docker and Docker Compose administration;
- Wazuh single-node deployment;
- Wazuh/OpenSearch certificate generation;
- administrative credential rotation;
- OpenSearch `securityadmin.sh` operation;
- direct API authentication testing with `curl`;
- HTTP 401 diagnosis;
- service-exposure hardening;
- host socket validation with `ss`;
- Wazuh Linux agent deployment;
- Wazuh Windows agent deployment;
- offline/controlled package staging;
- SHA-256 package-integrity verification;
- Windows Sysmon event-channel collection;
- Linux sudo-event correlation;
- Sysmon Event ID 1 process correlation;
- nftables rule design and persistence;
- least-privilege cross-segment SIEM transport;
- nftables counter validation;
- controlled telemetry-path failure testing;
- central visibility-gap analysis;
- agent reconnection validation;
- buffered-event recovery;
- post-recovery telemetry validation;
- rollback snapshot discipline;
- evidence-driven troubleshooting;
- portfolio-ready technical documentation.

---

## Technical Build Gate

```text
Host capacity preflight                  PASS
Ubuntu-SOC compute/storage expansion     PASS
Host prerequisites                       PASS
Pre-deployment snapshot                  PASS
Wazuh repository staging                 PASS
Certificate generation                   PASS
Wazuh deployment                         PASS
Dashboard management binding             PASS
Administrative credential hardening      PASS
Direct indexer authentication            PASS
Indexer host-port hardening              PASS
Linux-Mint agent enrollment              PASS
Linux centralized telemetry              PASS
Exact Linux sudo correlation             PASS
WIN11 least-privilege routing            PASS
WIN11 agent enrollment                   PASS
Sysmon collection                        PASS
Exact Windows Sysmon correlation         PASS
Controlled ingestion failure             PASS
Local telemetry during outage            PASS
Central visibility gap                   PASS
Network-path restoration                 PASS
Agent reconnection                       PASS
Buffered outage event backfill           PASS
Post-recovery telemetry                  PASS
Final router cleanup                     PASS
Final Wazuh stack health                 PASS
Both endpoint agents active              PASS
Final snapshots                          PASS
Temporary artifact cleanup               PASS

MODULE 05 TECHNICAL BUILD GATE            COMPLETE ✓
KNOWLEDGE REVIEW                          DEFERRED
INDEPENDENT QUALIFICATION                 DEFERRED
```

---

## Portfolio Summary

> Built and hardened a Wazuh 4.14.8 SIEM on a segmented Proxmox cyber range, enrolled Linux and Windows endpoints, centralized Linux sudo and Windows Sysmon telemetry, correlated known events, implemented least-privilege nftables transport policy, deliberately interrupted SIEM ingestion, demonstrated the resulting visibility gap, restored connectivity, validated agent reconnection and buffered-event backfill, and captured rollback-ready final snapshots.

---

## Next Module

Module 05 technical construction is complete.

Cyber Forge can now progress into **Module 06** while deeper Module 05 knowledge review remains deferred until the wider range has been built.
