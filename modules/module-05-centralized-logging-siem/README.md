# CyberBlue — Module 05
## Centralized Logging & SIEM Foundations

**Status:** TECHNICAL BUILD COMPLETE ✓  
**Platform:** Proxmox VE 9.2.2  
**SIEM implementation:** Wazuh 4.14.8 single-node Docker deployment  
**Primary SIEM host:** VM100 — Ubuntu-SOC  
**Endpoints:** Linux-Mint and WIN11-01  
**Training method:** Principle → Architecture → Build → Validate → Break/Test → Troubleshoot → Restore → Explain → Document → Qualify

> Module 05 moves Cyber Forge from endpoint-local telemetry into centralized security monitoring. This README is written as a build document: it records the architecture, the exact implementation sequence, validation checkpoints, troubleshooting, failure/recovery testing, and the evidence captured at each stage.

---

# Module Objective

Module 04 proved that useful telemetry existed locally on the endpoints.

Module 05 solves the next operational problem:

> **How do we collect, centralize, search, correlate, and investigate security telemetry without logging into every endpoint individually?**

The capability being built is:

```text
ENDPOINT ACTIVITY
      ↓
LOCAL TELEMETRY
      ↓
AGENT / COLLECTOR
      ↓
SECURE TRANSPORT
      ↓
SIEM MANAGER
      ↓
INDEX / STORAGE
      ↓
SEARCH / ALERT / INVESTIGATE
```

Wazuh is the implementation used in Cyber Forge, but the principles apply to SIEM platforms generally.

---

# Final Architecture

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

The Victim network was not broadly opened to the SOC network.

Only this permanent exception was added:

```text
Source:      10.10.30.10
Destination: 10.10.20.10
Protocol:    TCP
Ports:       1514, 1515
Action:      ACCEPT
```

Everything else continues to fall through to the router's default-drop policy.

---

# Build Walkthrough

## 1. Capacity Preflight and Ubuntu-SOC Resize

Before installing Wazuh, I validated that the Proxmox host and Ubuntu-SOC VM had enough CPU, memory, and storage to support the SIEM workload.

![Proxmox capacity baseline](screenshots/01a-module05-proxmox-capacity-baseline.png)

![Ubuntu-SOC resource baseline](screenshots/01b-module05-ubuntu-soc-resource-baseline.png)

The original Ubuntu-SOC allocation was:

```text
2 vCPU
4 GB RAM
32 GB disk
```

I resized VM100 to:

```text
4 vCPU
8 GB RAM
64 GB disk
```

![Ubuntu-SOC resource resize](screenshots/01c-module05-ubuntu-soc-resource-resize.png)

The virtual disk increase had to be extended through the Linux storage stack:

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

Commands used:

```bash
sudo growpart /dev/sda 3
sudo pvresize /dev/sda3
sudo lvextend -l +100%FREE -r /dev/mapper/ubuntu--vg-ubuntu--lv
```

![Ubuntu-SOC storage expanded](screenshots/01d-module05-ubuntu-soc-storage-expanded.png)

Final root filesystem state was approximately:

```text
61 GB total
52 GB available
12% used
```

> The Proxmox thin pool reported an overcommit warning. Physical utilization remained low enough to proceed, but thin-pool growth remains an infrastructure item to monitor.

---

## 2. Validate Wazuh Host Prerequisites

I validated Docker, Git, kernel settings, and Docker Compose before deploying the SIEM.

![Wazuh host prerequisites](screenshots/02a-module05-wazuh-host-prerequisites.png)

Docker Compose v2 was then installed and the prerequisite check was repeated.

![Wazuh prerequisites passed](screenshots/02b-module05-wazuh-prerequisites-passed.png)

Validated environment:

```text
Docker:           29.1.3
Docker Compose:   2.40.3
Git:              2.43.0
vm.max_map_count: 1048576
```

---

## 3. Create Pre-Wazuh Snapshot and Stage Repository

Before introducing Wazuh, I created a rollback point for Ubuntu-SOC.

![Pre-Wazuh snapshot](screenshots/03a-module05-pre-wazuh-snapshot.png)

Snapshot name:

```text
module05-pre-wazuh
```

I then staged the Wazuh Docker repository using the stable version selected for the build:

```text
v4.14.8
```

![Wazuh repository staged](screenshots/03b-module05-wazuh-repository-staged.png)

Deployment path:

```text
~/Wazuh-docker/single-node
```

---

## 4. Generate Wazuh Certificates

The Wazuh Docker deployment requires certificates for the manager, indexer, dashboard, and administrative security operations.

Certificate generation was executed through the Wazuh-supplied Docker Compose generator.

![Wazuh certificates generated](screenshots/04a-module05-wazuh-certificates-generated.png)

The certificate set included:

```text
root CA
admin certificate/key
manager certificate/key
indexer certificate/key
dashboard certificate/key
```

---

## 5. Deploy Wazuh Single-Node Stack

The first image-pull attempt failed with a TLS transport error.

![Wazuh image-pull TLS error](screenshots/05x-module05-wazuh-image-pull-tls-error.png)

Observed error:

```text
tls: bad record MAC
```

The Compose configuration itself validated cleanly, so I treated the problem as a transient image-transfer failure rather than a Wazuh configuration issue.

I retried the image pull and started the stack successfully.

![Wazuh stack started](screenshots/05a-module05-wazuh-stack-started.png)

The running stack contained:

```text
wazuh.manager
wazuh.indexer
wazuh.dashboard
```

The dashboard was bound to the management interface:

```text
192.168.12.227:443 → dashboard:5601
```

I then validated the first successful dashboard login.

![Initial Wazuh dashboard login](screenshots/05b-module05-wazuh-dashboard-initial-login.png)

---

## 6. Harden the Wazuh Administrative Credential

Before changing the default administrative credential, I created configuration backups.

![Wazuh credential backup](screenshots/06a-module05-wazuh-credential-backup.png)

I generated a new OpenSearch password hash and updated the relevant Wazuh configuration.

![Wazuh admin credential updated](screenshots/06b-module05-wazuh-admin-credential-updated.png)

The first direct authentication test failed with HTTP 401.

![Wazuh admin authentication 401](screenshots/06x-module05-admin-auth-401.png)

This was traced to a password/hash mismatch caused by manual transcription through the Proxmox console.

The troubleshooting path was:

```text
Dashboard login failure
        ↓
Direct indexer authentication test
        ↓
HTTP 401
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
```

The security configuration was applied successfully.

![Wazuh security config applied](screenshots/06c-module05-wazuh-security-config-applied.png)

A corrected configuration was then reapplied.

![Wazuh security config reapplied](screenshots/06c2-module05-wazuh-security-config-reapplied.png)

Direct indexer authentication returned HTTP 200.

![Wazuh indexer authentication validated](screenshots/06c3-module05-wazuh-indexer-auth-validated.png)

The full Wazuh stack was restarted.

![Wazuh stack restarted](screenshots/06c4-module05-wazuh-stack-restarted.png)

The new administrative credential was then validated through the dashboard.

![New Wazuh admin login validated](screenshots/06d-module05-wazuh-new-admin-login-validated.png)

### Principle

> A configuration loading successfully does not prove the intended credential works. Authentication must be tested directly.

---

## 7. Remove Unnecessary Host Exposure of Indexer Port 9200

The default Compose configuration exposed the Wazuh indexer API on the Ubuntu-SOC host.

I removed the host-level mapping for TCP 9200 and recreated the indexer container.

![Wazuh indexer port hardened](screenshots/07a-module05-wazuh-indexer-port-hardened.png)

Post-change validation showed:

```text
Indexer container: 9200/tcp
Ubuntu-SOC host:    PORT 9200 NOT LISTENING
```

The dashboard continued to function after the hardening change.

![Dashboard after indexer hardening](screenshots/07b-module05-dashboard-after-indexer-hardening.png)

### Principle

> Expose only the services that must cross a trust boundary.

---

# Linux-Mint Enrollment and Telemetry

## 8. Enroll Linux-Mint as Wazuh Agent 001

Linux-Mint was intentionally kept isolated on the SOC network.

I first validated its address, route state, and reachability to Ubuntu-SOC.

![Linux-Mint pre-agent network validation](screenshots/08a-module05-linux-mint-pre-agent-network-validation.png)

Then I validated the Wazuh communication ports from Linux-Mint:

```text
TCP 1514   reachable
TCP 1515   reachable
```

![Linux-Mint Wazuh port validation](screenshots/08b-module05-linux-mint-wazuh-port-validation.png)

Rather than give Linux-Mint Internet access, I downloaded the Wazuh agent package on Ubuntu-SOC.

![Linux agent package staged](screenshots/08c-module05-linux-agent-package-staged.png)

I temporarily served the package only on the SOC-side interface:

```text
10.10.20.10:8080
```

![Wazuh agent staging server](screenshots/08d-module05-wazuh-agent-staging-server.png)

Linux-Mint pulled the package from Ubuntu-SOC.

![Linux-Mint agent package received](screenshots/08e-module05-linux-mint-agent-package-received.png)

I compared SHA-256 hashes to prove the transferred file was byte-for-byte identical.

![Linux agent package integrity](screenshots/08f-module05-linux-agent-package-integrity.png)

After transfer, the temporary HTTP server was stopped and port 8080 was confirmed closed.

![Linux agent staging service removed](screenshots/08g-module05-agent-staging-service-removed.png)

The Wazuh agent package was installed.

![Linux-Mint Wazuh agent installed](screenshots/08h-module05-linux-mint-wazuh-agent-installed.png)

The agent configuration was validated to confirm:

```text
Manager:  10.10.20.10
Port:     1514
Protocol: TCP
Version:  4.14.8-1
```

![Linux-Mint agent config validated](screenshots/08i-module05-linux-mint-agent-config-validated.png)

The agent service was started.

![Linux-Mint Wazuh agent started](screenshots/08j-module05-linux-mint-agent-started.png)

Enrollment logs showed:

```text
Requesting a key from server: 10.10.20.10
Valid key received
Trying to connect to server ([10.10.20.10]:1514/tcp)
Connected to the server ([10.10.20.10]:1514/tcp)
```

![Linux-Mint agent enrollment validated](screenshots/08k-module05-linux-mint-agent-enrollment-validated.png)

The Wazuh dashboard showed Linux-Mint as active Agent 001.

![Linux-Mint dashboard enrolled](screenshots/08l-module05-linux-mint-dashboard-enrolled.png)

---

## 9. Correlate a Known Linux sudo Event

I generated a known privileged event on Linux-Mint:

```bash
sudo /usr/bin/id
```

![Known Linux sudo event generated](screenshots/09a-module05-linux-known-sudo-event-generated.png)

Wazuh received the corresponding sudo activity.

![Linux centralized sudo event](screenshots/09b-module05-linux-centralized-sudo-event.png)

I opened the event detail and verified the exact command and identity fields:

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

![Linux known event correlated](screenshots/09c-module05-linux-known-event-correlated.png)

### Capability demonstrated

> Generated a known privileged Linux event and correlated the exact command, source user, destination user, endpoint identity, and raw log centrally in Wazuh.

---

# WIN11-01 Enrollment and Sysmon Centralization

## 10. Extend the Router Policy for Wazuh Only

Before modifying ROUTER-01, I proved WIN11-01 could not reach Wazuh TCP 1514/1515.

![WIN11 pre-Wazuh segmentation baseline](screenshots/10a-module05-win11-pre-wazuh-segmentation-baseline.png)

I inspected the existing nftables policy before changing it.

![Router pre-Wazuh policy](screenshots/10b-module05-router-pre-wazuh-policy.png)

During rule insertion, duplicate Wazuh rules were accidentally added.

![Duplicate Wazuh router rules](screenshots/10x-module05-router-duplicate-wazuh-rules.png)

The duplicate handles were removed and only one narrow exception was retained.

![Router Wazuh policy added](screenshots/10c-module05-router-wazuh-policy-added.png)

Permanent rule:

```nft
iifname "ens19" oifname "ens18" ip saddr 10.10.30.10 ip daddr 10.10.20.10 tcp dport { 1514, 1515 } counter accept
```

WIN11-01 then reached both Wazuh ports.

![WIN11 Wazuh ports allowed](screenshots/10d-module05-win11-wazuh-ports-allowed.png)

I validated that the intended nftables rule counter incremented.

![Router Wazuh rule counter validation](screenshots/10e-module05-router-wazuh-rule-counter-validation.png)

The persistent nftables configuration was updated and syntax-checked.

![Router Wazuh persistent config](screenshots/10f-module05-router-wazuh-policy-persistent-config.png)

The persistent ruleset was reloaded.

![Router persistent policy reloaded](screenshots/10g-module05-router-persistent-policy-reloaded.png)

WIN11-01 connectivity still worked after reload.

![WIN11 Wazuh policy persistence validated](screenshots/10h-module05-win11-wazuh-policy-persistence-validated.png)

---

## 11. Install and Enroll the Windows Wazuh Agent

The Windows MSI was downloaded and staged on Ubuntu-SOC.

![WIN11 agent package staged](screenshots/11a-module05-win11-agent-package-staged.png)

A temporary nftables rule allowed only WIN11-01 to reach Ubuntu-SOC TCP 8080.

![Temporary WIN11 staging rule](screenshots/11b-module05-router-temporary-win11-staging-rule.png)

The temporary HTTP server was started on the SOC interface.

![WIN11 staging server](screenshots/11c-module05-win11-staging-server.png)

WIN11-01 downloaded the MSI.

![WIN11 agent package received](screenshots/11d-module05-win11-agent-package-received.png)

I compared SHA-256 hashes between Ubuntu-SOC and WIN11-01.

![WIN11 agent package integrity](screenshots/11e-module05-win11-agent-package-integrity.png)

After the transfer, I removed the temporary staging path.

![WIN11 staging path removed](screenshots/11f-module05-win11-staging-path-removed.png)

The Windows Wazuh agent was installed and configured for:

```text
Manager:  10.10.20.10
Port:     1514
Protocol: TCP
```

![WIN11 Wazuh agent installed and configured](screenshots/11g-module05-win11-wazuh-agent-installed-configured.png)

The service was started and enrollment began.

![WIN11 agent started and enrollment](screenshots/11h-module05-win11-agent-started-enrollment.png)

The agent reloaded its shared configuration and returned to a running/online state.

![WIN11 agent post-reload validated](screenshots/11i-module05-win11-agent-post-reload-validated.png)

The Wazuh dashboard showed WIN11-01 as active Agent 002.

![WIN11 dashboard enrolled](screenshots/11j-module05-win11-dashboard-enrolled.png)

---

## 12. Add Sysmon to Centralized Collection

The Wazuh agent initially collected the standard Windows event channels but not Sysmon.

![WIN11 Wazuh event-channel baseline](screenshots/12a-module05-win11-wazuh-eventchannel-baseline.png)

I verified that the Sysmon Operational channel existed locally and was active.

![WIN11 Sysmon channel validated](screenshots/12b-module05-win11-sysmon-channel-validated.png)

I added the following block to the Windows Wazuh agent configuration:

```xml
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

![WIN11 Wazuh Sysmon subscription added](screenshots/12c-module05-win11-wazuh-sysmon-subscription-added.png)

After the service restart, the runtime log confirmed:

```text
Analyzing event log: 'Microsoft-Windows-Sysmon/Operational'
```

![WIN11 Wazuh Sysmon config validated](screenshots/12d-module05-win11-wazuh-sysmon-config-validated.png)

I generated a unique known process event:

```text
CYBERBLUE_MODULE05_SYSMON_TEST
```

![Known WIN11 Sysmon event generated](screenshots/12e-module05-win11-known-sysmon-event-generated.png)

Wazuh Threat Hunting correlated the exact Sysmon Event ID 1 and command line centrally.

![WIN11 Sysmon event correlated](screenshots/12f-module05-win11-sysmon-event-correlated.png)

### Capability demonstrated

> Generated a known Windows process event and correlated its exact command line centrally through Sysmon and Wazuh.

---

# Controlled Ingestion Failure and Recovery

## 13. Break the SIEM Transport Path Without Stopping the Agent

To test operational resilience, I deliberately broke only the WIN11-01 → Wazuh transport path.

A temporary drop rule was inserted before the established/related rule so it could interrupt an existing Wazuh session.

![WIN11 ingestion failure rule added](screenshots/13a-module05-win11-ingestion-failure-rule-added.png)

The endpoint remained healthy while the SIEM transport path failed.

![WIN11 ingestion path failure validated](screenshots/13b-module05-win11-ingestion-path-failure-validated.png)

Validation state:

```text
WazuhSvc            Running
TCP 1514            Blocked
Local Sysmon        Working
Central transport   Broken
```

While the path was blocked, I generated a unique event:

```text
CYBERBLUE_MODULE05_INGESTION_GAP_TEST
```

Sysmon recorded it locally.

![Local event during ingestion failure](screenshots/13c-module05-win11-local-event-during-ingestion-failure.png)

A Wazuh search during the outage returned no central result.

![Central ingestion gap confirmed](screenshots/13d-module05-win11-central-ingestion-gap-confirmed.png)

This proved:

```text
Activity occurred locally            ✓
Endpoint telemetry continued         ✓
SIEM transport was unavailable       ✓
Central visibility gap existed       ✓
```

I then removed the temporary drop rule and restored the path.

![WIN11 ingestion path restored](screenshots/13e-module05-win11-ingestion-path-restored.png)

WIN11-01 reconnected to the Wazuh manager.

![WIN11 agent reconnected](screenshots/13f-module05-win11-agent-reconnected.png)

Immediately after reconnection, the outage event had not yet appeared in the SIEM.

![Outage event not yet ingested](screenshots/13g-module05-outage-event-not-yet-ingested.png)

I generated a separate post-recovery event:

```text
CYBERBLUE_MODULE05_RECOVERY_TEST
```

![WIN11 post-recovery event generated](screenshots/13h-module05-win11-post-recovery-event-generated.png)

Wazuh later backfilled the buffered outage event.

![Buffered outage event backfilled](screenshots/13i-module05-buffered-outage-event-backfilled.png)

The new post-recovery event was also received normally.

![Post-recovery telemetry validated](screenshots/13j-module05-post-recovery-telemetry-validated.png)

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

---

# Final Validation and Cleanup

## 14. Validate the Final Cyber Forge SIEM State

I inspected the final ROUTER-01 policy and confirmed:

```text
temporary ingestion drop rule     removed
temporary TCP 8080 rule           removed
permanent Wazuh TCP 1514/1515     present
default drop                      present
```

![Router final policy validation](screenshots/14a-module05-router-final-policy-validation.png)

I then validated the Wazuh stack:

```text
wazuh.manager      UP
wazuh.indexer      UP
wazuh.dashboard    UP
host TCP 9200      NOT LISTENING
```

![Wazuh final stack validation](screenshots/14b-module05-wazuh-final-stack-validation.png)

Finally, both enrolled endpoints were active:

```text
001  linux-mint   10.10.20.11   Active
002  WIN11-01     10.10.30.10   Active
```

![Module 05 final agent status](screenshots/14c-module05-final-agent-status.png)

---

## 15. Create Final Snapshots and Remove Temporary Artifacts

I created final Module 05 recovery snapshots for:

```text
VM100  Ubuntu-SOC
VM101  Linux-Mint
VM102  WIN11-01
VM104  ROUTER-01
```

![Module 05 final snapshots](screenshots/15a-module05-final-snapshots.png)

I then removed temporary installation/test artifacts from WIN11-01.

![WIN11 cleanup complete](screenshots/15b-module05-win11-cleanup-complete.png)

The Ubuntu-SOC staging directory was cleaned and the temporary HTTP server was confirmed stopped.

![Ubuntu-SOC cleanup complete](screenshots/15c-module05-ubuntu-soc-cleanup-complete.png)

The copied Linux Wazuh installer was removed from Linux-Mint.

![Linux-Mint cleanup complete](screenshots/15d-module05-linux-mint-cleanup-complete.png)

Persistent configuration retained:

- Wazuh Manager / Indexer / Dashboard
- hardened administrative credential
- dashboard management binding
- indexer internal-only port 9200
- Linux-Mint Wazuh agent
- WIN11-01 Wazuh agent
- Sysmon event-channel collection
- permanent least-privilege TCP 1514/1515 router rule

---

# Troubleshooting Highlights

## Docker image-pull TLS failure

The first image pull failed with:

```text
tls: bad record MAC
```

Compose validation remained clean, so the pull/start sequence was retried successfully.

## Password/hash mismatch

Manual hash transcription through the console caused an HTTP 401 authentication failure. Direct indexer testing isolated the problem, and SSH was used to rebuild the credential configuration reliably.

## Duplicate nftables rule insertion

Duplicate Windows Wazuh rules were accidentally inserted. I inspected rule handles, removed duplicates, and revalidated the clean policy before making it persistent.

## Windows configuration-test mismatch

A Unix-style `wazuh-logcollector -t` validation path was not available at the attempted Windows location. I corrected the validation method to:

```text
XML well-formedness
      ↓
WazuhSvc restart
      ↓
runtime ossec.log validation
```

## Threat Hunting time-window issue

One expected event disappeared from a 15-minute search window while troubleshooting. Expanding the Wazuh search range exposed the expected event and reinforced the need to account for time range, timezone display, indexing delay, and active filters during SIEM investigations.

---

# Technical Build Gate

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

# Skills Demonstrated

- SIEM architecture planning
- Proxmox capacity analysis and VM resizing
- Linux partition/LVM/filesystem expansion
- Docker and Docker Compose administration
- Wazuh single-node deployment
- Wazuh/OpenSearch certificate generation
- administrative credential rotation
- OpenSearch `securityadmin.sh`
- direct API authentication testing with `curl`
- HTTP 401 diagnosis
- service-exposure hardening
- Wazuh Linux agent deployment
- Wazuh Windows agent deployment
- controlled/offline package staging
- SHA-256 package-integrity verification
- Windows Sysmon event-channel collection
- Linux sudo-event correlation
- Sysmon Event ID 1 process correlation
- nftables rule design and persistence
- least-privilege cross-segment SIEM transport
- nftables counter validation
- controlled telemetry-path failure testing
- central visibility-gap analysis
- agent reconnection validation
- buffered-event recovery
- post-recovery telemetry validation
- rollback snapshot discipline
- evidence-driven troubleshooting
- portfolio-ready technical documentation

---

# Portfolio Summary

> Built and hardened a Wazuh 4.14.8 SIEM on a segmented Proxmox cyber range, enrolled Linux and Windows endpoints, centralized Linux sudo and Windows Sysmon telemetry, correlated known events, implemented least-privilege nftables transport policy, deliberately interrupted SIEM ingestion, demonstrated the resulting visibility gap, restored connectivity, validated agent reconnection and buffered-event backfill, and captured rollback-ready final snapshots.

---

# Evidence Index

The full evidence set is stored in:

```text
modules/module-05-centralized-logging-siem/screenshots/
```

See:

**[README-EVIDENCE.md](screenshots/README-EVIDENCE.md)**

for the complete evidence ledger.

---

# Next Module

Module 05 technical construction is complete.

Cyber Forge can now progress into **Module 06** while deeper Module 05 knowledge review remains deferred until the wider range has been built.
