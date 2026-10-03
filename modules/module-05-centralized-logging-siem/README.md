# CyberBlue — Module 05
## Centralized Logging & SIEM Foundations

**Status:** IN PROGRESS  
**Current checkpoint:** Wazuh platform foundation complete — agent enrollment pending  
**Platform:** Proxmox VE 9.2.2  
**SIEM implementation:** Wazuh 4.14.8 single-node Docker deployment  
**Primary SIEM host:** VM100 — Ubuntu-SOC  
**Training method:** Principle → Architecture → Build → Validate → Break/Test → Troubleshoot → Restore → Explain → Document → Qualify

> Module 05 moves Cyber Forge from local endpoint telemetry into centralized security monitoring. The current build has established the Wazuh SIEM platform, validated the underlying host capacity, hardened administrative credentials, and reduced unnecessary service exposure. Endpoint enrollment and centralized event ingestion are the next build phase.

---

## Module Purpose

Module 04 established that useful telemetry exists on individual endpoints. Module 05 addresses the operational problem that follows:

> **How do we collect, centralize, search, correlate, and investigate security telemetry without logging into every endpoint individually?**

The capability being built is:

```text
ENDPOINT TELEMETRY
        ↓
COLLECTION / FORWARDING
        ↓
CENTRAL ANALYSIS
        ↓
INDEX / STORAGE
        ↓
SEARCH / ALERT / INVESTIGATE
```

Wazuh is the implementation used for this module, but the underlying principles apply to SIEM platforms generally.

---

## Target Architecture

```text
Endpoints
  ├─ WIN11-01
  │    └─ Windows + Sysmon telemetry
  │
  └─ Linux-Mint
       └─ Linux + auditd / journal telemetry
             ↓
         Wazuh Agents
             ↓
      Ubuntu-SOC — 10.10.20.10
       ├─ Wazuh Manager
       ├─ Wazuh Indexer
       └─ Wazuh Dashboard
             ↓
      Search → Alert → Investigate
```

Ubuntu-SOC also retains its management interface at:

```text
192.168.12.227/24
```

The Wazuh dashboard is intentionally reachable through the management network, while endpoint telemetry will use the Cyber Forge SOC network.

---

## Technical Build Progress

```text
[✓] Proxmox capacity baseline captured
[✓] Ubuntu-SOC CPU and memory baseline captured
[✓] Ubuntu-SOC resized to 4 vCPU / 8 GB RAM
[✓] Ubuntu-SOC virtual disk expanded to 64 GB
[✓] LVM/root filesystem expanded and validated
[✓] Docker validated
[✓] Docker Compose v2 installed and validated
[✓] Git validated
[✓] vm.max_map_count validated
[✓] Pre-Wazuh Proxmox snapshot created
[✓] Wazuh Docker v4.14.8 repository staged
[✓] Wazuh indexer certificates generated
[✓] Docker Compose configuration validated
[✓] Dashboard bound to management address only
[✓] Initial Wazuh stack deployment completed
[✓] Transient Docker TLS image-pull failure diagnosed and recovered
[✓] Initial dashboard login validated
[✓] Wazuh admin credential rotated
[✓] OpenSearch security configuration reapplied successfully
[✓] Direct indexer authentication validated with HTTP 200
[✓] Full Wazuh stack restarted and validated
[✓] New dashboard admin login validated
[✓] External host exposure of indexer port 9200 removed
[✓] Dashboard operation validated after indexer hardening
[ ] Linux-Mint Wazuh agent enrollment
[ ] WIN11-01 Wazuh agent enrollment
[ ] Least-privilege routing policy for cross-segment agent traffic
[ ] Centralized Linux telemetry validation
[ ] Centralized Windows/Sysmon telemetry validation
[ ] Known-event generation and SIEM search
[ ] Alert correlation and investigation
[ ] Controlled ingestion failure / recovery
[ ] Module 05 Technical Build Gate
[ ] Knowledge Review — deferred
[ ] Independent Qualification — deferred
```

---

## 1. Capacity Preflight

The Wazuh deployment began with host-capacity validation rather than immediately installing software.

Validated resources included:

```text
Proxmox host RAM: 31 GiB total
Ubuntu-SOC original allocation: 2 vCPU / 4 GB RAM / 32 GB disk
CPU: Intel Core i7-3960X
Physical cores: 6
Logical CPUs: 12
```

The Proxmox thin pool had sufficient physical free space for the VM expansion, although an existing thin-provisioning overcommit warning remains a separate infrastructure item to address later.

### Result

```text
Capacity preflight     PASS
```

---

## 2. Ubuntu-SOC Resource Expansion

VM100 was resized to support the Wazuh single-node stack:

```text
vCPU:    4
Memory:  8192 MB
Disk:    64 GB
```

Inside Ubuntu-SOC, the underlying virtual disk expansion was followed through the full storage stack:

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

Commands used included:

```bash
sudo growpart /dev/sda 3
sudo pvresize /dev/sda3
sudo lvextend -l +100%FREE -r /dev/mapper/ubuntu--vg-ubuntu--lv
```

Final root filesystem state:

```text
~61 GB total
~52 GB available
~12% used
```

### Result

```text
Compute expansion     PASS
Storage expansion     PASS
```

---

## 3. Host Prerequisites

The SIEM host was validated for:

```text
Docker:          29.1.3
Docker Compose:  2.40.3
Git:             2.43.0
vm.max_map_count 1048576
```

Docker Compose v2 was installed from Ubuntu packages and the host prerequisite checkpoint passed.

A Proxmox snapshot named:

```text
module05-pre-wazuh
```

was created before the Wazuh deployment.

---

## 4. Wazuh Repository and Certificates

The Wazuh Docker repository was staged at the stable release used for this build:

```text
v4.14.8
```

Deployment path:

```text
~/Wazuh-docker/single-node
```

Indexer TLS certificates were generated successfully using the supplied Docker Compose certificate generator.

The generated certificate set included the root CA, indexer, dashboard, manager, and administrative certificate/key pairs required by the stack.

---

## 5. Initial Stack Deployment

The initial image pull encountered a transient TLS transport error:

```text
tls: bad record MAC
```

The Compose configuration itself remained valid. The deployment was recovered by retrying the image pull and stack startup.

The resulting stack contained:

```text
wazuh.manager
wazuh.indexer
wazuh.dashboard
```

The dashboard was bound specifically to the Ubuntu-SOC management address:

```text
192.168.12.227:443 → dashboard:5601
```

This avoided unnecessarily publishing the dashboard on every Ubuntu-SOC interface.

### Result

```text
Wazuh stack startup   PASS
Dashboard access      PASS
```

---

## 6. Administrative Credential Hardening

The default Wazuh/OpenSearch administrative credential was rotated.

This required coordination between:

```text
docker-compose.yml
        +
internal_users.yml
        +
OpenSearch securityadmin.sh
```

An initial authentication test returned:

```text
HTTP 401
Unauthorized
```

The failure was traced to a mismatch between the intended password and the manually transcribed password hash.

Rather than treating this as a failed build, the issue became a troubleshooting exercise:

```text
Authentication failure
        ↓
Direct indexer test
        ↓
Hash/password mismatch isolated
        ↓
SSH access used for reliable copy/paste
        ↓
Configuration reset to known-good backups
        ↓
New hash generated
        ↓
Security configuration reapplied
        ↓
Direct authentication retested
```

The corrected OpenSearch security update completed with:

```text
Clusterstate: GREEN
Configuration for 'internalusers' created or updated
Done with success
```

Direct authentication against the indexer then returned:

```text
HTTP 200
```

The full Wazuh stack was restarted and the dashboard login using the new administrative credential succeeded.

### Security principle

> A successful configuration load does not prove that the intended credential works. Authentication must be tested directly.

### Result

```text
Credential rotation        PASS
Security config reload     PASS
Direct indexer auth        PASS — HTTP 200
Dashboard admin login      PASS
```

---

## 7. Indexer Port Hardening

The default Compose configuration published the indexer API to the Ubuntu-SOC host:

```text
0.0.0.0:9200 → indexer:9200
```

The manager and dashboard do not require that host-level exposure because they communicate with the indexer over Docker's internal network.

The host mapping was removed from `docker-compose.yml` and the indexer container was recreated.

Post-change validation showed:

```text
wazuh.indexer ... 9200/tcp
```

This indicates that port 9200 remains available inside the container/network.

Host validation returned:

```text
PORT 9200 NOT LISTENING ON HOST
```

The Wazuh dashboard continued to load successfully after the change.

### Security principle

> **Expose only the services that must cross a trust boundary.**

### Result

```text
Indexer internal service     PASS
External port 9200 removed   PASS
Dashboard functionality      PASS
```

---

## Troubleshooting Highlights

### Docker image-pull TLS failure

The initial Wazuh image pull failed with a TLS `bad record MAC` transport error. Compose validation was clean, and a retry of the pull/start sequence succeeded. This was treated as a transient image-transfer problem rather than a Wazuh configuration failure.

### Password-hash mismatch

A manually transcribed bcrypt hash resulted in `HTTP 401` when testing the Wazuh indexer directly.

The troubleshooting process isolated the failure before making additional changes:

```text
Dashboard login failure
   ↓
Direct indexer authentication test
   ↓
HTTP 401
   ↓
Credential/hash mismatch
```

SSH was then used instead of the Proxmox noVNC console to provide reliable clipboard support. The credential configuration was rebuilt from backups, the OpenSearch security configuration was reapplied, and the direct test returned `HTTP 200`.

### Administrative access method

The Proxmox console remains useful as an out-of-band/emergency console. For normal administration of Ubuntu-SOC, SSH through the management interface provides a more reliable workflow for complex commands and configuration editing.

---

## Current SIEM Architecture

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
                           
Ubuntu-SOC ens19
10.10.20.10/24
      |
   vmbr20
      |
SOC / Cyber Forge telemetry path
```

---

## Evidence Ledger — Current

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
```

> Evidence filenames are tracked here as part of the build record. Screenshot assets can be added to the module's `screenshots/` directory as the documentation set is finalized.

---

## Skills Demonstrated So Far

- SIEM architecture planning;
- Proxmox resource-capacity validation;
- VM CPU, memory, and disk resizing;
- Linux partition/LVM/filesystem expansion;
- Docker and Docker Compose administration;
- Wazuh single-node deployment;
- OpenSearch/Wazuh certificate generation;
- Docker Compose validation;
- management-plane service binding;
- Wazuh/OpenSearch administrative credential rotation;
- OpenSearch `securityadmin.sh` use;
- direct API authentication testing with `curl`;
- HTTP 401 troubleshooting;
- recovery from credential/hash mismatch;
- Docker service exposure reduction;
- host-level socket validation with `ss`;
- preserving internal service communication while removing unnecessary external exposure;
- evidence-driven troubleshooting and documentation.

---

## Current Build Gate State

```text
Host capacity preflight               PASS
Ubuntu-SOC compute expansion          PASS
Ubuntu-SOC storage expansion          PASS
Host prerequisites                    PASS
Pre-deployment snapshot               PASS
Wazuh repository staging              PASS
Certificate generation                PASS
Compose validation                    PASS
Wazuh stack deployment                PASS
Dashboard management binding          PASS
Initial dashboard access              PASS
Admin credential hardening            PASS
Direct indexer authentication         PASS
Full stack restart                    PASS
Dashboard login after hardening       PASS
Indexer host-port hardening           PASS
Dashboard after port hardening        PASS

Agent enrollment                      PENDING
Centralized endpoint ingestion        PENDING
Known-event SIEM correlation          PENDING
Failure / recovery exercise           PENDING

MODULE 05 TECHNICAL BUILD GATE         IN PROGRESS
KNOWLEDGE REVIEW                       DEFERRED
INDEPENDENT QUALIFICATION              DEFERRED
```

---

## Next Build Phase

The next Module 05 milestone is endpoint enrollment.

The planned order is:

```text
1. Linux-Mint — same SOC segment as Ubuntu-SOC
2. Validate Wazuh manager communication
3. Confirm Linux telemetry reaches the SIEM
4. Add least-privilege routing policy for WIN11-01
5. Enroll WIN11-01 from the Victim network
6. Validate Sysmon / Windows telemetry centrally
7. Generate known events and investigate them in Wazuh
```

Linux-Mint is intentionally first because it can reach the Wazuh manager directly on the SOC network without changing the Module 03 segmentation policy.

The Windows endpoint will require a deliberate least-privilege routing decision because Victim-to-SOC initiated traffic is currently blocked by the Cyber Forge router policy.
