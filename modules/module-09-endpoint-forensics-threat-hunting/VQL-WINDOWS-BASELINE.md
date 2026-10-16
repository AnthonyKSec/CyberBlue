# CyberBlue — Module 09: Windows Baseline VQL Workbook

**Source:** RHINOTOUGH Velociraptor notebook queries, October 15 Central / October 16 UTC.  
**Scope:** Read-only queries using `source()` against an **already completed collection**, not live endpoint scanning.

> Open the selected collection's **Notebook** tab. Add a VQL cell, insert the query relevant to that collection, save to run. Keep queries in their respective `Windows.System.Pslist`, `Windows.Network.Netstat`, `Windows.System.Services`, or `Windows.System.TaskScheduler` collection notebooks. `source()` is context-sensitive.

## A — Process lineage: parent PID 524

```sql
SELECT CreateTime, Pid, Ppid, Name, Exe, CommandLine
FROM source()
WHERE Pid = 524 OR Ppid = 524
```

**Observed:** 187 rows scanned, two children: `csrss.exe` PID 556 and `wininit.exe` PID 668 both parented to PID 524. No row with `Pid=524`.

## B — Related Windows startup processes

```sql
SELECT CreateTime, Pid, Ppid, Name, Exe, CommandLine
FROM source()
WHERE Name = "smss.exe"
   OR Name = "csrss.exe"
   OR Name = "wininit.exe"
```

**Observed:** 5 rows: `smss.exe` PID 368, `csrss.exe` 556, `wininit.exe` 668, `csrss.exe` 676, `csrss.exe` 3160. Historical parent references 524, 660, 7920.

## C — Missing parent references in the process snapshot

```sql
SELECT CreateTime, Pid, Ppid, Name, Exe
FROM source()
WHERE Pid = 524 OR Pid = 660 OR Pid = 7920
```

**Observed:** 187 scanned, zero rows. This only proves those PIDs were not present in that process snapshot; it does *not* prove compromise, deliberate hiding, or historical parent names.

## D — Established TCP sockets (corrected dotted-field syntax)

```sql
SELECT
    Pid, Name, Family, Type, Status,
    `Laddr.IP` AS LocalIP,
    `Laddr.Port` AS LocalPort,
    `Raddr.IP` AS RemoteIP,
    `Raddr.Port` AS RemotePort,
    Timestamp
FROM source()
WHERE Status = "ESTAB"
```

**Observed:** 85 rows scanned, six established TCP connections. The **first attempt** selected `Laddr` / `Raddr` and generated 'Symbol not found' errors; the corrected query uses literal dotted column names in backticks. Retaining this failure/recovery path is part of the learning evidence.

## E — Match Windows services to socket owning PIDs

Run in `Windows.System.Services` notebook:

```sql
SELECT
    Name, DisplayName, State, Pid,
    StartMode, PathName, UserAccount, ServiceDll
FROM source()
WHERE Pid = 1084
   OR Pid = 5240
   OR Pid = 4752
   OR Pid = 3452
```

**Observed:** 286 service rows scanned and four matches: `TermService` 1084, `WpnService` 5240, `AnyDesk` 4752 and `Velociraptor` 3452. Note 28-minute gap between network and service collections.

## F — Identify scheduled-task scripting and indirect execution

Run in `Windows.System.TaskScheduler` notebook:

```sql
SELECT
    TaskName, Command, Arguments,
    UserId, RunLevel, LogonType
FROM source()
WHERE Command =~ "(?i)(powershell|pwsh|cmd.exe|wscript|cscript|mshta|rundll32)"
   OR Arguments =~ "(?i)(powershell|pwsh|cmd.exe|wscript|cscript|mshta|rundll32)"
```

**Observed:** 257 task rows scanned, 15 matching records reviewed across two result pages. Because `dsregcmd.exe` *contains* `cmd.exe`, this query matched Windows device-join tasks too. This is a known **pattern-selection false positive**.

### Improved candidate filter for future use

A more targeted filter can distinguish executable path endings and whitespace-separated invocation tokens, but must be checked against actual paths and escape conventions before relying on it. Do not treat a regex hit as a detection by itself.

## G — Specific task attribution (optional follow-up)

```sql
SELECT TaskName, Mtime, Command, Arguments, UserId, RunLevel, LogonType, RegistrationTime
FROM source()
WHERE TaskName =~ "DispatchBoard|MicrosoftEdgeUpdateTaskMachineCore"
```

**Context:** Operator identifies `DispatchBoard Import` as Claude Desktop workflow; execution target and signatures still need independent confirmation.

## VQL competency summary

- Use `source()` only in the correct completed-collection notebook.
- Filter and corroborate, do not overinterpret absences.
- Escape dotted column names with backticks.
- Compare collection timestamps, not just PIDs.
- Record initial query mistakes and corrected versions.
- Preserve screenshots / data without publishing credential-bearing configuration.

**Status:** These are analysis exercises and reproducible filters, not fully generalized production detections.
