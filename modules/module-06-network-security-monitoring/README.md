# CyberBlue — Module 06

![CyberBlue Module 06 — Network Security Monitoring](assets/module-banner.webp)

## Network Security Monitoring

**Status:** BUILD COMPLETE ✓  
**Current checkpoint:** Technical Build Gate passed — passive NSM, detection tuning, SIEM integration, controlled visibility failure/recovery, and post-reboot persistence validated  
**Platform:** Proxmox VE 9.2.2  
**NSM implementation:** Suricata 7.0.3 on VM105 — NSM-01  
**SIEM integration:** Wazuh 4.14.8  
**Training method:** Principle → Architecture → Build → Validate → Break/Test → Troubleshoot → Restore → Explain → Document → Qualify

> Module 06 moves Cyber Forge from endpoint and SIEM telemetry into **passive network security monitoring**. This README follows the same build-document format used in Modules 02–05: architecture, implementation sequence, validation checkpoints, troubleshooting, and evidence embedded at the stage where it was captured.

---

# Module Objective

Module 05 established centralized endpoint telemetry in Wazuh.

Module 06 addresses the next operational problem:

> **How do we observe network behavior between systems, detect suspicious patterns, tune the resulting detections, and present those events to an analyst in the SIEM?**

The capability being built is:

```text
NETWORK ACTIVITY
      ↓
OBSERVATION POINT
      ↓
PASSIVE PACKET CAPTURE
      ↓
FLOW / PROTOCOL INSPECTION
      ↓
DETECTION LOGIC
      ↓
ALERT
      ↓
SIEM INGESTION
      ↓
ANALYST INVESTIGATION
```

The goal is not simply to install Suricata. The goal is to prove that the sensor can see the right traffic, produce useful detections, reduce avoidable alert noise, and deliver actionable telemetry to Wazuh.

---

# Core Principle

> **A network sensor is useful only when it can see the traffic that matters, detect meaningful behavior, and deliver actionable telemetry to an analyst.**

A healthy Suricata process does not by itself prove useful monitoring.

Module 06 therefore validates:

- sensor placement;
- packet visibility;
- third-party traffic observation;
- signature processing;
- behavior-based detection;
- alert tuning;
- flow-level investigation; and
- end-to-end SIEM ingestion.

---

# Final Architecture — Qualified State

```text
                         MANAGEMENT LAN
                         192.168.12.0/24
                                |
                              vmbr0
                                |
                   +------------+-------------+
                   |                          |
              Ubuntu-SOC                  NSM-01
           Wazuh single-node          ens18 192.168.12.135
            192.168.12.227                management
                                              |
                                              |
                                       ens19 — no IPv4
                                              |
                                            vmbr20
                                              ^
                                              |
                                   mirrored ROUTER-01 traffic
                                              |
                               +--------------+--------------+
                               |                             |
                          Linux-Mint                     ROUTER-01
                          10.10.20.11                    10.10.20.1
```

### NSM-01

```text
VM 105 — NSM-01
OS:        Ubuntu Server 24.04
CPU:       2 vCPU
Memory:    4 GiB
Disk:      32 GiB

ens18 → vmbr0  → management / SSH
        192.168.12.135/24

ens19 → vmbr20 → passive monitoring
        no IPv4 address
```

Suricata listens on `ens19`, keeping the management plane and passive monitoring plane separate.

---

# Build Walkthrough

## 1. Capacity Preflight and NSM-01 Provisioning

Before introducing another security workload, I reviewed the Proxmox host for available memory, storage, and active VM pressure.

![Module 06 Proxmox capacity preflight](screenshots/01a-module06-proxmox-capacity-preflight.webp)

The host had sufficient memory headroom to proceed, and the guest filesystem review from the previous SIEM work confirmed that the Wazuh data footprint was legitimate rather than an immediate storage fault.

NSM-01 was provisioned as:

```text
VM ID:     105
Name:      NSM-01
OS:        Ubuntu Server 24.04
CPU:       2 vCPU
Memory:    4096 MiB
Disk:      32 GiB
net0:      VirtIO → vmbr0
```

The management interface became:

```text
ens18 → 192.168.12.135/24
```

OpenSSH was installed so the remaining work could be performed through a reliable terminal session.

---

## 2. Deploy and Validate Suricata

Suricata 7.0.3 was installed on NSM-01.

The first service start failed because the default capture configuration referenced `eth0`, while the actual interface was `ens18`.

Observed error:

```text
Failure when trying to get MTU via ioctl for 'eth0':
No such device
```

The AF_PACKET capture interface was corrected without globally replacing every interface reference in the configuration.

The Emerging Threats Open ruleset was installed using:

```bash
sudo suricata-update
```

Result:

```text
53,038 enabled rules
/var/lib/suricata/rules/suricata.rules
```

Configuration validation:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml
```

Live EVE JSON telemetry confirmed DNS, HTTP, IPv4, IPv6, flow, and multicast/broadcast processing.

### Principle

> Service health is not enough. The capture interface, ruleset, and actual packet processing must all be validated.

---

## 3. Create the First Controlled Detection

A local ICMP signature was created:

```text
alert icmp any any -> any any (msg:"CYBER FORGE - ICMP Detection Test"; itype:8; sid:1000001; rev:1;)
```

Controlled ICMP traffic from NSM-01 to `8.8.8.8` produced four matching alerts.

![First Suricata detection](screenshots/02a-module06-first-suricata-detection.webp)

This proved the first complete detection path:

```text
packet capture
    ↓
rule evaluation
    ↓
signature match
    ↓
EVE JSON alert
```

### Capability demonstrated

> Created, loaded, and validated a custom Suricata rule against known traffic.

---

## 4. Build the Passive Monitoring Path

The first ICMP test proved that Suricata could inspect traffic generated by NSM-01 itself, but a network sensor must also observe traffic generated by other systems.

A second NSM-01 virtual NIC was added:

```text
net1 → vmbr20
       ↓
     ens19
       ↓
  no IPv4 address
```

Suricata was moved from `ens18` to `ens19`.

Simply placing NSM-01 on the same bridge was not enough. Proxmox had to copy the target traffic to the sensor.

The relevant tap mappings were:

```text
tap104i0 → ROUTER-01 net0 / vmbr20
tap105i1 → NSM-01 net1 / vmbr20
```

Linux traffic control (`tc`) was used to mirror ROUTER-01 vmbr20 ingress and egress traffic to NSM-01.

The persistent mirror implementation is preserved in:

```text
configs/proxmox-vmbr20-mirror.sh
```

Linux-Mint then generated ICMP traffic:

```text
10.10.20.11 → 10.10.20.1
```

Suricata on the unaddressed `ens19` interface detected the third-party traffic.

![Passive mirrored Suricata detection](screenshots/02b-module06-passive-mirrored-detection.webp)

### Principle

> Passive monitoring depends on the observation point. Installing an IDS on the same subnet does not guarantee visibility into unrelated traffic.

---

## 5. Validate Protocol-Aware Inspection

A controlled request was sent from Linux-Mint to ROUTER-01 TCP/22 using an HTTP-style client.

Packet capture on `ens19` showed the TCP exchange and SSH service response.

Suricata also generated application-layer anomaly telemetry because the observed application behavior did not match the expected service interaction.

This demonstrated that NSM can interpret protocol behavior rather than operating only on IP addresses and port numbers.

---

## 6. Create a Behavior-Based TCP SYN Detection

A second custom rule was created to identify rapid TCP SYN activity from one source:

```text
alert tcp any any -> any any (msg:"CYBER FORGE - TCP SYN Scan Threshold"; flags:S; flow:stateless; detection_filter:track by_src, count 10, seconds 5; sid:1000002; rev:1;)
```

Linux-Mint generated controlled connection attempts across 50 destination ports on ROUTER-01.

The detection worked, but once the threshold was crossed the original rule produced repeated alerts.

![Initial TCP SYN threshold detection](screenshots/03a-module06-tcp-syn-threshold-detection.webp)

That created a realistic detection-engineering problem:

```text
Detection works
     ↓
Duplicate alerts accumulate
     ↓
Signal-to-noise decreases
     ↓
Rule requires tuning
```

---

## 7. Tune the Detection and Retest the Same Behavior

The rule was revised to use `threshold:type both`:

```text
alert tcp any any -> any any (msg:"CYBER FORGE - TCP SYN Scan Threshold"; flags:S; flow:stateless; threshold:type both, track by_src, count 10, seconds 5; sid:1000002; rev:2;)
```

Before restarting Suricata, the configuration was validated:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml
```

The exact same 50-port behavior was replayed.

### Before tuning

The scan produced multiple duplicate alerts.

### After tuning

The same behavior produced one clean alert for the interval.

![Tuned TCP SYN detection](screenshots/03b-module06-tuned-syn-detection.webp)

### Principle

> A detection that technically works but overwhelms the analyst is not a well-tuned detection.

The exercise demonstrated:

```text
Detect
  ↓
Identify noise
  ↓
Modify rule
  ↓
Validate syntax
  ↓
Replay identical behavior
  ↓
Compare result
```

The current local rules are preserved in:

```text
configs/suricata-local.rules
```

---

## 8. Investigate the TCP SYN Alert

The tuned event identified:

```text
Source:        10.10.20.11
Destination:   10.10.20.1
Protocol:      TCP
Signature:     CYBER FORGE - TCP SYN Scan Threshold
Signature ID:  1000002
Revision:      2
Severity:      3
Action:        allowed
Sensor:        ens19
```

Flow records showed rapid connections to many destination ports on one target.

Most probes closed quickly. TCP/22 showed additional bidirectional interaction, consistent with the reachable SSH service observed during protocol inspection.

### Preliminary disposition

> **True Positive — Controlled Reconnaissance.** A single internal host generated rapid TCP SYN activity across multiple ports on ROUTER-01. The activity exceeded the configured scan threshold and was detected by the passive NSM sensor. The activity was authorized as part of the Cyber Forge lab exercise; no containment was required.

### Analyst finding

> **True Positive — Controlled Reconnaissance.** Alert and flow correlation showed a single internal source, `10.10.20.11`, generating rapid TCP SYN activity across multiple destination ports on `10.10.20.1`. The behavior crossed the configured threshold and was detected by the passive NSM sensor. The traffic was authorized lab activity, so no containment was required. The evidence supports the detection as a valid scan/reconnaissance signal rather than a false positive.

---

# Suricata → Wazuh Integration

## 9. Enroll NSM-01 as Wazuh Agent 003

The Wazuh 4.14.8 agent was installed on NSM-01.

The agent was configured to collect:

```text
/var/log/suricata/eve.json
```

Configuration block:

```xml
<localfile>
  <log_format>json</log_format>
  <location>/var/log/suricata/eve.json</location>
</localfile>
```

The first agent restart failed because the new `<localfile>` block had been placed outside an `<ossec_config>` section.

After correcting the XML structure, both Wazuh configuration tests completed without errors:

```bash
sudo /var/ossec/bin/wazuh-logcollector -t
sudo /var/ossec/bin/wazuh-agentd -t
```

![Wazuh agent configuration validation](screenshots/04a-module06-wazuh-agent-validation.webp)

The service then started successfully, including:

```text
wazuh-agentd
wazuh-syscheckd
wazuh-logcollector
wazuh-modulesd
```

The agent log confirmed:

```text
Analyzing file: '/var/log/suricata/eve.json'
```

The reusable collection block is preserved in:

```text
configs/wazuh-suricata-localfile.xml
```

---

## 10. Validate Suricata Alert Ingestion in Wazuh

A fresh controlled SYN-scan test was generated after the Wazuh agent was online.

Wazuh Threat Hunting returned the Suricata alert under:

```text
rule.groups: suricata
```

![Suricata alert ingested into Wazuh](screenshots/04b-module06-suricata-wazuh-integration.webp)

The visible event confirmed:

```text
agent.name        NSM-01
rule.description  Suricata: Alert - CYBER FORGE - TCP SYN Scan Threshold
rule.level        3
rule.id           86601
```

### Capability demonstrated

> Proved that Suricata EVE JSON telemetry could traverse the full NSM → Wazuh pipeline and appear in the analyst-facing Threat Hunting interface.

---

## 11. Inspect the Suricata Event in Wazuh

The Wazuh document detail view exposed the original Suricata fields.

![Wazuh Suricata alert details](screenshots/04c-module06-wazuh-alert-details.webp)

![Wazuh Suricata rule classification](screenshots/04d-module06-wazuh-rule-classification.webp)

Validated fields included:

```text
agent.id                 003
agent.ip                 192.168.12.135
agent.name               NSM-01
data.alert.action        allowed
data.alert.rev           2
data.alert.severity      3
data.alert.signature     CYBER FORGE - TCP SYN Scan Threshold
data.alert.signature_id  1000002
data.src_ip              10.10.20.11
data.dest_ip             10.10.20.1
data.dest_port           8
data.in_iface            ens19
data.proto               TCP
rule.groups              ids, suricata
rule.id                  86601
rule.level               3
rule.firedtimes          1
```

The rule-classification evidence confirms that Wazuh parsed the Suricata event under the expected security groups and rule:

```text
rule.groups  ids, suricata
rule.id      86601
rule.level   3
```

This provides a second layer of validation: the event was not merely transported to Wazuh; it was recognized and classified as Suricata/IDS telemetry.

This validated the complete path:

```text
Linux-Mint
   ↓
ROUTER-01 traffic
   ↓
Proxmox traffic mirror
   ↓
NSM-01 / ens19
   ↓
Suricata
   ↓
eve.json
   ↓
Wazuh Agent 003
   ↓
Wazuh Manager
   ↓
Threat Hunting
   ↓
Field-level investigation
```

---

# Controlled Visibility Failure, Recovery & Persistence Qualification

## 12. Prove the Post-Reboot Blind Spot

A full Proxmox host shutdown/restart was used as the controlled failure condition.

After the first restart:

- Suricata was **active**;
- the Wazuh agent was **active**;
- `ens19` was **DOWN**; and
- the Proxmox `tc` mirror filters were absent.

![Post-reboot monitoring-path failure](screenshots/05a-module06-post-reboot-monitoring-path-failure.webp)

This demonstrated an important NSM principle:

> **A healthy security service does not guarantee healthy telemetry.**

The same controlled TCP SYN behavior was replayed while the monitoring path was broken. The latest Suricata alert timestamp remained unchanged before and after the test.

![Blind-spot validation](screenshots/05b-module06-blind-spot-validation.webp)

That proved a real visibility gap:

```text
Traffic generated
      ↓
ROUTER-01 receives it
      ↓
Mirror absent + ens19 down
      ↓
Suricata service still healthy
      ↓
No new alert
```

### Capability demonstrated

> Distinguished service availability from telemetry-path availability and proved the blind spot with a repeatable test.

---

## 13. Restore the Monitoring Path

The passive interface was made persistent with Netplan:

```yaml
network:
  version: 2
  ethernets:
    ens19:
      dhcp4: false
      dhcp6: false
      link-local: []
      optional: true
```

The reusable configuration is preserved in:

```text
configs/99-nsm-monitor.yaml
```

The Proxmox mirror was rebuilt using an idempotent script that waits for both tap devices, removes any stale `clsact` state, and recreates ingress and egress mirroring.

The mirror was then managed by systemd:

```text
cyberforge-vmbr20-mirror.service
```

The reusable files are preserved in:

```text
configs/proxmox-vmbr20-mirror.sh
configs/cyberforge-vmbr20-mirror.service
```

After restoring the path, the exact same SYN behavior produced a fresh Suricata alert.

![Monitoring-path recovery](screenshots/05c-module06-monitoring-path-recovery.webp)

### Principle

> Recovery is not proven by configuration state alone. The original behavior must be replayed and detected again.

---

## 14. Validate Persistence Across a Full Host Reboot

The required infrastructure VMs were configured to start automatically:

```text
VM 104 — ROUTER-01   startup order 1
VM 105 — NSM-01      startup order 2
VM 100 — Ubuntu-SOC  startup order 3
```

The mirror service was enabled at boot.

After a full Proxmox reboot, without manually bringing up `ens19` or manually running the mirror script:

- `ens19` returned **UP** with no IP address;
- Suricata returned **active**;
- the Wazuh agent returned **active**;
- the mirror service returned **active (exited)**;
- ingress mirroring returned automatically; and
- egress mirroring returned automatically.

![Post-reboot persistence validation](screenshots/05d-module06-post-reboot-persistence-validation.webp)

The same controlled SYN activity was then replayed from Linux-Mint.

A new post-reboot Suricata alert was generated:

```text
timestamp:  2026-10-06T01:06:24.649565+0000
src_ip:     10.10.20.11
dest_ip:    10.10.20.1
signature:  CYBER FORGE - TCP SYN Scan Threshold
```

![Post-reboot Suricata detection](screenshots/05e-module06-post-reboot-detection-validation.webp)

Wazuh Threat Hunting then displayed the corresponding fresh Suricata event under rule `86601`.

![Post-reboot Wazuh validation](screenshots/05f-module06-post-reboot-wazuh-validation.webp)

This completed the final qualification path:

```text
PVE reboot
   ↓
Infrastructure VM autostart
   ↓
Passive NIC restored
   ↓
Traffic mirror restored
   ↓
Suricata active
   ↓
Wazuh agent active
   ↓
Controlled behavior replayed
   ↓
Fresh Suricata detection
   ↓
Fresh Wazuh event
   ↓
Analyst visibility restored
```

### Qualification result

> **PASS — Module 06 monitoring capability survives a host reboot and automatically restores passive traffic visibility, Suricata detection, Wazuh ingestion, and analyst-facing event visibility.**

---

# Troubleshooting & Lessons Learned

## Suricata referenced the wrong capture interface

**Symptom:** Suricata failed to start.

**Root cause:** The configuration referenced `eth0`; NSM-01 used predictable interface names.

**Resolution:** Corrected only the AF_PACKET capture interface and validated with `suricata -T`.

**Lesson:** Avoid global configuration replacement when the fault is isolated to one stanza.

---

## Custom rule file was accidentally contaminated

**Symptom:**

```text
detect-parse: An invalid action "af-packet:" was given
```

**Root cause:** Part of the YAML AF_PACKET configuration was accidentally pasted into `local.rules`.

**Resolution:** Rebuilt `local.rules` with only valid signatures and validated the Suricata configuration before restart.

**Lesson:** Syntax validation should precede service restart after detection-rule changes.

---

## Wazuh rejected the Suricata localfile configuration

**Symptom:**

```text
Invalid element in the configuration: 'localfile'
```

**Root cause:** The Suricata `<localfile>` block was outside the active `<ossec_config>` section.

**Resolution:** Moved the block inside the Wazuh XML structure and tested both `wazuh-logcollector` and `wazuh-agentd` before restarting the agent.

**Lesson:** A telemetry integration is not complete until both configuration parsing and event flow are validated.

---

# Persistence Remediation

The runtime-only conditions discovered during testing were corrected and validated.

### Passive monitoring interface

`ens19` is now managed persistently through:

```text
/etc/netplan/99-nsm-monitor.yaml
```

The interface comes up automatically without DHCP, IPv6 autoconfiguration, or link-local addressing.

### Proxmox traffic mirror

The traffic mirror is now rebuilt automatically by:

```text
/usr/local/sbin/cyberforge-vmbr20-mirror.sh
/etc/systemd/system/cyberforge-vmbr20-mirror.service
```

The service waits for both `tap104i0` and `tap105i1` before creating the mirror and is enabled at boot.

### Infrastructure startup ordering

```text
ROUTER-01   VM 104 → order 1
NSM-01      VM 105 → order 2
Ubuntu-SOC  VM 100 → order 3
```

A full host reboot confirmed that the complete monitoring path returns automatically.

---

# Evidence Status

The current Module 06 build evidence is now embedded throughout this README at the stage where each validation occurred:

```text
01a-module06-proxmox-capacity-preflight.webp
02a-module06-first-suricata-detection.webp
02b-module06-passive-mirrored-detection.webp
03a-module06-tcp-syn-threshold-detection.webp
03b-module06-tuned-syn-detection.webp
04a-module06-wazuh-agent-validation.webp
04b-module06-suricata-wazuh-integration.webp
04c-module06-wazuh-alert-details.webp
04d-module06-wazuh-rule-classification.webp
05a-module06-post-reboot-monitoring-path-failure.webp
05b-module06-blind-spot-validation.webp
05c-module06-monitoring-path-recovery.webp
05d-module06-post-reboot-persistence-validation.webp
05e-module06-post-reboot-detection-validation.webp
05f-module06-post-reboot-wazuh-validation.webp
```

The screenshot is the evidence; the surrounding explanation records what was being tested, what the result proved, and why it matters.

---

# Skills Demonstrated

Module 06 work to date demonstrates practical experience with:

- Suricata IDS / NSM deployment;
- AF_PACKET capture configuration;
- Emerging Threats Open rules;
- EVE JSON telemetry;
- custom Suricata signatures;
- ICMP detection;
- behavior-based TCP SYN detection;
- threshold tuning and alert-noise reduction;
- repeatable before/after detection testing;
- passive monitoring architecture;
- dual-NIC sensor design;
- Proxmox Linux bridges;
- Linux `tc` traffic mirroring;
- third-party packet observation;
- `tcpdump` validation;
- protocol-aware NSM interpretation;
- flow and alert correlation;
- Wazuh agent enrollment;
- Suricata-to-Wazuh log ingestion;
- Wazuh Threat Hunting;
- SIEM field-level investigation; and
- evidence-driven troubleshooting;
- monitoring-path failure analysis;
- telemetry blind-spot validation;
- Netplan persistence for an unaddressed monitoring NIC;
- systemd-managed Proxmox traffic mirroring;
- infrastructure VM startup sequencing; and
- post-reboot NSM/SIEM qualification.

---

# Technical Build Gate

Module 06 technical qualification criteria were completed:

1. Dedicated passive NSM sensor deployed.
2. Intended third-party traffic visibility proven.
3. Custom signature detection validated.
4. Behavior-based detection created and tuned.
5. Alert and flow evidence investigated.
6. Suricata telemetry integrated into Wazuh.
7. Controlled monitoring-path failure produced.
8. Blind spot proven using the same test behavior.
9. Monitoring path restored and detection recovered.
10. Passive interface and traffic mirror made persistent.
11. Full Proxmox reboot performed.
12. Monitoring path restored automatically.
13. Fresh Suricata detection generated after reboot.
14. Fresh Wazuh Threat Hunting event confirmed after reboot.

**Technical Build Gate: PASS ✓**

The deeper knowledge review and independent qualification remain intentionally deferred until the wider Cyber Forge range build-out, consistent with Modules 03–05.

---

# Current Module State

```text
Dedicated NSM sensor deployed            ✓
Passive monitoring interface             ✓
Third-party mirrored visibility          ✓
Suricata ruleset active                   ✓
Custom ICMP detection                     ✓
Behavior-based SYN detection              ✓
Alert-noise tuning                        ✓
Alert / flow investigation                ✓
Suricata → Wazuh integration              ✓
Threat Hunting visibility                 ✓
Controlled visibility failure             ✓
Blind-spot validation                     ✓
Monitoring-path recovery                  ✓
Passive NIC persistence                   ✓
Traffic-mirror persistence                ✓
Infrastructure VM startup ordering        ✓
Full host reboot validation               ✓
Post-reboot Suricata detection            ✓
Post-reboot Wazuh validation              ✓
Inline build evidence                     ✓
Technical Build Gate                      PASS ✓
Knowledge review                          DEFERRED
Independent qualification                 DEFERRED
```

Module 06 is **BUILD COMPLETE ✓**. Cyber Forge now has a persistent passive network-security-monitoring pipeline that survives a host reboot, detects controlled reconnaissance behavior, forwards Suricata telemetry into Wazuh, and restores analyst visibility without manual repair.
