# CyberBlue — Module 06

## Network Security Monitoring

**Status:** WORK IN PROGRESS  
**Current checkpoint:** Passive Suricata monitoring, behavioral detection tuning, and Suricata → Wazuh SIEM integration validated  
**Platform:** Proxmox VE 9.2.2 / Ubuntu Server 24.04 / Suricata 7.0.3 / Wazuh 4.14.8  
**Training method:** Deploy → Configure → Generate Traffic → Detect → Investigate → Tune → Integrate → Validate

> Module 06 is actively being built. The current checkpoint proves end-to-end network-security-monitoring telemetry from mirrored lab traffic through Suricata and into Wazuh Threat Hunting. Analyst investigation, controlled visibility-failure testing, persistence hardening, and the final technical build gate remain open.

---

## Module Purpose

Module 06 introduces **Network Security Monitoring (NSM)** to Cyber Forge.

The goal is not simply to install Suricata. The goal is to demonstrate the ability to:

- deploy a dedicated network sensor;
- separate management access from passive monitoring;
- prove that the sensor can observe third-party traffic;
- distinguish normal activity from security-relevant behavior;
- create and tune custom detection logic;
- investigate alert context using network evidence;
- reduce duplicate/noisy alerts without losing useful signal; and
- forward Suricata telemetry into the existing Wazuh SIEM for analyst-facing investigation.

---

## Core Principle

> **A network sensor is useful only when it can see the traffic that matters, detect meaningful behavior, and deliver actionable telemetry to an analyst.**

A working Suricata process does not prove useful visibility.

Module 06 therefore validates the entire chain:

```text
Traffic
  ↓
Observation point
  ↓
Packet capture
  ↓
Protocol / flow inspection
  ↓
Detection logic
  ↓
Alert
  ↓
SIEM ingestion
  ↓
Analyst investigation
```

---

## Current Architecture

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

Suricata listens on `ens19`, not the management interface.

---

## Progress

```text
[✓] NSM-01 provisioned
[✓] Suricata 7.0.3 installed
[✓] AF_PACKET capture interface corrected
[✓] Emerging Threats Open rules installed
[✓] Suricata configuration validated
[✓] Live EVE JSON telemetry validated
[✓] Custom ICMP detection created and triggered
[✓] Dedicated passive monitoring NIC added
[✓] Proxmox vmbr20 traffic mirroring configured
[✓] Third-party passive detection validated
[✓] Protocol-aware inspection observed
[✓] TCP SYN behavioral threshold detection created
[✓] Alert-noise problem reproduced
[✓] Threshold rule tuned and retested
[✓] Wazuh Agent 003 enrolled on NSM-01
[✓] Suricata eve.json ingestion into Wazuh validated
[✓] Suricata alert visible in Wazuh Threat Hunting
[ ] Exact alert-window analyst write-up
[ ] Controlled NSM visibility failure / recovery test
[ ] Make passive NIC state persistent
[ ] Make Proxmox traffic mirroring persistent
[ ] Final Module 06 technical build gate
[ ] Knowledge review — deferred until wider range build-out
[ ] Independent qualification — deferred until wider range build-out
```

---

## 1. Suricata Deployment

Suricata 7.0.3 was installed on NSM-01.

The initial service start failed because the default capture configuration referenced `eth0`, while NSM-01 used `ens18`.

Observed error:

```text
Failure when trying to get MTU via ioctl for 'eth0':
No such device
```

The AF_PACKET interface was corrected and the configuration was validated before restart:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml
```

The Emerging Threats Open ruleset was installed with `suricata-update`.

Result:

```text
53,038 enabled rules
/var/lib/suricata/rules/suricata.rules
```

Live EVE JSON telemetry then confirmed DNS, HTTP, IPv4, IPv6, flow, and multicast/broadcast processing.

### Principle demonstrated

> **Service health is not enough. The capture interface, ruleset, and live packet processing must all be validated.**

---

## 2. First Controlled Detection

A local ICMP detection rule was created:

```text
alert icmp any any -> any any (msg:"CYBER FORGE - ICMP Detection Test"; itype:8; sid:1000001; rev:1;)
```

Controlled ICMP traffic from NSM-01 to `8.8.8.8` generated four matching alerts.

This validated:

```text
packet capture
    ↓
rule evaluation
    ↓
signature match
    ↓
EVE JSON alert generation
```

---

## 3. Passive Monitoring Design

The first ICMP test proved that Suricata could inspect traffic generated by NSM-01 itself, but that was not sufficient for a passive NSM sensor.

A second virtual NIC was therefore added:

```text
NSM-01 net1
  ↓
vmbr20
  ↓
ens19
  ↓
no IPv4 address
```

Suricata was moved from `ens18` to `ens19`.

Simply attaching NSM-01 to the same Linux bridge did **not** guarantee observation of unrelated VM traffic. A deliberate mirror point was required.

On the Proxmox host, ROUTER-01 vmbr20 traffic was mirrored from:

```text
tap104i0
```

to:

```text
tap105i1
```

using Linux traffic control (`tc`).

The current runtime mirror configuration is preserved in:

```text
configs/proxmox-vmbr20-mirror.sh
```

---

## 4. Third-Party Passive Detection

Linux-Mint generated:

```text
10.10.20.11 → 10.10.20.1
ICMP Echo Request
```

NSM-01, monitoring the unaddressed `ens19` interface, generated the custom ICMP alert.

This proved that the sensor could observe traffic generated by another system without being placed inline.

### Principle demonstrated

> **Passive monitoring depends on observation-point placement, not merely on installing an IDS on the same subnet.**

---

## 5. Protocol-Aware Inspection

A controlled request was sent from Linux-Mint to ROUTER-01 TCP/22 using an HTTP-style client.

The underlying TCP session was visible on `ens19`, including the SSH service response.

Suricata also produced application-layer anomaly telemetry because the observed protocol behavior did not match the expected service interaction.

This demonstrated that NSM can inspect more than source/destination IP addresses and ports.

---

## 6. Behavioral TCP SYN Detection

A behavior-oriented custom rule was added to identify rapid SYN activity from one source:

### Initial rule

```text
alert tcp any any -> any any (msg:"CYBER FORGE - TCP SYN Scan Threshold"; flags:S; flow:stateless; detection_filter:track by_src, count 10, seconds 5; sid:1000002; rev:1;)
```

Linux-Mint generated controlled TCP connection attempts across 50 destination ports on ROUTER-01.

Suricata successfully detected the activity, but the original rule generated repeated alerts after the threshold was crossed.

That produced a realistic detection-engineering problem:

```text
Detection works
     ↓
Too many duplicate alerts
     ↓
Analyst noise
     ↓
Rule requires tuning
```

---

## 7. Detection Tuning

The rule was revised to use `threshold:type both`:

```text
alert tcp any any -> any any (msg:"CYBER FORGE - TCP SYN Scan Threshold"; flags:S; flow:stateless; threshold:type both, track by_src, count 10, seconds 5; sid:1000002; rev:2;)
```

The exact same 50-port test was replayed.

### Before

Multiple alerts were generated after the threshold was reached.

### After

One clean alert was generated for the scan window.

### Principle demonstrated

> **A detection that technically works but overwhelms the analyst is not well tuned.**

The exercise validated a repeatable detection-engineering loop:

```text
Detect
  ↓
Measure noise
  ↓
Modify rule
  ↓
Validate syntax
  ↓
Replay same behavior
  ↓
Compare result
```

The active local rule file is preserved in:

```text
configs/suricata-local.rules
```

---

## 8. Alert Investigation

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

Flow review showed rapid connections to multiple destination ports.

Most flows closed quickly, while TCP/22 showed additional bidirectional interaction consistent with the reachable SSH service observed earlier.

Preliminary disposition:

> **True Positive — Controlled Reconnaissance.** A single internal host generated rapid TCP SYN activity against multiple ports on ROUTER-01. The behavior exceeded the configured scan threshold and was detected by the passive NSM sensor. The activity was authorized as part of the Cyber Forge lab exercise; no containment was required.

The exact alert-window correlation write-up remains an open item before the Module 06 build gate is closed.

---

## 9. Suricata → Wazuh Integration

NSM-01 was enrolled into the existing Wazuh environment as:

```text
Agent ID:   003
Agent name: NSM-01
Agent IP:   192.168.12.135
```

The Wazuh agent was configured to collect:

```text
/var/log/suricata/eve.json
```

Configuration snippet:

```xml
<localfile>
  <log_format>json</log_format>
  <location>/var/log/suricata/eve.json</location>
</localfile>
```

The reusable snippet is preserved in:

```text
configs/wazuh-suricata-localfile.xml
```

After a fresh controlled scan, Wazuh Threat Hunting displayed the Suricata event with:

```text
agent.name              NSM-01
data.src_ip             10.10.20.11
data.dest_ip            10.10.20.1
data.proto              TCP
data.in_iface           ens19
data.alert.signature    CYBER FORGE - TCP SYN Scan Threshold
data.alert.signature_id 1000002
rule.id                 86601
rule.groups             ids, suricata
rule.level              3
rule.firedtimes         1
```

This validated the end-to-end monitoring path:

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
Wazuh Agent
   ↓
Wazuh Manager
   ↓
Threat Hunting Dashboard
```

---

## 10. Troubleshooting Cases

### Suricata referenced the wrong capture interface

**Symptom:** Suricata failed to start.

**Root cause:** Configuration referenced `eth0`; NSM-01 used predictable interface names.

**Resolution:** Corrected only the AF_PACKET capture interface and validated with `suricata -T`.

**Lesson:** Do not perform a global interface-name replacement when only one capture stanza is wrong.

---

### Custom rule file was accidentally contaminated

**Symptom:**

```text
detect-parse: An invalid action "af-packet:" was given
```

**Root cause:** Part of the Suricata YAML AF_PACKET configuration was accidentally pasted into `local.rules`.

**Resolution:** Rebuilt `local.rules` with only valid Suricata signatures and revalidated before restart.

**Lesson:** Configuration syntax validation should happen before every service restart after rule changes.

---

### Wazuh agent failed after adding Suricata collection

**Symptom:**

```text
Invalid element in the configuration: 'localfile'
```

**Root cause:** The Suricata `<localfile>` block was placed outside an `<ossec_config>` section.

**Resolution:** Moved the block inside the active Wazuh configuration section and validated with:

```bash
sudo /var/ossec/bin/wazuh-logcollector -t
sudo /var/ossec/bin/wazuh-agentd -t
```

**Lesson:** Structured configuration should be syntax-tested before restarting a telemetry agent.

---

## 11. Current Temporary / Nonpersistent State

The following items are intentionally still runtime-only:

### NSM monitoring NIC state

```bash
sudo ip link set ens19 up
```

This state may be lost when NSM-01 reboots unless it is made persistent through the guest network configuration.

### Proxmox traffic mirror

The current `tc` mirror configuration is runtime-only.

It should be treated as lost after a Proxmox reboot and revalidated after relevant VM/tap-interface recreation.

These are tracked as finalization tasks rather than hidden assumptions.

---

## 12. Evidence Captured

The following evidence was captured during the current Module 06 build:

```text
01a-module06-proxmox-capacity-preflight.png
02a-module06-first-suricata-detection.png
02b-module06-passive-mirrored-detection.png
03a-module06-tcp-syn-threshold-detection.png
03b-module06-tuned-syn-detection.png
04a-module06-wazuh-agent-validation.png
04b-module06-suricata-wazuh-integration.png
04c-module06-wazuh-alert-details.png
```

The screenshots are retained as the portfolio evidence set for the current checkpoint.

---

## 13. Skills Demonstrated

Module 06 work to date demonstrates practical experience with:

- Suricata IDS/NSM deployment;
- AF_PACKET capture configuration;
- Suricata rule management;
- Emerging Threats Open rules;
- EVE JSON telemetry;
- custom Suricata signatures;
- ICMP detection;
- TCP SYN behavior detection;
- threshold-based detection logic;
- alert-noise reduction;
- repeatable before/after detection testing;
- passive monitoring architecture;
- dual-NIC sensor design;
- Proxmox Linux bridges;
- Linux `tc` traffic mirroring;
- passive third-party packet observation;
- `tcpdump` packet validation;
- protocol-aware NSM interpretation;
- flow and alert correlation;
- Wazuh agent enrollment;
- Suricata-to-Wazuh log ingestion;
- Wazuh Threat Hunting;
- SIEM field-level investigation; and
- evidence-driven troubleshooting.

---

## 14. Remaining Module Work

Before the Module 06 technical build gate is complete:

1. Complete the exact alert-window analyst investigation.
2. Perform a controlled monitoring/telemetry visibility failure.
3. Demonstrate the blind spot while the monitoring path is broken.
4. Restore the monitoring path and prove detection returns.
5. Make the passive monitoring NIC state persistent.
6. Make the Proxmox traffic mirror persistent or replace it with a documented durable mechanism.
7. Reboot/revalidate the final monitoring path.
8. Capture final evidence and close the technical build gate.

---

## Current Module State

```text
Dedicated NSM sensor deployed            ✓
Passive monitoring interface             ✓
Third-party mirrored visibility          ✓
Suricata ruleset active                   ✓
Custom ICMP detection                     ✓
Behavior-based SYN detection              ✓
Alert-noise tuning                        ✓
Suricata → Wazuh integration              ✓
Threat Hunting visibility                 ✓
Exact alert-window investigation          IN PROGRESS
Controlled visibility-failure test        PENDING
Monitoring-path persistence               PENDING
Post-reboot validation                    PENDING
Technical Build Gate                      OPEN
```

Module 06 has reached a meaningful checkpoint: **Cyber Forge now has a working passive network-security-monitoring pipeline with tuned behavioral detection and centralized SIEM visibility.**
