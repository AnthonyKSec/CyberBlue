# CyberBlue — Module 04
## Endpoint Telemetry & Logging

**Status:** IN PROGRESS 🚧  
**Current checkpoint:** Native endpoint telemetry and known authentication-event correlation complete  
**Platform:** Proxmox VE 9.2.2  
**Endpoints:** `Linux-Mint` and `WIN11-01`  
**Module focus:** Native endpoint evidence, event correlation, visibility gaps, and later enhanced telemetry  
**Training method:** Principle → Architecture → Build → Validate → Break/Test → Troubleshoot → Restore → Explain → Document → Qualify

> This README documents only the work actually completed so far. Module 04 is intentionally being published as a work-in-progress so the repository reflects active hands-on progress rather than only finished modules.

---

## Module Purpose

Module 04 shifts the Cyber Forge from network-path engineering into **endpoint visibility**.

The core question is:

> **When something happens on a Windows or Linux endpoint, what evidence does the operating system record, where does that evidence live, and how confidently can an investigator correlate it to a known action?**

The module begins with native operating-system telemetry before introducing enhanced instrumentation.

---

## Plain-English Model

```text
Something happens on an endpoint
        ↓
The operating system records evidence
        ↓
We locate the evidence
        ↓
We correlate it to a known action
        ↓
Later: enhanced telemetry fills visibility gaps
```

---

## Lab Endpoints

| System | Role | Address | Segment |
|---|---|---|---|
| Linux-Mint | Linux endpoint | `10.10.20.11/24` | SOC / `vmbr20` |
| WIN11-01 | Windows endpoint | `10.10.30.10/24` | Victim / `vmbr30` |

Both systems entered Module 04 with validated connectivity from the previous networking module.

---

## Progress

```text
[✓] Section 01 — Endpoint baseline and clean snapshots
[✓] Section 02 — Native Linux journal and session telemetry
[✓] Section 03 — Linux service/log-source inspection
[✓] Section 04 — Linux authentication telemetry
[✓] Section 05 — Native Windows Security telemetry
[✓] Section 06 — Known Linux privileged action correlated to logs
[✓] Section 07 — Known Windows interactive logon correlated to logs

[ ] Service activity generation and investigation
[ ] File activity visibility testing
[ ] Process activity visibility testing
[ ] Native telemetry matrix
[ ] Enhanced Windows telemetry
[ ] Enhanced Linux auditing
[ ] Controlled telemetry failure / restoration
[ ] Final documentation and Build Gate
[ ] Knowledge Review / Qualification Gate
```

---

## 1. Endpoint Baseline

Before changing telemetry configuration, clean snapshots were created for both endpoints.

![Cyber Forge endpoint baseline](screenshots/01a-endpoint-lab-baseline.png)

![Linux Mint pre-telemetry snapshot](screenshots/01b-linux-mint-pre-telemetry-snapshot.png)

![Windows 11 pre-telemetry snapshot](screenshots/01c-win11-pre-telemetry-snapshot.png)

Snapshot name used:

```text
module04-pre-telemetry-baseline
```

This established rollback points before introducing enhanced endpoint logging later in the module.

---

## 2. Native Linux Telemetry

The Linux endpoint was examined before installing any additional telemetry tooling.

### Recent journal events

```bash
journalctl -n 50 --no-pager
```

![Linux recent journal events](screenshots/02a-linux-recent-journal-events.png)

The captured events included normal desktop and service activity as well as security-relevant operational records such as `sudo`, cron, and service failures.

### Current boot telemetry

```bash
journalctl -b
```

![Linux current boot telemetry](screenshots/02b-linux-current-boot-telemetry.png)

This demonstrated that the systemd journal can reconstruct events beginning with the current boot.

### Login and reboot history

```bash
last
```

![Linux login and reboot history](screenshots/02c-linux-login-reboot-history.png)

The output provided user/session and reboot history, including a prior entry marked as a crash.

### Principle demonstrated

```text
Event     = something happened
Log       = a stored record of activity
Telemetry = evidence collected from the endpoint that can support investigation
```

---

## 3. Linux Service and Log-Source Inspection

Service-specific telemetry was inspected with the systemd journal.

```bash
journalctl -u NetworkManager -n 30 --no-pager
```

![Linux NetworkManager telemetry](screenshots/03a-linux-networkmanager-telemetry.png)

The output showed interface discovery, link-state transitions, and connection activation for the Mint endpoint.

The traditional Linux log directory was also inventoried:

```bash
sudo ls -lah /var/log
```

![Linux /var/log inventory](screenshots/03b-linux-var-log-inventory.png)

Observed sources included:

```text
auth.log
boot.log
dmesg
kern.log
syslog
wtmp
btmp
journal/
```

### Principle demonstrated

> Do not assume every Linux distribution exposes security evidence in exactly the same files. Inspect the host and determine which telemetry sources actually exist.

---

## 4. Linux Authentication Telemetry

The Mint host's authentication log was filtered for security-relevant activity:

```bash
sudo grep -E 'sudo|session opened|session closed|authentication failure|Failed password|Accepted' /var/log/auth.log | tail -n 40
```

![Linux authentication telemetry](screenshots/04a-linux-authentication-telemetry.png)

The evidence included:

- PAM session opens and closes;
- `sudo` activity;
- the `cyberadmin` lab account;
- commands executed with elevated privileges.

This demonstrated that authentication and privilege activity can be correlated to a user, command, and timestamp.

---

## 5. Native Windows Security Telemetry

Windows Event Viewer was used to inspect:

```text
Event Viewer
└── Windows Logs
    └── Security
```

A Security event was opened and interpreted rather than simply collecting a screenshot.

![Windows Security Event Viewer](screenshots/05a-windows-security-event-viewer.png)

The captured event showed:

```text
Event ID:     4672
Description:  Special privileges assigned to new logon
Account:      SYSTEM
Log:          Security
Result:       Audit Success
Host:         WIN11-01
```

### Principle demonstrated

When reviewing an event, ask:

```text
What happened?
Which component recorded it?
Which account was involved?
Which host generated it?
When did it happen?
Would this matter to an investigator?
```

---

## 6. Known Linux Privileged Activity

A known harmless administrative action was generated:

```bash
date
sudo whoami
```

Result:

```text
root
```

The corresponding evidence was then located in `/var/log/auth.log`.

![Known Linux sudo event](screenshots/06a-linux-known-sudo-event.png)

The command and log timestamps aligned closely, and the log recorded:

```text
COMMAND=/usr/bin/whoami
session opened for user root
session closed for user root
```

### Correlation model

```text
Known action
   ↓
Known timestamp
   ↓
Known privileged command
   ↓
Corresponding authentication evidence
```

---

## 7. Known Windows Interactive Logon

A Windows authentication event was generated and then correlated in the Security log.

An initial Event 4624 with **Logon Type 5** represented a service logon and was correctly rejected as evidence of the user's interactive authentication.

A matching event was then located:

```text
Event ID:       4624
Result:         Audit Success
Logon Type:     2
Account Name:   cyberadmin
Account Domain: WIN11-01
Computer:       WIN11-01
```

![Known Windows authentication event](screenshots/06b-windows-known-authentication-event.png)

### Why the logon type mattered

```text
4624 + Logon Type 5
→ service logon

4624 + Logon Type 2
→ interactive user logon
```

The lesson was not to treat an Event ID alone as proof of a specific user action. The account, timestamp, logon type, and surrounding context must agree.

---

## Troubleshooting Note — SPICE Clipboard

During the module, SPICE clipboard integration was investigated to speed command entry on Linux-Mint.

The Proxmox SPICE channel was present, but the guest package was not installed:

```text
spice-vdagent
Installed: (none)
```

Package installation could not proceed because the isolated Mint endpoint had no Internet/DNS path to Ubuntu repositories. Rather than alter the Cyber Forge network design solely for clipboard convenience, the troubleshooting effort was deferred and the lab continued with manual command entry.

### Operational lesson

> A convenience feature should not derail the primary lab objective or casually weaken the intended network architecture.

---

## Evidence Ledger — Current Checkpoint

```text
01a-endpoint-lab-baseline.png
01b-linux-mint-pre-telemetry-snapshot.png
01c-win11-pre-telemetry-snapshot.png

02a-linux-recent-journal-events.png
02b-linux-current-boot-telemetry.png
02c-linux-login-reboot-history.png

03a-linux-networkmanager-telemetry.png
03b-linux-var-log-inventory.png

04a-linux-authentication-telemetry.png

05a-windows-security-event-viewer.png

06a-linux-known-sudo-event.png
06b-windows-known-authentication-event.png
```

---

## Skills Demonstrated So Far

- Proxmox snapshot workflow;
- Linux systemd journal analysis;
- Linux boot-event review;
- Linux login and reboot history;
- service-specific journal filtering;
- Linux log-source discovery;
- PAM authentication-event review;
- `sudo` activity correlation;
- Windows Event Viewer navigation;
- Windows Security log interpretation;
- Event 4672 interpretation;
- Event 4624 logon-type differentiation;
- timestamp-based event correlation;
- distinguishing service logons from interactive user logons;
- evidence-driven troubleshooting;
- recognizing when operational convenience should not override lab architecture.

---

## Current Build State

```text
Endpoint baseline snapshots              ✓
Native Linux telemetry explored          ✓
Native Windows telemetry explored        ✓
Linux authentication evidence located    ✓
Windows authentication evidence located  ✓
Known Linux privileged action correlated ✓
Known Windows user logon correlated      ✓

Service activity testing                 NEXT
File/process visibility testing          PENDING
Native telemetry matrix                  PENDING
Enhanced telemetry                       PENDING
Telemetry failure/restoration            PENDING
Technical Build Gate                     PENDING
Knowledge Review                         PENDING
```

## Next Build Phase

The next practical phase will continue with:

```text
Service activity
        ↓
File/process visibility testing
        ↓
Native telemetry matrix
        ↓
Enhanced telemetry
        ↓
Controlled telemetry failure/restoration
        ↓
Build Gate
```

**Module 04 remains IN PROGRESS.**
