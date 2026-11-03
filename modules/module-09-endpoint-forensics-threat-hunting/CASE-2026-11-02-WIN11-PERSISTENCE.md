# CyberBlue / CyberForge — Module 09: WIN11-01 Controlled Persistence Case

> **Case:** CB-M09-WIN11-RUNKEY-2026-11-02  
> **Investigation status:** **PASS — controlled discovery, process correlation, evidence preservation, and cleanup.** **Full Module 09 qualification remains OPEN** (automatic logon and reproducible replay not demonstrated).  
> **Lab date:** November 2, 2026 US Central / November 3 UTC. All observations below are from operator-provided console screenshots, terminal output, and Velociraptor JSON, not independently downloaded evidence files.  
> **Scope:** Owned CyberForge WIN11-01 Windows 11 Pro 25H2 VM102, Velociraptor 0.77.3 client `C.e8f150bf59af8178`, private Victim zone `10.10.30.10`. No third-party system or real malware involved.

## 1. Principle and investigation question

A Windows `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` value can configure command execution at user sign-in. **Configuration is not proof of execution**; the investigative chain must distinguish persistent state, event telemetry, executed process, and cleanup state. Velociraptor provides registry collection, while Sysmon provides independent process-event telemetry. Missing telemetry is an evidence limitation, not evidence that activity did not happen.

**Question:** Could an investigator find a known benign user-level persistence change, correlate its configured command with executable behavior, preserve the evidence, and independently verify its removal?

## 2. Environment and safety

- Velociraptor client: `WIN11-01`, ID `C.e8f150bf59af8178`, v0.77.3, connected in GUI after installing a SHA-256-verified private Windows MSI. The installer and embedded enrollment configuration were **not** uploaded to GitHub.
- Server: DFIR-01 VM107, Velociraptor frontend `10.10.20.13:8000`; Windows `Test-NetConnection` yielded `TcpTestSucceeded=True`. Windows agent service `Velociraptor` was `Running` / `Automatic`.
- Router: ROUTER-01 VM104, default-deny nftables `inet cyberblue forward`. Narrow exception: source `10.10.30.10` to `10.10.20.13` TCP 8000. Post-reboot nftables listing confirmed default drop, Wazuh TCP 1514/1515 exception, and new rule remained. DFIR-01 Netplan drop-in staged return route `10.10.30.10/32 via 10.10.20.1 dev ens19`; its current presence and Velociraptor services were verified. **The supplied post-check alone does not prove DFIR-01 reboot occurred.**
- Test payload: local benign `marker.cmd` that appends `CYBERBLUE-M09-RUNKEY-EXECUTED` and date/time to `execution.log`. No exfiltration, networking, destructive action or credential collection.
- **Important risk:** Windows profile path `C:\Users\TEMP.WIN11-01.000`; `Win32_UserProfile` reported `Loaded=True`, `Status=1` (temporary profile). Sign-out/reboot could discard its data. Accordingly, **automatic sign-in replay was not attempted**.

## 3. Evidence and sequence

| ID | Evidence / method | Observed result | Interpretive limit |
|---|---|---|---|
| E01 | Velociraptor client overview | `WIN11-01` shown **Connected**, client `C.e8f150bf59af8178`, last-seen timestamp displayed | Enrollment and recent agent check-in, not evidence of persistence |
| E02 | First baseline collection: `Windows.Sys.StartupItems`, `Windows.System.Pslist`, `Windows.System.Services` | Completed; Windows services visible in GUI | Total baseline record counts and collection IDs were not transcribed |
| E03 | Controlled PowerShell user-level Registry Run-key creation | `CyberBlueM09PersistenceTest` points to `cmd.exe /c "C:\Users\TEMP.WIN11-01.000\AppData\Local\CyberBlue-M09\marker.cmd"` | Configuration staged; sign-in execution **not** established |
| E04 | Post-change Velociraptor `Windows.Sys.StartupItems` JSON | Exact `Run\CyberBlueM09PersistenceTest` entry present under current user's `HKEY_USERS\...-1001` hive; displayed `Enabled="disabled"` | Artifact's classification does not establish Windows launch behavior |
| E05 | Local Sysmon query IDs 12,13,14 (last 24h) | **0 matching registry events**; latest 300 Sysmon records contained **148 Event ID 1** process creates and **152 Event ID 5** terminations | Registry telemetry gap for this exercise; don't claim registry monitoring is comprehensively disabled without config inspection |
| E06 | Manually invoked benign `marker.cmd`, checked `execution.log`, queried Sysmon ID 1 | Marker written; Sysmon process creation records included `cmd.exe` command line referencing `CyberBlue-M09\marker.cmd` and `powershell.exe` parent | Confirms **manual** execution, **not** Run-key auto-execution |
| E07 | Local evidence preservation and cleanup in Administrator PowerShell | Nonempty `execution.log`, `run-key-before-cleanup.txt`, `sysmon-process-events.txt` saved to `C:\ProgramData\CyberBlue\Module09`; test Run value and script directory removed; local absence verified | SHA-256 digests and sizes captured later (Section 3A); original Velociraptor collections remain on DFIR-01 |
| E08 | **New** remote `Windows.Sys.StartupItems` collection after cleanup | `Run\CyberBlueM09PersistenceTest` **absent** from supplied JSON | Establishes remote cleanup at collection time, not permanent future state |
| E09 | Post-cleanup `RunNotification` artifact | `StartupTNotiCyberBlueM09PersistenceTest`, numeric detail `1`, still present | Residual notification metadata, **not** the executable `Run` value; intentionally not modified |

### Notable fields

- Active persistence path, as observed **before cleanup**: `HKEY_USERS\...-1001\Software\Microsoft\Windows\CurrentVersion\Run\CyberBlueM09PersistenceTest`.
- Script path `C:\Users\TEMP.WIN11-01.000\AppData\Local\CyberBlue-M09\marker.cmd`.
- The collected `Enabled="disabled"` metadata is retained as reported; it does not by itself prove the Run-key command was blocked by Windows.
- Original `desktop.ini` entries in Startup folders are Windows folder configuration, not proof of executable persistence.
- Timestamps across the training chat, Windows console and UTC may not be synchronized; **do not construct a minute-precise incident timeline** until host timezone and time synchronization are verified.

## 3A. Evidence file integrity manifest — observed on November 2, 2026 (US Central)

WIN11-01 Administrator PowerShell computed these SHA-256 digests against the **three existing files** under `C:\ProgramData\CyberBlue\Module09`. File names, sizes and digests are transcribed from the operator-supplied screenshot. The raw files themselves were **not transferred, independently rehashed on a second host, or committed to GitHub**.

| Relative file name | File size (bytes) | SHA-256 |
|---|---:|---|
| `execution.log` | 118 | `477C6EEE803CB09A835B0F4F07A339097831AAE5498691A48A89B6024875AC9A` |
| `run-key-before-cleanup.txt` | 179 | `952B49E95DE2582028AB0AB251721CCD1617269948A8CCB7E3BCBCAF659BCA68` |
| `sysmon-process-events.txt` | 2862 | `18642C6D52851505818D5AA3CB55C609264141FF2B7CF1F80E82DBE12465C18D` |

**Verification scope:** Hashes provide a future integrity comparison baseline, not an independently established chain of custody. Neither acquisition-time hashes nor signed collection manifests were produced at original capture; timestamps and user context should be recorded separately for formal legal-grade evidence.

## 4. Findings, confidence, and outcome

| Finding | Result / confidence |
|---|---|
| Registry persistence artifact identified by remote DFIR tool | **PASS / high**, E03 + E04 |
| Associated benign command manually executed and observed in Sysmon | **PASS / high**, E06 |
| Local evidence saved outside temporary profile | **PASS / high**, E07; hashing/independent export outstanding |
| Run-key removed and absence verified remotely | **PASS / high**, E07 + E08 |
| Windows profile healthy for sign-in replay | **FAIL / high** — temporary profile status 1 |
| Sysmon registry-change event coverage for this stimulus | **GAP / high observation**, zero IDs 12–14; cause unconfirmed |
| Automatic execution after sign-in | **NOT TESTED** |
| Independent reproducible scenario / reset and replay | **NOT TESTED** |
| Wazuh alert correlation for the specific test | **NOT VERIFIED** |
| Claim of malicious compromise | **NOT SUPPORTED** — entire activity was authorized/benign |

**Disposition:** Controlled lab simulation recovered and cleaned. There is no evidence in this case establishing malicious activity. The remaining `RunNotification` record is a documented residual, not active persistence. Do not overstate Sysmon coverage or user sign-in persistence.

## 5. Qualification follow-ups

1. Preserve protected offline copies of the three local evidence files, and independently re-verify them against Section 3A hashes; do not publish raw Windows user profile data or sensitive client config.
2. Repair the disposable WIN11-01 test profile under a dedicated rollback plan. Do **not** wipe or edit Windows `ProfileList` registry keys during this evidence session.
3. Inspect Sysmon configuration and implement narrow registry monitoring for the Run-key test; verify source event emission (ID 12/13/14) before claiming registry telemetry coverage.
4. Re-run the safe authorized simulation in a stable user profile. Capture prior state, sign-in-triggered execution, post-state Velociraptor collection, and event correlation. Remove only the test artifacts.
5. Validate repeatability, capture final screenshots/collection IDs/hashes, verify infrastructure reboot where not yet established, and complete Module 09 qualification gates.

### Evidence handling note

The user's screenshots and local preserved evidence were reviewed interactively during the training session. **Their raw binaries, screenshots, logs, private MSI, and credential-bearing Velociraptor configuration have not been added to this Git commit.** This report is a sanitized record of observations, not a claim that GitHub currently hosts the original forensic files.
