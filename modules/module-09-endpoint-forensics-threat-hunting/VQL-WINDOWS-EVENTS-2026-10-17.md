# Module 09 — Windows Event and Persistence VQL Workbook (October 17/18, 2026)

> All shown `source()` queries operate in the Velociraptor **Notebook of the relevant completed collection**. Fields belong to that artifact; do not assume they transfer between collection types. Queries are read-only. Local Windows PowerShell policy changes and task registration are documented in [progress report](PROGRESS-2026-10-17.md), not embedded in these query examples.

## `Windows.Sys.StartupItems` — initial count (38 collected)

```sql
SELECT Enabled, count() AS Entries
FROM source()
GROUP BY Enabled
ORDER BY Entries DESC
```

**Observed:** `disabled = 32`; `enable = 6`. The literal string is `enable` (not `enabled`).

### Enabled entries and startup locations

```sql
SELECT Name, OSPath, Enabled
FROM source()
WHERE Enabled = "enable"
ORDER BY Name
```

**Observed:** `AnyDesk.lnk`, `OpenVPN Connect.lnk`, `Tailscale.lnk`, three `desktop.ini` files; three Startup folder scopes. Metadata-only result avoids lengthy shortcut `Details` JSON.

## `Windows.EventLogs.RDPAuth` — 264 collected

```sql
SELECT EventTime, Computer, Channel, EventID, DomainName, UserName, LogonType
FROM source()
ORDER BY EventTime DESC
LIMIT 15
```

**Observed:** October 16 2026 events `24,25,40,4624,4634`, account `RHINOTOUGH\Anthony` for some rows. The newest shown event preceded the collection date.

### Source-address correlation

```sql
SELECT EventTime, EventID, UserName, SourceIP, Description
FROM source()
WHERE EventID = 21
   OR EventID = 24
   OR EventID = 25
ORDER BY EventTime DESC
LIMIT 15
```

**Observed:** ten displayed October 12–16 event 24/25 records with `SourceIP=192.168.12.125` and `UserName=Anthony`. Correlate source with the earlier network socket but do not equate RDP reconnects with unique TCP sessions.

## `Windows.EventLogs.ScheduledTasks` — 0 then 53 records

**Baseline:** artifact succeeded with 0 records while `Microsoft-Windows-TaskScheduler/Operational` was disabled and `Other Object Access Events` auditing was off.

**After enabling Operational and running one harmless scheduled task:** artifact succeeded with 53 rows. To isolate the controlled task:

```sql
SELECT
    EventTime,
    EventID,
    EventRecordID,
    UserName,
    TaskName,
    Message
FROM source()
WHERE TaskName =~ "CyberBlue-Module09-TelemetryTest"
```

**Observed:** eight matching event IDs: `106,325,129,100,200,110,201,102`. **Do not add `ASC`** to this example; in this notebook the previous `ORDER BY EventTime ASC` attempt resulted in a parser error, and omitting `ORDER BY` successfully returned all eight rows.

## Limitations

- `source()` queries only what the selected completed collection returned; a zero-result filter is not proof an event never occurred.
- Collection times and actual event times may differ; annotate UTC and local time.
- "Enabled" Startup-folder items may be configuration files rather than executables.
- This collection verifies Task Scheduler *Operational* visibility; it does **not** establish that Security task-change auditing was fixed.
- Save redacted screenshots; do not publish enrollment config, private keys, raw auth tokens or exposed credentials.
